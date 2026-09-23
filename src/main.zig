// Скачай GLAD (https://glad.dav1d.de), выбери: Language = C, gl = Version 4.0, Profile = Core, галочка "Generate a loader".

const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub fn main() !void {
    // 1. Initialisation of SDL: sub sustem for video
    // In SDL3 function of initialisation returned bool (true = success),
    // for example in SDL2 - 0 is success
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.debug.print("SDL_Init failed: {s}\n", .{c.SDL_GetError()});
        return error.SDLInitFailed;
    }

    // modern OpenGL without obsolete things like glBegin/glEnd, matrix stack, etc
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE);
    // specifically version 4.0, minimum on assignment
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 0);
    // important for animation without flickering
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
    // deep of Z-buffer is needed for the correct render 3D
    // reserve a 24-bit depth buffer per pixel so that OpenGL can decide which facets others are overlapping (need for depth test, GL_DEPTH_TEST).
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 24);

    defer _ = c.SDL_Quit();

    // 2. Create window
    // Inn SDL3 SDL_CreateWindow no longer takes a positin x,y
    // windows is set by default
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

    // 3. Make the OpenGL context
    const gl_context = c.SDL_GL_CreateContext(window) orelse {
        std.debug.print("SDL_GL_CreateContext failed: {s}\n", .{c.SDL_GetError()});
        return error.GLContextCreatingFailed;
    };
    defer _ = c.SDL_GL_DestroyContext(gl_context);

    // 4. Main loop
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
    }
}
