/// App color palette — light-first "Focus Studio" look with tomato brand accent.
const nanoui = @import("nanoui");
const ui = nanoui.ui;

pub const Palette = struct {
    bg_primary: u32,
    bg_secondary: u32,
    bg_sidebar: u32,
    bg_sidebar_end: u32,
    bg_card: u32,
    bg_elevated: u32,
    bg_input: u32,
    bg_hover: u32,

    accent: u32,
    accent_hover: u32,
    accent_soft: u32,
    accent_warm: u32,
    accent_green: u32,
    accent_teal: u32,
    accent_blue: u32,

    text_primary: u32,
    text_secondary: u32,
    text_muted: u32,
    text_on_accent: u32,

    sidebar_text: u32,
    sidebar_muted: u32,
    sidebar_line: u32,

    priority_urgent: u32,
    priority_high: u32,
    priority_normal: u32,
    priority_low: u32,

    border: u32,
    border_subtle: u32,
    dark: bool,

    pub fn phaseAccent(self: Palette, phase: TimerPhase) u32 {
        return switch (phase) {
            .idle => self.accent,
            .working => self.accent,
            .short_break => self.accent_teal,
            .long_break => self.accent_blue,
        };
    }

    pub fn timerText(self: Palette, phase: TimerPhase) u32 {
        return switch (phase) {
            .idle => self.text_primary,
            .working => self.accent,
            .short_break => self.accent_teal,
            .long_break => self.accent_blue,
        };
    }

    pub fn hex(self: Palette, field: u32) ui.Color {
        _ = self;
        return .hex(@truncate(field));
    }

    pub fn soft(self: Palette, field: u32, a: f32) ui.Color {
        return self.hex(field).alpha(a);
    }

    /// The soft wash used behind a card, tinted by the current phase.
    pub fn cardTint(self: Palette, field: u32) ui.Color {
        return self.soft(field, if (self.dark) 0.10 else 0.05);
    }

    /// A drop shadow: black in both themes, deeper on dark surfaces where a
    /// light shadow would read as a glow.
    pub fn shadow(self: Palette, light_alpha: f32, dark_alpha: f32) ui.Color {
        return ui.Color.black.alpha(if (self.dark) dark_alpha else light_alpha);
    }
};

/// Cool mist canvas + tomato focus accent (not purple, not cream/terracotta).
pub const light: Palette = .{
    .bg_primary = 0xf4f6fa,
    .bg_secondary = 0xedf0f6,
    .bg_sidebar = 0x12141b,
    .bg_sidebar_end = 0x1a1d26,
    .bg_card = 0xffffff,
    .bg_elevated = 0xffffff,
    .bg_input = 0xf0f3f8,
    .bg_hover = 0xe9edf4,
    .accent = 0xe8455b,
    .accent_hover = 0xd3344b,
    .accent_soft = 0xfdecef,
    .accent_warm = 0xff8a5b,
    .accent_green = 0x17a673,
    .accent_teal = 0x0e9f9a,
    .accent_blue = 0x3b82f6,
    .text_primary = 0x151823,
    .text_secondary = 0x596274,
    .text_muted = 0x8c95a6,
    .text_on_accent = 0xffffff,
    .sidebar_text = 0xeceff5,
    .sidebar_muted = 0x7f889a,
    .sidebar_line = 0x262a35,
    .priority_urgent = 0xe5484d,
    .priority_high = 0xf76b15,
    .priority_normal = 0x7c8aa0,
    .priority_low = 0xaab4c4,
    .border = 0xdfe4ec,
    .border_subtle = 0xecf0f6,
    .dark = false,
};

/// Charcoal surfaces (not navy/purple) with the same tomato brand.
pub const dark: Palette = .{
    .bg_primary = 0x0d0f14,
    .bg_secondary = 0x12151b,
    .bg_sidebar = 0x080a0e,
    .bg_sidebar_end = 0x11141b,
    .bg_card = 0x161a22,
    .bg_elevated = 0x1d222c,
    .bg_input = 0x202631,
    .bg_hover = 0x272e3b,
    .accent = 0xff5c6e,
    .accent_hover = 0xff7a89,
    .accent_soft = 0x3a1a22,
    .accent_warm = 0xffa36c,
    .accent_green = 0x30d18a,
    .accent_teal = 0x2dd4bf,
    .accent_blue = 0x6aa6ff,
    .text_primary = 0xf2f4f8,
    .text_secondary = 0xa2abbc,
    .text_muted = 0x6e7889,
    .text_on_accent = 0xffffff,
    .sidebar_text = 0xedf0f6,
    .sidebar_muted = 0x6d7688,
    .sidebar_line = 0x1f2530,
    .priority_urgent = 0xff6b6b,
    .priority_high = 0xffa94d,
    .priority_normal = 0x94a3b8,
    .priority_low = 0x64748b,
    .border = 0x2a3140,
    .border_subtle = 0x1f2530,
    .dark = true,
};

pub fn palette(is_dark: bool) Palette {
    return if (is_dark) dark else light;
}

/// nanoui Theme so built-in widgets (toggle, text field, progress) match the app.
pub fn nanouiTheme(is_dark: bool) ui.Theme {
    const p = palette(is_dark);
    return .{
        .dark = is_dark,
        .background = .hex(@truncate(p.bg_primary)),
        .surface = .hex(@truncate(p.bg_card)),
        .surface_hover = .hex(@truncate(p.bg_hover)),
        .text = .hex(@truncate(p.text_primary)),
        .muted = .hex(@truncate(p.text_muted)),
        .border = .hex(@truncate(p.border)),
        .accent = .hex(@truncate(p.accent)),
        .accent_hover = .hex(@truncate(p.accent_hover)),
        .accent_text = .hex(@truncate(p.text_on_accent)),
        .track = .hex(@truncate(p.bg_input)),
        .knob = if (is_dark) .hex(@truncate(p.text_primary)) else .white,
        .danger = .hex(@truncate(p.priority_urgent)),
        .success = .hex(@truncate(p.accent_green)),
        .shadow = if (is_dark) .{ .a = 0.45 } else .{ .a = 0.10 },
    };
}

pub const TimerPhase = enum {
    idle,
    working,
    short_break,
    long_break,
};
