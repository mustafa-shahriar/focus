# Building for Android

The Android build packages Pomodoro Focus as a NativeActivity APK using nanoui's Android backend.

The UI selects its compact layout below 680 logical units of width, with a mobile header and bottom navigation, stacked pages, and larger task controls. Resizing is based on width, so it also adapts to narrow desktop windows and tablet layouts.

## Requirements

- Zig 0.17.0
- Android SDK with **Android SDK Platform 34** and Android SDK Build-Tools installed
- Android NDK (install it with Android Studio's SDK Manager)
- Java, including `keytool` (used to sign the APK)
- `adb` to install the APK on a device or emulator

The build helper looks for the SDK in `ANDROID_HOME` or `ANDROID_SDK_ROOT`, and finds the NDK under the SDK unless `ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT` is set.

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

## Build the APK

For a 64-bit ARM phone or tablet:

```sh
zig build apk -Dtarget=aarch64-linux-android
```

For an x86-64 emulator:

```sh
zig build apk -Dtarget=x86_64-linux-android
```

The APK is written to:

```text
zig-out/android/focus.apk
```

`zig build -Dtarget=aarch64-linux-android` also builds and installs the APK into `zig-out/android/`.

## Install and launch

Connect a device with USB debugging enabled, or start an Android emulator, then run:

```sh
adb install -r zig-out/android/focus.apk
```

Launch **Pomodoro Focus** from the device's app launcher.

## Signing and app ID

The build creates a debug-signed APK, using Android Studio's debug key when available or generating a debug key in Zig's cache. The current application ID is `com.example.pomodorofocus`; change it in `build.zig` to a unique reverse-DNS ID before distributing the app.

Do not distribute the debug-signed APK as a release. Release distribution requires signing with your own protected release keystore.
