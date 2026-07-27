---
title: Derive authored compensations instead of transcribing them when porting
date: 2026-07-26
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
the sprite squashed by a hand-authored CSS transform (`roguecardv2 src/styles.css:783`,
the reference checkout at `~/Coding/roguecardv2`):

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

1. **The authored values stop being per-creature.** Eight of the nine shadow knobs
   became derived. The ninth (opacity) survived, but as a *single global* rather than
   one value per creature. Be precise about what shrank: the Godot path still carries
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
   (`presentation/combat/enemy_view.gd:1923` (`_update_shadow`); the swing itself
   enters at `enemy_view.gd:3622` (`set_light_angle`)). No amount of tuning the CSS version
   could produce that — the derived version is not merely cheaper to maintain, it does
   something the original could not.

The inverse failure is just as real, and this same change surfaced an instance of it:
the port had transcribed the art box (square, sized from tier and scale) while dropping
the CSS rule that made it correct — `object-fit: contain` on the sprite itself
(`roguecardv2 src/styles.css:2430`, the `.raster-art` rule; note the reference file has
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
| `--sh-skew`, `--sh-x`, `--sh-y` | Key light direction — horizontal run per unit height |
| `--sh-sx`, `--sh-sy` | Ground-plane tilt (`GROUND_TILT_DEG = 78.0`, cos ≈ 0.21) × cast length |
| `--foot-ox`, `--foot-oy` | Scanned off the painting's own alpha: lowest opaque row is the contact point, its horizontal centroid is where weight sits (`enemy_view.gd:1868` (`_read_contact`)) |
| `--sh-blur` | Distance from the contact point — sharp at the feet, diffuse at the far end |
| `--sh-o` | **Kept — but promoted to a single global.** Opacity is taste, not geometry, and one taste serves every actor. The per-creature values are no longer read. |

Float behaviour arrives free: a creature whose lowest opaque pixel sits above the
ground line gets a smaller, fainter, softer shadow, because the alpha scan already
measured the gap.

### The art-direction clamp (the part that is not physics)

The honest projection at the key light's authored pitch of −38°
(`enemy_view.gd:1672` (in `_build_stage`)) gives a horizontal run of roughly 1.6 body heights. That is
geometrically correct and reads badly: in a side-on view a long cast makes the
creature look like it is hovering over its own shadow. The derivation is therefore
bounded back into a ground pool that still leans with the light
(`enemy_view.gd:1859-1860` (`CAST_MIN`)):

```gdscript
const CAST_MIN: float = 0.6
const CAST_MAX: float = 1.15
...
var run: float = clampf(1.0 / -l.y, CAST_MIN, CAST_MAX)
```

These two bounds are authored, and rightly so — they encode an artistic decision about
how a side-on battlefield should read, not an estimate of geometry. That is the whole
distinction: a constant that says *what we want* earns its place; a constant that says
*where the light would land* does not.

### Godot mechanic that made the derived shadow invisible

The projection is a **shear**, so it must be built as a non-orthonormal `Basis`. The
first attempt set the basis and then set `scale` separately, and the shadow vanished:

```gdscript
# WRONG — Node3D.scale is DERIVED from the basis. Assigning it re-orthonormalises
# and silently discards the shear.
_shadow.transform.basis = tilt * shear
_shadow.scale = Vector3(s, s, 1.0)

# RIGHT — fold the scale into the same basis (enemy_view.gd:1938-1942 (in _update_shadow))
var shear: Basis = Basis.IDENTITY
shear.x = Vector3(s, 0.0, 0.0)
shear.y = Vector3(clampf(l.x * run, -1.2, 1.2) * s, run * s, 0.0)
_shadow.transform.basis = Basis(Vector3.RIGHT, deg_to_rad(-GROUND_TILT_DEG)) * shear
```

There is no error and no warning — the shear is simply gone. Any Godot code that
builds a skew, squash, or projection matrix has to keep scale inside the basis.

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
- `assets/art/enemies/char-meta.json` — the ported per-character table. Its `shadow`
  entries are now vestigial for rendering and are retained only as reference data.
