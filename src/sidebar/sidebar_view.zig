const nanoui = @import("nanoui");
const ui = nanoui.ui;
const AppState = @import("../app_state.zig").AppState;
const colors = @import("../theme/colors.zig");
const kit = @import("../theme/kit.zig");

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

pub fn view(state: *AppState, c: *ui.Context) void {
    const t = colors.palette(state.settings.dark_mode);

    const sidebar = ui.div(c)
        .column()
        .w(232)
        .hFull()
        .bg(t.hex(t.bg_sidebar))
        .gradient(t.hex(t.bg_sidebar_end))
        .px(16)
        .py(20)
        .gap(6);
    defer sidebar.end();

    // Brand
    {
        const brand = ui.div(c).row().wFull().itemsCenter().gap(10).pb(18);
        defer brand.end();

        {
            const mark = ui.div(c)
                .w(40)
                .h(40)
                .rounded(13)
                .bg(t.hex(t.accent))
                .gradient(t.hex(t.accent_warm))
                .itemsCenter()
                .justifyCenter()
                .shadow(.{ .color = t.soft(t.accent, 0.45), .blur = 18, .y = 6 });
            defer mark.end();
            ui.icon(c, "gauge.with.dots.needle.33percent", .{
                .size = 20,
                .color = t.hex(t.text_on_accent),
            });
        }

        {
            const words = ui.div(c).column().gap(1);
            defer words.end();
            ui.text(c, "Focus", .{
                .size = 17,
                .weight = .bold,
                .color = t.hex(t.sidebar_text),
                .tracking = -0.2,
            });
            ui.text(c, "STUDIO", .{
                .size = 9,
                .weight = .semibold,
                .color = t.hex(t.sidebar_muted),
                .tracking = 1.8,
            });
        }
    }

    ui.text(c, "WORKSPACE", .{
        .size = 9,
        .weight = .semibold,
        .color = t.hex(t.sidebar_muted),
        .tracking = 1.6,
    });
    {
        const pad = ui.div(c).h(4);
        defer pad.end();
    }

    for (nav_items) |item| {
        const is_active = state.current_page == item.page;
        const btn = ui.div(c)
            .row()
            .wFull()
            .h(44)
            .px(10)
            .gap(10)
            .rounded(12)
            .itemsCenter()
            .bg(if (is_active) t.soft(t.accent, 0.16) else ui.Color.transparent)
            .border(if (is_active) t.soft(t.accent, 0.26) else ui.Color.transparent)
            .borderW(1)
            .hover(if (is_active) t.soft(t.accent, 0.24) else ui.Color.white.alpha(0.06));
        defer btn.end();
        if (btn.clicked()) state.current_page = item.page;

        {
            const bar = ui.div(c)
                .w(3)
                .h(18)
                .roundedFull()
                .bg(if (is_active) t.hex(t.accent) else ui.Color.transparent);
            defer bar.end();
        }

        ui.icon(c, item.icon, .{
            .size = 17,
            .weight = if (is_active) .semibold else .regular,
            .color = if (is_active) t.hex(t.accent) else t.hex(t.sidebar_muted),
        });
        ui.text(c, item.label, .{
            .size = 13.5,
            .weight = if (is_active) .semibold else .medium,
            .color = if (is_active) t.hex(t.sidebar_text) else t.hex(t.sidebar_muted),
        });
    }

    ui.spacer(c);

    // Today at a glance
    todayCard(state, c, t);

    {
        const gap = ui.div(c).h(10);
        defer gap.end();
    }

    themeSwitch(state, c, t);

    {
        const foot = ui.div(c).row().wFull().justifyCenter().pt(12);
        defer foot.end();
        ui.text(c, "v0.1.0 · Zig + nanoui", .{
            .size = 9.5,
            .color = t.soft(t.sidebar_muted, 0.9),
        });
    }
}

fn todayCard(state: *AppState, c: *ui.Context, t: colors.Palette) void {
    const goal = @max(1, state.settings.pomodoros_until_long_break);
    const sessions = state.stats.todays_pomodoros;
    const ratio = @min(1.0, @as(f32, @floatFromInt(sessions)) / @as(f32, @floatFromInt(goal)));

    const card = ui.div(c)
        .column()
        .wFull()
        .p(14)
        .rounded(16)
        .bg(ui.Color.white.alpha(0.045))
        .border(ui.Color.white.alpha(0.07))
        .borderW(1)
        .gap(9);
    defer card.end();

    {
        const top = ui.div(c).row().wFull().itemsCenter().justifyBetween();
        defer top.end();
        ui.text(c, "TODAY", .{
            .size = 9,
            .weight = .semibold,
            .color = t.hex(t.sidebar_muted),
            .tracking = 1.5,
        });
        {
            const streak = ui.div(c).row().gap(4).itemsCenter();
            defer streak.end();
            ui.icon(c, "flame", .{ .size = 11, .color = t.hex(t.accent_warm) });
            ui.text(c, c.print("{d}d", .{state.stats.current_streak}), .{
                .size = 10,
                .weight = .semibold,
                .color = t.hex(t.accent_warm),
            });
        }
    }

    {
        const numbers = ui.div(c).row().itemsEnd().gap(6);
        defer numbers.end();
        ui.text(c, c.print("{d}", .{sessions}), .{
            .size = 28,
            .weight = .bold,
            .color = t.hex(t.sidebar_text),
            .tracking = -0.8,
            .tabular = true,
        });
        ui.text(c, "sessions", .{
            .size = 10.5,
            .color = t.hex(t.sidebar_muted),
        });
    }

    // Slim progress track, white on the dark rail.
    {
        const track = ui.div(c).row().wFull().h(5).roundedFull().bg(ui.Color.white.alpha(0.10));
        defer track.end();
        if (ratio > 0.001) {
            const fill = kit.growBy(ui.div(c).hFull().roundedFull().bg(t.hex(t.accent)), ratio);
            defer fill.end();
        }
        if (ratio < 0.999) {
            const rest = kit.growBy(ui.div(c).hFull(), 1 - ratio);
            defer rest.end();
        }
    }

    ui.text(c, c.print("{d} min focused · goal {d}", .{ state.stats.todays_focus_min, goal }), .{
        .size = 9.5,
        .color = t.hex(t.sidebar_muted),
    });
}

fn themeSwitch(state: *AppState, c: *ui.Context, t: colors.Palette) void {
    const rail = ui.div(c)
        .row()
        .wFull()
        .p(3)
        .rounded(12)
        .bg(ui.Color.white.alpha(0.05))
        .gap(3);
    defer rail.end();

    const modes = [_]struct { dark: bool, label: []const u8, icon: []const u8 }{
        .{ .dark = false, .label = "Light", .icon = "sun.max" },
        .{ .dark = true, .label = "Dark", .icon = "moon" },
    };

    for (modes) |mode| {
        const active = state.settings.dark_mode == mode.dark;
        const btn = ui.div(c)
            .row()
            .grow()
            .h(30)
            .rounded(9)
            .gap(5)
            .itemsCenter()
            .justifyCenter()
            .bg(if (active) ui.Color.white.alpha(0.10) else ui.Color.transparent)
            .hover(ui.Color.white.alpha(0.08));
        defer btn.end();
        if (btn.clicked()) state.settings.dark_mode = mode.dark;

        ui.icon(c, mode.icon, .{
            .size = 12,
            .color = if (active) t.hex(t.sidebar_text) else t.hex(t.sidebar_muted),
        });
        ui.text(c, mode.label, .{
            .size = 10.5,
            .weight = if (active) .semibold else .medium,
            .color = if (active) t.hex(t.sidebar_text) else t.hex(t.sidebar_muted),
        });
    }
}
