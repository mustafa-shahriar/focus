const std = @import("std");
const pt = @import("../platform_time.zig");

/// Maximum number of todo items supported.
pub const MAX_TODOS = 128;
/// Maximum text length per item (bytes, UTF-8).
pub const MAX_TEXT_LEN = 256;

pub const Priority = enum(u8) {
    low = 0,
    normal = 1,
    high = 2,
    urgent = 3,
};

pub const TodoItem = struct {
    id: u64,
    text: [MAX_TEXT_LEN]u8 = undefined,
    text_len: usize = 0,
    completed: bool = false,
    /// How many pomodoros have been spent on this item
    pomodoros_spent: u32 = 0,
    /// User estimate of how many pomodoros it will take
    pomodoros_estimated: u32 = 1,
    created_at_ms: i64 = 0,
    priority: Priority = .normal,

    pub fn textSlice(self: *const TodoItem) []const u8 {
        return self.text[0..self.text_len];
    }
};

pub const Filter = enum {
    all,
    active,
    completed,
};

pub const TodoState = struct {
    items: [MAX_TODOS]TodoItem = undefined,
    item_count: usize = 0,
    next_id: u64 = 1,

    /// Text currently typed in the new-todo input field
    input_buffer: [MAX_TEXT_LEN]u8 = undefined,
    input_len: usize = 0,

    filter: Filter = .all,

    // ── CRUD ──────────────────────────────────────────────────────────────────

    pub fn addItem(self: *TodoState, text: []const u8) void {
        if (self.item_count >= MAX_TODOS) return;
        if (text.len == 0) return;

        const len = @min(text.len, MAX_TEXT_LEN);
        var item = TodoItem{
            .id = self.next_id,
            .text_len = len,
            .created_at_ms = pt.milliTimestamp(),
        };
        @memcpy(item.text[0..len], text[0..len]);

        self.items[self.item_count] = item;
        self.item_count += 1;
        self.next_id += 1;
    }

    pub fn toggleItem(self: *TodoState, index: usize) void {
        if (index >= self.item_count) return;
        self.items[index].completed = !self.items[index].completed;
    }

    pub fn removeItem(self: *TodoState, index: usize) void {
        if (index >= self.item_count) return;
        // Shift items left to fill the gap
        var i = index;
        while (i + 1 < self.item_count) : (i += 1) {
            self.items[i] = self.items[i + 1];
        }
        self.item_count -= 1;
    }

    pub fn incrementPomodoro(self: *TodoState, index: usize) void {
        if (index >= self.item_count) return;
        self.items[index].pomodoros_spent += 1;
    }

    pub fn setPriority(self: *TodoState, index: usize, priority: Priority) void {
        if (index >= self.item_count) return;
        self.items[index].priority = priority;
    }

    // ── Queries ───────────────────────────────────────────────────────────────

    pub fn countActive(self: *const TodoState) usize {
        var count: usize = 0;
        for (self.items[0..self.item_count]) |item| {
            if (!item.completed) count += 1;
        }
        return count;
    }

    pub fn countCompleted(self: *const TodoState) usize {
        return self.item_count - self.countActive();
    }

    pub fn totalPomodoros(self: *const TodoState) u32 {
        var total: u32 = 0;
        for (self.items[0..self.item_count]) |item| {
            total += item.pomodoros_spent;
        }
        return total;
    }

    /// Returns true if the item at index matches the current filter.
    pub fn itemVisible(self: *const TodoState, index: usize) bool {
        if (index >= self.item_count) return false;
        return switch (self.filter) {
            .all => true,
            .active => !self.items[index].completed,
            .completed => self.items[index].completed,
        };
    }

    // ── Input helpers ─────────────────────────────────────────────────────────

    pub fn inputSlice(self: *const TodoState) []const u8 {
        return self.input_buffer[0..self.input_len];
    }

    pub fn clearInput(self: *TodoState) void {
        self.input_len = 0;
    }

    /// Submit the current input as a new todo item.
    /// Returns true if an item was added.
    pub fn submitInput(self: *TodoState) bool {
        const text = self.inputSlice();
        // Trim leading/trailing spaces
        const trimmed = std.mem.trim(u8, text, " \t");
        if (trimmed.len == 0) return false;
        self.addItem(trimmed);
        self.clearInput();
        return true;
    }
};

// ── Tests ─────────────────────────────────────────────────────────────────────

test "add and remove todo" {
    var state = TodoState{};
    state.addItem("Write tests");
    try @import("std").testing.expect(state.item_count == 1);
    try @import("std").testing.expectEqualStrings("Write tests", state.items[0].textSlice());
    state.removeItem(0);
    try @import("std").testing.expect(state.item_count == 0);
}

test "toggle todo" {
    var state = TodoState{};
    state.addItem("Design UI");
    try @import("std").testing.expect(!state.items[0].completed);
    state.toggleItem(0);
    try @import("std").testing.expect(state.items[0].completed);
    state.toggleItem(0);
    try @import("std").testing.expect(!state.items[0].completed);
}

test "count active and completed" {
    var state = TodoState{};
    state.addItem("Task A");
    state.addItem("Task B");
    state.toggleItem(0); // complete Task A
    try @import("std").testing.expect(state.countActive() == 1);
    try @import("std").testing.expect(state.countCompleted() == 1);
}

test "submit input creates todo" {
    var state = TodoState{};
    @memcpy(state.input_buffer[0..8], "New task");
    state.input_len = 8;
    const added = state.submitInput();
    try @import("std").testing.expect(added);
    try @import("std").testing.expect(state.item_count == 1);
    try @import("std").testing.expect(state.input_len == 0);
}
