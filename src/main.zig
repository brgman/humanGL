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
    defer c.SDL_Quit();

    // 2. Create window
    // Inn SDL3 SDL_CreateWindow no longer takes a positin x,y
    // windows is set by default
    const window = c.SDL_CreateWindow(
        "HumanGL",
        800,
        600,
        c.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.debug.print("SDL_CreateWindow failed: {s}\n", .{c.SDL_GetError()});
        return error.WindowCreationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    // 3. Main loop
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
