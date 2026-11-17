const nanoui = @import("nanoui");
const ui = nanoui.ui;
const AppState = @import("app_state.zig").AppState;
const colors = @import("theme/colors.zig");
const topbar = @import("topbar.zig");
const timerView = @import("timer/timer_view.zig").view;
const todoView = @import("todo/todo_view.zig").view;
const statsView = @import("stats/stats_view.zig").view;
const settingsView = @import("settings/settings_view.zig").view;
const platform = @import("platform.zig");
const responsive = @import("responsive.zig");
const storage = @import("storage.zig");

/// Top-level view — the app's title bar over the routed page.
pub fn view(state: *AppState, c: *ui.Context) void {
    const t = colors.palette(state.settings.dark_mode);
    const compact = responsive.isCompact(c);
    c.theme = colors.nanouiTheme(state.settings.dark_mode);
    // Android's window has no caption of ours to reserve.
    c.title_bar_height = if (platform.is_android) 0 else topbar.height;

    const root = ui.div(c).column().sizeFull().bg(t.hex(t.bg_primary));
    defer root.end();

    topbar.view(state, c, compact);

    const safe_area = c.safe_area;
    c.safe_area.top = 0;
    defer c.safe_area = safe_area;

    const safe_content = ui.div(c).column().wFull().grow().safeArea();
    defer safe_content.end();

    {
        const content = ui.div(c)
            .column()
            .wFull()
            .grow()
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

    if (compact) topbar.mobileNavigation(state, c);

    // After the views ran: a pomodoro finished this frame is saved now.
    storage.autosave();
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
