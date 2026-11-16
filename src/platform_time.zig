//! Thin wrappers around Windows native time APIs for Zig 0.17.
//! Replaces the removed std.time.nanoTimestamp() / milliTimestamp().

const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;
const ntdll = windows.ntdll;
const linux = std.os.linux;

/// Returns a monotonic timestamp in nanoseconds (suitable for measuring
/// elapsed time).
pub fn nanoTimestamp() i128 {
    if (builtin.os.tag == .windows) {
        var counter: windows.LARGE_INTEGER = undefined;
        var freq: windows.LARGE_INTEGER = undefined;
        _ = ntdll.RtlQueryPerformanceCounter(&counter);
        _ = ntdll.RtlQueryPerformanceFrequency(&freq);
        return @divTrunc(@as(i128, counter) * 1_000_000_000, @as(i128, freq));
    }

    var ts: linux.timespec = undefined;
    if (linux.clock_gettime(.MONOTONIC, &ts) != 0) @panic("clock_gettime(CLOCK_MONOTONIC) failed");
    return @as(i128, ts.sec) * 1_000_000_000 + @as(i128, ts.nsec);
}

/// Windows FILETIME epoch offset: 100-nanosecond intervals from Jan 1 1601
/// to Jan 1 1970 (Unix epoch).
const WINDOWS_EPOCH_OFFSET_HNS: i64 = 116444736000000000;

/// Returns milliseconds since Unix epoch (wall clock).
pub fn milliTimestamp() i64 {
    if (builtin.os.tag == .windows) {
        const hns: i64 = ntdll.RtlGetSystemTimePrecise();
        return @divTrunc(hns - WINDOWS_EPOCH_OFFSET_HNS, 10_000);
    }

    var ts: linux.timespec = undefined;
    if (linux.clock_gettime(.REALTIME, &ts) != 0) @panic("clock_gettime(CLOCK_REALTIME) failed");
    return @as(i64, @intCast(ts.sec)) * 1_000 +
        @divTrunc(@as(i64, @intCast(ts.nsec)), 1_000_000);
}

/// Returns seconds since Unix epoch (wall clock).
pub fn timestamp() i64 {
    return @divTrunc(milliTimestamp(), 1_000);
}
