---
title: "Measure the running reference, not the tables it publishes"
date: 2026-07-28
last_refreshed: 2026-07-29
category: conventions
module: port/layout
problem_type: convention
component: development_workflow
severity: high
applies_when:
  - Porting layout from a reference that publishes authored data files
  - A transliterated data table matches the reference exactly and the screen is still wrong
  - Deciding what counts as "the authored layout" for a parity check
  - Adding a new responsive dimension (screen shape, density, orientation) to a port
tags: [port, parity, layout, container-queries, verification, methodology, web-reference, measurement, godot]
---

# Measure the running reference, not the tables it publishes

> **Citation convention.** `src/styles.css`, `src/battlefield-layout.js` and
> `src/ui-chrome-layout.js` below belong to the **reference** repo
> (`~/Coding/roguecardv2-benchmark` at `6e06911`), not to glassvow. A claims
> validator run against this repository will flag them as unresolvable; that is
> expected and correct.

## Context

The stage-shape work gave this port five authored screen compositions where it
had one. Its data came from the benchmark's two layout files, transliterated
verbatim into `assets/layout/combat-layout.json`: `src/battlefield-layout.js`
(209 lines — ground line, hero seat, foe formations, three scenery plates, per
act) and `src/ui-chrome-layout.js` (74 lines — ten chrome widgets).

Both were carried completely. Every number in them was then verified against the
running reference, one shape at a time, and **matched to the pixel** — the energy
orb's box, the lantern, the END seal, all three plates' sizes and vertical
positions, the hero's centre, the hand box, the fan gap.

Four of the five shapes were still visibly broken. A card on a 390px phone was
drawn at the iPad's 152px and covered a third of the stage. The HUD title ran off
the right edge. The energy orb drew a 44px numeral into a 66px-tall box.

The tables were complete. The layout was not.

## Guidance

**Treat the reference's data files as one store among several, and the running
reference as the only authority.** Before declaring a layout dimension ported,
measure the reference itself in that dimension and diff it against the port
measured the same way — do not diff the port's source against the reference's
source.

For a web reference this is cheap and exact. `#stage` is set to the shape's
reference size in CSS px and carries a uniform transform (`src/stage.js`), so an
element's client rect divided by that scale **is** stage px. One script per shape
produces the whole composition as gaps from each edge — the same form the port's
layout book stores, so the two tables compare without arithmetic. (This project
already knew the reference could be read live through the DOM for exact parity
specs; what was new was reading it to find numbers *no data file contained*.
— auto memory [claude])

Then build the equivalent readout on the port side. `tools/probe_layout.gd`
constructs the real screen at a shape, lets the entrance settle, and prints every
box in stage px. A capture shows where something *looks* like it is; on a 390px
screen that is how a twelve-pixel error survives.

**When the two readouts disagree and both source tables agree, look for a third
store.** Ours was `@container stage` in `src/styles.css` — ten blocks, 331 lines,
holding real layout numbers:

| What | Where in the reference | Resolves to (pad-land / desk-land / pad-port / phone-port / phone-land) |
|---|---|---|
| card width (`--cw`) | `styles.css:500, 2059, 2134, 2206` | 152 / 152 / 132 / 118 / 104 |
| `.hand-zone` height | `styles.css:614, 2061, 2138, 2210` | 260 / 260 / 230 / 214 / 128 |
| card inset in the hand | `styles.css:619, 2139, 2211` | 8 / 8 / 8 / 46 / 0 |
| energy orb box | same blocks | 120×90 / 120×90 / 102×78 / 84×66 / 72×57 |
| HUD rail | `styles.css:2106-2117, 2189-2197` | 14 declarations per regime |

## Why This Matters

**A port cannot notice a store it was never told about.** The two data files have
editors upstream (`?bfedit=1`, `?bfuiedit=1`), a schema implied by their
serialisers, and a shape to transliterate. The container-query block has none of
those. Nothing in the port's tests, validator or reviews could have reported it
missing, because there was no declaration of it to be missing *from*. The absence
was invisible in exactly the way a complete-looking table makes it invisible.

The failure mode is worse than an incomplete port, because a complete-looking one
stops the search. Two verified tables and a matching pixel diff on the identity
shape read as "done" — and the identity shape is precisely the one where the
third store's values equal the defaults, so it could never have shown the gap.

The same shape of mistake was still live in this tree when this was written:
the reward rack drew three 178px cards across a 390px stage, because
`CARD_SCALE` was a `const` divided out of `CardView.CARD_W` in four files. Its
numbers live in the same container-query blocks
(`styles.css:1657, 2060, 2174, 2261`), and they were never in a data file
either. It has since been closed the same way this doc prescribes: the rack's
per-shape numbers were authored into the layout book's `reward` scope
(`presentation/stage/layout_book.gd:282-284` (`rack/w`)), and the four
`CARD_SCALE` consts survive only as identity-column defaults
(`presentation/reward/reward_screen.gd:144` (`CARD_SCALE`)).

One more consequence worth stating: a store with no schema also has no
*validation*, so upstream can carry a plain bug in it indefinitely. The
benchmark's `min-width: 100%` declares that a scenery plate covers the stage, and
`sl-drift` then slides that plate ±`drift` px — so a plate exactly stage-wide
uncovers up to `drift` px of bare sky at one edge on every sweep. Measured on the
port at pad-landscape act 2, the far-right four columns swung from mean 19.6 to
47.9 across one sweep. Copying the store faithfully would have copied that too.

## When to Apply

- Before calling any responsive dimension ported — shape, orientation, density,
  text scale. Measure the reference in that dimension; do not infer it from the
  reference's tables.
- When an authored table verifies clean and the screen is still wrong. That
  combination is the signature of a second store, not of a transcription error.
- When the identity case passes and the others do not. The identity case is where
  every override equals its default, so it is the one case that cannot detect a
  missing override store.

Not needed when the dimension has exactly one authored store and the port's
readout already matches it end to end.

## Examples

The port-side readout that made the disagreement visible, and the schema entries
the third store became:

```gdscript
# tools/probe_layout.gd:41 — the real screen, at a shape, read back in stage px
func _probe(shape: StringName, act: int) -> void:
    var screen: CombatScreen = CombatScreen.new(game, shape, act)
    ...
    # gaps from each edge, so a row compares with the book without arithmetic
    print("  %-14s %s" % [row[0], row[1]])
```

```gdscript
# presentation/stage/layout_book.gd:141 — a number that had no data file upstream
&"card/w": {"bind": BIND_NONE, "unit": "px", "min": 40.0, "max": 400.0, "default": 152.0},
```

The port draws each piece once at its identity-shape size and spends the shape as
one scale outside it — `CardView.base_scale`
(`presentation/combat/card_view.gd` (`base_scale`)) for a card,
`HudBar._place_widget` (`presentation/combat/hud_bar.gd` (`_place_widget`)) for a
chrome widget — rather than teaching every widget to lay itself out at any size.

The table is pinned so it cannot quietly drift back:

```gdscript
# tests/test_layout_book.gd:377 (`_sizes`)
static func _sizes(fails: Array[String]) -> void:
    var want: Dictionary[StringName, Array] = {
        &"pad-landscape": [152.0, 8.0, 260.0, 120.0, 90.0, 56.0, 1.0],
        &"phone-portrait": [118.0, 46.0, 214.0, 84.0, 66.0, 47.0, 0.0],
        ...
```

That test was **proved able to fail before being believed**: one authored value
was broken on purpose, the suite reported `FAIL` with the assertion's own message,
and the value was restored. This tree has already shipped one assertion that never
executed while the suite reported `PASS` — see
[A const typed Dictionary hands back a plain Array](../logic-errors/const-typed-dictionary-drops-its-packed-array-type.md).

## Related Issues

- [Audit a port by enumerating the reference's CSS](../workflow-issues/audit-port-by-enumerating-reference-css.md)
  — the same instinct applied to motion rather than layout: go to the reference's
  CSS and enumerate rather than wait for someone to notice. That doc enumerates
  the reference's **source**; this one says the source is not sufficient and the
  running page has to be measured.
- [Every number matched, and the declaration still did
  not](every-number-matched-and-the-declaration-still-did-not.md) — the third
  member of this cluster, and the closest to this doc: there too every figure
  agreed and the screen was wrong. The causes are different and that is the whole
  distinction. Here you read the **wrong source** — a published table instead of
  the running page. There you read the right source and only read its **numbers**,
  missing a property that carries no figure at all.

  *This doc used to end the entry above with "worth consolidating into one
  porting-method doc if a third instance of this shows up." The third instance
  arrived, the question was put, and the answer was to keep all three separate:
  they share a symptom and nothing else. This one is about which source to read,
  the CSS-enumeration doc is about auditing at scale (reached for when planning
  an audit, not when debugging one mismatch), and the declaration doc is about
  reading a source completely. Merging them would produce a document whose
  sections have only the symptom in common. Recorded here so the next reader does
  not re-open a settled question.*
- [Matching constants prove nothing](../design-patterns/derive-authored-compensations-when-porting.md)
  — the mirrored failure: a number transcribed correctly from the reference that
  is still wrong, because what the reference authored was a compensation rather
  than a value.
