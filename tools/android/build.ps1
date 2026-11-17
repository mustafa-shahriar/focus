# Builds the Android APK with the toolchain tools/android/install.ps1 set up
# (or any SDK found through ANDROID_HOME). An emulator build is:
#   .\tools\android\build.ps1 -Target x86_64-linux-android
# Add -Install to install the APK on the connected device or emulator.
param(
    [string]$Target = "aarch64-linux-android",
    [string]$Optimize = "ReleaseSafe",
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $root
try {
    $sdk = $env:ANDROID_HOME
    if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
    if (-not $sdk) {
        $candidate = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
        if (Test-Path $candidate) { $sdk = $candidate }
    }
    if (-not $sdk -or -not (Test-Path $sdk)) {
        throw "No Android SDK: run tools/android/install.ps1 first, or set ANDROID_HOME."
    }
    $env:ANDROID_HOME = $sdk

    if (-not $env:JAVA_HOME) {
        $jdk = Join-Path (Split-Path -Parent $sdk) 'jdk21'
        if (Test-Path (Join-Path $jdk 'bin\java.exe')) { $env:JAVA_HOME = $jdk }
    }
    if ($env:JAVA_HOME) { $env:PATH = "$env:JAVA_HOME\bin;$sdk\platform-tools;$env:PATH" }

    if (-not $env:ANDROID_NDK_HOME -and (Test-Path (Join-Path $sdk 'ndk'))) {
        $ndk = Get-ChildItem (Join-Path $sdk 'ndk') -Directory |
            Sort-Object { [version]($_.Name -replace '[^0-9.].*$', '') } -Descending |
            Select-Object -First 1
        if ($ndk) { $env:ANDROID_NDK_HOME = $ndk.FullName }
    }

    Write-Output "SDK: $sdk"
    Write-Output "NDK: $env:ANDROID_NDK_HOME"
    Write-Output "Java: $env:JAVA_HOME"

    zig build apk "-Dtarget=$Target" "-Doptimize=$Optimize"
    if ($LASTEXITCODE -ne 0) { throw "zig build failed ($LASTEXITCODE)" }

    $apk = Join-Path $root 'zig-out\android\focus.apk'
    if (-not (Test-Path $apk)) { throw "no APK at $apk" }
    Write-Output "APK: $apk"

    if ($Install) {
        $adb = Join-Path $sdk 'platform-tools\adb.exe'
        if (-not (Test-Path $adb)) { $adb = 'adb' }
        & $adb install -r $apk
        if ($LASTEXITCODE -ne 0) { throw "adb install failed ($LASTEXITCODE)" }
        Write-Output "Installed. Launch Pomodoro Focus from the app list."
    }
} finally {
    Pop-Location
}
