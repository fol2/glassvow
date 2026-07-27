# Assembling the true combat screen

Written 2026-07-26 by the Assembly lane (`4bb74d72`), against the benchmark
worktree at `6e06911` — read from source, not sampled from the render, per
`docs/session-ownership.md`. Companions: `docs/visual-direction.md` (decisions),
`docs/port-status.md` (what landed), `docs/session-ownership.md` (boundaries).

## The finding

The drift is not the wiring. Three finished widgets do sit unused in labs, and
that is real — but it is the smaller problem.

**The combat screen has no stage.** The benchmark's fight happens on a painted
ground with a ground line, and every actor stands on it. `combat_screen.gd`
paints a procedural indigo gradient, centres the enemies in a box near the top,
and represents the player as a 212px text panel in the bottom-left corner. The
M5d craft pass invented a look instead of porting one, and everything built
since has been fitted to that invention.

Two facts make this cheap to correct rather than expensive:

- **`EnemyView` is already built to the benchmark's real contract.** Its own
  docblock: *"Foes and heroes are the same animal — a painting standing at its
  own size on the ground line — so one actor serves both and the art id decides
  the folder."* It already ports `.hpbar-wrap` at 150, `.cplate` gap 6,
  `.top-chrome` at `calc(100% + 8px)`, and it already loads from
  `assets/art/heroes/`. The Enemy lane delivered an actor that expects a ground
  line. Assembly never built the ground line.
- **The stage art is already in the tree and has never been referenced.**
  `assets/art/stage/` holds nine PNGs — `act{1,2,3}-{backdrop,mid,ledge}.png`
  — imported, committed, and not named by a single `.gd` file.

So this is not "port the scene". It is "stop hiding the scene we already have".

## What the benchmark's combat screen actually is

`src/ui/combat.js:215–257` is the whole skeleton. Bottom of the z-stack upward:

| z | Element | What it is |
|---|---|---|
| — | `img.sl-backdrop` / `.sl-mid` / `.sl-ledge` | three painted parallax plates, centred, `bottom:0`, `min-width:100%` |
| 2 | `.combat-screen::after` | depth mist — 300px linear fade to `rgba(5,7,14,.55)` |
| 3 | `.stage-ledge` | 120px glow band sitting **at** the ground line, horizontally masked to 14–86%, with a 1.5px lit lip `--ledge-lip` above it |
| 0 | `.stage-breath` ×2 | two blurred radial blobs, 7s alternating breath |
| 4 | `.stage-dim` | radial lamp dimming, centre and radius driven live |
| 5 | `.cast-shadow-layer` | the projected actor shadows |
| 7 | `.battlefield` | `inset 0` with `bottom: var(--ground-y)` — **the region above the ground line** |
| 22 | `.hand-zone` | 680×260, centred (`left:50%; margin-left:-340px`), `bottom:-12px` |

`.battlefield` contains exactly two things:

```
.player-zone            ← positioned by JS: left, bottom, width, height
  .top-chrome             .status-row              (bottom: calc(100% + 2px))
  .hero-wrap              the painting              (100% × 100%)
  .cplate                 ward chip · hp vial · hp label   (top: 100%)
.enemy-zone
  .enemy   ×N           ← same three parts, plus .intent in top-chrome,
                          a name in the cplate, and a .facet-row
```

The hero and the enemy are the **same shape**. `.cplate` is `position:absolute;
top:100%; left:50%; translate:-50%` — it hangs off the bottom of its actor's
box and follows it. `.top-chrome` is the mirror above it. Neither belongs to the
HUD chrome layer.

### The resolved numbers for this project

Our viewport is 1180 × 820, which `src/stage.js:23` names **`pad-landscape`** —
one of the five authored shapes, not an approximation. So `BF.base` merged with
`BF.shapes['pad-landscape']` at act 0 is the layout, verbatim:

| Value | Resolved |
|---|---|
| `groundY` | **232** (px up from the stage bottom) |
| `ledgeLip` | 14 |
| hero box | `x 200` (centre), `w 190`, `h 285`, lift 0 |
| 1 foe | `x 980` |
| 2 foes | `x 820`, `x 1035` |
| 3 foes | `x 698 y+42`, `x 850 y−18`, `x 996 y+26` |
| tier size | normal 185 · elite 230 · boss 280 |
| layers (act 0) | backdrop `h 640 y 280 op .85 drift 30` · mid `h 1000 y 300 x +100 zoom .4 op .95 drift 10` · ledge `h 450 y 0 zoom 1 op 1` |
| `--ledge` tint | act 1 theme `glow: 6750110` → `#66ff9e` |

Placement, from `combat.js:392–414` — every `bottom` is measured up from the
ground line, because that is where `.battlefield` ends:

```
hero:  left = round(x − w/2)          bottom = hero.y + meta.footY
foe:   size = round(clamp(tierSize × slot.s × meta.scale,
                          8, stageW−16, stageH−groundY−bottom−8))
       left = round(slot.x − size/2 + meta.footX)
       bottom = slot.y + meta.footY
```

`footX` / `footY` / `scale` per actor come from `char-meta.json` — which this
repo already carries, and which `enemy_view.gd` already reads.

The chrome hung off the stage edges (`UIC`, `pad-landscape`) is what `HudBar`
already implements, and it matches exactly: `energy {left 0, bottom 162}`,
`lantern {left 18, bottom 268}`, `endTurn {right 0, bottom 163}`,
`draw {left 16, bottom 14}`, `ashes {right 132}`, `discard {right 22}`. That
widget is faithful and needs no rework — only a consumer.

## The drift, stated

| Concern | Benchmark | `combat_screen.gd` today |
|---|---|---|
| ground | painted plates + ledge glow + lip + mist + breath, ground line at 232 | indigo gradient + ember radial + vignette; **no ground line at all** |
| hero | a 190×285 painting at x 200 standing on the ground line, status row above, plate below | a 212px text panel pinned bottom-left with name, HP label, bar and two pill chips |
| foes | fixed slot centres, tier-sized, per-slot lift, depth-sorted | `CenterContainer` + `HBoxContainer`, separation 28, floating at `offset_top 90` |
| hand | 680 wide, centred, `bottom −12` | 720 wide (inset 230 each side), `bottom −10` |
| chrome | `HudBar` | hand-built top strip, right column, End Turn button, piles label |
| statuses | `StatusRow` of chips | *(another lane is landing this right now)* |
| scene art | three plates per act | nine PNGs sitting unused in `assets/art/stage/` |

The hand is the only one already close: 680 vs 720 wide, −12 vs −10 bottom.

## Ownership

Everything in the stage list below is `combat_screen.gd` — Assembly's file. The
actor *rendering* is `enemy_view.gd` (Enemy lane) and is **consumed, not
edited**; the actor *placement* is the screen's job and therefore this lane's.
`hud_bar.gd`, `status_chip.gd`, `intent_chip.gd`, `status_row.gd` and
`presentation/reward/` are likewise consumed only.

---

## S1 — build the stage — **LANDED** (`933ab46`)

`combat_screen.gd`. Replaced `_build_ui()`'s three procedural background nodes
with the real layer stack:

1. A `_ground_y: float = 232.0` on the screen, and a `battlefield` `Control`
   anchored full-rect with `offset_bottom = -_ground_y`. Every actor becomes a
   child of it, positioned by `bottom`.
2. Three `TextureRect` plates from `assets/art/stage/act1-*.png`, each with its
   authored height, y, zoom, opacity and `object-position` equivalent.
3. The ledge glow band (120px at the ground line, masked to 14–86% across), its
   1.5px lip 14px above, tinted `#66ff9e`.
4. The depth mist (300px bottom fade) and the two breath blobs.

**Deliberately deferred to a later pass, and marked as such in the code:** the
idle parallax drift (`--amp`), `stage-dim`'s live lamp tracking, and
`cast-shadow-layer` — `EnemyView` already projects its own shadow, so the shared
layer is only needed once shadows have to interact.

**Constraint to state up front:** our slice content carries no theme section
(`content_db.gd:45–62` has no `themes`), so the act → plate mapping and the
`--ledge` tint have to live in the presentation layer with a ponytail note until
the exporter carries them. Adding them to content is a `roguecardv2` exporter
change, outside every lane here.

## S2 — put the actors on it

Same file. Delete `enemy_center` / `_enemy_row` and the `player_pane` block
(`:122–182`), and place actors by the resolved table instead:

- Foes: `left = round(slot.x − size/2 + footX)`, `bottom = slot.y + footY`,
  `size` per the clamp above, drawn back-to-front by slot lift.
- **The hero becomes an actor.** `EnemyView` already loads
  `assets/art/heroes/%s.png` and `duskblade.png` is in the tree. Placing one at
  `x 200`, `190×285` on the ground line replaces the text panel outright, and
  the ward chip and HP rail come with it as that actor's `.cplate` — which is
  where the benchmark puts them.

This is the step that needs the Enemy lane's agreement, because a hero actor
wants `EnemyView` without an intent chip, without facet pips and possibly
without the name line. Whether that is a constructor flag or a sibling class is
**their** call, not this lane's. It is the one cross-lane request in the plan.

## S3 — the hand box

`hand_view.gd` / `combat_screen.gd`. 680 wide centred instead of 720 inset,
`bottom −12` instead of −10. Two numbers. Worth doing in the same wave as S2
because the hand's width is what decides whether the hero at x 200 and the
piles at x 16 are clear of the fan.

## S4 — the HUD

Wire `HudBar` in and delete the hand-built chrome. Full detail — what it
replaces line by line, the nine-value mapping, the five signals — was worked out
before the stage finding and still holds; the only change is that it now lands
*after* the stage, because `HudBar`'s plate is the one piece of it that S2 makes
redundant (the benchmark's `.cplate` belongs to the actor, and `HudBar` places
its own copy at a fixed stage coordinate). **Do not wire both.**

- The nine values map with nothing missing: `hp`, `max_hp`, `block`, `gold`,
  `energy`, `energy_max`, `draw`, `discard`, `exhaust` all exist today.
- `end_turn_pressed` → `_on_end_turn_pressed`; `lantern_pressed` →
  `_on_art_pressed`. `deck_pressed`, `menu_pressed` and `pile_pressed` have no
  destination in this port and would land as three dead controls.
- `_float_text` is anchored on four labels this step deletes (`:493`, `:542`,
  `:552`, `:574`); after S2 the natural anchors are the actors themselves,
  which is also what the benchmark does.

## S5 — the reward screen

`main.gd`. `game.gen_combat_rewards()` already returns exactly the dict
`RewardScreen` takes, so construction is direct and `_on_combat_over`'s text
building (`:184–198`) comes out. `show_result` stays for Defeat and
"Slice cleared". The blocker is the claim path: gold is already banked in the
application layer, `addCardToDeck` exists, **relic has no command**, and potion
can never fire (`rewards.gd:73-79` (in `gen_combat_rewards`) gates the phial behind a reveal a fresh
profile does not have).

## Chips — not this lane's work, **LANDED** by this lane (`b39cf54`)

Cross-lane queue item #1. The Chips and Enemy lanes built it; Assembly committed
it, because it could not be separated from `combat_screen.gd`: `status_row.gd`
was untracked while `combat_screen.gd` already named `StatusRow`, so either side
alone was a tree that does not parse. `EnemyView.sync()` went from three
arguments to five and `clear_intent()` replaced `set_intent("")`.

---

## Decisions needed

| # | Question |
|---|---|
| **D1** | S2 makes the hero a real actor, which needs `EnemyView` to serve a hero without intent chip / facet pips / name. Constructor flag or sibling class? **Enemy lane's call.** |
| **D2** | S4 and S2 both want to own the player's ward chip + HP rail. The benchmark says the actor owns it. Confirm `HudBar._build_plate()` goes unused rather than both being wired. |
| **D3** | `set_lantern(charges, ready)` — the domain has no charge count; the Art is once per turn gated on embers. The benchmark's `.lantern-btn` carries `.lb-pips`, so pips are the intended read. What feeds them? |
| **D4** | The Kindle toggle is this port's own invention and the benchmark's chrome has no seat for it. |
| **D5** | `deck` / `menu` / `pile` buttons lead nowhere in this port. Inert for one commit, or a minimal pile list through the existing `_inspect` panel? |
| **D6** | Relic claiming: application layer with a ponytail note (matching gold and rest-heal), or a new `domain/` command — which is off-limits to visual lanes and needs sequencing. |
| **D7** | Act theme data lives in the exporter, not our content. Confirm the hardcoded act → plate mapping is acceptable as an interim. |

## Order

**S1 → S2 → S3 in one wave, then S4, then S5.** The stage first, because every
later number is measured against the ground line; the actors second, because
they are what the stage is for; the hand third, because its width is decided by
what now stands beside it. S4 and S5 are then ordinary wiring against a screen
that is finally the right shape.

S1–S3 together are larger than SKILL §9's 400-line stop condition allows in one
task, so they land as three commits with a screenshot each, not one.

## Verification

Per lane rules — gate per file, do not run the suite:

```bash
godot --headless --check-only -s presentation/combat/combat_screen.gd
```

Then the shot, which SKILL §6 requires for any presentation change:

```bash
godot --path . -- --seed=1 --enter=0 --shot=/tmp/stage.png
```

Baseline taken 2026-07-26 before any of this, on a clean tree: parse gate clean,
`PASS (9 tests)`, engine `4.7.1.stable`.

## Off limits to this lane

`hud_bar.gd`, `status_chip.gd`, `intent_chip.gd`, `status_row.gd`,
`enemy_view.gd`, `presentation/reward/`, `glass_style.gd`, `domain/`,
`content/`, `port_fixtures/`, `tests/`. Commits use explicit paths;
`git status --short` is checked before each one.
