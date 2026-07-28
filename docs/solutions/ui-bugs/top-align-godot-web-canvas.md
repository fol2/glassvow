---
title: "Top-align a Godot Web canvas without breaking pointer mapping"
date: 2026-07-27
last_refreshed: 2026-07-27
category: ui-bugs
module: developer-tools/web-export
problem_type: ui_bug
component: tooling
symptoms:
  - "The Interactive Web canvas could be vertically centred instead of starting at the top of its available viewport"
  - "Shell CSS could not control the final canvas box while Godot adaptive resizing still owned its dimensions"
root_cause: config_error
resolution_type: config_change
severity: medium
related_components:
  - "development_workflow"
tags: [godot-web, canvas-layout, custom-html-shell, aspect-ratio, pointer-mapping]
---

# Top-align a Godot Web canvas without breaking pointer mapping

## Problem

The custom Godot Web development surface was vertically centred in its
available viewport instead of starting at the top. The repair also had to keep
the authored 1180×820 surface proportional in direct and embedded browser
views, without moving interactive controls away from the pointer.

## Symptoms

- The Web canvas did not reliably begin at `y=0`.
- Responsive CSS in the custom shell appeared correct but did not determine the
  running canvas dimensions.
- A visual-only layout fix risked reintroducing the pointer offset that the
  Enemy Bench had just exposed.

## What Didn't Work

The first attempt left adaptive resizing enabled and added top-aligned,
proportional CSS:

```ini
html/canvas_resize_policy=2
```

```css
body {
  display: flex;
  justify-content: center;
  align-items: flex-start;
}
```

In the live browser, Godot then applied absolute, full-window dimensions as an
inline canvas style. The canvas remained 944×578, so the shell did not own the
box that Flexbox was trying to align. This was not a CSS specificity problem;
two different systems were deciding the same geometry.

## Solution

Give the custom shell sole ownership of responsive display sizing. The Web
export selects the shell and disables automatic canvas resizing in
[export_presets.cfg:17](../../../export_presets.cfg#L17):

```ini
html/custom_html_shell="res://tools/web_shell.html"
html/canvas_resize_policy=0
```

Keep the logical surface explicit in the HTML
([web_shell.html:16](../../../tools/web_shell.html#L16)):

```html
<canvas id="canvas" width="1180" height="820"
        aria-label="Glassvow development surface"></canvas>
```

Let CSS contain that surface within the browser, centre spare horizontal space,
and place it at the top
([web_shell.html:9](../../../tools/web_shell.html#L9)):

```css
html, body {
  width: 100%;
  height: 100%;
  margin: 0;
  overflow: hidden;
}

body {
  display: flex;
  justify-content: center;
  align-items: flex-start;
}

canvas {
  width: min(100vw, 143.902439vh);
  height: min(100vh, 69.491525vw);
  display: block;
}
```

The reciprocal viewport-unit factors encode the 1180:820 aspect ratio. The
shorter available dimension limits the canvas, so it fits without stretching.

The live acceptance check covered both browser shapes:

- A direct 944×578 page produced an 831.75×578 canvas at
  `(x=56.125, y=0)`, backed by 1180×820 pixels.
- The development-tools 610×396 iframe produced a 569.8515625×396 canvas at
  `(x=20.0703125, y=0)`.
- Clicking the visible Time scale control at CSS coordinate `(730, 308)`
  changed it from `1.00x` to `0.27x`; the adjacent Yaw control did not move.

The exported build and local checks then passed:

```bash
python3 tools/dev.py --build-web
python3 -B tools/dev.py --check
git diff --check
```

## Why This Works

With resize policy `0` configured
([export_presets.cfg:18](../../../export_presets.cfg#L18)), the custom shell
controls the presentation rectangle in the observed export. The HTML
attributes retain the 1180×820 backing surface, while the CSS rules calculate
only its display rectangle.

Flexbox therefore has a stable box to place: `justify-content: center` consumes
horizontal spare space and `align-items: flex-start` fixes its vertical origin
at zero. The direct-page and iframe measurements prove that the same rule holds
at two container sizes.

**1180×820 is one shape, not the shape.** When this was written it was the only
authored surface; the stage-shape work has since made it the *identity* shape of
five, and the shell still hardcodes it in three coupled places — the two `canvas`
attributes and both viewport-unit factors. A run forced to another shape keeps
this canvas and letterboxes inside it, because a shape changes the engine's
content scale rather than the backing surface. That is a limitation of the Web
surface, not of the fix above: single-owner sizing, resize policy `0`, and the
pointer canary are all independent of which shape is being shown.

The pointer canary is the second half of the proof. A canvas can look aligned
while its input transform is wrong; changing only the intended slider shows
that the displayed rectangle still maps to the 1180×820 interactive surface.

## Prevention

- Assign Web canvas sizing to one owner. A custom responsive shell uses
  `html/canvas_resize_policy=0`; adaptive Godot sizing and shell-owned sizing
  must not compete.
- Keep the canvas attributes and both viewport-unit factors together — all three
  encode one aspect ratio and must be recomputed from it together. Since the
  stage-shape work there is no longer a single "the authored viewport" to derive
  them from: they are pinned to the identity shape, and giving the Web surface a
  second shape means making all three follow it rather than editing one.
- Verify the direct export and the development-tools iframe after changing the
  shell, export preset, or host layout. Record the canvas rectangle and require
  `y=0`, the authored aspect ratio, and the expected backing dimensions.
- Pair geometry evidence with an input canary on adjacent controls. A
  screenshot proves placement; it does not prove pointer mapping.
- Rebuild the export before browser verification. Editing
  `tools/web_shell.html` does not alter an already-generated Web build.

## Related Issues

- [Drive the lab the way the game drives it](../tooling-decisions/drive-the-lab-the-way-the-game-drives-it.md)
  — verification surfaces must preserve the product's real geometry and input
  path.
- [Capture through a long-lived host](../tooling-decisions/long-lived-capture-host-not-process-per-shot.md)
  — the corresponding native-window guidance for observing real viewport
  behaviour.
- [Godot custom Web shell documentation](https://docs.godotengine.org/en/4.7/tutorials/platform/web/customizing_html5_shell.html)
  — the engine's supported `canvasResizePolicy` override.
