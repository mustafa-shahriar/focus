const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const nanoui_dep = b.dependency("nanoui", .{
        .target = target,
        .optimize = optimize,
    });

    const nanoui_mod = nanoui_dep.module("nanoui");

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "nanoui", .module = nanoui_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "pomodoro",
        .root_module = root_mod,
    });

    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
    const run_step = b.step("run", "Run the Pomodoro app");
    run_step.dependOn(&run_cmd.step);

    // Test step — test the state modules (no nanoui UI needed for logic tests)
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "nanoui", .module = nanoui_mod },
        },
    });
    const unit_tests = b.addTest(.{ .root_module = test_mod });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
