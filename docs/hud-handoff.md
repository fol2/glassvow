# HUD → assembly handoff

Written 2026-07-26 by the combat-HUD lane, handing `presentation/combat/hud_bar.gd`
and `presentation/lab/hud_lab.gd` over for wiring.

`docs/assembly-integration-plan.md` § S4 already works out what `HudBar`
replaces, the value mapping and the five signals, and that analysis still
holds. **This document does not repeat it.** It carries three things S4 cannot
have: what changed in the widget after S4 was written, the answers to the
questions S4 asks of this lane, and the parts of the contract that only matter
once the thing is in a real fight.

## 1. Errata against S4

S4 was written against the widget as it stood earlier on 2026-07-26. Three
things moved since.

**`set_values()` takes ten ints, not nine.** `hand_count: int = 0` is appended
last. It defaults, so a nine-argument call still compiles — and reads wrong: the
deck seal is short by the whole hand. Feed it `cb.hand.size()`.

```gdscript
hud.set_values(
    cb.player.hp, cb.player.max_hp, cb.player.block,   # hp, max_hp, block
    run.player.gold,                                    # gold
    cb.player.energy, cb.player.energy_max,             # energy, max_energy
    cb.draw.size(), cb.discard.size(), cb.exhaust.size(),
    cb.hand.size())                                     # ← new, last
```

**The deck seal counts something different now.** It shows `draw + hand +
discard` — the cards still in the fight. Ash is excluded deliberately: a pile
whose meaning is *removed from the fight* cannot also be counted as in it. The
benchmark instead shows `p.deck.length`, the run's whole deck, a number that
never moves mid-fight. The port's number is a decision, not a bug; it is
recorded here so it does not get "corrected" back.

**`_init` takes three flags now**, all defaulting to today's behaviour:

```gdscript
HudBar.new(vial_frame := true, wide_plate := true, plate := true)
```

## 2. D2 — the plate: yes, the actor owns it

**Pass `plate = false`.** The benchmark is unambiguous and S4 read it right:
`.cplate` sits inside `.player-zone` at `position: absolute; top: 100%`, and the
 enemy carries byte-identical markup (`src/ui/combat.js:232` and
 `src/ui/combat.js:288` at
`6e069118`). It belongs to whichever actor it describes. `HudBar` hangs its own
copy at a fixed stage coordinate, which is correct in a lab with no hero in it
and wrong the moment a hero stands somewhere else.

The flag exists so this is one argument rather than a fork. With it false the
widget does not build the plate, and `set_values()` skips it — the ward and
plate arguments are simply not drawn.

**What this does not remove.** The top strip keeps its own HP readout —
`.hud-hp-wrap`: heart, `41 / 80`, and a 170px rail. That is a different element
from `.cplate`, and the benchmark runs both at once. Dropping the plate does not
leave the player without a health read.

## 3. D3 — the lantern

`set_lantern(charges: int, ready: bool)` — the count on the art, and whether it
can be spent. The domain has no charge count, so the honest mapping is:

```gdscript
hud.set_lantern(cb.embers, rules.can_use_art(run, cb))
```

Embers are the number, the rules gate is the readiness. `ready = false` desatur-
ates the art (`.lantern-btn.unlit`).

One thing S4 could not know: the benchmark's `.lantern-btn` carries **both**
`.lb-count` and `.lb-pips`, and only the count is ported. If pips are the read
you want, that is HUD-lane work — ask, do not build it in `combat_screen.gd`.

## 4. D5 — the three controls that lead nowhere

`deck_pressed`, `menu_pressed` and `pile_pressed(pile)` are plain signals.
Leaving them unconnected is safe: `HudBar` does not disable, grey out or
otherwise notice. So *inert for one commit* costs nothing structurally.

It is not free to the player, though. When the bench was driven by hand the
draw pile was clicked three times in a row — which is what someone does when
they expect a pile to open. A control that looks pressable and does nothing is
a real cost; either answer is fine, but it should be answered rather than
inherited.

## 5. The contract

**Coordinates.** Every offset in the widget is measured in the benchmark's
1180×820 combat screen, which is this project's viewport, so its CSS pixels are
our pixels with no scaling step. `_place()` re-hangs each cluster off its
nearest window edge, so a taller or wider window keeps the furniture in its
corner rather than stretching it. The top bar is the only thing that spans.

**Where the chrome sits**, for clearance checks:

| Cluster | Box (in 1180×820) | Hung off |
|---|---|---|
| top bar | `0, 0, 1180, 56` | top, spans |
| lantern | `18, 448, 104, 104` | bottom-left |
| energy orb + candles | `0, 568, 120, 90` | bottom-left |
| plate *(if built)* | centred on x 245, `y 614`, `h 34`, w 240 or 150 | bottom-left |
| draw pile | `16, 658, 96, 148` | bottom-left |
| END seal | `1060, 537, 120, 120` | bottom-right |
| ashes pile | `952, 658, 96, 148` | bottom-right |
| discard pile | `1062, 658, 96, 148` | bottom-right |

**One clearance worth checking before it surprises you.** S4's stage numbers put
the hero in a 190-wide box centred at x 200 — so x 105 to 295. The lantern
occupies x 18–122 and the energy orb x 0–120. Those overlap in x by about 17px.
The vertical extents may keep them clear (the lantern tops out at y 552, the orb
at 568); this lane cannot tell from here, and it is cheaper to look than to
discover it in a screenshot.

**Input and layering.** `HudBar` is `PRESET_FULL_RECT` with
`MOUSE_FILTER_IGNORE` — only its buttons take input, and everything else passes
clicks through to whatever is beneath. Add it above the stage and the actors and
below any modal overlay. The hand spans x 230–950, which clears every cluster
above.

**Calling `set_values()` is cheap and idempotent.** It guards on the ten ints
and returns immediately when nothing moved, so driving it from a signal that
fires for anything — or every frame — costs one array compare. The piles carry
the same guard and only rebuild their fan when a count actually changes. There
is no need to be clever about when to call it.

## 6. Two things that look like defects and are not

- **The pile fan is one `_draw()` per pile**, not one node per visible face.
  That collapse was deliberate — 48 `Control` nodes to 3 — and is written up in
  `docs/solutions/design-patterns/dom-node-per-layer-in-godot.md`. Do not turn
  it back into nodes to make a face hoverable; ask this lane instead.
- **The pile and seal numerals are baseline-anchored** off real font metrics
  rather than centred in a guessed box. See
  `docs/solutions/ui-bugs/godot-label-placement-guessed-font-height.md`.

## 7. Open in this lane, not blocking assembly

- **Plate width.** Two widths are built and switchable (`wide_plate`); the
  choice is with fol2 and is moot while D2 stands. If D2 is ever reversed, the
  A/B is a keypress away in the lab.
- **The ward chip's vertical gradient** (`linear-gradient(180deg, #1c3b55,
  #0e2033)`) is not ported — `StyleBoxFlat` has no gradient, and doing it
  natively means generating a rounded-pill texture and nine-patching it, with
  the rim and glow baked in. Deferred, not forgotten.
- **The pile backs** are out at the card line as `docs/pile-back-brief.md` —
  real card slabs instead of flat paintings. That change is entirely internal to
  `HudBar`: it swaps a texture and nothing about this contract moves.
- **No animation exists yet.** The benchmark has four the port has none of:
  `chromeIn` (the chrome flying in at combat start), `pileBump`, `blockPulse`
  and `candleFlick`. If the fight should feel alive at those moments, that is
  this lane's work and it has not been asked for.

## 8. Verifying it

The bench stands the widget up with no game behind it:

```bash
godot --path . -- --hud
```

`1`–`6` presets, `←`/`→` cycle, `H` panel, `F` vial frame, `W` plate width,
`P` plate on or off. `--noplate`, `--narrow`, `--noframe` and `--state=N` do the
same from the command line, and `--shot=PATH` captures. Captures must be run
**windowed** — headless has no viewport texture and the run hangs rather than
failing.

The gate, from the repo root: `tools/check_imports.sh`, then
`tools/check_scripts.sh`, then
`godot --headless -s res://tests/run_all.gd`. All green as of this handoff.

## 9. Ownership

This lane owns `presentation/combat/hud_bar.gd` and
`presentation/lab/hud_lab.gd`. Assembly owns `combat_screen.gd`, `main.gd`,
`main.tscn` and `project.godot`. If the wiring needs the widget to do something
it does not do — a plate anchor that follows the hero, lantern pips, a pile
overlay — that is a request to this lane, not an edit to these two files.

Shared tree, five concurrent sessions: **commit with explicit paths only.**
`3d0fce2` is what happens otherwise — a staged rename from this lane was swept
into another lane's commit.
