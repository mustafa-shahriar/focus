# Pomodoro Focus

A Pomodoro timer and task list built with Zig and [nanoui](https://github.com/justrach/nanoui). It runs on the desktop (Windows and Linux) and on Android, and includes configurable focus and break sessions, task tracking, session statistics, and light/dark themes.

The layout adapts to the window: below 680 logical units of width the app switches to a compact mobile layout with a top header, a bottom navigation bar, stacked pages and larger touch targets. That same layout serves phones, small tablets, and narrow desktop windows.

## Requirements

- [Zig 0.17.0](https://ziglang.org/download/)
- Windows or Linux
- On Linux, a GTK 3 or GTK 4 runtime. WebKitGTK is also needed for nanoui views that use web content.

nanoui loads GTK and WebKitGTK dynamically, so these libraries are runtime requirements rather than build-time linker dependencies.

## Build

Build for the current host:

```sh
zig build
```

To select a target explicitly (for example, when cross-compiling):

```sh
# 64-bit Windows
zig build -Dtarget=x86_64-windows

# 64-bit Linux with glibc
zig build -Dtarget=x86_64-linux-gnu
```

The executable is written to `zig-out/bin/` (`focus.exe` on Windows and `focus` on Linux).

### Desktop release builds

Build an optimized 64-bit Windows release:

```sh
zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast
```

Build an optimized 64-bit Linux release for glibc-based distributions:

```sh
zig build -Dtarget=x86_64-linux-gnu -Doptimize=ReleaseFast
```

Both commands can be run on Windows or Linux to cross-compile. The Windows executable is `zig-out/bin/focus.exe`; the Linux executable is `zig-out/bin/focus`. Linux users need GTK 3 or GTK 4 at runtime, and WebKitGTK for features that display web content. These commands produce the executable, not an installer or self-contained Linux bundle.

## Android

Build and install a debuggable APK:

```powershell
.\tools\android\build.ps1 -Target aarch64-linux-android -Optimize Debug -Install
```

With release keystore environment variables configured as described in [ANDROID.md](./ANDROID.md#production-release), build a production APK with:

```powershell
zig build apk -Dtarget=aarch64-linux-android -Doptimize=ReleaseFast
```

The APK is written to `zig-out/android/focus.apk`. Release builds require your own keystore; they never fall back to the debug key. See [ANDROID.md](./ANDROID.md) for SDK setup, signing, install, and debug details.

## Run

```sh
zig build run
```

Or run the installed binary directly:

```sh
# Windows PowerShell
.\zig-out\bin\focus.exe

# Linux
./zig-out/bin/focus
```

## Tests

Run the unit tests with:

```sh
zig build test
```

## Saved state

Your tasks, statistics, settings, and the timer's place are kept between launches in one JSON file per user:

| Platform | File |
| --- | --- |
| Windows | `%APPDATA%\Pomodoro Focus\focus-state.json` |
| Linux | `$XDG_DATA_HOME/Pomodoro Focus/focus-state.json` (usually `~/.local/share/Pomodoro Focus/focus-state.json`) |
| Android | the app's internal files directory, `.../files/Pomodoro Focus/focus-state.json` |

The file is written to a temporary name and renamed into place, so an interrupted write leaves the previous state intact. Saves happen automatically when something changes, every 15 seconds while the timer runs, and when the window closes. A timer that was running when the app was closed comes back paused, at the time it had left.

The file is small, human-readable JSON: because the data is at most a few hundred tasks and a thousand sessions, a JSON file is faster and more portable than a database, and it keeps the app free of extra dependencies on all three platforms. Deleting the file resets the app.

## Focus mode

The expand button in the timer card's bottom-right corner makes the card fill the window, hiding the page header and side panels for an undisturbed session. The `x` in the same corner brings the normal layout back, as does switching to another page.

## Project layout

- `src/timer/` - Pomodoro timer state and view
- `src/todo/` - task state and view
- `src/stats/` - session statistics
- `src/settings/` - timer and appearance settings
- `src/storage.zig` - saved state: reading and atomically writing the JSON file
- `src/theme/` - app colors and shared UI components
- `src/responsive.zig` — the compact/desktop breakpoint and page padding
- `src/platform.zig` — which platform the build targets (desktop chrome vs Android)
- `assets/icon.png` — the Android launcher icon (`tools/android/make-icon.ps1` redraws it)
- `build.zig` — Zig build, run, test, and APK steps
