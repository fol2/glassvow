# #432 — omit unused empty iOS privacy usage descriptions

Godot 4.7.2.stable.official.ed1daf0bf. Project-only exports. No signing, archive, or upload.

## Non-use

Repo search for device camera / microphone / photo-library APIs returned no production hits:

- `CameraServer`, `CameraFeed`, `AVCapture`, `UIImagePicker`
- `AudioStreamMicrophone`, `AudioEffectCapture`, `AudioEffectRecord`
- `OS.request_permission`, `PHPhoto`
- `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription` (except this ticket's stripper and tests)

In-game `Camera3D` / map "camera" are render cameras, not `NSCameraUsageDescription`. Sentry 2.1.1 is privacy-minimal (`attach_screenshot=false`); this ticket does not touch `PrivacyInfo.xcprivacy`.

Fresh Store export `project.pbxproj` has no camera refs. `libgodot_camera.ios*.xcframework` is not copied into the Xcode project (`modules/camera=false`).

## Source of the empty keys

They are not authored anywhere in this tree until this ticket. Godot 4.7.2's iOS template `godot_apple_embedded-Info.plist` always contains:

```
<key>NSCameraUsageDescription</key>
<string>$camera_usage_description</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>$photolibrary_usage_description</string>
<key>NSMicrophoneUsageDescription</key>
<string>$microphone_usage_description</string>
<key>ITSAppUsesNonExemptEncryption</key>
<false />
```

`EditorExportPlatformAppleEmbedded` substitutes `privacy/*_usage_description` (default `""`) even when those options are absent from `export_presets.cfg`. Empty strings still emit the keys.

`ITSAppUsesNonExemptEncryption = false` is hardcoded in the same template, not an export-preset field.

## Change

Both `iOS` and `iOS Dev Review` presets now pin `modules/camera=false` and empty usage descriptions. `addons/glassvow_ios_export` strips those three keys from `{stem}/{stem}-Info.plist` after a Godot iOS export when the strings are empty. Filled descriptions are kept.

## Exported plist

Baseline Store export (`/tmp/glassvow-432-before/glassvow/glassvow-Info.plist`):

```
<key>ITSAppUsesNonExemptEncryption</key>
<false />
…
<key>NSCameraUsageDescription</key>
<string></string>
<key>NSPhotoLibraryUsageDescription</key>
<string></string>
<key>NSMicrophoneUsageDescription</key>
<string></string>
```

Fresh Store and Dev Review exports after the change (`docs/reviews/432/after-glassvow-Info.plist`; the two Info.plists compared identical):

```
<key>ITSAppUsesNonExemptEncryption</key>
<false />
```

No `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, or `NSPhotoLibraryUsageDescription`. Godot-generated `PrivacyInfo.xcprivacy` (required-reason APIs) left in place.

## Gates

| Gate | Result |
|---|---|
| `godot --version` | `4.7.2.stable.official.ed1daf0bf` |
| `tools/check_scripts.sh` (new files) | `scripts OK (3 checked)` |
| `godot --headless -s res://tests/run_all.gd` | `PASS (59 tests)` including `test_ios_plist_privacy.gd` |
| `python3 tools/check_anchors.py` | `anchors OK` |
| `python3 tools/check_benchmark_freeze.py` | `benchmark citations frozen (602 in 55 file(s))` |
| `godot --headless --export-release "iOS"` | rc 0, keys omitted |
| `godot --headless --export-release "iOS Dev Review"` | rc 0, keys omitted |

`tools/check_imports.sh` reports the sandbox `get_system_ca_certificates` `ERROR:` on stderr; Godot rc 0. The same line appeared on the pre-change export.
