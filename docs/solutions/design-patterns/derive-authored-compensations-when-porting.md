---
title: Derive authored compensations instead of transcribing them when porting
date: 2026-07-26
last_refreshed: 2026-07-29
category: design-patterns
module: presentation/combat
problem_type: design_pattern
component: rails_view
severity: medium
applies_when:
  - Porting a feature from a platform that lacked a capability the target platform has
  - A per-instance tuning table exists whose values all approximate one physical effect
  - Hand-authored constants must be re-authored for every new asset added
tags: [godot, porting, rendering, shadows, derived-parameters, web-reference, art-direction]
---

# Derive authored compensations instead of transcribing them when porting

## Context

Glassvow is a parallel port of a web deckbuilder into Godot 4.7. Parity is checked
against the frozen web reference, so the default instinct on any ported feature is
to transcribe what the reference does.

That instinct is right for design decisions and wrong for **compensations** — values
that exist only because the source platform could not compute them.

The cast shadow was the clearest case. The web reference draws it as a black copy of
the sprite squashed by a hand-authored CSS transform (`roguecardv2-benchmark src/styles.css:769`, the reference checkout at
`~/Coding/roguecardv2-benchmark` @ `6e06911`; this record used to cite
`~/Coding/roguecardv2`, which is 284 commits ahead and post-Pixi — the rule the
agent contract now states plainly):

```css
.cast-shadow {
  transform-origin: var(--foot-ox, 50%) var(--foot-oy, 100%);
  transform: translate(var(--sh-x, 0), var(--sh-y, 0))
             scale(var(--sh-sx, 1), var(--sh-sy, 0.24))
             skewX(var(--sh-skew, 0deg));
  opacity: var(--sh-o, 0.62); filter: blur(var(--sh-blur, 1.5px));
}
```

Nine knobs, authored per creature. Every one of them is a person estimating where a
light they do not have would throw the silhouette — CSS cannot project geometry, so
a human approximates the projection by hand, once per asset, forever.

Godot has a real directional light. Transcribing the nine knobs would have carried a
permanent authoring tax into an engine that can compute the answer.

## Guidance

When porting, sort each authored constant into one of two bins before writing any code:

- **Design** — someone decided this because they wanted it. Port it.
- **Compensation** — someone decided this because the platform could not work it out.
  Delete it and derive the value from the capability the new platform actually has.

The test is a question: *if the source platform had been able to compute this, would
the number still exist?* If no, it is a compensation.

Then apply the correction that keeps this from becoming naive physics-worship:

> **Derive the shape, then clamp for art direction.** Deriving replaces the
> *authoring*, not the *judgment*. A physically correct result can be artistically
> wrong, and the clamp that fixes it is real design, not leftover hand-tuning.

## Why This Matters

Three payoffs, in increasing order of importance:

1. **The authored values stop being per-creature.** Seven of the nine shadow knobs
   became derived. Opacity survived as a *single global* rather than one value per
   creature, and `dy` survived per creature — see the correction below for why that one
   is not derivable. Be precise about what shrank: the Godot path still carries
   roughly a dozen authored constants — ground tilt, cast bounds, shadow opacity, the
   blur ramp, the lift response. The win is not "fewer numbers," it is that the
   remaining numbers describe **intent once** instead of **geometry per asset**.
2. **New assets cost nothing.** A creature added tomorrow gets a correct shadow with
   no per-asset authoring. The two hero paintings had been sitting unused in the repo;
   the same change gave them actor treatment and neither needed shadow work. (Their
   nine-knob blocks were transcribed into the ported character table alongside the
   foes', and are simply never read — dead data, not tuning.)
3. **Behaviour the source could not have.** Because the shadow is a projection along
   the key light, swinging the key swings the shadow
   (`presentation/combat/enemy_view.gd:2246` (`_update_shadow`); the swing itself
   enters at `presentation/combat/enemy_view.gd:4128` (`set_light_angle`)). No amount of tuning the CSS version
   could produce that — the derived version is not merely cheaper to maintain, it does
   something the original could not.

The inverse failure is just as real, and this same change surfaced an instance of it:
the port had transcribed the art box (square, sized from tier and scale) while dropping
the CSS rule that made it correct — `object-fit: contain` on the sprite itself
(`roguecardv2-benchmark src/styles.css:2268`, the `.raster-art` rule; note the reference file has
a second, unrelated `object-fit: contain` inside the `.cast-shadow` block). Six of the
27 enemy paintings are not square — 21 are 1024×1024, and the other six are 1024 tall
but narrower — and all six were being stretched sideways across a square quad.
**Transcribing a value while dropping the behaviour that made it correct is the same
mistake in the other direction.**

## When to Apply

- A per-instance tuning table exists and every entry approximates the same physical
  effect (shadows, reflections, occlusion, parallax, depth sorting)
- The source platform is declarative/limited (CSS, a 2D canvas) and the target has a
  real simulation for the same thing (lights, physics, depth buffer)
- Adding one new asset currently requires hand-authoring numbers that describe
  geometry rather than intent

Do **not** apply it when the authored value encodes taste rather than geometry — a
colour, a timing curve, a silhouette exaggeration. Those are design; port them.

## Examples

### The mapping, knob by knob

| Web (authored per creature) | Godot (derived) |
| --- | --- |
| `--sh-skew`, `--sh-x` | Key light direction — horizontal run per unit height |
| `--sh-sx`, `--sh-sy` | Ground-plane tilt (`GROUND_TILT_DEG = 78.0`, cos ≈ 0.21) × cast length |
| `--foot-ox`, `--foot-oy` | Scanned off the painting's own alpha. Originally one point per creature — lowest opaque row, horizontal centroid of the band above it (`presentation/combat/enemy_view.gd:2064` (`_read_contact`)). Now the *origin* only: the contact is read per painting column, because one contact line cannot serve a creature standing on four feet at four heights. See [A flat billboard has one depth](../ui-bugs/flat-billboard-shadow-had-one-ground-line.md) |
| `--sh-blur` | Distance from the contact point — sharp at the feet, diffuse at the far end |
| `--sh-o` | **Kept — but promoted to a single global.** Opacity is taste, not geometry, and one taste serves every actor. The per-creature values are no longer read. |
| `--sh-y` (`shadow.dy`) | **Kept, per creature.** See the correction below: this is the one knob that says something the painting cannot. |

### Correction, 2026-07-27: a derived value is only as good as what it measures

This record used to end the table with a claim that was wrong, and wrong in the way
this pattern is most likely to fail:

> Float behaviour arrives free: a creature whose lowest opaque pixel sits above the
> ground line gets a smaller, fainter, softer shadow, because the alpha scan already
> measured the gap.

The scan was real, the projection was real, and the quantity was not a gap. Measured
across all 27 enemy paintings, the transparent margin below the lowest opaque row
matches the margin above it to a tenth of a percent on most of them — 10.0/10.0,
5.2/5.2, 13.0/13.0, 20.7/20.6. It is a uniform export border. The largest belongs to
`shellback`, a crab flat on the floor, at 20.7%; `voidWisp`, which is a wisp, has 4.3%.
So the response was not merely free, it was **inverted**: most float to the crab, almost
none to the wisp. It was also static — `_update_shadow` ran twice in an actor's life,
at build and at reset, while the benchmark resynchronises its copy every frame.

Two things follow, and they are the general lesson rather than a shadow detail:

- **Derivation moves the risk from the value to the measurement.** An authored number
  is wrong visibly; a derived one is wrong invisibly, because the derivation reads
  correct. Name what the scan measures (`_art_pad`, a framing border) rather than what
  you hope it means (lift).
- **A derive can be right and dead at the same time.** Nothing about the projection was
  incorrect. It was simply never asked again after the frame it was built on.

What this record cannot say from the derivation side is how the deadness was allowed
to persist for so long: no verification surface in the project could have shown a
shadow that never moved, and the audit that graded this entry compared constants.
That half is [Drive the lab the way the game drives it, and photograph loops as well
as beats](../tooling-decisions/drive-the-lab-the-way-the-game-drives-it.md).

**And one authored knob came back.** `shadow.dy` — carried in the benchmark by exactly
five creatures, `watcherEye` 24, `shade` 16, `voltEel` 13, `sporeling` 10, `voidWisp` 9,
which are exactly the floaters — says the thing the alpha cannot: *this painting is of
something already off the ground.* Contact point, lean, length and softening are all in
the image or the light. Resting height is in neither. It is read as a height and fed
through the same projection the live hover uses
(`presentation/combat/enemy_view.gd:2246` (`_update_shadow`)), so it buys a shadow that
is offset, smaller, fainter and softer rather than the straight-down shove CSS could
manage. One authored number doing the job eight were approximating is still the pattern
working — it is just not zero.

**Correction, 2026-07-27 (second): `dy` was doing half its job.** Feeding it through the
projection slides the cast sideways along the light's ground track, and that is only one
of the two things being airborne means. The other is that the ground is *lower* than the
silhouette's own bottom edge — which, for a creature painted already off the floor, is
not a contact at all. Until that was fixed the shadow sat pinned directly under the
hovering body and `watcherEye`'s hung off its own tassels. A sixth creature, `thornling`,
now carries a `dy` the benchmark does not give it; that one is a deliberate divergence,
recorded in the successor doc.

### The art-direction clamp (the part that is not physics)

The honest projection at the key light's authored pitch of −38°
(`presentation/combat/enemy_view.gd:1792` (in `_build_stage`)) gives a horizontal run of roughly 1.6 body
heights. That is
geometrically correct and reads badly: in a side-on view a long cast makes the
creature look like it is hovering over its own shadow. The derivation is therefore
bounded back into a ground pool that still leans with the light
(`presentation/combat/enemy_view.gd:2055-2056` (`CAST_MIN`)):

```gdscript
const CAST_MIN: float = 0.68
const CAST_MAX: float = 1.31
...
var run: float = clampf(1.0 / -l.y, CAST_MIN, CAST_MAX)
```

These two bounds are authored, and rightly so — they encode an artistic decision about
how a side-on battlefield should read, not an estimate of geometry. That is the whole
distinction: a constant that says *what we want* earns its place; a constant that says
*where the light would land* does not.

They read 0.6 / 1.15 when this doc was written. The look they encode has not changed;
the arithmetic underneath them has. Height used to be measured from the creature's
*lowest* contact, which overstates it for anything standing on higher ground, and moving
to a per-column ground line reduced measured height by a silhouette-weighted 12.0% across
the roster. The bounds were restated ×1.137 — 1/(1 − 0.120) — so the approved result
survived the correction. **This is the maintenance clause the rule above was missing: an
art-direction clamp is expressed in the units of a derived quantity, so correcting a
systematic error in that quantity silently changes what the clamp asks for.** Preserving
the judgement means restating the numbers; preserving the numbers would have changed the
look and left no record of why.

### Godot mechanic that made the derived shadow invisible

**Historical — the shadow no longer uses a `Basis` at all.** The Godot fact below is
still true and still worth carrying; the code that worked around it has been retired,
and the paragraph after the block says what replaced it.

The projection was built as a **shear**, which means a non-orthonormal `Basis`. The
first attempt set the basis and then set `scale` separately, and the shadow vanished:

```gdscript
# WRONG — Node3D.scale is DERIVED from the basis. Assigning it re-orthonormalises
# and silently discards the shear.
_shadow.transform.basis = tilt * shear
_shadow.scale = Vector3(s, s, 1.0)

# The workaround: fold the scale into the same basis.
var shear: Basis = Basis.IDENTITY
shear.x = Vector3(s, 0.0, 0.0)
shear.y = Vector3(clampf(l.x * run, -1.2, 1.2) * s, run * s, 0.0)
_shadow.transform.basis = Basis(Vector3.RIGHT, deg_to_rad(-GROUND_TILT_DEG)) * shear
```

There is no error and no warning — the shear is simply gone. Any Godot code that
builds a skew, squash, or projection matrix has to keep scale inside the basis.

The workaround is gone because the constraint it worked around turned out to be the
deeper problem: a `Basis` shears about exactly one origin, so a basis-projected shadow
can only ever have one contact line. The shear now lives in the shadow's vertex stage,
where it can run from each column's own contact — and with no basis in the picture there
is no shear left to lose. See
[A flat billboard has one depth](../ui-bugs/flat-billboard-shadow-had-one-ground-line.md).

## Related

- [Web ports carry DOM node-per-layer thinking into Godot](dom-node-per-layer-in-godot.md)
  — the same root cause in the *structural* dimension. That doc is about ported
  **shape** (one node per visual layer, because the DOM had no other way); this one is
  about ported **values**. Read together they are one principle: a port inherits the
  source's intent, not the source's workarounds.
- [Procedural glass reads off its edges, not its fill](procedural-glass-reads-off-its-edges.md)
  — the same move in the drawing layer, and in 2D: replace an authored appearance
  constant with a per-element term computed against a light that actually exists
  in the scene. Here it is the shadow's run from the key's pitch; there it is a
  shard edge's brightness from its own outward normal.
- `CONCEPTS.md` › **Benchmark** — states the governing rule this doc applies: the web
  build is authority for *what* the game does, never for *how* it had to achieve it.
- Implemented in commit `0c8ed59` (`feat(actors): the shadow is projected, not
  authored — and heroes are actors too`), reachable from `main`.
- `docs/commercial-game-delivery.md` — content-stability policy that makes a shrinking
  per-asset tuning table valuable rather than merely tidy.
- `assets/art/enemies/char-meta.json` — the ported per-character table. All of its
  `shadow` entries but `dy` are vestigial for rendering and are retained as reference
  data; `dy` is read as a resting height (`presentation/combat/enemy_view.gd:2670` (`_read_hover`)).
