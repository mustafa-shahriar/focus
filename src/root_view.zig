const nanoui = @import("nanoui");
const ui = nanoui.ui;
const AppState = @import("app_state.zig").AppState;
const colors = @import("theme/colors.zig");
const sidebarView = @import("sidebar/sidebar_view.zig").view;
const timerView = @import("timer/timer_view.zig").view;
const todoView = @import("todo/todo_view.zig").view;
const statsView = @import("stats/stats_view.zig").view;
const settingsView = @import("settings/settings_view.zig").view;

/// Top-level view — renders sidebar + routed content.
pub fn view(state: *AppState, c: *ui.Context) void {
    const t = colors.palette(state.settings.dark_mode);
    c.theme = colors.nanouiTheme(state.settings.dark_mode);

    const root = ui.div(c).row().sizeFull().bg(t.hex(t.bg_primary));
    defer root.end();

    sidebarView(state, c);

    const content = ui.div(c)
        .column()
        .grow()
        .hFull()
        .bg(t.hex(t.bg_primary))
        .gradient(t.hex(t.bg_secondary));
    defer content.end();

    ambient(c, t);

    switch (state.current_page) {
        .timer => timerView(state, c),
        .todos => todoView(state, c),
        .stats => statsView(state, c),
        .settings => settingsView(state, c),
    }
}

/// A few very soft color clouds behind the content: depth without noise.
fn ambient(c: *ui.Context, t: colors.Palette) void {
    const cv = ui.canvas(c, .{
        .absolute = true,
        .width = .fill,
        .height = .fill,
    });
    if (cv.size.w <= 0 or cv.size.h <= 0) return;

    const w = cv.size.w;
    const h = cv.size.h;

    softCloud(cv, .{ .x = w * 0.92, .y = h * 0.04 }, w * 0.42, t.hex(t.accent), 0.006);
    softCloud(cv, .{ .x = w * 0.08, .y = h * 1.02 }, w * 0.48, t.hex(t.accent_blue), 0.0045);
    softCloud(cv, .{ .x = w * 0.58, .y = h * 0.62 }, w * 0.36, t.hex(t.accent_warm), 0.0035);
}

fn softCloud(cv: *ui.Canvas, center: ui.Point, radius: f32, color: ui.Color, alpha: f32) void {
    const steps: usize = 22;
    var i: usize = steps;
    while (i > 0) : (i -= 1) {
        const r = radius * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(steps));
        cv.circle(center, r, color.alpha(alpha));
    }
}
