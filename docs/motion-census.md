# The motion census — every animated thing on the combat surface

Until now, divergences from the reference were found by someone looking at the
screen and noticing. That found real bugs, and it found them one at a time, in
the order a human happened to look. This document is the other way round.

**The reference is CSS, and CSS is enumerable.** Every animated property on the
combat surface is a declaration in `src/styles.css` with a selector, a duration,
an easing curve and — for `animation` — a `@keyframes` body. There are a fixed
number of them. They can all be extracted mechanically, and each one is then a
single yes/no question for the port: *does it do this, with these numbers?*

Extraction, from `~/Coding/roguecardv2-benchmark` at `6e06911`:

```
src/styles.css   1297 rules · 45 transition · 108 animation · 70 @keyframes
combat surface   78 declarations, of which 67 are live
                 (the other 11 are prefers-reduced-motion overrides)
```

Sixty-two of the live ones fall on the combat screen proper; five belong to
reward, shop and aspect screens and are out of scope here.

## The result

| verdict | rows | |
|---|--:|---|
| **MATCH** | 39 | the port does this, with these numbers |
| **DIVERGES** | 9 | the port does something, with different numbers |
| **DIVERGES (documented)** | 3 | different on purpose, and the port says why |
| **ABSENT** | 0 | the port does not do this at all |
| **N/A** | 11 | the rule never fires in the reference, or drives a renderer the port does not use |
| **UNRESOLVED** | 0 | the audit answered a different question; needs a second look |

**ABSENT reached zero on 2026-07-31** — every liveable rule is either matched,
deliberately diverged with its reasons written down, or recorded dead with grep
evidence (see the P2.6 record at the end). The remaining nine DIVERGES are each
a judged trade, not a gap; the counts above are recomputed from the table, not
carried forward.

**UNRESOLVED reached zero on 2026-08-02** — row 505 was the last one, and it
closed N/A rather than as a defect: the half that looked like a gap turns out to
be a rule the reference never fires. Every row now carries an answer.

The shape of it is the same base rate this port has shown everywhere else: it is
precise where it was handed a number and thin where it had to notice that a
number existed. Geometry was 16/16 because someone went looking for boxes.
Nobody had gone looking for durations.

## What was measured, and by whom

The extraction is mechanical and reproducible. The port-side verdicts came from
five parallel audits, each required to quote the port's literal code and give
`file:line` — a verdict with no quoted evidence was rejected. Rows marked ✱ below
are ones the assembling session re-checked by hand, either because the verdict
looked wrong or because the row mattered enough to confirm.

One audit verdict was **wrong and was corrected**: `.stage-breath` (696) was
reported ABSENT. It is N/A. `styles.css:719` — `.stage-ledge, .stage-breath {
opacity: 0; animation: none; }` — sits at brace depth 0, so it always applies and
the reference never shows the animation at all. This is the same trap that has
already cost this project once (`docs/wrong-reference-audit.md`): a declaration
existing is not evidence that it renders.

## The table

### Card and hand

| css | selector | reference | port | |
|---|---|---|---|:-:|
| 505 | `.card-inner` | box-shadow .2s, transform .12s ease-out | transform half never fires — `.tilting` has no writer; box-shadow half is row 632 (closed 2026-08-02) | N/A ✱ |
| 592 | `.card.r-rare .card-inner::after` | `shine` 4.5s ease-in-out ∞ | canvas shader over the slab, TIME-driven, 62/92 marks (closed 2026-07-31) | MATCH |
| 599 | `.card-inner::before` | opacity .25s | `LAMP_FADE 0.25` on a shader hover, not the pane's opacity | DIVERGES |
| 610 | `.card.nope, .lantern-btn.nope` | `nope` .32s ease — ±7px, ±1.5° | `Motion.NOPE_*` shared by card and lantern, CSS ease per interval (closed 2026-07-31) | MATCH |
| 619 | `.hand-zone .card` | transform .28s cb(.25,.9,.3,1.2), filter .2s, opacity .12s | transform only — and see below | DIVERGES ✱ |
| 629 | `.hand-zone .card.dragging` | `transition: none` | `_kill_pose()` on drag | MATCH ✱ |
| 632 | `.hand-zone .card .card-inner` | box-shadow .2s | the will-burn glow glides the shadow .2s; other shadow states still write directly | DIVERGES |
| 633 | `.hand-zone .card .card-lift` | transform .28s cb(.25,.9,.3,1.2) | `POSE_TIME 0.28`, `POSE_EASE [.25,.9,.3,1.2]` | MATCH ✱ |
| 642 | `.card.draw-in .card-lift` | `drawReveal` .24s cb(.2,.8,.3,1.05) | variable 0.16–0.28s cubic ease-out | DIVERGES |
| 649 | `.card.played-up` | transform + opacity .3s ease-in, −240px, ×0.72 | the port flies the card to the discard pile instead | DIVERGES |
| 650 | `.card.exhausting` | .5s, −140px, ×0.6, 8°, brightness 2.4 blur 2px | the ash flight wears the blaze — ×0.6, 8°, hot lift; it flies to the pile instead of −140px, the port's own pile language (closed 2026-07-31) | DIVERGES (documented) |

### Enemy states

| css | selector | reference | port | |
|---|---|---|---|:-:|
| 102 | `.enemy.doomed .enemy-art` | `doomTremble` .09s linear ∞ | `DOOM_PERIOD 0.09`, same 5 offsets, same X/Y | MATCH |
| 738 | `.enemy` | filter .2s, transform .25s | structural: every state change here is an explicit tween with its own clock (see the P2.6 record) | N/A |
| 788 | `.enemy.hurt .enemy-art` | `hurtFlash` .3s — 30% brightness 2.6 +7px, 60% −5px | `HIT_TIME 0.3`, `FLARE_RISE 0.09`, ±7/−5px | MATCH |
| 790 | `.enemy.dying` | `dissolve` .85s ease-in forwards | superseded by the real 3D death rite (§1.8 of the actor checklist) — the deliberate departure | DIVERGES (documented) |
| 971 | `.cracks .crack` | `crackIn` .2s ease-out | propagation is speed-based (`CRACK_SPEED 2.6`), duration varies | DIVERGES |
| 974 | `.enemy.igniting .vessel-fire` | `vesselFire` .32s cb(.3,.7,.3,1) | one `set_ignite` cubic tween drives everything | DIVERGES |
| 977 | `.enemy.igniting .cracks` | `crackBlaze` .32s ease-out | same single tween | DIVERGES |
| 980 | `.enemy.igniting .enemy-art` | `vesselHeat` .32s ease-out | same single tween, linear emission ramp | DIVERGES |
| 1062 | `.enemy.reseaming .enemy-art` | `reseam` .7s ease-out, 30% brightness 1.55 sat .55 | `RESEAM_MS .7`, `RESEAM_AT .3`, 1.55 / 0.55 | MATCH |
| 1238 | `.enemy.targetable .enemy-art` | `targetGlow` 1s ease-in-out ∞ | `css_pulse` 6→18px / 0.5→0.9 lit on the rim, 1s ∞ (closed 2026-07-31) | MATCH |
| 1239 | `.enemy.targetable:hover` | `animation: none`, static brighter glow | hover kills the pulse: solid 22px, brightness 1.25 (closed 2026-07-31) | MATCH |

### Chrome — HP, chips, facets, lantern

| css | selector | reference | port | |
|---|---|---|---|:-:|
| 182 | `.hud-hpbar > div` | width **.4s** cb(.3,1,.4,1) | `HP_BAR_TIME 0.4` / `HP_EASE [.3,1,.4,1]` via `_glide_hp` | MATCH |
| 834 | `.hpbar > .fill` | width **.35s** cb(.3,1,.4,1) | `HP_GLIDE 0.35` on `Motion.HP_FILL` (closed 2026-07-31) | MATCH |
| 835 | `.hpbar > .ghost` | width .9s **ease** delay .25s | same timings on `Motion.CSS_EASE` (closed 2026-07-31) | MATCH |
| 890 | `.schip.pop` | `chipPop` .35s ease-out | dead rule — no writer (P2.6 record) | N/A |
| 907 | `.intent.telegraph` | `teleFlash` .5s ×2 — scale 1.22, brightness 1.8, glow | one linear clock, css_pulse per iteration, event-only 10px glow over the resting halo (closed 2026-07-31) | MATCH |
| 938 | `.intent.pop` | `chipPop` .4s ease-out | dead rule — no writer (P2.6 record) | N/A |
| 959 | `.hpbar > .pv.show` | `pvPulse` .9s ease-in-out ∞, opacity → .4 | `PREVIEW_PULSE .9`, `PREVIEW_DIP .4`, same easing | MATCH |
| 988 | `.facet-row .pip` | background/box-shadow/filter .2s | per-pip .2s crossfade, intact pane fades under the overlay (closed 2026-07-31) | MATCH |
| 1030 | `.facet-row .pip.willchip` | `pvPulse` .9s ∞ | dead for raster pips — `animation: none` at :1035 (P2.6 record) | N/A |
| 1035 | `…willchip:has(.facet-img)` | `animation: none` | no animation on will-state | MATCH |
| 1058 | `.facet-row.pop` | `chipPop` .4s ease-out | 1.35 at 0.16s, back over 0.24s | MATCH |
| 1068 | `.lantern-btn` | filter .25s, transform .25s | the unlit dim glides .25s on CSS ease (closed 2026-07-31) | MATCH |
| 1106 | `.lantern-btn .lbp` | background/box-shadow .25s | per-pip .25s crossfade on the ring (closed 2026-07-31) | MATCH |
| 1115 | `.lantern-btn.pop` | `chipPop` .4s ease-out | `_keyframe_pop(_lantern, 1.35, 0, 0.4)` | MATCH |
| 1116 | `.lantern-btn.ready` | `artReady` 1.6s ease-in-out ∞ | css_pulse 1.6s — brightness 1.22, halo swell; shared clock with the END seal (closed 2026-07-31) | MATCH |
| 1123 | `.lantern-btn.kindle-target` | `kindleCall` 1.1s ease-in-out ∞ | css_pulse 1.1s — brightness 1.2, 1.07 swell, wide halo, lit while a burnable card is in the air (closed 2026-07-31) | MATCH |

### Idle and creature motion

The reference has two body renderers. `.enemy-svg` is the inline-SVG creature and
`.enemy-sprite` is the raster one. This port paints rasters in 3D, so the SVG
rules do not apply to it — those rows are N/A, not defects.

| css | selector | reference | port | |
|---|---|---|---|:-:|
| 1600 | `.enemy-svg .breathe` | `breathe` 3.4s | SVG path unused; breathing is a vertex shader | N/A |
| 1606 | `.enemy-art svg` | transform .9s ease | SVG path unused | N/A |
| 1609 | `.enemy-svg .hover-float` | `hoverFloat` 3s | SVG path unused | N/A |
| 1612 | `.enemy-sprite.idle-wisp` | `idleFloat` 3.1s, 16px | `KIND_FLOAT_PX` 16.0 + `KIND_IDLE_PERIOD` 3.1 | MATCH |
| 1613 | `.enemy-sprite.idle-eye` | `idleFloat` 3.4s, 18px | `(18.0, 3.4)` | MATCH |
| 1614 | `…idle-siren, …idle-shade` | `idleFloat` 3.6s, 12px | `(12.0, 3.6)` both | MATCH |
| 1615 | `.enemy-sprite.idle-plant` | `idleFloat` 3.8s, 9px | `(9.0, 3.8)` | MATCH |
| 1616 | `.enemy-sprite.idle-slime` | `idleSlime` 4.2s, 3 keyframes | `SLIME_AT/_Y/_SX` — translateY 0/−4/+2, scaleX 1/1.04/.97 at 0/33/66%, 4.2s | MATCH |
| 1617 | `.enemy-sprite.idle-serpent` | `idleSway` 3.5s, 5px + 1.8° | `SWAY_X 5.0`, `SWAY_DEG 1.8`, 3.5s | MATCH |
| 1618 | `…idle-beast` and five more | `idleBreathe` 3.6s, scaleY 1.025 | `BREATHE_SY 1.025`, 3.6s, on the same six kinds | MATCH |
| 1639 | `.enemy-svg .eye` | `eyeGlow` 2.6s | SVG path unused | N/A |

The four `idleFloat` rows are the strongest MATCH in the whole census: amplitude
and period agree exactly, creature for creature.

**Amended 2026-07-27.** Rows 1616-1618 were graded DIVERGES (documented) here, on
the reading that the port had deliberately replaced a transform keyframe with a
vertex deformation — *"one rigid card being wobbled, which is a different animal
from a body that BENDS"*. That reading was wrong about the reference, which runs
**both** layers at once: the WebGL plane tracks the CSS box every frame
(`src/styles.css:1611`), so a vertex deformation there is *additional* to
`idleSlime`, not a substitute for it. `df3cc64` built all three at the source's
own amplitudes and periods, composed onto the vessel alongside the mesh layer, and
the rows are now MATCH. The port's vertex deform was never the disagreement.

Two cautions this section earned the hard way. The `idleFloat` verdicts above are
correct about the shipping screen, but they were reached by reading a port-side
constant — one only ever resolved through `set_profile()`, which the enemy lab did
not call. So on the only surface anyone would have used to *watch* a floater
float, the amplitude was zero and nothing floated: the census's own strongest
MATCH was, in practice, unobservable. That is this document's fourth honest limit
biting, and the precondition it assumes is written up in
[`drive-the-lab-the-way-the-game-drives-it.md`](solutions/tooling-decisions/drive-the-lab-the-way-the-game-drives-it.md).
Second, `moteDrift` (`src/styles.css:1635`) and its `.idle-motes` carrier have no
row in this census at all — the enumeration missed them. They were built in
`df3cc64`; the row is still owed.

### Stage, entrance and buttons

| css | selector | reference | port | |
|---|---|---|---|:-:|
| 94 | `#lantern.gutter, .stage-dim.gutter` | `gutter` 1.9s ∞, 5 opacity stops | same period, same 6 offsets, same values | MATCH |
| 696 | `.stage-breath` | `breath` 7s alternate ∞ | never fires in the reference — see 719 | N/A ✱ |
| 719 | `.stage-ledge, .stage-breath` | `opacity: 0; animation: none` | off, and the port says why | DIVERGES (documented) |
| 725 | `.combat-screen.intro .player-zone` | `heroIn` .55s cb(.2,.75,.3,1), −70px | `_enter(_hero, -70.0, …)`, `Motion.ENTER`, 0.55 | MATCH |
| 726 | `.combat-screen.intro .enemy` | `enemyIn` .55s, +90px | `_enter(view, 90.0, …)` | MATCH |
| 727 | `.combat-screen.intro` chrome | `chromeIn` .5s **delay .4s**, +44px | `tween_interval(0.4)`, 0.5s, 44px | MATCH |
| 1282 | `.energy-orb.pop` | `chipPop` .35s ease-out | `_keyframe_pop(_energy_orb, 1.35, 0, 0.35)` | MATCH |
| 1333 | `.end-turn` | transform .15s, filter .15s | hover glides −1px / brightness 1.08 over .15s on CSS ease (closed 2026-07-31) | MATCH |
| 1352 | `.end-turn.ready` | `artReady` 1.6s ease-in-out ∞ | the seal's halo breathes on the lantern's own clock; gated off while locked (closed 2026-07-31) | MATCH |
| 1393 | `.end-turn.enemy-phase` | opacity .45, no pointer events | `modulate.a = 0.45`, `MOUSE_FILTER_IGNORE` | MATCH |
| 1395 | `.pile-btn` | transform .15s, filter .15s | hover glides −3px / brightness 1.08 over .15s (closed 2026-07-31) | MATCH |
| 1449 | `.pile-btn.pile-bump` | `pileBump` .28s ease-out, −4px ×1.05 | `_keyframe_pop(p.stack, 1.05, -4.0, 0.28)` | MATCH |
| 1802 | `.ember` | `emberRise` 4s linear ∞ | a run-end screen dressing, not combat — P3.4's build target (P2.6 record) | N/A |

## What to fix first

Ranked by how often a player sees it, not by how easy it is.

1. **`.hpbar > .fill` (834) and `.hud-hpbar > div` (182)** — ~~both bars snap~~
   closed 2026-07-31: both glide on their own durations over `Motion.HP_FILL`.
2. **`.intent.pop` (938) and `.schip.pop` (890)** — re-judged: both are DEAD
   rules with no writer (see the P2.6 record); nothing to wire.
3. **`.end-turn` and `.pile-btn` .15s (1333, 1395)** — ~~respond instantly~~
   closed 2026-07-31: both glide on hover.
4. **`.lantern-btn.ready` / `.end-turn.ready` `artReady` (1116, 1352)** — ~~do
   not beacon~~ closed 2026-07-31: both breathe on one shared clock.
5. **`.enemy.targetable` `targetGlow` (1238)** — ~~a targetable foe is lit but
   does not pulse~~ closed 2026-07-31: the pulse and the hover stillness are
   both live, and every legal target lights while a single-target card is
   armed.

Items 1–4 are all small, and two of them are calling a function the port already
has. That is what a census buys — it separates *twenty-two missing things* from
*twenty-two hard things*, and they are not the same list.

### A correction to this list, and what it turned up

Row 619's `filter .2s` was first ranked second here, as *"the playability
grey-out snaps"*. That was wrong, and tracing which class actually uses the
transition is what showed it:

- The grey-out is `.card.unplayable-now .card-inner { filter: saturate(0.35)
  brightness(0.7) }` (609) — on `.card-inner`, whose own transition is
  `box-shadow 0.2s` (632) with **no filter**. So the grey-out is instant in the
  reference too, and the port writing `modulate` straight is correct.
- `filter .2s` on `.hand-zone .card` covers exactly one class: `.will-burn`
  (1125), `sepia(0.35) saturate(1.45) brightness(1.08)` — the kindle preview.
- `opacity .12s` covers `.draw-pending` (640), which the port answers with a
  flight instead of a fade.

Which leaves a bigger finding than the one it replaced: **the port has no
`.will-burn` tint at all.** `kindle_mode` exists in `hand_view.gd` and nothing
tints the cards it would burn. There is no point transitioning a filter that is
never applied, so 619's filter half is blocked behind a missing appearance, not
a missing animation.

The general lesson, and the second one this census has produced: **a transition
is only worth what the classes that trigger it are worth.** Ranking by the
transition alone ranked a no-op second.

## Reproducing this

The extractor is a throwaway; the method is not. Strip comments from
`src/styles.css` (keeping newline counts so line numbers stay true), walk every
`selector { flat body }`, pull `animation:` and `transition:`, resolve each
animation name against the `@keyframes` bodies, and record whether the rule sits
inside a `prefers-reduced-motion` block. Then filter selectors to the combat
surface.

Two rules learned assembling it:

- **Check the brace depth of every override.** A later top-level rule that says
  `animation: none` silently kills an earlier one, and an audit that reads only
  the first declaration will report a defect where the reference shows nothing.
- **A `transition` on element X is not answered by a tween on element Y.** Row
  505 was reopened precisely because `.card-inner` and the hand seat are two
  different elements that both animate `transform`. Asking the question about
  the right element then answered it in one grep — the rule is dead (see the
  P2.6 record). The lesson survives its row: the first audit's verdict was
  reached by looking at the wrong element, and it would have been wrong even if
  the number had happened to agree.

## Not covered here

This is motion only. Three surfaces remain unaudited:

- **Static appearance** — colour, size, shadow, border, font. Enumerable the same
  way, through `getComputedStyle` on the live page. A first sample already
  needs doing. (An earlier draft claimed `.intent` diverged at 34px against the
  reference's 30. It does not — the chip is 30. What measured 34 was the crown
  ROW, which adds a 4px separation to an empty status row. The static pass is
  still owed; that particular finding was mis-attributed and is withdrawn.)
- **Canvas and WebGL** — `vfx.js`, `mesh.js` and the `drain.js` timings are not
  CSS and have to be read from source.
- **Whether the port's MATCHes look right on screen.** A number can agree and
  still be attached to the wrong thing.

## Dead rules and non-items — the P2.6 record (2026-07-31, extended 2026-08-02)

Four rules the stylesheet declares that nothing in the shipping build ever
fires, each verified by grepping for a class writer at `6e06911`. They are
DECLINED, not ported:

- **`.intent.pop`** (`src/styles.css:938`) — `chipPop` on the telegraph chip.
  No `classList` write ever adds `pop` to an intent element; the only `pop`
  writers are the facet row (`src/ui/drain.js:287`), the lantern
  (`src/ui/drain.js:374`) and the energy orb (`src/ui/drain.js:662`).
- **`.schip.pop`** (`src/styles.css:890-891`) — already recorded at §3.4:
  nothing adds the class.
- **`.facet-row .pip.willchip` `pvPulse`** (`src/styles.css:1030`) — overridden
  by `animation: none` for pips carrying a raster face (`src/styles.css:1035`), and every pip
  in the game carries one.
- **`.card.tilting .card-inner`** (`src/styles.css:520`) — the 3D cursor tilt,
  and with it the `transform .12s ease-out` half of row 505. `grep -rn tilting
  src/` returns exactly two hits at `6e06911`, both in the stylesheet: the
  comment at `src/styles.css:515` and the selector at `src/styles.css:520`. No
  code adds the class, and the card's class string is built from card type and
  rarity only (`src/ui/tooltip.js:103`), so no dynamic path can produce it
  either. `src/styles.css:520` is the only rule anywhere that sets `transform`
  on `.card-inner`, so `transform: none` (`src/styles.css:516`) holds for the
  whole life of every card and the transition (`src/styles.css:517`) has nothing
  to interpolate. `src/ui/tooltip.js:126-127` does write `--rx`/`--ry` on
  mousemove, which is what makes this rule read live at a glance — but the only
  consumer of those variables is the selector that never matches. The
  reference's own comment at `src/styles.css:513-515` says why the tilt was
  gated behind a class in the first place (idle `rotateX(0)` builds a
  perspective layer that Chromium soft-samples at non-integer stage scales); the
  gate went in and the class never followed.

  **This one is not a decline.** The port tilts — `MAX_TILT 7.0` degrees on a
  spring (`presentation/combat/card_view.gd:177`) — so the port shows a motion
  the reference does not. That is the deliberate 3D departure argued at
  `presentation/combat/card_view.gd:145-161`, not a parity defect in either
  direction. Row 505 is graded N/A because the rule it cites is dead, and the
  port's tilt is answerable to §1 of the visual direction, not to this row.

Three candidates from the same sweep that are NOT dead, recorded so the list
does not grow back by rumour:

- **`.enemy { transition: filter .2s, transform .25s }`**
  (`src/styles.css:738`) — live, but structural here: the port drives those
  channels through explicit tweens with their own clocks, so a blanket
  smoothing layer has nothing left to smooth.
- **`dissolve`** (`src/styles.css:790-791`) — live via `.dying`
  (`src/ui/drain.js:582`); superseded in this port by the real 3D death rite
  (§1.8 KEEP), which is the deliberate departure, not an omission.
- **`.ember` / `.embers`** (`src/styles.css:1801-1812`) — live on the run-end
  screen; it is P3.4's build target rather than a combat census item.
