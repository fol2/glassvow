# Port status & handoff

Living status for the Glassvow Godot port. Spec = the frozen web engine
(`roguecardv2` @ tag `web-reference-v1`, HEAD `2068b76c`) — mirror `engine.js`.

## Done (all green, pushed)

- **A0/M0** freeze + scaffold · **M1** Rng byte-exact (`domain/rng/rng.gd`).
- **A1a–A1e** fixture exporter (`roguecardv2/tools/capture-port-fixtures.mjs`,
  `2068b76c`). Fixtures committed in `port_fixtures/` (manifest pins that SHA):
  rng, content, `ai/enemy-ai.json`, `combat-probes/probes.jsonl` (136 rows),
  `traces/slice-combat/seed-{101,202,303,404}.jsonl`, `saves/`.
- **M2** `content/content_db.gd` + `domain/rules/enemy_ai.gd` + `test_content` /
  `test_enemy_ai` (1710 AI cases, 672 rng-consuming — all parity-clean).

## M3 — combat core: DONE (green)

Landed as 4 commits (M3a state layer + start_combat · M3b play_card/damage/
chips/shatter + previews + potions · M3c kindle + Lantern Art · M3d end_turn +
enemy phase). Layout: `domain/state/{run_state,combat_state,player_combatant,
enemy_combatant,card_inst}.gd`, `domain/rules/combat.gd` (the whole combat
law; slice-inert systems documented in its docblock), `domain/events/
event_types.gd`, `domain/game.gd` (`apply(cmd)` facade — cmd `t` values are
the web trace op names verbatim). Proof: `test_combat_probes.gd` (136/136
rows: events + post + ret + preview) and `test_combat_traces.gd` (all 4 slice
traces replay to the end: events delta + rngState + combat/run snapshots per
row; reward rows resync rng + gold pending M4).

Parity notes for future waves: fixture card projections carry `up`/`bonus`
only when set; kindle/useArt/endTurn trace steps record `ret:null` (only
playCard's return is captured); the elite trace passes its affix explicitly so
no affix-pick rng draw fires. Damage law is **sequential floors**: `base+str →
weak ⌊×0.75⌋ → vulnerable ⌊×1.5⌋ → max(0,·)`; every calc keeps its pure
preview mirror in lockstep.

## Next: M4 — run loop minus map-gen

Rewards (`genCombatRewards` parity — the traces' reward rows carry expected
output), `GameState.to/from_dict` + `SaveService` (`user://`),
resume-via-pending-encounter, hand-authored horizontal slice map data.
Verify: `test_save.gd` vs `saves/invalid-cases.json` (reject-vs-heal loader
semantics) + reward rows in the slice traces (stop resyncing rng there).

## Contracts & gotchas

- Architecture: SKILL.md is binding. Pure `RefCounted` domain (no Node/FileAccess
  in `domain/`); state via `GlassvowGame.apply(cmd) -> Array[Dictionary]` events;
  no EventBus / manager autoloads.
- Typed GDScript is **warnings-as-errors**: `str(v)` not `String(v)` for JSON
  Variants, `float(str(v))` for JSON floats, pull JSON arrays/dicts into typed
  locals before `append_array`; `floorf` not `floor`; explicit `return` per path.
- Gate: `godot --headless --import` then `godot --headless -s res://tests/run_all.gd`.
  godot 4.7.1 is on PATH — the local `run_all` loop makes inline work fast for
  this parity-critical layer. Trunk flow: commit + push `main`; commit `.uid`,
  never touch `.godot/`.
