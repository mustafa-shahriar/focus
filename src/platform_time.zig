//! Thin wrappers around Windows native time APIs for Zig 0.17.
//! Replaces the removed std.time.nanoTimestamp() / milliTimestamp().

const std = @import("std");
const windows = std.os.windows;
const ntdll = windows.ntdll;

/// Returns a monotonic timestamp in nanoseconds (suitable for measuring
/// elapsed time). Wraps RtlQueryPerformanceCounter.
pub fn nanoTimestamp() i128 {
    var counter: windows.LARGE_INTEGER = undefined;
    var freq: windows.LARGE_INTEGER = undefined;
    _ = ntdll.RtlQueryPerformanceCounter(&counter);
    _ = ntdll.RtlQueryPerformanceFrequency(&freq);
    // counter / freq * 1_000_000_000
    return @divTrunc(@as(i128, counter) * 1_000_000_000, @as(i128, freq));
}

/// Windows FILETIME epoch offset: 100-nanosecond intervals from Jan 1 1601
/// to Jan 1 1970 (Unix epoch).
const WINDOWS_EPOCH_OFFSET_HNS: i64 = 116444736000000000;

/// Returns milliseconds since Unix epoch (wall clock). Wraps
/// RtlGetSystemTimePrecise (100-ns resolution).
pub fn milliTimestamp() i64 {
    const hns: i64 = ntdll.RtlGetSystemTimePrecise();
    // Convert from Windows 100-ns units to Unix milliseconds
    return @divTrunc(hns - WINDOWS_EPOCH_OFFSET_HNS, 10_000);
}

/// Returns seconds since Unix epoch (wall clock).
pub fn timestamp() i64 {
    return @divTrunc(milliTimestamp(), 1_000);
}
