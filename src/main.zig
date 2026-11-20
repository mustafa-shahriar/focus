const std = @import("std");
const nanoui = @import("nanoui");
const AppState = @import("app_state.zig").AppState;
const rootView = @import("root_view.zig").view;
const colors = @import("theme/colors.zig");
const platform = @import("platform.zig");
const shell = @import("shell.zig");
const storage = @import("storage.zig");
const updates = @import("updates.zig");

pub fn main(init: std.process.Init) !void {
    // A staged update is run with `--version` before it is installed.
    if (try printVersionIfAsked(init)) return;

    const app = try nanoui.App.create(init, .{
        .name = "Pomodoro Focus",
    });
    defer app.destroy();

    // Before the window exists, so it opens on the saved page and theme.
    var state = AppState{};
    storage.start(init, &state);
    defer storage.stop();

    const window = try app.newWindow(.{
        .title = "Pomodoro Focus",
        .width = 980,
        .height = 680,
        .min_width = 380,
        .min_height = 480,
        .full_bleed = platform.is_android,
        .title_bar = .hidden,
        .theme = colors.nanouiTheme(state.settings.dark_mode),
        .on_close = .{ .ctx = @ptrCast(&state), .func = onClose },
        .content = .{ .view = .init(&state, rootView) },
    });
    shell.window = window;
    defer shell.window = null;

    updates.start(init, app);
    defer updates.stop();

    try app.run();
}

/// Prints the version and returns true when `--version` (or `-v`) is the
/// first argument: the desktop updater runs a downloaded program with it
/// to check that it is the release it claims to be.
fn printVersionIfAsked(init: std.process.Init) !bool {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next(); // the program's own name
    const first = args.next() orelse return false;
    if (!std.mem.eql(u8, first, "--version") and !std.mem.eql(u8, first, "-v")) return false;
    try std.Io.File.stdout().writeStreamingAll(init.io, "Pomodoro Focus " ++ updates.version ++ "\n");
    return true;
}

/// Write the latest state on the way out.
fn onClose(_: *anyopaque, _: *nanoui.Window) void {
    storage.saveNow();
}

// The test step only sees tests in the root file and in what its test
// blocks reference, so name the modules whose tests should run.
test {
    _ = @import("app_state.zig");
    _ = @import("storage.zig");
    _ = @import("updates.zig");
    _ = @import("todo/todo_state.zig");
    _ = @import("timer/timer_state.zig");
    _ = @import("stats/stats_state.zig");
    _ = @import("settings/settings_state.zig");
}
