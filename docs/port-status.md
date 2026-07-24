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

## Next: M3 — combat core

Reimplement combat in `domain/` to match the web engine. Rough shape (split
however lands cleanly, small PRs, each green before the next): states +
`start_combat` + piles/draw/reshuffle → `play_card` + damage/block + effects →
statuses + shatter/chips → kindle/embers/Lantern-Art + the slice specials
(execute/momentum/doubleBlock) → enemy turn + `end_turn`.

**Verify against fixtures, in order:**
1. `tests/test_combat_probes.gd` — the 136 rows are rng-free; each carries
   `pre`/`op`/`args`/`events`/`post` (+ `preview`). Reconstruct `pre`, run the
   op, assert events + post + preview mirror.
2. `tests/test_combat_traces.gd` — replay each trace's command stream; assert
   the events-delta + `rngState` per step. Use `tests/support/diff.gd` `deep_eq`
   for first-divergence (step, op, field path, expected/actual, last-good state).

Damage law is **sequential floors**: `base+str → weak ⌊×0.75⌋ → vulnerable
⌊×1.5⌋ → max(0,·)`; block = round. Every calc needs its pure preview mirror.

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
