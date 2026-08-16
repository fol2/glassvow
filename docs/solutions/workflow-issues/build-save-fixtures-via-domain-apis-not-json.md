---
title: "Plant save fixtures through the domain API and roundtrip-verify — hand-written JSON is silently swallowed"
date: 2026-08-01
category: workflow-issues
module: application
problem_type: workflow_issue
component: development_workflow
severity: high
applies_when:
  - "A test, screenshot drive, or QA session needs pre-seeded user:// save state (vigil or run)"
  - "About to hand-write save JSON to set up test state"
  - "A drive built on planted state misbehaves in a way that looks like logic or routing"
  - "A load path validates strictly and falls back silently to default state"
resolution_type: workflow_improvement
tags: [godot, save-validation, fixtures, headless-testing, domain-api, silent-failure, roundtrip-verification]
---

# Plant save fixtures through the domain API and roundtrip-verify — hand-written JSON is silently swallowed

## Context

Driving the Act IV threshold screen (P4.16, PR #55) requires a vigil save with
all six emberglass shards. The obvious shortcut — hand-writing a minimal
`glassvow_vigil_v2.json` containing just the shards — fails, and fails
invisibly.

The v2 vigil validator is strict and total. `VigilState.from_dict()`
(`domain/state/vigil_state.gd:58`) returns `null` — with no log, push_error, or
assert — whenever:

- the version tag is not exactly `VERSION` (2): `vigil_state.gd:59-60`;
- `deeds`, `quests`, or `receipts` is missing or not a Dictionary:
  `vigil_state.gd:61-64`;
- any of the eleven `DEFAULT_DEEDS` counters is negative: `vigil_state.gd:69-70`;
- **any** of the six `QUEST_IDS` is absent from `quests`, or its entry lacks a
  valid `state`/`progress`/`memory`: `vigil_state.gd:78-86` — this is the clause
  a "just the shards" fixture trips, because every quest must be present;
- a shard is not a known quest id, or is duplicated: `vigil_state.gd:91-92`;
- a receipt is non-null but malformed: `vigil_state.gd:100-101`.

The silence lives one layer up. `SaveService.load_vigil()`
(`application/save_service.gd:50-58`) substitutes a blank ledger on every
failure path — file missing, JSON unparsable, or `from_dict()` returning
`null`:

```gdscript
var loaded: VigilState = VigilState.from_dict(raw)
return loaded if loaded != null else VigilState.blank()   # save_service.gd:58
```

So a malformed fixture does not error; it loads as `VigilState.blank()`
(`vigil_state.gd:35-39` — zero deeds, all six quests dormant, **empty
shards**). Downstream — as re-anchored after the #217 redesign — the vigil's
shards are copied into the run profile by `_new_run`
(`application/main.gd:1088` (in `_new_run`)), `RunState.final_act()`
(`domain/state/run_state.gd` (`final_act`)) extends the journey to a third act
only with six shards, and the Act IV threshold is a sealed-door overlay on the
ordinary final-act map (`presentation/map/world_map_screen.gd:377` (in
`_sync_sealed_door`)). Empty shards means the drive silently shortens the run
to two acts and never shows the sealed door — the failure presents as a
routing bug in the map code, three layers away
from the actual cause, a rejected fixture.

## Guidance

Never hand-write vigil (or run) JSON. Build the state headlessly through the
domain's own API, persist through `SaveService`, and roundtrip-verify before
driving any UI on top of it.

```gdscript
# Throwaway plant-and-verify script — the pattern, not a committed tool.
# (A committed tool now embodies the same principle for dev scenarios:
# application/scenario_kernel.gd builds checkpoints from clean domain state
# and validates them on the real save encode/decode path. The throwaway
# script remains the pattern for ad-hoc vigil fixtures the kernel does not
# cover.)
# Save as e.g. tools/plant_act4_vigil.gd and run headless; delete after use.
extends SceneTree

func _init() -> void:
	# 1. Build through the domain: blank() emits the full valid envelope.
	var vigil: VigilState = VigilState.blank()
	for id: String in VigilState.QUEST_IDS:
		vigil.quests[id]["state"] = "complete"
		vigil.shards.append(id)

	# 2. Persist through the real save layer (atomic write, real path).
	assert(SaveService.store_vigil(vigil), "store_vigil failed")

	# 3. Roundtrip-verify: load back through the same validator the game uses.
	var loaded: VigilState = SaveService.load_vigil()
	assert(loaded.shards.size() == 6,
		"planted vigil did not survive load — validator rejected it")

	print("vigil planted and verified: %d shards" % loaded.shards.size())
	quit(0)
```

Step 3 is the one that matters. `load_vigil()` cannot fail loudly, so the only
way to know the fixture is real is to pull it back through the exact code path
the game will use and assert on the property the drive depends on. If the
assert fires, the fixture is wrong — not the routing.

`to_dict()` (`vigil_state.gd:42-55`) always serialises the complete envelope,
so state built from `blank()` and mutated on the object can never be missing a
required key. For states that a normal game reaches (deed counts, receipts,
quest memory), prefer the real mutation method `commit_run()`
(`vigil_state.gd:115`) over poking fields, so invariants like the runId
receipts stay coherent.

## Why This Matters

- **Frozen schema, strict validator, silent fallback** is a trap triad. Any one
  alone is survivable; together they convert "my fixture has a typo" into "the
  app has a routing bug", and the debugging starts in the wrong file.
- Hand-fabricated fixtures rot instantly under a strict validator: every new
  required key or invariant (a seventh quest id, a new deed counter)
  invalidates them, and the invalidation is invisible. State built via
  `blank()` + domain mutations + `to_dict()` tracks the schema by construction.
- The fallback-to-blank behaviour is *correct* for players (a corrupt vigil
  should not brick the game). Note the design is asymmetric: `load_run()`
  (`application/save_service.gd:35-43`) returns `null` on a corrupt run save —
  the title simply offers no Continue — while only the vigil substitutes a
  blank ledger. The lesson is not to remove the fallback, but to never trust a
  planted save that has not been read back through it.

## When to Apply

- Any time a test, screenshot drive, or manual QA session needs pre-seeded
  `user://` save state (vigil or run) in glassvow.
- Any codebase where a load path validates strictly and falls back silently
  (default state, empty state, `null`-means-fresh): plant via the domain API,
  then roundtrip through the production load function and assert the property
  the downstream behaviour keys on.
- When a drive built on planted state misbehaves in a way that looks like logic
  or routing: verify the plant survived loading **before** debugging
  downstream.

## Examples

**Before (P4.16, first attempt).** A hand-written
`glassvow_vigil_v2.json` containing `{"v": 2, "shards": [ ...six ids... ]}` and
little else. `from_dict()` returned `null` at `vigil_state.gd:61-64` (missing
`deeds`/`quests`/`receipts`), `load_vigil()` swapped in `blank()` with zero
shards, `main.gd:760` took the `else` branch, and the drive landed on a normal
act map. Time was spent reading `WorldMap.act4_entrance()` and the routing in
`_show_act4_entrance()` for a bug that was never there.

**After.** The plant-and-verify script above: `VigilState.blank()`, mark the
six quests complete and append their shards, `SaveService.store_vigil()`, then
`SaveService.load_vigil()` and assert `shards.size() == 6` before launching the
UI. The then-current gate (as of PR #55, pre-#217) selected
`WorldMap.act4_entrance()` on the first drive, and the threshold screen
rendered as intended. (Today the equivalent proof is the sealed door
appearing on the final-act map; `act4_entrance` survives only as the legacy
route for old saves.)

## Related

- `docs/solutions/workflow-issues/verify-whole-run-routes-with-headed-input-and-throwaway-drivers.md`
  — the companion verification practice: this doc covers how planted state gets
  *made and trusted*; that one covers how routes built on it get *driven and
  proven*. Its throwaway drivers build state the same way — through `_new_run()`
  and `game.apply()`, never JSON.
- `tests/test_save.gd` — the in-suite precedent for the full roundtrip:
  `blank()` → `commit_run` → `store_vigil` → `load_vigil`.
- `tests/test_quests.gd` — the in-suite precedent for domain-API planting
  (`blank()` + mutations to light six shards); it stays in memory and does
  not exercise the serialisers.
- Issue #36 (P4.16), PR #55 — the drive this lesson was learnt on.
