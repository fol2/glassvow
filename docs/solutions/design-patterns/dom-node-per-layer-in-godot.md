---
title: Web ports carry DOM node-per-layer thinking into Godot
date: 2026-07-26
category: design-patterns
module: presentation/combat
problem_type: design_pattern
component: frontend_stimulus
severity: medium
applies_when:
  - Porting a DOM/CSS interface to Godot Control nodes
  - A widget spawns one node per repeated visual element (stack layers, fan faces, tick marks, pips)
  - A refactor has to be proven to change nothing on screen
tags: [godot, web-port, presentation, draw-call, node-count, refactor-verification]
---

# Web ports carry DOM node-per-layer thinking into Godot

## Context

This project is a parallel port of a web build. Porting presentation faithfully
means copying measured CSS pixels — which is correct and is why the chrome
matches. But it also copies the DOM's *structure*, and one piece of that
structure is wrong in Godot.

In a browser, the only thing you can independently rotate, offset or fade is an
element. So the benchmark's card piles are drawn as a stack of `.pile-layer`
divs — one per visible card. The port mirrored that shape: one `TextureRect` per
face, created lazily, shown/hidden and rotated as the count moved.

At [hud_bar.gd:70](../../../presentation/combat/hud_bar.gd) the fan is capped at 16
faces, and there are three piles (draw, ashes, discard). So a deep board was up
to **48 Control nodes** — each with its own transform, style cache and layout
slot — all drawing the *identical* texture.

Nothing was broken. It rendered correctly. It was simply the browser's only
option imported into an engine that has better ones.

## Guidance

**When a ported widget repeats a node purely to repeat a picture, collapse it
into one `_draw()`.** A `Control` that overrides `_draw()` can emit any number of
transformed copies of a texture in a single node, and `draw_set_transform()`
gives per-copy rotation about an arbitrary pivot — which is the only thing the
node-per-layer version was buying.

The replacement in this repo is [`class Fan`](../../../presentation/combat/hud_bar.gd):

```gdscript
class Fan:
	extends Control
	var tex: Texture2D
	var face: float = 96.0
	var faces: int = 0

	func _draw() -> void:
		if tex == null or faces <= 0:
			return
		var pivot: Vector2 = Vector2(face * 0.5, size.y - face + face * 0.92)
		var origin: Vector2 = Vector2(0.0, size.y - face) - pivot
		for i: int in range(faces):
			# Qualified: an inner class does not see the outer one's statics.
			var a: float = HudBar._fan_angle(i, faces)
			draw_set_transform(pivot, deg_to_rad(a), Vector2.ONE)
			draw_texture_rect(tex, Rect2(origin, Vector2(face, face)), false)
```

Updating the pile stops allocating anything —
[hud_bar.gd:581](../../../presentation/combat/hud_bar.gd):

```gdscript
var faces: int = mini(maxi(n, 0), FAN_FACES)
p.stack.visible = faces > 0
p.stack.faces = faces
p.stack.queue_redraw()
```

**Then prove the swap changed nothing, with pixels rather than with confidence.**
Render every lab state before the refactor, render them again after, and diff:

```bash
for st in 0 1 2 3 4 5; do
  magick compare -metric AE /tmp/base/s$st.png /tmp/after/s$st.png null:
done
```

All six states returned `0` differing pixels. That number is what makes a
"pure implementation change" claim checkable instead of asserted.

Two Godot details this ran into:

- **`draw_set_transform(offset, rot, scale)` composes as translate-then-rotate.**
  To turn a rect about a pivot, pass the pivot as the offset and draw the rect at
  `rect_origin - pivot`. Getting this wrong shifts the fan rather than erroring.
- **An inner class cannot see the outer class's statics unqualified.**
  `_fan_angle(...)` inside `class Fan` fails to parse; `HudBar._fan_angle(...)`
  resolves ([hud_bar.gd:135](../../../presentation/combat/hud_bar.gd)).

## Why This Matters

A node in Godot is not free the way a div is cheap in a retained browser layout:
it participates in the scene tree, layout, input picking, theme resolution and
per-frame processing. Spending 48 of them to draw one texture 48 times is paying
engine machinery for something the renderer does directly.

The wider point is about *how* a port goes wrong. Parity work is judged on the
output looking identical, and this code passed that test from day one — the flaw
is invisible in a screenshot. So a port needs a second question alongside "does
it match?": **"is this shape a decision, or is it the source platform's only
option?"** Measured CSS pixels should survive the port. DOM structure usually
should not.

## When to Apply

- A ported widget creates N nodes that differ only by transform, tint or z-order
- Node count scales with a gameplay value (cards in a pile, stacks of a status,
  ticks on a gauge) rather than being fixed
- The nodes are non-interactive — they exist to be looked at, not clicked. Keep
  real nodes when each one needs its own input, focus, tooltip or animation
- You are about to claim a change is visually a no-op

Do **not** reach for `_draw()` when the repeated elements each need independent
hover/press behaviour, or when there are only two or three of them and the node
version is clearer.

## Examples

Before — one node per face, allocated as the count grows:

```gdscript
while p.faces.size() < faces:
	var f: TextureRect = _icon_rect(p.art, p.face)
	f.position = Vector2(0.0, p.stack.size.y - p.face)
	f.pivot_offset = Vector2(p.face * 0.5, p.face * 0.92)
	p.stack.add_child(f)
	p.faces.append(f)
for i: int in range(p.faces.size()):
	var f: TextureRect = p.faces[i]
	f.visible = i < faces
	if f.visible:
		f.rotation = deg_to_rad(_fan_angle(i, faces))
```

After — three nodes total, and a count change allocates nothing:

```gdscript
p.stack.faces = faces
p.stack.queue_redraw()
```

Same geometry (same 50%/92% pivot, same 5°-per-card / 30°-span rule from the
benchmark's `pile-chrome.js`), same pixels, 48 nodes → 3.

## Related

- `presentation/combat/hud_bar.gd` — the widget this was found in. The
  node-per-layer version and its `.pile-layer` lineage are in this file's git
  history on `main`; the `_draw()` version is in the working tree, uncommitted
  as of this writing.
- Verified on Godot 4.7.1.stable, the version pinned by this project's
  `CLAUDE.md`.
- The same question is worth asking of any other ported cluster that repeats a
  node per value — status stacks and facet pips are the obvious next candidates,
  and neither has been checked.
