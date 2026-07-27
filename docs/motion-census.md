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
| **MATCH** | 18 | the port does this, with these numbers |
| **DIVERGES** | 9 | the port does something, with different numbers |
| **DIVERGES (documented)** | 4 | different on purpose, and the port says why |
| **ABSENT** | 24 | the port does not do this at all |
| **N/A** | 6 | the rule never fires in the reference, or drives a renderer the port does not use |
| **UNRESOLVED** | 1 | the audit answered a different question; needs a second look |

**Twenty-four of sixty-two — 39% of the combat motion surface — has no
implementation.** Eighteen (29%) are verified to match. That is the size of the
gap, measured rather than estimated.

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
already cost this project once (`docs/solutions/` › source-existing-is-not-
rendering): a declaration existing is not evidence that it renders.

## The table

### Card and hand

| css | selector | reference | port | |
|---|---|---|---|:-:|
| 505 | `.card-inner` | box-shadow .2s, transform .12s ease-out | audit matched this against the hand-seat glide, which is a different element | UNRESOLVED |
| 592 | `.card.r-rare .card-inner::after` | `shine` 4.5s ease-in-out ∞ | nothing | ABSENT |
| 599 | `.card-inner::before` | opacity .25s | `LAMP_FADE 0.25` on a shader hover, not the pane's opacity | DIVERGES |
| 610 | `.card.nope, .lantern-btn.nope` | `nope` .32s ease — ±7px, ±1.5° | nothing | ABSENT |
| 619 | `.hand-zone .card` | transform .28s cb(.25,.9,.3,1.2), **filter .2s, opacity .12s** | transform only | DIVERGES ✱ |
| 629 | `.hand-zone .card.dragging` | `transition: none` | `_kill_pose()` on drag | MATCH ✱ |
| 632 | `.hand-zone .card .card-inner` | box-shadow .2s | shadow written directly | ABSENT |
| 633 | `.hand-zone .card .card-lift` | transform .28s cb(.25,.9,.3,1.2) | `POSE_TIME 0.28`, `POSE_EASE [.25,.9,.3,1.2]` | MATCH ✱ |
| 642 | `.card.draw-in .card-lift` | `drawReveal` .24s cb(.2,.8,.3,1.05) | variable 0.16–0.28s cubic ease-out | DIVERGES |
| 649 | `.card.played-up` | transform + opacity .3s ease-in, −240px, ×0.72 | the port flies the card to the discard pile instead | DIVERGES |
| 650 | `.card.exhausting` | .5s, −140px, ×0.6, 8°, brightness 2.4 blur 2px | nothing | ABSENT |

### Enemy states

| css | selector | reference | port | |
|---|---|---|---|:-:|
| 102 | `.enemy.doomed .enemy-art` | `doomTremble` .09s linear ∞ | `DOOM_PERIOD 0.09`, same 5 offsets, same X/Y | MATCH |
| 738 | `.enemy` | filter .2s, transform .25s | no blanket transition; each state hand-tweened | ABSENT |
| 788 | `.enemy.hurt .enemy-art` | `hurtFlash` .3s — 30% brightness 2.6 +7px, 60% −5px | `HIT_TIME 0.3`, `FLARE_RISE 0.09`, ±7/−5px | MATCH |
| 790 | `.enemy.dying` | `dissolve` .85s ease-in forwards | the body does not dissolve; the fracture is a separate layer | ABSENT |
| 971 | `.cracks .crack` | `crackIn` .2s ease-out | propagation is speed-based (`CRACK_SPEED 2.6`), duration varies | DIVERGES |
| 974 | `.enemy.igniting .vessel-fire` | `vesselFire` .32s cb(.3,.7,.3,1) | one `set_ignite` cubic tween drives everything | DIVERGES |
| 977 | `.enemy.igniting .cracks` | `crackBlaze` .32s ease-out | same single tween | DIVERGES |
| 980 | `.enemy.igniting .enemy-art` | `vesselHeat` .32s ease-out | same single tween, linear emission ramp | DIVERGES |
| 1062 | `.enemy.reseaming .enemy-art` | `reseam` .7s ease-out, 30% brightness 1.55 sat .55 | `RESEAM_MS .7`, `RESEAM_AT .3`, 1.55 / 0.55 | MATCH |
| 1238 | `.enemy.targetable .enemy-art` | `targetGlow` 1s ease-in-out ∞ | `target_lit` set to 1.0, no pulse | ABSENT |
| 1239 | `.enemy.targetable:hover` | `animation: none`, static brighter glow | no hover/non-hover distinction | ABSENT |

### Chrome — HP, chips, facets, lantern

| css | selector | reference | port | |
|---|---|---|---|:-:|
| 182 | `.hud-hpbar > div` | width **.4s** cb(.3,1,.4,1) | `_hp_fill.size.x = …` assigned | ABSENT |
| 834 | `.hpbar > .fill` | width **.35s** cb(.3,1,.4,1) | `_hp_bar.value = now` | ABSENT |
| 835 | `.hpbar > .ghost` | width .9s **ease** delay .25s | right timings, sine ease-in-out instead of CSS `ease` | DIVERGES |
| 890 | `.schip.pop` | `chipPop` .35s ease-out | status chips never pop | ABSENT |
| 907 | `.intent.telegraph` | `teleFlash` .5s ×2 — scale 1.22, brightness 1.8, glow | scale and brightness present, drop-shadow omitted | DIVERGES |
| 938 | `.intent.pop` | `chipPop` .4s ease-out | `IntentChip` has `telegraph()` only | ABSENT |
| 959 | `.hpbar > .pv.show` | `pvPulse` .9s ease-in-out ∞, opacity → .4 | `PREVIEW_PULSE .9`, `PREVIEW_DIP .4`, same easing | MATCH |
| 988 | `.facet-row .pip` | background/box-shadow/filter .2s | redraws immediately | ABSENT |
| 1030 | `.facet-row .pip.willchip` | `pvPulse` .9s ∞ | fixed dim tint, no pulse | ABSENT |
| 1035 | `…willchip:has(.facet-img)` | `animation: none` | no animation on will-state | MATCH |
| 1058 | `.facet-row.pop` | `chipPop` .4s ease-out | 1.35 at 0.16s, back over 0.24s | MATCH |
| 1068 | `.lantern-btn` | filter .25s, transform .25s | instant modulate | ABSENT |
| 1106 | `.lantern-btn .lbp` | background/box-shadow .25s | the port has no ember-pip ring at all | ABSENT |
| 1115 | `.lantern-btn.pop` | `chipPop` .4s ease-out | `_keyframe_pop(_lantern, 1.35, 0, 0.4)` | MATCH |
| 1116 | `.lantern-btn.ready` | `artReady` 1.6s ease-in-out ∞ | static modulate only | ABSENT |
| 1123 | `.lantern-btn.kindle-target` | `kindleCall` 1.1s ease-in-out ∞ | kindle is a separate toggle; no lantern pulse | ABSENT |

### Idle and creature motion

The reference has two body renderers. `.enemy-svg` is the inline-SVG creature and
`.enemy-sprite` is the raster one. This port paints rasters in 3D, so the SVG
rules do not apply to it — those rows are N/A, not defects.

| css | selector | reference | port | |
|---|---|---|---|:-:|
| 1600 | `.enemy-svg .breathe` | `breathe` 3.4s | SVG path unused; breathing is a vertex shader | N/A |
| 1606 | `.enemy-art svg` | transform .9s ease | SVG path unused | N/A |
| 1609 | `.enemy-svg .hover-float` | `hoverFloat` 3s | SVG path unused | N/A |
| 1612 | `.enemy-sprite.idle-wisp` | `idleFloat` 3.1s, 16px | `KIND_HOVER["wisp"] = (16.0, 3.1)` | MATCH |
| 1613 | `.enemy-sprite.idle-eye` | `idleFloat` 3.4s, 18px | `(18.0, 3.4)` | MATCH |
| 1614 | `…idle-siren, …idle-shade` | `idleFloat` 3.6s, 12px | `(12.0, 3.6)` both | MATCH |
| 1615 | `.enemy-sprite.idle-plant` | `idleFloat` 3.8s, 9px | `(9.0, 3.8)` | MATCH |
| 1616 | `.enemy-sprite.idle-slime` | `idleSlime` 4.2s, 3 keyframes | shader sine at 1.1 rad/s, per-kind weights | DIVERGES (documented) |
| 1617 | `.enemy-sprite.idle-serpent` | `idleSway` 3.5s, 5px + 1.8° | shader sine at 0.9 and 1.7 rad/s | DIVERGES (documented) |
| 1618 | `…idle-beast` and five more | `idleBreathe` 3.6s, scaleY 1.025 | chest-only shader breathing at 2.2 rad/s | DIVERGES (documented) |
| 1639 | `.enemy-svg .eye` | `eyeGlow` 2.6s | SVG path unused | N/A |

The four `idleFloat` rows are the strongest MATCH in the whole census: amplitude
and period agree exactly, creature for creature. The three DIVERGES are the port
deliberately replacing a transform keyframe with a vertex deformation, and it says
so at `enemy_view.gd` — *"one rigid card being wobbled, which is a different
animal from a body that BENDS"*. A body that bends cannot be a `scaleY`.

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
| 1333 | `.end-turn` | transform .15s, filter .15s | instant modulate on hover | ABSENT |
| 1352 | `.end-turn.ready` | `artReady` 1.6s ease-in-out ∞ | nothing | ABSENT |
| 1393 | `.end-turn.enemy-phase` | opacity .45, no pointer events | `modulate.a = 0.45`, `MOUSE_FILTER_IGNORE` | MATCH |
| 1395 | `.pile-btn` | transform .15s, filter .15s | no transition | ABSENT |
| 1449 | `.pile-btn.pile-bump` | `pileBump` .28s ease-out, −4px ×1.05 | `_keyframe_pop(p.stack, 1.05, -4.0, 0.28)` | MATCH |
| 1802 | `.ember` | `emberRise` 4s linear ∞ | embers are VFX particles, not a rising UI element | ABSENT |

## What to fix first

Ranked by how often a player sees it, not by how easy it is.

1. **`.hpbar > .fill` (834) and `.hud-hpbar > div` (182)** — HP is the most-watched
   number on the screen and both bars snap. 0.35s and 0.4s on the same
   `cb(.3, 1, .4, 1)`. The ghost rail already tweens beside them, so the fill
   jumping to its new width while the ghost glides is visible on every single hit.
2. **`.hand-zone .card` filter .2s / opacity .12s (619)** — the playability
   grey-out snaps. Every energy change flips it across the whole hand at once.
3. **`.end-turn` and `.pile-btn` .15s (1333, 1395)** — every button on the screen
   responds instantly instead of moving.
4. **`.lantern-btn.ready` / `.end-turn.ready` `artReady` (1116, 1352)** — the two
   "you can act now" beacons do not beacon.
5. **`.intent.pop` (938) and `.schip.pop` (890)** — `chipPop` is already
   implemented four times over for the lantern, energy orb, facet row and pile.
   These two just never got wired to it.
6. **`.enemy.targetable` `targetGlow` (1238)** — a targetable foe is lit but does
   not pulse, so nothing distinguishes "can be hit" from "is being aimed at".

Items 1–5 are all small: three of them are calling a function the port already
has. That is what a census buys — it separates *twenty-four missing things* from
*twenty-four hard things*, and they are not the same list.

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
  505 is UNRESOLVED precisely because `.card-inner` and the hand seat are two
  different elements that both animate `transform`.

## Not covered here

This is motion only. Three surfaces remain unaudited:

- **Static appearance** — colour, size, shadow, border, font. Enumerable the same
  way, through `getComputedStyle` on the live page. A first sample already
  disagrees with the port in at least one place: `.intent` is `height: 30px` in
  the reference and the port's chip measures 34.
- **Canvas and WebGL** — `vfx.js`, `mesh.js` and the `drain.js` timings are not
  CSS and have to be read from source.
- **Whether the port's MATCHes look right on screen.** A number can agree and
  still be attached to the wrong thing.
