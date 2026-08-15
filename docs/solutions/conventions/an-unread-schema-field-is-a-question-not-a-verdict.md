---
title: "An unread schema field is a question, not a verdict — two orphans, opposite answers"
date: 2026-07-31
category: conventions
module: presentation/stage
problem_type: convention
component: development_workflow
severity: medium
symptoms:
  - "Four fields in the layout book had no reader after a screen was rewritten"
  - "A single sweep would have deleted all four; two of them deserved opposite fates"
  - "The orphaned code left inline replacements behind — the exact thing the scope exists to collect"
root_cause: incorrect_assumption
resolution_type: process_change
related_components:
  - documentation
tags: [schema, layout-book, dead-code, stage-shape, refactoring, godot]
---

# An unread schema field is a question, not a verdict

## Problem

`WorldMapScreen` was rewritten from a fixed trail into a navigable Spire while
the `map` scope of the layout book was being authored against the old design.
Four fields came out the far side with no reader: `trail/top`, `trail/bottom`,
`mapbar/title`, `mapbar/region`.

The obvious move — sweep them — is wrong, and so is the opposite reflex of
keeping everything on the grounds that somebody must have meant it. The four
split three ways.

## Symptoms

| Field | Reader after the rewrite | Right answer |
|---|---|---|
| `mapbar/title` | none | **keep** — the case arrived from the other direction |
| `trail/top`, `trail/bottom` | none | **replace** — the concept survived, the shape of it did not |
| `mapbar/region` | none | **delete** — no case, and never had one |

The failure this prevents is not "a dead field sat in a JSON file". It is that
**the rewrite that orphaned a field usually left an inline replacement behind**,
and a sweep that deletes the field leaves the replacement standing. Here the
Spire had `clampf(size.y * 0.12, 74.0, 98.0)` written into `_row_gap()` and three
shape names spelled out in ternaries for the act line's offsets — a fresh
unauthored layout store, in the file whose scope had just been opened to collect
exactly that.

## What Didn't Work

**Sweeping by grep for readers.** It answers "is anyone calling this?", which is
not the question. `mapbar/title` had no reader on the afternoon it was nearly
deleted; the next day the Spire's rail started printing the act, the floor and
the boss, and the separate title label under it became a duplicate that clipped
at phone-portrait and was drawn straight over the top waystone row at
phone-landscape. Switching it off is one value in the book. The field was one
edit away from being gone when the case for it arrived.

**Keeping all four "in case".** `mapbar/region` was authored against a bare
`size.x < 650.0` threshold that lived in a `refresh()` which no longer exists. It
would have gated the horizon tree line — load-bearing atmosphere that no defect
ever asked to remove. A field kept without a case is a field the next person
authors a value into because it is there.

## Solution

**Ask what the ORPHANING change did to the concept, not what the field does.**

1. **The concept survived and the field still describes it** → keep. Look for a
   case arriving from a new direction before concluding there is none.
2. **The concept survived but the change re-shaped it** → replace, and take the
   inline code the change left behind with you. `top`/`bottom` described a
   vertical band between two insets; the Spire scrolls rows past a camera, so
   the vertical rhythm is a row gap. Three fields (`rowRate`, `rowMin`,
   `rowMax`) went in, two came out, and `_row_gap()` stopped being a literal.
   (Historical example: the vertical Spire has since been replaced by the
   horizontal Pilgrimage, and that rewrite re-applied this very rule in the
   same motion — `rowRate`/`rowMin`/`rowMax` became `trail/stepRate`/`stepMin`/
   `stepMax`, `_row_gap()` became `_step()`. `_step` itself retired with 2D
   seating in #234 slice 7b2; the lattice owns spacing now.)
3. **The concept is gone and no defect ever pointed at the field** → delete.

The clause that does the work is the second half of rule 3. A field that was
authored speculatively, whose gating code has been rewritten away, and which no
observed defect has ever asked for, is the delete case. A field with a defect
behind it is not, however quiet it has been.

## Why This Works

The three outcomes differ by *evidence*, and "has a reader" is not evidence
about any of them — it is a fact about the last person to touch the consumer.
A rewrite mechanically removes readers from correct and incorrect fields alike,
which is precisely why the reader count carries no signal at the moment you are
most tempted to use it.

Meanwhile the second rule is what stops the schema losing ground. A rewrite that
orphans a field has almost always re-solved the same problem inline, because the
author was thinking about the screen and not about the book. Deleting the field
without collecting the inline replacement ratchets the codebase one notch back
towards hardcoded layout, one rewrite at a time.

## Prevention

- **When a screen is rewritten, audit the scope it reads in the same pass** —
  and grep the rewrite for the literals its orphaned fields used to carry. The
  replacement is usually right there.
- **Do not bulk-sweep unread fields.** Triage them one at a time against the
  change that orphaned them. Four fields here produced three different answers.
- **Prove the replacement is arithmetically identical before capturing.** All
  five shapes were dumped through the resolver and compared against the old
  inline expressions figure by figure; the capture then only had to confirm
  nothing crashed. See [Measure the running reference, not the tables it
  publishes](measure-the-running-reference-not-its-tables.md) for the direction
  this does *not* work in.

## Related Issues

- [A scaled Control shrinks its hit area with its picture](../ui-bugs/a-scaled-control-shrinks-its-hit-area-with-its-picture.md)
  — the same lane, and the other half of the lesson: a field authored with a
  default of 0 costs the shapes that do not need it nothing, which is what makes
  keeping a quiet field cheap enough to be worth doing when it has a case.
- [Measure the running reference, not the tables it publishes](measure-the-running-reference-not-its-tables.md)
  — why the resolved-value table above is a proof of identity and not a proof of
  composition.
