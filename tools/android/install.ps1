# Installs what an Android build of this app needs on Windows:
#   - a JDK (apksigner, keytool)
#   - the Android SDK command-line tools
#   - platform-tools, a platform, build-tools and the NDK
# Everything lands under %LOCALAPPDATA%\Android (the SDK in Sdk\, the JDK
# beside it), which is where Android Studio puts the SDK and where zig's
# Android support and nanoui's APK builder look.
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:TEMP 'android-install.log'
function Log($m) {
    $line = "[{0:HH:mm:ss}] {1}" -f (Get-Date), $m
    Add-Content -Path $log -Value $line
    Write-Output $line
}

$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$jdkDir = Join-Path $env:LOCALAPPDATA 'Android\jdk21'
$dl = Join-Path $env:TEMP 'android-dl'
New-Item -ItemType Directory -Force -Path $dl, $sdk | Out-Null

$drive = (Get-Item $env:LOCALAPPDATA).PSDrive
Log ("free on {0}: {1:N1} GB" -f $drive.Name, ($drive.Free / 1GB))

function Download($url, $out) {
    if ((Test-Path $out) -and ((Get-Item $out).Length -gt 1MB)) {
        Log "cached $(Split-Path -Leaf $out)"
        return
    }
    Log "GET $url"
    & curl.exe -L --fail --retry 3 --retry-delay 2 --connect-timeout 30 -s -o $out $url
    if ($LASTEXITCODE -ne 0) {
        Remove-Item $out -ErrorAction SilentlyContinue
        throw "download failed: $url"
    }
    Log ("  {0:N1} MB" -f ((Get-Item $out).Length / 1MB))
}

# ── JDK ─────────────────────────────────────────────────────────────────────
$java = Join-Path $jdkDir 'bin\java.exe'
if (-not (Test-Path $java)) {
    $zip = Join-Path $dl 'microsoft-jdk-21-windows-x64.zip'
    Download 'https://aka.ms/download-jdk/microsoft-jdk-21-windows-x64.zip' $zip
    Log 'extracting the JDK'
    New-Item -ItemType Directory -Force -Path $jdkDir | Out-Null
    Expand-Archive -Path $zip -DestinationPath $jdkDir -Force
    $inner = Get-ChildItem $jdkDir -Directory | Select-Object -First 1
    if ($inner -and -not (Test-Path (Join-Path $jdkDir 'bin'))) {
        Get-ChildItem $inner.FullName | Move-Item -Destination $jdkDir -Force
        Remove-Item $inner.FullName -Recurse -Force
    }
}
Log "java: $(& $java -version 2>&1 | Select-Object -First 1)"

# ── SDK command-line tools ─────────────────────────────────────────────────
$sdkmanager = Join-Path $sdk 'cmdline-tools\latest\bin\sdkmanager.bat'
if (-not (Test-Path $sdkmanager)) {
    $candidates = @(
        'commandlinetools-win-13114758_latest.zip',
        'commandlinetools-win-12700392_latest.zip',
        'commandlinetools-win-11076708_latest.zip'
    )
    $zip = $null
    foreach ($c in $candidates) {
        try {
            $o = Join-Path $dl $c
            Download "https://dl.google.com/android/repository/$c" $o
            $zip = $o
            break
        } catch {
            Log "no $c"
        }
    }
    if (-not $zip) { throw 'no command-line tools to download' }
    Log 'extracting the command-line tools'
    $ct = Join-Path $sdk 'cmdline-tools'
    Expand-Archive -Path $zip -DestinationPath $ct -Force
    if (Test-Path (Join-Path $ct 'cmdline-tools')) {
        Move-Item (Join-Path $ct 'cmdline-tools') (Join-Path $ct 'latest') -Force
    }
}
if (-not (Test-Path $sdkmanager)) { throw "no sdkmanager at $sdkmanager" }

$env:JAVA_HOME = $jdkDir
$env:ANDROID_HOME = $sdk
$env:PATH = "$jdkDir\bin;$sdk\platform-tools;$env:PATH"
$yes = (1..400 | ForEach-Object { 'y' }) -join "`n"

Log 'accepting the SDK licenses'
$yes | & $sdkmanager --sdk_root=$sdk --licenses *> $null

Log 'listing the SDK packages'
$list = (& $sdkmanager --sdk_root=$sdk --list 2>&1 | Out-String)
Log ("list: {0} characters" -f $list.Length)

function Newest($pattern) {
    $found = [regex]::Matches($list, $pattern) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    $best = $null
    $bestV = $null
    foreach ($v in $found) {
        try { $parsed = [version]$v } catch { continue }
        if ($null -eq $bestV -or $parsed -gt $bestV) { $bestV = $parsed; $best = $v }
    }
    return $best
}

$platform = Newest 'platforms;android-([0-9]+)'
$buildTools = Newest 'build-tools;([0-9]+\.[0-9]+\.[0-9]+)'
$ndk = Newest 'ndk;([0-9]+\.[0-9]+\.[0-9]+)'
# build.zig's `target_api` is 34, and the APK builder wants that exact
# platform: install it even when a newer one exists.
if ($list -match 'platforms;android-34\s*\|') { $platform = '34' }
Log "newest: platform android-$platform, build-tools $buildTools, ndk $ndk"
if (-not $platform -or -not $buildTools -or -not $ndk) { throw 'could not read the package list' }

$pkgs = @('platform-tools', "platforms;android-$platform", "build-tools;$buildTools", "ndk;$ndk")
Log ("installing: {0}" -f ($pkgs -join ', '))
$yes | & $sdkmanager --sdk_root=$sdk @pkgs 2>&1 | ForEach-Object { Log "  $_" }

# ── Remember where they are ────────────────────────────────────────────────
[Environment]::SetEnvironmentVariable('JAVA_HOME', $jdkDir, 'User')
[Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdk, 'User')
[Environment]::SetEnvironmentVariable('ANDROID_NDK_HOME', (Join-Path $sdk "ndk\$ndk"), 'User')
Log "JAVA_HOME=$jdkDir"
Log "ANDROID_HOME=$sdk"
Log "ANDROID_NDK_HOME=$(Join-Path $sdk "ndk\$ndk")"
Log 'done'
