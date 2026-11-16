const nanoui = @import("nanoui");
const ui = nanoui.ui;
const AppState = @import("../app_state.zig").AppState;
const colors = @import("../theme/colors.zig");
const kit = @import("../theme/kit.zig");
const todo_state = @import("../todo/todo_state.zig");
const Priority = todo_state.Priority;
const responsive = @import("../responsive.zig");

var input_buf: ui.TextBuffer = .{};

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
        const subtitle = c.print("{d} active · {d} completed", .{
            state.todos.countActive(),
            state.todos.countCompleted(),
        });
        const header = kit.pageHeader(c, t, t.hex(t.accent), "ORGANIZE", "Tasks", subtitle);
        defer header.end();
        filterTabs(state, c, t);
    }

    completionSummary(state, c, t);
    composer(state, c, t);

    {
        const list_area = ui.div(c)
            .column()
            .wFull()
            .grow()
            .scrollY()
            .gap(8)
            .pt(10)
            .scrollbar(.{ .overlay = t.soft(t.text_muted, 0.35) });
        defer list_area.end();

        if (state.todos.item_count == 0) {
            emptyState(c, t, "Your day starts here", "Add a task above and give it a focused session.", "checklist");
        } else {
            var visible: usize = 0;
            var i: usize = 0;
            while (i < state.todos.item_count) : (i += 1) {
                if (!state.todos.itemVisible(i)) continue;
                todoRow(state, c, t, i, compact);
                visible += 1;
            }
            if (visible == 0) {
                emptyState(c, t, "Nothing in this view", "Try another filter to see your tasks.", "magnifyingglass");
            }
        }
    }
}

fn filterTabs(state: *AppState, c: *ui.Context, t: colors.Palette) void {
    const rail = ui.div(c)
        .row()
        .p(3)
        .rounded(11)
        .bg(if (t.dark) t.hex(t.bg_card) else t.hex(t.bg_secondary))
        .border(t.hex(t.border_subtle))
        .borderW(1)
        .gap(2);
    defer rail.end();

    const names = [_][]const u8{ "All", "Active", "Done" };
    for (names, 0..) |name, i| {
        const fi: todo_state.Filter = @fromBackingInt(@intCast(i));
        const active = state.todos.filter == fi;
        const tab_shadow: ui.Color = if (active)
            t.shadow(0.06, 0.45)
        else
            ui.Color.transparent;
        const tab = ui.div(c)
            .px(13)
            .py(if (responsive.isCompact(c)) 12 else 6)
            .rounded(8)
            .bg(if (active) (if (t.dark) t.hex(t.bg_hover) else t.hex(t.bg_card)) else ui.Color.transparent)
            .hover(if (active) (if (t.dark) t.hex(t.bg_hover) else t.hex(t.bg_card)) else t.hex(t.bg_hover))
            .shadow(.{ .color = tab_shadow, .blur = 8, .y = 2 });
        defer tab.end();
        if (tab.clicked()) state.todos.filter = fi;
        ui.text(c, name, .{
            .size = 12,
            .weight = if (active) .semibold else .medium,
            .color = if (active) t.hex(t.text_primary) else t.hex(t.text_muted),
        });
    }
}

fn completionSummary(state: *AppState, c: *ui.Context, t: colors.Palette) void {
    const total = state.todos.item_count;
    const done = state.todos.countCompleted();
    const ratio: f32 = if (total == 0) 0 else @as(f32, @floatFromInt(done)) / @as(f32, @floatFromInt(total));
    const pct: u32 = @intFromFloat(@round(ratio * 100));

    const card = ui.div(c)
        .row()
        .wFull()
        .p(14)
        .gap(12)
        .rounded(16)
        .itemsCenter()
        .bg(t.hex(t.bg_card))
        .border(t.hex(t.border_subtle))
        .borderW(1)
        .shadow(.{
        .color = t.shadow(0.035, 0.35),
        .blur = 14,
        .y = 4,
    });
    defer card.end();

    kit.iconTile(c, t.hex(t.accent_green), 38, "checklist", 18);

    {
        const col = ui.div(c).column().grow().gap(5);
        defer col.end();
        {
            const labels = ui.div(c).row().wFull().itemsCenter().justifyBetween();
            defer labels.end();
            ui.text(c, "Completion", .{
                .size = 11,
                .weight = .semibold,
                .color = t.hex(t.text_secondary),
            });
            ui.text(c, c.print("{d}%", .{pct}), .{
                .size = 11,
                .weight = .semibold,
                .color = t.hex(t.accent_green),
                .tabular = true,
            });
        }
        kit.progressBar(c, t, ratio, 6, t.hex(t.accent_green));
        ui.text(c, c.print("{d} of {d} tasks done · {d} focus sessions logged", .{
            done,
            total,
            state.todos.totalPomodoros(),
        }), .{
            .size = 9.5,
            .color = t.hex(t.text_muted),
        });
    }
}

fn composer(state: *AppState, c: *ui.Context, t: colors.Palette) void {
    const lane = ui.div(c).column().wFull().pt(14).pb(12);
    defer lane.end();

    const field = ui.div(c)
        .row()
        .wFull()
        .h(50)
        .p(5)
        .pl(14)
        .gap(10)
        .rounded(15)
        .bg(t.hex(t.bg_card))
        .border(t.hex(t.border))
        .borderW(1)
        .itemsCenter()
        .shadow(.{
        .color = t.shadow(0.04, 0.35),
        .blur = 12,
        .y = 3,
    });
    defer field.end();

    ui.icon(c, "plus", .{ .size = 14, .color = t.hex(t.text_muted) });

    const result = ui.textField(c, &input_buf, .{
        .placeholder = "What will you focus on?",
        .width = .fill,
        .size = 13.5,
        .bare = true,
    });
    if (result.submitted) submit(state);

    if (!responsive.isCompact(c)) ui.kbd(c, "Enter");

    {
        const add_btn = ui.div(c)
            .w(if (responsive.isCompact(c)) 44 else 40)
            .h(if (responsive.isCompact(c)) 44 else 40)
            .rounded(11)
            .bg(t.hex(t.accent))
            .gradient(t.hex(t.accent).mix(ui.Color.black, 0.12))
            .itemsCenter()
            .justifyCenter()
            .hover(t.hex(t.accent_hover))
            .shadow(.{ .color = t.soft(t.accent, 0.32), .blur = 10, .y = 3 });
        defer add_btn.end();
        if (add_btn.clicked()) submit(state);
        ui.icon(c, "plus", .{ .size = 17, .color = t.hex(t.text_on_accent) });
    }
}

fn submit(state: *AppState) void {
    const text = input_buf.text();
    if (text.len > 0) {
        state.todos.addItem(text);
        input_buf.clear();
    }
}

fn todoRow(state: *AppState, c: *ui.Context, t: colors.Palette, index: usize, compact: bool) void {
    const item = &state.todos.items[index];
    ui.keyInt(c, item.id);

    const is_active_timer_task = if (state.timer.active_todo_index) |idx| idx == index else false;
    const prio_color = kit.priorityColor(t, item.priority);

    const row = ui.div(c)
        .row()
        .wFull()
        .px(12)
        .py(11)
        .rounded(15)
        .gap(10)
        .itemsCenter()
        .bg(if (is_active_timer_task) t.soft(t.accent, if (t.dark) 0.10 else 0.06) else t.hex(t.bg_card))
        .border(if (is_active_timer_task) t.soft(t.accent, 0.30) else t.hex(t.border_subtle))
        .borderW(1)
        .hover(if (is_active_timer_task) t.soft(t.accent, if (t.dark) 0.14 else 0.09) else t.hex(t.bg_hover))
        .shadow(.{
        .color = t.shadow(0.025, 0.30),
        .blur = 10,
        .y = 2,
    });
    defer row.end();

    // Priority stripe
    {
        const stripe = ui.div(c)
            .w(3)
            .h(28)
            .roundedFull()
            .bg(if (item.completed) t.hex(t.border) else t.soft(prio_color, if (item.priority == .low) 0.45 else 0.9));
        defer stripe.end();
    }

    // Checkbox
    {
        const cb = ui.div(c)
            .w(if (compact) 44 else 23)
            .h(if (compact) 44 else 23)
            .itemsCenter()
            .justifyCenter()
            .hover(t.soft(t.accent_green, 0.24));
        defer cb.end();
        if (cb.clicked()) state.todos.toggleItem(index);

        const box = ui.div(c)
            .w(23)
            .h(23)
            .rounded(7)
            .bg(if (item.completed) t.hex(t.accent_green) else t.hex(t.bg_input))
            .border(if (item.completed) t.hex(t.accent_green) else t.hex(t.border))
            .borderW(1.5)
            .itemsCenter()
            .justifyCenter();
        defer box.end();
        if (item.completed) {
            ui.icon(c, "checkmark", .{ .size = 11, .weight = .bold, .color = t.hex(t.text_on_accent) });
        }
    }

    // Text
    {
        const text_col = ui.div(c).column().grow().gap(4);
        defer text_col.end();

        const title = item.textSlice();
        const title_style: ui.TextStyle = .{
            .size = 14,
            .weight = .medium,
            .color = if (item.completed) t.hex(t.text_muted) else t.hex(t.text_primary),
            .wrap = true,
            .leading = 1.2,
        };
        if (item.completed) {
            if (c.alloc().alloc(ui.Span, 1)) |spans| {
                spans[0] = .{ .start = 0, .end = @intCast(title.len), .strike = true };
                ui.richText(c, title, spans, title_style);
            } else |_| ui.text(c, title, title_style);
        } else {
            ui.text(c, title, title_style);
        }

        const meta = ui.div(c).row().gap(8).itemsCenter();
        defer meta.end();

        if (is_active_timer_task) {
            {
                const focusing = ui.div(c).row().gap(4).itemsCenter();
                defer focusing.end();
                {
                    const dot = ui.div(c).w(5).h(5).roundedFull().bg(t.hex(t.accent));
                    defer dot.end();
                }
                ui.text(c, "FOCUSING", .{
                    .size = 8.5,
                    .weight = .semibold,
                    .color = t.hex(t.accent),
                    .tracking = 1.1,
                });
            }
        }

        if (item.pomodoros_spent > 0 or item.pomodoros_estimated > 1) {
            ui.text(c, c.print("{d}/{d} sessions", .{ item.pomodoros_spent, item.pomodoros_estimated }), .{
                .size = 10,
                .color = t.hex(t.text_muted),
                .tabular = true,
            });
        }

        // Priority badge: click to cycle.
        {
            const badge = ui.div(c)
                .row()
                .px(7)
                .py(2)
                .rounded(6)
                .bg(t.soft(prio_color, 0.11))
                .gap(4)
                .itemsCenter()
                .hover(t.soft(prio_color, 0.22));
            defer badge.end();
            if (badge.clicked()) {
                const next_prio: Priority = switch (item.priority) {
                    .low => .normal,
                    .normal => .high,
                    .high => .urgent,
                    .urgent => .low,
                };
                state.todos.setPriority(index, next_prio);
            }
            {
                const dot = ui.div(c).w(4).h(4).roundedFull().circular().bg(t.hex(prio_color));
                defer dot.end();
            }
            ui.text(c, kit.priorityLabel(item.priority), .{
                .size = 9,
                .weight = .semibold,
                .color = t.hex(prio_color),
            });
        }
    }

    // Link / focus action
    {
        const link_btn = ui.div(c)
            .row()
            .px(9)
            .py(5)
            .rounded(8)
            .gap(5)
            .itemsCenter()
            .bg(if (is_active_timer_task) t.soft(t.accent, 0.15) else t.hex(t.bg_input))
            .hover(t.soft(t.accent, 0.16));
        defer link_btn.end();
        if (link_btn.clicked()) {
            if (is_active_timer_task) {
                state.timer.active_todo_index = null;
            } else {
                state.timer.active_todo_index = index;
            }
        }
        ui.icon(c, if (is_active_timer_task) "checkmark" else "play.fill", .{
            .size = 9,
            .color = if (is_active_timer_task) t.hex(t.accent) else t.hex(t.text_muted),
        });
        ui.text(c, if (is_active_timer_task) "Linked" else "Focus", .{
            .size = 9.5,
            .weight = .semibold,
            .color = if (is_active_timer_task) t.hex(t.accent) else t.hex(t.text_muted),
        });
    }

    // Delete
    {
        const del_btn = ui.div(c)
            .w(30)
            .h(30)
            .rounded(8)
            .itemsCenter()
            .justifyCenter()
            .hover(t.soft(t.priority_urgent, 0.14));
        defer del_btn.end();
        if (del_btn.clicked()) {
            if (state.timer.active_todo_index) |idx| {
                if (idx == index) state.timer.active_todo_index = null else if (idx > index)
                    state.timer.active_todo_index = idx - 1;
            }
            state.todos.removeItem(index);
        }
        ui.icon(c, "trash", .{ .size = 13, .color = t.hex(t.text_muted) });
    }
}

fn emptyState(c: *ui.Context, t: colors.Palette, title: []const u8, subtitle: []const u8, icon_name: []const u8) void {
    const empty = ui.div(c).column().wFull().grow().itemsCenter().justifyCenter().gap(9).py(26);
    defer empty.end();

    {
        const mark = ui.div(c)
            .w(68)
            .h(68)
            .rounded(22)
            .bg(t.soft(t.accent, if (t.dark) 0.14 else 0.09))
            .itemsCenter()
            .justifyCenter()
            .shadow(.{ .color = t.soft(t.accent, 0.20), .blur = 26, .y = 10, .spread = -4 });
        defer mark.end();
        ui.icon(c, icon_name, .{ .size = 28, .color = t.hex(t.accent) });
    }

    ui.text(c, title, .{
        .size = 18,
        .weight = .bold,
        .color = t.hex(t.text_primary),
        .tracking = -0.2,
    });
    ui.text(c, subtitle, .{
        .size = 12,
        .color = t.hex(t.text_muted),
    });

    const hint = ui.div(c).row().gap(6).itemsCenter().pt(4);
    defer hint.end();
    ui.kbd(c, "Enter");
    ui.text(c, "adds a task", .{
        .size = 10,
        .color = t.hex(t.text_muted),
    });
}
