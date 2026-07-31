---
title: "Scaling a Control does not move its centre — so half-size times scale is always wrong"
date: 2026-07-28
category: ui-bugs
module: presentation/combat
problem_type: ui_bug
component: frontend_stimulus
severity: medium
symptoms:
  - "A card dealt from a pile started roughly 28px right and 40px below the pile it was meant to leave, then lerped into place"
  - "The error grew as the card shrank, so it was invisible at the identity shape and obvious on a phone"
  - "A plausible explanation for the bug survived into three code comments and a glossary entry, and was wrong"
root_cause: wrong_api
resolution_type: code_fix
related_components:
  - documentation
tags: [godot, godot-4-7, control, scale, pivot-offset, get_global_rect, layout, stage-shape, wrong-explanation]
---

# Scaling a Control does not move its centre — so half-size times scale is always wrong

## Problem

Making cards and chrome widgets shrink per stage shape meant scaling `Control`
nodes for the first time. Several placement expressions in the combat screen
multiplied a node's half-size by its scale to work out where to put it. Every one
of those was wrong, because the quantity they were correcting for does not exist.

## Symptoms

- A card flying in from the draw pile appeared beside the pile rather than on it,
  then travelled to its seat from that wrong start. With a 96px pile and a 152px
  card the offset was about 28px right and 40px down.
- The size of the error scaled with the shrink, so it was zero at the identity
  shape (nothing is scaled there) and grew on every smaller shape — the classic
  shape of a bug a single-composition port cannot see.
- **The explanation was wrong even though the fix was right.** "`get_global_rect()`
  pairs a global origin with a local size" was written into three code comments
  and one `CONCEPTS.md` entry before anyone measured it.

## What Didn't Work

**Reasoning about `Control`'s transform instead of measuring it.** The session
concluded, from reading how Godot composes a Control's transform, that
`get_global_rect()` reports a scale-aware origin with an unscaled size, and that
this was why the flights started in the wrong place. That reading was applied to
three call sites. It produced one real fix and two behaviour-neutral changes —
and the two neutral ones are the tell: a wrong explanation that happens to
prescribe a correct action at one site will prescribe a pointless one at the next,
and a harmful one at the site after that.

The correct answer took one throwaway script:

```gdscript
var node: Control = Control.new()
node.size = Vector2(152, 216)
node.position = Vector2(100, 200)
node.pivot_offset = node.size * 0.5
# ... then, per scale:
print(node.get_global_rect(), node.get_global_rect().get_center())
```

On `4.7.1.stable.official`:

| `scale` | `get_global_rect()` | centre |
|---|---|---|
| 1.000 | `P: (100, 200)  S: (152, 216)` | `(176, 308)` |
| 0.776 | `P: (117.02, 224.19)  S: (117.95, 167.62)` | `(176, 308)` |
| 1.380 | `P: (71.12, 158.96)  S: (209.76, 298.08)` | `(176, 308)` |

`get_global_rect()` is scale-aware in **both** origin and size. And the centre
does not move at all.

## Solution

Drop the scale factor from every placement expression. A centre-pivoted Control's
centre is `position + size * 0.5` at any scale, so placing one by its centre needs
the **unscaled** half-size:

```gdscript
# presentation/combat/hand_view.gd — before
var start: Vector2 = from.get_center() - view.size * 0.5 * born

# after
var start: Vector2 = from.get_center() - view.size * 0.5
```

The same correction applies at `spend_to` and `strike_to`, which flew a card to a
pile and at a foe with `* shrink` and `* STRIKE_SCALE` in the destination.

Where a call site genuinely wants the on-screen box of a node inside a scaling
shell, either accessor is correct; `HudBar.pile_rect`
(`presentation/combat/hud_bar.gd` (`pile_rect`)) spells it out from the
transform so the question is answered at the call site rather than assumed:

```gdscript
var xf: Transform2D = p.stack.get_global_transform()
return Rect2(xf.origin, p.stack.size * xf.get_scale())
```

And the three wrong comments plus the `CONCEPTS.md` entry were rewritten to say
what was actually measured.

## Why This Works

A Control's transform maps a local point `p` to `position + pivot + R·S·(p −
pivot)`. Substitute `p = pivot`: the two `pivot` terms cancel and the result is
`position + pivot`, with no `S` in it. **The point at the pivot is a fixed point
of the scaling.** With `pivot_offset = size * 0.5` — which is what a node that
scales about its own middle sets — that fixed point is the centre.

So a placement expression that wants a node's centre at `X` needs
`position = X − size * 0.5`, with the half-size unscaled. Multiplying it by the
scale places the centre at `X + size * 0.5 * (1 − k)` instead, which is zero at
`k = 1` and grows as the node shrinks. That is exactly the observed error: zero at
the identity shape, 28×40px at a card born from a pile.

The corollary that made the wrong explanation feel right: at `k = 1` **every**
version of the expression agrees. A screen with one composition has no way to tell
a correct placement from three incorrect ones.

## Prevention

- **Never multiply a half-size by a scale in a placement expression.** If a node
  scales about its own centre, its centre is `position + size * 0.5` at every
  scale. Reach for `get_global_transform() * (size * 0.5)` when a call site needs
  the on-screen centre of something several transforms deep.
- **`get_global_rect()` is not the trap it is often assumed to be.** On 4.7.1 it
  reports the scaled origin and the scaled size. Do not add a "corrected" variant
  on the belief that it does not — measure first, and if the two agree, say so in
  the comment so the next reader does not add the same correction again.
- **A fix that works is not an explanation that is right.** Both are needed,
  because the explanation is what gets applied to the next site. Here one correct
  fix and a wrong reason together produced two changes that did nothing and a
  glossary entry that would have misled a future reader. When a fix lands, check
  that the stated cause predicts the observed magnitude — 28×40px is
  `size * 0.5 * (1 − born)` exactly, and is not what "an unscaled size in the
  rect" would predict.
- **Measure engine behaviour with a throwaway script, not by reading the source.**
  The check above is ten lines and runs headless in under a second. Reading how
  Godot composes a transform took longer and got it wrong.
- **A single-composition screen cannot catch this class of bug at all.** Anything
  proportional to `(1 − scale)` is identically zero while every scale is 1. When
  adding a scale dimension — screen shapes, density, zoom — expect a crop of these
  and expect the identity case to keep passing throughout. See
  [Measure the running reference, not the tables it publishes](../conventions/measure-the-running-reference-not-its-tables.md).

## Related Issues

- [A scaled Control shrinks its hit area with its
  picture](a-scaled-control-shrinks-its-hit-area-with-its-picture.md) — the other
  `Control.scale` trap, and the same blind spot from the input side: scaling the
  picture scales the pick rect with it, so a target can pass every geometric
  check and still be too small for a finger. Both are invisible at the identity
  shape, where nothing is scaled at all.
- [Measure the running reference, not the tables it publishes](../conventions/measure-the-running-reference-not-its-tables.md)
  — the same session, the same blind spot from the other side: the identity shape
  is where every override equals its default, so it is the one case that can
  neither detect a missing layout store nor a wrong scale correction.
- [A const typed Dictionary hands back a plain Array](../logic-errors/const-typed-dictionary-drops-its-packed-array-type.md)
  — the previous time an engine behaviour in this tree was diagnosed half-right
  and the half got written into a code comment. The rule that came out of it —
  ask the container its size before theorising — is the same rule as this one:
  measure the engine, do not reason about it.
