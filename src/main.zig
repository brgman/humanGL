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

    try configureSdlContext(config);
}

fn configureSdlContext(config: Config) !void {
    try sdl3.video.gl.setAttribute(.context_major_version, config.opengl.major_version);
    try sdl3.video.gl.setAttribute(.context_minor_version, config.opengl.minor_version);
    try sdl3.video.gl.setAttribute(.context_profile_mask, @intFromEnum(config.opengl.profile_mask));
    try sdl3.video.gl.setAttribute(.double_buffer, @intFromBool(config.opengl.double_buffer));
}
