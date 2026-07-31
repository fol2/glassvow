---
title: "Put the gate where the change is deterministic, not where the result is visible"
date: 2026-07-31
category: conventions
module: presentation/stage
problem_type: convention
component: development_workflow
severity: high
applies_when:
  - Moving hardcoded figures into a data table and needing to prove nothing moved
  - The screen under change animates continuously, so a capture diff has no stable floor
  - A same-build capture diff is being quoted as a regression gate
  - Choosing what evidence a refactor's "identical output" claim actually rests on
tags: [verification, methodology, capture, noise-floor, regression-gate, layout-book, godot, determinism]
---

# Put the gate where the change is deterministic, not where the result is visible

## Context

Three refactors in one session each moved hardcoded layout figures into the
book: the map's row gap, the title screen's twelve-field shape table, and the
reward studies' stage-width literals. Each carried the same claim — **nothing
moved** — and the obvious way to back it is a before/after capture diff at the
identity shape.

The convention this repo already holds is
[Establish the noise floor before trusting a
diff](../tooling-decisions/long-lived-capture-host-not-process-per-shot.md):
capture the same build twice, and only a change larger than that difference is
evidence of anything. That rule is right, and it is not sufficient. It assumes
the floor is a floor — a number you can measure once and compare against.

On the title screen it is not a number. Three captures of one unchanged build,
same seed, same arguments, differed by:

| pair | differing px (of 967,600) |
|---|---|
| 1 vs 2 | 583,025 |
| 1 vs 3 | 576,426 |
| 2 vs 3 | **57,506** |

A ten-fold spread. `TitleWorld` is a continuously drifting sky, so two captures
either land in the same phase or they do not; the result is bimodal, not a
distribution with a floor under it. The before/after diff for the real change
came back 585,235 — inside the spread, above two of the three pairs, and
**evidence of nothing in either direction**.

`--settle=SECONDS` does not rescue this. That flag works because an *entrance*
finishes; a procedural sky never does.

## Guidance

**When the observable is stochastic, do not tighten the gate — move it upstream
to where the change is deterministic.**

The three refactors were all of one shape: an expression became a table lookup.
That transformation is exactly deterministic at the point of the lookup, whatever
the renderer does downstream. So the gate belongs there — resolve every field at
every reference shape and compare it against the expression it replaced:

```gdscript
for s: StringName in [&"pad-landscape", &"desktop-landscape", &"pad-portrait",
        &"phone-portrait", &"phone-landscape"]:
    var w: float = float(StageShape.REFERENCES[s].x)
    var compact: bool = w >= 1000.0 and float(StageShape.REFERENCES[s].y) <= 860.0
    var old: Dictionary = {
        "columnW": (minf(760.0, w - 32.0) if s == &"phone-landscape"
            else (340.0 if compact or s == &"phone-portrait" else minf(300.0, w - 32.0))),
        # ... the other eleven, verbatim as they stood
    }
    var t: Dictionary = LayoutBook.resolve(&"run", s).get("title", {})
    var new: Dictionary = {
        "columnW": minf(LayoutBook.num(t.get("columnW"), 340.0), w - 32.0),
        # ...
    }
```

Twelve fields across five shapes: **sixty comparisons, zero differences.** That
is a stronger claim than any pixel diff could have made, and it is repeatable —
run it again next week and it returns the same sixty.

Three corollaries worth stating separately:

**A noise floor is per screen, and per session.** It is not a project constant.
The same session measured this repo's map at 442 px in one sitting and at
9,926–13,380 px in another, and the title screen at 57k–583k. Quoting a floor
measured on one screen as though it governed another is how a false regression
gets reported.

**Say out loud when a gate is unavailable.** The temptation is to publish the
585,235 with a sentence explaining it away, because a number looks like evidence.
It is not evidence; printing it invites a future reader to treat it as a
baseline. The commit for that change states plainly that the pixel diff is not
available on that screen and names what the evidence actually is.

**Some changes have no numeric gate at all, and that is a valid outcome.** The
same session ported a missing CSS `drop-shadow` to the same title screen. There
is no resolver to compare and no stable capture, so the evidence is the reference
declaration read in full plus a before/after crop of the affected edge — stated
as such, with no number attached.

## Why This Matters

A gate exists to make a claim falsifiable. A gate whose own variance exceeds the
effect it is meant to detect does the opposite: it produces a number, the number
gets recorded, and the claim becomes *less* falsifiable than if nothing had been
measured — because now there is a figure in the commit message that looks like it
was checked.

The upstream gate is also cheaper and faster than the thing it replaces. Sixty
resolver comparisons run headless in under a second and need no window, no
settle, no focus grab, and no macOS desktop (see [Capture without stealing
focus](../tooling-decisions/long-lived-capture-host-not-process-per-shot.md)).
The capture is still worth taking — it catches crashes, missing nodes and
compositions that are arithmetically perfect and visually wrong — but it is doing
a different job, and it should not be asked to do this one.

## When to Apply

- **Apply** when a refactor's claim is "the resolved values are unchanged". That
  claim lives above the renderer, so test it above the renderer.
- **Apply** when a same-build diff's spread is a meaningful fraction of the
  effect you are looking for — check the spread across *three* captures, not two,
  or a bimodal signal reads as a tight floor by luck.
- **Do not apply** when the claim is about composition rather than values. A
  resolved-value table cannot show that three correctly-shrunk cards sit in a
  panel hanging 194 px off the stage; only a capture shows that. Both gates
  exist because they answer different questions.
- **Do not apply** as an excuse to skip looking. Every change in this session was
  still captured and read by eye at each affected shape. The upstream gate
  replaces the *diff*, not the looking.

## Examples

**Before** — the gate as first reached for:

> Identity capture came back 10,856 differing px. Under the 442-px noise floor
> measured earlier? No. Is that a regression? Unknown, and the number is now in
> the commit message.

**After** — the gate moved upstream, with the capture kept for the job it can do:

```
pad-landscape       rowGap now=98.0 was=98.0  titleTop=62 H=26 inset=0
desktop-landscape   rowGap now=98.0 was=98.0  titleTop=62 H=26 inset=0
pad-portrait        rowGap now=98.0 was=98.0  titleTop=62 H=26 inset=0
phone-portrait      rowGap now=98.0 was=98.0  titleTop=58 H=38 inset=58
phone-landscape     rowGap now=74.0 was=74.0  titleTop=42 H=26 inset=0
```

plus a same-build spread measured *for this screen in this sitting*
(9,926–13,380 px) against which the observed 10,856 is unremarkable — reported as
context, not as the gate.

## Related

- [Establish the noise floor before trusting a
  diff](../tooling-decisions/long-lived-capture-host-not-process-per-shot.md) —
  the rule this extends. It owns measuring the floor; this owns what to do when
  the floor will not hold still.
- [Measure the running reference, not the tables it
  publishes](measure-the-running-reference-not-its-tables.md) — the opposite
  direction, and not in conflict: read the *reference* from what runs, and gate
  the *port* where its change is deterministic.
- [Every number matched, and the declaration still did
  not](every-number-matched-and-the-declaration-still-did-not.md) — why the
  upstream gate is necessary and never sufficient: it can only check the
  quantities somebody thought to author.
- [A scaled Control shrinks its hit area with its
  picture](../ui-bugs/a-scaled-control-shrinks-its-hit-area-with-its-picture.md)
  — a defect that passed every geometric gate, numeric and visual alike.
