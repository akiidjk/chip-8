const std = @import("std");
const sdl = @import("sdl");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl_mod = b.addModule("sdl", .{
        .root_source_file = b.path("src/sdl.zig"),
        .target = target,
        .optimize = optimize,
    });

    const logging_mod = b.addModule("logging", .{
        .root_source_file = b.path("src/logging.zig"),
        .target = target,
    });

    const chip8_mod = b.addModule("chip_8", .{
        .root_source_file = b.path("src/chip8.zig"),
        .target = target,
        .imports = &.{ .{ .name = "sdl", .module = sdl_mod }, .{ .name = "logging", .module = logging_mod } },
    });

    const debug_mod = b.addModule("logging", .{ .root_source_file = b.path("src/logging.zig"), .target = target, .imports = &.{
        .{ .name = "chip_8", .module = chip8_mod },
    } });

    const exe = b.addExecutable(.{
        .name = "chip_8",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{ .{ .name = "chip_8", .module = chip8_mod }, .{ .name = "sdl", .module = sdl_mod }, .{ .name = "logging", .module = logging_mod }, .{ .name = "debug", .module = debug_mod } },
        }),
    });

    if (target.result.os.tag == .linux) {
        exe.linkSystemLibrary("SDL2");
        exe.linkLibC();
    } else {
        const sdl_dep = b.dependency("SDL", .{
            .optimize = .ReleaseFast,
            .target = target,
        });
        exe.linkLibrary(sdl_dep.artifact("SDL2"));
    }

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = chip8_mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
