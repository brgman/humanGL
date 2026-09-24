const std = @import("std");
const zopengl = @import("zopengl");
const sdl3 = @import("sdl3");

pub fn main() !void {
    defer sdl3.shutdown();

    const init_flags = sdl3.InitFlags{ .video = true };
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    try sdl3.video.gl.setAttribute(.context_major_version, 4);
    try sdl3.video.gl.setAttribute(.context_minor_version, 0);
    try sdl3.video.gl.setAttribute(.context_profile_mask, @intFromEnum(sdl3.video.gl.Profile.core));
    try sdl3.video.gl.setAttribute(.double_buffer, 1);

    const window = try sdl3.video.Window.init("humanGL", 800, 600, .{ .open_gl = true });
    defer window.deinit();

    const context = try sdl3.video.gl.Context.init(window);
    defer context.deinit() catch {};

    try zopengl.loadCoreProfile(getProcAddress, 4, 0);

    const gl = zopengl.bindings;

    var running = true;
    while (running) {
        while (sdl3.events.poll()) |event| switch (event) {
            .quit, .terminating => running = false,
            else => {},
        };

        const clear_color: [4]f32 = .{ 0.2, 0.4, 0.8, 1.0 };
        gl.clearBufferfv(gl.COLOR, 0, &clear_color);
        try sdl3.video.gl.swapWindow(window);
    }
}

fn getProcAddress(name: [*:0]const u8) callconv(.c) ?*const anyopaque {
    return sdl3.video.gl.getProcAddress(std.mem.span(name));
}
