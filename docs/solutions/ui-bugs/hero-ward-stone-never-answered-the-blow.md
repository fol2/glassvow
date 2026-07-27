---
title: "The hero's ward stone never answered a blow it stopped, because only one of two mirrored branches made the call"
date: 2026-07-27
category: ui-bugs
module: presentation/combat/combat_screen
problem_type: ui_bug
component: rails_view
symptoms:
  - "A foe that absorbed a blow flinched its ward stone and lit the facets facing the hero; the hero absorbing the identical blow showed no stone movement at all"
  - "A guarded hero and an unguarded hero were the same picture apart from the numeral on the ward chip"
  - "No error, no warning, no failing test — both call sites parse, both run, and each reads as complete on its own"
  - "The one instrument built to photograph this beat showed the hero's stone answering correctly, because the lab was making the call the shipping code was not"
  - "Four prior exhaustive parity audits read the file end to end and none of them found it"
root_cause: logic_error
resolution_type: code_fix
severity: high
related_components:
  - tooling
  - testing_framework
tags: [godot, combat, ward, enemy-view, mirrored-branches, paired-calls, blind-instrument, hard-coded-parameter, screen-space-direction, parity-audit-blind-spot]
---

# The hero's ward stone never answered a blow it stopped

## Problem

`EnemyView` is one actor class serving two roles. The foes are built from it and
so is the hero, which is why the ward stone — the faceted gem shell held in front
of a guarded creature (`CONCEPTS.md` › **Ward stone**) — exists on both without
anyone having written it twice.

Two calls fire together when a warded creature eats a blow, and they are
deliberately two:

- `take_hit(direct)` — the BODY recoiling from being struck.
- `ward_hit(from)` (`presentation/combat/enemy_view.gd:2490` (`ward_hit`)) — the
  STONE answering for having stopped it: it rings the facets facing the blow and
  drives the shield back along it.

The separation is not accidental and it is not undocumented. `ward_hit`'s own
docstring says why, in as many words:

> Separate from `take_hit` and not folded into it, because the two are different
> events that happen to coincide: the body recoils from being struck, and the
> shield answers for having stopped it. A creature with no ward gets only the
> first, and calling this on one is a no-op rather than a caller's problem.

That last clause is real: the function returns immediately when there is no stone
(`presentation/combat/enemy_view.gd:2491`, in `ward_hit`), so the call is safe to
make unconditionally on any actor.

The combat sequencer has two mirrored paths for the same beat: `_hit_enemy` is the
hero attacking a foe, `_hit_player` is a foe attacking the hero. Both live in
`presentation/combat/combat_screen.gd`.

> **Cited by symbol, not by line.** Every `combat_screen.gd` reference in this doc
> names the function and omits the line number on purpose. That file was under
> concurrent edit by another lane while this was written — it grew by 142 lines
> (+217 / −75) between `HEAD` and the working tree in the same hour — so any
> number here would have been a claim against an uncommitted state that was never
> true at any commit. `grep -n 'func _hit_enemy\|func _hit_player'` is the durable form. The
> four audits described below hit the same moving file and each re-pinned to a
> committed blob for the same reason.

`_hit_enemy` made the pair. Inside its `if blocked > 0:` branch it calls
`view.ward_hit(Vector2.LEFT)` directly under a comment explaining the pairing to
whoever reads it next. `_hit_player` made only `take_hit` and stopped.

So a foe that ate a blow flinched its shield and lit the facets facing the hero.
The hero ate the identical blow and its stone did not move. A guarded hero and an
unguarded hero were the same picture apart from the numeral on the Ward chip.

## Symptoms

- The hero's ward stone sat perfectly still through every absorbed hit, while a
  foe's stone visibly flinched and rang on the same event type.
- Guarded and unguarded hero states were visually indistinguishable during a
  foe's attack; the only difference was the chip numeral.
- No error, no warning, no failing test. Both call sites parse, both run, and
  each reads as complete on its own.
- The one instrument built to photograph this beat — the enemy lab's
  `--ward --absorb` strip — showed the stone answering correctly for heroes,
  because the lab was making the call the shipping code was not.

## What Didn't Work

Being honest about the route matters more here than the fix does, because the fix
is two lines and the route is the transferable part.

**Reading the code did not find it.** The asymmetry had been sitting in two
functions a hundred lines apart, each with a comment above the relevant branch,
through every prior pass over this file. Both branches look finished. Nothing in
`_hit_player` is missing in a way a reader notices — you have to already be
holding `_hit_enemy` in your head to see the gap.

### Four exhaustive parity audits read this file and could not have found it

This is the sharpest part of the case, and it comes from prior sessions rather
than from this one. On 2026-07-26, four independent combat control-flow audits
ran over `presentation/combat/combat_screen.gd`, each instructed to read it to
EOF and compare it against the reference combat controller and drain, tracing
battle start to battle end and reporting every divergence with a
`file:line`. Between them they used adversarial and correctness-review methods
and spawned read-only specialists. They found real defects — stale targeting
surviving end-turn, played cards removed before their handlers could animate
them, deck and pile signals `CombatScreen` never connects.

None of them found this. (session history)

They could not have, and the reason is structural. Checked at the benchmark —
commit `6e06911`, which is a commit of the *reference* repository and resolves in
that checkout, not in this one — the port's `_hit_player` **matched the reference
exactly**:

- `roguecardv2-benchmark src/ui/drain.js:587` `case 'hitPlayer'` — its
  `if (ev.blocked > 0)` branch runs a sound, a float, a burst and the
  guard-shattered pair. There is no ward call in it.
- `roguecardv2-benchmark src/ui/combat.js:72` `syncWardMesh(el, on, grow)` — the
  reference's *entire* ward-mesh vocabulary is three states: on, off, and
  on-with-grow. It has no per-blow ring or flinch anywhere, for either combatant.

(Both paths are in the benchmark checkout, not this repo — see the project
contract for where it lives and how to confirm the commit.)

`ward_hit` is port-invented, added for the Godot cut-gem ward that replaced the
benchmark's `meshWard`. The port's `_hit_player` was a faithful port; the
asymmetry was created later, when `ward_hit` was added to `_hit_enemy` alone.

**A divergence-from-reference audit cannot see an asymmetry inside behaviour the
reference does not have.** Both branches matched the reference. They just did not
match each other, and nothing in a parity audit's frame asks that question.

### Rapid screenshotting the live fight could not have judged it either

The first move was to boot a real fight, play a Ward card and photograph the hero
mid-blow. That failed for a measurable reason: the ring decays over `WARD_RING`,
200 ms (`presentation/combat/enemy_view.gd:239` (`WARD_RING`)), against a
live-host screenshot round trip of roughly half a second (per this session's
measurement). The live host could confirm the stone was RAISED. It could never
have confirmed whether the stone RANG. Sampling was not close.

That boot was not wasted, and it is what made the next step worth taking. It
confirmed the ward is genuinely wired for battle rather than partly stubbed: the
`BLOCK_GAIN` handler raises the stone for the hero and for foes alike, the break
fires when block reaches zero, and the mid-combat restore works
(`combat_screen.gd` › `_restore_ward_shell`). With the
subsystem established as live, an absent effect had to be an absent *call*.

### Only then did enumerating the call sites find it

One grep over the shipping tree, excluding lab and test:

```bash
grep -n 'take_hit\|ward_hit' presentation/combat/combat_screen.gd
```

Which prints the pairing in `_hit_enemy` and, before the fix, a bare `take_hit`
in `_hit_player` with no `ward_hit` under it. The defect is legible in
nine lines of grep output and invisible in the two functions themselves.

## Solution

Two changes, one to the shipping path and one to the instrument that should have
caught it.

**1. `_hit_player` now makes the pair, mirrored.**

```gdscript
if _hero != null:
    _hero.ward_hit(Vector2.RIGHT)
```

in `_hit_player`, under a comment that states both halves of the reasoning.

`RIGHT`, not the default, and this is the dangerous half of the fix. `from` is a
screen-space heading pointing from the creature toward whoever struck it. It
drives the shield AWAY from that side — the flinch is computed as `-_ward_from`
scaled by the decaying ring and `WARD_FLINCH`
(`presentation/combat/enemy_view.gd:2591`, in `_step_ward`;
`presentation/combat/enemy_view.gd:240` (`WARD_FLINCH`)) and applied to
`_ward_root.position` on top of the vessel's own motion — and it lights the
facets ON that side, through the shader's `hit_from` uniform
(`presentation/combat/enemy_view.gd:1216` (`hit_from`)) weighting the ring term
by `dot(axis, -hit_from)` (`presentation/combat/enemy_view.gd:1418`).

`ward_hit`'s default is `Vector2.LEFT`
(`presentation/combat/enemy_view.gd:2490` (`ward_hit`)), correct for a foe struck
by the hero, who stands on the foe's left. The hero is struck from the RIGHT.
Passing the default would have driven the hero's stone INTO the blow — a wrong
value that still renders as a plausible effect, which is the failure mode that
survives review.

**2. The lab derives the heading instead of hard-coding it.**

```gdscript
var from: Vector2 = Vector2.RIGHT if HEROES.has(_strip_id) else Vector2.LEFT
```

at `presentation/lab/enemy_lab.gd:1386` (in `_ready`), consumed by the strip's
action callable two lines below. `HEROES`
(`presentation/lab/enemy_lab.gd:156` (`HEROES`)) is the lab's own two-hero
roster — `duskblade` and `ashwarden` — and `_strip_id`
(`presentation/lab/enemy_lab.gd:110` (`_strip_id`)) is the subject being
photographed.

**Verification.** Two slowed strips from the same lab mode, compared at cell 1:
the foe's stone is driven right, the hero's is driven left. The mirror is correct
in both. The strip is the only surface that could settle this — it runs at
`Engine.time_scale = CRACK_SLOMO`, 0.06
(`presentation/lab/enemy_lab.gd:1442` (`CRACK_SLOMO`)), against a frame table
sized to the 200 ms ring rather than the 340 ms break
(`presentation/lab/enemy_lab.gd:1461` (`WARD_ABSORB_FRAMES`)).

The work landed directly on `main` — there is no PR — in
`fix(combat): the hero's ward stone never answered a blow it stopped`.

## Why This Works

The stone's response is a single decaying scalar plus a direction, and both are
set by the one call. `ward_hit` writes `_ward_hit = 1.0` and normalises `from`
into `_ward_from` (`presentation/combat/enemy_view.gd:2493-2494`, in `ward_hit`).
`_step_ward` (`presentation/combat/enemy_view.gd:2545` (`_step_ward`)) then does
everything else on its own clock: it decays `_ward_hit` linearly by
`delta / WARD_RING`, offsets `_ward_root` along `-_ward_from`, and pushes the
squared value to the shader
(`presentation/combat/enemy_view.gd:2597`, in `_step_ward`). Nothing else in the
frame needs to know a blow was absorbed. That is why one missing call removes the
entire effect with no other trace, and why one added call restores all of it.

The direction argument works because it composes rather than replaces. The flinch
is added to `_vessel.position` rather than overwriting it
(`presentation/combat/enemy_view.gd:2592`, in `_step_ward`), so the stone travels
with the body's recoil and is *additionally* driven back along the blow. The
body's recoil axis and the shield's are different axes for a reason: a body is
knocked back by force, a shield is driven back by where it was struck. Mirroring
one and not the other would have been wrong in a subtler way.

And it works for the hero specifically because `EnemyView` never had a foe-only
assumption in the effect itself — only in the *caller's* choice of constant. The
class was already correct for both roles. That is exactly the shape of bug a
shared class invites: the shared code is fine, and the divergence lives in the
two call sites nobody diffs.

## Prevention

### 1. The paired-call rule: the pairing lives in a comment on one site and nothing enforces it at the other

`_hit_enemy` carried a comment explaining why `take_hit` and `ward_hit` are two
calls rather than one. That comment is genuinely good and it did not help,
because it was a hundred lines away from the site that needed it. A comment
documents an invariant; it does not enforce one, and it does not travel to the
sibling.

When two calls must fire together, the check is mechanical and costs one command:

```bash
grep -rn 'take_hit\|ward_hit' presentation/combat/combat_screen.gd
```

Read the output as pairs. Every `take_hit` in a `blocked > 0` context with no
`ward_hit` beside it is either a bug or a decision that has to be written down as
one. There are legitimate singletons here — the poison and shatter paths call
`take_hit(false)` for a flash with no shove — and the point of the grep is that
you have to *say* which those are, not that pairs are mandatory.

This is the "grep the call sites" half of the repo's standing lesson made
concrete: *matching constants prove nothing — the reference's call may draw
nothing, the port's may never run; count pixels, and grep the call sites*
(auto memory [claude]). Here it was neither a constant nor a dead function: it
was a live function with one caller too few.

### 2. "Built and left unplugged" already had a name here, and this variant still got through

The repo had already named this failure mode and written it down. One session hit
it five times in a day, and the list opens with *"a `take_hit()` the combat screen
never called"* — the same method, the same file pair, one branch over
(`docs/solutions/tooling-decisions/drive-the-lab-the-way-the-game-drives-it.md`).

So why did naming it not prevent this? Because every prior instance was **a call
nobody made at all**, and that shape is found by grepping for the call and
getting nothing. This one is **a call one branch makes and its mirror does not**,
and the same grep finds it present and moves on. The remedy for the documented
variant actively passes the undocumented one.

The generalisation worth carrying: when a failure mode is named, ask what its
*near-miss* looks like. "Never called" and "called from half the places it should
be" produce identical symptoms and are separated by exactly one habit — reading
grep output as a set of pairs rather than as a presence check.

### 3. A lab that hard-codes the parameter under test is a second copy of the assumption

The enemy lab's `--ward --absorb` mode exists specifically to photograph this beat
at a slowed clock. It hard-coded `v.ward_hit(Vector2.LEFT)` for every subject,
including the two heroes on its own roster
(`presentation/lab/enemy_lab.gd:156` (`HEROES`)). So the one instrument built to
judge this beat:

- **could not surface the missing hero call**, because it drove `ward_hit`
  itself — on the bench the hero's stone always answered; and
- **could not have caught a wrong direction either**, because it hard-coded the
  very constant that had to mirror.

Stated generally: **a lab that drives the subject with a constant the shipping
code derives cannot validate the derivation.** It can only validate the effect
downstream of the constant. If the parameter is the thing that might be wrong,
the lab has to compute it the way production computes it, or the lab is testing a
premise it also supplied.

This is the rule from
[Drive the lab the way the game drives it](../tooling-decisions/drive-the-lab-the-way-the-game-drives-it.md)
applied to a *parameter* rather than to a *timebase* — and the lab violated it
while carrying the lesson. That doc's §1 already says to enumerate the calls
production makes on the subject and assert the harness makes the same ones. The
harness did make the same call. It passed a different argument, and the argument
was the whole question. Extend the §1 check accordingly: diff the call *sequence*
and the *arguments*, and treat any literal in a harness that is a derived value in
production as a finding until it is justified in a comment.

### 4. Mirrored-branch checklist for anything the hero and foes share via one actor class

`EnemyView` is used for both roles, so every effect on it has two call sites that
must agree in structure and disagree in orientation. Before calling any such
effect done:

- **Both sites present?** List the effect's callers. A call in the hero path with
  no counterpart in the foe path (or the reverse) is a bug until argued
  otherwise. A test or capture that exercises only one branch cannot see this —
  and asymmetries survive precisely because both branches look complete on their
  own.
- **Orientation mirrored, not copied?** Any screen-space direction, sign, or
  offset is `LEFT` on one side and `RIGHT` on the other. Copying the sibling's
  literal is the single most likely error, and it is the one that still renders
  as a plausible effect rather than as nothing.
- **Is the behaviour port-invented?** If the reference has no counterpart, no
  parity audit will ever check it — for either branch. Port-invented behaviour
  needs its own symmetry check because the usual safety net does not reach it.
- **Can the instrument tell the two apart?** If the harness would photograph both
  roles identically, it cannot certify the mirror. Two strips side by side, with
  the mirrored quantity visibly opposite, is the cheapest sufficient check.
- **Is the beat within the instrument's sampling window?** A 200 ms decay against
  a half-second screenshot round trip is unmeasurable in the live host regardless
  of how carefully it is driven. Match the instrument to the beat's duration
  before concluding anything from a capture.

## Related Issues

- [Drive the lab the way the game drives it, and photograph loops as well as
  beats](../tooling-decisions/drive-the-lab-the-way-the-game-drives-it.md) — the
  lab-fidelity doc this one extends from timebase to parameter. Its §1 (enumerate
  production's calls on the subject) and its §2 (a category of behaviour with no
  capture mode is a finding) are both live here; this case adds the third
  variant, where the mode exists, the call is made, and the *argument* is the
  fiction. It is also where "built and left unplugged" is named.
- [A flat billboard has one depth, so a four-footed shadow planted one
  foot](flat-billboard-shadow-had-one-ground-line.md) — the same actor and the
  same session lineage; another defect that a still frame could not falsify.
- [Audit a port by enumerating the reference's CSS](../workflow-issues/audit-port-by-enumerating-reference-css.md)
  — the complement, and the limit this case marks on it: enumerating the
  reference finds everything the reference has. It finds nothing about behaviour
  the port invented, which is where this bug lived.
- `CONCEPTS.md` › **Ward** — the three distinct terms this doc uses precisely:
  *Ward* is the protection, the *Ward chip* is the numeral beside the health
  vial, the *Ward stone* is the gem shell.
- No GitHub issues: `gh` is authenticated against `fol2/glassvow` and the
  repository carries no issues, open or closed.
