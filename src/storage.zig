//! Keeping the app's state between launches.
//!
//! One JSON file in the platform's per-user data directory:
//!
//!   Windows  %APPDATA%\Pomodoro Focus\focus-state.json
//!   Linux    $XDG_DATA_HOME/Pomodoro Focus/focus-state.json
//!            (usually ~/.local/share/Pomodoro Focus/focus-state.json)
//!   Android  <app's internal files dir>/Pomodoro Focus/focus-state.json
//!
//! The directory comes from `nanoui.path(.data, ...)`, which knows each
//! platform. JSON (and not a database) because everything kept here is
//! tiny - at most 128 todos and 1000 history entries - and it needs no
//! extra dependency on any of the three targets.
//!
//! Writes go to a temporary file that is renamed over the real one, so a
//! crash or a power cut leaves either the old file or the new one, never
//! half of one. A file that doesn't parse is left alone and the app starts
//! with its defaults.
//!
//! Saving is automatic: each frame hashes the persisted fields (cheap) and
//! writes only when they changed. While the timer runs, its remaining time
//! is excluded from that hash (it changes every frame) and is written every
//! 15 seconds and whenever anything else changes instead. Closing the
//! window writes the latest state.

const std = @import("std");
const nanoui = @import("nanoui");

const AppState = @import("app_state.zig").AppState;
const SettingsState = @import("settings/settings_state.zig").SettingsState;
const TodoState = @import("todo/todo_state.zig").TodoState;
const TodoItem = @import("todo/todo_state.zig").TodoItem;
const Filter = @import("todo/todo_state.zig").Filter;
const Priority = @import("todo/todo_state.zig").Priority;
const MAX_TODOS = @import("todo/todo_state.zig").MAX_TODOS;
const MAX_TEXT_LEN = @import("todo/todo_state.zig").MAX_TEXT_LEN;
const StatsState = @import("stats/stats_state.zig").StatsState;
const MAX_HISTORY = @import("stats/stats_state.zig").MAX_HISTORY;
const HISTORY_DAYS = @import("stats/stats_state.zig").HISTORY_DAYS;
const Phase = @import("timer/timer_state.zig").Phase;
const pt = @import("platform_time.zig");

/// The folder under the platform's data directory.
pub const APP_NAME = "Pomodoro Focus";
/// The file inside it.
pub const FILE_NAME = "focus-state.json";
const TMP_NAME = "focus-state.json.tmp";
/// Bumped when the shape of the file changes; readers stay tolerant.
pub const VERSION: u32 = 1;

/// How often a running timer's remaining time is written.
const RUNNING_SAVE_MS: i64 = 15 * 1000;
/// Never retry a failing write more often than this.
const RETRY_MS: i64 = 1000;
/// A file bigger than this is not ours.
const MAX_FILE_BYTES = 8 << 20;

// -- Settings limits, also the ones the settings page allows ----------------

const WORK_MIN: u32 = 1;
const WORK_MAX: u32 = 90;
const SHORT_BREAK_MAX: u32 = 30;
const LONG_BREAK_MAX: u32 = 60;
const CYCLE_MAX: u32 = 12;

/// The state file this run uses, if it could be opened.
pub const Store = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    /// The app's data directory.
    dir: []u8,
    /// `<dir>/focus-state.json` and the temporary file beside it.
    path: []u8,
    tmp: []u8,
    /// Fingerprint of the last successful write; 0 until there is one.
    saved_fp: u64 = 0,
    /// When the last successful write happened.
    saved_ms: i64 = 0,
    /// When a write was last tried, successful or not.
    tried_ms: i64 = 0,
    /// Whether a failing write has been logged already.
    warned: bool = false,

    /// Resolves the data directory and reads the state saved there over
    /// `state`. Missing files, and ones that don't parse, leave `state` as
    /// it came in.
    pub fn open(init: std.process.Init, state: *AppState) !Store {
        const gpa = init.gpa;
        const dir = try nanoui.path(gpa, .data, APP_NAME);
        errdefer gpa.free(dir);
        const path = try std.fs.path.join(gpa, &.{ dir, FILE_NAME });
        errdefer gpa.free(path);
        const tmp = try std.fs.path.join(gpa, &.{ dir, TMP_NAME });
        errdefer gpa.free(tmp);

        var opened: Store = .{ .gpa = gpa, .io = init.io, .dir = dir, .path = path, .tmp = tmp };
        opened.load(state);
        return opened;
    }

    pub fn deinit(s: *Store) void {
        s.gpa.free(s.dir);
        s.gpa.free(s.path);
        s.gpa.free(s.tmp);
    }

    /// Writes `state` now, if anything worth writing changed.
    pub fn maybeSave(s: *Store, state: *const AppState) void {
        const fp = fingerprint(state);
        const now = pt.milliTimestamp();
        const due_while_running = state.timer.is_running and
            now - s.saved_ms >= RUNNING_SAVE_MS;
        if (fp == s.saved_fp and !due_while_running) return;
        // A failing disk (or a read-only folder) must not cost a write
        // attempt on every frame.
        if (s.tried_ms != 0 and now - s.tried_ms < RETRY_MS) return;
        s.tried_ms = now;
        s.write(state, fp) catch |e| s.report(e);
    }

    /// Writes `state` now, whether or not it looks changed. Failures are
    /// logged once and otherwise ignored: a session must not end in a crash
    /// because the file couldn't be written.
    pub fn save(s: *Store, state: *const AppState) void {
        s.write(state, fingerprint(state)) catch |e| s.report(e);
    }

    fn report(s: *Store, e: anyerror) void {
        if (s.warned) return;
        s.warned = true;
        std.log.warn("focus: {s} not written: {t}", .{ s.path, e });
    }

    fn dataDir(s: *Store) !std.Io.Dir {
        return std.Io.Dir.openDirAbsolute(s.io, s.dir, .{}) catch |e| switch (e) {
            error.FileNotFound => {
                std.Io.Dir.createDirAbsolute(s.io, s.dir, .default_dir) catch {};
                return std.Io.Dir.openDirAbsolute(s.io, s.dir, .{});
            },
            else => |err| return err,
        };
    }

    fn write(s: *Store, state: *const AppState, fp: u64) !void {
        var out: std.Io.Writer.Allocating = .init(s.gpa);
        defer out.deinit();
        try encode(&out.writer, state);

        const dir = try s.dataDir();
        defer dir.close(s.io);

        try dir.writeFile(s.io, .{ .sub_path = TMP_NAME, .data = out.written() });
        dir.rename(TMP_NAME, dir, FILE_NAME, s.io) catch |e| {
            dir.deleteFile(s.io, TMP_NAME) catch {};
            return e;
        };
        s.saved_fp = fp;
        s.saved_ms = pt.milliTimestamp();
        s.warned = false;
    }

    fn load(s: *Store, state: *AppState) void {
        const dir = std.Io.Dir.openDirAbsolute(s.io, s.dir, .{}) catch |e| switch (e) {
            error.FileNotFound => return,
            else => {
                std.log.info("focus: {s} not read: {t}", .{ s.path, e });
                return;
            },
        };
        defer dir.close(s.io);

        const bytes = dir.readFileAlloc(s.io, FILE_NAME, s.gpa, .limited(MAX_FILE_BYTES)) catch |e| switch (e) {
            error.FileNotFound => return,
            else => {
                std.log.info("focus: {s} not read: {t}", .{ s.path, e });
                return;
            },
        };
        defer s.gpa.free(bytes);
        decode(s.gpa, state, bytes) catch |e| {
            std.log.info("focus: {s} not read: {t}", .{ s.path, e });
        };
    }
};

// -- Wiring: one store for the run ------------------------------------------

var store: ?*Store = null;
var state_ref: ?*AppState = null;

/// Opens the state file, reads it over `state`, and starts saving to it.
/// Without a usable data directory the app simply runs without persistence.
pub fn start(init: std.process.Init, state: *AppState) void {
    state_ref = state;
    const s = init.gpa.create(Store) catch |e| {
        std.log.warn("focus: state not kept: {t}", .{e});
        return;
    };
    s.* = Store.open(init, state) catch |e| {
        init.gpa.destroy(s);
        std.log.warn("focus: state not kept: {t}", .{e});
        return;
    };
    store = s;
}

/// Writes the last state and closes the store.
pub fn stop() void {
    const s = store orelse return;
    store = null;
    if (state_ref) |state| s.save(state);
    state_ref = null;
    s.deinit();
    s.gpa.destroy(s);
}

/// Called once a frame: writes only when the persisted state changed.
pub fn autosave() void {
    const s = store orelse return;
    s.maybeSave(state_ref orelse return);
}

/// For the window closing: writes the latest state now.
pub fn saveNow() void {
    const s = store orelse return;
    s.save(state_ref orelse return);
}

// -- Fingerprint ------------------------------------------------------------

const fnv_offset: u64 = 0xcbf29ce484222325;
const fnv_prime: u64 = 0x100000001b3;

fn mix(h: u64, v: anytype) u64 {
    var x = v;
    return mixBytes(h, std.mem.asBytes(&x));
}

fn mixBytes(h: u64, bytes: []const u8) u64 {
    var r = h;
    for (bytes) |b| {
        r ^= b;
        r *%= fnv_prime;
    }
    return r;
}

/// A hash of everything that is written, cheap enough to take each frame.
/// The remaining time of a running timer is left out: it changes every
/// frame, and `maybeSave` writes it on its own schedule instead.
fn fingerprint(state: *const AppState) u64 {
    var h: u64 = fnv_offset;
    h = mix(h, @as(u8, @intFromEnum(state.current_page)));

    const s = &state.settings;
    h = mix(h, s.work_min);
    h = mix(h, s.short_break_min);
    h = mix(h, s.long_break_min);
    h = mix(h, s.pomodoros_until_long_break);
    h = mix(h, @intFromBool(s.auto_start_breaks));
    h = mix(h, @intFromBool(s.auto_start_pomodoros));
    h = mix(h, @intFromBool(s.sound_enabled));
    h = mix(h, @intFromBool(s.follow_system_theme));
    h = mix(h, @intFromBool(s.dark_mode));

    const todos = &state.todos;
    h = mix(h, @as(u8, @intFromEnum(todos.filter)));
    h = mix(h, todos.item_count);
    h = mix(h, todos.next_id);
    for (todos.items[0..todos.item_count]) |item| {
        h = mix(h, item.id);
        h = mixBytes(h, item.textSlice());
        h = mix(h, @intFromBool(item.completed));
        h = mix(h, item.pomodoros_spent);
        h = mix(h, item.pomodoros_estimated);
        h = mix(h, item.created_at_ms);
        h = mix(h, @intFromEnum(item.priority));
    }

    const stats = &state.stats;
    h = mix(h, stats.total_pomodoros);
    h = mix(h, stats.total_focus_min);
    h = mix(h, stats.current_streak);
    h = mix(h, stats.best_streak);
    h = mix(h, stats.todays_pomodoros);
    h = mix(h, stats.todays_focus_min);
    h = mix(h, stats.today_day_index);
    h = mixBytes(h, std.mem.asBytes(&stats.daily_pomodoros));
    h = mixBytes(h, std.mem.asBytes(&stats.daily_focus_min));
    h = mix(h, stats.history_len);
    for (stats.history[0..stats.history_len]) |e| {
        h = mix(h, e.completed_at_ms);
        h = mix(h, e.duration_min);
        h = mix(h, e.todo_id);
    }

    const timer = &state.timer;
    h = mix(h, @as(u8, @intFromEnum(timer.phase)));
    h = mix(h, timer.total_ms);
    h = mix(h, timer.completed_in_cycle);
    h = mix(h, timer.total_completed);
    h = mix(h, timer.active_todo_index orelse std.math.maxInt(usize));
    if (!timer.is_running) h = mix(h, timer.remaining_ms);
    return h;
}

// -- Writing ----------------------------------------------------------------

/// The state as JSON. Field names are the ones `decode` reads; unknown
/// ones are ignored by it, so newer files stay readable.
fn encode(w: *std.Io.Writer, state: *const AppState) !void {
    var s: std.json.Stringify = .{ .writer = w, .options = .{} };
    const st = &state.settings;
    const todos = &state.todos;
    const stats = &state.stats;
    const timer = &state.timer;

    try s.beginObject();
    try s.objectField("version");
    try s.write(VERSION);
    try s.objectField("page");
    try s.write(@tagName(state.current_page));

    try s.objectField("settings");
    try s.beginObject();
    try s.objectField("work_min");
    try s.write(st.work_min);
    try s.objectField("short_break_min");
    try s.write(st.short_break_min);
    try s.objectField("long_break_min");
    try s.write(st.long_break_min);
    try s.objectField("pomodoros_until_long_break");
    try s.write(st.pomodoros_until_long_break);
    try s.objectField("auto_start_breaks");
    try s.write(st.auto_start_breaks);
    try s.objectField("auto_start_pomodoros");
    try s.write(st.auto_start_pomodoros);
    try s.objectField("sound_enabled");
    try s.write(st.sound_enabled);
    try s.objectField("follow_system_theme");
    try s.write(st.follow_system_theme);
    try s.objectField("dark_mode");
    try s.write(st.dark_mode);
    try s.endObject();

    try s.objectField("todos");
    try s.beginObject();
    try s.objectField("next_id");
    try s.write(todos.next_id);
    try s.objectField("filter");
    try s.write(@tagName(todos.filter));
    try s.objectField("items");
    try s.beginArray();
    for (todos.items[0..todos.item_count]) |item| {
        try s.beginObject();
        try s.objectField("id");
        try s.write(item.id);
        try s.objectField("text");
        try writeText(&s, item.textSlice());
        try s.objectField("completed");
        try s.write(item.completed);
        try s.objectField("pomodoros_spent");
        try s.write(item.pomodoros_spent);
        try s.objectField("pomodoros_estimated");
        try s.write(item.pomodoros_estimated);
        try s.objectField("created_at_ms");
        try s.write(item.created_at_ms);
        try s.objectField("priority");
        try s.write(@intFromEnum(item.priority));
        try s.endObject();
    }
    try s.endArray();
    try s.endObject();

    try s.objectField("stats");
    try s.beginObject();
    try s.objectField("total_pomodoros");
    try s.write(stats.total_pomodoros);
    try s.objectField("total_focus_min");
    try s.write(stats.total_focus_min);
    try s.objectField("current_streak");
    try s.write(stats.current_streak);
    try s.objectField("best_streak");
    try s.write(stats.best_streak);
    try s.objectField("todays_pomodoros");
    try s.write(stats.todays_pomodoros);
    try s.objectField("todays_focus_min");
    try s.write(stats.todays_focus_min);
    try s.objectField("today_day_index");
    try s.write(stats.today_day_index);
    try s.objectField("daily_pomodoros");
    try s.write(stats.daily_pomodoros[0..]);
    try s.objectField("daily_focus_min");
    try s.write(stats.daily_focus_min[0..]);
    try s.objectField("history");
    try s.beginArray();
    for (stats.history[0..stats.history_len]) |e| {
        try s.beginObject();
        try s.objectField("completed_at_ms");
        try s.write(e.completed_at_ms);
        try s.objectField("duration_min");
        try s.write(e.duration_min);
        try s.objectField("todo_id");
        try s.write(e.todo_id);
        try s.endObject();
    }
    try s.endArray();
    try s.endObject();

    try s.objectField("timer");
    try s.beginObject();
    try s.objectField("phase");
    try s.write(@tagName(timer.phase));
    try s.objectField("remaining_ms");
    try s.write(timer.remaining_ms);
    try s.objectField("total_ms");
    try s.write(timer.total_ms);
    try s.objectField("completed_in_cycle");
    try s.write(timer.completed_in_cycle);
    try s.objectField("total_completed");
    try s.write(timer.total_completed);
    try s.objectField("active_todo_id");
    try s.write(if (timer.active_todo_index) |i| todos.items[i].id else 0);
    try s.endObject();

    try s.endObject();
}

/// Writes a todo's text. Text that isn't valid UTF-8 (a pasted byte
/// sequence, say) becomes U+FFFD so the file stays valid JSON.
fn writeText(s: *std.json.Stringify, text: []const u8) !void {
    if (std.unicode.utf8ValidateSlice(text)) return s.write(text);
    var buf: [MAX_TEXT_LEN * 3]u8 = undefined;
    try s.write(sanitizeUtf8(&buf, text));
}

/// Replaces each invalid byte of `src` with U+FFFD, as much as fits `buf`.
fn sanitizeUtf8(buf: []u8, src: []const u8) []const u8 {
    var len: usize = 0;
    var i: usize = 0;
    while (i < src.len) {
        const n: usize = std.unicode.utf8ByteSequenceLength(src[i]) catch 1;
        if (n > 1 and i + n <= src.len and std.unicode.utf8ValidateSlice(src[i .. i + n])) {
            if (len + n > buf.len) break;
            @memcpy(buf[len..][0..n], src[i..][0..n]);
            len += n;
            i += n;
        } else if (n == 1 and i + 1 <= src.len and src[i] < 0x80) {
            if (len + 1 > buf.len) break;
            buf[len] = src[i];
            len += 1;
            i += 1;
        } else {
            if (len + 3 > buf.len) break;
            buf[len] = 0xEF;
            buf[len + 1] = 0xBF;
            buf[len + 2] = 0xBD;
            len += 3;
            i += 1;
        }
    }
    return buf[0..len];
}

// -- Reading ----------------------------------------------------------------

/// Reads JSON `bytes` over `state`: every field that is there and sane is
/// applied, everything else keeps its default. A file that doesn't parse
/// as a JSON object leaves `state` untouched and returns an error.
fn decode(gpa: std.mem.Allocator, state: *AppState, bytes: []const u8) !void {
    const parsed = try std.json.parseFromSlice(std.json.Value, gpa, bytes, .{});
    defer parsed.deinit();
    const root = parsed.value;
    if (root != .object) return error.NotAnObject;

    if (asStr(get(root, "page"))) |name| {
        if (std.meta.stringToEnum(AppState.Page, name)) |page| state.current_page = page;
    }
    if (get(root, "settings")) |v| applySettings(&state.settings, v);
    if (get(root, "todos")) |v| applyTodos(&state.todos, v);
    if (get(root, "stats")) |v| applyStats(&state.stats, v);
    if (get(root, "timer")) |v| applyTimer(state, v);

    // An idle timer shows the work length from the settings, which a file
    // without a timer section may have changed.
    if (state.timer.phase == .idle) {
        state.timer.remaining_ms = state.settings.workMs();
        state.timer.total_ms = state.timer.remaining_ms;
    }

    // The file may have been written yesterday: move the daily arrays on.
    state.stats.rollDay();
}

fn get(v: std.json.Value, key: []const u8) ?std.json.Value {
    return switch (v) {
        .object => |o| o.get(key),
        else => null,
    };
}

fn asInt(v: ?std.json.Value) ?i64 {
    const x = v orelse return null;
    return switch (x) {
        .integer => |i| i,
        .float => |f| if (std.math.isFinite(f) and f > -9.2e18 and f < 9.2e18) @as(i64, @intFromFloat(f)) else null,
        .number_string => |t| std.fmt.parseInt(i64, t, 10) catch null,
        else => null,
    };
}

fn asBool(v: ?std.json.Value) ?bool {
    return switch (v orelse return null) {
        .bool => |b| b,
        else => null,
    };
}

fn asStr(v: ?std.json.Value) ?[]const u8 {
    return switch (v orelse return null) {
        .string => |t| t,
        else => null,
    };
}

fn asArray(v: ?std.json.Value) ?[]std.json.Value {
    return switch (v orelse return null) {
        .array => |a| a.items,
        else => null,
    };
}

/// A number in `min..max`, with anything outside pulled to the near end.
fn clampU32(n: i64, min: u32, max: u32) u32 {
    if (n <= @as(i64, min)) return min;
    if (n >= @as(i64, max)) return max;
    return @intCast(n);
}

/// A counter: never negative, never above a `u32`.
fn countU32(n: i64) u32 {
    if (n <= 0) return 0;
    if (n >= std.math.maxInt(u32)) return std.math.maxInt(u32);
    return @intCast(n);
}

fn countU64(n: i64) u64 {
    if (n <= 0) return 0;
    return @intCast(n);
}

fn applySettings(dst: *SettingsState, v: std.json.Value) void {
    if (asInt(get(v, "work_min"))) |n| dst.work_min = clampU32(n, WORK_MIN, WORK_MAX);
    if (asInt(get(v, "short_break_min"))) |n| dst.short_break_min = clampU32(n, 1, SHORT_BREAK_MAX);
    if (asInt(get(v, "long_break_min"))) |n| dst.long_break_min = clampU32(n, 1, LONG_BREAK_MAX);
    if (asInt(get(v, "pomodoros_until_long_break"))) |n| dst.pomodoros_until_long_break = clampU32(n, 1, CYCLE_MAX);
    if (asBool(get(v, "auto_start_breaks"))) |b| dst.auto_start_breaks = b;
    if (asBool(get(v, "auto_start_pomodoros"))) |b| dst.auto_start_pomodoros = b;
    if (asBool(get(v, "sound_enabled"))) |b| dst.sound_enabled = b;
    if (asBool(get(v, "follow_system_theme"))) |b| dst.follow_system_theme = b;
    if (asBool(get(v, "dark_mode"))) |b| dst.dark_mode = b;
}

fn applyTodos(dst: *TodoState, v: std.json.Value) void {
    dst.item_count = 0;
    if (asStr(get(v, "filter"))) |name| {
        if (std.meta.stringToEnum(Filter, name)) |f| dst.filter = f;
    }

    const items = asArray(get(v, "items")) orelse return;
    if (items.len == 0) return;

    // Ids are what the stats history points at, so an item keeps its own.
    var max_id: u64 = 0;
    for (items) |it| {
        const n = asInt(get(it, "id")) orelse continue;
        if (n <= 0) continue;
        const id = countU64(n);
        if (id > max_id) max_id = id;
    }
    var free_id = max_id + 1;

    for (items) |it| {
        if (dst.item_count >= MAX_TODOS) break;
        var id = countU64(asInt(get(it, "id")) orelse 0);
        if (id == 0) {
            id = free_id;
            free_id += 1;
        }

        var item: TodoItem = .{ .id = id };
        @memset(&item.text, 0);
        const text = asStr(get(it, "text")) orelse "";
        item.text_len = copyText(&item.text, text);
        // An item with nothing to show is not worth keeping.
        if (item.text_len == 0) continue;

        item.completed = asBool(get(it, "completed")) orelse false;
        item.pomodoros_spent = countU32(asInt(get(it, "pomodoros_spent")) orelse 0);
        item.pomodoros_estimated = @max(1, countU32(asInt(get(it, "pomodoros_estimated")) orelse 0));
        item.created_at_ms = asInt(get(it, "created_at_ms")) orelse 0;
        if (asInt(get(it, "priority"))) |n| {
            item.priority = @enumFromInt(clampU32(n, 0, @intFromEnum(Priority.urgent)));
        }

        dst.items[dst.item_count] = item;
        dst.item_count += 1;
    }

    const saved_next = countU64(asInt(get(v, "next_id")) orelse 0);
    dst.next_id = @max(@max(saved_next, max_id + 1), free_id);
    if (dst.next_id == 0) dst.next_id = 1;
}

/// Copies `src` into `dst` as valid UTF-8 (lossy, see `sanitizeUtf8`),
/// cut to what fits without splitting a character. Returns the length.
fn copyText(dst: []u8, src: []const u8) usize {
    var tmp: [MAX_TEXT_LEN * 3]u8 = undefined;
    const clean = sanitizeUtf8(&tmp, src);
    var n = @min(clean.len, dst.len);
    while (n > 0 and !std.unicode.utf8ValidateSlice(clean[0..n])) : (n -= 1) {}
    @memcpy(dst[0..n], clean[0..n]);
    return n;
}

fn applyStats(dst: *StatsState, v: std.json.Value) void {
    if (asInt(get(v, "total_pomodoros"))) |n| dst.total_pomodoros = countU32(n);
    if (asInt(get(v, "total_focus_min"))) |n| dst.total_focus_min = countU32(n);
    if (asInt(get(v, "current_streak"))) |n| dst.current_streak = countU32(n);
    if (asInt(get(v, "best_streak"))) |n| dst.best_streak = countU32(n);
    if (asInt(get(v, "todays_pomodoros"))) |n| dst.todays_pomodoros = countU32(n);
    if (asInt(get(v, "todays_focus_min"))) |n| dst.todays_focus_min = countU32(n);
    if (asInt(get(v, "today_day_index"))) |n| dst.today_day_index = @max(0, n);
    applyDays(&dst.daily_pomodoros, get(v, "daily_pomodoros"));
    applyDays(&dst.daily_focus_min, get(v, "daily_focus_min"));

    dst.history_len = 0;
    const entries = asArray(get(v, "history")) orelse return;
    for (entries) |e| {
        if (dst.history_len >= MAX_HISTORY) break;
        dst.history[dst.history_len] = .{
            .completed_at_ms = asInt(get(e, "completed_at_ms")) orelse 0,
            .duration_min = countU32(asInt(get(e, "duration_min")) orelse 0),
            .todo_id = countU64(asInt(get(e, "todo_id")) orelse 0),
        };
        dst.history_len += 1;
    }
}

fn applyDays(dst: *[HISTORY_DAYS]u32, v: ?std.json.Value) void {
    const arr = switch (v orelse return) {
        .array => |a| a,
        else => return,
    };
    const n = @min(arr.items.len, HISTORY_DAYS);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        dst[i] = countU32(asInt(arr.items[i]) orelse 0);
    }
}

fn applyTimer(state: *AppState, v: std.json.Value) void {
    const t = &state.timer;
    t.* = .{};

    if (asStr(get(v, "phase"))) |name| {
        if (std.meta.stringToEnum(Phase, name)) |p| t.phase = p;
    }

    if (t.phase == .idle) {
        // Idle means the start of work, whose length lives in the settings.
        t.remaining_ms = state.settings.workMs();
        t.total_ms = t.remaining_ms;
    } else {
        const saved_total = countU64(asInt(get(v, "total_ms")) orelse 0);
        t.total_ms = if (saved_total >= 1000) saved_total else phaseMs(t.phase, state);
        const saved_remaining = if (asInt(get(v, "remaining_ms"))) |n|
            countU64(n)
        else
            t.total_ms;
        // Nothing left means the phase was about to end: show it whole
        // rather than completing it behind the user's back.
        t.remaining_ms = if (saved_remaining == 0 or saved_remaining > t.total_ms)
            t.total_ms
        else
            saved_remaining;
    }

    t.completed_in_cycle = clampU32(asInt(get(v, "completed_in_cycle")) orelse 0, 0, CYCLE_MAX);
    t.total_completed = countU32(asInt(get(v, "total_completed")) orelse 0);

    const todo_id = countU64(asInt(get(v, "active_todo_id")) orelse 0);
    if (todo_id != 0) {
        for (state.todos.items[0..state.todos.item_count], 0..) |item, i| {
            if (item.id == todo_id) {
                t.active_todo_index = i;
                break;
            }
        }
    }

    // A restored timer waits for the user: it doesn't jump while the app
    // was closed.
    t.is_running = false;
    t.last_tick_ns = 0;
    t.phase_just_completed = false;
}

fn phaseMs(phase: Phase, state: *const AppState) u64 {
    return switch (phase) {
        .idle, .working => state.settings.workMs(),
        .short_break => state.settings.shortBreakMs(),
        .long_break => state.settings.longBreakMs(),
    };
}

// -- Tests ------------------------------------------------------------------

test "state survives a round trip through the file's format" {
    const gpa = std.testing.allocator;
    var original = AppState{};
    original.current_page = .todos;
    original.settings.work_min = 50;
    original.settings.short_break_min = 8;
    original.settings.dark_mode = true;
    original.settings.auto_start_pomodoros = true;
    original.todos.addItem("Write the report");
    original.todos.addItem("Read a chapter");
    original.todos.toggleItem(1);
    original.todos.items[0].pomodoros_spent = 3;
    original.todos.items[0].priority = .high;
    original.stats.recordPomodoro(50, original.todos.items[0].id);
    original.timer.phase = .short_break;
    original.timer.remaining_ms = 120_000;
    original.timer.total_ms = 300_000;
    original.timer.completed_in_cycle = 1;
    original.timer.total_completed = 2;
    original.timer.active_todo_index = 0;
    original.timer.is_running = true;

    var out: std.Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    try encode(&out.writer, &original);

    var restored = AppState{};
    try decode(gpa, &restored, out.written());

    try std.testing.expectEqual(AppState.Page.todos, restored.current_page);
    try std.testing.expectEqual(@as(u32, 50), restored.settings.work_min);
    try std.testing.expectEqual(@as(u32, 8), restored.settings.short_break_min);
    try std.testing.expect(restored.settings.dark_mode);
    try std.testing.expect(restored.settings.auto_start_pomodoros);
    try std.testing.expectEqual(@as(usize, 2), restored.todos.item_count);
    try std.testing.expectEqualStrings("Write the report", restored.todos.items[0].textSlice());
    try std.testing.expect(restored.todos.items[1].completed);
    try std.testing.expectEqual(@as(u32, 3), restored.todos.items[0].pomodoros_spent);
    try std.testing.expectEqual(Priority.high, restored.todos.items[0].priority);
    try std.testing.expect(restored.todos.next_id > restored.todos.items[1].id);
    try std.testing.expectEqual(@as(u32, 1), restored.stats.total_pomodoros);
    try std.testing.expectEqual(@as(usize, 1), restored.stats.history_len);
    try std.testing.expectEqual(original.todos.items[0].id, restored.stats.history[0].todo_id);
    try std.testing.expectEqual(Phase.short_break, restored.timer.phase);
    try std.testing.expectEqual(@as(u64, 120_000), restored.timer.remaining_ms);
    try std.testing.expectEqual(@as(u64, 300_000), restored.timer.total_ms);
    try std.testing.expectEqual(@as(u32, 1), restored.timer.completed_in_cycle);
    try std.testing.expectEqual(@as(?usize, 0), restored.timer.active_todo_index);
    // Restored timers always wait, even if they were running when saved.
    try std.testing.expect(!restored.timer.is_running);
}

test "odd values are pulled into range and broken items dropped" {
    const gpa = std.testing.allocator;
    const bytes = "{\"page\":\"nonsense\",\"settings\":{\"work_min\":900,\"short_break_min\":0,\"long_break_min\":-3,\"dark_mode\":true,\"sound_enabled\":\"yes\"},\"todos\":{\"next_id\":1,\"items\":[{\"id\":7,\"text\":\"keep me\",\"completed\":true},{\"text\":\"no id\"},{\"id\":8}]},\"stats\":{\"total_pomodoros\":-5,\"history\":[{\"completed_at_ms\":5,\"duration_min\":25,\"todo_id\":7}]},\"timer\":{\"phase\":\"working\",\"remaining_ms\":-100,\"total_ms\":0}}";
    var state = AppState{};
    try decode(gpa, &state, bytes);

    // Unknown page: left as it was.
    try std.testing.expectEqual(AppState.Page.timer, state.current_page);
    try std.testing.expectEqual(@as(u32, 90), state.settings.work_min);
    try std.testing.expectEqual(@as(u32, 1), state.settings.short_break_min);
    try std.testing.expectEqual(@as(u32, 1), state.settings.long_break_min);
    try std.testing.expect(state.settings.dark_mode);
    try std.testing.expect(state.settings.sound_enabled);

    // The item without an id gets one after the highest; the one with no
    // text is dropped.
    try std.testing.expectEqual(@as(usize, 2), state.todos.item_count);
    try std.testing.expectEqual(@as(u64, 7), state.todos.items[0].id);
    try std.testing.expectEqual(@as(u64, 9), state.todos.items[1].id);
    try std.testing.expectEqualStrings("no id", state.todos.items[1].textSlice());
    try std.testing.expectEqual(@as(u64, 10), state.todos.next_id);

    try std.testing.expectEqual(@as(u32, 0), state.stats.total_pomodoros);
    try std.testing.expectEqual(@as(usize, 1), state.stats.history_len);
    try std.testing.expectEqual(@as(u64, 7), state.stats.history[0].todo_id);

    // Zero total falls back to the work length, and the whole phase shows.
    try std.testing.expectEqual(@as(u64, 90 * 60 * 1000), state.timer.total_ms);
    try std.testing.expectEqual(state.timer.total_ms, state.timer.remaining_ms);
    try std.testing.expect(!state.timer.is_running);
}

test "a file that is not JSON leaves the state alone" {
    const gpa = std.testing.allocator;
    var state = AppState{};
    state.settings.work_min = 42;
    if (decode(gpa, &state, "{not json")) |_| {
        return error.TestUnexpectedResult;
    } else |_| {}
    try std.testing.expectEqual(@as(u32, 42), state.settings.work_min);
}

test "the same state fingerprints the same, and a change shows" {
    var state = AppState{};
    state.todos.addItem("one");
    const before = fingerprint(&state);
    try std.testing.expectEqual(before, fingerprint(&state));

    state.todos.items[0].completed = true;
    try std.testing.expect(before != fingerprint(&state));

    // The clock of a running timer is not part of it.
    state.timer.is_running = true;
    const running = fingerprint(&state);
    state.timer.remaining_ms -= 1000;
    try std.testing.expectEqual(running, fingerprint(&state));
}
