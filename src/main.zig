const std = @import("std");
const nanoui = @import("nanoui");
const AppState = @import("app_state.zig").AppState;
const rootView = @import("root_view.zig").view;
const colors = @import("theme/colors.zig");
const shell = @import("shell.zig");

pub fn main(init: std.process.Init) !void {
    const app = try nanoui.App.create(init, .{
        .name = "Pomodoro Focus",
    });
    defer app.destroy();

    var state = AppState{};

    const window = try app.newWindow(.{
        .title = "Pomodoro Focus",
        .width = 980,
        .height = 680,
        .min_width = 760,
        .min_height = 600,
        .title_bar = .hidden,
        .theme = colors.nanouiTheme(state.settings.dark_mode),
        .content = .{ .view = .init(&state, rootView) },
    });
    shell.window = window;
    defer shell.window = null;

    {
        const cs = window.contentSize();
        std.debug.print("DBG content size {d}x{d}\n", .{ cs[0], cs[1] });
    }

    try app.run();
}
