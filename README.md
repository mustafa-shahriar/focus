# Pomodoro Focus

A desktop Pomodoro timer and task list built with Zig and [nanoui](https://github.com/justrach/nanoui). It includes configurable focus and break sessions, task tracking, session statistics, and light/dark themes.

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

## Android

The Android APK build requirements and commands are documented in [ANDROID.md](./ANDROID.md).

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

## Project layout

- `src/timer/` — Pomodoro timer state and view
- `src/todo/` — task state and view
- `src/stats/` — session statistics
- `src/settings/` — timer and appearance settings
- `src/theme/` — app colors and shared UI components
- `build.zig` — Zig build, run, and test steps
