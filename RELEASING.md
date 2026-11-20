# Releasing

A release is one git tag. Pushing `v<version>` runs
[`.github/workflows/release.yml`](./.github/workflows/release.yml), which
tests the app, builds all three platforms, and publishes a GitHub release
containing:

| File | Used by |
| --- | --- |
| `focus-windows-x86_64.zip` | Windows app and its updater |
| `focus-linux-x86_64.tar.gz` | Linux app and its updater |
| `focus-android-arm64.apk` | Android app and its installer |
| `manifest.json` | Update checks on every platform |

The names are fixed: the app asks for them by name, and the updaters look
for `manifest.json` under `releases/latest/download`. Don't rename them.

```json
{
  "version": "0.2.0",
  "files": {
    "focus-windows-x86_64.zip": { "sha256": "..." },
    "focus-linux-x86_64.tar.gz": { "sha256": "..." },
    "focus-android-arm64.apk": { "sha256": "..." }
  }
}
```

The workflow generates this file and its hashes; you never edit it by hand.

## One-time setup: Android signing

Android only accepts an update that is signed with the same key as the
installed app and has a higher `versionCode`. The release workflow reads
the key from repository secrets, so set them once, before the first
release.

1. Create the keystore (once, and never again for this app). See
   [ANDROID.md](./ANDROID.md#production-release) for the `keytool`
   command; keep the `.jks` file and its passwords backed up somewhere
   safe and outside the repository.

2. Base64-encode the keystore, so it can be stored as a secret:

   ```powershell
   # Windows PowerShell: copies the encoded key to the clipboard
   [Convert]::ToBase64String(
     [IO.File]::ReadAllBytes("$env:USERPROFILE\pomodoro-focus-release.jks")
   ) | Set-Clipboard
   ```

   ```sh
   # macOS
   base64 -i ~/pomodoro-focus-release.jks | pbcopy
   # Linux
   base64 -w0 ~/pomodoro-focus-release.jks
   ```

3. Add the secrets, either in **Settings → Secrets and variables →
   Actions** on GitHub, or with the GitHub CLI:

   ```sh
   gh secret set ANDROID_KEYSTORE_BASE64   # paste the base64 text
   gh secret set ANDROID_KEY_ALIAS         # e.g. pomodoro-focus
   gh secret set ANDROID_STORE_PASSWORD    # the keystore password
   gh secret set ANDROID_KEY_PASSWORD      # only if it differs from the store password
   ```

   `ANDROID_KEY_PASSWORD` is optional; when it is unset or empty, the key
   is assumed to share the keystore's password.

If the keystore is ever lost, installed apps can no longer be updated:
they would have to be uninstalled and reinstalled under the same package
ID, which loses their saved state.

The Android application ID (`io.github.mustafashahriar.pomodorofocus` in
`build.zig`) is permanent for the same reason. Changing it installs a
separate app rather than updating this one.

## Publishing a release

1. Pick the new version and set it in `build.zig.zon`:

   ```zig
   .version = "0.2.0",
   ```

   That one line drives everything: the version printed by
   `focus --version`, the About card, the version the updaters compare
   against, the APK's `versionName`, and its `versionCode`
   (`major * 1_000_000 + minor * 1_000 + patch`, so `0.1.10` sorts above
   `0.1.9`). Any higher version is a valid update; there is no need to
   touch the ID or the keystore.

2. Commit it and push:

   ```sh
   git add build.zig.zon
   git commit -m "Release 0.2.0"
   git push origin master
   ```

3. Tag the same commit and push the tag:

   ```sh
   git tag v0.2.0
   git push origin v0.2.0
   ```

   The workflow checks that the tag is `v` plus `build.zig.zon`'s version
   and stops before publishing if they differ.

4. Watch the run under **Actions**. When it finishes, the release is
   published with the four files above and generated release notes.

## Checking the result

- `focus --version` in the downloaded build prints the new version (the
  Windows zip contains `focus.exe`; the Linux tarball contains `focus`).
- `apksigner verify --verbose focus-android-arm64.apk` reports the same
  signer as earlier releases.
- Settings → **Updates** in an installed copy of the previous version
  finds the release within a few seconds of launch.

## How the update installs

**Windows and Linux.** A release build (anything built with
`-Doptimize=ReleaseSafe` or `-Doptimize=ReleaseFast`) checks every six
hours and downloads the new archive in the background, verifying its
sha256 and running the unpacked program with `--version` before keeping
it. **Update and restart** installs it and starts the new version; if the
user quits with an update waiting, it is installed as the app closes.

Two conditions are required, and the card explains when they aren't met:

- The app must be installed in a folder the user can write to. Under
  `C:\Program Files` or `/usr`, the updater stays off; unzip or untar
  into the user's own folder instead.
- Linux needs `curl` at `/usr/bin/curl` and `tar`, which every normal
  distribution provides.

Builds made with plain `zig build` (debug builds) never update
themselves, so development executables can't be replaced by a release.

**Android.** **Get update** opens the APK's download URL in the browser,
which downloads it and hands it to Android's installer; confirming the
install replaces the app and keeps its data. The browser needs the
"Install unknown apps" permission for that to work, and the app has to
come from this release channel rather than an app store.

## Linux compatibility

The Linux build targets `x86_64-linux-gnu.2.28`, so it runs on glibc 2.28
and newer (Debian 10, Ubuntu 18.10+, and later distributions). Raising
that number makes the binary run on fewer systems; lowering it can fail
to link against the runner's libraries.
