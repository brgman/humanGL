const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zopengl = b.dependency("zopengl", .{});
    const sdl3 = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zopengl", .module = zopengl.module("root") },
            .{ .name = "sdl3", .module = sdl3.module("sdl3") },
        },
    });

    // exe_mod.addImport("sdl3", sdl3.module("sdl3"));
    //
    const exe = b.addExecutable(.{
        .name = "humanGL",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);

    const exe_check = b.addExecutable(.{
        .name = "humanGL",
        .root_module = exe_mod,
    });

    const check_step = b.step("check", "Run checks for zls");
    check_step.dependOn(&exe_check.step);
}
