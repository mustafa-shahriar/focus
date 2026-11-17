# Building for Android

The Android build packages Pomodoro Focus as a NativeActivity APK using nanoui's Android backend.

The UI selects its compact layout below 680 logical units of width, with a mobile header and bottom navigation, stacked pages, and larger task controls. Resizing is based on width, so it also adapts to narrow desktop windows and tablet layouts.

## Requirements

- Zig 0.17.0
- Android SDK with **Android SDK Platform 34** and Android SDK Build-Tools installed
- Android NDK (r27 or newer)
- Java, including `keytool` (used to sign the APK)
- `adb` to install the APK on a device or emulator

The build helper looks for the SDK in `ANDROID_HOME` or `ANDROID_SDK_ROOT`, and finds the NDK under the SDK unless `ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT` is set.

The Android window is edge-to-edge: the top inset is painted with a theme-appropriate background, while header controls and page/navigation content stay within the system-bars' safe area. The app has no title bar or window buttons of its own there.

### One-step setup on Windows

`tools/android/install.ps1` installs everything the build needs without Android Studio:

```powershell
.\tools\android\install.ps1
```

It downloads a JDK 21, the SDK command-line tools and then `platform-tools`, Android SDK Platform 34, the newest build-tools and the newest NDK into `%LOCALAPPDATA%\Android` (the SDK in `Sdk\`), accepts the SDK licenses, records `JAVA_HOME`, `ANDROID_HOME` and `ANDROID_NDK_HOME` for your user, and adds the JDK's `bin` directory to your user `PATH` so `keytool` is available. Open a new terminal afterwards so the updated environment is visible.

### Set up the SDK path

If Android Studio installed the SDK in its default location, the helper can usually find it automatically. Otherwise, set the SDK and NDK paths before building.

PowerShell:

```powershell
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:ANDROID_NDK_HOME = "$env:ANDROID_HOME\ndk\<installed-ndk-version>"
```

Linux:

```sh
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/<installed-ndk-version>"
```

Use the actual installed NDK directory name in place of `<installed-ndk-version>`. If these variables are not set, the build helper also searches the SDK's `ndk` directory for the newest installed NDK.

## Debug build

The debug build is debuggable and uses the Android debug key (Android Studio's key when available, otherwise a generated key). This is the build to use for local development; it is not suitable for distribution.

Build and install on an ARM device:

```powershell
.\tools\android\build.ps1 -Target aarch64-linux-android -Optimize Debug -Install
```

For an x86-64 emulator, use `-Target x86_64-linux-android`. To build without installing, omit `-Install`. The equivalent direct Zig command is:

```sh
zig build apk -Dtarget=aarch64-linux-android -Doptimize=Debug
```

The APK is written to `zig-out/android/focus.apk`. Install it manually with `adb install -r zig-out/android/focus.apk`. To inspect Android logs while running the app, use `adb logcat`.

## Production release

An optimized Android build must have a release keystore configured; it will fail rather than use the debug key. Keep the keystore backed up and outside the repository. Never commit it or its passwords. The Windows setup script above installs JDK 21, including `keytool`; after running it, open a new PowerShell window. Invoke `keytool` through `JAVA_HOME` so it does not need to be on `PATH`. Create the keystore once (do not repeat this for app updates):

```powershell
& "$env:JAVA_HOME\bin\keytool.exe" -genkeypair -v `
  -keystore "$env:USERPROFILE\pomodoro-focus-release.jks" `
  -storetype JKS `
  -alias pomodoro-focus `
  -keyalg RSA -keysize 2048 -validity 10000
```

Keytool prompts for a keystore password and certificate details. For each release build, set the keystore path, alias, and password in the environment. The password is read by `apksigner` from the environment, not embedded in the build command:

```powershell
$env:FOCUS_ANDROID_KEYSTORE = "$env:USERPROFILE\pomodoro-focus-release.jks"
$env:FOCUS_ANDROID_KEY_ALIAS = "pomodoro-focus"
$securePassword = Read-Host "Keystore password" -AsSecureString
$passwordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
    $env:FOCUS_ANDROID_STORE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPtr)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPtr)
}

zig build apk -Dtarget=aarch64-linux-android -Doptimize=ReleaseFast
```

If the key password differs from the keystore password, also set `FOCUS_ANDROID_KEY_PASSWORD` in the environment. Use your CI secret manager to provide these environment variables in automated builds. Clear them from your shell when finished.

Before distributing a release, replace the example application ID `com.example.pomodorofocus` in `build.zig` with your own permanent reverse-DNS ID. Increment the app version in `build.zig.zon` for each release. The resulting signed APK is `zig-out/android/focus.apk`. Verify its signature with:

```powershell
& "$env:ANDROID_HOME\build-tools\<version>\apksigner.bat" verify --verbose zig-out/android/focus.apk
```

Replace `<version>` with the installed build-tools version directory. Preserve the same keystore for all future updates to the same application ID; Android will reject updates signed with a different key.

## Icon

The launcher icon is `assets/icon.png`, wired up in `build.zig`. `tools/android/make-icon.ps1` redraws it in the app's tomato-to-amber colors.
