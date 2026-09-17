# #542 / 5721191528 — source repair and inert evidence

**Disposition: SOURCE_BLOCKED / NATIVE_UNVERIFIED. This is an author handoff, not an acceptance or review verdict.** The connected driver, capture, verifier and reservation-account implementation are published. The aggregate native containment backend remains unimplemented; the native entry refuses before reservation/spawn. Consequently this is NOT a complete execution-ready producer/meter and does not satisfy the batch's stronger source-complete endpoint. This package records the remaining source blocker explicitly rather than presenting a disabled entry as a finished meter.

## Exact basis and delivery

Task authority: [#542/5721191528](https://github.com/fol2/glassvow/issues/542#issuecomment-5721191528), plus the owner's sole-author takeover and renewed GitHub write grant. No local writer/reviewer was invoked. Current-main AGENTS, AI-SDLC and Godot instructions were refreshed; M remained `07b5aa9dec8436132a524511d5438c510e322070` on final readback.

This run resumed checkpoint `4f7d76c5548977843520fbdacb1b13ff5c1dd7b5` (tree `2bbcb38485bb59278c62127bfe37c1a38a204161`); its nine prior commits are not claimed as new work. Five new commits lead to implementation I=`b2e2399c71b101db1e740db6d43672d84d3cd661`, tree `574fa8a6f2ec766a8fe88046fe90585cab67d555`. The later evidence/capsule and readback commits do not change these implementation bytes. `GITHUB-READBACK.json` identifies the final publication and single #156 handoff.

Historical tested/reported source S=`6c2253f6bb746652704591d47ecf9628d905cff9`, tree `94e7abb1271de65df259c1ef737a22f6124a2084`, and historical readback R=`4fab9db600567a1978893d66ac5c489061c56068` remain distinct. No old result was relabelled as tested against I.

GitHub Contents blob readback matched every one of the 12 locally held candidate files listed in `SOURCE-AND-RESULTS.json`. Local work was a source subset, not a complete repository checkout. SHA256 and Git blob SHA1 are recorded per file. The complete implementation lives on the existing overlay branch, not in a local download.

## Source-to-obligation arguments

All source links below are repository-relative; use implementation I for an immutable source view.

| Obligation | Connected implementation | Decisive checks and limits |
| --- | --- | --- |
| Count only actual combat creation; never redispatch a stale object after reward/safe nodes | `tests/support/dd1_native_driver_main.gd`: `before_combat_start`, `after_combat_start`, `dispatch_once`; `dd1_route_journal.gd`: `ObservedGame.apply`; `dd1_unit_grant.gd`: `consume` | Process-wide grant is consumed before increment/creation. Strong combat reference and run/act/node key survive rewards and safe-screen clearing. Latch is set before the real result callback. Rehashed stale-after-reward/safe-node records reject at the identity guard; a second created combat has a distinct structural positive. Actual GDScript negative/positive is authored in `tests/test_dd1_source_repair.gd` but UNEXECUTED. Old reported debits are not refunded. |
| Preserve actual Pilot inputs/events instead of opaque turn/reward labels | Observer retains original game/run/rules/rewards/quests objects and calls `super.apply(cmd)` exactly once. Nested journal includes actual `playCard`/`endTurn`/kindle/art/potion/start inputs, native events/returns, UID zones, combat identity and queue sizes | Inert mutations repair all hashes before dropping events, changing UID/encounter/source or substituting an opaque command. They reject; tests do not merely detect a stale digest. Source-shape tests establish one native call in the adapter, not GDScript runtime dispatch. No Pilot source, weights, modes or thresholds changed. |
| Ordinary initial bytes, real durable saves, preterminal bytes and exact terminal receipt | `dd1_ordinary_capture.gd`: `drive`; Main overrides `_store_run`, `_store_vigil`, `_clear_run`, `_show_save_error`, `_on_terminal_commit`, `complete_terminal` | Read ordinary initial Vigil before any clear; refuse existing run/journal outputs. Read back saves and sticky-fail on write/capture errors. Preserve preterminal bytes before commit; a win must complete real Dawn advance/finish and actual run clear. Constructed missing-Dawn/receipt/save/initial-state controls reject. A native ENOTDIR save-failure fixture and two-combat terminal fixture are authored, not run. |
| Capture choices without policy refit, replacement routes or outcome injection | Public reward/shop/rest/event/boss choice callbacks are journalled. `_claim_pending_reward` connects the existing Pilot to native singular `relic` and nullable `potion` fields. `tools/dd1_recovery_acquire.gd` writes only a new host-reserved directory and stops on first incomplete route | No fallback node selection, new root order or policy tuning. Correcting reward-field plumbing can change driver-dependent outcomes; old runs cannot qualify the corrected driver. Unsupported scene/pool/hollow/monument/lamplighter/Act-IV choices explicitly fail INCOMPLETE. Full public-route coverage is not claimed. |
| Reject constructed/unrelated witnesses; preserve H's authentication boundary | `tools/dd1_provenance.py`: `inspect_route`, `inspect_sequence`, `evaluate_witness`. Current matrix's constructed-save roundtrip now requires REJECT/BLOCKED, never an earned positive | Structural checks bind blank Vigil, ascending roots, ordinary vow progression, run/UID/RNG/map identities, successful linked saves/terminal receipts and first-profile bytes. Self-hash without H context is BLOCKED. H `verify` runs before inspecting host-bound `preflight_trace` and `development_manifest`; `extractor_source` remains actual producer bytes, linked by digest. The two H adapter tests use explicit mocks; full H integration and genuine captured positive remain UNEXECUTED/ABSENT. Structural consistency is not external provenance or proof of all native laws. |
| Reserve complete costs before spawn and preserve failure debits | `tools/dd1_reservations.py`: exact account/cap/clock/demand checks, exclusive lock, `reserve_and_run`; existing `dd1_recovery_meter.py` connects to `dd1_meter_entry.py` | Actual inert child sees the entire engine-plus-contained-start, CPU and cumulative raw reservation durably present before it runs. Invalid caps/identities/source/argv, exhausted dimensions, duplicate units and aliased outputs reject before runner. Injected interruption/final-write failure retain the full reservation. These prove reservation/account mechanics, NOT aggregate OS containment. |
| Enforce aggregate CPU/process tree, every raw channel and interruption cleanup | `dd1_meter_entry.py::require_native_backend` is deliberately BLOCKED before live reservation/spawn | **B1 remains a source implementation blocker.** No functioning aggregate backend is delivered or claimed. Per-child CPU limits, stdout-only budgets and delayed accounting are not enabled as substitutes. The disabled-entry test verifies no spawn/account mutation even for internally consistent synthetic demands. |

## Actual inert proof

Executed command, exit 0, **23 tests passed**:

```text
PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s tools -p test_dd1_source_repair.py -v
```

`INERT-TESTS.log` is the complete actual output; `SOURCE-AND-RESULTS.json` binds the tested sources and records the environment. `tools/dd1_synthetic_capture.py` contains the complete fabricated fixture generator. Its five constructed wins/P0/P5 are test input only: they are not ordinary game observations, discovery, fresh native spend or a certificate.

`INERT-CONTROLS.json` contains additional actual temporary-account snapshots before/during/after the reservation and exact harmless child stdout `INERT_ONLY\n`. The interruption case injects `KeyboardInterrupt` at the runner seam; it does NOT demonstrate killing an arbitrary process tree. Both controls preserve every legacy account field and retain the full synthetic reservation. Their fake receipt/head, injected clock and permissive test authority are explicitly synthetic and never passed to a native child.

`HOST-CAPABILITY.json` is a limited actual host inspection: cgroup mount read-only, `/dev/fuse` absent, private user/mount namespace probe **succeeded**. These observations are not proof that all alternate backends are impossible and are not macOS qualification. No aggregate backend was implemented or validated from them.

Zero engine/version/import/parse/native/capture/profile launches occurred. All changed GDScript, the current matrix orchestration, a genuine linked native chain, aggregate enforcement and actual H-boundary integration remain unexecuted. No unrelated core gate or old green result stands in for them.

## Preserved evidence and dependency-specific invalidation

Accepted D=`746388323b8e886967e0e13fe109490a70206a66`, C=`cf27285a3103d8867a179f700c5ebf32661453d5`, H=`5b6b3a718b8c6200d12d5c06c85702ea9a0f35c6`, and H ALLOCATION=`824ff18acbca2f776533beed83a43b21d9a50f2c` are unchanged. The three-strategy, Duskblade-first goal and bound #547 acceptance are not redesigned or reopened.

The implementation diff from the resumed checkpoint contains only the driver/capture/meter/verifier/tests, this repair capsule and the exact historical test-source relocation. No production application/domain/content/Pilot file or existing evidence/account file changed. The 707-line old matrix source is retained byte-for-byte at `history/test_dd1_native_matrix_at_4f7.gd`, blob `ca41c39252dbd06340a53fd20a3e6a35e44857d6`. Commit `a2dff9cfffd44f80bc3de59c8809d9e3bf92f0d6` is a GitHub-confirmed rename with zero line changes; a separate commit supplies current orchestration. The whole-range diff is larger, but no one-commit code-file rewrite over 600 lines was used.

Only named unchanged collateral fixture functions are called from that archive; `Archive.run`, the old automatic acquisition and its false 'genuine supplied witness' assertion are not executed by current orchestration. Historical source is not current authority.

Existing M pending-save bytes retain their original source/save-reader compatibility scope. Existing reader, signed control, collateral and visual records retain only their original source, fixture, configuration and capture scope. Their files and historical results are not rewritten, relabelled independently accepted, rerun or promoted to evidence for the new producer/driver/meter. New orchestration and adapter capture require their own future native qualification.

Old recovery route/status/counter observations remain historical records. Missing detailed commands and preterminal bytes are not reconstructed. The stale-combat bug makes old driver-derived progression/reward accounting and ordinary-profile qualification inadmissible as validation of I. It does not establish that a named historical path occurred, nor a universal game-balance failure. The recorded first-root win and later Vow-1 deaths are neither new evidence nor a prediction that corrected replay will reach P5.

Both accounts remain unchanged. Recovery ACCOUNT blob `8b7e4e6367ad4bc366c04b930ef4fc3810e2a900`: reported starts **2040/2048**, CPU **398617197992 ns**, raw **893139 bytes**. Arithmetic remainder 8 is not permission. Historical **1277/8192**, remainder **6915**, remains unspendable with UNKNOWN observations preserved. No account-completeness certification, refund, top-up, second recovery or new clock is asserted. Window remains 2026-09-17T17:54:40Z through 2026-09-24T17:54:40Z.

## Remaining source/authority boundary

B1 is not merely an unavailable native test: the native OS containment implementation is still missing. It must establish aggregate process/thread CPU, bound or deny all descendants, account for every raw write channel including saves/traces/logs and rewrites, and terminate/reap the entire unit on interruption. It must also preserve source/output isolation and bind the executable, command and complete source/content closure to externally authorised demand. A caller-supplied demand file, digest or Unit environment variable is not authority. The disabled backend must not simply be replaced by a generic `subprocess` runner.

The current source does provide the before-start reservation transaction, driver-side contained-start consumption and fail-closed entry for that backend. It does not claim these compose into enforced native limits yet. A future planner decision cannot cure B1 merely by assigning more starts or retrying a 16-root run.

`EXECUTION-DEMAND.md` supplies exact dormant tests/inputs, reservations, falsification targets and the same-law versus changed-policy boundary. No command in that document is an authorised launch. No reviewer, N0 acceptance, N1/N2, alpha, #548 spend, production PR/CI, merge, closure or release is opened. Certificates remain **0/3**. The planner owns the next resource/scope disposition after this handoff.
