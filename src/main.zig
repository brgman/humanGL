const std = @import("std");
const zopengl = @import("zopengl");
const c = @import("c");
const math = @import("maths.zig");
const constants = @import("constants.zig");
const body = @import("body.zig");
const anim = @import("anim.zig");

const gl = zopengl.bindings;
const Mat4 = math.Mat4;

var tri_limit: usize = 12;
pub var show_axes: bool = false;

// const State = enum {splash, scene};
// var state: State = .splash;
// const splash_time = 2.0;
// var splash_start = c.getTime();
// var cur: usize = 0;
// var acc: f64 =  0;
// var last = c.getTime();

// --- shaders ---
// Le vertex shader place chaque sommet a l'ecran, le fragment shader donne la couleur.
// La normale suit la rotation du modele (mat3(uModel)). Le scale est applique sur les
// axes de chaque boite, donc la direction de la normale reste juste apres normalize().

const vertex_src =
    \\#version 400 core
    \\layout(location = 0) in vec3 aPos;
    \\layout(location = 1) in vec3 aNormal;
    \\uniform mat4 uProj;
    \\uniform mat4 uView;
    \\uniform mat4 uModel;
    \\out vec3 vNormal;
    \\void main() {
    \\    vNormal = mat3(uModel) * aNormal;
    \\    gl_Position = uProj * uView * uModel * vec4(aPos, 1.0);
    \\}
;

const fragment_src =
    \\#version 400 core
    \\in vec3 vNormal;
    \\uniform vec3 uColor;
    \\out vec4 FragColor;
    \\void main() {
    \\    vec3 n = normalize(vNormal);
    \\    float light = 0.35 + 0.65 * max(dot(n, normalize(vec3(0.4, 0.8, 0.6))), 0.0);
    \\    FragColor = vec4(uColor * light, 1.0);
    \\}
;

// --- cube 1x1x1 centre en (0,0,0) ---
// 6 faces x 2 triangles x 3 sommets, chaque sommet = position (3) + normale (3)

const cube_vertex_count = 36;

fn buildCube() [cube_vertex_count * 6]f32 {
    // pour chaque face : normale, axe u, axe v
    const faces = [6][3][3]f32{
        .{ .{ 0, 0, 1 }, .{ 1, 0, 0 }, .{ 0, 1, 0 } }, // +Z
        .{ .{ 0, 0, -1 }, .{ -1, 0, 0 }, .{ 0, 1, 0 } }, // -Z
        .{ .{ 1, 0, 0 }, .{ 0, 0, -1 }, .{ 0, 1, 0 } }, // +X
        .{ .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 1, 0 } }, // -X
        .{ .{ 0, 1, 0 }, .{ 1, 0, 0 }, .{ 0, 0, -1 } }, // +Y
        .{ .{ 0, -1, 0 }, .{ 1, 0, 0 }, .{ 0, 0, 1 } }, // -Y
    };

    //   (y) v
    //  ^   3(-1,+1) ---- 2(+1,+1)
    //  \      |            |
    //  \   0(-1,-1) ---- 1(+1,-1)
    //  └──────────────────────> (x) u          from the center of facem
    const signs = [4][2]f32{ .{ -1, -1 }, .{ 1, -1 }, .{ 1, 1 }, .{ -1, 1 } };
    const order = [6]usize{ 0, 1, 2, 0, 2, 3 };

    var data: [cube_vertex_count * 6]f32 = undefined;
    var n: usize = 0;
    for (faces) |face| {
        const nrm = face[0];
        const u = face[1];
        const v = face[2];
        var corners: [4][3]f32 = undefined;
        for (signs, 0..) |s, i| {
            for (0..3) |k| {
                corners[i][k] = 0.5 * nrm[k] + 0.5 * s[0] * u[k] + 0.5 * s[1] * v[k];
            }
        }
        for (order) |idx| {
            for (0..3) |k| {
                data[n] = corners[idx][k];
                n += 1;
            }
            for (0..3) |k| {
                data[n] = nrm[k];
                n += 1;
            }
        }
    }
    return data;
}

// --- OpenGL utils ---

fn getProcAddress(name: [*:0]const u8) callconv(.c) ?*const anyopaque {
    return @ptrCast(c.SDL_GL_GetProcAddress(name));
}

fn compileShader(kind: gl.Enum, src: [*:0]const u8) !gl.Uint {
    const shader = gl.createShader(kind);
    gl.shaderSource(shader, 1, &[_][*:0]const u8{src}, null);
    gl.compileShader(shader);

    var ok: gl.Int = 0;
    gl.getShaderiv(shader, gl.COMPILE_STATUS, &ok);
    if (ok == 0) {
        var log: [512]u8 = undefined;
        var len: gl.Sizei = 0;
        gl.getShaderInfoLog(shader, log.len, &len, &log);
        std.debug.print("shader error: {s}\n", .{log[0..@intCast(len)]});
        return error.ShaderCompileFailed;
    }
    return shader;
}

fn createProgram() !gl.Uint {
    const vs = try compileShader(gl.VERTEX_SHADER, vertex_src);
    const fs = try compileShader(gl.FRAGMENT_SHADER, fragment_src);

    const program = gl.createProgram();
    gl.attachShader(program, vs);
    gl.attachShader(program, fs);
    gl.linkProgram(program);
    gl.deleteShader(vs);
    gl.deleteShader(fs);

    var ok: gl.Int = 0;
    gl.getProgramiv(program, gl.LINK_STATUS, &ok);
    if (ok == 0) {
        var log: [512]u8 = undefined;
        var len: gl.Sizei = 0;
        gl.getProgramInfoLog(program, log.len, &len, &log);
        std.debug.print("link error: {s}\n", .{log[0..@intCast(len)]});
        return error.ProgramLinkFailed;
    }
    return program;
}

const speeds = [_]f32{ 0.1, 0.25, 0.5, 1, 2, 4 }; // facteur de vitesse (x1 = temps reel)
const frame_step: f32 = 1.0 / 30.0; // pas image par image (en pause)

const BuildState = struct {
    limit: usize = std.math.maxInt(usize), // cubes autorises dans cette image
    seen: usize = 0, // cubes rencontres dans cette image
    total: usize = 0, // nombre total de cubes (mesure a l'image precedente)
    report: bool = false, // afficher la matrice du dernier cube apparu ?
};
var build = BuildState{};

fn printCube(n: usize, model: Mat4) void {
    std.debug.print("\n[cube {d}/{d}] matrice du modele (translation = derniere colonne)\n", .{ n, build.total });
    // model.m est en column-major : l'element (ligne r, colonne col) est m[col * 4 + r]
    for (0..4) |row| {
        std.debug.print("  | {d:8.3} {d:8.3} {d:8.3} {d:8.3} |\n", .{ model.m[row], model.m[4 + row], model.m[8 + row], model.m[12 + row] });
    }
}

// -- render ---
pub const Renderer = struct {
    program: gl.Uint,
    vao: gl.Uint,
    vbo: gl.Uint,
    u_proj: gl.Int,
    u_view: gl.Int,
    u_model: gl.Int,
    u_color: gl.Int,

    /// A appeler une fois que le contexte OpenGL est charge
    pub fn init() !Renderer {
        const program = try createProgram();

        const cube_data = buildCube();
        var vao: gl.Uint = 0;
        var vbo: gl.Uint = 0;
        gl.genVertexArrays(1, &vao);
        gl.genBuffers(1, &vbo);
        gl.bindVertexArray(vao);
        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
        gl.bufferData(gl.ARRAY_BUFFER, @intCast(cube_data.len * @sizeOf(f32)), &cube_data, gl.STATIC_DRAW);
        // attribut 0 : position (3 floats), attribut 1 : normale (3 floats), pas de 6 floats
        gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), null);
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
        gl.enableVertexAttribArray(1);

        gl.enable(gl.DEPTH_TEST);

        return Renderer{
            .program = program,
            .vao = vao,
            .vbo = vbo,
            .u_proj = gl.getUniformLocation(program, "uProj"),
            .u_view = gl.getUniformLocation(program, "uView"),
            .u_model = gl.getUniformLocation(program, "uModel"),
            .u_color = gl.getUniformLocation(program, "uColor"),
        };
    }

    pub fn deinit(self: Renderer) void {
        var vao = self.vao;
        var vbo = self.vbo;
        gl.deleteVertexArrays(1, &vao);
        gl.deleteBuffers(1, &vbo);
        gl.deleteProgram(self.program);
    }

    /// Debut d'image : camera (projection + vue)
    pub fn begin(self: Renderer, proj: Mat4, view: Mat4) void {
        gl.useProgram(self.program);
        gl.bindVertexArray(self.vao);
        gl.uniformMatrix4fv(self.u_proj, 1, gl.FALSE, &proj.m);
        gl.uniformMatrix4fv(self.u_view, 1, gl.FALSE, &view.m);
    }

    /// Dessine UN cube 1x1x1 a l'origine de la matrice 'model'
    /// Tout le reste (position, taille) est dans la matrice
    pub fn drawUnitCube(self: Renderer, model: Mat4, color: [3]f32) void {
        // construction au ralenti : on compte chaque cube, on ne dessine que les `limit` premiers
        build.seen += 1;
        if (build.seen > build.limit) return;
        if (build.report and build.seen == build.limit) printCube(build.seen, model);

        gl.uniformMatrix4fv(self.u_model, 1, gl.FALSE, &model.m);
        gl.uniform3f(self.u_color, color[0], color[1], color[2]);
        // gl.drawArrays(gl.TRIANGLES, 0, cube_vertex_count);
        gl.drawArrays(gl.TRIANGLES, 0, @intCast(tri_limit * 3));
        // gl.finish();
        // c.SDL_Delay(300);
    }

    fn drawRaw(self: Renderer, model: Mat4, color: [3]f32) void {
        gl.uniformMatrix4fv(self.u_model, 1, gl.FALSE, &model.m);
        gl.uniform3f(self.u_color, color[0], color[1], color[2]);
        gl.drawArrays(gl.TRIANGLES, 0, cube_vertex_count);
    }

    pub fn drawAxes(self: Renderer, base: Mat4, len: f32) void {
        if (!show_axes) return;
        gl.disable(gl.DEPTH_TEST);
        defer gl.enable(gl.DEPTH_TEST);

        const t: f32 = 0.01;
        // X red
        self.drawRaw(base.mul(Mat4.translate(len / 2, 0, 0)).mul(Mat4.scale(len, t, t)), .{ 1.0, 0.2, 0.2 });
        // Y green
        self.drawRaw(base.mul(Mat4.translate(0, len / 2, 0)).mul(Mat4.scale(t, len, t)), .{ 0.2, 1.0, 0.2 });
        // Z blue
        self.drawRaw(base.mul(Mat4.translate(0, 0, len / 2)).mul(Mat4.scale(t, t, len)), .{ 0.3, 0.5, 1.0 });
    }
};

fn adjust(v: *f32, delta: f32) void {
    v.* = std.math.clamp(v.* + delta, 0.3, 2.0);
}

pub fn main() !void {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.debug.print("SDL_Init failed: {s}\n", .{c.SDL_GetError()});
        return error.SDLInitFailed;
    }
    defer c.SDL_Quit();

    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 0);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 24);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_MULTISAMPLEBUFFERS, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_MULTISAMPLESAMPLES, 4);

    const window = c.SDL_CreateWindow(
        "HumanGL",
        800,
        600,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.debug.print("SDL_CreateWindow failed: {s}\n", .{c.SDL_GetError()});
        return error.WindowCreationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const gl_context = c.SDL_GL_CreateContext(window) orelse {
        std.debug.print("SDL_GL_CreateContext failed: {s}\n", .{c.SDL_GetError()});
        return error.GLContextCreationFailed;
    };
    defer _ = c.SDL_GL_DestroyContext(gl_context);

    _ = c.SDL_GL_SetSwapInterval(1);

    try zopengl.loadCoreProfile(getProcAddress, 4, 0);
    std.debug.print("OpenGL loaded: {s}\n", .{gl.getString(gl.VERSION)});

    const renderer = try Renderer.init();
    defer renderer.deinit();

    // -- etat de la scene
    var dims = body.Dims{};
    var mode: anim.Mode = .stay;
    var time: f32 = 0;
    var yaw: f32 = 25; // camera orbitale (degres)
    var pitch: f32 = 15;
    var auto_rotate = true;
    var last_ticks: u64 = c.SDL_GetTicks();

    var paused = false; // P : fige le temps (animation + construction)
    var speed_idx: usize = 3; // index dans `speeds` (3 -> x1)
    var build_mode = false; // B : le corps apparait cube par cube
    var build_limit: usize = 0; // nombre de cubes visibles
    var build_timer: f32 = 0; // secondes accumulees (x vitesse)
    var wireframe = false; // F : mode filaire
    var title_dirty = true; // mettre a jour le titre de la fenetre

    std.debug.print("1: stay | 2: walk | 3: jump | Espace: rotation auto | souris (clic gauche): camera | Esc: quitter\n", .{});
    std.debug.print("T/G: allonger / raccourcir le torse (tete et bras suivent)\n", .{});
    std.debug.print("P: pause | haut/bas: vitesse | N/V: image suivante/precedente (en pause) | F: filaire\n", .{});
    std.debug.print("B: construction cube par cube | Entree / Retour arriere: cube +1 / -1 | R: recommencer\n", .{});

    var running = true;
    while (running) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            if (event.type == c.SDL_EVENT_QUIT) running = false;
            if (event.type == c.SDL_EVENT_KEY_DOWN and !event.key.repeat) {
                if (event.key.key == c.SDLK_ESCAPE) running = false;
                if (event.key.key == c.SDLK_SPACE) auto_rotate = !auto_rotate;
                if (event.key.key == c.SDLK_1) {
                    mode = .stay;
                    title_dirty = true;
                }
                if (event.key.key == c.SDLK_2) {
                    mode = .walk;
                    title_dirty = true;
                }
                if (event.key.key == c.SDLK_3) {
                    mode = .jump;
                    title_dirty = true;
                }

                if (event.key.scancode == c.SDL_SCANCODE_PERIOD) {
                    if (tri_limit < 12) tri_limit += 1;
                }
                if (event.key.scancode == c.SDL_SCANCODE_COMMA) {
                    if (tri_limit > 0) tri_limit -= 1;
                }

                // --- ralenti
                if (event.key.key == c.SDLK_P) {
                    paused = !paused;
                    title_dirty = true;
                }
                if (event.key.scancode == c.SDL_SCANCODE_UP and speed_idx + 1 < speeds.len) {
                    speed_idx += 1;
                    title_dirty = true;
                }
                if (event.key.scancode == c.SDL_SCANCODE_DOWN and speed_idx > 0) {
                    speed_idx -= 1;
                    title_dirty = true;
                }
                // image par image : seulement en pause 
                if (paused and event.key.key == c.SDLK_N) time += frame_step;
                if (paused and event.key.key == c.SDLK_V) time = @max(time - frame_step, 0.0);
                if (event.key.key == c.SDLK_F) {
                    wireframe = !wireframe;
                    gl.polygonMode(gl.FRONT_AND_BACK, if (wireframe) gl.LINE else gl.FILL);
                }

                if (event.key.key == c.SDLK_X) show_axes = !show_axes;

                // --- construction cube par cube
                if (event.key.key == c.SDLK_B) {
                    build_mode = !build_mode;
                    build_limit = 0;
                    build_timer = 0;
                    build.report = false;
                    title_dirty = true;
                    std.debug.print("Mode construction : {s}\n", .{if (build_mode) "active" else "desactive"});
                }
                if (build_mode and event.key.key == c.SDLK_R) {
                    build_limit = 0;
                    build_timer = 0;
                    build.report = false;
                    title_dirty = true;
                }
                // pas a pas manuel : met automatiquement en pause
                if (build_mode and event.key.key == c.SDLK_RETURN and build_limit < build.total) {
                    build_limit += 1;
                    build_timer = 0;
                    paused = true;
                    build.report = true;
                    title_dirty = true;
                }
                if (build_mode and event.key.key == c.SDLK_BACKSPACE and build_limit > 0) {
                    build_limit -= 1;
                    build_timer = 0;
                    paused = true;
                    build.report = true;
                    title_dirty = true;
                }
            }
            if (event.type == c.SDL_EVENT_MOUSE_MOTION and (event.motion.state & 1) != 0) {
                yaw += event.motion.xrel * 0.4;
                pitch = std.math.clamp(pitch + event.motion.yrel * 0.4, -89.0, 89.0);
            }
        }

        // temps écoulé (en secondes) : base de toute amination à venir
        const now = c.SDL_GetTicks();
        const dt = @as(f32, @floatFromInt(now - last_ticks)) / 1000.0;
        last_ticks = now;

        const speed = speeds[speed_idx];
        if (!paused) time += dt * speed;

        // construction automatique : un cube toutes les (1 / vitesse) secondes
        if (build_mode and !paused and build_limit < build.total) {
            build_timer += dt * speed;
            if (build_timer >= 1.0) {
                build_timer -= 1.0;
                build_limit += 1;
                build.report = true;
                title_dirty = true;
            }
        }

        // exemple : changer la longueur du torse, la tete et les bras se replacent seuls
        const keys = c.SDL_GetKeyboardState(null);
        if (keys[@intCast(c.SDL_SCANCODE_T)]) adjust(&dims.torso_h, dt);
        if (keys[@intCast(c.SDL_SCANCODE_G)]) adjust(&dims.torso_h, -dt);

        // === fenetre ===
        var w: c_int = 0;
        var h: c_int = 0;
        _ = c.SDL_GetWindowSizeInPixels(window, &w, &h);
        gl.viewport(0, 0, w, h);
        const fw: f32 = @floatFromInt(@max(w, 1));
        const fh: f32 = @floatFromInt(@max(h, 1));

        gl.clearColor(0.16, 0.18, 0.23, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const dragging = (c.SDL_GetMouseState(null, null) & c.SDL_BUTTON_LMASK) != 0;
        if (auto_rotate and !dragging) {
            yaw = @mod(yaw + constants.auto_speed * dt, 360.0);
        }

        // === caméra : on deplace le monde dans le sens inverse
        //      view = T(0,0,-d) * Rx(pitch) * Ry(yaw) * T(0,-centre,0)
        const proj = Mat4.perspective(math.radians(45.0), fw / fh, 0.1, 100.0);
        const view = Mat4.translate(0, -0.5, -constants.camera_dist)
            .mul(Mat4.rotateX(math.radians(pitch)))
            .mul(Mat4.rotateY(math.radians(yaw)))
            .mul(Mat4.translate(0, -constants.view_center_y, 0));
        renderer.begin(proj, view);
        renderer.drawAxes(Mat4.identity(), 1.5);   // оси мира в точке (0, 0, 0)

        // === le corps
        // hors mode construction, `limit` est maximal : tous les cubes sont dessines
        build.limit = if (build_mode) build_limit else std.math.maxInt(usize);
        build.seen = 0;
        const pose = anim.pose(mode, time, dims);
        var stack = math.MatrixStack.init();
        body.drawBody(renderer, &stack, dims, pose);
        build.total = build.seen; // nombre total de cubes de la scene
        build.report = false;

        _ = c.SDL_GL_SwapWindow(window);
    }
}