const std = @import("std");
const zopengl = @import("zopengl");
const sdl3 = @import("sdl3");
const gl = zopengl.bindings;
const mem = std.mem;
const Io = std.Io;
const json = std.json;
pub const Config = @This();

window: struct {
    width: u32 = 800,
    height: u32 = 600,
},

opengl: struct {
    major_version: u32 = 4,
    minor_version: u32 = 0,
    profile_mask: sdl3.video.gl.Profile = .core,
    double_buffer: bool = true,
},

pub const default: Config = .{
    .window = .{
        .width = 800,
        .height = 600,
    },
    .opengl = .{
        .major_version = 4,
        .minor_version = 0,
        .profile_mask = .core,
        .double_buffer = true,
    },
};

pub fn parse(allocator: mem.Allocator, io: std.Io, file_path: []const u8) !json.Parsed(Config) {
    var file = try Io.Dir.cwd().openFile(io, file_path, .{ .mode = .read_only });
    defer file.close(io);
    const stats = try file.stat(io);

    var file_buffer: [128]u8 = undefined;
    var file_reader: Io.File.Reader = .init(file, io, &file_buffer);
    const reader: *Io.Reader = &file_reader.interface;

    const file_content = try reader.readAlloc(allocator, stats.size);
    defer allocator.free(file_content);

    return try json.parseFromSlice(Config, allocator, file_content, .{ .allocate = .alloc_always });
}

pub fn format(
    self: @This(),
    writer: *std.Io.Writer,
) std.Io.Writer.Error!void {
    try json.Stringify.value(self, .{ .whitespace = .indent_4 }, writer);
}
