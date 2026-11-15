/// Settings — user-configurable preferences.
/// All durations stored in minutes for readability; convert to ms when needed.
pub const SettingsState = struct {
    // ── Timer durations ───────────────────────────────────────────────────────
    work_min: u32 = 25,
    short_break_min: u32 = 5,
    long_break_min: u32 = 15,
    /// Number of work sessions before a long break
    pomodoros_until_long_break: u32 = 4,

    // ── Automation ────────────────────────────────────────────────────────────
    /// Automatically advance to the next phase when the timer ends
    auto_start_breaks: bool = true,
    /// Automatically start working after a break
    auto_start_pomodoros: bool = false,

    // ── Sound & notifications ─────────────────────────────────────────────────
    sound_enabled: bool = true,

    // ── Appearance ────────────────────────────────────────────────────────────
    /// Follows OS dark/light mode preference if true
    follow_system_theme: bool = true,
    dark_mode: bool = false,

    // ── Helpers ───────────────────────────────────────────────────────────────

    pub fn workMs(self: SettingsState) u64 {
        return @as(u64, self.work_min) * 60 * 1000;
    }

    pub fn shortBreakMs(self: SettingsState) u64 {
        return @as(u64, self.short_break_min) * 60 * 1000;
    }

    pub fn longBreakMs(self: SettingsState) u64 {
        return @as(u64, self.long_break_min) * 60 * 1000;
    }

    /// Clamp and increment work duration in minutes (1–90 range).
    pub fn incrementWork(self: *SettingsState) void {
        if (self.work_min < 90) self.work_min += 1;
    }
    pub fn decrementWork(self: *SettingsState) void {
        if (self.work_min > 1) self.work_min -= 1;
    }

    pub fn incrementShortBreak(self: *SettingsState) void {
        if (self.short_break_min < 30) self.short_break_min += 1;
    }
    pub fn decrementShortBreak(self: *SettingsState) void {
        if (self.short_break_min > 1) self.short_break_min -= 1;
    }

    pub fn incrementLongBreak(self: *SettingsState) void {
        if (self.long_break_min < 60) self.long_break_min += 1;
    }
    pub fn decrementLongBreak(self: *SettingsState) void {
        if (self.long_break_min > 1) self.long_break_min -= 1;
    }
};
