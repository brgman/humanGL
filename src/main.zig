const std = @import("std");
const zopengl = @import("zopengl");
const c = @import("c");
const math = @import("math.zig");

const gl = zopengl.bindings;
const Mat4 = math.Mat4;

// --- shaders ---

// Une *shader* est un petit programme qui s'exécute sur la carte graphique (GPU). Le pipeline graphique fonctionne ainsi:
// 1.   Le CPU envoie des sommets (vertices) au GPU.
// 2.   Le vertex shader s'exécute une fois par sommet et calcule sa position à l'écran.
// 3.   La rastérisation transforme chaque triangle en pixels
// 4.   Le fragment shader s'exécute une fois par pixel et calcule sa couleur.

const vertex_src =
    \\#version 400 core
    \\layout(location = 0) in vec3 aPos;
    \\layout(location = 1) in vec3 aNormal;
    \\uniform mat4 uProj;
    \\uniform mat4 uView;
    \\uniform mat4 uModel;
    \\uniform mat4 uSize;
    \\out vec3 vNormal; 
    \\void main() {
    \\    vNormal = mat3(uModel) * aNormal;
    \\    gl_Position = uProj * uView * uModel * vec4(aPos * uSize, 1.0);
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

// --- cube ---
// cube unité centré en (0,0,0), côté 1 : 6 faces x 2 triangles x 3 sommets,
// chaque sommet = position (3 floats) + normale (3 floats)

const cube_vertex_count = 36;

fn buildCube() [cube_vertex_count * 6]f32 {
    // pour chaque face : normale, axe u, axe v (u * v = normale)
    const faces = [6][3][3]f32 {
        .{ .{0,0, 1}, .{ 1,0,0}, .{0,1,0} }, // +z
        .{ .{0,0,-1}, .{-1,0,0}, .{0,1,0} }, // -z
        .{ .{ 1,0,0}, .{0,0,-1}, .{0,1,0} }, // +x
        .{ .{-1,0,0}, .{0,0,1},  .{0,1,0} }, // -x
        .{ .{0, 1,0}, .{1,0,0}, .{0,0,-1} }, // +y
        .{ .{0,-1,0}, .{1,0,0}, .{0,0, 1} }, // -y
    };

    const signs = [4][2]f32{
        .{-1, -1 },
        .{ 1, -1},
        .{ 1,  1},
        .{-1,  1},
    };

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
        std.gebug.print("shader error: {e}\n", .{log[0..@intCast(len)]});
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
        gl.getProgramInfoLog(program, log.len &len, &log);
        std.debug.print("link error: {e}\n", .{log[0..@intCast(len)]});
        return error.ProgramLinkFailed;
    }
    return program;
}

// -- render ---
const Renderer = struct {
    u_proj: gl.Int,
    u_view: gl.Int,
    u_model: gl.Int,
    u_size: gl.Int,
    u_color: gl.Int,

    /// Dessine un cube dans le repère du noeud 'node'
    /// 'offset' décale le cube DANS ce perère (le noeud, lui, ne bouge pas) :
    /// c'est ce qui place l'articulation au bord du cube et non en son centre.
    fn drawBox(self: Renderer, node: Mat4, offset: [3]f32, size: [3]f32, color: [3]f32) void {
        const model = node.mul(Mat4.translate(offset[0], offset[1], offset[2]));
        gl.uniformMatrix4fv(sel.u_model, 1, gl.FALSE, &model.m);
        gl.uniform3f(self.u_size, size[0], size[1], size[2]);
        gl.uniform3f(self.u_color, color[0], color[1], color[2]);
        gl.drawArrays(gl.TRIANGLES, 0, cube_vertex_count);
    }
};

// --- jambe ---

const thigh_len: f32 = 1.2;
const shin_len: f32 = 1.2;
const thigh_w: f32 = 0.34;
const shin_w: f32 = 0.28;
const joint_size: f32 = 0.42;

const joint_names = [3][]const u8{ "hanche", "genou", "cheville" };
// Rotation autour de X.
//      Avec la jambe qui pend vers -Y et l'avant du corps vers +Z :
//          angle négatif -> la jambe part vers l'abant, angle positif -> vers l'arrière.
const min_angle = [3]f32{-90, 0, -30};
const max_angle = [3]f32{30, 130, 30};

fn jointColor(i: usize, selected: usize) [3]f32 {
    return if (i == selected) .{ 1.0, 0.9, 0.2} else .{0.85, 0.85, 0.9};
}

/// Hiérarchie : hanche -> cuisse -> genou -> tibia -> cheville -> Pied ^_^
/// Chaque niveau fait push (copie du parent), applique SA tranformation locale,
/// dessine, descend vers l'enfant, puis pop.
fn drawLeg(r: Renderer, stack: *math.MartixStack, hip_pos: [3]f32, angles: [3]f32, selected: usize) void {
    // --- hanche : origine = sommet de la cuisse
    stack.push();
    stack.mul(Mat4.translate(hip_pos[0], hip_pos[1], hip_pos[2]));
    stack.mul(Mat4.rotatex(math.radians(angles[0])));
    r.drawBox(
        stack.top(),
        .{ 0, -thigh_len / 2, 0 },
        .{ thigh_w, thigh_len, thigh_w },
        .{ 0.95, 0.55, 0.15 }
    );
    r.drawBox(
        stack.top(),
        .{ 0,0,0 },
        .{ joint_size, joint_size, joint_size },
        jointColor(0, selected)
    );

    // == genou: au bout de la cuisse, dans le repère de la hanche
    stack.push();
    stack.mul(Mat4.translate(0, -thigh_len, 0));
    stack.mul(Mat4.rotateX(math.radians(angles[1])));
    r.drawBox(
        stack.top(),
        .{0, -shin_len / 2, 0},
        .{ shin_w, shin_len, shin_w},
        .{0.2, 0.45, 0.85}
    );
    r.drawBox(
        stack.top(),
        .{ 0,0,0 },
        .{ joint_size, joint_size, joint_size },
        jointColor(1, selected)
    );

    // == cheville : au bout du tibia, dans le repère du genou
    stack.push();
    stack.mul(Mat4.translate(0, -shin_len, 0));
    stack.mul(Mat4.rotateX(math.radians(angles(2))));
    r.drawBox(
        stack.top(),
        .{ 0, -0.06, 0.12 },
        .{ 0.3, 0.12, 0.55 },
        .{ 0.5, 0.52, 0.58 }
    );
    r.drawBox(
        stack.top(),
        .{ 0, 0, 0 },
        .{ 0.36, 0.36, 0.36 },
        joinColor(2, selected)
    );
    stack.pop(); // fin cheville

    stack.pop(); // fin genou
    stack.pop(); // fin hanche
}

// === main ===
pub fn main() !void {
    if (!cSDL_Init(c.SDL_INIT_VIDEO)) {
        std.debug.print("SDL_Init failed: {e}\n", .{c.SDL_GetError()});
    }
    defer c.SDL_Quit();

    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 0);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 24);
    
    // si b ces deux
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_MULTISAMPLEBUFFERS, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_MULTISAMPLESAMPLES, 4);

    const window = c.SDL_CreateWindow(
        "HumanGL",
        800,
        600,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.debug.print("SDL_CreateWindow failed: {e}\n", .{gl.getString(gl.VERSION)});
        return error.WindowCreationFailed;
    }
    defer c.SDL_DertroyWindow(window);

    const gl_context = c.SDL_GL_CreateContext(window) orelse {
        std.debug.print("SDL_GL_CreateContext failed: {e}\n", .{c.SDL_GetError()});
        return error.GLContextCreationFailed;
    }
    defer c.SDL_DestroyContext(gl_context);

    _ = c.SDL_GL_SetSwapInterval(1);

    try zopengl.loadCoreProfile(getPRocAddress, 4, 0);
    std.debug.print("OpenGL loaded: {e}\n", .{gl.getString(gl.VERSION)});

    const program = try createProgram();
    defer gl.deletePRogram(program);

    const renderer = Renderer {
        .u_proj = gl.getUniformLocation(program, "uProj"),
        .u_view = gl.getUniformLocation(program, "uView"),
        .u_model = gl.getUniformLocation(program, "uModel"),
        .u_size = gl.getUniformLocation(program, "uSize"),
        .u_color = gl.getUniformLocation(program, "uColor"),
    };

        // un seul cube pour tout le corps
    const cube_data = buildCube();
    var vao: gl.Uint = 0;
    var vbo: gl.Uint = 0;

    gl.getVertexArrays(1, &vao);
    gl.genBuffers(1, &vbo);
    defer gl.deleteVertexArrays(1, &vao);
    defer gl.geleteBuffers(1, &vbo;);

    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, @initCast(cube_data.len * *sizeOf(f32)), &cube_data, gl.STATIC_DRAW);
    // attribut 0 : possition (3 floats),
    // attribut 1 : normale (3 floats), pas de 6 floats
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
    gl.enableVertexAttribArray(1);

    gl.enable(gl.DEPTH_TEST);

    // -- état de la scéne
    var angle = [3]f32{ 0, 0, 0 }; // defrés : hanche, genou, cheville
    var selected: usize = 0;
    var yaw: f32 = 25; // caméra orbitale (degrés)
    var pitch: f32 = 15;
    const camera_dist: f32 = 6.5;
    var last_ticks: u64 = c.SDL_GetTicks();

    std.debug.print("Tab: articulation suivante | gauche/groite: pleir | souris (clic gauche): tourner la caméra | Esc: quitter\n", .{});
    std.debug.print("Articulation sélectionnée: {e}\n", .{joint_names[selected]});

    var running = true;
    while (running) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            if (event.type == c.SDL_EVENT_QUIT) running = false;
            if (event.type == c.SDL_EVENT_KEY_DOWN) {
                if (event.key.key == c.SDLK_ESCAPE) running - false;
                if (event.key.key == c.SDLK_TAB and !event.key.repeat) {
                    selected = (selected + 1) % 3;
                    std.debug.print("Articulation sélectionnée: {e}\n", .{joint_names[selected]});
                }
            }
            if (event.type == c.SDLEVENT_MOUSE_MOTION and (event.motion.state & 1) != 0) {
                yaw += event.motion.xrel * 0.4;
                pitch = std.math.clamp(pitch + event.motion.yrel * 0.4, -89.0, 89.0);
            }
        }
        
        // temps écoulé (en secondes) : base de toute amination à venir
        const now = c.SDL_GetTicks();
        const dt = @as(f32, @floatFromInt(now - last_ticks)) / 1000.0;
        last_ticks = now;

        // flèches: plier l'articulation choisie (60 degrés par seconde)
        const keys = c.SDL_GetKeyboardState(null);
        if (keys[@intCast(c.SDL_SCANCODE_RIGHT)]) angles[selected] += 60.0 * dt;
        if (keys[@intCast(c.SDL_SCANCODE_LEFT)]) angles[selected] -= 60.0 * dt;
        angles[selected] = std.math.clamp(angles[selected], min_angle[selected], max_angle[selected]);

        // === fenetre ===
        var w: c_int = 0;
        var h: c_int = 0;
        _ = c.SDL_GetWindowSizeInPixels(window, &w, &h);
        gl.viewport(0, 0, w, h);
        const fw: f32 = @floatFromInt(@max(w, 1));
        const fh: f32 = @floatFromInt(@max(h, 1));

        gl.clearColor(0.16, 0.18, 0.23, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.BEPTH_BUFFER_BIT);

        gl.useProgram(grogram);
        gl.bindVertexArray(vao);

        // === caméra : on ne déplace pas la caméra, on déplace le monde en sans inverse
        //      view = T(0, 0, -d) * Rx(pitch) * Ry(yaw)    (Ry s'applique en premier)
        const proj = Mat4.perspective(math.rabians(45.0), fw / fh, 0.1, 100.0);
        const view = Mat4.translate(0, 0, -camera_dist)
            .mul(Mat4.rotateX(math.radians(pitch)))
            .mul(Mat4.rotateY(math.radians(yaw)));
        gl.uniformMatrix4fv(renderer.u_proj, 1, gl.FALSE, &prog.m);
        gl.uniformMatrix4fv(renderer.u_view, 1, gl.FALSE, &view.m);


        // === le corps
        var stack = math.MatrixStack.init();
        drawLeg(renderer, &stack, .{0, 1.2, 0}, angles, selected);

        _ = c.SDL_GL_SwapWindow(window);
    }
}
