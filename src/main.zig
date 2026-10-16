const std = @import("std");
const zopengl = @import("zopengl");
const c = @import("c");

const gl = zopengl.bindings;

// Une *shader* est un petit programme qui s'exécute sur la carte graphique (GPU). Le pipeline graphique fonctionne ainsi:
// 1.   Le CPU envoie des sommets (vertices) au GPU.
// 2.   Le vertex shader s'exécute une fois par sommet et calcule sa position à l'écran.
// 3.   La rastérisation transforme chaque triangle en pixels
// 4.   Le fragment shader s'exécute une fois par pixel et calcule sa couleur.

const vertex_src =
    \\#version 400 core
    \\layout(location = 0) in vec2 aPos;
    \\uniform vec2 uScale;
    \\void main() {
    \\    gl_Position = vec4(aPos * uScale, 0.0, 1.0);
    \\}
;

const fragment_src =
    \\#version 400 core
    \\uniform vec4 uColor;
    \\out vec4 FragColor;
    \\void main() {
    \\    FragColor = uColor;
    \\}
;

// Geometry in normalized units: 1.0 = half of the shorter window side.
const ring_segments = 16;                       // l'anneau est un polygone de 16 côtés
const ring_outer: f32 = 0.8;                    // les rayons extérieur et intérieur. Leur différence donne l'épaisseur de l'anneau
const ring_inner: f32 = 0.597;
// Triangle vertices lie slightly under the ring, so they touch its inner edge.
const tri_radius: f32 = 0.606;                  // les pointes du trianglepassent dons dégèrement sous l'anneau, et le triangle paraît parfairement inscrit
const tri_floats = 6;                           // 3 sommets pour 2 nombres (x, y)
const ring_floats = (ring_segments + 1) * 4;    // pour chaque angle, il y a 2 sommets (exrérieur et intérieur) donc 4 nombres

// Les fonctions OpenGL ne sont pas liées à la compilation.
// Le pilote graphique les fourint à l'exécution
//      _zopenlg_ appelle cette fonction pour chaque fonction OpenGL (glClear, glDrawArrays, etc.).
//      SDL renvoie l'adresse mémoire de chacune.
//      callconv(.c) - la fonction doi t respecter la convention d'appel du C.
fn getProcAddress(name: [*:0]const u8) callconv(.c) ?*const anyopaque {
    return @ptrCast(c.SDL_GL_GetProcAddress(name));
}

// La fonction renvoie soit un identifiant, soit une erreur (type "error union")
fn compileShader(kind: gl.Enum, src: [*:0]const u8) !gl.Uint {
    const shader = gl.createShader(kind);     // cree une shader vide, de type  vertex ou fragment.
    gl.shaderSource(shader, 1, &[_][*:0]const u8{src}, null);   // donne le code source. 1 = une seule chaîne.
    gl.compileShader(shader);       // le pilote compile le code.

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

// Un programme est l’assemblage du vertex shader et du fragment shader. attachShader les attache, linkProgram les relie
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

// SDL et le contexte OpenGL
//      SDL_Init initialise le sous-système vidéo.
//      defer : cette ligne s’exécute à la sortie de la fonction, quoi qu’il arrive. Le nettoyage est donc écrit juste à côté de l’initialisation.

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
    // Smooth edges
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

    const program = try createProgram();
    defer gl.deleteProgram(program);
    const u_color = gl.getUniformLocation(program, "uColor");
    const u_scale = gl.getUniformLocation(program, "uScale");

    // One buffer: 3 triangle vertices first, then the ring as a triangle strip.
    var vertices: [tri_floats + ring_floats]f32 = undefined;

    const cos30: f32 = @cos(std.math.pi / 6.0);
    vertices[0] = 0.0;
    vertices[1] = tri_radius;
    vertices[2] = tri_radius * cos30;
    vertices[3] = -tri_radius * 0.5;
    vertices[4] = -tri_radius * cos30;
    vertices[5] = -tri_radius * 0.5;

    var i: usize = 0;
    while (i <= ring_segments) : (i += 1) {
        const a = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / ring_segments;
        const cs = @cos(a);
        const sn = @sin(a);
        const base = tri_floats + i * 4;
        vertices[base + 0] = cs * ring_outer;
        vertices[base + 1] = sn * ring_outer;
        vertices[base + 2] = cs * ring_inner;
        vertices[base + 3] = sn * ring_inner;
    }

    // VBO (Vertex Buffer Object)   : une tampon dans le mémoire du GPU qui contient les données des sommets.
    // VAO (Vertex Array Object)    : une "dossier" qui mémorise comment lire ces données. Il retient le VBO utilisé et le fornat des attributs.
    
    var vao: gl.Uint = 0;
    var vbo: gl.Uint = 0;
    gl.genVertexArrays(1, &vao);
    gl.genBuffers(1, &vbo);
    defer gl.deleteVertexArrays(1, &vao); // les détruiront à la fin
    defer gl.deleteBuffers(1, &vbo);

    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        @intCast(vertices.len * @sizeOf(f32)),
        &vertices,
        gl.STATIC_DRAW,
    );
    gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);

    var running = true;
    while (running) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            if (event.type == c.SDL_EVENT_QUIT) running = false;
            if (event.type == c.SDL_EVENT_KEY_DOWN and event.key.key == c.SDLK_ESCAPE)
                running = false;
        }

        var w: c_int = 0;
        var h: c_int = 0;
        _ = c.SDL_GetWindowSizeInPixels(window, &w, &h);
        gl.viewport(0, 0, w, h);

        // Keep the circle round on any window shape.
        const fw: f32 = @floatFromInt(@max(w, 1));
        const fh: f32 = @floatFromInt(@max(h, 1));
        const sx: f32 = if (fw > fh) fh / fw else 1.0;
        const sy: f32 = if (fh > fw) fw / fh else 1.0;

        // Background: gray #b9bdc3
        gl.clearColor(0.725, 0.741, 0.765, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        gl.useProgram(program);
        gl.uniform2f(u_scale, sx, sy);
        gl.bindVertexArray(vao);

        // Orange triangle #f28c28
        gl.uniform4f(u_color, 0.949, 0.549, 0.157, 1.0);
        gl.drawArrays(gl.TRIANGLES, 0, 3);

        // Dark blue ring #0f2a5c
        gl.uniform4f(u_color, 0.059, 0.165, 0.361, 1.0);
        gl.drawArrays(gl.TRIANGLE_STRIP, 3, (ring_segments + 1) * 2);

        _ = c.SDL_GL_SwapWindow(window);
    }
}
