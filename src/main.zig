const std = @import("std");
const nanoui = @import("nanoui");
const AppState = @import("app_state.zig").AppState;
const rootView = @import("root_view.zig").view;
const colors = @import("theme/colors.zig");

pub fn main(init: std.process.Init) !void {
    const app = try nanoui.App.create(init, .{
        .name = "Pomodoro Focus",
    });
    defer app.destroy();

    var state = AppState{};

    _ = try app.newWindow(.{
        .title = "Pomodoro Focus",
        .width = 980,
        .height = 680,
        .theme = colors.nanouiTheme(state.settings.dark_mode),
        .content = .{ .view = .init(&state, rootView) },
    });

    try app.run();
}
