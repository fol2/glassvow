---
title: "Godot Label placement guessed at font height instead of measuring it"
date: 2026-07-26
category: ui-bugs
module: presentation/combat
problem_type: ui_bug
component: rails_view
symptoms:
  - "Count numeral's Label box was 16px tall while the 12px font needs 18px, so the glyph rendered outside its own Control bounds"
  - "Changing NUM_SIZE silently shifted the numeral vertically, because placement was derived from the guessed box height"
  - "A status with no PNG in assets/art/statuses/ drew nothing — an invisible 32px chip with a stack count floating beside it"
root_cause: wrong_api
resolution_type: code_fix
severity: medium
related_components:
  - documentation
tags: [godot, gdscript, font-metrics, label, css-port, asset-fallback, status-chip]
---

# Godot Label placement guessed at font height instead of measuring it

## Problem

`StatusChip` renders a status icon with a stack count in the corner. It is a
parallel port of the web benchmark's `.schip`, and it looked pixel-correct. It
was built on two guesses: a Label box height invented as `NUM_SIZE + 4`, and an
early `return` when the icon art is missing. Neither was visible in the shipped
build; both were latent.

## Symptoms

- The count Label's box was `NUM_SIZE + 4` = **16px** tall, holding a font that
  needs **18px**. The glyph overflowed its own Control and only looked right
  because a Godot `Label` does not clip its children to its rect.
- Because the vertical position was computed *from* that guessed height
  (`SIZE - h - NUM_BOTTOM`), changing `NUM_SIZE` moved the numeral vertically —
  a coupling nobody designed and nobody would expect.
- A status whose PNG is absent from `assets/art/statuses/` drew **nothing**.
  `_draw()` early-returned on a null texture, leaving an invisible 32px hole
  with a stack count floating next to it — which reads as a layout bug, not a
  missing file.

## What Didn't Work

**Assuming the numeral was blurry because of sub-pixel positioning.** The
numeral looked soft under magnification, and the obvious culprit was a
fractional `position.x` — `SIZE - w - NUM_RIGHT` where `w` comes from
`get_string_size().x`, which is generally fractional.

That hypothesis was wrong, and measuring is what showed it:

```
"2"   w=6.0000   ->  pos=(28.0000, 20.0000)   WHOLE PIXEL
"9"   w=6.0000   ->  pos=(28.0000, 20.0000)   WHOLE PIXEL
"99"  w=12.0000  ->  pos=(22.0000, 20.0000)   WHOLE PIXEL
```

Alegreya's digits are tabular, so at 12px they measure to exactly 6.0 and 12.0
and every position lands on a whole pixel. The perceived softness was an
artifact of the lab's own ×3 inspector scaling a 12px Label — not a defect in
the chip at all.

The same measurement run printed the real defect on the line above:

```
Alegreya-700 @ 12 — ascent 13.000  descent 5.000  height 18.000
box height in use: NUM_SIZE + 4.0 = 16.000
```

Had the fix been applied on the strength of the visual impression, it would
have "corrected" a non-problem and left the actual one in place.

## Solution

Anchor the numeral to its **baseline**, using the font's real metrics
([status_chip.gd:138](../../../presentation/combat/status_chip.gd#L138)):

```gdscript
# Before — box height invented, position derived from it
var h: float = float(NUM_SIZE) + 4.0
_count.size = Vector2(w, h)
_count.position = Vector2(SIZE - w - NUM_RIGHT, SIZE - h - NUM_BOTTOM)

# After — box from the font, position from the baseline
var f: FontFile = numeral_font()
_count.size = Vector2(w, f.get_height(NUM_SIZE))
_count.position = Vector2(SIZE - w - NUM_RIGHT, NUM_BASELINE - f.get_ascent(NUM_SIZE))
```

`NUM_BASELINE` ([status_chip.gd:52](../../../presentation/combat/status_chip.gd#L52))
states the validated number — `33.0` — instead of arriving at it by accident
through a guessed line-height.

And make a missing asset loud rather than invisible
([status_chip.gd:142](../../../presentation/combat/status_chip.gd#L142)):

```gdscript
func _draw() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	if _tex == null:
		_draw_missing(box)   # was: return
		return
	draw_outlined_texture(self, _tex, box, Color(0.0, 0.0, 0.0, 1.0), outline_px)
```

Shipped in `9a7e3ff` on `main`.

## Why This Works

A `Label`'s box and its glyph are two different things. Godot draws the first
line's baseline at `get_ascent()` from the top of the box, so the box height
only ever *indirectly* controls where text appears. Guessing that height means
guessing the thing you actually care about, one step removed.

Anchoring the baseline inverts the dependency: the number in the source is now
the number a typographer would name, and the box is derived from the font
rather than from a constant that happened to look right. Changing `NUM_SIZE`
now rescales the glyph in place instead of sliding it.

Digits have no descender, so the visual bottom of "99" *is* its baseline —
which is why baseline-anchoring is not merely more principled here, it is the
measurement that matches what the eye reads.

## Prevention

- **Ask the font, don't guess the box.** `get_height()`, `get_ascent()` and
  `get_descent()` exist; `font_size + n` is a magic number wearing a formula.
  A quick `SceneTree` script that prints the metrics costs one minute:

  ```gdscript
  var f: FontFile = load("res://assets/fonts/Alegreya-700.woff2")
  print("ascent %.1f descent %.1f height %.1f"
      % [f.get_ascent(12), f.get_descent(12), f.get_height(12)])
  ```

- **Measure before fixing, especially when the defect is visual.** The blur
  hypothesis here was plausible, cheap to act on, and wrong. Magnifying a lab
  screenshot can mislead when the lab itself scales the widget — judge at
  actual size, or print the numbers.

- **A pixel-diff is the right acceptance test for a refactor that should change
  nothing.** This change was verified by capturing the contact sheet before and
  after and running `cmp`; byte-identical output is what "polish" should mean:

  ```bash
  godot --path . -- --chips --sheet --shot=/tmp/after.png
  cmp -s /tmp/before.png /tmp/after.png && echo IDENTICAL
  ```

  Note the sheet's own title text is part of the capture — changing a caption
  will fail the diff for a reason that has nothing to do with the widget.

- **Never let a missing asset render as nothing.** In a data-driven content
  system, content outruns art. An early `return` on a null texture produces a
  silent invisible widget, which is among the most expensive bug classes to
  trace — the symptom points at layout and the cause is a filename.

- **A lab screenshot taken headless does not fail fast — it hangs.**
  `--headless` has no viewport texture, so `save_png` gets a null image and
  raises. The process then never exits: measured at exit code 124 after a full
  60s `timeout`, with the PNG never written. Always run lab captures windowed;
  keep `--headless` for `--check-only` parse gates. If you must script the
  combination, wrap it in `timeout` — without one it will sit forever.

  ```
  $ timeout 60 godot --path . --headless -- --chips --shot=/tmp/x.png
  SCRIPT ERROR: Cannot call method 'save_png' on a null value.
  exit code: 124   elapsed: 60s
  ```

## Related Issues

- [Tune one card-surface recipe with a per-recipe uniform](../conventions/per-recipe-shader-knobs.md)
  — the same discipline applied to shader work: the visual impression was wrong
  there too, and only a numeric diff against a control settled it.
- `AGENTS.md` / `CLAUDE.md` — the repo's verification contract (parse gate,
  import, test suite).
- `.claude/skills/glassvow-godot/SKILL.md` — the binding engine contract.
- `presentation/combat/status_chip.gd` header — documents the `.schip` CSS this
  widget ports, and carries a deliberate `ponytail:` note declining to move the
  8-draw outline into a shader until a screen shows dozens of chips
  ([status_chip.gd:20](../../../presentation/combat/status_chip.gd#L20)).
