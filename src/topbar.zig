/// The app's own title bar: the brand, the page tabs and the window controls,
/// drawn in the band Windows otherwise keeps for its caption.
const nanoui = @import("nanoui");
const std = @import("std");
const ui = nanoui.ui;
const AppState = @import("app_state.zig").AppState;
const colors = @import("theme/colors.zig");
const shell = @import("shell.zig");

pub const height: f32 = 50;
const mobile_nav_height: f32 = 64;

const NavItem = struct {
    page: AppState.Page,
    label: []const u8,
    icon: []const u8,
};

const nav_items = [_]NavItem{
    .{ .page = .timer, .label = "Focus", .icon = "gauge.with.dots.needle.33percent" },
    .{ .page = .todos, .label = "Tasks", .icon = "checklist" },
    .{ .page = .stats, .label = "Insights", .icon = "chart.bar.xaxis" },
    .{ .page = .settings, .label = "Settings", .icon = "gearshape" },
};

pub fn view(state: *AppState, c: *ui.Context, compact: bool) void {
    const t = colors.palette(state.settings.dark_mode);

    const bar = ui.div(c)
        .column()
        .wFull()
        .h(height)
        .bg(t.hex(t.bg_sidebar))
        .gradient(t.hex(t.bg_sidebar_end));
    defer bar.end();

    {
        const row = ui.div(c).row().wFull().grow().pl(10).gap(5).itemsCenter();
        if (!compact) row.c.node(row.index).style.window_drag = true;
        defer row.end();

        brand(c, t);
        if (compact) {
            ui.spacer(c);
            themeButton(state, c, t, true);
        } else {
            verticalRule(c, t);
            tabs(state, c, t);
            ui.spacer(c);
            //themeButton(state, c, t);
            windowControls(c, t);
        }
    }

    {
        const edge = ui.div(c).wFull().h(1).bg(t.hex(t.sidebar_line));
        defer edge.end();
    }
}

pub fn mobileNavigation(state: *AppState, c: *ui.Context) void {
    const t = colors.palette(state.settings.dark_mode);
    const bar = ui.div(c)
        .row()
        .wFull()
        .h(mobile_nav_height)
        .itemsStretch()
        .bg(t.hex(t.bg_sidebar))
        .border(t.hex(t.sidebar_line));
    defer bar.end();

    for (nav_items) |item| {
        const active = state.current_page == item.page;
        const tab = ui.div(c)
            .column()
            .grow()
            .hFull()
            .gap(4)
            .itemsCenter()
            .justifyCenter()
            .hover(ui.Color.white.alpha(0.08));
        defer tab.end();
        if (tab.clicked()) state.current_page = item.page;

        ui.icon(c, item.icon, .{
            .size = 19,
            .weight = if (active) .semibold else .regular,
            .color = if (active) t.hex(t.accent) else t.hex(t.sidebar_muted),
        });
        ui.text(c, item.label, .{
            .size = 10,
            .weight = if (active) .semibold else .medium,
            .color = if (active) t.hex(t.sidebar_text) else t.hex(t.sidebar_muted),
        });
    }
}

fn brand(c: *ui.Context, t: colors.Palette) void {
    const group = ui.div(c).row().itemsCenter().gap(9).pr(6);
    defer group.end();

    {
        const mark = ui.div(c)
            .w(26)
            .h(26)
            .rounded(8)
            .bg(t.hex(t.accent))
            .gradient(t.hex(t.accent_warm))
            .itemsCenter()
            .justifyCenter()
            .shadow(.{ .color = t.soft(t.accent, 0.4), .blur = 12, .y = 3 });
        defer mark.end();
        ui.icon(c, "gauge.with.dots.needle.33percent", .{
            .size = 14,
            .color = t.hex(t.text_on_accent),
        });
    }

    ui.text(c, "Focus Studio", .{
        .size = 12.5,
        .weight = .semibold,
        .color = t.hex(t.sidebar_text),
        .tracking = -0.1,
    });
}

fn verticalRule(c: *ui.Context, t: colors.Palette) void {
    const rule = ui.div(c).w(1).h(18).bg(t.hex(t.sidebar_line));
    defer rule.end();
}

fn tabs(state: *AppState, c: *ui.Context, t: colors.Palette) void {
    const rail = ui.div(c).row().itemsCenter().gap(2).pl(4).pr(4);
    defer rail.end();

    for (nav_items) |item| {
        const active = state.current_page == item.page;
        const tab = ui.div(c)
            .row()
            .h(32)
            .px(12)
            .rounded(9)
            .gap(7)
            .itemsCenter()
            .bg(if (active) ui.Color.white.alpha(0.12) else ui.Color.transparent)
            .hover(if (active) ui.Color.white.alpha(0.15) else ui.Color.white.alpha(0.06));
        defer tab.end();
        if (tab.clicked()) {
            std.debug.print("DBG tab {s}\n", .{item.label});
            state.current_page = item.page;
        }

        ui.icon(c, item.icon, .{
            .size = 13,
            .weight = if (active) .semibold else .regular,
            .color = if (active) t.hex(t.accent) else t.hex(t.sidebar_muted),
        });
        ui.text(c, item.label, .{
            .size = 12.5,
            .weight = if (active) .semibold else .medium,
            .color = if (active) t.hex(t.sidebar_text) else t.hex(t.sidebar_muted),
        });
    }
    themeButton(state, c, t, false);
}

fn themeButton(state: *AppState, c: *ui.Context, t: colors.Palette, compact: bool) void {
    const btn = ui.div(c)
        .w(if (compact) 44 else 30)
        .h(if (compact) 44 else 30)
        .rounded(8)
        .itemsCenter()
        .justifyCenter()
        .hover(ui.Color.white.alpha(0.08));
    defer btn.end();
    if (btn.clicked()) state.settings.dark_mode = !state.settings.dark_mode;

    ui.icon(c, "circle.lefthalf.filled", .{
        .size = 14,
        .color = if (state.settings.dark_mode) t.hex(t.sidebar_text) else t.hex(t.sidebar_muted),
    });
}

fn windowControls(c: *ui.Context, t: colors.Palette) void {
    const group = ui.div(c).row().hFull().itemsStretch();
    defer group.end();

    // Minimize
    {
        const btn = controlButton(c, t);
        defer btn.end();
        if (btn.clicked()) {
            std.debug.print("DBG min\n", .{});
            if (shell.window) |w| w.minimize();
        }
        const glyph = ui.div(c).w(10).h(1.4).roundedFull().bg(t.hex(t.sidebar_text).alpha(0.8));
        defer glyph.end();
    }

    // Maximize / restore
    {
        const btn = controlButton(c, t);
        defer btn.end();
        if (btn.clicked()) {
            std.debug.print("DBG max\n", .{});
            if (shell.window) |w| w.zoom();
        }
        const glyph = ui.div(c)
            .w(9)
            .h(9)
            .border(t.hex(t.sidebar_text).alpha(0.8))
            .borderW(1.2);
        defer glyph.end();
    }

    // Close
    {
        const btn = ui.div(c)
            .w(44)
            .hFull()
            .itemsCenter()
            .justifyCenter()
            .hover(ui.Color.hex(0xe81123));
        defer btn.end();
        if (btn.clicked()) {
            if (shell.window) |w| w.close();
        }
        ui.icon(c, "xmark", .{ .size = 11, .weight = .semibold, .color = t.hex(t.sidebar_text) });
    }
}

fn controlButton(c: *ui.Context, t: colors.Palette) ui.Div {
    _ = t;
    return ui.div(c)
        .w(44)
        .hFull()
        .itemsCenter()
        .justifyCenter()
        .hover(ui.Color.white.alpha(0.08));
}
