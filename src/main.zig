const std = @import("std");
const zopengl = @import("zopengl");
const sdl3 = @import("sdl3");
const gl = zopengl.bindings;
const Config = @import("Config.zig");

pub fn main(init: std.process.Init) !void {
    const argv = try std.process.Args.toSlice(init.minimal.args, init.arena.allocator());

    var config: Config = .default;
    if (argv.len == 2) {
        const parsed = try Config.parse(init.arena.allocator(), init.io, argv[1]);
        config = parsed.value;
    }

    try sdl3.init(.{ .video = true });
    defer {
        sdl3.quit(.{ .video = true });
        sdl3.shutdown();
    }

    try configureGame(config);
    try runGame(init, config);
}

fn configureGame(config: Config) !void {
    try sdl3.video.gl.setAttribute(.context_major_version, config.opengl.major_version);
    try sdl3.video.gl.setAttribute(.context_minor_version, config.opengl.minor_version);
    try sdl3.video.gl.setAttribute(.context_profile_mask, @intFromEnum(config.opengl.profile_mask));
    try sdl3.video.gl.setAttribute(.double_buffer, @intFromBool(config.opengl.double_buffer));
}

fn runGame(init: std.process.Init, config: Config) !void {
    _ = init;
    var running: bool = true;

    const window = try sdl3.video.Window.init("humanGL", config.window.width, config.window.height, .{
        .open_gl = true,
        .resizable = true,
    });
    defer window.deinit();

    const context = try sdl3.video.gl.Context.init(window);
    defer {
        context.deinit() catch {};
    }
    try context.makeCurrent(window);

    try zopengl.loadCoreProfile(
        getGlProcAddress,
        config.opengl.major_version,
        config.opengl.minor_version,
    );

    while (running) {
        while (sdl3.events.poll()) |event| {
            switch (event) {
                .quit => running = false,
                else => continue,
            }
        }

        gl.clear(gl.COLOR_BUFFER_BIT);
        gl.clearColor(
            config.app.background.r,
            config.app.background.g,
            config.app.background.b,
            config.app.background.a,
        );
        try sdl3.video.gl.swapWindow(window);
    }
}

fn getGlProcAddress(name: [*:0]const u8) callconv(.c) ?*const anyopaque {
    return sdl3.video.gl.getProcAddress(std.mem.span(name));
}
