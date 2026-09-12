---
name: glassvow-godot
description: Use when changing Glassvow Godot code, scenes, resources, imports or build configuration.
---

# Glassvow Godot 4.7.2 Binding Contract

## 1. Engine Contract

**Pin:** Godot 4.7.2 exact. Verify before running Godot in a new or changed environment: `godot --version` must print `4.7.2.stable`. Running any GDScript requires this exact version; mismatches silently break type checking and produce confusing test failures.

Historical evidence keeps the engine version it actually used. A dated packet
that truthfully records 4.7.1 is not an active pin and must not be rewritten as
though the run happened on 4.7.2.

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

Use text edits for scripts, configuration and scenes when the change is clear.
Prefer the Godot editor or an available Funplay MCP integration for complex
scene layout, hierarchy inspection or restructuring. Neither is a prerequisite:
text-edited scenes still need import/parse checks and relevant runtime evidence.
Do not wait for an editor or MCP connection when the existing CLI tools suffice.

**Never:**
- Edit `.godot/` directly.
- Hand-edit `.import/` sidecars — they regenerate on `godot --headless --import`.
- Commit without including `.import/` and `.uid` sidecars; they are version-specific import metadata.

## 5. Verification Commands

Follow **Verification** in `AGENTS.md`, the canonical local checklist and
change-sensitive execution policy. Keep CI's additional checks in
`.github/workflows/ci.yml`; do not duplicate their inventory here.

Use `tools/check_scripts.sh`, not the exit code of bare `--check-only`, to detect
parse failures. Include new `.gd` files in the tracked sweep as described in
`AGENTS.md`. Grade the test suite by its exit status and `PASS` line, not harmless
dummy-renderer warnings.

## 6. Runtime Inspection

Choose evidence by observable effect, not by directory:
- Layout or static visual changes: inspect a runtime screenshot before review.
- Tweens or VFX: inspect the running transition or a temporal capture; a single
  still does not prove motion.
- Audio changes: verify playback and routing; a screenshot alone is insufficient.
- Pure domain, architecture, tests or documentation with no audiovisual effect:
  no capture is required. Content and locale changes may affect the visible UI.

Use `tools/shot.sh` for one-off screenshots or `tools/live.sh` for iteration,
following `docs/session-ownership.md` and `docs/dev-tools.md`. Editor/MCP views
are useful supplementary inspection, not proof that the game renders correctly.
Report missing required runtime evidence rather than claiming completion.

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

Pause the affected implementation and obtain an approved plan for an unexpected
breaking save-schema change or native Android/iOS SDK integration. If the current
approved task already covers that change and its migration or platform plan,
continue within that scope; do not request the same approval again.

More than 400 changed lines is a scope-review signal, not an automatic halt.
Check whether the increase is explained by the approved work, tests or generated
content. Pause only for new unapproved scope, architecture or risk; continue
independent in-scope work. Explicit one-shot, STOP and owner-approval boundaries
in the task remain binding.

## 10. Governance

Continue through implementation, relevant verification and fixes caused by the
requested change until its acceptance criteria are met or a named approval
boundary is reached. Record unrelated improvements as follow-ups rather than
expanding the task. Report pre-existing failures separately; do not conceal them.

For implementation PRs, retain one implementer and one reviewer; review is a
handoff gate, not a pause after every edit. Read-only answers and mechanical
non-semantic documentation corrections do not need a separate reviewer. Human
visual decisions apply to the milestones or briefs that explicitly require them.
No auto-revert machinery: a red CI is a handled event, not an emergency.

**Historical milestones:** M0 scaffold, M1–M4 domain port, M5–M7 presentation.
M8 was settled on 2026-08-16 (#317): this port ships independently. Current
quality criteria are the commercial rubric (#157) and `docs/rc-bar.md`, not a
new web-parity or M8 approval exercise.

**Authority:** James signs off on concept briefs and high-level PRs. Preserve
explicit merge, release, provider-spend and production-activation boundaries;
local implementation permission does not grant those actions.
