---
title: "Drive the lab the way the game drives it, and photograph loops as well as beats"
date: 2026-07-27
last_refreshed: 2026-07-29
category: tooling-decisions
module: presentation/lab
problem_type: tooling_decision
component: tooling
severity: high
applies_when:
  - "Building or extending a Lab that stands a widget up outside the screen that ships it"
  - "Deciding which capture modes a verification harness needs, not just how each one works"
  - "Judging whether a port is missing a behaviour rather than rendering it with different numbers"
  - "A prior audit graded a call site correct by comparing constants against the reference"
  - "Slowing or scaling time in a harness so a slow viewport readback can sample an animation"
symptoms:
  - "The one lab built to judge actor animation showed every creature running the humanoid idle, because it never called set_profile"
  - "Every lab strip mode photographs a one-shot beat, so a looping idle had no capture mode and its absence stayed invisible"
  - "The benchmark's whole per-kind idle layer was found by reading the reference stylesheet, not by looking at the port"
  - "`_update_shadow()` ran at build and at reset but never from `_process`, and no still screenshot can show a dead call site"
  - "`Engine.time_scale` cannot reach an idle clocked off `Time.get_ticks_msec()`, so the slowed-strip trick silently fails"
root_cause: missing_tooling
resolution_type: tooling_addition
related_components:
  - "development_workflow"
tags: [verification-tooling, lab-harness, capture-modes, screenshot-verification, idle-animation, port-parity, engine-time-scale, dead-call-site]
---

# Drive the lab the way the game drives it, and photograph loops as well as beats

> **Citation convention.** `src/styles.css` and the SHA `6e06911` belong to the
> **reference** repo (`~/Coding/roguecardv2-benchmark`), not to glassvow; a claims
> validator run against this repository will flag the SHA as unresolvable and that
> is expected. Bare SHAs are glassvow's: `bf7b751` and `2c683fa` are reachable from
> `origin/main`; `df3cc64` was local to `main` when this was written.

## Context

The enemy lab is the surface this project built to judge how its actors move. It
stands every creature in the content set on a shared ground line at true relative
size — 27 enemies, read out of `port_fixtures/content/core-mechanics.json`
(`presentation/lab/enemy_lab.gd:178` (`load_roster`)) — and it carried five
strip modes — six since
`--idle` — that photograph an animation across several instants and tile the
frames side by side.
It is the one place in the port where actor motion is looked at deliberately rather
than in passing.

It was building its actors wrong. `_actor`
(`presentation/lab/enemy_lab.gd:434` (`_actor`)) constructed every
view with `EnemyView.new(...)` and then placed it, and that was all. The shipping
screen does one more thing: `presentation/combat/combat_screen.gd:1305`
(in `start_encounter`) calls `view.set_profile(_foe_kind(e.idx))` for every foe,
and `presentation/combat/combat_screen.gd:1263` (in `start_encounter`) calls
`_hero.set_profile("rogue")` for the player. Without that call an actor keeps the
profile it is constructed with, and the construction default is not neutral —
`_read_idle` ends by calling `_resolve_profile(&"humanoid")`
(`presentation/combat/enemy_view.gd:2642` (`_read_idle`)), and
`_resolve_profile` falls back to
`IDLE_PROFILES[&"humanoid"]` for any kind it does not know
(`presentation/combat/enemy_view.gd:2685` (`_resolve_profile`)). So every
creature on the sheet — every slime, serpent, wisp and golem — hovered, swayed,
breathed and cast its shadow as a humanoid. The sheet was not showing a wrong
number. It was showing an idle that no fight has ever run.

The fix is one line, now at `presentation/lab/enemy_lab.gd:434` (in `_actor`):

```gdscript
view.set_profile(str(art.get("kind", "humanoid")))
```

That is the whole defect and the whole repair, and on its own it would be a
footnote. What makes it worth a document is the second thing, which the first was
hiding.

**A whole category of behaviour had no capture mode.** Every pre-existing strip
photographs a *beat* — a one-shot animation with a start, a peak and an end. The
frame tables say so in their own comments:
`presentation/lab/enemy_lab.gd` (`RITE_FRAMES`),
`presentation/lab/enemy_lab.gd` (`HIT_FRAMES`, clustered early because the
flash peaks at 90 ms), `presentation/lab/enemy_lab.gd` (`CRACK_FRAMES`),
`presentation/lab/enemy_lab.gd` (`WARD_FRAMES`) and
`presentation/lab/enemy_lab.gd` (`ENTER_FRAMES`). An
**idle** is not a beat. It is a loop with no start and no end, and nothing in the
lab sampled a loop. That is not a coincidence of coverage; it is the reason the
gap survived. The benchmark's entire per-kind idle layer was absent from the port,
and it stayed absent because there was no instrument that could have shown its
absence.

**Update, 2026-07-27 — a second dimension the lab does not offer: exposure.** The
same subject produced the same shape of failure again, in a different axis. The
enemy cast shadow was misplaced on every painting with an off-centre or multi-point
contact, and none of it was visible in a lab capture, because the shadow is
near-black on a near-black ground: the defect only appeared once screenshots were
brightened 2.4–3.0× after the fact. Sampling was not the problem this time — the
frames were correct and showed nothing. What the harness lacked was a way to
photograph the *low end* of the value range at all.

So the generalisation is wider than loop-versus-beat. A capture surface has
dimensions — when it samples, how long it samples for, and **what range of values
it can resolve** — and a defect living outside any of them is invisible in exactly
the way a defect that no test covers is invisible. Ask of a new instrument not only
"does it drive the subject the way the game does" but "could this instrument show
the failure if it were happening". Related: [A flat billboard has one depth](../ui-bugs/flat-billboard-shadow-had-one-ground-line.md).

**Update, same day — the range dimension answered, and what answering it cost.**
The dimension was named above and then hit again immediately: the ward stone's
ring, which lights the facets that stopped a blow, could not be read in
`--ward --absorb` because the body's hurt flash sat on top of it. Three
separate defects were behind one unreadable cell, and only the first is the one
the paragraph above predicted:

- **Range.** The flash was not clipping — 0.25% of the frame reached 254 — it
  simply raised the neighbourhood a two-level effect had to be seen against.
  Brightening cannot undo that, because the ring and the flash are equally
  bright; only removing one of them can. `--alone` drops the body's half and
  takes the frame from 5.2% to 0.3% of pixels above 200.
- **Duration, again.** `--absorb` had been borrowing the BREAK's frame table:
  340 ms of cells for a 200 ms ring, so two of six photographed a finished
  effect. The strip that named the loop-versus-beat lesson had the same error
  inside it, one flag over.
- **What the picture is OF.** `--delta` re-photographs each cell as its
  difference from the last, normalised at the 99.5th percentile — the divisor
  matters, because one specular pixel hit 185 where the answer averaged 2.6 and
  dividing by the maximum crushed it to black. The last cell is a free
  reference: every strip here is built to end after its beat.

**And a fourth, which that pass did not find.** The three above are the defects
behind the unreadable *cell*. A fourth sat in the same `--absorb` block and was
outside that frame entirely: the strip drove every subject with a hard-coded
`Vector2.LEFT`, the foe convention, so it could neither surface the missing
hero-side `ward_hit` nor have caught a wrong heading. Enumerating "what made
this cell unreadable" was the right question and it did not reach a defect in
the same six lines, because that one damaged the strip's *verdict* rather than
its legibility. Three-item lists invite the reading that the list is complete;
this one was complete only for the question asked of it.

The limit, stated because a general instrument invites over-trust: `--delta`
answers *what changed*, and for this beat what changed most is the stone's
flinch travel, not its brightness. Both decay on the same clock, so the strip
shows them together and cannot separate them. A difference image is a sharper
instrument than a still, and it is still an instrument with a blind spot —
which is the whole point of the paragraph above.

The layer is thirteen lines of the reference stylesheet, at
`roguecardv2-benchmark src/styles.css:1612-1624` (`6e06911`): `idleFloat` on the
floaters (wisp 3.1s/16px, eye 3.4s/18px, siren and shade 3.6s/12px, plant
3.8s/9px), `idleSlime` at 4.2s with `translateY 0 / -4 / +2` and
`scaleX 1 / 1.04 / .97` at 0/33/66%, `idleSway` on serpents at 3.5s with
`translateX 5px` plus `rotate 1.8deg`, and `idleBreathe` at 3.6s with
`scaleY 1.025` on beast, rogue, cultist, knight, zombie and crawler — plus
`.idle-motes`, two drifting spores on wisps and plants only. (Those names are the
reference's; the port's equivalents are reached through `set_profile`.) None of it
was in the port. It is now, at the source's own numbers:
`presentation/combat/enemy_view.gd` (`KIND_IDLE`),
`presentation/combat/enemy_view.gd` (`KIND_IDLE_PERIOD`),
`presentation/combat/enemy_view.gd` (`KIND_FLOAT_PX`),
`presentation/combat/enemy_view.gd` (`SLIME_AT`),
`presentation/combat/enemy_view.gd` (`SWAY_X`) and
`presentation/combat/enemy_view.gd` (`BREATHE_SY`), composed onto the vessel in
`presentation/combat/enemy_view.gd` (`_process`), with the spores as their own
Control (`presentation/combat/idle_motes.gd` (`IdleMotes`)), built on demand by
`presentation/combat/enemy_view.gd` (`_sync_motes`).

Note where that list came from. It was found by reading the reference stylesheet —
the method [`audit-port-by-enumerating-reference-css.md`](../workflow-issues/audit-port-by-enumerating-reference-css.md)
argues for — and **not** by looking at the port, at the lab, or at a screenshot.
The lab could not have found it. A sheet whose creatures all idle as humanoids
cannot report that there are four idle shapes and it is showing one of them.

**And the third instance, which is the one that shows why stills are not enough.**
The actor's cast shadow is an analytic projection of the silhouette along the key
light (`presentation/combat/enemy_view.gd:2246` (`_update_shadow`)) — a derived
replacement for the
benchmark's nine hand-authored CSS knobs, and structurally correct as such. It had
plausible lift-response coefficients. It also never ran: `_update_shadow` was
called from `_build_shadow`
(`presentation/combat/enemy_view.gd:2184` (`_build_shadow`)), from the
reset path, and from two lab-bench setters that no fight ever reaches — and from
nothing else, while the benchmark resynchronises its darkened copy against the
body's live transform on every frame of its rig loop. That the only other callers
were in the bench is itself the finding in miniature.
Worse, its one variable — then named `_lift` — was the quantity now called
`_art_pad` (`presentation/combat/enemy_view.gd:738`), computed at
`presentation/combat/enemy_view.gd:2063` (in `_read_contact`) as the transparent
margin below the painting's lowest opaque row.
That is a uniform export border, not height. Across the 27 enemy paintings the
bottom margin matches the top to a tenth of a percent on 13 of them and to within
a percentage point on 18 — 10.0/10.0, 5.2/5.2, 13.0/13.0, 20.7/20.6 — and the
outliers do not rescue the reading either: the largest bottom margin belongs to
`shellback`, a crab flat on the floor, at 20.7%, while `voidWisp`, which is a
wisp, has 4.3%. The response was inverted as well as frozen.

A prior audit had graded that entry by comparing its *constants* against the
reference and had written "correct as a derive, not a numeric match". Both defects
were invisible to that comparison, because both are properties of when the code
runs, not of what it computes. The corrected write-up is
`docs/actor-animation-checklist.md:269` (§2) and the "Correction, 2026-07-27"
section of
[`derive-authored-compensations-when-porting.md`](../design-patterns/derive-authored-compensations-when-porting.md).
The per-frame call now exists at
`presentation/combat/enemy_view.gd:2385` (in `_process`).

Three failures, one shape: the instrument was not being driven the way the product
drives the thing it measures, and where no instrument existed at all, the missing
behaviour was simply never on anyone's list.

### How the shadow was verified when it was built

Worth recording, because the method was careful and still could not have caught
this. When the projected shadow first landed, it was checked by capturing one real
fight, cropping the ground region and counting pixels; when the crop showed
nothing, the shadow's colour was temporarily changed to red and the capture
repeated, to prove the quad was rendering at all before any conclusion was drawn.
That is a good instinct and it produced a real finding — the `0.55` opacity had
been calibrated against the lab's flat navy and disappeared entirely on painted
stone. But every step of it is a single static frame, and a single static frame
cannot distinguish a live projection from a frozen one. The verification was sound
about *whether the shadow drew* and silent about *whether it moved*, and only the
first question was ever asked. (session history)

Two other things from the same period sharpen it. **"Built and left unplugged" was
already a named failure mode here** — one session hit it five times in a day: a
`take_hit()` the combat screen never called, an aim rim living in the shader but
never driven by hover, an `EnemyView.new()` that was never passed an `art_id` so
every fight showed the fallback gem while dozens of paintings sat unused, a HUD
frame only ever loaded by the HUD lab, and an inventory table marking four widgets
"only reachable in their lab". The phrase used at the time was that the animation
was not missing — it was built and left unplugged. Nobody asked the same question
about the *lab*. And **the project had already decided to verify through the
shipping screen**: `--fight` exists precisely so that a check runs the real
`CombatScreen` down the real input path rather than a mock. The lab kept being
reached for anyway whenever the subject was actor-shaped, and it drifted from
production without anyone re-testing that premise. (session history)

## Guidance

### 1. Enumerate the calls production makes on the subject — and the arguments it passes — and assert the harness makes the same ones

A lab that builds the subject with a constructor and nothing else is testing the
constructor. Before trusting any verification surface, read the production call
site end to end and list every method it invokes on the subject between
construction and first paint, and the value it passes to each. That pair — call
and argument — is the harness's contract. Here it was one
call — `set_profile`
(`presentation/combat/enemy_view.gd:2680` (`set_profile`)) — and the sheet's
own comment now names the production line it mirrors
(`presentation/lab/enemy_lab.gd` (in `_actor`)) so the next divergence
is a diff rather than an archaeology.

The check is cheap and mechanical: `grep` the subject's public methods against
both the production caller and the harness, and explain every method the first
calls and the second does not — **and every method both call with different
arguments**. A literal in the harness where production has a derived value is a
finding until a comment justifies it.

That second half was added on 2026-07-27 because the rule above, as first
written, passed a harness that was lying. The `--ward --absorb` strip called
`ward_hit` exactly as production does and hard-coded `Vector2.LEFT` for every
subject — including the two heroes on the lab's own roster
(`presentation/lab/enemy_lab.gd:156` (`HEROES`)). It cleared the method check
and could not have caught either the missing hero-side call in `_hit_player` or
a wrong heading, because it supplied the parameter under test. See
[The hero's ward stone never answered a blow it stopped](../ui-bugs/hero-ward-stone-never-answered-the-blow.md).

The two failure modes are not equally visible, which is why the argument half
matters more than it looks: a missing call renders as **nothing**, and someone
eventually notices nothing. A wrong-but-plausible argument renders as a
plausible effect, and nobody notices at all.

An intentional difference is fine — the lab
deliberately skips the seat delay in `--enter` because one actor cannot show a
stagger (`presentation/lab/enemy_lab.gd` (in `_ready`)) — but it has
to be written down as a decision, not left as an omission.

Note the shape of the failure that makes this necessary: `_resolve_profile` falls
back to the humanoid profile for an unknown kind rather than erroring
(`presentation/combat/enemy_view.gd:2685` (`_resolve_profile`)), and
`KIND_IDLE.get(kind, &"")` returns a benign empty value. A tolerant default is
right for production and is exactly what makes a missing call silent in a
harness.

### 2. Treat "this category of behaviour has no capture mode" as a finding in its own right

When you inventory a harness, inventory it by *kind of behaviour*, not by count of
tests. Five strip modes looked like good coverage. All five photographed beats. A
loop had no mode, and the consequence was not a weak test — it was an unbuilt
feature, because a gap nobody can photograph is a gap nobody argues about.

Write the inventory as a table of categories against instruments and look for the
empty cells. Beat: covered. Loop: nothing. Steady state: the roster sheet. A dead
call site: nothing (see 3). Each empty cell is a place where the port can silently
be missing an entire layer, and the cost of the cell being empty is paid in
features that were never noticed, not in bugs that were shipped.

### 3. A still frame cannot falsify a per-frame claim

`_update_shadow` produced a correct shadow in every screenshot ever taken of it,
because the frame it was built on was the frame being photographed. Nothing about
a still can distinguish "recomputed sixty times a second" from "computed once and
frozen", and nothing about a still can distinguish a correct response coefficient
from one whose input is the wrong quantity. Any claim of the form *X tracks Y* is
a claim about consecutive frames, and needs a capture that spans them with Y
moving. If the harness cannot make Y move, the claim is unverified regardless of
how carefully the constants were checked.

The technique was not the obstacle — multi-frame probes already existed here, and
had already earned their keep: a chrome-clamp probe that read successive frames
until the layout converged, and a card-glide probe whose sample point was moved
from frame 10 to frame 40 because the cards were demonstrably still gliding at 10.
(session history) Nobody had pointed one at the shadow, because nothing in the
shadow's write-up suggested the answer depended on which frame you looked at.

The corollary for audit documents: a verdict reached by comparing constants must
say so, and must not be recorded in the same vocabulary as a verdict reached by
watching the thing run.

### 4. The harness inherits the timebase of the subject, and cannot choose its own

This is the sharpest constraint in the set and the easiest to get wrong, because
the existing tooling made the wrong answer look like a house convention.

Three of the lab's five original strips slow the engine clock — `crack`, `enter`
and `ward`, each assigning `Engine.time_scale = CRACK_SLOMO`
(`presentation/lab/enemy_lab.gd` (in `_ready`)), with
`presentation/lab/enemy_lab.gd` (`CRACK_SLOMO`) set to `0.06` — and
convert their BEAT-time frame tables to wall time by dividing. (`rite` and `hit`
do not: their frame tables are already in real seconds.) They must, because a strip cell costs a
full-frame GPU readback while a crack front is over in about 170 ms; sampled at
wall-clock speed the first cell already lands most of the way along the arc.
Stretching the beat is what makes six cells fit.

That trick does not reach the idle. The kind-idle clock is
`Time.get_ticks_msec()` — `var t: float = Time.get_ticks_msec() * 0.001 + _phase`
in `presentation/combat/enemy_view.gd` (in `_process`), which is what the four
shapes are phased against in the same block. `Engine.time_scale` scales
`delta`; it does not touch the monotonic millisecond counter. Setting
`time_scale = 0.06` and sampling six frames would have photographed the same
instant of the cycle six times and produced a strip that looked, convincingly,
like a creature standing perfectly still.

So `--idle` runs in **real time** and spaces its frames wider than the readback
costs instead: `IDLE_FRAMES` at 0.84s intervals over one 4.2s period — the slowest
kind idle, `idleSlime` — at `presentation/lab/enemy_lab.gd:1469`
(`IDLE_FRAMES`), dispatched at `presentation/lab/enemy_lab.gd:1306-1313`
(in `_ready`) with no `time_scale` assignment at all.

The general rule: **a verification tool inherits the timebase of the thing it
verifies.** Before reaching for a clock knob, find which clock the subject reads.
If it reads a wall clock, the harness cannot slow it and must widen its sampling
instead. If it reads `delta`, the harness can slow it and should. This subject
reads *both* inside one function — `_idle_t += delta` drives the vertex-stage
deform at `presentation/combat/enemy_view.gd:2333` (in `_process`) while the kind
layer a few lines below reads the wall clock — which means one `time_scale` setting would have desynced
the two layers relative to each other even where it appeared to work. The same
asymmetry sits in the harness: `_shoot_strip` waits against elapsed
`Time.get_ticks_msec()` (`presentation/lab/enemy_lab.gd:1439-1448`, in
`_shoot_strip`), which is
precisely why the slowed modes have to pre-divide their frame tables.

### 5. Verify by predicted numeric signature, not by "it moved"

"It looks like it moves" is not a verification; it is the absence of one. Before
running a strip, write down the number the intended transform would move and the
number it would leave alone, then measure both. The point is a signature that
distinguishes the intended transform *from its neighbours*:

- **Width changes, height does not** ⇒ `scaleX`.
- **Height changes, width does not** ⇒ `scaleY`.
- **Bright centroid swings while the bounding box stays fixed** ⇒ translate plus
  rotate, not a scale.
- **Bounding box translates as a whole with no shape change** ⇒ a pure offset.

A predicted signature is falsifiable in both directions: it fails when nothing
moves, and it also fails when the *wrong* thing moves, which is the case a
did-anything-change check passes. Expect the measured swing to sit slightly inside
the authored range, because a strip samples discretely and will usually miss the
extrema; a small honest shortfall is agreement, and a match to three decimal
places on six samples is a reason to suspect the measurement.

## Why This Matters

A harness that lies is worse than no harness, and the arithmetic is not close.

With no harness, a behaviour is *unverified*, and unverified work stays on the
list. With a harness that drives the subject differently from production, the same
behaviour is *verified* — recorded as checked, taken off the list, and used as the
premise for the next decision. The enemy lab converted "nobody has looked at the
per-kind idle" into "we have a sheet of all 27 creatures and they look fine". That
is not a smaller amount of knowledge than having no sheet. It is a negative
amount, because it also consumed the attention that would otherwise have gone
looking.

### The census that graded its own blind spot the strongest MATCH

The clearest measure of the cost is what happened when a careful, deliberately
exhaustive audit ran straight into it. `docs/motion-census.md` enumerated the
reference stylesheet's transitions and animations and graded each against the port.
Rows 1612-1618 are exactly this idle layer. The four `idleFloat` rows were graded
**MATCH** — and called the strongest MATCH in the whole census — on the strength of
a port-side constant that carried the reference's numbers verbatim. That constant
is only ever resolved through `set_profile()` → `_resolve_profile()`, and
`KIND_IDLE.get(kind, …)` falls back silently when the call never comes. So on the
only surface anyone would have used to look at a floater floating, `_hover_amp` was
zero and nothing floated. The census's own strongest MATCH was, in practice,
unobservable.

Three further rows — `idle-slime`, `idle-serpent` and the six `idleBreathe`
kinds — were graded **DIVERGES (documented)**, on the rationale that the port had
deliberately replaced a transform keyframe with a vertex deformation. That
rationale is now false: `df3cc64` built all three at the source's own amplitudes
and periods, composed alongside the mesh layer exactly as the reference runs both.

The census is not at fault for this and the method is sound; its own write-up
already names the limit, that a MATCH does not prove the motion landed on the
element the player watches, and prescribes "a screenshot or a live capture" as the
remedy. (This doc's §3 argues the first of those two is not enough.) What this learning adds is the precondition that remedy assumes: **a look
is worth only what the surface being looked at is worth**, and for a behaviour with
no capture mode there is nothing to look at. Enumeration establishes what should
exist; a production-faithful, mode-complete harness establishes what does. Neither
half is sufficient, and here the first ran without the second.

### Wrong verdicts propagate into the documents people trust most

`docs/actor-animation-checklist.md` is the port's per-behaviour ledger; before
2026-07-27 its cast-shadow entry read as a sympathetic pass — the constants were
checked against the reference and the approach was endorsed as a derive. Every
future reader of that entry would have concluded the shadow was done. Nothing in
the entry was dishonest; it answered the question it had asked, which was about
numbers, while both defects were about scheduling. The correction is now the
longest passage in §2 (`docs/actor-animation-checklist.md:281-289`) and a whole new
section in the pattern doc it had been cited by
([`derive-authored-compensations-when-porting.md`](../design-patterns/derive-authored-compensations-when-porting.md)).
Two documents had to be amended because one instrument had been trusted past what
it measured.

There is a compounding effect specific to the missing capture mode, and it is the
worst of the three. A defect with a capture mode gets fixed on the day someone
looks. A defect with no capture mode is not a backlog item; it is not anywhere. The
per-kind idle layer had been missing since the actor was built, and the reason it
survived every prior audit is that no instrument in the project could have raised
it. The blast radius was larger than one layer: the same session found that the
actor entrance had been running **two** concurrent animations — one moving the
body inside its 3D sub-viewport with the correct stagger, one moving the whole
Control with the correct curve and the chrome — and neither looked broken in a
still. That is now one function:
`presentation/combat/enemy_view.gd:2858` (`enter`) owns the motion and the fill,
`presentation/combat/combat_screen.gd:1353` (`_play_entrance`) owns the seat
delay and the re-anchor. It was found the same way, by giving a category of
behaviour an instrument and then reading a number off it.

Finally, note what this costs to prevent. The lab defect was one line. The missing
capture mode was one frame table and one `if` branch — `IDLE_FRAMES`
(`presentation/lab/enemy_lab.gd:1469` (`IDLE_FRAMES`)) and the
`_mode == "idle"` dispatch (`presentation/lab/enemy_lab.gd:1306-1313`, in
`_ready`),
reusing `_shoot_strip` unchanged. The expensive part was never the tool. It was
the parity work performed against a surface nobody had checked was telling the
truth.

## When to Apply

- **Whenever a lab, fixture, sandbox, or preview surface constructs the same
  object production constructs.** Diff the call sequences *and the argument
  values* before you trust a verdict taken from it. This is the highest-yield
  check in the list and it costs a `grep`.
- **Before recording a verdict in a shared audit document.** State which
  instrument produced it. "Constants compared against the reference" and "watched
  it run and measured X" are different verdicts and must not share a word.
- **Whenever a claim is of the form *A tracks B*, *A resyncs every frame*, or *A
  responds to C*.** These are per-frame claims. They cannot be settled by a still,
  by reading the function, or by checking the coefficients — only by a
  multi-frame capture with B or C actually moving.
- **Before adding any speed knob to a capture harness.** Find the subject's clock
  first. `Engine.time_scale`, fake timers, and injected clocks all reach exactly
  one timebase; a subject that reads a wall clock, a system counter, or an audio
  clock is out of reach, and a subject that reads two clocks cannot be slowed
  coherently at all.
- **When auditing tool coverage.** Enumerate by category of behaviour — one-shot
  beat, loop, steady state, response-to-input, response-to-another-value — and
  look for the categories with no instrument. Do not enumerate by number of
  fixtures.
- **Not as a reason to build an instrument per behaviour.** `--idle` earned its
  place because a loop is a distinct shape that five beat modes structurally could
  not sample. A sixth mode that photographed a beat slightly differently would not
  have.

## Examples

### The lab defect, before and after

Before, `_actor` built and placed and stopped:

```gdscript
var view: EnemyView = EnemyView.new(0, display, hue, StringName(id))
view.position = Vector2(x + view.foot.x, ground - view.size.y - view.foot.y)
```

`EnemyView`'s construction path resolves the humanoid profile
(`presentation/combat/enemy_view.gd:2642` (`_read_idle`)), so `gloomslime` —
`art.kind == "slime"`,
whose profile is `sway .55, bob .55, breathe 1.35, head 0, pin 1.2, float .25`
(`presentation/combat/enemy_view.gd:520`) — rendered with `sway 1.0, bob 1.0,
breathe 1.0, head 1.0,
float 0` and no kind idle at all. After, one line reproduces what
`presentation/combat/combat_screen.gd:1263` (in `start_encounter`) does, and
the comment above it
names that line so the two can be diffed rather than rediscovered
(`presentation/lab/enemy_lab.gd` (in `_actor`)).

### Why `--idle` could not be a slowed strip

The pattern every other strip follows, and the one that would have failed here:

```gdscript
# WRONG for the idle. `Engine.time_scale` scales `delta`; the kind-idle clock is
# `Time.get_ticks_msec()` (`presentation/combat/enemy_view.gd` (in `_process`)),
# which it cannot reach. Six cells
# would photograph the same instant six times and read as a still creature.
Engine.time_scale = CRACK_SLOMO  # 0.06 — presentation/lab/enemy_lab.gd:1382
var wall: Array[float] = []
for t: float in IDLE_FRAMES:
    wall.append(t / CRACK_SLOMO)
await _shoot_strip(wall, "idle", ...)
```

What is in the tree instead — real time, six cells spaced 0.84s apart across one
full 4.2s `idleSlime` period, wide enough that a viewport readback per cell keeps
up without any clock trickery
(`presentation/lab/enemy_lab.gd` (in `_ready`), against
`presentation/lab/enemy_lab.gd` (`IDLE_FRAMES`)):

```gdscript
await _shoot_strip(IDLE_FRAMES, "idle", func(_v: EnemyView) -> void: pass)
```

The action callable is empty, which is itself the point: a beat strip has to
*trigger* something, and a loop strip has to trigger nothing and simply wait long
enough. That structural difference is why five beat modes could not have been
stretched to cover this one.

### Signatures, not "it moved"

Once `--idle` existed, each shape was confirmed by a number chosen in advance to
distinguish it from its neighbours. These are this session's measurements off the
strips; they are not recorded in the tree and are not reproducible from it without
re-running the captures.

| Command | Kind | Predicted signature | Measured |
| --- | --- | --- | --- |
| `--idle=gloomslime` | slime → `idleSlime` | bounding-box **width** swings, tracking `scaleX` | 6.8% against the authored 7.2% (`SLIME_SX` 1.04 → 0.97, `presentation/combat/enemy_view.gd:586`) |
| `--idle=voltEel` | serpent → `idleSway` | bright **centroid** swings, bounding-box width does **not** | confirmed — translate plus rotate, not a scale |
| `--idle=waylayer` | rogue → `idleBreathe` | **height** moves, width does not | confirmed — what `scaleY` alone looks like (`BREATHE_SY` 1.025, `presentation/combat/enemy_view.gd:589`) |

The 6.8-against-7.2 shortfall is the expected shape of agreement rather than a
miss: six evenly spaced samples across a period will land near, not on, the
extrema. What the table would have caught is the failure a
did-anything-change test passes — a serpent whose width swung, or a slime whose
height did.

Two further measurements from the same session are recorded in the tree. On
`--enter`, the actor's bright centroid travels 79.6 canvas px on an ease-out
profile **and the name plate and HP rail travel with it**
(`docs/actor-animation-checklist.md:64-65`) — the second clause is the whole
verification, because the defect was that the chrome used to stand at the
destination waiting for the painting. And for the shadow, on `watcherEye` over
eight frames of its own hover, shadow mass swings 22.3k → 28.3k while its centroid
travels 11.4px (`docs/actor-animation-checklist.md:301-303`). A frozen
`_update_shadow` scores zero on both. A shadow whose only input was the export
border would have scored the wrong sign on the first: most response on
`shellback`, a crab flat on the floor at 20.7% margin, and almost none on
`voidWisp`, a wisp at 4.3%.

### The audit verdict that could not have been right

The pattern doc's shadow table had ended with a claim that reads perfectly and
measures nothing:

> Float behaviour arrives free: a creature whose lowest opaque pixel sits above
> the ground line gets a smaller, fainter, softer shadow, because the alpha scan
> already measured the gap.

The scan was real
(`presentation/combat/enemy_view.gd:2064` (`_read_contact`)), the projection
was real (`presentation/combat/enemy_view.gd:2246` (`_update_shadow`)), and the
quantity was a framing border rather than a gap
(`presentation/combat/enemy_view.gd:2063`, in `_read_contact`; the variable is
now named `_art_pad` at `presentation/combat/enemy_view.gd:738` for exactly
this reason). A
constants audit cannot see that, because every constant was fine. Only a
multi-frame capture with the body actually rising can, and until `--idle` and the
per-frame call at `presentation/combat/enemy_view.gd:2385` (in `_process`) existed,
there was no way
to make the body rise on a surface anyone was photographing.

## Related

- [Audit a port by enumerating the reference's CSS instead of waiting for someone to notice](../workflow-issues/audit-port-by-enumerating-reference-css.md)
  — the complement, and the pair should be read together. That doc makes the
  *reference* enumerable so the gap becomes a count; this one makes sure the
  *instrument* you check the count against is telling the truth. Its fourth honest
  limit — that a MATCH does not prove attachment, and a capture still has to
  confirm the motion landed on the element the player watches — is the rule this
  doc supplies the missing precondition for. `docs/motion-census.md` rows 1612-1618
  are the worked case where the two halves meet.
- [Derive authored compensations instead of transcribing them when porting](../design-patterns/derive-authored-compensations-when-porting.md)
  — the shadow's design rationale, and the doc this learning forced a correction
  into: see its "Correction, 2026-07-27" section. Its two general lessons —
  derivation moves the risk from the value to the measurement, and a derive can be
  right and dead at the same time — are the same finding seen from the
  implementation side rather than the tooling side.
- [Capture through a long-lived host, not a process per screenshot](./long-lived-capture-host-not-process-per-shot.md)
  — the sibling tooling lesson, and the closest prior statement of this idea: "a
  harness that synchronises on the healthy state has defined the unhealthy state
  out of its own observation window." A harness that drives the subject
  differently from production is the same error one level up, and a harness with
  no mode for a category of behaviour is that error one level up again — it hides
  a whole class rather than one instance.
- [Godot Label placement guessed at font height instead of measuring it](../ui-bugs/godot-label-placement-guessed-font-height.md)
  — the same distortion with the opposite sign: there the lab's own magnification
  manufactured a defect that was not in the chip. A lab misleads in both
  directions, which is the general case this doc argues from.
- [The hero's ward stone never answered a blow it stopped](../ui-bugs/hero-ward-stone-never-answered-the-blow.md)
  — the case that forced §1's argument clause. The harness made the same call
  production makes and passed a constant where production derives a value, so it
  cleared the method check and still certified a premise it had supplied itself.
  Read together, the two docs are the same rule at two grains: *which* calls, and
  *with what*.
- `CONCEPTS.md` › **Lab** — where the vocabulary lives. This learning records
  the production-driving, capture-mode, timebase and exposure constraints that
  make a Lab trustworthy.
- `docs/actor-animation-checklist.md` — §1.1 Entrance, §1.2 Idle and §2 Cast
  shadow. The ledger
  these corrections landed in.
- `presentation/lab/enemy_lab.gd` — the harness: the profile call
  (`presentation/lab/enemy_lab.gd` (`_actor`)), the strip dispatch
  (`presentation/lab/enemy_lab.gd` (`_ready`)), the frame tables and the shared
  capture loop (`presentation/lab/enemy_lab.gd` (`_shoot_strip`)).
- `presentation/combat/enemy_view.gd` — the subject:
  `presentation/combat/enemy_view.gd` (`set_profile`), the two clocks and kind
  idle in `presentation/combat/enemy_view.gd` (`_process`), and the per-frame
  shadow resync in `presentation/combat/enemy_view.gd` (`_update_shadow`).
- Commits reachable from `main` that carry this learning: `bf7b751`
  (`feat(actors): the shadow answers the height, and the floaters have one`) and
  `df3cc64` (`feat(actors): the rest of the kind idle, and one entrance instead of
  two`).
