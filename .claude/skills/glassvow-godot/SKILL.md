---
name: glassvow-godot
description: Binding contract for working in the glassvow Godot repo — engine minimum, architecture boundaries, editing methods, verification, save compatibility, stop conditions. Load before any implementation work here.
---

# Glassvow Godot 4.7.2+ Binding Contract

## 1. Engine Contract

**Minimum:** Godot 4.7.2 stable. Verify before starting work:
`godot --version` must report 4.7.2 stable or a later stable release. Pre-release
builds are unsupported; an older or pre-release engine can silently change type
checking and produce confusing test failures.

Historical evidence keeps the engine version it actually used. A dated packet
that truthfully records 4.7.1 is not the active minimum and must not be rewritten
as though the run happened on 4.7.2. A release or evidence protocol may still
require one exact supported version; that narrower protocol pin remains binding.

**4.7 Gotchas (trap setters):**
- **Typed-return overrides need an explicit `return`:** since 4.7, overriding a method whose declared return type is non-void without a `return` on every path is an error, not a silent null.
- **`CONFUSABLE_TEMPORARY_MODIFICATION` warning (new in 4.7):** modifying a temporary value (`get_position().x = 1`, `dict_of_vectors["k"].x = 1` on value types) silently discards the write. Assign to a local, modify, write back. RefCounted/Object elements are references and are NOT affected.

## 2. Architecture Boundaries

**Domain purity:** `domain/` holds pure game logic as `RefCounted` classes only — zero Node, SceneTree, FileAccess, DirAccess, Input, DisplayServer, OS, or `get_tree()` references. Tested in `tests/test_arch.gd` (banned-token scan). This boundary allows headless testing and deterministic playback.

**Command → Event seam:** The facade `GlassvowGame.apply(cmd: Dictionary) -> Array[Dictionary]` receives a command dict (e.g. `{"t": "playCard", "uid": 1}` or `{"t": "endTurn"}`) and returns an array of GameEvent dicts (`{"t": StringName, ...}`). Command `t` values live in `domain/game.gd`; event type constants live in `domain/events/event_types.gd`. The presentation layer (`presentation/`) subscribes to these events and never owns game truth.

**Anti-patterns forbidden:**
- **No global EventBus autoload.** Screens and managers signal upward to `application/main.tscn`; main routes and holds the single `GlassvowGame` instance.
- **No manager singletons.** `application/main.tscn` is the only composition root. Dependency injection happens at scene instantiation.

## 3. IDs & Locale

**Internal StringName IDs frozen:** Card, relic, enemy, status, and ability IDs are engine-internal constants (e.g. `poison`, `vulnerable`, `str`, `strike`, `leech`). Once M4 lands, these IDs never change — saves depend on them. Changes to an ID require a migration step or a new save-version envelope.

**Display names are locale data:** Render "Block" instead of "defend"? Change the display string, never the internal key `defend`. This separation protects cross-version save loading. English display names live in the content catalogue (`content/full-content.json`). `Locale.hydrate_content` overlays the active language's `content.*` strings from `locale/<code>.json` onto those rows at boot (`application/locale.gd`); hydrating `en` is a no-op because the bake already is English.

## 4. Editing Methods

**By hand:** Small `.gd` scripts and `project.godot` / `.tres` bus layout. Hand-edit in the editor or IDE.

**Via Godot editor:**
- Medium/large `.tscn` scene tweaks: open in editor, drag/edit, Save.
- New `.tscn` files for significant UI: use the editor, commit the result.

**With MCP (funplay-godot-mcp):**
- Large presentation scene generation or restructuring.
- Screenshot-driven iteration (layout tweaks visible before commit).
- Query scene hierarchy, bounding boxes, anchoring state.

**Never:**
- Edit `.godot/` directly.
- Hand-edit `.import/` sidecars — they regenerate on `godot --headless --import`.
- Commit without including `.import/` and `.uid` sidecars; they are version-specific import metadata.

## 5. Verification Commands

Run these three from the repo root, in order. All must pass before pushing:

```bash
godot --version                          # confirm 4.7.2 stable or later stable
tools/check_imports.sh                   # import; fail on stderr ERRORs or process status
tools/check_scripts.sh                   # per-file parse + warnings-as-errors gate
godot --headless -s res://tests/run_all.gd   # run test suite; must exit 0 with PASS
```

CI runs this same gate on every push to verify nothing is broken — literally the
same script, called from `.github/workflows/ci.yml`, so local and CI cannot
drift.

**Never grade `--check-only` by its exit code.** It writes diagnostics to stderr
and exits 0 whatever it found; measured on 4.7.1, a duplicate `var`, an
unterminated string, a type mismatch and an untyped `var` all exited 0. The
`|| exit 1` loop that stood here until 2026-08-06 therefore never failed once.
`tools/check_scripts.sh` greps stderr for `SCRIPT ERROR` / `Failed to load
script`, while separately failing on a non-zero process status so invocation
failures and crashes cannot pass. Warnings-as-errors is genuinely reaching the
check — `project.godot` sets four warning classes to level 2 and an untyped
`var x = 1` prints `(Warning treated as error.)` — it is enforced by that grep,
not by the exit code.

## 6. Visual Inspection

Any presentation-affecting change (screen layout, tween, VFX, audio routing) requires a screenshot before review. Use the Funplay MCP editor integration:

1. Godot editor open, MCP connected (port 8765).
2. Make the change, Save the scene.
3. Call Funplay `capture_editor_view` (editor 2D/3D viewport) or `capture_runtime_view` (live game viewport via the runtime bridge). Both photograph the view that is showing; they do not take a `res://` scene path.
4. Review the screenshot before committing.

Without the editor, capture through `tools/shot.sh` (one-off) or `tools/live.sh` (iteration) — see `docs/dev-tools.md`.

Changes that don't touch `presentation/` or audio buses (pure domain, architecture, test-only) skip this step.

## 7. Fixtures & Determinism

**Fixtures are port-owned goldens** (amended 2026-08-16 by #317 D5; they were immutable before). The 18 files in `port_fixtures/` were captured once from roguecardv2's `tools/capture-port-fixtures.mjs` and now pin **this port's** behaviour, not the web's. Treat them as goldens: a fixture change is a behaviour change and needs its own commit saying what moved and why — never a silent edit to make a failing test pass. No port-side regeneration tool exists; it gets designed the first time a refactor actually needs one.

**All randomness flows through run Rng:** A run's seed produces one seeded Mulberry32 stream (`run.rngState` int cursor). Every random draw (card pick, enemy AI, damage variance) pulls from this stream. No other randomness sources. This makes runs deterministic and reproducible.

**Dictionary-event + cast-at-boundary pattern:** Events are `{"t": StringName, ...}` dictionaries — there are NO event classes. Presentation handlers cast individual fields at the boundary:
```gdscript
# domain/ returns events
var events: Array[Dictionary] = game.apply(cmd)
# presentation/ casts fields at the boundary
for ev: Dictionary in events:
	match ev["t"]:
		EventTypes.HIT_ENEMY:
			var amount: int = int(ev["amount"])
			var idx: int = int(ev["idx"])
			_play_hit(idx, amount)
```

Dictionaries compare natively against the JSON parity fixtures and survive serialization; typed locals contain the untyped-access surface to one line per field.

## 8. Save Compatibility

**Lineage:** the live envelope is the v2 pair — `user://glassvow_run_v2.json` (run) and `user://glassvow_vigil_v2.json` (meta). The v1 lineage is deliberately not read or migrated (`application/save_service.gd`). The v2 schema is frozen; any breaking change requires a version bump and a migration handler in `SaveService`.

**Web saves never migrate:** Users porting from web restart at the beginning; progress doesn't carry over (the map is redesigned anyway).

**Resume semantics:** If a save has `pending_encounter`, the next session re-enters combat at that step. Mid-combat state is never serialized (recomputed from deck + run state). Kill the app and resume — you're back to the same fight.

**ID validation on load:** `SaveService.load()` validates every card/relic/potion ID in the save against the current content registry. Any unknown ID **rejects the whole save** (load returns null; the player starts fresh) — same stale-content shield as the web engine's `normaliseRunSnapshot`. Never partially heal a save by dropping or substituting items.

## 9. Stop Conditions

**Halt implementation and produce a separate plan if any of these arise:**

1. **Save-schema change** — a breaking change to the save envelope or top-level structure that would require a new version.
2. **Platform plugin work** — native Android/iOS SDK integration (push, analytics, in-app purchase). This is a separate skillset and project.
3. **Per-file code change >600 lines** — in one commit, additions plus deletions
   to any one code file must not exceed 600 lines. Evidence artefacts are
   excluded. Split the commit or present a revised plan before proceeding.

## 10. Governance

**Narrow loop:** One implementer + one reviewer + fast local gate (the three verification commands) + milestone gate (CI + parity fixtures + one human visual decision). No auto-revert machinery for this project — a red CI is a handled event, not an emergency.

**Milestone checkpoints:**
- **M0:** Scaffold (this).
- **M1–M4:** Domain parity (RNG, content, combat, saves).
- **M5–M7:** Presentation slice (combat screen, world map, mobile).
- **M8:** ~~Decision gate (parity suite green; ship the full port, or return to web).~~ **Settled 2026-08-16 (#317): the port ships.** The reference is detached and "return to web" is off the table; what replaces this gate is the commercial rubric (#157) and the RC bar (`docs/rc-bar.md`).

**Authority:** User (fol2) signs off on concept briefs (especially M6 map concept), high-level PRs, and the M8 decision. Otherwise, reviewers drive their lane.
