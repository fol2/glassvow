# #356 story-complete acceptance

Base: `origin/main` at `ea8ff74` (PRs #393 / #394 already on main). Branch: `work/356-story-acceptance`. This is verification — no copy or production-code changes.

## Verdict

| Bar | Status |
|---|---|
| **Narrative complete** | **PASS** — every approved Phase 1 leaf has one authority, one real runtime host, and a reachable fresh / returning / loss / repeat path in both `zh-Hant` and `en`. Active beats survive interruption without changing or duplicating. Production saves stay byte-identical around the suite. |
| **Story-surface complete** | **PASS, with one named asset-only gap** — bespoke staging (#334) and the Act IV visual/audio package (#221) are on `main`. Remaining: Route A's ghost still paints over the rose tracery (map #156; optional polish, not a story-complete blocker). |

Issue comments on #356 were empty. Where the ticket is silent, the map's story-finished definition (#156) governs.

## Matrix

Every cell is bilingual. Stateful proof is `tests/test_story_acceptance.gd` (discovered by `tests/run_all.gd`). Shots are 1280×720 captures via `tools/shot.sh` — never a bare `godot` launch.

| Cell | Locale | Result | Drive recipe | Evidence |
|---|---|---|---|---|
| Inventory | both | **PASS** | Flatten `story.*` from both locale catalogues; map keys through `content/scenes.json`; census `content/line-table.json` and `content.whispers.*` | [inventory.md](inventory.md). 122 / 122 `story.*`, 79 scene + 25 dawn + 18 event. 178 line-table (hearth 60 / waystone 60 / loss 50 + 8 residue). 24 whispers. 0 unhosted, 0 duplicate-authority, 0 fallback-only. Companion: 57 `content.quests.*` leaves hosted on Vigil / Dawn / quest HUD. |
| A fresh-run | en | **PASS** | `_journey_a`: `Main` 續火 → opening → map; hearth via `DepartureStaging`; first waystone pick with `WorldMapScreen.instant` | `a-opening-dest-en.png` (`story.opening.b2.l2`: sealed door + emberglass; skip caption `ui.dawn.inputHint`). `a-departure-en.png` (L0 linger host). Test: destination names the door before combat; skip grammar; hearth/waystone draw locale pool rows. |
| A fresh-run | zh-Hant | **PASS** | same | `a-opening-dest-zh-Hant.png` (封門、燼璃、守離人; `點擊或按空白鍵繼續，長按跳過`). `a-departure-zh-Hant.png`. |
| B returning-run | en | **PASS** | `_journey_b`: returning 續火 must be `EmbarkScreen`, not opening; `lamplighter-m2-pre` cursor 1; hearth save/resume | `b-lamplighter-m2-en.png` (`story.lamplighter-m2.pre.l2`: "LAST TIME — THAT WAS YOU"). Test: opening is not replayed; hearth id and locale line survive resume. |
| B returning-run | zh-Hant | **PASS** | same | `b-lamplighter-m2-zh-Hant.png` (「上次是你。三點餘燼…」). |
| C loss | en | **PASS** | `_journey_c`: `VigilState.commit_run(..., "death")` twice; `VigilScreen._show_epitaphs`; v2 fold | No dedicated epitaph-tab shot — the catalogue `vigil` fixture lights the rose and does not seed `defeat_epitaphs`. Test: exactly one loss-slot epitaph, readable later in the locale, no double-write, ledger survives `from_dict`. |
| C loss | zh-Hant | **PASS** | same | same test path under `zh-Hant`. |
| D Act IV win (first + repeat short) | en | **PASS** | `_journey_d`: Scenario `act-4-map-start` r1 constructs the authored road; first crossing `act4-entry`; repeat crossing `unsealing-short`; nodes `act4-node1`…`node5` in order with authored enemies; Keeper win → `finale` → `finale-win` → `DawnScreen`; already-seen finale → short close | Recorded checkpoints: `d-unsealing-panes-en.png`, `d-unsealing-mirror-en.png`, `d-unsealing-short-en.png`, `d-act4-entry-en.png`, `d-act4-map-start-en.png` (Scenario `act-4-map-start`, `revision: 1`), `d-act4-node1-en.png` … `d-act4-node5-en.png`, `d-act4-map-terminus-en.png` (Scenario `act-4-map-terminus` — Eternal Keeper combat), `d-finale-en.png`, `d-finale-walk-en.png`, `d-finale-win-en.png`, `d-vigil-en.png` (six panes, English quest names + whisper). |
| D Act IV win (first + repeat short) | zh-Hant | **PASS** | same | Matching `*-zh-Hant.png` set. Finale: 「六片重歸一圈，時辰已到。」 Vigil: 守夜 / 碎片已尋回 / 「有一種顏色，長路拒絕為它命名。」 |
| E Act IV loss + repeat | en | **PASS** | `_journey_e`: Keeper `lose` → `finale-loss` → `RunEndScreen` death; repeat with first-time scenes marked → `finale-win` still finishable, `MIRRORED_ROAD` kept | `e-finale-loss-en.png` ("THIS ONE DID NOT COME BACK EITHER"). |
| E Act IV loss + repeat | zh-Hant | **PASS** | same | `e-finale-loss-zh-Hant.png`. |
| F interruption | en | **PASS** | `_journey_f`: waystone save/resume; opening `pending_scene` cursor 1; library rest once then coda; finale cursor 1 | Test: pool draw count and locale line unchanged; opening resumes `story.opening.b1.l2`; HP not re-applied; event result stays `story.event-library.c1`; finale resumes `story.finale.b1.l2`. |
| F interruption | zh-Hant | **PASS** | same | same invariants under `zh-Hant`. |
| F isolation (#329) | n/a | **PASS** | ScenarioKernel on `user://test_story_acceptance_dev_*`; construct `act-4-map-terminus` | Production `SaveService.RUN_PATH` / `VIGIL_PATH` snapshotted around the whole suite and restored byte-for-byte. Construct does not touch the production pair. |

## Recorded Journey D recipes

`--scene=` is the bespoke-beat capture hook. Locale for those shots is the player `settings.cfg` language (swap, capture, restore). `--scenario=` **must** include `"revision": 1` — omitted revision loads as `-1` and the capture host still writes a blank frame.

```bash
# Opening destination (Journey A, also the Act IV promise)
tools/shot.sh --scene=opening --cursor=3 --vp=1280x720 --settle=0.4 \
  --shot=docs/reviews/356/a-opening-dest-en.png

# Full unsealing (flat cursor 6 = pane-lighting beat)
tools/shot.sh --scene=unsealing --cursor=6 --vp=1280x720 --settle=0.4 \
  --shot=docs/reviews/356/d-unsealing-panes-en.png

# Act IV map / Keeper / Vigil (catalogue)
tools/shot.sh --scenario='{"id":"act-4-map-start","revision":1,"locale":"en"}' \
  --vp=1280x720 --settle=0.6 --shot=docs/reviews/356/d-act4-map-start-en.png
tools/shot.sh --scenario='{"id":"act-4-map-terminus","revision":1,"locale":"en"}' \
  --vp=1280x720 --settle=0.6 --shot=docs/reviews/356/d-act4-map-terminus-en.png
tools/shot.sh --scenario='{"id":"vigil","revision":1,"locale":"en"}' \
  --vp=1280x720 --settle=0.6 --shot=docs/reviews/356/d-vigil-en.png
```

`--scene=` writes `user://glassvow_run_v2.json`. Production pair was snapshotted to `/tmp/356-save-snap` and restored after the capture pass.

## Story-surface vs narrative

Narrative complete is the matrix above. Story-surface complete adds:

- Bespoke opening / unsealing / curator / finale staging (#334 / PR #346) — on `main`; visible in the unsealing pane and finale shots.
- Act IV plates, eight selves, `act4-combat` / `act4-boss` (#221 / PR #367) — on `main`; visible in `d-act4-map-terminus-*.png`.
- Unsealing sting (#377 / PR #378) — on `main` (audio; not in stills).

Named remaining asset-only gap: Route A's ghost paints over the rose tracery. A luminance-derived lobe mask would put it behind the mullions. Map #156 already calls this optional polish, not a story-complete blocker.

## #225 overlap (not resolved)

#225 is the RC-bar reachability ticket (P3 full journeys on the **twin**, no `dev_tools`). This gate used Development-profile Scenarios and `--scene=` on a Dev build. Findings that overlap:

- Catalogue recipes `act-4-map-start` and `act-4-map-terminus` construct the authored Act IV road in both locales.
- That is **not** a twin / RC-bar proof. P3 still owes four full journeys without the Scenario kernel.

No child issue filed.

## Tooling notes (not matrix defects)

1. `ScenarioReference.load_from` defaults `revision` to `-1`. A `--scenario='{"id":"vigil","locale":"en"}'` blob is rejected as unsupported revision; `main.gd` still claims the shot and writes a blank grey frame. Always pass `"revision": 1`.
2. `--scene=` is a known production-save footgun (`docs/design/2026-08-16-bespoke-beats/README.md`). Isolate or restore the pair.
3. Scenario `locale` swaps `Locale.active` and sets `_content_hydration_pending`, but `apply_dev_scenario` can `_show_vigil` before that flush. If Preferences language ≠ Scenario locale, Vigil chrome follows the Scenario while `content.quests.*.name` stays on the boot overlay. Match `settings.cfg` language to the Scenario locale for honest Vigil shots. Production boot hydrates once from Preferences and is fine.

## Defects

None. Every matrix cell passed. No child issues to file.

## Gates

All green on this branch:

| Gate | Result |
|---|---|
| `godot --version` | `4.7.1.stable` |
| `tools/check_imports.sh` | asset import OK |
| `tools/check_scripts.sh` | scripts OK (211 checked), including staged `tests/test_story_acceptance.gd` |
| `godot --headless -s res://tests/run_all.gd` | `PASS (56 tests)` |
| `python3 tools/check_anchors.py` | anchors OK |
| `python3 tools/check_benchmark_freeze.py` | frozen (602 in 55 files) |
