const std = @import("std");
const pt = @import("../platform_time.zig");

/// Session history entry — one completed pomodoro session.
pub const SessionEntry = struct {
    /// Unix timestamp (ms) when session completed
    completed_at_ms: i64,
    /// Duration of the session in minutes
    duration_min: u32,
    /// ID of the linked todo (0 = no link)
    todo_id: u64,
};

pub const MAX_HISTORY = 1000;
pub const HISTORY_DAYS = 7;

pub const StatsState = struct {
    // ── All-time ─────────────────────────────────────────────────────────────
    total_pomodoros: u32 = 0,
    total_focus_min: u32 = 0,
    current_streak: u32 = 0,
    best_streak: u32 = 0,

    // ── Today ─────────────────────────────────────────────────────────────────
    todays_pomodoros: u32 = 0,
    todays_focus_min: u32 = 0,

    // ── Last 7 days (index 0 = oldest, index 6 = today) ───────────────────────
    daily_pomodoros: [HISTORY_DAYS]u32 = std.mem.zeroes([HISTORY_DAYS]u32),
    daily_focus_min: [HISTORY_DAYS]u32 = std.mem.zeroes([HISTORY_DAYS]u32),

    // ── Session log ───────────────────────────────────────────────────────────
    history: [MAX_HISTORY]SessionEntry = undefined,
    history_len: usize = 0,
    /// The day index (std.time.timestamp / 86400) for index 6 of daily arrays
    today_day_index: i64 = 0,

    // ── API ───────────────────────────────────────────────────────────────────

    /// Record a completed pomodoro. Call after TimerState.onPhaseComplete for .working.
    pub fn recordPomodoro(self: *StatsState, duration_min: u32, todo_id: u64) void {
        const now_ms = pt.milliTimestamp();
        const today = @divTrunc(pt.timestamp(), (60 * 60 * 24));

        // Shift daily arrays if day changed
        self.maybeShiftDay(today);

        // Record in daily arrays
        self.daily_pomodoros[HISTORY_DAYS - 1] += 1;
        self.daily_focus_min[HISTORY_DAYS - 1] += duration_min;

        // Update totals
        self.total_pomodoros += 1;
        self.total_focus_min += duration_min;
        self.todays_pomodoros += 1;
        self.todays_focus_min += duration_min;

        // Update streak
        if (self.todays_pomodoros == 1) {
            // First pomodoro of today — check if yesterday had any
            self.current_streak += 1;
            if (self.current_streak > self.best_streak) {
                self.best_streak = self.current_streak;
            }
        }

        // Add to history log
        if (self.history_len < MAX_HISTORY) {
            self.history[self.history_len] = .{
                .completed_at_ms = now_ms,
                .duration_min = duration_min,
                .todo_id = todo_id,
            };
            self.history_len += 1;
        }
    }

    /// Returns this week's total pomodoros.
    pub fn weeklyPomodoros(self: *const StatsState) u32 {
        var total: u32 = 0;
        for (self.daily_pomodoros) |d| total += d;
        return total;
    }

    /// Returns this week's total focus minutes.
    pub fn weeklyFocusMin(self: *const StatsState) u32 {
        var total: u32 = 0;
        for (self.daily_focus_min) |d| total += d;
        return total;
    }

    /// Max pomodoros in any single day this week (for chart scaling).
    pub fn maxDailyPomodoros(self: *const StatsState) u32 {
        var max: u32 = 1;
        for (self.daily_pomodoros) |d| {
            if (d > max) max = d;
        }
        return max;
    }

    fn maybeShiftDay(self: *StatsState, today: i64) void {
        if (self.today_day_index == 0) {
            self.today_day_index = today;
            return;
        }
        const days_elapsed = today - self.today_day_index;
        if (days_elapsed <= 0) return;

        // Reset streak if we skipped days
        if (days_elapsed > 1 and self.todays_pomodoros == 0) {
            self.current_streak = 0;
        }

        // Shift arrays left
        const shift = @min(@as(usize, @intCast(days_elapsed)), HISTORY_DAYS);
        var i: usize = 0;
        while (i + shift < HISTORY_DAYS) : (i += 1) {
            self.daily_pomodoros[i] = self.daily_pomodoros[i + shift];
            self.daily_focus_min[i] = self.daily_focus_min[i + shift];
        }
        // Zero out new days
        while (i < HISTORY_DAYS) : (i += 1) {
            self.daily_pomodoros[i] = 0;
            self.daily_focus_min[i] = 0;
        }

        self.today_day_index = today;
        self.todays_pomodoros = 0;
        self.todays_focus_min = 0;
    }
};
