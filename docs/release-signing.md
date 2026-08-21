# Release Signing & Store Builds

How a signed store build of Glassvow is produced on this machine, and where
every credential lives. Set up interactively by `scripts/store_signing_wizard.sh`
(re-runnable; stages skip work already done). Requirements background:
`docs/research/2026-08-13-store-compliance-dossier.md` (wayfinder #162);
this pipeline is wayfinder #165.

## Toolchain (all pinned)

| Piece | Where | Why this one |
|---|---|---|
| Godot 4.7.2.stable | `godot` on PATH | engine pin (SKILL.md §1) |
| Export templates 4.7.2 | `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` — must contain `ios.zip`, `android_source.zip`, `android_debug.apk`, `android_release.apk`; the selected mobile, macOS and no-thread web templates were installed 2026-08-21 from the checksum-verified official `.tpz` | must match engine version exactly |
| JDK 17 (Temurin 17.0.20) | `~/.local/share/jdk-17/Contents/Home`, wired into Godot's `export/android/java_sdk_path` editor setting | Godot 4.7's gradle template runs Gradle 8.11.1, which rejects JDK >23 ("Unsupported class file major version 69" on the machine's JDK 25); docs pin OpenJDK 17 |
| Android SDK | `~/Library/Android/sdk` (platform android-36, build-tools 36.0.0) | Play requires target API 36 from 2026-08-31 |
| Xcode 26 | `/Applications/Xcode.app` | App Store uploads must be built with the iOS 26 SDK since 2026-04-28 |
| Android gradle template | `android/` (gitignored, machine-local) | reinstall any checkout: `mkdir -p android/build && unzip -o ~/Library/Application\ Support/Godot/export_templates/4.7.2.stable/android_source.zip -d android/build && echo 4.7.2.stable > android/.build_version && touch android/build/.gdignore` — the wizard's preflight does this automatically |
| Sentry for Godot **2.1.1** | `addons/sentry` ([release](https://github.com/getsentry/sentry-godot/releases/tag/2.1.1), tree `d288ad9`) | crash reporting on iOS store + Dev Review; do not follow `latest`. Client DSN lives in `project.godot` `[sentry]`; privacy-minimal (`attach_log=false`). Android Gradle injection is a later wave |

**4.7.2 template install receipt (2026-08-21):** the official
`Godot_v4.7.2-stable_export_templates.tpz` matched its published SHA-512,
`ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079`.
The selected iOS, Android, macOS and no-thread Web templates are installed
under the 4.7.2 directory; the old 4.7.1 directory remains available only for
replaying historical evidence.

## Credentials — where they live

- **Play upload keystore**: `~/Library/Application Support/Godot/keystores/glassvow-upload.keystore`
  (alias `glassvow-upload`, RSA 4096, 10,000-day validity; store pass == key
  pass, alphanumeric — a Godot requirement). Password lives in the password
  manager only, **never on disk**. Play App Signing holds the real app key;
  this upload key is resettable via a Play Console help form if lost.
- **Apple Team ID**: `application/app_store_team_id` in `export_presets.cfg`
  (not secret; committed).
- **Apple distribution cert + provisioning profile**: minted and stored by
  Xcode automatic signing (Keychain); nothing to manage by hand.
- **`export_credentials.cfg`**: written by the Godot editor if keystore fields
  are ever filled in the Export dialog; gitignored along with `*.keystore`.

## Export recipe

Presets live in `export_presets.cfg`: `iOS` (project-only export) and
`Android (Play AAB)` (gradle build, AAB, target SDK 36, arm64-v8a only — all
four floor devices are 64-bit). Godot does not create target folders:
`mkdir -p build/android build/ios` first.

**Android dev build** (debug keystore, auto-configured):

```bash
godot --headless --export-debug "Android (Play AAB)" build/android/glassvow-dev.aab
```

**Android store build** (signed with the upload key; password prompted from the
password manager — the env vars keep it out of shell history and repo files):

```bash
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$HOME/Library/Application Support/Godot/keystores/glassvow-upload.keystore" \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=glassvow-upload \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<from password manager> \
  godot --headless --export-release "Android (Play AAB)" build/android/glassvow.aab
jarsigner -verify build/android/glassvow.aab
```

Bump `version/code` in the Android preset before every Play upload. Play's
upload screen re-verifies the target API level (must read 36).

**iOS store build** (Godot signs nothing; Xcode does). The shipping iOS
family is iPhone **and** iPad — both iOS presets already emit Apple
`TARGETED_DEVICE_FAMILY = "1,2"` from Godot enum `2` (see the tethered
path below). Release order note: Android is deferred — it ships after
the iOS release, before desktop/Steam (map #156 decision, 2026-08-13) —
so iOS is the release path that matters now.

```bash
godot --headless --export-release "iOS" build/ios/glassvow.ipa   # emits build/ios/glassvow.xcodeproj
# archive with development signing (verified headless on this machine):
xcodebuild -project build/ios/glassvow.xcodeproj -scheme glassvow \
  -destination "generic/platform=iOS" archive \
  -archivePath build/ios/glassvow.xcarchive \
  -allowProvisioningUpdates CODE_SIGN_IDENTITY="Apple Development"
# re-sign with Apple Distribution + export the .ipa:
xcodebuild -exportArchive -archivePath build/ios/glassvow.xcarchive \
  -exportPath build/ios/export \
  -exportOptionsPlist scripts/ios_export_options.plist \
  -allowProvisioningUpdates
```

`scripts/ios_export_options.plist` keeps `method = app-store-connect`,
`teamID = V45S7U2LZB`, and `signingStyle = automatic`. It also pins
`manageAppVersionAndBuildNumber = false` so App Store Connect cannot rewrite
marketing **1.0.0** / build **1**, and `uploadSymbols = true` so a direct
App Store Connect upload includes symbols. With `destination = export`, retain
the archive's `dSYMs/` for the later Apple and Sentry symbol-upload steps; dSYMs
are not embedded in the IPA.

Headless, `-exportArchive` alone fails with **"No Accounts"** (the CLI can't
reach Xcode's Apple ID session). The working path — verified 2026-08-13, it
produced a distribution-signed `glassvow.ipa` (Team V45S7U2LZB, full Apple
chain) — authenticates with the existing App Store Connect **team API key**:
append `-authenticationKeyPath` / `-authenticationKeyID` /
`-authenticationKeyIssuerID` to the `-exportArchive` command above. The `.p8`
lives under `~/.appstoreconnect/private_keys/`; its key + issuer IDs are in
`~/.appstoreconnect/octomiser-api-key.json` (a team-wide key, first created
for Octomiser's TestFlight uploads — IDs deliberately not reproduced here:
public repo). The same key later serves upload/TestFlight automation.

## iOS build on a tethered device — the measurement path, not the store path

Performance tickets need a `dev_tools` build running on real hardware (#233
measures the map scene on iPad 8). That is a **different route** from the store
recipe above and the two must not be confused: `scripts/ios_export_options.plist`
declares `method = app-store-connect`, which produces an artifact that cannot be
installed on a tethered device. It is not needed here at all — Godot's own
`--export-debug` writes a `glassvow/export_options.plist` next to the project
with `method = development` and the team already filled in.

Verified end to end on this machine, 2026-08-14, against an iPhone 16 Pro Max:

```bash
mkdir -p build/ios-dev                       # Godot will not create it
godot --headless --export-debug "iOS Dev Review" build/ios-dev/glassvow.ipa
xcodebuild -project build/ios-dev/glassvow.xcodeproj -scheme glassvow \
  -configuration Debug -destination 'id=<devicectl identifier>' \
  -allowProvisioningUpdates -derivedDataPath build/ios-dev/dd build
xcrun devicectl device install app --device <devicectl identifier> \
  build/ios-dev/dd/Build/Products/Debug-iphoneos/glassvow.app
```

`xcrun devicectl list devices` gives the identifier. Signing needs no new
profile: automatic signing picked `Apple Development: James TO` under the
wildcard `iOS Team Provisioning Profile: *`, and **BUILD SUCCEEDED** without a
portal visit.

Three things that will stop you:

- **Do not confuse Godot's family enum with Apple's.** Both iOS presets
  (`iOS` store and `iOS Dev Review`) set
  `application/targeted_device_family=2`. That is Godot's INT enum for
  **iPhone & iPad** (hint: `iPhone,iPad,iPhone & iPad`; default 2). The
  exporter writes Xcode `TARGETED_DEVICE_FAMILY = "1,2"`. Apple's family
  `2` is iPad-only; Godot's enum `1` is the iPad-only value. Writing the
  Apple string `1,2` into that INT field is out of range and can emit an
  empty family (godotengine/godot#122262). A store-recipe IPA already
  installs on a phone; do not append `TARGETED_DEVICE_FAMILY="1,2"` at
  `xcodebuild`.
- **The device must be tethered and unlocked.** A Wi-Fi-paired device reports
  `available (paired)` from `devicectl list devices` while
  `tunnelState: disconnected` and `tunnelIPAddress: nil`; installing then fails
  with `com.apple.dt.CoreDeviceError error 4`. Check `tunnelState` before
  blaming the build.
- **`IPHONEOS_DEPLOYMENT_TARGET` is 15.0, which is below the renderer's floor.**
  `project.godot` selects the Mobile renderer, whose documented minimum is
  iPadOS 16 + Metal 3 (see the mobile performance-floor research note). The app
  therefore *installs* on an OS where the renderer is not supported, and it will
  produce numbers that look valid. Read the OS version off the device before
  trusting any measurement taken on it.

Benches launch through `main.gd` user-arg routes (`--map-bench`, `--perf-out=`),
never `-s`: measured 2026-08-14 on iPad 8, the iOS release template silently
ignores `-s` both as a `devicectl` launch argument and via the Info.plist
`godot_cmdline` array — the app boots `main.tscn` either way — while generic
options from the same array (`--log-file`, `--verbose`) are honoured. The
working recipe: set `godot_cmdline` to
`["--log-file","user://bench.log","--","--map-bench"]` in the generated
project's Info.plist (plutil, then rebuild — the exporter regenerates the plist
on every export), and pull the log with
`xcrun devicectl device copy from … --domain-type appDataContainer
--domain-identifier io.fol2.glassvow --source Documents/bench.log`, since
`print()` output never reaches `devicectl --console` (also measured; `user://`
maps to `Documents/`).

Use `--export-debug` only to rehearse the plumbing. Timings for a ticket must
come from `--export-release`: the debug engine slice is a different binary, and
`tools/bench_map_scene.gd` stamps a DEBUG BUILD warning across its own output to
stop a rehearsal run being pasted in as evidence.

## Store accounts

Apple Developer Program (US$99/yr) and Play Console (US$25 one-time) are
walked through by wizard stages 2–4, including identity verification, the
payments profiles, and the EU DSA trader notes. Compliance detail and
deadlines: the store-compliance dossier.
