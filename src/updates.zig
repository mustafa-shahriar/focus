//! Updates from the project's GitHub releases.
//!
//! Windows and Linux are handled by nanoui's `Updater`: some seconds after
//! launch, then every few hours, it reads the latest release's
//! `manifest.json`, downloads this platform's archive, checks its sha256,
//! runs the unpacked program with `--version`, and keeps it waiting. One
//! click in Settings installs it and starts the new version; quitting with
//! one waiting installs it for the next launch.
//!
//! Android can't replace a running app: the update check reads the same
//! manifest, and the install button opens the APK's download URL, which
//! lets the browser download it and Android's own installer update the
//! app. That needs the same signing key and a higher versionCode, both of
//! which the release workflow guarantees.

const std = @import("std");
const builtin = @import("builtin");
const nanoui = @import("nanoui");
const build_options = @import("build_options");
const platform = @import("platform.zig");
const shell = @import("shell.zig");

/// The repository whose releases carry the files below.
pub const repo = "mustafa-shahriar/focus";

/// This build's version, from build.zig.zon.
pub const version: []const u8 = build_options.version;

/// The APK asset in each release.
pub const android_asset = "focus-android-arm64.apk";

const first_check_ms: u64 = 8 * 1000;
const check_every_ms: u64 = 6 * 60 * 60 * 1000;

pub const Status = enum {
    /// This build can't update itself (a debug build, or an install the
    /// user can't write to).
    off,
    idle,
    checking,
    /// A newer version is waiting (desktop) or downloadable (Android).
    available,
    /// Android: the check found nothing newer.
    up_to_date,
    /// The check or the install failed; `detail` says why.
    failed,
};

var gpa: std.mem.Allocator = std.heap.page_allocator;
var app: ?*nanoui.App = null;
var updater: ?*nanoui.Updater = null;
var install_error: ?[]const u8 = null;
var changed_ctx: u8 = 0;

const Android = struct {
    status: Status = .idle,
    latest: [32]u8 = undefined,
    latest_len: usize = 0,
    feed: []u8 = &.{},
    /// A downloadable feed override (NANOUI_UPDATE_FEED, for testing).
    feed_owned: bool = false,
};

var android: Android = .{};

var detail_buf: [192]u8 = undefined;

/// Starts the automatic check. Call after the window exists, so the
/// callbacks can redraw it; call `stop` before the app ends.
pub fn start(init: std.process.Init, application: *nanoui.App) void {
    gpa = init.gpa;
    app = application;
    install_error = null;

    if (platform.is_android) {
        android.feed = feedFor(init) catch {
            android.status = .failed;
            return;
        };
        android.feed_owned = true;
        android.status = .idle;
        nanoui.App.after(first_check_ms, @ptrCast(&android), autoCheck);
        return;
    }

    // Builds made with `zig build` stay out of it: a development program
    // must not replace itself with a release.
    if (!build_options.self_update) return;

    updater = nanoui.Updater.start(init, .{
        .repo = repo,
        .asset = desktopAsset(),
        .version = version,
        .name = "Pomodoro Focus",
        .changed = .{ .ctx = @ptrCast(&changed_ctx), .func = onChanged },
    }) catch |e| {
        std.log.warn("focus: updates are off: {t}", .{e});
        return;
    };
}

/// Frees the updater; a version still waiting is installed for the next
/// launch, as nanoui's updater does when the app quits.
pub fn stop() void {
    if (updater) |u| {
        u.deinit();
        updater = null;
    }
    if (android.feed_owned and android.feed.len > 0) gpa.free(android.feed);
    android.feed = &.{};
    android.feed_owned = false;
    app = null;
}

pub fn status() Status {
    if (platform.is_android) return android.status;

    const u = updater orelse return .off;
    if (u.phase.load(.acquire) == .off) return .off;
    if (u.ready() != null) return .available;
    if (u.checking()) return .checking;
    return .idle;
}

/// The newer version, when one is ready.
pub fn availableVersion() ?[]const u8 {
    if (platform.is_android) {
        return if (android.status == .available) android.latest[0..android.latest_len] else null;
    }
    const u = updater orelse return null;
    return u.ready();
}

/// Whether the "Check for updates" button does anything.
pub fn canCheck() bool {
    return switch (status()) {
        .off, .checking, .available => false,
        .idle, .up_to_date, .failed => true,
    };
}

/// One line under the card's heading.
pub fn detail() []const u8 {
    if (install_error) |e| return e;

    if (platform.is_android) {
        return switch (android.status) {
            .off => "This build can't update itself.",
            .idle => "Check GitHub for a newer release.",
            .checking => "Looking for a newer release...",
            .available => std.fmt.bufPrint(&detail_buf, "Version {s} is ready to download.", .{android.latest[0..android.latest_len]}) catch "A newer release is ready.",
            .up_to_date => "You're running the latest version.",
            .failed => "Couldn't check for updates. Connect to the internet and try again.",
        };
    }

    const u = updater orelse return "Updates are off in this build.";
    if (u.phase.load(.acquire) == .off) return "Install a release build in a folder you can write to.";
    if (u.ready()) |v| return std.fmt.bufPrint(&detail_buf, "Version {s} is ready to install.", .{v}) catch "A newer version is ready.";
    if (u.checking()) return "Looking for a newer version...";
    return "Updates are checked automatically.";
}

/// The button that installs a waiting update, worded for the platform.
pub fn installLabel() []const u8 {
    return if (platform.is_android) "Get update" else "Update and restart";
}

/// Checks now, unless a check is already running.
pub fn checkNow() void {
    install_error = null;
    if (platform.is_android) {
        androidCheck();
        return;
    }
    if (updater) |u| u.checkNow();
}

/// Desktop: installs the waiting version and restarts the app. Android:
/// opens the APK's download, which Android's installer takes over.
pub fn install() void {
    install_error = null;
    if (platform.is_android) {
        const v = availableVersion() orelse return;
        var buf: [512]u8 = undefined;
        const url = std.fmt.bufPrint(&buf, "https://github.com/{s}/releases/download/v{s}/{s}", .{ repo, v, android_asset }) catch {
            install_error = "The download address is too long.";
            return;
        };
        if (!nanoui.shell.openUrl(url)) {
            install_error = "No browser could open the download.";
        }
        return;
    }

    const u = updater orelse {
        install_error = "This build can't update itself.";
        return;
    };
    if (!u.restart()) {
        install_error = "The update couldn't be installed. Try again.";
        return;
    }
    if (app) |a| a.quit();
}

fn desktopAsset() []const u8 {
    // Only these builds are published: Windows x86_64, Linux x86_64, and
    // Android arm64. There is no 32-bit, macOS, or Linux ARM release.
    return switch (builtin.os.tag) {
        .windows => "focus-windows-x86_64.zip",
        .linux => "focus-linux-x86_64.tar.gz",
        else => "",
    };
}

fn feedFor(init: std.process.Init) ![]u8 {
    if (init.environ_map.get("NANOUI_UPDATE_FEED")) |f| {
        return init.gpa.dupe(u8, std.mem.trimEnd(u8, f, "/"));
    }
    return std.fmt.allocPrint(init.gpa, "https://github.com/{s}/releases/latest/download", .{repo});
}

fn androidCheck() void {
    if (android.status == .checking) return;
    android.status = .checking;
    redraw();

    var buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&buf, "{s}/manifest.json", .{android.feed}) catch {
        android.status = .failed;
        redraw();
        return;
    };
    // The request's bytes are copied; the answer arrives on the main thread.
    nanoui.http.fetch(gpa, .{ .url = url, .timeout = 20 }, &android, onManifest);
}

fn onManifest(a: *Android, r: nanoui.http.Response) void {
    if (r.status != 200) {
        a.status = .failed;
        redraw();
        return;
    }

    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const release = nanoui.update.parseManifest(arena.allocator(), r.body, android_asset) catch {
        a.status = .failed;
        redraw();
        return;
    };

    if (nanoui.update.newer(release.version, version)) {
        if (release.version.len > a.latest.len) {
            a.status = .failed;
            redraw();
            return;
        }
        @memcpy(a.latest[0..release.version.len], release.version);
        a.latest_len = release.version.len;
        a.status = .available;
    } else {
        a.status = .up_to_date;
    }
    redraw();
}

fn autoCheck(_: ?*anyopaque) callconv(.c) void {
    if (android.status != .checking) androidCheck();
    nanoui.App.after(check_every_ms, @ptrCast(&android), autoCheck);
}

fn onChanged(_: *anyopaque) void {
    redraw();
}

fn redraw() void {
    if (shell.window) |w| w.redraw();
}
