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

## M4 — rewards + saves: DONE (green)

- **M4a rewards**: `domain/rules/rewards.gd` ports genCombatRewards /
  rollCardReward / randomRelic incl. the web **stale-cursor quirk** (the outer
  closure's potion-roll write clobbers rollCardReward's cursor — card rolls
  run on a detached chain whose cursor is discarded; net cursor = gold + potion
  roll + elite relic tier draw) and the poolGate reveal filter (exporter stage
  4 added `poolGate` to slice-content; executioner/momentum are poolWave2-
  gated). The trace replayer computes all 16 reward rows live (gold, cards,
  potion, relic, rngState). Law was pinned first with a Node scratch harness
  against the frozen engine — do that for any future rng-order question.
- **M4b saves**: `user://glassvow_save_v1.json` lineage; validation is pure
  domain (`RunState.from_save_dict`): envelope v==1 → id shield (unknown
  card/relic/potion/art/omen/reveal rejects the whole save) → additive heals
  (art/unlocks/omens/boon/bossRelicAct/shards) → reveals check → per-act omen
  top-up (null; rollOmen path unported). `application/save_service.gd` = file
  IO only. `test_save.gd`: 9/9 fixture verdicts + 2 snapshot anchors through
  a real file round-trip. Reveal registry ids load from core-mechanics.json
  (`mechanics.REVEALS`).

Deferred out of M4: resume-*flow* (pending fields persist; wiring needs the
screen/map layer) and the hand-authored slice map data (no consumer until
M5/M6 — author it with the map concept brief).

## M5 — combat screen: functional slice DONE, craft pass in flight

- **M5a skeleton**: `presentation/combat/` — `EventSequencer` (await-pump,
  one event at a time, input locked while busy; `instant` mode drains
  synchronously for headless tests), `CombatScreen` (event playback from
  event-carried fields + drain-idle truth re-sync `_sync_all`), EnemyView /
  CardView / HandView. `RunState.new_run` builds a fresh core-only profile
  (reveals=[] — keeps omens off, combat parity holds from any cursor).
  `application/main.gd` drives the trace encounter ladder (sporeling pair →
  duskfang → waylayer → gravewarden elite); reward *display* on victory,
  claiming deferred to the M6 RewardScreen. The startCombat batch is
  hard-synced, not replayed (views don't exist until apply returns) —
  opening-draw choreography is a craft-pass item.
- **M5b input**: HandView owns the arc + gesture machine — fan layout, 14px
  slop (below = tap-to-inspect, above = drag), hover raise mouse-only,
  mouse + touch via gui_input (no emulate_touch_from_mouse; ScreenTouch/Drag
  carry only control-local positions — lift to global via the control
  transform). Targeted cards drop on an enemy pane's rect; kindle/untargeted
  release above the hand line; failed drops snap back. Rules-gated
  `request_play`/`request_kindle` on the screen.
- **M5c font**: NotoSansTC (variable, OFL bundled) as `gui/theme/custom_font`;
  琉璃誓言 in the combat top bar; test asserts the four title glyphs shape.
  Music/SFX buses already existed from M0; audio assets = gate-time decision.
- **Screenshot loop without the editor MCP**: `godot --path . --
  --shot=/tmp/x.png [--seed=N]` captures the combat screen after first paint.
  Gotcha caught with it: an autowrap Label sorted at ~0 width reports a
  one-glyph-per-line minimum height and the PanelContainer clamps up to fit
  (cards ballooned to 935px) — pin `custom_minimum_size.x` on wrap labels.
- Suite is 9 checks in 8 test files (`test_presentation.gd` drives a real
  fight headless through the instant drain via the same input paths).
- **Craft pass (opus-designer) landed**: "night-glass placards" — layered
  indigo gradient ground + ember glow + vignette; enemies as procedural
  faceted glass crystals (`glass_gem.gd`, tinted by content hue, dim/crack
  with HP, dark husk on death) on translucent panes with ember intent chips
  and segmented facet pips (`facet_pips.gd`); cards as type-tinted glass
  panes with corner cost-gems (`ember attack / glass-blue skill / violet
  power`); shared palette + stylebox factory in `glass_style.gd`. Styling
  only — zero logic changes, sequencer contract preserved.
- **Remaining for M5**: the human visual checkpoint (user judges the look
  against the web reference). Funplay MCP handshake still pending (editor
  must be opened once) — the --shot loop covers agent iteration meanwhile.

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
