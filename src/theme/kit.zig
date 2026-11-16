/// Small shared building blocks for the "Focus Studio" look: page headers,
/// soft panels, dividers, icon buttons and stat cards.
const nanoui = @import("nanoui");
const ui = nanoui.ui;
const colors = @import("colors.zig");
const todo_state = @import("../todo/todo_state.zig");
const responsive = @import("../responsive.zig");

/// A page header. Returns the row so the caller can add actions on the right.
pub fn pageHeader(
    c: *ui.Context,
    t: colors.Palette,
    kicker_color: ui.Color,
    kicker: []const u8,
    title: []const u8,
    subtitle: []const u8,
) ui.Div {
    const compact = responsive.isCompact(c);
    const row = if (compact)
        ui.div(c).column().wFull().gap(4).pb(14)
    else
        ui.div(c).row().wFull().itemsEnd().justifyBetween().pb(20);
    {
        const col = ui.div(c).column().gap(4);
        defer col.end();
        ui.text(c, kicker, .{
            .size = 10,
            .weight = .semibold,
            .color = kicker_color,
            .tracking = 1.6,
        });
        ui.text(c, title, .{
            .size = if (compact) 24 else 28,
            .weight = .bold,
            .color = t.hex(t.text_primary),
            .tracking = -0.4,
        });
        ui.text(c, subtitle, .{
            .size = if (compact) 12 else 13,
            .color = t.hex(t.text_muted),
            .wrap = compact,
        });
    }
    return row;
}

/// The standard card surface: white (or charcoal), a hairline border and a
/// soft, slightly lifted shadow.
pub fn panel(c: *ui.Context, t: colors.Palette) ui.Div {
    return ui.div(c)
        .column()
        .wFull()
        .p(18)
        .rounded(20)
        .bg(t.hex(t.bg_card))
        .border(t.hex(t.border_subtle))
        .borderW(1)
        .gap(10)
        .shadow(.{
        .color = t.shadow(0.05, 0.5),
        .blur = 24,
        .y = 8,
        .spread = -4,
    });
}

/// A nested, quieter surface inside a panel.
pub fn innerCard(c: *ui.Context, t: colors.Palette) ui.Div {
    return ui.div(c)
        .column()
        .wFull()
        .p(12)
        .rounded(14)
        .bg(t.hex(t.bg_input))
        .gap(6);
}

pub fn divider(c: *ui.Context, t: colors.Palette) void {
    const line = ui.div(c).wFull().h(1).bg(t.hex(t.border_subtle));
    defer line.end();
}

/// The tiny uppercase label that introduces a group.
pub fn sectionLabel(c: *ui.Context, t: colors.Palette, label: []const u8) void {
    ui.text(c, label, .{
        .size = 10,
        .weight = .semibold,
        .color = t.hex(t.text_muted),
        .tracking = 1.4,
    });
}

/// A 42-point rounded icon button. Add the icon, then read `clicked`.
pub fn iconButton(c: *ui.Context, t: colors.Palette) ui.Div {
    return ui.div(c)
        .w(42)
        .h(42)
        .rounded(13)
        .bg(t.hex(t.bg_card))
        .border(t.hex(t.border))
        .borderW(1)
        .itemsCenter()
        .justifyCenter()
        .hover(t.hex(t.bg_hover))
        .shadow(.{
        .color = t.shadow(0.04, 0.4),
        .blur = 10,
        .y = 3,
    });
}

/// A small icon inside a tinted rounded square (decorative).
pub fn iconTile(c: *ui.Context, color: ui.Color, size: f32, name: []const u8, icon_size: f32) void {
    const box = ui.div(c)
        .w(size)
        .h(size)
        .rounded(size * 0.3)
        .bg(color.alpha(0.12))
        .itemsCenter()
        .justifyCenter();
    defer box.end();
    ui.icon(c, name, .{ .size = icon_size, .color = color });
}

/// A compact pill label. Returns the box so the caller can add an icon.
pub fn pill(c: *ui.Context, text: []const u8, color: ui.Color) ui.Div {
    const b = ui.div(c)
        .row()
        .px(9)
        .py(4)
        .roundedFull()
        .gap(5)
        .itemsCenter()
        .bg(color.alpha(0.10))
        .border(color.alpha(0.18))
        .borderW(1);
    ui.text(c, text, .{ .size = 10.5, .weight = .semibold, .color = color });
    return b;
}

pub fn priorityColor(t: colors.Palette, priority: todo_state.Priority) u32 {
    return switch (priority) {
        .urgent => t.priority_urgent,
        .high => t.priority_high,
        .normal => t.priority_normal,
        .low => t.priority_low,
    };
}

pub fn priorityLabel(priority: todo_state.Priority) []const u8 {
    return switch (priority) {
        .urgent => "Urgent",
        .high => "High",
        .normal => "Normal",
        .low => "Low",
    };
}

/// A big number card with an icon, a label and a supporting hint.
pub fn statCard(
    c: *ui.Context,
    t: colors.Palette,
    icon_name: []const u8,
    tint: u32,
    label: []const u8,
    value: []const u8,
    hint: []const u8,
    compact: bool,
) void {
    const card = ui.div(c)
        .column()
        .grow()
        .p(if (compact) 12 else 16)
        .rounded(18)
        .bg(t.hex(t.bg_card))
        .gap(10)
        .border(t.hex(t.border_subtle))
        .borderW(1)
        .shadow(.{
        .color = t.shadow(0.045, 0.45),
        .blur = 18,
        .y = 6,
        .spread = -4,
    });
    defer card.end();

    {
        const top = ui.div(c).row().wFull().itemsCenter().justifyBetween();
        defer top.end();
        iconTile(c, t.hex(tint), 32, icon_name, 16);
        const dot = ui.div(c).w(6).h(6).roundedFull().bg(t.soft(tint, 0.5));
        defer dot.end();
    }

    ui.text(c, value, .{
        .size = if (compact) 22 else 26,
        .weight = .bold,
        .color = t.hex(t.text_primary),
        .tracking = -0.5,
    });
    {
        const bottom = ui.div(c).column().gap(1);
        defer bottom.end();
        ui.text(c, label, .{ .size = 12, .weight = .semibold, .color = t.hex(t.text_secondary) });
        ui.text(c, hint, .{ .size = 10.5, .color = t.hex(t.text_muted) });
    }
}

/// A horizontal progress track. `value` is 0..1.
pub fn progressBar(c: *ui.Context, t: colors.Palette, value: f32, height: f32, color: ui.Color) void {
    const v = @max(0, @min(1, value));
    const track = ui.div(c)
        .row()
        .wFull()
        .h(height)
        .roundedFull()
        .bg(t.soft(t.text_primary, if (t.dark) 0.12 else 0.06))
        .clip();
    defer track.end();
    if (v > 0.001) {
        const fill = growBy(ui.div(c)
            .hFull()
            .roundedFull()
            .bg(color)
            .gradient(color.alpha(0.65)), v);
        defer fill.end();
    }
    if (v < 0.999) {
        const rest = growBy(ui.div(c).hFull(), 1 - v);
        defer rest.end();
    }
}

/// Div's `grow` only takes 1; some bars need a weighted share.
pub fn growBy(d: ui.Div, v: f32) ui.Div {
    d.c.node(d.index).style.grow = v;
    return d;
}
