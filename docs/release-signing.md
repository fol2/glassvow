# Release Signing & Store Builds

How a signed store build of Glassvow is produced on this machine, and where
every credential lives. Set up interactively by `scripts/store_signing_wizard.sh`
(re-runnable; stages skip work already done). Requirements background:
`docs/research/2026-08-13-store-compliance-dossier.md` (wayfinder #162);
this pipeline is wayfinder #165.

## Toolchain (all pinned)

| Piece | Where | Why this one |
|---|---|---|
| Godot 4.7.1.stable | `godot` on PATH | engine pin (SKILL.md §1) |
| Export templates 4.7.1 | `~/Library/Application Support/Godot/export_templates/4.7.1.stable/` — must contain `ios.zip`, `android_source.zip`, `android_debug.apk`, `android_release.apk` (the slim install shipped only macOS+web; the mobile four were added 2026-08-13 from the official `.tpz`) | must match engine version exactly |
| JDK 17 (Temurin 17.0.20) | `~/.local/share/jdk-17/Contents/Home`, wired into Godot's `export/android/java_sdk_path` editor setting | Godot 4.7's gradle template runs Gradle 8.11.1, which rejects JDK >23 ("Unsupported class file major version 69" on the machine's JDK 25); docs pin OpenJDK 17 |
| Android SDK | `~/Library/Android/sdk` (platform android-36, build-tools 36.0.0) | Play requires target API 36 from 2026-08-31 |
| Xcode 26 | `/Applications/Xcode.app` | App Store uploads must be built with the iOS 26 SDK since 2026-04-28 |
| Android gradle template | `android/` (gitignored, machine-local) | reinstall any checkout: `mkdir -p android/build && unzip -o ~/Library/Application\ Support/Godot/export_templates/4.7.1.stable/android_source.zip -d android/build && echo 4.7.1.stable > android/.build_version && touch android/build/.gdignore` — the wizard's preflight does this automatically |

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

**iOS store build** (Godot signs nothing; Xcode does). Release order note:
Android is deferred — it ships after the iOS release, before desktop/Steam
(map #156 decision, 2026-08-13) — so iOS is the release path that matters now.

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

If `-exportArchive` fails with **"No Accounts"** the CLI can't reach Xcode's
Apple ID session: open the `.xcarchive` (Organizer) → Distribute App →
App Store Connect → **Export** (Upload once a store listing exists). For
fully headless releases, create an App Store Connect API key and pass
`-authenticationKeyPath` / `-authenticationKeyID` / `-authenticationKeyIssuerID`.

## Store accounts

Apple Developer Program (US$99/yr) and Play Console (US$25 one-time) are
walked through by wizard stages 2–4, including identity verification, the
payments profiles, and the EU DSA trader notes. Compliance detail and
deadlines: the store-compliance dossier.
