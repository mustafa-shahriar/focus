const TimerState = @import("timer/timer_state.zig").TimerState;
const PhaseSettings = @import("timer/timer_state.zig").PhaseSettings;
const TodoState = @import("todo/todo_state.zig").TodoState;
const SettingsState = @import("settings/settings_state.zig").SettingsState;
const StatsState = @import("stats/stats_state.zig").StatsState;

/// Root application state — single source of truth for all app data.
/// Views are pure functions of this struct.
pub const AppState = struct {
    current_page: Page = .timer,

    timer: TimerState = .{},
    todos: TodoState = .{},
    settings: SettingsState = .{},
    stats: StatsState = .{},

    pub const Page = enum {
        timer,
        todos,
        stats,
        settings,
    };

    /// Returns a PhaseSettings derived from the current settings.
    pub fn phaseSettings(self: *const AppState) PhaseSettings {
        return .{
            .work_ms = self.settings.workMs(),
            .short_break_ms = self.settings.shortBreakMs(),
            .long_break_ms = self.settings.longBreakMs(),
            .pomodoros_until_long_break = self.settings.pomodoros_until_long_break,
            .auto_advance = self.settings.auto_start_breaks,
            .auto_start_next = self.settings.auto_start_pomodoros,
        };
    }
};
