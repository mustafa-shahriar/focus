const std = @import("std");

pub fn build(b: *std.Build) void {
    // Pass the selected target to both the app and nanoui for the matching platform backend.
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

    if (target.result.abi.isAndroid()) {
        const android = @import("nanoui").android;
        const lib = android.library(b, .{
            .name = "focus",
            .root_module = root_mod,
            .nanoui = nanoui_mod,
        });
        const apk_options: android.Options = .{
            .name = "Pomodoro Focus",
            .id = "com.example.pomodorofocus",
            .version = @import("build.zig.zon").version,
            .target_api = 34,
            .icon = b.path("assets/icon.png"),
            .permissions = &.{},
        };
        const apk = android.apk(b, lib, apk_options);
        const install_apk = b.addInstallFileWithDir(apk, .prefix, "android/focus.apk");
        b.getInstallStep().dependOn(&install_apk.step);
        b.step("apk", "Build and install the Android APK").dependOn(&install_apk.step);
    } else {
        const exe = b.addExecutable(.{
            .name = "focus",
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
}
