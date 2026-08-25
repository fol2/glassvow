---
title: "A hypothetical in review is a rate you have not measured"
date: 2026-08-25
category: conventions
module: presentation/map
problem_type: convention
component: development_workflow
severity: high
applies_when:
  - A review flags a failure mode that is reasoned from the code rather than observed
  - Accepting a finding would replace a working heuristic with a more precise rule
  - Deciding whether a review comment is closed by argument or by measurement
  - A procedural or seeded system has a harness that could count how often the flagged case fires
  - Judging a change by its precision rather than by the metric the code exists to defend
root_cause: missing_workflow_step
resolution_type: workflow_improvement
tags: [code-review, adjudication, measurement, methodology, regression, seeded-probe, map-scenery, godot]
---

# A hypothetical in review is a rate you have not measured

## Context

`MapScene` deals the map's 25 scenery seats per run instead of standing them in
the same holes every time (PR #453). The three follow-up commits quoted below
landed directly on `main` by fast-forward rather than through a PR of their own;
their record is in #453's comments. Three families draw on three independent
RNG streams — `_band_seats` at `presentation/map/map_scene.gd:829`, called once
each for nine wedges, four slabs and eight dabs — and no stream can see the
other two. `WEDGE_Z` (8.5..11.7) and `DAB_Z` (7.4..11.8) overlap outright, so
two pieces from different families can land in the same metre. The commit that
added `_separate` measured that before believing it: over 200 seeds, pairs
closer than **half** their combined footprint radius ran at 1.30 per seed
against 0.00 for the hand-authored set it replaced.

> **Which number, from which harness.** Every 0.00 / 1.30 / 0.95 below is taken
> at *half* combined reach, by a throwaway script that seeded `MapScene` and
> compared the dealt layout against the authored one. `tools/probe_map_seeds.gd`
> as shipped counts a wider band — `gap < 1.0`, footprints merely touching
> (`tools/probe_map_seeds.gd:100`) — and the `SEAT_GAP` trade table at
> `presentation/map/map_scene.gd:797-802` records a third, `< 0.75` reach. The
> three are consistent with each other (the authored set is 0.00 at half reach
> and 1.00 at 0.75) but they are **not interchangeable**, and running the probe
> as shipped will not reproduce the figures quoted here. Instrument for the
> threshold you mean to quote.

`_separate` (`presentation/map/map_scene.gd:871`) relaxes the whole 25-seat list
apart along X only — the z bands carry the design — and skips pairs that are
*coincident*, within 0.001 in both x and z:

```gdscript
if absf(dx) < 0.001 and absf(dz) < 0.001:
    continue
```

The skip exists because `_slab_seats` (`presentation/map/map_scene.gd:920`)
deliberately emits two entries at one (x, z) so the real kits, flattened to
y = 0, stack. That stack is the family's whole point.

An independent reviewer flagged the shape of the test: skipping by DISTANCE
rather than by IDENTITY could also exempt two pieces from different families
that happened to collide exactly — the one case the pass exists to fix, excusing
itself by being bad enough. The reasoning is sound on its face.

The structural version — skip when `b == a + 1` inside the known slab index
range — is strictly more precise and closes the hypothetical hole outright. It
also regressed a real metric. Welding each stack permanently against its own two
halves leaves them as a non-repelling pair that packs badly against everything
else: over the same 200 seeds, pairs closer than half their combined footprint
went from **0.00 per seed to 0.95**.

So the hypothetical itself got measured. Instrumenting the original distance
skip with a counter for how often it exempted a NON-slab pair returned **zero**
across 200 seeds. `_band_seats` draws x and z from continuous uniform
distributions; two independent floats agreeing to a millimetre in *both* axes is
not an event that distribution produces.

The distance test stayed, and both numbers went into the comment at
`presentation/map/map_scene.gd:878-895` so the next reader does not re-try the
more precise version blind. The settling commit is `659669b`, two commits on
from `2decfdc`, which added the separation pass.

## Guidance

**A reviewer's demonstrated defect is a fact. A reviewer's hypothetical is a
hypothesis with an unknown rate. Adjudicate them differently.**

When a review finding names a failure mode rather than exhibiting one — "this
*could* also match X", "an input *might* reach here" — the finding has two
unknowns, not one: whether the hole exists in the code (usually yes, and easy to
confirm by reading) and whether anything drives inputs into it (unknown, and the
part that decides whether the fix is worth anything). Confirming the first and
treating the second as settled is how a correct-looking patch buys nothing and
pays something.

Before changing code to close a hypothetical:

1. **Measure the rate the hypothetical actually fires at.** Instrument the exact
   branch the reviewer named and count. Here that was a counter on the
   coincident skip, tallying non-slab exemptions over a 200-seed sweep — a
   throwaway counter driven by the same seeding loop `tools/probe_map_seeds.gd`
   already provides, not a new harness. Note that "reuse the harness" meant
   reusing its *seed loop*; the packing figures still needed their own
   threshold, which is the sort of detail that makes a quoted number
   irreproducible if left implicit.
2. **Measure the metric the current code was written to defend, under the
   proposed replacement.** The proposal is only more precise on the axis the
   reviewer was looking at. `_separate` exists to hold interpenetration at 0.00
   per seed; the precise version took it to 0.95, which is most of the way back
   to the 1.30 the pass was added to fix.
3. **If the rate is zero and the replacement costs a real number, keep the code
   and record both numbers where the code is.** Not in the PR, not in the issue
   — in the comment at the branch, because the next person to have this idea
   will be reading the branch.

Distributional arguments belong in the comment alongside the count, because they
say *why* the zero is not luck. Continuous draws in two independent axes give a
millimetre-exact collision probability so low that 200 seeds finding none is the
expected result rather than an under-powered sample — a different and stronger
claim than "we did not see it."

**State the scope of the zero.** A measured rate is a rate *on the distribution
you sampled*, not a proof of impossibility. This zero holds while seats come
from `_band_seats`' continuous uniform draws. Give any family a quantised or
snapped x, or seed two families from one stream, and the collision the reviewer
described becomes reachable and the count has to be re-run. See
[A canary pins the rule, not the bug's shape](../test-failures/canary-pins-the-rule-not-the-bugs-shape.md)
for why enumerating the shapes you have observed is a bet that the set is
closed.

None of this licenses ignoring reviewers. In the same review round, three other
findings from the same reviewer were real and all three shipped in `c99376a`:
`_embedded_mean_findings` decoded with PIL `convert("L")` and compared luma
against a `tex_mean` the shader divides `.rgb` by (the two agree to 0.001 on the
shipped atlas, which is exactly why it would have stayed invisible until an
atlas with a colour cast arrived); a `tex_mean` declared with no embedded image
returned no findings at all; and `_connected_components` returned 1 — "one clean
body", the strongest possible pass — for an unindexed mesh with no shared
vertices to union in the first place. Each was demonstrable from the code,
needed no rate, and got fixed the same day. The test is not who raised it. The
test is whether the finding is a fact or a probability.

## Why This Matters

Precision and correctness are not the same property, and a review conversation
pulls toward precision because precision is the thing that can be argued about
in the abstract. "Test identity, not distance" is unanswerable as a principle.
It is answerable as a measurement, and the measurement said the principle cost
0.95 interpenetrating pairs per seed to buy a defect that occurs zero times.

The asymmetry is what makes this cheap to get wrong. Accepting a hypothetical
feels conservative — you are closing a hole, the diff is small, the reviewer is
satisfied. But every replacement of working code has a cost that is only visible
if you measure the thing the working code was doing, and a hypothetical gives
you no reason to go looking. The `b == a + 1` version would have passed every
gate in this repo: six gates green, suite PASS, and no test in the tree asserts
a packing rate. It would have shipped as an improvement.

This module learned the same lesson from the other direction two hours earlier
the same afternoon. The bug `2e03bde` fixed was this: a per-run salt had been
applied to the loop that places scenery meshes but not to the loop eleven lines
below it — that spacing is the pre-fix figure from `2e03bde`'s own message; the
two loops sit further apart in the tree today — which publishes their footprints
to `MapPinProjection`, so for five run seeds in six every seat
was registered under the wrong species — a 6.2-scaled ash trunk could be
published carrying a 2.2-scaled stump's radius and depth, one of five possible
mispairings, and the node solver stepped around trees that were not there. What talked the author out of checking the second loop was
his own comment on the first: "Positions are untouched, so nothing the node
solver ... depend[s] on moves." Positions were untouched. The radius and the
depth are per-species and moved with the salt. That finding needed no rate
measurement at all — it was demonstrable by reading eleven lines — and the fix
routed both loops plus the probe through one function, `seat_kit`
(`presentation/map/map_scene.gd:469`).

Two findings, one afternoon, one file. One was a fact and the right move was to
fix it immediately. One was a probability and the right move was to measure it
and decline. Treating both the same way — either way — gets one of them wrong.

## When to Apply

Reach for this when a review finding is phrased with a modal verb: *could*,
*might*, *in principle*, *if an input ever*. Especially when:

- The finding targets a **heuristic or tolerance** — a distance threshold, an
  epsilon, a hash prefix, a "close enough" comparison. These are the natural
  home of "but two different things could compare equal", and also the place
  where the replacement most often has a side effect on the thing the heuristic
  was tuned for.
- The code under review is **procedural or generative**, so its inputs come from
  a distribution you control and can therefore reason about and sample. A rate
  is cheap to get here. Where inputs come from users or the network, the same
  argument does not hold and a hypothetical deserves more weight.
- **A sampling harness already exists.** `tools/probe_map_seeds.gd` made the
  measurement a counter and a run, not a project. If measuring the rate would
  cost more than the risk it retires, that is a legitimate reason to just take
  the safe change — say so explicitly rather than pretending you measured.

Do NOT apply this to findings that are demonstrated rather than hypothesised —
the reviewer showed the wrong line, the wrong constant, the branch that cannot
be reached. Those get fixed. Nor to trust boundaries, save-format compatibility,
or anything where the failure is unrecoverable rather than merely ugly; a rate
of zero over 200 samples is not an argument in a place where the first
occurrence is the last one.

## Examples

**The finding, and what it was right about.** `_separate` skipped pairs by
proximity, and the slab stacks it means to skip are at distance zero. Any other
pair at distance zero gets the same free pass, and that pair is maximally
overlapping — the worst case the function exists to fix, exempted for being the
worst case. Reading the code, that is simply true.

**What measuring the rate showed.** Instrumenting the branch and counting
non-slab exemptions over 200 seeds: zero. `_band_seats` builds each seat as

```gdscript
out.append(Vector3(
        centre + rng.randf_range(-0.5, 0.5) * span * BAND_INSET,
        height,
        side * rng.randf_range(z_band.x, z_band.y)))
```

Two continuous draws, independent across families because each family has its
own stream from `_scatter_rng`. A cross-family pair has to match within 0.001 in
x *and* within 0.001 in z to hit the skip. The count and the distribution agree,
which is the point — either alone would be weaker.

**What the more precise version cost.** Skipping by index (`b == a + 1` inside
the slab range) does not merely exempt the pair from being pushed apart; it
exempts them permanently and in every pass, so each stack behaves as a rigid
two-seat unit that never relaxes against its own halves and packs worse against
the other 21 seats. Measured on the same 200 seeds, pairs closer than half their
combined footprint: 0.00 → 0.95 per seed. For scale, the pass was added because
the unseparated deal ran at 1.30 against a hand-authored 0.00.

**Where the answer lives now.** `presentation/map/map_scene.gd:878-895`, at the
branch, carrying both numbers and the reason:

```gdscript
# A reviewer flagged that testing by DISTANCE rather than by
# identity could also exempt two pieces from different families
# that happened to collide exactly -- the one case this pass
# exists to fix, excusing itself by being bad enough. Measured
# over 200 seeds: that fires ZERO times.
```

and, below it, that the index version "welds each stack against its own halves
permanently, and pairs closer than half their combined footprint went from 0.00
per seed to 0.95. Distance stays." A comment that records only the decision
invites the next reader to re-litigate it; a comment that records the two
measurements ends the conversation.

**The contrast case, handled the other way.** The salt-vs-footprint bug fixed in
`2e03bde` was two loops eleven lines apart disagreeing about
`posmod(j + _scatter_salt, kinds)` versus `j % kinds`. No sweep, no counter, no
rate — `kinds` is 6, so five run seeds in six were wrong, and that follows from
reading the two lines. It was fixed by collapsing the duplication into
`seat_kit` rather than re-synchronising it. Same file, same afternoon, opposite
adjudication, because the evidence was of a different kind.

## Related Issues

- [An unread schema field is a question, not a verdict](an-unread-schema-field-is-a-question-not-a-verdict.md)
  — the same shape one level up: a signal that *looks* like a verdict is only a
  question, and sweeping the whole class on it is the error. That doc supplies a
  conceptual test; this one supplies a numeric test for the review-comment case.
- [Measure the running reference, not the tables it publishes](measure-the-running-reference-not-its-tables.md)
  — the parent rule this is an instance of. It decides which *source* to believe;
  this decides which *claim* to believe, and adds the second half: re-measure the
  metric the code defends, not only the hypothetical.
- [Scaling a Control does not move its centre](../ui-bugs/scaling-a-control-does-not-move-its-centre.md)
  — same rule, different origin of the wrong belief. There the plausible
  mechanism came from the author reasoning about engine internals; here it came
  from a reviewer naming a failure mode. Both were fixed by measuring instead.
- [Put the gate where the change is deterministic](put-the-gate-where-the-change-is-deterministic.md)
  — why the packing rate belongs in a probe rather than in a rendered capture.
- `CLAUDE.md` › Verification — the house ancestor of all of these: "Measure the
  running thing; do not infer from source", and the parse gate that was believed
  on argument until four seeded error classes settled it.
