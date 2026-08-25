---
title: "A scaled Control shrinks its hit area with its picture — and 44pt is a floor, not a preference"
date: 2026-07-30
last_refreshed: 2026-08-25
category: ui-bugs
module: presentation/map
problem_type: ui_bug
component: frontend_stimulus
severity: high
symptoms:
  - "At discovery, waystones on a phone were 36x45 stage px; held sideways, 21x27"
  - "Every stage shape passed its layout gate — nothing overflowed, nothing overlapped"
  - "The defect is invisible in a screenshot and invisible in a resolved-value table"
root_cause: wrong_api
resolution_type: code_fix
related_components:
  - documentation
tags: [godot, godot-4-7, control, scale, touch-target, accessibility, mobile, stage-shape, hig, material]
---

# A scaled Control shrinks its hit area with its picture — and 44pt is a floor, not a preference

## Problem

Making the world map follow the stage shape meant scaling every waystone down so
fifteen rows fit a phone. `Control.scale` scales the whole node — which is the
point, and is also the bug: **input picking uses the scaled rect**, so shrinking
the picture shrank the target by exactly the same factor.

## Symptoms

- At discovery, `GlassWaystone` was 120x150. At the trail scales the book then
  authored, the target a finger had to find was:

  | shape | trail scale | target | verdict |
  |---|---|---|---|
  | pad-landscape | 0.36 | 43.2 x 54.0 | mouse — fine |
  | phone-portrait | 0.30 | **36.0 x 45.0** | under 44pt |
  | phone-landscape | 0.18 | **21.6 x 27.0** | half the floor |

  The picture has since been re-authored at 104x104. After landscape-only,
  shipping trail scale is 0.92 base / 0.58 on phone-landscape; phone-portrait
  is retired. `trail/touch = 44` on phone-landscape still adds no padding at
  that scale. `set_touch_min` remains the defensive authoring seam: a future
  smaller scale grows the hit rect without requiring the picture to grow
  with it. The discovery table above is the 2026-07 incident, not the live
  inventory.

- **Every layout gate passed.** Nothing overflowed, nothing overlapped, the
  identity capture was pixel-identical. A composition can be geometrically
  perfect and still be unusable, because "can this be touched" is not a question
  about where things are.
- Apple's Human Interface Guidelines and Android's Material guidance both set
  44pt / 48dp as a minimum. On this port a phone-portrait stage px is
  approximately a point, so the table above reads directly against that floor.

## What Didn't Work

**Raising the trail scale until the stones are big enough.** It is the obvious
move and it is wrong twice: at phone-landscape the stones would have to more than
double, which puts them back into the row overlap the scale was chosen to avoid;
and it treats a touch requirement as an art-direction knob, so the next person to
tune the composition silently reintroduces the bug.

**A second Control per stone to catch input.** Correct, and 105 extra nodes on
this screen — plus a second thing that can drift out of alignment with the first.
See [Web ports carry DOM node-per-layer thinking into
Godot](../design-patterns/dom-node-per-layer-in-godot.md): interactive nodes are
that rule's carve-out, so this would not have violated it. It is simply worse.

## Solution

**Grow the hit rect around the drawing, and leave the drawing alone.**

This is free here for one specific reason worth checking before copying it:
`GlassWaystone._draw()` measures from its own constants (`WIDTH`, `EMBLEM_H`),
**not** from `size`. So the rect can change without the picture knowing.

```gdscript
func set_touch_min(min_px: float, draw_scale: float) -> void:
    var base: Vector2 = Vector2(WIDTH, EMBLEM_H + CAPTION_H)
    var want: Vector2 = Vector2.ONE * (min_px / maxf(0.01, draw_scale))
    var pad: Vector2 = ((want - base) * 0.5).max(Vector2.ZERO)
    if pad.is_equal_approx(_pad):
        return
    _caption.offset_top = _pad.y + EMBLEM_H - 2 + (pad.y - _pad.y)
    _caption.offset_bottom = _caption.offset_top + CAPTION_H + 2
    _pad = pad
    size = base + pad * 2.0
    _seat_art()
    queue_redraw()
```

`_draw` then measures from `_pad + WIDTH * 0.5` instead of `WIDTH * 0.5`, which
puts the picture back in the middle of the bigger rect. The children that
*do* read the rect — the caption's centring box, and the frame/glyph art
re-centred by `_seat_art()` — are reseated against the same pad.
`WorldMapScreen` seats each stone by its centre, so nothing moves.

The minimum is authored, not hardcoded: `trail/touch` in the layout book,
defaulting to **0** so the shapes a mouse points at are untouched, and 44 on the
two phone shapes.

Verified by capture: `pad-landscape` came back **pixel-identical** to two of five
runs of the same build, and inside the 442px noise band of the other three.

## Why This Works

`Control` input picking tests the node's rect after its transform. `_has_point`
can only *reject* points inside that rect — it cannot accept points outside it —
so the rect is the only lever. Growing it is therefore the whole solution, and
the only question left is whether the picture follows the rect. Here it does not,
because the drawing was written against constants.

## Prevention

- **When a screen gains a scale dimension, audit the touch targets in the same
  pass.** Anything multiplied by a shrink factor is a candidate, and the identity
  shape will never show it: at scale 1 every target is the size it was designed
  at. Same blind spot as [Scaling a Control does not move its
  centre](scaling-a-control-does-not-move-its-centre.md), from the other side.
- **Author the minimum, do not bake it.** A hardcoded 44 in the screen is a
  number the next composition pass will quietly invalidate. In the book it is a
  field with a default of 0, so a shape that does not need it pays nothing and a
  shape that does states it.
- **Before growing a rect to fix input, check whether `_draw` reads `size`.** If
  it does, this trick moves the picture and you want the extra node instead.
- **A layout gate is not a usability gate.** Overflow checks, edge bindings and
  pixel diffs all passed here. Add the question "can a finger hit this?" to the
  per-shape checklist explicitly, because no geometric check implies it.

## Related Issues

- [Scaling a Control does not move its centre](scaling-a-control-does-not-move-its-centre.md)
  — the other `Control.scale` trap from the same lane, and the same lesson about
  the identity shape hiding anything proportional to `(1 - scale)`.
- [Web ports carry DOM node-per-layer thinking into Godot](../design-patterns/dom-node-per-layer-in-godot.md)
  — why the rejected fix (one hit node per stone) would have been legal under
  that rule and still worse.
- [Measure the running reference, not the tables it publishes](../conventions/measure-the-running-reference-not-its-tables.md)
  — the table of scales above is exactly the kind of published number that looks
  settled; what made this a finding was multiplying it out against a real device
  guideline.
