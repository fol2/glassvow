---
title: "Every number matched, and the declaration still did not — a CSS property with no figure in it"
date: 2026-07-31
category: conventions
module: presentation/run
problem_type: convention
component: frontend_stimulus
severity: medium
symptoms:
  - "The title banner's three ratios matched the reference exactly, and the screen still looked wrong"
  - "A hard rectangular cut where the raster met the living sky, on three sides"
  - "Read as an art-direction choice, because every figure the port carried was already correct"
root_cause: incorrect_assumption
resolution_type: code_fix
related_components:
  - documentation
tags: [parity, css, benchmark, shader, drop-shadow, godot, title-screen, verification]
---

# Every number matched, and the declaration still did not

## Problem

The port's title banner reproduced `styles.css:341-343` figure for figure —
`opacity: 0.35`, `max-height: 55cqh`, `max-width: 90cqw`,
`padding-bottom: 18cqh`, `object-fit: contain`. Five values, five matches.

The screen still looked wrong: the raster plate ended in a hard rectangular cut
against the procedural sky behind it, on three sides, at every shape.

Because the numbers all agreed, the natural reading was that the composition was
correct and the *look* was somebody's art decision. It was not. The reference
declaration has a sixth property that carries no layout figure at all:

```css
.title-banner .raster-art {
  max-height: 55cqh; width: auto; max-width: 90cqw; object-fit: contain;
  filter: drop-shadow(0 12px 40px rgba(0,0,0,.6));
}
```

The `filter` had never been ported.

## Symptoms

- The plate reads as pasted on rather than lying over the night.
- Every ratio check passes. Every resolved-value dump passes. A pixel diff is
  useless on this screen anyway (`TitleWorld` animates the whole frame; three
  captures of one unchanged build disagreed by 57k, 576k and 583k px).
- The defect survives a careful numeric audit **precisely because** it is not a
  number. A layout book, a resolved-value table and a `file:line` anchor all
  describe quantities; this is a property whose entire content is a rendering
  behaviour.

## What Didn't Work

**Reading the port's own comment.** It said "the authored raster sits over the
living sky", which is true and complete about *placement* — and placement was
never the gap. A docstring that accurately describes what the code does is not
evidence that the code does everything the reference does.

**Calling it art direction and stopping.** That is the failure worth naming. The
reasoning was "these are proportions with no shape name on them, so this is
composition, not a layout store, and composition belongs to another lane." Both
halves were correct and the conclusion was still wrong, because the question
"are the numbers right?" and the question "is the declaration ported?" are
different questions and only the first had been asked.

## Solution

Port the filter. `background.png` is RGB with **no alpha channel**, so the
drop-shadow of an opaque rectangle is by definition a blurred axis-aligned
rectangle — which has a closed form, separable in x and y, and needs no texture
read and no two-pass blur:

```glsl
float blurred_step(float x, float s) {
    return 0.5 + 0.5 * tanh(1.2533 * x / max(s, 0.0001));
}
float band(float lo, float hi, float x, float s) {
    return blurred_step(x - lo, s) - blurred_step(x - hi, s);
}
```

Three details that are easy to get wrong:

- **CSS states a blur RADIUS, and defines it as twice the Gaussian standard
  deviation.** A `40px` filter is σ = 20, not σ = 40.
- **The shadow must be masked out under the plate.** CSS applies the group's
  `opacity: 0.35` to the composite of shadow-under-image, and the image is
  opaque, so no shadow survives behind it. Two Godot nodes each at 0.35 would
  darken that overlap twice.
- **The shadow Control has to be bigger than the plate.** A shader can only draw
  inside its own rect, so the node is grown by 3σ plus the offset — otherwise
  the shadow's tail is clipped into a second hard edge and the fix defeats
  itself.

## Why This Works

A blurred step function is an erf, which the shading language does not carry;
the `tanh` form above stays within about 1% of it, which on a shadow whose
effective alpha is 0.6 × 0.35 = 0.21 is well under one 8-bit level. Separability
means the 2D result is the product of two 1D evaluations, so the whole shadow is
four `tanh` calls per fragment with no sampling at all.

## Prevention

- **Enumerate the DECLARATION, not the figures in it.** When auditing a ported
  rule, list every property in the reference block and tick each one off,
  including the ones with no number: `filter`, `mix-blend-mode`, `backdrop-filter`,
  `mask-image`, `object-fit`, `will-change`. A numeric audit cannot see them, and
  a numeric audit is what this port mostly runs. This is the same discipline that
  made the CSS enumeration pass work where sampling failed — see [Measure the
  running reference, not the tables it
  publishes](measure-the-running-reference-not-its-tables.md).
- **"Every number matches" is not "ported".** Treat a numeric match as evidence
  about the numbers and nothing else. It is the mirror of the trap
  `CLAUDE.md` already pins — a function existing in the source is not evidence
  that it renders. There, the port's call matched the reference's and neither
  drew anything; here, the port's figures matched and a property with no figure
  in it was missing. Both times the agreement was real and about the wrong
  thing.
- **When you find yourself concluding "this is art direction, not my lane",
  check the reference first.** It costs one grep. The conclusion is often right
  and the one time it is wrong, it is wrong in the direction of leaving a real
  divergence in the tree with a reasoned-sounding comment on top of it.

## Related Issues

- [An unread schema field is a question, not a
  verdict](an-unread-schema-field-is-a-question-not-a-verdict.md) — the same
  session, and the same shape of error in the other direction: a fast, plausible
  classification applied before the evidence that would have settled it.
- [Measure the running reference, not the tables it
  publishes](measure-the-running-reference-not-its-tables.md) — why the
  benchmark's own CSS block, read in full, beats any summary of it.
