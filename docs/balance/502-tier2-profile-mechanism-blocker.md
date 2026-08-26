# #502 Tier-2 counter-profile census — mechanism blocker

Issue: [fol2/glassvow#502](https://github.com/fol2/glassvow/issues/502).
Base: landed #501 head `cb5b542bc744ef160463591a6e00456227b3f2e5`.
Engine: `4.7.2.stable.official.ed1daf0bf`.

Status: **STOP — no legal cleanse/status-removal mechanic exists in the fixed
Act I–III enemy moves and effects.** The issue's stop clause applies. No four
enemies are selected, and no registry, factorial, profile instrumentation or F0
response contract is authored from this result.

## Exact reference and bounded census

The census used reconstructed s009 content and the exact empty mob override.
The s009 and H39 `enemies` subtrees are identical, with canonical subtree
SHA-256 `c8ced7411998b3c648f4986de509a4553ea57aadca150741ebeab81c3a2f2dd4`.
The live H39 catalogue and `content/mob-overrides.json` remained unchanged.

The one admissible census was:

```bash
python3 -B tools/balance_s009_reconstruct.py --out "$OUT/s009-full-content.json"
godot --headless -s res://tools/balance_sweep.gd -- \
  --mode=sweep --out="$OUT/census.ndjson" \
  --rootSeed=7354 --policyFirst=0 --policyCount=1 \
  --seeds=32 --seed0=12064 \
  --content="$OUT/s009-full-content.json" \
  --stage=tier2-profile-census
```

This produced 128 rows across the four grids, with zero stalls and zero errors.
The raw NDJSON SHA-256 is
`f28203e4def3ed013b06fb30a7df1cd48ed6bf2780fbf3c18f5a7b774ddb67d7`.
The compact checked-in packet is
[`data/502/profile-census-blocker-v1.json`](data/502/profile-census-blocker-v1.json),
SHA-256 `20c03f1e1357de9b80c6a829c3e9e3b42f29dd31aef5cfd222067bee3a1033d9`.
It binds the content, empty mob override, search space, seed contract, driver,
commit and Godot identities. It also records exact move IDs, numeric move
leaves, status effects, complete start-status shape, locale coverage and
per-grid exposure counts.

Counts below are enemy units in design order **Dusk v0 / Dusk v5 / Ash v0 /
Ash v5**. Bosses and Act IV/counterfactual enemies are excluded. All 24 rows
have executable `EnemyAi` handling and both en and zh-Hant locale-owned names.
The only non-empty start-status entries are `chaosHound.rampage = 1` and
`thornling.thorns = 2`; the other 22 entries have an empty start-status shape.
Both seed a known non-negative status at combat setup and neither removes one.

| Enemy | Act/tier | Census counts | Total | Existing numeric move leaves | Existing status effects | Removes status? |
|---|---|---:|---:|---|---|---|
| `abyssalKnight` | II elite | 8 / 4 / 2 / 2 | 16 | block, dmg, times, fx.n | self str +2; player vulnerable/weak +2 | no |
| `alphaFang` | I elite | 8 / 9 / 10 / 13 | 40 | dmg, times, fx.n | self str +3 | no |
| `ashAcolyte` | I normal | 25 / 23 / 23 / 24 | 95 | dmg, fx.n | self ritual +2 | no |
| `chaosHound` | III normal | 17 / 4 / 24 / 10 | 55 | dmg, ramp, fx.n | self str +2 | no |
| `deepmaw` | II normal | 17 / 9 / 15 / 17 | 58 | dmg, heal, fx.n | player vulnerable +2 | no |
| `drownedOne` | II normal | 79 / 33 / 88 / 60 | 260 | dmg, times, fx.n | player weak +2 | no |
| `duskfang` | I normal | 93 / 95 / 97 / 92 | 377 | dmg, times, fx.n | self str +2 | no |
| `gloomslime` | I normal | 42 / 32 / 36 / 34 | 144 | block, dmg, fx.n | player weak +2 | no |
| `gravewarden` | I elite | 14 / 13 / 12 / 9 | 48 | block, dmg, fx.n | player frail/vulnerable +2 | no |
| `heraldOfEnd` | III elite | 5 / 0 / 5 / 3 | 13 | dmg, times, fx.n | player poison +7; self str +3 | no |
| `mirelurker` | II normal | 66 / 24 / 83 / 69 | 242 | block, dmg, fx.n | player poison +3 | no |
| `obsidianGolem` | III normal | 12 / 6 / 9 / 6 | 33 | block, dmg, fx.n | player frail +2 | no |
| `shade` | III normal | 45 / 24 / 37 / 13 | 119 | block, dmg, times, fx.n | player weak +2 | no |
| `shellback` | II normal | 15 / 14 / 11 / 14 | 54 | block, dmg, times, fx.n | self thorns +1 | no |
| `siren` | II elite | 12 / 3 / 11 / 6 | 32 | block, dmg, heal, times, fx.n | player weak/frail +2 | no |
| `sporeling` | I normal | 182 / 179 / 184 / 174 | 719 | dmg, fx.n | self str +1 | no |
| `starCultist` | III normal | 43 / 9 / 45 / 16 | 113 | dmg, fx.n | self ritual +3 | no |
| `thornling` | I normal | 46 / 30 / 50 / 50 | 176 | dmg, fx.n | self thorns +2 | no |
| `tidecaller` | II normal | 27 / 16 / 51 / 24 | 118 | dmg, fx.n | allies str +2; player frail +2 | no |
| `voidColossus` | III elite | 5 / 3 / 2 / 8 | 18 | block, dmg, fx.n | self str +2; player frail +3 | no |
| `voidWisp` | III normal | 51 / 27 / 51 / 26 | 155 | dmg, heal | — | no |
| `voltEel` | II normal | 51 / 34 / 70 / 54 | 209 | block, dmg, fx.n | self str +1 | no |
| `watcherEye` | III normal | 29 / 7 / 14 / 13 | 63 | block, dmg, fx.n | player vulnerable +2 | no |
| `waylayer` | I normal | 45 / 57 / 46 / 51 | 199 | block, dmg, fx.n | player frail +2 | no |

Twenty-one enemies clear the ticket's total-24/two-grid reachability floor.
Reachability is therefore not the blocker.

## Concrete schema and execution blocker

The ticket fixes each enemy's start-status shape.
`ContentDB._validate_start_status` accepts only known status IDs and
non-negative whole-number amounts, while `CombatRules` copies those values into
each enemy's statuses at combat setup. The two existing non-empty leaves are
therefore additive initial state, not a move-owned removal operation or a
three-level cleanse control.

`ContentDB._validate_enemy_moves` preserves the baseline move-ID set and
locale-owned move names. The tunable numeric move leaves it recognises are
`dmg`, `block`, `heal`, `ramp`, `times`, `addCards.n` and existing `fx.n`.
`ContentDB._validate_move_fx` restricts each effect to `self`, `player` or
`allies`, a known status ID and a **non-negative** whole-number amount. A live
validator probe over s009 confirmed all 24 IDs are handled and rejected
`sporeling.grow.fx[0].n = -1` with:

```text
sporeling.moves.grow.fx[0] has an invalid target, status, or amount
```

`CombatRules.end_turn` executes those leaves as damage, block, heal, ramp,
card addition or additive status application. Its `fx` path calls
`add_status_player`/`add_status_enemy`; it has no move-owned cleanse, purge,
dispel or status-removal operation. `_tick_status` performs fixed automatic
decay: enemy poison before its action, then vulnerable and weak after it. Those
ticks can erase an expired status, but have no enemy-definition leaf, are not
profile-attributable and cannot form the required three-level
`cleanseIntensity` knob.

Consequently:

- the legal write set for `cleanseIntensity` is empty;
- low/baseline/high would either be semantically identical or require a new
  field, a negative effect, a new move/effect kind or a new AI arm;
- a `3^4` design cannot produce 81 unique semantic effective catalogues;
- no profile-attributable status-removal instrumentation can fire on a targeted
  legal fixture.

Calling poison, weak, frail, vulnerable, thorns, strength or ritual application
"cleanse" would relabel an unrelated effect and is expressly forbidden by
#502. Adding a mechanism is also out of scope. The bounded Tier-2 decision in
#500 therefore needs explicit revision before this chain can continue.
