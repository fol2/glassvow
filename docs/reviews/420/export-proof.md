# #420 AFK / export proof — Sentry Cocoa privacy manifest and dist

Slice: AFK/export-proof only. No tethered probes, no crashes, no upload,
no credentials, no GitHub writes. Engine: **Godot 4.7.2.stable.official.ed1daf0bf**.
Preset: `iOS` (`application/export_project_only=true`).

```
godot --headless --export-release "iOS" build/ios/glassvow.ipa
```

## Baseline (pre-change, commit `a7823d7`)

| Check | Generated location | Value |
|---|---|---|
| App-level Godot `PrivacyInfo.xcprivacy` | `build/ios/PrivacyInfo.xcprivacy` | present (required-reason APIs only; not Sentry Cocoa) |
| Sentry Cocoa `PrivacyInfo.xcprivacy` | `build/ios/glassvow/dylibs/addons/sentry/bin/ios/Sentry.xcframework/ios-arm64/SentryObjC.framework/` | **missing** |
| Same, simulator slice | `…/ios-arm64_x86_64-simulator/SentryObjC.framework/` | **missing** |
| `ITSAppUsesNonExemptEncryption` | `build/ios/glassvow/glassvow-Info.plist` | `false` |
| Marketing version | `build/ios/glassvow.xcodeproj/project.pbxproj` | `MARKETING_VERSION = 0.6.0` |
| iOS build number | same pbxproj | `CURRENT_PROJECT_VERSION = 0.6.0` (same string as marketing) |
| Sentry `dist` source | `application/sentry_loop.gd` | `application/config/version` (marketing `0.6.0`) |

The 2.1.1 vendored `Sentry.xcframework` is a dynamic `SentryObjC.framework`
(`CFBundleShortVersionString` 9.24.0). Godot copies the whole xcframework
into `glassvow/dylibs/…`. A file that is not in the source framework cannot
appear in the generated project.

## After packaging

The minimum honest manifest is sentry-cocoa **9.24.0**
`Sources/Resources/PrivacyInfo.xcprivacy` (Crash / Performance / Other
Diagnostic data, unlinked, not tracking, App Functionality; UserDefaults
`CA92.1`, SystemBootTime `35F9.1`, FileTimestamp `C617.1`). No extra
collected-data types were added (no Device ID, user ID, location, photos,
contacts, advertising).

| Check | Generated location | Value |
|---|---|---|
| Sentry Cocoa privacy manifest (device) | `build/ios/glassvow/dylibs/addons/sentry/bin/ios/Sentry.xcframework/ios-arm64/SentryObjC.framework/PrivacyInfo.xcprivacy` | present; SHA-256 `118b16e0e97ffe8b6f1f01b7e04f68e5da764474a4d39d2933b0eeaef3cdc0ca` |
| Sentry Cocoa privacy manifest (simulator) | `build/ios/glassvow/dylibs/addons/sentry/bin/ios/Sentry.xcframework/ios-arm64_x86_64-simulator/SentryObjC.framework/PrivacyInfo.xcprivacy` | identical |
| Repo/plugin export path | `addons/sentry/bin/ios/Sentry.xcframework/…/SentryObjC.framework/PrivacyInfo.xcprivacy` | same SHA |
| App-level Godot manifest | `build/ios/PrivacyInfo.xcprivacy` | still present (distinct file; Godot template) |
| `ITSAppUsesNonExemptEncryption` | `build/ios/glassvow/glassvow-Info.plist` | still `<false />` |
| Marketing version | pbxproj | `MARKETING_VERSION = 0.6.0` |
| iOS build number | pbxproj | `CURRENT_PROJECT_VERSION = 1` |
| Sentry `dist` | `GlassvowMainLoop.IOS_BUILD_NUMBER` / `sentry/options/dist` / both iOS presets `application/version` | `"1"` (numeric CFBundleVersion, not marketing) |

Xcode project reference for the Cocoa SDK (unchanged wrapper path):

```
glassvow/dylibs/addons/sentry/bin/ios/Sentry.xcframework
```

Checked-in copy of the Cocoa manifest: [SentryObjC.PrivacyInfo.xcprivacy](SentryObjC.PrivacyInfo.xcprivacy).
Plist/version excerpts: [glassvow-Info.plist.excerpt](glassvow-Info.plist.excerpt),
[pbxproj-versions.excerpt](pbxproj-versions.excerpt).
Source vs generated-framework `ls`/`shasum` (fresh 4.7.2 project-only
export; source plugin path and exported copies share the pin, Godot
app-level `PrivacyInfo.xcprivacy` does not):
[generated-framework-ls-shasum.txt](generated-framework-ls-shasum.txt).
`tests/test_sentry_release.gd` pins that SHA with `FileAccess.get_sha256`.

`libsentry.ios.release.xcframework` (the Godot GDExtension wrapper) still
has no privacy manifest. This slice packaged a static file into the Cocoa
framework only; native plugin source was not modified.

## Gates

- `godot --version` → `4.7.2.stable.official.ed1daf0bf`
- `tools/check_scripts.sh` → `scripts OK (219 checked)`
- `godot --headless -s res://tests/run_all.gd` → `PASS (58 tests)`
- `python3 tools/check_anchors.py` → `anchors OK`
- `python3 tools/check_benchmark_freeze.py` → `benchmark citations frozen (602 in 55 file(s))`
- `tools/check_imports.sh` import completed (`godot` rc 0). The sandbox
  prints `ERROR: Condition "ret != noErr"` from `get_system_ca_certificates`
  (`os_macos.mm`), which the stderr-ERROR grep treats as failure. Not an
  asset-import defect.

## Remaining HITL (James — tethered device)

Not this slice. Still owed on #420, on a **Dev Review** or RC-shape iOS
build with Sentry on and matching dSYMs uploaded:

1. One GDScript error — grouped Sentry event id + native console + payload
   inspection (no logs, screenshots, scene tree, GDScript locals, user id,
   save, seed, deck, locale strings, or player-entered text).
2. One deliberate native crash — same proof.
3. One iOS main-thread hang — same proof.

Record event ids on the ticket. Do not paste the DSN.
