# #413 AFK — 1.0.0 release identity and export options

Slice: AFK identity / export-options only. No signing, archive, upload,
credentials, ASC mutation, app-record creation, bundle/team/device-family/
orientation edits, or TestFlight claim. Engine: **Godot 4.7.2.stable**.

Accommodates landed #432 (empty usage-description strip) and the #420 AFK
Sentry slice landed by PR #435 (Cocoa privacy manifest + numeric `dist=1`).
Those tests are unchanged; #420 tethered probes remain open.

## Version matrix

| Surface | Field | Value |
|---|---|---|
| Project | `application/config/version` | `1.0.0` (marketing) |
| iOS Store | `application/short_version` | `1.0.0` |
| iOS Store | `application/version` | `1` (numeric CFBundleVersion) |
| iOS Dev Review | `application/short_version` | `1.0.0` |
| iOS Dev Review | `application/version` | `1` |
| Sentry | `options/dist` / `GlassvowMainLoop.IOS_BUILD_NUMBER` | `1` |
| macOS | `application/short_version` and `application/version` | `1.0.0` (shared marketing convention; macOS CFBundleVersion is not the iOS numeric build) |
| Android Play AAB / Dev Review | `version/name` | `1.0.0` |
| Android Play AAB / Dev Review | `version/code` | `1` |

## Export options (`scripts/ios_export_options.plist`)

Retained: `method=app-store-connect`, `destination=export`, `teamID=V45S7U2LZB`,
`signingStyle=automatic`. Added: `manageAppVersionAndBuildNumber=false`,
`uploadSymbols=true`.

## Gates

Recorded after the local 4.7.2 run on this slice (no signed archive).

| Gate | Result |
|---|---|
| `godot --version` | `4.7.2.stable.official.ed1daf0bf` |
| `tools/check_imports.sh` | `asset import OK` |
| `tools/check_scripts.sh` | `scripts OK (1 checked)` on `tests/test_release_identity.gd`; `scripts OK (221 checked)` on tracked scripts |
| `godot --headless -s res://tests/run_all.gd` | `PASS (60 tests)` including `test_release_identity.gd`, `test_sentry_release.gd`, and `test_ios_plist_privacy.gd`. Dummy-renderer RID leaks on stderr do not change the exit. |
| `python3 tools/check_anchors.py` | `anchors OK` |
| `python3 tools/check_benchmark_freeze.py` | `benchmark citations frozen (602 in 55 file(s))` |
| `python3 tools/check_store_dev_exclusion.py` | `store-dev-exclusion OK` |

`tests/test_release_identity.gd` pins the matrix and plist flags.
`tests/test_sentry_release.gd` and `tests/test_ios_plist_privacy.gd` still own
#420 / #432.

## Remaining HITL / blockers

Not this slice. Still owed before a TestFlight upload:

- **#295** — paid map kit / runtime budgets (native blocker on #413).
- **#426** — App Store Connect app record and iOS 1.0.0 version (HITL).
- **#434** — Store PCK hardening landed in PR #436; exact-main CI passed at
  `b9dc8b59354559c588f8de71e4743ebb86f50172` ([run 32446467045](https://github.com/fol2/glassvow/actions/runs/32446467045)).
- **Signing / archive / upload** — Codex owns; this slice does not sign,
  authenticate, or upload.
- **ASC / TestFlight** — no app record claimed; no build id recorded.
