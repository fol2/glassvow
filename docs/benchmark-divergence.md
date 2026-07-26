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
| 2 | mote flight stagger (`fly_to`) | all `n` motes spawn on one frame | `delay: i * 46` — one mote every 46 ms (`combat.js:1457`) | **R** |
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
| 15 | damage floaters (`floaters.gd`) | ported from the Pixi floater | DOM `.floaty` div (`vfx.js:177`) + 28 CSS rule blocks | **?** |
| 16 | aim arc (`aim_arc.gd`) | ported from `paintAim` | `paintAim` does not exist | **?** |
| 17 | hand seat poses (`hand_view.gd`) | cites `combat-gl.js:1096-1123` | file does not exist | **?** |
| 18 | drag / long-press thresholds | cites `pointer.js:5` | file does not exist; both constants absent | **?** |
| 19 | hand fan law | cites `hand-layout.js` | file does not exist | **?** |

Nine of the nineteen are citation-only: the code was read correctly and written
down against the wrong line. Row 12 is the clearest case — the comment claims a
500 ms budget yields a 100 ms stagger, a 280 ms flight and a 680 ms total, and
`drawBatchSchedule(5, 500)` returns exactly that. Whoever wrote it had the real
function in front of them; only the line number came from elsewhere.

## The two that are ours on purpose

**Row 1, the ward restore.** The benchmark grows the shell again on a restore,
including at combat start when a relic like `basaltIdol` grants block before
`blockGain` ever fires. This port raises it already formed. The comment in
`combat_screen.gd` gives the reason — the stone was up before the screen
existed, so it should not build itself in front of you — and that reason is
sound. What the comment gets wrong is quoting `syncWardMesh(heroSprite, true,
true)` and then describing it as raised *without* the grow. The benchmark's
third argument **is** the grow flag and it is `true`. The deviation should be
labelled as a deviation.

**Rows 4 and 6.** A particle system with gravity is a legitimate way to spend an
arc that the web spends on three keyframes, and suppressing two primitives that
the reference never draws is parity, not licence.

## The three that are ours by accident

Rows 2, 3 and 5. None is a judgement call; each is a value nobody compared.
Row 2 is the one to look at first: 46 ms between motes is the difference
between a stream and a puff, and it costs one line. Row 5 needs a fourth Cinzel
weight bundled, which is an assets change rather than a lane change.

## How to keep this from coming back

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
