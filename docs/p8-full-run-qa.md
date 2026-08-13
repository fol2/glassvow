# #107 closure — full-run gameplay QA and defect sweep

## Accepted stage boundary

This record applies to exact gameplay candidate
[`f7d3ea257ff7465cad06e3be299cb5495886b45d`](https://github.com/fol2/glassvow/commit/f7d3ea257ff7465cad06e3be299cb5495886b45d).

It covers gameplay journeys, durable save/resume behaviour in the current Godot
4.7.1 development runtime, and UI/UX composition and reachability at the
project's authored viewport references. Mouse evidence is labelled as mouse; it
is not native-touch evidence.

It does not claim Web/browser behaviour, platform compatibility, export or
packaging, physical-device behaviour, native touch, performance, release
readiness, or human sign-off. Those later-stage claims remain outside #107;
[#108](https://github.com/fol2/glassvow/issues/108#issuecomment-5273355875)
remains explicitly deferred.

## Full-journey matrix

| Run | Aspect | Authored viewport | Locale | Input | Result |
|---|---|---:|---|---|---|
| R1 | Duskblade | 1180×820 pad-landscape | en | keyboard | Full headed journey to Dawn |
| R2 | Duskblade | 390×844 phone-portrait | zh-Hant | Godot mouse pointer/drag | Full headed journey to Dawn |
| R3 | Ashwarden | 1180×820 pad-landscape | zh-Hant | Godot mouse pointer/drag | Full headed journey to Dawn |
| R4 | Ashwarden | 390×844 phone-portrait | en | keyboard | Full headed journey to Dawn |

The immutable discovery packet records 48 raw PNGs, 244 headed route boundaries
and 122 headless route boundaries:

- current tip: [`fbb27b641081606ff121c478f6c2708c69ea6557`](https://github.com/fol2/glassvow/tree/fbb27b641081606ff121c478f6c2708c69ea6557);
- [proof boundary](https://github.com/fol2/glassvow/blob/fbb27b641081606ff121c478f6c2708c69ea6557/proof.md);
- [manifest](https://github.com/fol2/glassvow/blob/fbb27b641081606ff121c478f6c2708c69ea6557/manifest.json);
- [offline verifier](https://github.com/fol2/glassvow/blob/fbb27b641081606ff121c478f6c2708c69ea6557/verify.py).

This packet remains labelled **pre-fix** because it discovered #167 and #168.
It proves the recorded journey breadth, route projections, representative
keyboard/mouse paths and pre-fix pixels; it is not relabelled as final visual
acceptance.

## Final-candidate viewport bridge

The final applicability packet is immutable evidence commit
[`4752e87e62086e91a749791df13f08a88aab4a07`](https://github.com/fol2/glassvow/tree/4752e87e62086e91a749791df13f08a88aab4a07):

- [proof boundary](https://github.com/fol2/glassvow/blob/4752e87e62086e91a749791df13f08a88aab4a07/proof.md);
- [manifest](https://github.com/fol2/glassvow/blob/4752e87e62086e91a749791df13f08a88aab4a07/manifest.json);
- [offline verifier](https://github.com/fol2/glassvow/blob/4752e87e62086e91a749791df13f08a88aab4a07/verify.py);
- [issue receipt](https://github.com/fol2/glassvow/issues/107#issuecomment-5274250703).

Fresh independent archive verification passed. The packet binds the final
source tree, #167/#168 merge lineage, the complete local gate set, and eight
non-uniform headed images: boss-relic and Dawn, both locales, exact 390×844 and
1180×820. It is an applicability bridge, not a second four-run matrix.

[#167](https://github.com/fol2/glassvow/issues/167) was fixed by
[PR #169](https://github.com/fol2/glassvow/pull/169), merged as
[`bd0dba2b5ca61075caaebf75539cd96c98b8045c`](https://github.com/fol2/glassvow/commit/bd0dba2b5ca61075caaebf75539cd96c98b8045c).

[#168](https://github.com/fol2/glassvow/issues/168) was fixed by
[PR #170](https://github.com/fol2/glassvow/pull/170), merged as the final
candidate `f7d3ea257ff7465cad06e3be299cb5495886b45d`.

## True process-kill resume matrix

The first immutable fresh-PID packet is
[`90457cf7662b966531285768fe72a702cce674a1`](https://github.com/fol2/glassvow/tree/90457cf7662b966531285768fe72a702cce674a1).
Its offline verifier passes five true `SIGKILL` process-A → fresh-process-B rows,
ten screenshots and an unchanged normal save:

| Checkpoint | Restored state |
|---|---|
| rest | Rest screen, exact save/RNG/map/scratch fingerprint |
| event | Event screen, exact fingerprint |
| shop | Post-purchase shop state, exact fingerprint |
| treasure | Treasure screen, exact fingerprint |
| eventPending | Event choice overlay, exact fingerprint |

The final completion packet at
[`2e09ea610f46d31a4eb58008497c06f11113dc6c`](https://github.com/fol2/glassvow/tree/2e09ea610f46d31a4eb58008497c06f11113dc6c)
adds the five binding rows not supplied by that first packet. Its
[proof](https://github.com/fol2/glassvow/blob/2e09ea610f46d31a4eb58008497c06f11113dc6c/proof.md),
[manifest](https://github.com/fol2/glassvow/blob/2e09ea610f46d31a4eb58008497c06f11113dc6c/manifest.json),
[verifier](https://github.com/fol2/glassvow/blob/2e09ea610f46d31a4eb58008497c06f11113dc6c/verify.py)
and [issue receipt](https://github.com/fol2/glassvow/issues/107#issuecomment-5274538346)
are immutable:

| Checkpoint | Process A → B | Restored route | Real continuation |
|---|---:|---|---|
| map | 95140 → 95767 | map | mouse reachable-node selection → combat |
| combat | 96575 → 97861 | combat | `E` advances the live turn |
| partial reward | 97970 → 99431 | reward | mouse confirmation → map |
| boss-relic | 99688 → 863 | boss-relic choice | Enter → next map |
| progressed Dawn | 99490 → 247 | Dawn cursor 1 | Space → cursor 2 |

Each binding row records a production checkpoint, true process termination,
absent process tree, a distinct fresh PID, equality across eight durable
fingerprints and a real-input continuation. The Dawn row starts from the
retained cursor-zero save created by the authentic three-act Ashwarden journey;
current `RunState`, `SaveService` and `Main` validate, store and route it before
the production Dawn handler progresses the cursor. A save/load comparison
inside one process is not substituted for process-kill evidence.

## Desktop-landscape spot checks

Both locales receive exact 1458×820 desktop-landscape headed combat spot checks
at the final gameplay candidate, retained in `2e09ea6`:

- [en capture](https://raw.githubusercontent.com/fol2/glassvow/2e09ea610f46d31a4eb58008497c06f11113dc6c/desktop/captures/combat-en-desktop-landscape.png);
- [zh-Hant capture](https://raw.githubusercontent.com/fol2/glassvow/2e09ea610f46d31a4eb58008497c06f11113dc6c/desktop/captures/combat-zh-Hant-desktop-landscape.png).

Both are non-uniform and have process exit 0. These are viewport UI/UX checks
only; they are not desktop-platform or export compatibility evidence.

## Gate and isolation record

At the final gameplay candidate, serial checks passed under disposable
HOME/XDG roots:

- Godot `4.7.1.stable.official.a13da4feb`;
- clean import;
- strict parse/warnings gate: 146 tracked scripts;
- complete suite: `PASS (26 tests)`, process exit 0;
- focused boss-relic and Dawn containment tests;
- documentation and web-reference anchor checkers;
- `git diff --check`.

The suite log retains its intentional negative-test diagnostics and known dummy
renderer/resource diagnostics; this record claims the explicit PASS/result and
process status, not empty stderr.

The normal user run save remained 9,039 bytes with exact SHA-256
`e49a710d82f9dc4b63b7f85db97b42e2452aa35f0da88b0fee1fcf16cf08ab2b`.
All QA profiles were disposable and are absent from the evidence archives.

## Fail-closed defect ledger

The ledger is refreshed against the closure candidate immediately before merge.
Its required query set is all open `bug` issues, all open phase tasks, and every
held/waived item referenced by #7/#8. Missing, duplicate or unknown rows fail
the ledger.

| Row | Disposition |
|---|---|
| Open `bug` issues | 0 at the closure snapshot (`2026-08-13T00:45:08Z`); refresh immediately before merge |
| #107 | Resolved by this closure PR on merge |
| #108 | Downstream and [explicitly deferred](https://github.com/fol2/glassvow/issues/108#issuecomment-5273355875) to the later compatibility/release stage |
| #85 | Explicit post-1.0 hold: [decision](https://github.com/fol2/glassvow/issues/85#issuecomment-5231805781) |
| #86 | Explicit hold with retired PR #126: [decision](https://github.com/fol2/glassvow/issues/86#issuecomment-5231806232) |
| #87 | Existing procedural sky retained: [decision](https://github.com/fol2/glassvow/issues/87#issuecomment-5231806763) |
| #7 exception | Historical process exception only: [decision](https://github.com/fol2/glassvow/issues/7#issuecomment-5264971463); no functional or future-gate waiver |
| #7 | Closed with [final P7 receipt](https://github.com/fol2/glassvow/issues/7#issuecomment-5265084026) |
| #8 | Closed/superseded by #156: [decision](https://github.com/fol2/glassvow/issues/8#issuecomment-5273846456) |
| #156, #159, #160, #163–#166 | Open parallel/downstream commercial-roadmap work; not silently absorbed into #107 |
| #171, #172 | Open later platform-performance device/profiling work; excluded from the present stage |
| #175–#177 | Open story/onboarding/copy design work under #156; excluded from this gameplay QA closure |

The zero-open-bug count is an exact-snapshot statement. At merge time, the sole
open PR is this closure PR; neither fact is a general product or
release-readiness claim.

## Completion boundary

The evidence above completes the required current-development-runtime gameplay,
save/resume and authored-viewport matrix for exact candidate `f7d3ea2…`. This
document becomes the decision of record only when its docs-only closure PR has
exact-head CI, independent direction/engineering/simplicity approvals and merges.
It does not advance #108 or any platform/export/release stage.
