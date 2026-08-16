# Where this port diverges from the benchmark — and which way

**Written 2026-07-26, after `docs/wrong-reference-audit.md`.** That document
recorded three commits aimed at code the reference does not contain. This one
answers the larger question it opened: *how much of the port's stated provenance
points at the wrong tree, and which of those places are actually wrong on
screen?*

Divergence is not the same as error. A value that differs because nobody
checked is a **regression**. A value that differs because this engine can do
better, decided on purpose, is a **progression**. Most of what follows is
neither: the behaviour matches and only the `file:line` is wrong.

> **Superseded as a standard on 2026-08-16 — kept as measurement.** [#317](https://github.com/fol2/glassvow/issues/317)
> detached the reference: the port is content- and behaviour-owning, and the
> benchmark is no longer the authority against which any of this is judged. Every
> **R** row below is now port-owned UI/UX work judged against the commercial
> rubric, tracked on [#324](https://github.com/fol2/glassvow/issues/324) — never
> restored merely because the web did it differently. The measurements stay valid
> as observations, and the census above is the reason the 612 remaining citations
> were frozen rather than re-resolved.

## The content baseline stopped being faithful, and said otherwise

This document's subject is presentation. The same question asked of *content*
has a blunter answer, measured on 2026-08-16: `content/full-content.json`
carried `_source: {commit: 6e06911}`, claiming to be a verbatim capture, while
differing from a fresh capture by **12 values and 5 keys**.

| leaf | fresh capture of `6e06911` | checked in |
|---|---|---|
| `enemies/sovereign/hp` | 330 / 330 | **650 / 650** |
| `enemies/heraldOfEnd/hp` | 128 / 142 | **260 / 280** |
| `enemies/voidColossus/hp` | 155 / 168 | **300 / 320** |
| `enemies/rootheart/hp` | 150 / 150 | **240 / 240** |
| `enemies/leviathan/hp` | 260 / 260 | **310 / 310** |
| `relics/emberHeart/text` | heal 6 HP | **heal 3 HP** |
| present only in the checked-in file | — | `relics/emberHeart/heal`, `aspects[0].nameBare`, `aspects[1].nameBare`, `shadeKits[…].namePattern` ×2 |

Five boss HP curves, the Emberheart rework and two data-driven mechanisms —
`1b06346`, `32b45a1`, `1e0f0b9`, `c519def`. Each was a deliberate balance or
mechanism decision; **none was a decision to stop being a capture**, and
re-running `tools/capture_full_content.mjs` would have reverted all of them
without a word. The reasoning behind the numbers belongs to
[#203](https://github.com/fol2/glassvow/issues/203).

Two mechanism causes are worth recording, because both are the same disease this
document names elsewhere — a guard that exists in belief rather than mechanism.
The file was **one line of 65,591 bytes**, so `32b45a1 Lift the two short boss
curves` appeared in review as `1 insertion, 1 deletion`. And the test believed to
protect capture fidelity, `tests/test_original_content.gd:61-64` at `89f71c4`
(`_capture_survives`; the file is deleted below, so the commit is the only place
left to read it), took the already-edited tree file as its stand-in for a fresh
capture, so it would have passed at any amount of drift.

[#323](https://github.com/fol2/glassvow/issues/323) resolved it by deleting the
capture script, pretty-printing the baseline to 5,485 lines, and replacing the
`_source` claim with an ancestry note. The file is port-authored now, and says so.

## What was measured

The port carries **174 `file:line` anchors into the web reference**.
`tools/check_anchors.py` has never seen them — it checks anchors pointing into
*this* repo. So they were resolved mechanically for the first time: take the
backticked symbol beside each citation, and ask whether it exists at the cited
line in `6e06911`.

Then the same 174 were resolved against the post-Pixi tree. A frozen commit
cannot drift, so a citation that misses in one tree and lands in the other is
telling you which tree it was written against.

| resolved against | anchors that land |
|---|---|
| benchmark `6e06911` (pre-Pixi) — **the reference** | **45 / 174** |
| `web-reference-v1` `1343e1d` (post-Pixi) — 284 commits later | **119 / 174** |

The port's citations were written against the newer tree, not by exception but
as the norm. The failures partition cleanly:

| | count | meaning |
|---|---|---|
| symbol in both trees, line number shifted | **76** | citation rot; the code was still read from something real |
| lands in the newer tree, missing from the benchmark | **14** | written against code the reference does not contain |
| missing from both | 14 | mostly descriptive tokens the checker cannot resolve; four are real |
| resolves at the cited line | 45 | |

The 14 hard hits are where a real regression could hide, so every one was
opened and compared against the benchmark's actual behaviour.

## The divergence table

**P** progression — deliberate, defensible, keep it.
**R** regression — we are behind the benchmark and did not mean to be.
**C** citation only — behaviour verified equivalent; the anchor is wrong.
**?** open — not yet compared.

| # | Thing | This port | Benchmark `6e06911` | |
|---|---|---|---|---|
| 1 | ward shell on mid-combat restore | `set_ward_shell(true, **false**)` — no grow | `syncWardMesh(sprite, true, **true**)` → `meshWard(…, {grow: true})` (`combat.js:1897`) | **P** |
| 2 | mote flight stagger (`fly_to`) | all `n` motes spawn on one frame | a `delay` of `i * 46` — one mote every 46 ms (`combat.js:1457`) | **R** |
| 3 | mote flight scale (`fly_to`) | fixed size per mote | `0.5 → 1.05 @0.45 → 0.55` — swells at apex, shrinks on landing | **R** |
| 4 | mote flight mechanism | gravity 180, drag 0.35, velocity arc | three WAAPI keyframes over a random mid control point | **P** |
| 5 | enemy name weight | Cinzel 700 (only 700/800 bundled) | `.enemy .name` declares **no** `font-weight` → 400 (`styles.css:793`) | **R** |
| 6 | `ring()` / `slashArc()` | suppressed by `DEAD_KINDS` | present in source, NaN out before drawing — never on screen | **P** |
| 7 | enemy hit-test order | reverse iteration, last view wins | DOM `box.onclick` — topmost painted element wins (`combat.js:304`) | **C** |
| 8 | press on a card during targeting | hand seats resolve first, guard returns | `e.stopPropagation()` on the card (`combat.js:959`) | **C** |
| 9 | hover tick | one per seat crossed | `c.onmouseenter`, gated `if (FINE)` (`combat.js:961`) | **C** |
| 10 | aimed foe update | changes when the pointer crosses a body | `hoverEnemyAt` (`combat.js:1050`) | **C** |
| 11 | `impact_frame()` | `flash(WHITE, 0.28, 0.09)`, `hitstop(90)` | `flash('#ffffff', 0.28, 0.09); hitstop(90)` (`vfx.js:435`) | **C** |
| 12 | `DEAL_BUDGET` deal pacing | 500 ms budget → 100 ms stagger, 680 ms total | `drawBatchSchedule` (`pile-chrome.js:58`) — arithmetic exact | **C** |
| 13 | motion curves | `[0.22,1,0.36,1]` / `[0.34,1.56,0.64,1]` | `BASE_EASING` (`tokens.js:31`) — identical | **C** |
| 14 | `archetypeHit`, `BESPOKE_VFX`, ward underlay | as ported | byte-identical between both trees | **C** |
| 15 | damage floaters (`floaters.gd`) | 4 tiers, 450/640 ms, no rotation, poison rises | 18 `.floaty` tiers, 1100/1250 ms, ±8°/±16°, **poison drips down** | **R** |
| 16 | aim arc dashes | 10 dashes at 62% ink, scaled to the arc | `stroke-dasharray: 4 10` — 28.6% duty in path px | **R** |
| 17 | aim arc ink | `#ff8a92` @0.92, plus a 9px glow pass @0.16 | one stroke, `rgba(255,89,100,.85)`, width 4, no glow | **R** |
| 18 | aim reticle | r 11, width 2.5, plus a filled r-3 core | `r=9`, width 3, `rgba(255,89,100,.95)`, **no fill** | **R** |
| 19 | hover / armed card pose | lift 24 px, scale 1.08 | `.lifted` −92 px @1.38, `.armed` −118 px @1.24 | **R** |
| 20 | tap-after-drag guard | `CLICK_SLOP` — 12 px of travel | **time, not distance**: a click within 350 ms of a drag ends is swallowed | **R** |
| 21 | drag arm threshold | `DRAG_START_PX = 26`, upward only | `st.y0 - e.clientY > 26` | **C** |
| 22 | hand fan law | gap 112/640/246, tilt 5/42, sag 3.2, base 26 | `layoutHand` — **all seven identical** | **C** |
| 23 | aim arc geometry | P0 lifted 80, apex 120, quadratic | `M x,y-80 Q cx,cy x1,y1`, apex `min(y0,y1)-120` | **C** |
| 24 | press the stage with nothing armed | returns early — a lifted card cannot be set down | `else if (S.hoveredCard != null) { … }` (`combat.js:359`) | **R** |
| 25 | hover tick on a coarse pointer | fires — twice per tap, with the COARSE branch | `onmouseenter` is wired only `if (FINE)` (`combat.js:960`) | **R** |

Twelve of the twenty-three are citation-only: the code was read correctly and
written down against the wrong line. Row 12 is the clearest case — the comment
claims a 500 ms budget yields a 100 ms stagger, a 280 ms flight and a 680 ms
total, and `drawBatchSchedule(5, 500)` returns exactly that. Whoever wrote it
had the real function in front of them; only the line number came from
elsewhere.

## What the four Pixi-sourced widgets turned out to be

None of them needed the file it cited. Every one has a pre-Pixi original, and
the results split three ways rather than the one way "ported from Pixi" implies.

**The hand fan law was right all along (rows 21–22).** `hand-layout.js` does not
exist at `6e06911`; the law is inline in `layoutHand` (`combat.js:983`). All
seven constants match to the digit — `min(112, 640 / n, (stageW - 246) / (n-1))`
for the gap, `min(5, 42 / n)` for the per-seat tilt step, `|rot| * 3.2` for the
sag, `+ 26` for the base. So does the 26 px upward-only drag arm
(`st.y0 - e.clientY > 26`, `combat.js:1038`). Nobody should re-derive these.

**The card poses are not (row 19).** The benchmark lifts a hovered card
**92 px at scale 1.38** and an armed one **118 px at 1.24**
(`styles.css:634-635`). This port lifts 24 px at 1.08 — roughly a quarter of the
travel, on the gesture the whole hand reads through.

**`CLICK_SLOP` is invented, and the real guard is a different kind of thing
(row 20).** There is no distance test for a tap that follows a drag. The
benchmark stamps `dragConsumedAt` when a drag ends and drops any click inside
350 ms of it (`combat.js:1262`). A distance slop cannot express that, and the
two disagree exactly where it matters: a slow, short drag.

**The aim arc is an SVG path, not a Pixi paint (rows 16–18, 23).** `aimMove`
writes `#aim` (`combat.js:1063`) — a fixed full-stage `<svg>` at z-index 45 —
with one quadratic path plus one circle:

    M from.x,(from.y - 80)  Q cx,cy  mx,my
      stroke rgba(255,89,100,.85)  width 4  dasharray "4 10"  linecap round
    circle cx=mx cy=my r=9  stroke rgba(255,89,100,.95)  width 3  no fill

The geometry this port ported is exactly right. Everything drawn along it is
not: the dashes are a fixed 4-on/10-off in path pixels rather than ten cells at
62% ink, there is one stroke rather than a glow pass under an ink pass, the ink
is `#ff5964` rather than `#ff8a92`, and the reticle is an empty ring of r 9 at
width 3 rather than an r-11 ring at 2.5 around a filled core.

One behaviour worth keeping from the same function: when targeting is not a
card the arc starts at `{stageW()/2, 60}`, not at a seat.

**The floaters are the CSS ones (row 15).** `floaters.gd` says the stylesheet's
`.floaty` variants are "explicitly the non-combat path" and quotes a comment
about combat floaters being Pixi-owned. That comment belongs to the newer tree.
At `6e06911` `floatText` (`vfx.js:175`) builds a `.floaty` div and `drain.js`
calls it *during combat* — `blockf` on a block, `debufff` on the ember toll.

The spec it should have been built from:

- Base `.floaty` (`styles.css:1497`): Cinzel **800**, **32 px**, `#fff`,
  tabular-nums, an eight-offset `#05070e` outline, `0 0 12px rgba(255,90,90,.9)`
  and `0 3px 6px #000`.
- **18 tiers**, not four. Sizes where they differ: `dmg-big` 42, `dmg-kill` 52,
  `dmg-overkill` 62 with a 1.5 px white text-stroke, `crit` 47, `blockedf` /
  `bufff` / `debufff` 22, `notice` 20, `movef` 14 in a bordered pill.
- **Three animation shapes**, not one. Default 1100 ms, `-50% → -90% @0.18 →
  -230%`, scale `0.6 → 1.15 → 0.95`, rotation ±8° for damage only. Crit 1250 ms
  with a four-stop `brightness(3 → 1.9 → 1)` blaze and ±16°. Poison **drips
  down**: `-50% → -26% @0.2 → +80%`.
- Horizontal drift `(random - 0.5) * 40`, applied only at the last stop; easing
  `cubic-bezier(.2,.7,.3,1)` over the whole iteration.
- The Y figures are percentages of the element's own height, not pixels.

Against that, this port runs 450/640 ms, four tiers, no rotation, no crit, and a
poison numeral that rises.

## The ones that are ours on purpose

**Row 1, the ward restore.** The benchmark grows the shell again on a restore,
including at combat start when a relic like `basaltIdol` grants block before
`blockGain` ever fires. This port raises it already formed. The comment in
`combat_screen.gd` gives the reason — the stone was up before the screen
existed, so it should not build itself in front of you — and that reason is
sound. What the comment gets wrong is quoting `syncWardMesh(heroSprite, true,
true)` and then describing it as raised *without* the grow. The benchmark's
third argument **is** the grow flag and it is `true`. **Moot in practice: the
ward is being redesigned**, so this row is recorded and not acted on.

**Row 6.** Suppressing two primitives the reference never draws is parity, not
licence.

**Row 4 was not one of them, and the distinction is the whole point of this
document.** "A particle system instead of three keyframes" sounds like a
mechanism choice. It was not: with drag on and a fixed upward bias the mote
under-lifted about fivefold and arrived above the target rather than on it. A
quadratic Bézier and a projectile are the same parabola, so the shape was never
the argument — the pacing and the endpoint were, and both were wrong. Fixed in
`65ffac8` by interpolating the benchmark's own three control points and leaving
the renderer alone. The engine's way of drawing a thing can stay ours; where the
thing ends up cannot.

## Fixed

| row | commit |
|---|---|
| 2 mote stagger, 3 mote scale, 4 mote path, plus a 2x size error found with them | `65ffac8` |
| 5 enemy name weight — `Cinzel-500.woff2`, byte-identical to the benchmark's own | `d1c228d` |
| 24 stage press lowers a lifted card, 25 hover tick behind the pointer test | `038f390` |

The size error is the one worth remembering. `size` in `flyTo` is a DOM width,
so a diameter; `size` in `vfx.js` is the argument to `arc()`, so a radius. The
port carried `drain.js`'s 6 and 7 across into the second meaning and drew every
mote at double. Nothing in the citation was wrong. The unit was.

## The 30 anchors that sat in changed code — resolved, and clean

The sweep left one open question: 112 of 148 resolvable anchors point at code
identical in both trees, but **30 sit in regions that genuinely differ**, and
symbol presence alone said nothing about whether the port's claim survived.
All 30 were opened and compared body against body.

**They came back clean on substance.** Every one of the port's behavioural
claims holds against `6e06911` — the drag's two branches (`setTargeting` for
`target === 'enemy'`, `st.free = true` for everything else, `combat.js:1141`),
the click path's disarm-on-second-press, the unplayable rejection, the `armed`
pose, the 200 ms spent-card flight, the 0.3 low-HP threshold, the sources that
skip `choreoHit`. All 30 line numbers are wrong; none of the behaviour was.

Five earlier pieces of work were positively validated in the process, because
what they cite exists **only** in the benchmark:

- `.art-cast` and its rule (`styles.css:1122`) — zero occurrences in the newer
  tree, which moved the art cast to Pixi.
- `choreoStagger` — one definition in the benchmark's `combat.js`, zero in the
  newer tree's, which moved it to `combat-choreo.js`.
- `choreoAttack` — identical in both trees, line for line, at the same number.
- `flyTo`'s DOM path.
- `layoutHand`'s `armed` handling, which the newer tree deleted entirely.

Two new regressions did come out of it, both recorded above as rows 24 and 25,
and neither was found by comparing bodies. They came from following a fact
sideways: `tapBackground` is absent from the reference, and the handler that
replaces it carries an `else` branch this port never had.

## Still open, all measured

Rows 15–20 are regressions with a full specification recorded above and no work
done. Rows 15 (floaters) and 19 (card poses) are the two that touch every fight:
one is every numeral on the screen, the other is the gesture the hand is read
through. Rows 16–18 are one file and one afternoon.

## How to keep this from coming back

> **Granted, then retired — and the sequel matters more than the request.** The
> gate below was built, and it worked: `tools/check_web_anchors.py` shipped at ~450
> lines. It also needed the benchmark checkout, so it exited 2 wherever that was
> absent — every CI runner, every git worktree — and stayed hand-run, which is the
> weakest kind of gate there is. On 2026-08-16 (#325) it was deleted with the
> detachment and replaced by `tools/check_benchmark_freeze.py`, which does not
> resolve citations at all: it **counts** them per file against a frozen census and
> refuses an increase. New citations being banned, that is the whole of the rule —
> and needing nothing, it runs in CI. Keep the method below for the record; it is
> the right design for the problem as it stood.

`tools/` is organiser-owned — lanes run it, no lane edits it — so this is a
request rather than a commit. A `tools/check_web_anchors.py` belongs in the
verification block in `AGENTS.md` beside `check_anchors.py`. It is about eighty
lines and the method is the whole of it:

1. Pull every `` `symbol` (file.js:NNN) `` out of `presentation/` and
   `application/`, taking the backticked token from the comment block the
   citation sits in.
2. Map each basename to its path at `6e06911` (`combat.js` → `src/ui/combat.js`,
   `vfx.js` → `src/vfx.js`, and so on). A basename with no path is the loudest
   possible failure — the file does not exist in the reference.
3. Grade: **GONE** (no such file), **OOB** (line past EOF), **ABSENT** (symbol
   nowhere in the file), **DRIFT** (symbol real, different line), **ok**.
4. **Run it a second time against the post-Pixi tree and diff the two verdicts.**

Step 4 is what makes it worth having. Against one tree the report is 118
failures deep and the 14 that matter are buried in it. Against two, the 14
name themselves: they are the anchors that miss the reference and land in the
tree the reference is not.

Until it exists, the rule from the audit still stands — if a symbol is missing
from `~/Coding/roguecardv2-benchmark`, it is not portable, however good it looks
in the newer tree.

## Putting the benchmark into a named fight — the reproducible recipe

Everything above was measured from source. Measuring it on the screen needs the
benchmark in a *known* fight, and until now nobody had a way to ask for one.
There is one, and it was in the reference the whole time.

```
http://localhost:5190/?lab&shape=pad-landscape&scenario=<base64url>
```

- **`?lab`** boots the Content Lab (`main.js:20`, dev builds only).
- **`?shape=pad-landscape`** forces the 1180x820 stage (`stage.js:33`). Without
  it a wide desktop window resolves to **`desktop-landscape` (1458x820)** — a
  genuinely different layout, not a scaled one. Any comparison made in that
  shape is against the wrong chrome.
- **`?scenario=`** is base64url JSON, decoded at `lab.js:673`. Required fields:
  `v, mode, seed, aspectId, themeId, omenId, kind, enemies[{id,variantId}],
  deck[{id,up}], hand`. Build it in the page — `await import('/src/dev/lab-scenario.js')`
  then `encodeLabScenario(...)`; the validator names every missing field.

Verified on 2026-07-27 with two sporelings at seed 7. The stage came up at
exactly 1180x820 and three independently recorded numbers landed on the nose:
`.end-turn` at 1060,537, `.hud-bar` 1180x56 at the origin, `.pile-draw` at
16,658. Both enemy art boxes measured **115x115 at y 473**, x 763 and 978 —
which is also what `assets/art/enemies/char-meta.json` gives a sporeling.

**This must be done in a real browser.** The in-app Browser pane serves the page
with `document.visibilityState === "hidden"`, which throttles rAF to a stop. The
consequences are not subtle and they are silent:

- **No creature ever appears.** Bodies are drawn on the WebGL `canvas#mesh`, and
  `.mesh-live > .raster-art { opacity: 0 }` hides the DOM image that would
  otherwise stand in. The stage, chrome, cards and backdrop all render normally,
  so the screenshot looks healthy and the floor is empty.
- **Screen transitions never settle.** `.combat-screen` keeps `screen-enter`
  forever and inputs stop responding after the first one.

In Chrome the same page reports `visible`, the GL context is live, and the
sporelings draw. `?mesh=0` is the fallback if only geometry is needed.

## The geometry, measured on both sides

With the recipe above, the benchmark and the port can be put in the same fight —
two sporelings, seed 7 — and every box compared. Sixteen independent
measurements, taken off the live DOM in design pixels and matched against the
port's own constants:

| element | benchmark, measured | port | |
|---|---|---|:-:|
| stage | 1180 x 820 | `STAGE` | ✓ |
| hud bar | 1180 x 56 at the origin | `BAR_H 56` | ✓ |
| end turn | 1060, 537 — 120 x 120 | `Rect2(1060, 537, 120, 120)` | ✓ |
| lantern | 18, 448 — 104 x 104 | `Rect2(18, 448, 104, 104)` | ✓ |
| draw pile | 16, 658 — 96 x 148 | `Rect2(16, 658, 96, 148)` | ✓ |
| ashes pile | 952, 658 — 96 x 148 | `Rect2(952, 658, 96, 148)` | ✓ |
| discard pile | 1062, 658 — 96 x 148 | `Rect2(1062, 658, 96, 148)` | ✓ |
| card | 152 x 216 | `CARD_W` / `CARD_H` | ✓ |
| pile fan | 5° step, 30° span, 16 faces | `FAN_STEP` / `FAN_SPAN` / `FAN_FACES` | ✓ |
| ground line | 588 — enemy feet sit on it | `GROUND_Y 232` (820 − 232) | ✓ |
| ledge lip | 14 | `LEDGE_LIP 14` | ✓ |
| enemy slots, two foes | centres 820.5 and 1035.5 | `Vector2(820, 0)`, `Vector2(1035, 0)` | ✓ |
| enemy art box | 115 x 115 | `char-meta.json` sporeling 115 | ✓ |
| hero | centre 200, 190 x 285 | `HERO_X 200` | ✓ |
| hp rail | inner bar 9 tall | `RAIL_H 9` | ✓ |
| hand fan tilt | ±10° at five cards | `min(5, 42 / n)` | ✓ |

**Sixteen for sixteen.** The chrome layout and the battlefield geometry are
exact. Whatever else this port got wrong, it did not get the boxes wrong.

The card measurement is worth one line of explanation, because the raw numbers
look like they disagree. A five-card hand reports bounding boxes of 187, 170,
152, 170, 187 — symmetric, and only the middle one is 152 x 216. That is not
five different card sizes. It is one card size seen through five rotations: an
axis-aligned bounding box grows with the tilt, and the middle seat has none.
The ±10° that produces 187 from 152 is exactly `min(5, 42 / 5) × 2`.

### The false regression this caught

`battlefield-layout.js` gives `hero: { x: 179, w: 190, h: 285 }`. The port has
`HERO_X = 200.0`. Read side by side in the source, that is a 21 px error in the
hero's standing position, on a lane's own file, and it would have been "fixed".

Measured, the hero's rendered centre is **200.0** — the port's number, to the
decimal. `hero.x` is not the centre: the hero box spans 105 to 295, so 179 is
neither its centre nor either edge. Whatever origin that field is expressed in,
the layout does not put the hero there.

This is the argument for the recipe above in one example. Reading two sources
and diffing the numbers manufactures regressions that do not exist, in exactly
the same way that reading the wrong tree hid the ones that do.
