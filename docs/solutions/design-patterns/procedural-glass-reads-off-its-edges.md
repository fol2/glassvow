---
title: Procedural glass reads off its edges, not its fill
last_refreshed: 2026-08-01
date: 2026-07-26
category: design-patterns
module: presentation/reward
problem_type: design_pattern
component: rails_view
severity: medium
applies_when:
  - Drawing a material procedurally in _draw rather than with a shader or painted art
  - A filled polygon with an outline is meant to read as glass, metal, or any lit solid
  - A hand-drawn scene contains a light source other elements are supposed to answer to
tags: [godot, procedural-rendering, canvas-item, glass, lighting, additive-blending, draw]
---

# Procedural glass reads off its edges, not its fill

## Context

The reward screen concept 「燼」 draws the enemy's shattered body procedurally —
polygons in `_draw`, no art, no viewport — deliberately mirroring `GlassGem`, the
fallback enemy avatar, which is also pure `_draw`. (Enemies normally render as
painted Actors; the gem survives as the fallback when a painting is missing, and
as the world map's emblem.)

Status note (2026-08-01): the reward's OWN drawing layer is being superseded by
a real-3D stage (`docs/reward-embers-3d-plan.md`, staged behind the reward lab
pending the owner's integration call) — that plan's premise is precisely that a
flat drawing cannot be a material. This lesson remains the standing contract
for glass that IS drawn in 2D — `GlassGem`, the map emblem, and any future
`_draw`-based pane.

The first pass drew each shard the obvious way: a filled polygon plus an outline.
It was rejected on sight; the note in the session was that the pieces read as
"floating triangles", "cut paper", and "brown". Six rounds of tuning colour,
alpha and scatter changed nothing that mattered, because none of those were the
problem.

The problem was a single optical fact the fill-plus-outline shape cannot express.
`GlassGem` has the same shape today — one uniform-width closed outline at
`presentation/combat/glass_gem.gd:59` (in `_draw`):

```gdscript
draw_polyline(outline, Color(rim.r, rim.g, rim.b, 0.85 * lit), 1.8)
```

That is fine there: the gem is a single small intact avatar read at a glance. It
stops being fine the moment the same approach is asked to carry a large broken
object the player is meant to look at.

## Guidance

**A cut edge is the brightest part of a piece of glass, and it is bright
unevenly.** A body is comparatively dark; the edge gathers light along its length
and throws it at the viewer, and how much it throws depends on which way that
edge faces. Draw the rim **per edge**, with width and heat set by that edge's
outward normal against a real light position in the scene
(`presentation/reward/reward_embers.gd:423-448` (in `_draw_shard`)):

```gdscript
var outward: Vector2 = edge.orthogonal().normalized()
if outward.dot(((a + b) * 0.5) - at) < 0.0:
    outward = -outward
var facing: float = maxf(0.0, outward.dot(dir))
var w: float = (1.0 + 5.6 * facing * (0.45 + 0.55 * near)) * (1.0 + flare * 1.7)
```

A uniform outline — any width, any brightness — is a vector shape. One term that
varies per edge is what gives a flat polygon a near side and a far side.

Three corollaries follow, and skipping any of them keeps the paper look:

1. **The rim goes white where it is hot.** A fracture's brightness is a *surface
   reflection*, not transmission, so it does not carry the glass's colour.
   Coloured glass with a coloured outline is a sticker
   (`reward_embers.gd:439-446` (in `_draw_shard`)).
2. **The body goes near-black.** Dark glass in a dark room is read off its edges
   and almost nothing else. A mid-toned body describes the piece twice and
   succeeds at neither — too dark to be a colour, too light to be a silhouette.
   That is precisely the brown-paper look (`reward_embers.gd:379-383` (in `_draw_shard`)).
3. **The inner glow is inset *and* pushed toward the light.** Centred, it reads
   as a shape with a hole in it; shifted, the bright region crowds the lit edge
   and the piece reads as something light enters from one side
   (`reward_embers.gd:413-419` (in `_draw_shard`)).

**The light has to actually exist in the scene**, or none of the above has an
argument to take. That imposes two more rules:

4. **Light and matter cannot share a canvas layer.** Light drawn with normal
   alpha can only ever pull the background toward its own colour — it becomes a
   stain, not a glow. It needs its own `CanvasItemMaterial` with
   `BLEND_MODE_ADD`, beneath the matter layer so solids can still occlude it
   (`reward_embers.gd:192-193` (in `_init`)).
5. **A light source must be somewhere you can see it lighting things.** Staged
   behind three opaque cards, the fire's hot core was the brightest thing on the
   screen and entirely invisible; only its dim outer throw showed past the edges.

## Why This Matters

The wrong instinct here is expensive because it is *plausible*. Fill-plus-outline
is what every vector drawing API nudges you toward, it is what the existing
`GlassGem` does, and when it looks wrong the symptoms ("flat", "muddy", "like
paper") all sound like colour problems. So the natural response is to tune
colour, alpha, saturation and scatter — none of which can fix a missing
directional term. That is a tuning loop with no exit, and this session spent six
screenshot rounds in it before naming the real cause.

Getting the edge term right also buys behaviour for free. Because every piece
computes its own direction and distance to one shared light position, pieces near
the fire are hot and pieces thrown clear are nearly cold with no extra authoring
— and re-colouring the light re-lights the whole scene coherently. In this
screen that is what lets one hue value produce a visibly different screen with no
second asset and no second code path.

This is also the 2D counterpart of a rule the project already holds for card
surfaces — see **Angle, not time** in `CONCEPTS.md`. Both say the same thing: a
material is a function of geometry against a light, not a set of tuned constants.

## When to Apply

Apply when drawing any lit solid procedurally in `_draw` — glass, metal, stone,
ice — especially when the object is large on screen or the player is meant to
study it.

Do **not** reach for this when the object is small, intact, and read at a glance;
`GlassGem` at avatar size is correctly served by a uniform outline, and per-edge
lighting there would be cost without benefit — the more so now that it renders
only as a fallback. The trigger is *size and
attention*, not the material.

The light-layer rules (4 and 5) apply more broadly than the edge rule: any
procedurally drawn glow in a Godot `CanvasItem` scene needs an additive layer,
whether or not anything else in the scene is lit by it.

## Examples

### Two failures worth recognising by sight

Both were hit in this session and both look like colour bugs:

- **A stack of concentric `draw_circle` calls bands.** Nine nested ellipses used
  to fake a radial falloff rendered as nine visible rings — a target, not a fire.
  Replaced with three cached `GradientTexture2D` radials nested into a hot core
  with a long throw (`reward_embers.gd:344-353` (in `_draw_bed`)). Cache them: rebuilt inside
  `_draw` they allocate on every frame of an animation.
- **A mid-toned body under a bright outline** reads as cardboard with a
  highlight. The fix is counter-intuitive — make the body *darker*, not more
  colourful.

### The shape of the fix

```gdscript
# before — a vector shape
draw_colored_polygon(pts, body_colour)
draw_polyline(closed, rim_colour, 1.8)

# after — a solid with a near side and a far side
draw_colored_polygon(pts, near_black_body)
draw_colored_polygon(core_inset_and_shifted_toward_light, glow)
for each edge:
    facing = outward_normal · direction_to_light
    draw_line(a, b, lerp(tone, white, facing), 1.0 + k * facing)
```

## Related

- `docs/solutions/conventions/per-recipe-shader-knobs.md` — the shader-side
  counterpart: tune one recipe's uniform, never the shared model.
- `docs/solutions/design-patterns/dom-node-per-layer-in-godot.md` — the other
  "the obvious construction is the wrong one" learning in this presentation area.
- [Derive authored compensations instead of transcribing them when porting](derive-authored-compensations-when-porting.md)
  — the same move one layer up, in 3D: an authored constant replaced by a term
  derived from the scene's own light. That doc also names the discipline this one
  relies on without stating it — derive the shape, then clamp for art direction,
  which is exactly what the coefficients above are doing.
- `CONCEPTS.md` → **Angle, not time**, **Vessel**, **Crack** — the project's
  existing glass vocabulary this screen draws on.
