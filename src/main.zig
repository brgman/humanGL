const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

const GLADloadproc = ?*const fn (name: [*c]const u8) callconv(.c) ?*anyopaque;
extern fn gladLoadGLLoader(load: GLADloadproc) c_int;
extern fn glGetString(name: c_uint) [*c]const u8;
extern fn glClearColor(r: f32, g: f32, b: f32, a: f32) void;
extern fn glClear(mask: c_uint) void;

const GL_VERSION: c_uint = 0x1F02;
const GL_COLOR_BUFFER_BIT: c_uint = 0x00004000;
const GL_DEPTH_BUFFER_BIT: c_uint = 0x00000100;

fn glGetProcAddressWrapper(name: [*c]const u8) callconv(.c) ?*anyopaque {
    return @ptrCast(c.SDL_GL_GetProcAddress(name));
}

pub fn main() !void {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.debug.print("SDL_Init failed: {s}\n", .{c.SDL_GetError()});
        return error.SDLInitFailed;
    }

    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 0);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 24);

    defer _ = c.SDL_Quit();

    const window = c.SDL_CreateWindow(
        "HumanGL",
        800,
        600,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.debug.print("SDL_CreateWindow failed: {s}\n", .{c.SDL_GetError()});
        return error.WindowCreationFailed;
    };
    defer _ = c.SDL_DestroyWindow(window);

    const gl_context = c.SDL_GL_CreateContext(window) orelse {
        std.debug.print("SDL_GL_CreateContext failed: {s}\n", .{c.SDL_GetError()});
        return error.GLContextCreatingFailed;
    };
    defer _ = c.SDL_GL_DestroyContext(gl_context);

    const loaded = gladLoadGLLoader(&glGetProcAddressWrapper);
    if (loaded == 0) {
        std.debug.print("gladLoadGLLoader failed\n", .{});
        return error.GLADLoadFailed;
    }

    std.debug.print("OpenGL loaded: {s}\n", .{glGetString(GL_VERSION)});

    var running = true;
    while (running) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            if (event.type == c.SDL_EVENT_QUIT) {
                running = false;
            }
            if (event.type == c.SDL_EVENT_KEY_DOWN and
                event.key.key == c.SDLK_ESCAPE)
            {
                running = false;
            }
        }

        glClearColor(0.1, 0.1, 0.15, 1.0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        _ = c.SDL_GL_SwapWindow(window);
    }
}
