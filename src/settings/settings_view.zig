const nanoui = @import("nanoui");
const ui = nanoui.ui;
const AppState = @import("../app_state.zig").AppState;
const colors = @import("../theme/colors.zig");
const kit = @import("../theme/kit.zig");

pub fn view(state: *AppState, c: *ui.Context) void {
    const t = colors.palette(state.settings.dark_mode);

    const root = ui.div(c).column().sizeFull().px(30).pt(26).pb(24);
    defer root.end();

    {
        const header = kit.pageHeader(c, t, t.hex(t.accent), "PREFERENCES", "Settings", "Shape a rhythm that fits your day.");
        defer header.end();
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

        {
            const row = ui.div(c).row().wFull().gap(14).itemsStretch();
            defer row.end();

            durationsCard(state, c, t);

            {
                const right = ui.div(c).column().w(274).gap(14);
                defer right.end();
                automationCard(state, c, t);
                appearanceCard(state, c, t);
            }
        }

        aboutCard(c, t);
    }
}

fn durationsCard(state: *AppState, c: *ui.Context, t: colors.Palette) void {
    const card = kit.panel(c, t).grow();
    defer card.end();

    kit.sectionLabel(c, t, "TIMER");

    {
        const intro = ui.div(c).column().gap(2).pb(2);
        defer intro.end();
        ui.text(c, "Session lengths", .{
            .size = 16,
            .weight = .semibold,
            .color = t.hex(t.text_primary),
            .tracking = -0.2,
        });
        ui.text(c, "Fine-tune each phase of your cycle.", .{
            .size = 10.5,
            .color = t.hex(t.text_muted),
        });
    }

    durationRow(c, t, "Focus duration", "Your deep work block", &state.settings.work_min, 1, 90, "min");
    kit.divider(c, t);
    durationRow(c, t, "Short break", "A quick reset between sessions", &state.settings.short_break_min, 1, 30, "min");
    kit.divider(c, t);
    durationRow(c, t, "Long break", "Step away a little longer", &state.settings.long_break_min, 1, 60, "min");
    kit.divider(c, t);
    durationRow(c, t, "Long break interval", "Sessions before a long break", &state.settings.pomodoros_until_long_break, 1, 10, "sessions");
}

fn durationRow(
    c: *ui.Context,
    t: colors.Palette,
    label: []const u8,
    hint: []const u8,
    value: *u32,
    min_val: u32,
    max_val: u32,
    unit: []const u8,
) void {
    const row = ui.div(c).row().wFull().itemsCenter().justifyBetween().py(7);
    defer row.end();

    {
        const col = ui.div(c).column().gap(1);
        defer col.end();
        ui.text(c, label, .{
            .size = 13,
            .weight = .medium,
            .color = t.hex(t.text_primary),
        });
        ui.text(c, hint, .{
            .size = 10,
            .color = t.hex(t.text_muted),
        });
    }

    stepper(c, t, value, min_val, max_val, unit);
}

fn stepper(c: *ui.Context, t: colors.Palette, value: *u32, min_val: u32, max_val: u32, unit: []const u8) void {
    const group = ui.div(c)
        .row()
        .p(3)
        .rounded(11)
        .bg(t.hex(t.bg_secondary))
        .border(t.hex(t.border_subtle))
        .borderW(1)
        .gap(2)
        .itemsCenter();
    defer group.end();

    {
        const minus = ui.div(c)
            .w(27)
            .h(27)
            .rounded(8)
            .itemsCenter()
            .justifyCenter()
            .hover(t.hex(t.bg_hover))
            .opacity(if (value.* <= min_val) 0.35 else 1.0);
        defer minus.end();
        if (minus.clicked() and value.* > min_val) value.* -= 1;
        ui.icon(c, "minus", .{ .size = 12, .color = t.hex(t.text_secondary) });
    }

    {
        const readout = ui.div(c).row().minW(70).itemsCenter().justifyCenter().gap(3);
        defer readout.end();
        ui.text(c, c.print("{d}", .{value.*}), .{
            .size = 13,
            .weight = .semibold,
            .color = t.hex(t.accent),
            .tabular = true,
        });
        ui.text(c, unit, .{
            .size = 9.5,
            .color = t.hex(t.text_muted),
        });
    }

    {
        const plus = ui.div(c)
            .w(27)
            .h(27)
            .rounded(8)
            .itemsCenter()
            .justifyCenter()
            .hover(t.hex(t.bg_hover))
            .opacity(if (value.* >= max_val) 0.35 else 1.0);
        defer plus.end();
        if (plus.clicked() and value.* < max_val) value.* += 1;
        ui.icon(c, "plus", .{ .size = 12, .color = t.hex(t.text_secondary) });
    }
}

fn automationCard(state: *AppState, c: *ui.Context, t: colors.Palette) void {
    const card = kit.panel(c, t);
    defer card.end();

    kit.sectionLabel(c, t, "AUTOMATION");

    toggleRow(c, t, "Auto-start breaks", "Begin the break timer when focus ends", &state.settings.auto_start_breaks);
    kit.divider(c, t);
    toggleRow(c, t, "Auto-start pomodoros", "Begin focus again when a break ends", &state.settings.auto_start_pomodoros);
}

fn toggleRow(c: *ui.Context, t: colors.Palette, title: []const u8, subtitle: []const u8, value: *bool) void {
    const row = ui.div(c).row().wFull().itemsCenter().justifyBetween().py(6).gap(10);
    defer row.end();
    {
        const col = ui.div(c).column().grow().gap(1);
        defer col.end();
        ui.text(c, title, .{
            .size = 12.5,
            .weight = .medium,
            .color = t.hex(t.text_primary),
        });
        ui.text(c, subtitle, .{
            .size = 9.5,
            .color = t.hex(t.text_muted),
            .wrap = true,
        });
    }
    _ = ui.toggle(c, "", value);
}

fn appearanceCard(state: *AppState, c: *ui.Context, t: colors.Palette) void {
    const card = kit.panel(c, t);
    defer card.end();

    kit.sectionLabel(c, t, "APPEARANCE");

    ui.text(c, "Theme", .{
        .size = 13,
        .weight = .medium,
        .color = t.hex(t.text_primary),
    });

    themeTile(state, c, t, false);
    themeTile(state, c, t, true);
}

fn themeTile(state: *AppState, c: *ui.Context, t: colors.Palette, is_dark: bool) void {
    const p = colors.palette(is_dark);
    const selected = state.settings.dark_mode == is_dark;

    const tile = ui.div(c)
        .row()
        .wFull()
        .p(7)
        .rounded(11)
        .gap(9)
        .itemsCenter()
        .bg(if (selected) t.soft(t.accent, if (t.dark) 0.13 else 0.08) else t.hex(t.bg_secondary))
        .border(if (selected) t.soft(t.accent, 0.55) else t.hex(t.border_subtle))
        .borderW(if (selected) 1.5 else 1)
        .hover(t.hex(t.bg_hover));
    defer tile.end();
    if (tile.clicked()) state.settings.dark_mode = is_dark;

    // A tiny preview of the theme.
    {
        const preview = ui.div(c)
            .row()
            .w(46)
            .h(32)
            .rounded(6)
            .bg(p.hex(p.bg_primary))
            .border(p.hex(p.border))
            .borderW(1)
            .clip();
        defer preview.end();

        {
            const rail = ui.div(c).w(10).hFull().bg(p.hex(p.bg_sidebar));
            defer rail.end();
        }

        {
            const body = ui.div(c).column().grow().p(4).gap(3);
            defer body.end();

            {
                const bar = ui.div(c).wFull().h(3).roundedFull().bg(p.soft(p.text_primary, 0.22));
                defer bar.end();
            }

            {
                const card = ui.div(c)
                    .row()
                    .wFull()
                    .h(11)
                    .rounded(3)
                    .bg(p.hex(p.bg_card))
                    .border(p.hex(p.border_subtle))
                    .borderW(1)
                    .px(3)
                    .itemsCenter();
                defer card.end();
                {
                    const dot = ui.div(c).w(4).h(4).roundedFull().bg(p.hex(p.accent));
                    defer dot.end();
                }
            }
        }
    }

    {
        const words = ui.div(c).column().grow().gap(1);
        defer words.end();
        ui.text(c, if (is_dark) "Dark" else "Light", .{
            .size = 11.5,
            .weight = if (selected) .semibold else .medium,
            .color = t.hex(t.text_primary),
        });
        ui.text(c, if (is_dark) "Charcoal" else "Cool mist", .{
            .size = 9,
            .color = t.hex(t.text_muted),
        });
    }

    {
        const check = ui.div(c)
            .w(17)
            .h(17)
            .roundedFull()
            .bg(if (selected) t.hex(t.accent) else ui.Color.transparent)
            .border(if (selected) t.hex(t.accent) else t.hex(t.border))
            .borderW(1)
            .itemsCenter()
            .justifyCenter();
        defer check.end();
        if (selected) {
            ui.icon(c, "checkmark", .{ .size = 9, .weight = .bold, .color = t.hex(t.text_on_accent) });
        }
    }
}

fn aboutCard(c: *ui.Context, t: colors.Palette) void {
    const card = ui.div(c)
        .row()
        .wFull()
        .p(16)
        .rounded(18)
        .gap(12)
        .itemsCenter()
        .bg(t.hex(t.bg_card))
        .border(t.hex(t.border_subtle))
        .borderW(1)
        .shadow(.{
            .color = t.shadow(0.035, 0.4),
            .blur = 16,
            .y = 4,
        });
    defer card.end();

    {
        const mark = ui.div(c)
            .w(40)
            .h(40)
            .rounded(12)
            .bg(t.hex(t.accent))
            .gradient(t.hex(t.accent_warm))
            .itemsCenter()
            .justifyCenter()
            .shadow(.{ .color = t.soft(t.accent, 0.32), .blur = 14, .y = 5 });
        defer mark.end();
        ui.icon(c, "gauge.with.dots.needle.33percent", .{
            .size = 19,
            .color = t.hex(t.text_on_accent),
        });
    }

    {
        const words = ui.div(c).column().grow().gap(1);
        defer words.end();
        ui.text(c, "Focus Studio", .{
            .size = 13.5,
            .weight = .semibold,
            .color = t.hex(t.text_primary),
        });
        ui.text(c, "A calm Pomodoro timer and task list, built with Zig + nanoui.", .{
            .size = 10,
            .color = t.hex(t.text_muted),
        });
    }

    const version = kit.pill(c, "v0.1.0", t.hex(t.text_muted));
    defer version.end();
}
