# The port was reading the wrong reference — what that hit, and what is still open

**Written 2026-07-26. Every lane needs to read this before its next parity pass.**

## What happened

`AGENTS.md` named [web-reference-v1](https://github.com/fol2/roguecardv2/tree/web-reference-v1)
— `1343e1d`, 2026-07-24 — as the reference, and on this machine that tag is
checked out at `~/Coding/roguecardv2`. It is not the benchmark.

**The benchmark is `6e06911` (2026-07-13), checked out at
`~/Coding/roguecardv2-benchmark`, and it is what `localhost:5190` serves.**
It is **PRE-PIXI**. The two are **284 commits** apart, and the Pixi combat
renderer landed between them (`96ac5e5`, 2026-07-13, "scaffold combat Pixi
renderer (Task 22a)").

So parity specs were being read from one tree while pixels were measured on the
other. `AGENTS.md` is corrected; this file records the damage.

Confirm before quoting any `file:line`:

```bash
git -C ~/Coding/roguecardv2-benchmark log -1 --format=%h   # must print 6e06911
```

## What the newer tree has that the benchmark does not

| | in the benchmark? |
|---|---|
| `src/ui/combat-gl.js` | **no** |
| `src/ui/combat-presentation.js` | **no** |
| `src/ui/combat-choreo.js` | **no** — `choreoAttack`/`choreoHit`/`choreoStagger` are inline in `combat.js` |
| `#uigl` (the Pixi canvas, z 51) | **no** |
| `chromePulse` | **no** |
| Pixi `artCast` | **no** — it is a DOM `<img class="art-cast">` |
| Pixi floaters / `TIER_STYLE` | **no** — `floatText` makes a DOM `.floaty` div; 19 `.floaty` rules carry the tiers |
| `paintAim` | **no** |
| `EASING` in `tokens.js` | **no** — the benchmark has `BASE_EASING` at `tokens.js:31` |

Files that differ substantially: `styles.css` 725+/179−, `drain.js` 161+/186−,
`mesh.js` 118+/22−, `vfx.js` 72+/7−. **Identical in both:** `scene3d.js`,
`ward-params.js`.

## Verified against `6e06911` and CORRECT — no action

| commit | what was checked |
|---|---|
| `b926ae1` `.stage-dim` | `rgba(3,4,10)`, hole 42%, 1500px, `gutter 1.9s`, `#lantern` z 21 |
| `6843a2a` boss worldstop | `saturate(.07) brightness(.85)`, `hitstop(110)`, `doomTremble .09s`, `drop-shadow(0 0 7px rgba(255,255,255,.95))` |
| `1d90ebc` defeat snuff | `#lantern.snuff` radial identical |
| `d86f906` tr-bloom / tr-crack | `#ffe9ac 0% / #f2c14e55 30% / transparent 70%`; `rgba(3,4,10,.9)` |
| `c77b56b` elite hitstop removed | the reference has exactly four hitstops (90, 70, 130/90, 110) and none is an elite death |
| `8bbc8a5` BESPOKE_VFX | 18 entries; `archetypeHit`, `slashArc` and `impactFrame` are byte-identical between the two trees |
| `5629467` ward shell | `ward-params.js` byte-identical; both `mesh.js` claims hold |
| `8dc3539` `kick()` | `scene3d.js` byte-identical; all seven call sites identical |
| `623499c` reseam | `animation: reseam 0.7s ease-out`, `30% { brightness(1.55) saturate(0.55) }`, `setTimeout(720)` |
| `a303795` dead `ring`/`slash` | the NaN bug is identical in both trees; measured 0 pixels on the running benchmark |

## Wrong, and already handled

| commit | fate |
|---|---|
| `e071e34` chromePulse | reverted (`41167ca`). The ember beat's 440ms deferral was KEPT — it is the benchmark's, at `drain.js:371` |
| `d367e44` Pixi artCast | redone as `ee4dab6` from the DOM `.art-cast` |
| `806272c` effect layer under the chrome | reverted (`6d420f7`). There is no `#uigl`; `#vfx` at z 50 IS above `#shake` at 10, so the port's original order was right |

## STILL OPEN — other lanes' files, not touched

Four widgets were ported from sources the benchmark does not contain. None has
been re-checked; the values may or may not survive.

1. **`presentation/combat/floaters.gd`** — its own docblock says *"the PIXI
   floater, not the CSS one"*, and cites `TIER_STYLE (combat-presentation.js:31)`.
   The benchmark makes a DOM `<div class="floaty ...">` (`vfx.js:177`) and
   carries the tiers in **28 `.floaty` rule blocks**. Highest risk on this list:
   every damage numeral in the game goes through it.
2. **`presentation/combat/aim_arc.gd`** — *"Ported verbatim from `paintAim`
   (`combat-gl.js:1254`)"*. `paintAim` does not exist in the benchmark.
3. **`presentation/combat/hand_view.gd`** — the four seat poses cite
   `combat-gl.js:1096-1123` (Assembly lane).
4. **`presentation/combat/motion.gd`** — cites `EASING (tokens.js:52)`. The
   benchmark has `BASE_EASING` at `tokens.js:31`; the values need comparing.
   `motion.gd` is consumed by several lanes, so a change there is a cross-lane
   event.

`docs/battlefield-parity.md` also lists `combat-choreo.js` and
`combat-presentation.js` among its sources and needs the same pass.

## The two rules this cost

- **Read from `~/Coding/roguecardv2-benchmark`.** If a symbol is missing there it
  is not portable, however good it looks in the newer tree.
- **A function existing in the source is not evidence that it renders.** `ring()`
  and `slashArc()` push particles with no `vx`/`vy` while the draw loop does
  `p.x += p.vx * dt` unconditionally, so their coordinates go NaN before they
  draw. They have never been on screen at either commit. This port's `Part`
  class defaults `vel` to zero, silently repaired the bug, and grew two
  expanding rings and a slash arc that were then defended as parity. Measure on
  the running page.
