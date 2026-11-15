const std = @import("std");
const pt = @import("../platform_time.zig");

/// Timer phase — represents which stage of the Pomodoro cycle we're in.
pub const Phase = enum {
    idle,
    working,
    short_break,
    long_break,
};

/// Full timer state machine.
/// tick() must be called each frame when is_running == true.
pub const TimerState = struct {
    phase: Phase = .idle,
    /// Remaining time in milliseconds
    remaining_ms: u64 = 25 * 60 * 1000,
    /// Total duration of current phase in milliseconds
    total_ms: u64 = 25 * 60 * 1000,
    /// Number of completed work pomodoros in the current cycle
    completed_in_cycle: u32 = 0,
    /// All-time pomodoro count for this session
    total_completed: u32 = 0,
    is_running: bool = false,
    /// Wall-clock time of last tick (nanoseconds). 0 = not started.
    last_tick_ns: i128 = 0,
    /// Set to true when a phase just completed (cleared after one frame)
    phase_just_completed: bool = false,
    /// Optional linked todo index (null = no task linked)
    active_todo_index: ?usize = null,

    // ── Controls ──────────────────────────────────────────────────────────────

    pub fn start(self: *TimerState) void {
        if (self.phase == .idle) {
            self.phase = .working;
        }
        self.is_running = true;
        self.last_tick_ns = 0; // reset delta on next tick
    }

    pub fn pause(self: *TimerState) void {
        self.is_running = false;
    }

    pub fn reset(self: *TimerState, work_ms: u64) void {
        self.is_running = false;
        self.phase = .idle;
        self.remaining_ms = work_ms;
        self.total_ms = work_ms;
        self.last_tick_ns = 0;
        self.phase_just_completed = false;
    }

    pub fn skip(self: *TimerState, settings: PhaseSettings) void {
        self.is_running = false;
        self.phase_just_completed = false;
        self.advancePhase(settings);
    }

    // ── Tick ─────────────────────────────────────────────────────────────────

    /// Call once per frame while is_running == true.
    /// Uses wall-clock delta to prevent drift.
    pub fn tick(self: *TimerState, settings: PhaseSettings) void {
        if (!self.is_running) return;

        const now = pt.nanoTimestamp();
        if (self.last_tick_ns == 0) {
            self.last_tick_ns = now;
            return;
        }

        const delta_ns: u64 = @intCast(now - self.last_tick_ns);
        const delta_ms: u64 = delta_ns / std.time.ns_per_ms;
        self.last_tick_ns = now;
        self.phase_just_completed = false;

        if (delta_ms >= self.remaining_ms) {
            self.remaining_ms = 0;
            self.onPhaseComplete(settings);
        } else {
            self.remaining_ms -= delta_ms;
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /// Returns progress as 0.0 (done) to 1.0 (full/start).
    pub fn progress(self: TimerState) f32 {
        if (self.total_ms == 0) return 0.0;
        return @as(f32, @floatFromInt(self.remaining_ms)) /
            @as(f32, @floatFromInt(self.total_ms));
    }

    /// Returns "MM:SS" formatted remaining time.
    pub fn formatRemaining(self: TimerState) [5]u8 {
        const total_secs = self.remaining_ms / 1000;
        const mins = total_secs / 60;
        const secs = total_secs % 60;
        var buf: [5]u8 = undefined;
        buf[0] = @intCast('0' + mins / 10);
        buf[1] = @intCast('0' + mins % 10);
        buf[2] = ':';
        buf[3] = @intCast('0' + secs / 10);
        buf[4] = @intCast('0' + secs % 10);
        return buf;
    }

    pub fn phaseLabel(self: TimerState) []const u8 {
        return switch (self.phase) {
            .idle => "Ready to Focus",
            .working => "Focus Time",
            .short_break => "Short Break",
            .long_break => "Long Break",
        };
    }

    pub fn phaseEmoji(self: TimerState) []const u8 {
        return switch (self.phase) {
            .idle => "🍅",
            .working => "🍅",
            .short_break => "☕",
            .long_break => "🌴",
        };
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    fn onPhaseComplete(self: *TimerState, settings: PhaseSettings) void {
        self.phase_just_completed = true;
        if (self.phase == .working) {
            self.completed_in_cycle += 1;
            self.total_completed += 1;
        }

        if (settings.auto_advance) {
            self.advancePhase(settings);
            self.is_running = settings.auto_start_next;
        } else {
            self.is_running = false;
            self.advancePhase(settings);
        }
    }

    fn advancePhase(self: *TimerState, settings: PhaseSettings) void {
        switch (self.phase) {
            .idle => {
                self.setPhase(.working, settings.work_ms);
            },
            .working => {
                if (self.completed_in_cycle >= settings.pomodoros_until_long_break) {
                    self.completed_in_cycle = 0;
                    self.setPhase(.long_break, settings.long_break_ms);
                } else {
                    self.setPhase(.short_break, settings.short_break_ms);
                }
            },
            .short_break, .long_break => {
                self.setPhase(.working, settings.work_ms);
            },
        }
    }

    fn setPhase(self: *TimerState, phase: Phase, duration_ms: u64) void {
        self.phase = phase;
        self.remaining_ms = duration_ms;
        self.total_ms = duration_ms;
        self.last_tick_ns = 0;
    }
};

/// Minimal settings passed to tick/skip/reset to avoid circular imports.
pub const PhaseSettings = struct {
    work_ms: u64 = 25 * 60 * 1000,
    short_break_ms: u64 = 5 * 60 * 1000,
    long_break_ms: u64 = 15 * 60 * 1000,
    pomodoros_until_long_break: u32 = 4,
    auto_advance: bool = true,
    auto_start_next: bool = false,
};

// ── Tests ─────────────────────────────────────────────────────────────────────

test "timer starts in idle phase" {
    const timer = TimerState{};
    try @import("std").testing.expect(timer.phase == .idle);
    try @import("std").testing.expect(!timer.is_running);
}

test "timer start transitions to working" {
    var timer = TimerState{};
    timer.start();
    try @import("std").testing.expect(timer.phase == .working);
    try @import("std").testing.expect(timer.is_running);
}

test "timer format remaining" {
    var timer = TimerState{};
    timer.remaining_ms = 25 * 60 * 1000;
    const formatted = timer.formatRemaining();
    try @import("std").testing.expectEqualStrings("25:00", &formatted);
}

test "timer progress is 1.0 at start" {
    const timer = TimerState{};
    try @import("std").testing.expect(timer.progress() == 1.0);
}

test "timer advances from working to short_break" {
    var timer = TimerState{};
    const settings = PhaseSettings{};
    timer.phase = .working;
    timer.remaining_ms = 0;
    timer.onPhaseComplete(settings);
    try @import("std").testing.expect(timer.phase == .short_break);
}
