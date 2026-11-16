const std = @import("std");
const nanoui = @import("nanoui");
const ui = nanoui.ui;
const AppState = @import("../app_state.zig").AppState;
const colors = @import("../theme/colors.zig");
const kit = @import("../theme/kit.zig");
const timer_state = @import("../timer/timer_state.zig");

const ring_size: f32 = 268;
const ring_width: f32 = 11;

pub fn view(state: *AppState, c: *ui.Context) void {
    const ps = state.phaseSettings();
    state.timer.tick(ps);
    c.frameIn(1);
    const t = colors.palette(state.settings.dark_mode);

    if (state.timer.phase_just_completed) {
        const dur_min = @as(u32, @intCast(ps.work_ms / 60_000));
        const todo_id: u64 = if (state.timer.active_todo_index) |idx|
            state.todos.items[idx].id
        else
            0;
        state.stats.recordPomodoro(dur_min, todo_id);
        if (state.timer.active_todo_index) |idx| {
            state.todos.incrementPomodoro(idx);
        }
    }

    const phase = @as(colors.TimerPhase, @fromBackingInt(@intCast(@backingInt(state.timer.phase))));
    const accent = t.phaseAccent(phase);
    const timer_color = t.timerText(phase);
    const progress = state.timer.progress();

    const root = ui.div(c).column().sizeFull().px(30).pt(26).pb(24);
    defer root.end();

    {
        const subtitle = switch (state.timer.phase) {
            .idle => "Set your intention, then begin a focused session.",
            .working => "Protect this block. Everything else can wait.",
            .short_break, .long_break => "Step away, breathe, and come back sharper.",
        };
        const kicker = switch (state.timer.phase) {
            .idle, .working => "DEEP WORK",
            .short_break, .long_break => "RECHARGE",
        };
        const header = kit.pageHeader(c, t, t.hex(accent), kicker, state.timer.phaseLabel(), subtitle);
        defer header.end();

        const meta = ui.div(c).row().gap(8).itemsCenter();
        defer meta.end();
        metaPill(c, t, "flame", c.print("{d} day streak", .{state.stats.current_streak}), t.hex(t.accent_warm));
        metaPill(c, t, "checkmark.circle.fill", c.print("{d} today", .{state.stats.todays_pomodoros}), t.hex(t.accent_green));
    }

    {
        const body = ui.div(c).row().wFull().grow().gap(18).itemsStretch();
        defer body.end();

        timerHero(state, c, t, phase, accent, timer_color, progress, ps);
        sideColumn(state, c, t, accent, ps);
    }
}

fn timerHero(
    state: *AppState,
    c: *ui.Context,
    t: colors.Palette,
    phase: colors.TimerPhase,
    accent: u32,
    timer_color: u32,
    progress: f32,
    ps: timer_state.PhaseSettings,
) void {
    const hero = ui.div(c)
        .column()
        .grow()
        .hFull()
        .rounded(26)
        .bg(t.hex(t.bg_card))
        .gradient(t.soft(accent, if (t.dark) 0.13 else 0.055))
        .border(t.hex(t.border_subtle))
        .borderW(1)
        .itemsCenter()
        .justifyCenter()
        .gap(14)
        .p(22)
        .shadow(.{
        .color = t.soft(accent, if (t.dark) 0.10 else 0.13),
        .blur = 34,
        .y = 14,
        .spread = -6,
    });
    defer hero.end();

    // Phase chip
    {
        const chip = ui.div(c)
            .row()
            .px(12)
            .py(6)
            .roundedFull()
            .gap(7)
            .itemsCenter()
            .bg(t.soft(accent, if (t.dark) 0.16 else 0.10))
            .border(t.soft(accent, 0.24))
            .borderW(1);
        defer chip.end();
        {
            const dot = ui.div(c)
                .w(6)
                .h(6)
                .roundedFull()
                .bg(t.hex(accent));
            defer dot.end();
        }
        ui.text(c, state.timer.phaseLabel(), .{
            .size = 11,
            .weight = .semibold,
            .color = t.hex(accent),
            .tracking = 0.4,
        });
    }

    // Dial + progress ring
    {
        const wrap = ui.div(c)
            .w(ring_size)
            .h(ring_size)
            .itemsCenter()
            .justifyCenter();
        defer wrap.end();

        const cv = ui.canvas(c, .{
            .absolute = true,
            .width = .{ .px = ring_size },
            .height = .{ .px = ring_size },
        });
        drawRing(cv, t, accent, progress);

        const dial = ui.div(c).column().itemsCenter().gap(4);
        defer dial.end();

        const total_secs = state.timer.remaining_ms / 1000;
        ui.text(c, c.print("{d:0>2}:{d:0>2}", .{ total_secs / 60, total_secs % 60 }), .{
            .size = 58,
            .weight = .bold,
            .color = t.hex(timer_color),
            .tracking = -2.2,
            .tabular = true,
        });

        const status = if (state.timer.is_running)
            "Stay with it"
        else switch (state.timer.phase) {
            .idle => "Ready when you are",
            else => "Paused — take your time",
        };
        ui.text(c, status, .{
            .size = 11.5,
            .weight = .medium,
            .color = t.hex(t.text_muted),
            .tracking = 0.2,
        });
    }

    // Controls
    {
        const controls = ui.div(c).row().gap(12).itemsCenter();
        defer controls.end();

        {
            const reset = kit.iconButton(c, t);
            defer reset.end();
            if (reset.clicked()) {
                state.timer.reset(ps.work_ms);
            }
            ui.icon(c, "arrow.clockwise", .{ .size = 17, .color = t.hex(t.text_secondary) });
        }

        {
            const label = if (state.timer.is_running) "Pause" else if (state.timer.phase == .idle) "Start focus" else "Start";
            const play_btn = ui.div(c)
                .row()
                .px(28)
                .py(13)
                .rounded(15)
                .bg(t.hex(accent))
                .gradient(t.hex(accent).mix(ui.Color.black, 0.14))
                .itemsCenter()
                .gap(8)
                .hover(t.hex(accent).mix(ui.Color.white, 0.12))
                .shadow(.{ .color = t.soft(accent, 0.42), .blur = 20, .y = 9 });
            defer play_btn.end();
            if (play_btn.clicked()) {
                if (state.timer.is_running) {
                    state.timer.pause();
                } else {
                    state.timer.start();
                }
            }
            ui.icon(c, if (state.timer.is_running) "pause.fill" else "play.fill", .{
                .size = 12,
                .color = t.hex(t.text_on_accent),
            });
            ui.text(c, label, .{
                .size = 14.5,
                .weight = .semibold,
                .color = t.hex(t.text_on_accent),
            });
        }

        {
            const skip = kit.iconButton(c, t);
            defer skip.end();
            if (skip.clicked()) {
                state.timer.skip(ps);
            }
            ui.icon(c, "forward.fill", .{ .size = 14, .color = t.hex(t.text_secondary) });
        }
    }

    // Cycle dots
    {
        const cycle = ui.div(c).row().gap(8).itemsCenter();
        defer cycle.end();
        ui.text(c, "CYCLE", .{
            .size = 9,
            .weight = .semibold,
            .color = t.hex(t.text_muted),
            .tracking = 1.3,
        });
        var i: u32 = 0;
        while (i < ps.pomodoros_until_long_break) : (i += 1) {
            const filled = i < state.timer.completed_in_cycle;
            const current = !filled and i == state.timer.completed_in_cycle and phase != .idle;
            const dot = ui.div(c)
                .w(if (filled or current) 9 else 7)
                .h(if (filled or current) 9 else 7)
                .roundedFull()
                .bg(if (filled) t.hex(accent) else if (current) t.soft(accent, 0.55) else t.soft(t.text_primary, if (t.dark) 0.22 else 0.13));
            defer dot.end();
        }
        ui.text(c, c.print("{d}/{d}", .{ state.timer.completed_in_cycle, ps.pomodoros_until_long_break }), .{
            .size = 10,
            .weight = .medium,
            .color = t.hex(t.text_muted),
            .tabular = true,
        });
    }

    if (state.timer.total_completed > 0) {
        ui.text(c, c.print("{d} sessions completed this run", .{state.timer.total_completed}), .{
            .size = 10.5,
            .color = t.hex(t.text_muted),
        });
    }
}

fn sideColumn(
    state: *AppState,
    c: *ui.Context,
    t: colors.Palette,
    accent: u32,
    ps: timer_state.PhaseSettings,
) void {
    const side = ui.div(c)
        .column()
        .w(248)
        .hFull()
        .gap(12)
        .scrollY()
        .scrollbar(.{ .overlay = t.soft(t.text_muted, 0.35) });
    defer side.end();

    currentTask(state, c, t, accent);
    upNext(state, c, t, accent);
    todaySummary(state, c, t, accent, ps);
}

fn currentTask(state: *AppState, c: *ui.Context, t: colors.Palette, accent: u32) void {
    const card = kit.panel(c, t);
    defer card.end();

    {
        const top = ui.div(c).row().wFull().itemsCenter().justifyBetween();
        defer top.end();
        kit.sectionLabel(c, t, "CURRENT TASK");
        if (state.timer.active_todo_index != null) {
            const unlink = ui.div(c)
                .w(24)
                .h(24)
                .rounded(8)
                .itemsCenter()
                .justifyCenter()
                .hover(t.hex(t.bg_hover));
            defer unlink.end();
            if (unlink.clicked()) state.timer.active_todo_index = null;
            ui.icon(c, "xmark", .{ .size = 10, .color = t.hex(t.text_muted) });
        }
    }

    if (state.timer.active_todo_index) |idx| {
        if (idx < state.todos.item_count) {
            const item = &state.todos.items[idx];
            const prio_color = kit.priorityColor(t, item.priority);

            ui.text(c, item.textSlice(), .{
                .size = 14,
                .weight = .semibold,
                .color = t.hex(t.text_primary),
                .wrap = true,
                .leading = 1.25,
                .max_lines = 3,
            });

            {
                const meta = ui.div(c).row().wFull().itemsCenter().justifyBetween().pt(2);
                defer meta.end();
                {
                    const left = ui.div(c).row().gap(6).itemsCenter();
                    defer left.end();
                    {
                        const dot = ui.div(c).w(6).h(6).roundedFull().bg(t.hex(prio_color));
                        defer dot.end();
                    }
                    ui.text(c, c.print("{d}/{d} sessions", .{ item.pomodoros_spent, item.pomodoros_estimated }), .{
                        .size = 10.5,
                        .color = t.hex(t.text_muted),
                        .tabular = true,
                    });
                }
                ui.text(c, kit.priorityLabel(item.priority), .{
                    .size = 10,
                    .weight = .semibold,
                    .color = t.hex(prio_color),
                });
            }

            const est = @max(1, item.pomodoros_estimated);
            const ratio = @min(1.0, @as(f32, @floatFromInt(item.pomodoros_spent)) / @as(f32, @floatFromInt(est)));
            kit.progressBar(c, t, ratio, 5, t.hex(accent));
            return;
        }
    }

    // Empty state
    {
        const empty = ui.div(c).column().itemsCenter().gap(7).py(8);
        defer empty.end();
        kit.iconTile(c, t.hex(accent), 38, "checklist", 18);
        ui.text(c, "No task linked", .{
            .size = 13,
            .weight = .semibold,
            .color = t.hex(t.text_primary),
        });
        ui.text(c, "Link work to track your sessions", .{
            .size = 10.5,
            .color = t.hex(t.text_muted),
        });
        {
            const pick = ui.div(c)
                .row()
                .px(12)
                .py(6)
                .rounded(9)
                .bg(t.soft(accent, 0.10))
                .hover(t.soft(accent, 0.18));
            defer pick.end();
            if (pick.clicked()) state.current_page = .todos;
            ui.text(c, "Pick a task", .{
                .size = 10.5,
                .weight = .semibold,
                .color = t.hex(accent),
            });
        }
    }
}

fn upNext(state: *AppState, c: *ui.Context, t: colors.Palette, accent: u32) void {
    const card = kit.panel(c, t);
    defer card.end();

    kit.sectionLabel(c, t, "UP NEXT");

    var shown: usize = 0;
    var i: usize = 0;
    while (i < state.todos.item_count and shown < 2) : (i += 1) {
        const item = &state.todos.items[i];
        if (item.completed) continue;
        if (state.timer.active_todo_index) |active| {
            if (active == i) continue;
        }

        const row = ui.div(c)
            .row()
            .wFull()
            .py(6)
            .px(6)
            .rounded(8)
            .gap(8)
            .itemsCenter()
            .hover(t.hex(t.bg_hover));
        defer row.end();
        if (row.clicked()) state.timer.active_todo_index = i;

        {
            const dot = ui.div(c)
                .w(6)
                .h(6)
                .roundedFull()
                .bg(t.hex(kit.priorityColor(t, item.priority)));
            defer dot.end();
        }

        ui.text(c, item.textSlice(), .{
            .size = 11.5,
            .color = t.hex(t.text_secondary),
            .wrap = true,
            .max_lines = 1,
        });
        ui.icon(c, "arrow.right", .{ .size = 10, .color = t.hex(accent) });
        shown += 1;
    }

    if (shown == 0) {
        ui.text(c, if (state.todos.item_count == 0) "Add a task to get started." else "Nothing else queued up.", .{
            .size = 11,
            .color = t.hex(t.text_muted),
        });
    } else {
        ui.text(c, "Click one to link it to this session", .{
            .size = 9.5,
            .color = t.hex(t.text_muted),
        });
    }
}

fn todaySummary(
    state: *AppState,
    c: *ui.Context,
    t: colors.Palette,
    accent: u32,
    ps: timer_state.PhaseSettings,
) void {
    const card = kit.panel(c, t);
    defer card.end();

    {
        const top = ui.div(c).row().wFull().itemsCenter().justifyBetween();
        defer top.end();
        kit.sectionLabel(c, t, "TODAY");
        {
            const goal = ui.div(c)
                .row()
                .px(7)
                .py(3)
                .roundedFull()
                .gap(4)
                .itemsCenter()
                .bg(t.soft(accent, 0.10));
            defer goal.end();
            ui.icon(c, "circle.dotted", .{ .size = 9, .color = t.hex(accent) });
            ui.text(c, c.print("goal {d}", .{ps.pomodoros_until_long_break}), .{
                .size = 9,
                .weight = .semibold,
                .color = t.hex(accent),
            });
        }
    }

    {
        const numbers = ui.div(c).row().itemsCenter().gap(6);
        defer numbers.end();
        ui.text(c, c.print("{d}", .{state.stats.todays_pomodoros}), .{
            .size = 28,
            .weight = .bold,
            .color = t.hex(t.text_primary),
            .tracking = -0.8,
            .tabular = true,
        });
        ui.text(c, c.print("of {d} sessions", .{ps.pomodoros_until_long_break}), .{
            .size = 10.5,
            .color = t.hex(t.text_muted),
        });
    }

    const goal = @max(1, ps.pomodoros_until_long_break);
    const ratio = @min(1.0, @as(f32, @floatFromInt(state.stats.todays_pomodoros)) / @as(f32, @floatFromInt(goal)));
    kit.progressBar(c, t, ratio, 6, t.hex(accent));

    ui.text(c, c.print("{d} min focused today", .{state.stats.todays_focus_min}), .{
        .size = 10,
        .color = t.hex(t.text_muted),
    });
}

fn metaPill(c: *ui.Context, t: colors.Palette, icon_name: []const u8, label: []const u8, color: ui.Color) void {
    _ = t;
    const pill = ui.div(c)
        .row()
        .px(10)
        .py(5)
        .roundedFull()
        .gap(6)
        .itemsCenter()
        .bg(color.alpha(0.10))
        .border(color.alpha(0.18))
        .borderW(1);
    defer pill.end();
    ui.icon(c, icon_name, .{ .size = 11, .color = color });
    ui.text(c, label, .{
        .size = 10.5,
        .weight = .semibold,
        .color = color,
    });
}

fn drawRing(cv: *ui.Canvas, t: colors.Palette, accent: u32, progress: f32) void {
    _ = t;
    const center: ui.Point = .{ .x = ring_size / 2, .y = ring_size / 2 };
    const radius = ring_size / 2 - ring_width - 4;

    const track_color = ui.Color.hex(@truncate(accent)).alpha(0.12);
    cv.ring(center, radius, ring_width, track_color);

    const p = @max(0, @min(1, progress));
    if (p <= 0.001) return;

    const accent_color = ui.Color.hex(@truncate(accent));
    if (p >= 0.999) {
        cv.ring(center, radius, ring_width, accent_color);
        return;
    }

    const steps: usize = 128;
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

    cv.polyline(points[0 .. steps + 1], .{ .width = ring_width, .color = accent_color });

    const tip = points[steps];
    cv.circle(tip, ring_width + 2, accent_color.alpha(0.16));
    cv.circle(tip, ring_width * 0.55, accent_color);
}
