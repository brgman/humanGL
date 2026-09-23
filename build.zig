const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.link_libc = true;
    exe_mod.linkSystemLibrary("SDL3", .{});
    exe_mod.linkSystemLibrary("GL", .{});
    // glad.c when compiling should also see its titles
    exe_mod.addIncludePath(b.path("vendor/glad/include"));

    // Compile glad.c as a normal C-file and link into our binary.
    // Flag is important: without it, Zig can swear at some
    // C-constructions inside the generated code.
    exe_mod.addCSourceFile(.{
        .file = b.path("vendor/glad/src/glad.c"),
        .flags = &.{"-std=c99"},
    });

    const exe = b.addExecutable(.{
        .name = "scop",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
