const std = @import("std");
const nanoui = @import("nanoui");
const ui = nanoui.ui;
const AppState = @import("../app_state.zig").AppState;
const colors = @import("../theme/colors.zig");
const kit = @import("../theme/kit.zig");
const stats_state = @import("../stats/stats_state.zig");
const responsive = @import("../responsive.zig");

const mini_ring_size: f32 = 96;

pub fn view(state: *AppState, c: *ui.Context) void {
    const t = colors.palette(state.settings.dark_mode);
    const compact = responsive.isCompact(c);

    const root = ui.div(c)
        .column()
        .sizeFull()
        .px(responsive.pagePadding(c))
        .pt(if (compact) 16 else 26)
        .pb(if (compact) 16 else 24);
    defer root.end();

    {
        const header = kit.pageHeader(c, t, t.hex(t.accent), "INSIGHTS", "Your focus, at a glance", "Small sessions add up to meaningful work.");
        defer header.end();
        const week = kit.pill(c, c.print("{d} sessions this week", .{state.stats.weeklyPomodoros()}), t.hex(t.accent));
        defer week.end();
    }

    {
        const scroll = ui.div(c)
            .column()
            .wFull()
            .grow()
            .scrollY()
            .gap(14)
            .pt(2)
            .scrollbar(.{ .overlay = t.soft(t.text_muted, 0.35) });
        defer scroll.end();

        if (compact) {
            {
                const cards = ui.div(c).row().wFull().gap(8).itemsStretch();
                defer cards.end();
                kit.statCard(c, t, "chart.bar.xaxis", t.accent_blue, "Sessions", c.print("{d}", .{state.stats.total_pomodoros}), "all time", true);
                kit.statCard(c, t, "gauge.with.dots.needle.33percent", t.accent_teal, "Focus time", c.print("{d}h {d}m", .{
                    state.stats.total_focus_min / 60,
                    state.stats.total_focus_min % 60,
                }), "all time", true);
            }
            {
                const cards = ui.div(c).row().wFull().gap(8).itemsStretch();
                defer cards.end();
                kit.statCard(c, t, "flame", t.accent_warm, "Streak", c.print("{d}", .{state.stats.current_streak}), "days in a row", true);
                kit.statCard(c, t, "star.fill", t.accent_green, "Best streak", c.print("{d}", .{state.stats.best_streak}), "personal record", true);
            }
        } else {
            const cards = ui.div(c).row().wFull().gap(12).itemsStretch();
            defer cards.end();
            kit.statCard(c, t, "chart.bar.xaxis", t.accent_blue, "Sessions", c.print("{d}", .{state.stats.total_pomodoros}), "all time", false);
            kit.statCard(c, t, "gauge.with.dots.needle.33percent", t.accent_teal, "Focus time", c.print("{d}h {d}m", .{
                state.stats.total_focus_min / 60,
                state.stats.total_focus_min % 60,
            }), "all time", false);
            kit.statCard(c, t, "flame", t.accent_warm, "Streak", c.print("{d}", .{state.stats.current_streak}), "days in a row", false);
            kit.statCard(c, t, "star.fill", t.accent_green, "Best streak", c.print("{d}", .{state.stats.best_streak}), "personal record", false);
        }

        {
            const mid = if (compact)
                ui.div(c).column().wFull().gap(12).itemsStretch()
            else
                ui.div(c).row().wFull().gap(14).itemsStretch();
            defer mid.end();
            dailyGoal(state, c, t, compact);
            weekChart(state, c, t);
        }

        {
            const bottom = if (compact)
                ui.div(c).column().wFull().gap(12).itemsStretch()
            else
                ui.div(c).row().wFull().gap(14).itemsStretch();
            defer bottom.end();
            summaryPanel(c, t, "TODAY", state.stats.todays_pomodoros, state.stats.todays_focus_min, t.hex(t.accent), compact);
            summaryPanel(c, t, "THIS WEEK", state.stats.weeklyPomodoros(), state.stats.weeklyFocusMin(), t.hex(t.accent_blue), compact);
        }
    }
}

fn dailyGoal(state: *AppState, c: *ui.Context, t: colors.Palette, compact: bool) void {
    const goal = @max(1, state.settings.pomodoros_until_long_break);
    const sessions = state.stats.todays_pomodoros;
    const ratio = @min(1.0, @as(f32, @floatFromInt(sessions)) / @as(f32, @floatFromInt(goal)));
    const remaining = if (sessions >= goal) 0 else goal - sessions;

    const card = if (compact) kit.panel(c, t).wFull().h(208) else kit.panel(c, t).w(250).h(208);
    defer card.end();

    kit.sectionLabel(c, t, "DAILY GOAL");

    {
        const row = ui.div(c).row().wFull().grow().gap(14).itemsCenter();
        defer row.end();

        {
            const wrap = ui.div(c).w(mini_ring_size).h(mini_ring_size).itemsCenter().justifyCenter();
            defer wrap.end();

            const cv = ui.canvas(c, .{
                .absolute = true,
                .width = .{ .px = mini_ring_size },
                .height = .{ .px = mini_ring_size },
            });
            drawMiniRing(cv, t.hex(t.accent), ratio);

            const center = ui.div(c).column().itemsCenter().gap(0);
            defer center.end();
            ui.text(c, c.print("{d}", .{sessions}), .{
                .size = 24,
                .weight = .bold,
                .color = t.hex(t.text_primary),
                .tracking = -0.6,
                .tabular = true,
            });
            ui.text(c, c.print("/ {d}", .{goal}), .{
                .size = 9,
                .weight = .medium,
                .color = t.hex(t.text_muted),
                .tabular = true,
            });
        }

        {
            const col = ui.div(c).column().grow().gap(3);
            defer col.end();
            ui.text(c, if (remaining == 0) "Goal reached" else c.print("{d} to go", .{remaining}), .{
                .size = 15,
                .weight = .semibold,
                .color = if (remaining == 0) t.hex(t.accent_green) else t.hex(t.text_primary),
            });
            ui.text(c, "sessions today", .{
                .size = 10.5,
                .color = t.hex(t.text_muted),
            });
            {
                const spacer = ui.div(c).h(6);
                defer spacer.end();
            }
            ui.text(c, c.print("{d} min", .{state.stats.todays_focus_min}), .{
                .size = 18,
                .weight = .bold,
                .color = t.hex(t.accent),
                .tracking = -0.3,
                .tabular = true,
            });
            ui.text(c, "focused", .{
                .size = 10,
                .color = t.hex(t.text_muted),
            });
        }
    }
}

fn weekChart(state: *AppState, c: *ui.Context, t: colors.Palette) void {
    const card = kit.panel(c, t).grow().h(208);
    defer card.end();

    {
        const top = ui.div(c).row().wFull().itemsCenter().justifyBetween();
        defer top.end();
        kit.sectionLabel(c, t, "LAST 7 DAYS");
        {
            const balance = ui.div(c).row().gap(5).itemsCenter();
            defer balance.end();
            ui.icon(c, "flame", .{ .size = 10, .color = t.hex(t.accent_warm) });
            ui.text(c, c.print("{d} total", .{state.stats.weeklyPomodoros()}), .{
                .size = 10,
                .weight = .semibold,
                .color = t.hex(t.text_secondary),
            });
        }
    }

    {
        const chart_row = ui.div(c).row().wFull().grow().gap(8).itemsEnd().pt(4);
        defer chart_row.end();

        const max_val = state.stats.maxDailyPomodoros();
        const day_labels = [_][]const u8{ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" };
        const chart_h: f32 = 104;

        for (state.stats.daily_pomodoros, 0..) |count, i| {
            const col = ui.div(c).column().grow().hFull().itemsCenter().justifyEnd().gap(5);
            defer col.end();

            const is_today = i == stats_state.HISTORY_DAYS - 1;
            const ratio: f32 = if (max_val > 0)
                @as(f32, @floatFromInt(count)) / @as(f32, @floatFromInt(max_val))
            else
                0;
            const bar_px: f32 = if (count == 0) 5 else @max(10, ratio * chart_h);

            ui.text(c, if (count > 0) c.print("{d}", .{count}) else "·", .{
                .size = 9.5,
                .weight = .semibold,
                .color = if (is_today) t.hex(t.accent) else t.hex(t.text_muted),
                .tabular = true,
            });

            {
                const track = ui.div(c)
                    .w(18)
                    .h(chart_h)
                    .rounded(9)
                    .bg(t.soft(t.accent, if (t.dark) 0.10 else 0.06))
                    .column()
                    .justifyEnd()
                    .clip();
                defer track.end();

                const fill = ui.div(c)
                    .wFull()
                    .h(bar_px)
                    .rounded(9)
                    .bg(if (is_today) t.hex(t.accent) else t.soft(t.accent, if (t.dark) 0.45 else 0.32))
                    .gradient(if (is_today) t.soft(t.accent_warm, 0.75) else t.soft(t.accent, if (t.dark) 0.22 else 0.14));
                defer fill.end();
            }

            ui.text(c, day_labels[i % 7], .{
                .size = 9.5,
                .weight = if (is_today) .semibold else .regular,
                .color = if (is_today) t.hex(t.accent) else t.hex(t.text_muted),
            });
        }
    }
}

fn summaryPanel(c: *ui.Context, t: colors.Palette, title: []const u8, sessions: u32, focus_min: u32, tint: ui.Color, compact: bool) void {
    const card = kit.panel(c, t).grow().h(126);
    defer card.end();

    {
        const top = ui.div(c).row().wFull().itemsCenter().justifyBetween();
        defer top.end();
        kit.sectionLabel(c, t, title);
        const dot = ui.div(c).w(6).h(6).roundedFull().bg(tint);
        defer dot.end();
    }

    {
        const values = ui.div(c).row().wFull().grow().gap(if (compact) 16 else 36).itemsCenter();
        defer values.end();
        valueBlock(c, t, c.print("{d}", .{sessions}), "SESSIONS", tint);
        valueBlock(c, t, c.print("{d}h {d}m", .{ focus_min / 60, focus_min % 60 }), "FOCUS TIME", t.hex(t.text_primary));
    }
}

fn valueBlock(c: *ui.Context, t: colors.Palette, value: []const u8, label: []const u8, color: ui.Color) void {
    const col = ui.div(c).column().gap(1);
    defer col.end();
    ui.text(c, value, .{
        .size = 24,
        .weight = .bold,
        .color = color,
        .tracking = -0.5,
        .tabular = true,
    });
    ui.text(c, label, .{
        .size = 8.5,
        .weight = .semibold,
        .color = t.hex(t.text_muted),
        .tracking = 1.1,
    });
}

fn drawMiniRing(cv: *ui.Canvas, color: ui.Color, ratio_raw: f32) void {
    const center: ui.Point = .{ .x = mini_ring_size / 2, .y = mini_ring_size / 2 };
    const radius = mini_ring_size / 2 - 6;
    const width: f32 = 8;

    cv.ring(center, radius, width, color.alpha(0.13));

    const p = @max(0, @min(1, ratio_raw));
    if (p <= 0.001) return;

    const steps: usize = 96;
    var points: [steps + 1]ui.Point = undefined;
    const sweep = 2 * std.math.pi * p;
    var i: usize = 0;
    while (i <= steps) : (i += 1) {
        const a = -std.math.pi * 0.5 + sweep * (@as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(steps)));
        points[i] = .{
            .x = center.x + radius * @cos(a),
            .y = center.y + radius * @sin(a),
        };
    }
    cv.polyline(points[0 .. steps + 1], .{ .width = width, .color = color });
}
