---
title: "Two rules, one property: the state class wins, so the centring died on reveal"
date: 2026-08-14
category: ui-bugs
module: docs/story-candidates/render
problem_type: ui_bug
component: frontend_stimulus
severity: medium
symptoms:
  - "Every full-bleed illustration sat centred while off-screen and jumped right by half its own width the instant it scrolled into view"
  - "Fifteen published bilingual review pages shipped with it; a human found it by eye, and no check in the pipeline could have"
  - "`.pane.seen{transform:none}` at (0,2,0) beats `figure.pane{transform:translateX(-50%)}` at (0,1,1) — class count is compared before element count"
  - "The centring and the animation sit far apart in the stylesheet, so neither rule looks wrong where it is written"
root_cause: scope_issue
resolution_type: code_fix
related_components:
  - tooling
  - documentation
tags: [css, cascade, specificity, transform, centring, scroll-reveal, intersection-observer, html-artifact]
---

# Two rules, one property: the state class wins, so the centring died on reveal

## Where this code lives

`docs/story-candidates/render.py` — the renderer for the fifteen bilingual story
pages published for [#175](https://github.com/fol2/glassvow/issues/175). It is
review tooling that emits self-contained HTML, not game code. It is the largest
stylesheet in this repository, though not the only one — `tools/web_shell.html`
and the design mockups under `docs/design/` carry their own. Line numbers below
are that file at the current tree.

The bug was found and fixed while the file still lived in a session scratchpad;
the copy in the repo is the fixed one. There is no commit that shows the fix as a
diff — the file entered version control already corrected.

## Problem

Each page carries 10–14 full-bleed illustrations. The prose column is narrow by
design — `--measure:34rem` (`render.py:193`), applied as
`.wrap{max-width:var(--measure);margin:0 auto;padding:0 1.25rem}`
(`render.py:219`) — and every illustration is a `<figure class="pane">` that must
break *out* of that column, up to `min(52rem, calc(100vw - 2.5rem))` wide.

The original way of breaking out was the classic negative-margin trick, with the
figure pulled back by half its own width using `transform: translateX(-50%)`.

The same elements also carry a scroll-reveal entrance animation, still present at
`render.py:308-311`:

```css
@media(prefers-reduced-motion:no-preference){
  .pane{opacity:0;transform:translateY(14px);transition:opacity .7s,transform .7s}
  .pane.seen{opacity:1;transform:none}
}
```

`seen` is added by an `IntersectionObserver` (`render.py:352`) the first time a
figure enters the viewport.

So `transform` had two owners: layout (centring) and motion (entrance). One
property, two owners — and both owners were getting the wrong answer, at
different moments.

**The specificity arithmetic.** Compare the selectors' triples left to right:
first the number of **id** selectors, then **class / attribute / pseudo-class**,
then **element / pseudo-element**. The first column that differs decides; later
columns are never consulted.

| Selector | ids | classes | elements | triple |
|---|---|---|---|---|
| `.pane.seen` | 0 | 2 (`.pane`, `.seen`) | 0 | (0,2,0) |
| `figure.pane` | 0 | 1 (`.pane`) | 1 (`figure`) | (0,1,1) |
| `.pane` | 0 | 1 (`.pane`) | 0 | (0,1,0) |

- `.pane.seen` (0,2,0) vs `figure.pane` (0,1,1): ids tie at 0; classes are 2 vs 1;
  **`.pane.seen` wins**, and the element column is never reached. Once `seen` was
  added, `transform:none` beat the centring transform.
- `.pane` (0,1,0) vs `figure.pane` (0,1,1): ids tie, classes tie at 1, elements
  are 0 vs 1; **`figure.pane` wins**. So *before* `seen` was added, the centring
  transform beat `translateY(14px)` and the entrance offset never applied at all.

Read those two rows together: the animation had been silently half-broken since
the day it was written — the figures never actually slid up — and the layout was
broken for the entire remainder of each figure's life on screen.

## Symptoms

**This is the part worth remembering.** The images were correctly centred *before*
they scrolled into view, and jumped right by exactly half their own width — the
`translateX(-50%)` being cancelled — at the precise moment the observer added
`seen`. That moment is, by construction, the moment a human first looks at them.

The consequences of that timing:

- The broken state and the only observable state were **the same state**. Any
  figure a person could see was a figure that had already lost its centring.
- Nothing but a human eye could catch it. No error, no console warning, no failed
  request, no layout thrash visible in a log.
- Scrolling back up did not help either: `seen` is never removed — `render.py:352`
  calls `io.unobserve` and leaves the class in place.
- It reproduced only with motion enabled. Under `prefers-reduced-motion: reduce`
  the animation block does not apply and the script's `else` branch
  (`render.py:355`) adds `seen` to everything up front — so a reduced-motion
  reader saw a *consistently* off-centre page, and a normal reader saw a page that
  jumped.
- It was reported in the plainest possible terms, after someone read one published
  page: *"the picture is not aligned centre."*

## What Didn't Work

**Rejected: raising the centring selector's specificity.** The obvious patch is to
make the centring rule outrank `.pane.seen` — add another class, add the `figure`
element to both, reach for `:where()` gymnastics, or in the worst case
`!important`. Any of these wins *this* round.

It was rejected because it leaves the collision in place. `transform` still has
two owners; the winner is still decided by a specificity comparison nobody
re-derives when they touch the file. The next person who edits the animation —
adds a hover state, adds a second state class, splits the rule — re-breaks the
layout, with no warning and the same invisible-until-a-human-looks failure mode.
A fix that has to be defended by an arms race is not a fix.

The durable move is to stop sharing the property.

## Solution

Centre with margins, and let `transform` belong entirely to the animation. The
current rule, `render.py:243-244` (the `%%` there are Python `%`-format escapes;
the emitted CSS contains a literal `%`):

```css
figure.pane{margin-block:2.8rem;width:min(52rem,calc(100vw - 2.5rem));
  margin-inline:calc(50% - min(26rem,50vw - 1.25rem))}
```

The animation block is untouched and now genuinely runs: `.pane`'s
`translateY(14px)` no longer loses to anything, and `.pane.seen{transform:none}`
cancels nothing but the entrance offset it was written to cancel.

## Why This Works

**The arithmetic.** A percentage margin resolves against the **containing block's
inline size** — here the content width of `.wrap`. Call that column width `C` and
the figure's own width `F`. The figure is `min(52rem, calc(100vw - 2.5rem))`, so
half of it is exactly `min(26rem, 50vw - 1.25rem)` — 26rem is half of 52rem, and
`50vw - 1.25rem` is half of `100vw - 2.5rem`. The margin is therefore `C/2 - F/2`.

Place the figure's left edge at `C/2 - F/2` and its centre lands at
`C/2 - F/2 + F/2 = C/2` — the centre of the column, at any viewport width, with no
transform involved. When the figure is wider than the column the value goes
negative and the figure hangs out symmetrically on both sides, which is the whole
point of a full-bleed pane.

**The narrow-viewport case.** `.wrap` is `max-width:34rem` with
`padding:0 1.25rem` under `*{box-sizing:border-box}` (`render.py:195`), so at
viewport widths at or below 34rem the column content is `100vw - 2.5rem` — and the
figure is *also* `100vw - 2.5rem`. Both terms converge, the margin collapses to
exactly zero, and that is correct: the figure now fills the column precisely and
has nothing to be offset by.

**Why it is durable, not just correct.** Layout owns `margin-inline`; motion owns
`transform`. The two rules no longer name the same property, so no specificity
comparison decides the layout, and no future edit to the animation can move the
figure. That is the actual fix — the arithmetic is only the mechanism.

**The alternative that was available and not taken.** Modern CSS exposes
`translate`, `rotate` and `scale` as independent properties that *compose with*
`transform` rather than replacing it. Keeping the transform-based centring and
moving the entrance offset to `translate: 0 14px` / `translate: none` would have
worked, and would have been a smaller diff. Margins were chosen anyway, because
they leave the layout independent of **any** transform at all — including a future
one nobody has written yet.

## Verification

Measured, not inferred:

- All fifteen pages re-rendered, then the output grepped:
  `grep -o "transform:translateX" pages/*.html | wc -l` → **0**.
- Each of the fifteen `story-NN.html` files carries `margin-inline:calc(` exactly
  once (`index.html` has no panes, correctly reporting 0).
- Pages republished to the URLs in `docs/story-candidates/urls.json`.

`pages/` is gitignored build output, so those two greps are reproducible only
after re-rendering. At source they are structurally guaranteed: `render.py`
contains `translateX` zero times and `margin-inline` once, and every page is one
expansion of the single `TEMPLATE`.

**No test covers the rendered CSS or the resulting geometry.**
`docs/story-candidates/validate.py` gates the content JSON only — bilingual
pairing, block types, image references, asset paths — and nothing in CI runs even
that. The only check that existed for this behaviour was a human reading a
published page, which is how the bug was found, after it shipped.

## Prevention

1. **Two rules setting the same CSS property on the same element is a latent bug
   even when the page currently renders correctly.** Which one wins is decided by a
   specificity comparison, and that comparison's result flips the moment a state
   class is added or removed. "It looks right" tells you which rule won today, not
   that only one rule exists.

2. **When a layout concern and an animation concern both want to move an element,
   give them different properties.** Layout takes `margin` / `inset` / grid
   placement; motion takes `transform` / `translate`. CSS has `translate`, `rotate`
   and `scale` as independent longhands precisely so motion need not seize
   `transform` wholesale.

3. **A bug whose broken state is also its only observable state cannot be caught by
   looking at the page.** It needs an assertion — on the source, or on computed
   geometry. Two cheap options, either of which would have caught this in seconds:
   - a source-level assertion on the rendered CSS (the `grep` above, promoted from
     a one-off to a check that runs on every render);
   - a computed-position check in a headless browser: scroll a `.pane` into view,
     wait for `seen`, then assert
     `getBoundingClientRect().left + width/2 ≈ column.left + column.width/2`.

4. **Do not let the cheap source-level check stand in for the real one.** A `grep`
   for `transform:translateX` proves a string is absent; it does not prove a figure
   is centred in a browser. Green gates routinely cover less than they appear to —
   check what is actually in the coverage set, and watch the check fail in the
   target environment before trusting it *(auto memory [claude])*. Here that means:
   break the centring on purpose, confirm the computed-position check goes red in a
   real browser, then keep it.

## Related Issues

- [Top-align the Godot web canvas](./top-align-godot-web-canvas.md) — the same
  root cause one level coarser: Godot's adaptive resizing and the custom shell's
  CSS both owned canvas sizing, and the fix was likewise to remove one writer
  rather than out-rank it.
- [Per-recipe shader knobs, not a shared model](../conventions/per-recipe-shader-knobs.md)
  — the same family on the "one knob, many consumers" axis: a constant added
  inside a shared helper reached six recipes instead of the one requested.
- [Put the gate where the change is deterministic](../conventions/put-the-gate-where-the-change-is-deterministic.md)
  — the project's answer to "why was there no automated check": the gate belongs
  where the change is deterministic, not where the result is visible.
- [Scaling a control does not move its centre](./scaling-a-control-does-not-move-its-centre.md)
  — adjacent by symptom: another centring-and-transform defect that was invisible
  in one configuration and obvious in another.
- [Every number matched and the declaration still did not](../conventions/every-number-matched-and-the-declaration-still-did-not.md)
  — the nearest CSS-reasoning precedent: reading a declaration is not the same as
  knowing what the browser computed.
