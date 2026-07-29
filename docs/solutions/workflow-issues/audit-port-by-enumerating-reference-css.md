---
title: Audit a port by enumerating the reference's CSS instead of waiting for someone to notice
date: 2026-07-27
last_refreshed: 2026-07-29
category: workflow-issues
module: port/audit
problem_type: workflow_issue
component: development_workflow
severity: high
applies_when:
  - Porting a feature from a platform with different animation capabilities
  - Visual parity divergences need systematic auditing rather than waiting for noticed issues
  - Working with CSS-based animation reference material
  - Parallel auditing is needed to check a large surface area against a frozen reference
tags: [port, audit, css, animation, parity, workflow, verification, methodology, web-reference, parallel-auditing]
---

# Audit a port by enumerating the reference's CSS instead of waiting for someone to notice

## Context

Glassvow is a parallel port of a web deckbuilder into Godot 4.7. Parity is checked
against a frozen web reference — `~/Coding/roguecardv2-benchmark` at commit
`6e06911` (2026-07-13), the pre-Pixi checkout this project treats as authority.
Until the motion census, divergences from that reference were found the way a
person finds dust on a shelf: by looking at the screen and noticing that
something was wrong.

> **Citation convention.** Throughout this doc, `src/styles.css` and the SHA
> `6e06911` belong to the **reference** repo, not to glassvow. A claims validator
> run against this repository will flag both as unresolvable; that is expected
> and correct. Bare SHAs without a repo (`2c683fa`, `4e78410`, …) are glassvow's
> and are reachable from `main`.

That method found real bugs. The hand's resting fan hung off the wrong edge
(`13f9536`). A card appeared in its pose instead of travelling to it
(`8101382`). The intent chip had no ceiling and the HP rail had no floor
(`a9eb324`). Each fix was correct for the thing it touched. None of them said
how many other things were still wrong, or which of those things a player would
see first. The judging step — deciding what mattered — was being done by whoever
happened to look, in the order they happened to look. Geometry got measured
because someone went looking for boxes (`docs/battlefield-parity.md` and the
sixteen-box audit). Durations did not, because nobody had asked for a list of
every animated property on the combat surface.

The failure was not laziness. It was an incomplete question. Asking "does this
look right?" can only return the defects that fall inside the frame you are
looking at. Asking "which animated declarations exist, and which of them does
the port answer?" returns a countable gap. The reference's combat motion lives
in CSS, and CSS is enumerable: every transition and every animation is a
declaration with a selector, a duration, an easing curve, and — for
`animation` — a `@keyframes` body. There are a fixed number of them. They can
all be extracted mechanically, and each one is then a single yes/no question for
the port.

This conclusion had a lineage, and the lineage is worth recording because it
shows where the method comes from. (session history) Sessions on 2026-07-24
through 07-26 had already hit the ceiling of the obvious approach: pulling
computed styles off the running benchmark with `getComputedStyle()`. That is
reactive by construction — you only learn about the properties you already knew
to ask for, and a rarity-tinted card variation nobody suspected existed is
invisible to it however carefully you sample. Those sessions moved to reading
`src/styles.css` directly, and one pass through the source surfaced six details
that piecemeal sampling had missed (`5ba0f63`). They then named the gap in so
many words: the missing piece was tooling that enumerates `animation:` and
`transition:` declarations as a first-pass discovery mechanism. The census is
that tooling. The idea was two days old before anyone built it, which is its own
small argument for writing methods down rather than re-deriving them.

The first census run on combat is the proof that the prior method was leaving
work on the table. Extraction from `src/styles.css` at `6e06911` found 1297
rules, 45 `transition` declarations, 108 `animation` declarations and 70
`@keyframes` bodies. Filtered to the combat surface that left 78 declarations,
of which 67 are live (the other 11 are `prefers-reduced-motion` overrides).
Sixty-two of those live ones fall on the combat screen proper. Of those
sixty-two, twenty-two — **35%** — had no implementation in the port at all;
twenty-three matched, ten diverged, one diverged on purpose and the port said
why, five were N/A because the rule never fires in the reference or drives a
renderer the port does not use, and one was unresolved because the audit had
answered a different question. The numbers are in `docs/motion-census.md`,
landed in `2c683fa` and corrected in `da8ffa2`. The first item on the ranked
fix list — the two HP rails that snapped while their ghost already glided —
was closed in `4e78410`.

**The verdict table in the census is the authority for that split, not this
paragraph.** It moves: the 2026-07-27 amendment regraded three rows from
*diverges on purpose* to *match*, and this document carried the pre-amendment
figures until a refresh caught it. A method document that restates numbers it
does not own will drift from them — cite the table, and re-read it before
quoting a count.

## Guidance

Treat the reference stylesheet as a finite set, not a scrapbook. The extraction
shape that produced the census is deliberately boring, so it can be re-run
without inventing judgement:

1. Strip comments from `src/styles.css`, keeping newline counts so line numbers
   stay true against the frozen tree.
2. Walk every `selector { flat body }`. Pull every `animation:` and
   `transition:` property.
3. Resolve each animation name against the `@keyframes` bodies in the same
   file, so a row carries duration, easing, and the keyframe stops that
   actually move.
4. Record whether the rule sits inside a `prefers-reduced-motion` block; those
   rows are live overrides, not second copies of the motion.
5. Filter selectors to the surface under audit (combat, shop, reward — one
   surface at a time).

That produces the census rows. The audit that judges each row against the port
is a separate contract, and it is the part that failed when people only looked
at screenshots. Every verdict must quote the port's literal code with
`file:line`. A verdict with no quoted evidence is rejected, even when the
auditor is sure. Parallel audits are fine — the first census used five — but
the assembling session re-checks any row whose verdict looks wrong or whose
absence would be expensive if missed. Rows the assembler re-checked by hand are
marked in the table; the rest stand on the quoted evidence alone.

The brief each auditor answers is one question per declaration: *does the port
do this, with these numbers?* The allowed answers are the census vocabulary —
MATCH, DIVERGES, DIVERGES (documented), ABSENT, N/A, UNRESOLVED — and nothing
else. MATCH means the port does the motion with the same numbers. DIVERGES
means it does something with different numbers. DIVERGES (documented) means the
difference is deliberate and the port says why in its own comments. ABSENT
means there is no implementation. N/A means the reference declaration does not
fire, or drives a renderer the port has replaced. UNRESOLVED means the audit
answered a different question — usually because it matched a tween on element
Y against a transition on element X — and needs a second look rather than a
guess.

Two checks belong in the brief before any ranking happens, because both fooled
the first run:

```css
/* styles.css:696 — looks live */
.stage-breath {
  /* ... */
  animation: breath 7s ease-in-out infinite alternate;
}

/* styles.css:719 — brace depth 0, always applies, kills it */
.stage-ledge, .stage-breath { opacity: 0; animation: none; }
```

A later top-level rule that says `animation: none` silently kills an earlier
one. An audit that reads only the first declaration will report a defect where
the reference shows nothing. Check the brace depth of every override before you
write ABSENT.

```css
/* styles.css:619 — transition on .hand-zone .card */
.hand-zone .card {
  transition: transform 0.28s cubic-bezier(0.25, 0.9, 0.3, 1.2),
              filter 0.2s, opacity 0.12s;
}

/* styles.css:609 — grey-out is on .card-inner, not on .card */
.card.unplayable-now .card-inner {
  filter: saturate(0.35) brightness(0.7);
}

/* styles.css:632 — .card-inner's own transition has no filter */
.hand-zone .card .card-inner { transition: box-shadow 0.2s; }
```

A transition is only worth what the classes that trigger it are worth. Ranking
by the transition alone ranked a no-op second; tracing the trigger corrected
the ranking and surfaced a missing appearance instead. Put the trigger classes
in the audit brief next to the transition, or the ranking will invent urgency.

On the port side, answer a CSS duration with a named constant and a tween that
reads it, not with an assignment that happens to land on the final value. The
HP rails are the worked shape:

```gdscript
# presentation/combat/hud_bar.gd:80-82 — two rails, two durations, one curve
const HP_BAR_TIME: float = 0.4
const HP_PLATE_TIME: float = 0.35
const HP_EASE: Array[float] = [0.3, 1.0, 0.4, 1.0]
```

```gdscript
# presentation/combat/hud_bar.gd:643 (_glide_hp) — travel; first sync snaps
func _glide_hp() -> void:
	if not _hp_seeded:
		_hp_seeded = true
		_set_hp_bar(1.0, _hp_ratio, _hp_ratio)
		if _plate_rail != null:
			_set_hp_plate(1.0, _hp_ratio, _hp_ratio)
		return
	_hp_bar_tween = create_tween()
	_hp_bar_tween.tween_method(_set_hp_bar.bind(_hp_shown_bar, _hp_ratio),
		0.0, 1.0, HP_BAR_TIME)
	# ...
	_hp_plate_tween.tween_method(_set_hp_plate.bind(_hp_shown_plate, _hp_ratio),
		0.0, 1.0, HP_PLATE_TIME)
```

The census row named the defect; the constants and the first-sync guard are
what closing it looks like. Do not invent a second method for the next row.
Extract, audit with evidence, rank by how often a player sees it, then fix.

## Why This Matters

Enumeration wins because it changes the unit of work from "whatever looks off"
to "every declaration in scope." The prior method could not have produced the
sentence "twenty-two of sixty-two animated things on the combat surface are
not implemented," because it never held the sixty-two. Once the set is finite,
the gap is a percentage rather than a feeling. Thirty-five percent absent is
not an estimate from a tired playthrough; it is a count against a frozen file.

The shape of that gap matches what this port has shown everywhere else: it is
precise where it was handed a number and thin where it had to notice that a
number existed. Geometry was 16/16 because someone went looking for boxes.
Idle float amplitudes match creature for creature because those numbers sat
next to the paintings. The HP fill durations — 0.4s on the HUD bar
(`styles.css:182`) and 0.35s on the plate fill (`styles.css:834`), both on
`cubic-bezier(0.3, 1, 0.4, 1)` — were sitting in the same file, and both rails
were being assigned. Nobody had gone looking for durations.

What a census buys is the separation between missing and hard. The ranked fix
list in `docs/motion-census.md` puts the HP rails first not because they are
clever, but because they are the most-watched number on the screen and they
snap while the ghost beside them already glides. Next come `.intent.pop` and
`.schip.pop` — `chipPop` is already implemented four times over for the
lantern, energy orb, facet row and pile; those two just never got wired to it.
Then the 0.15s button transitions, then the two `artReady` beacons, then
`targetGlow`. Items one through four are small, and two of them are calling a
function the port already has. Twenty-two missing things is not the same list
as twenty-two hard things. Without the census, the hard ones absorb the
attention and the missing ones wait for another notice.

The human stops being search. Looking at the screen remains the right tool for
asking whether a MATCH looks attached to the right thing, and for art direction
that no declaration encodes. It is the wrong tool for discovering that a
declaration exists. Once extraction has produced the rows, the owner's eyes go
to ranking and to the two caveats — does this fire, and what triggers it —
instead of to hunting. That is the workflow change: notice is for judgement,
not for inventory.

## When to Apply

Apply this when the reference surface is CSS (or another declarative stylesheet
with the same shape), the port claims visual parity with that surface, and
divergences are still being found by playthrough or screenshot inspection. It
is the right move for combat, and it will be the right move for reward, shop
and aspect once those screens are in scope — five of the sixty-seven live
declarations already belong to those screens and were held out of the first
census on purpose. Apply it also when a parallel audit is about to spend
several sessions on "does the port feel right"; spend the first session on
extraction so the later sessions have rows to mark.

The honest limits matter as much as the method:

- **CSS is enumerable.** That is the whole warrant. If the motion lives in a
  stylesheet as `transition` and `animation` declarations, extract them. Do not
  sample.
- **But an enumeration can silently under-enumerate, and this one did.**
  `moteDrift` and its `.idle-motes` carrier have no row in the census at all —
  the extraction missed them (`docs/motion-census.md:155-156`). That is a worse
  failure than a wrong verdict, because a wrong verdict is visible in the table
  and a missing row is not: the census reads complete either way. Enumeration
  buys you completeness *over what the extractor matched*, which is not the same
  as completeness over the stylesheet. Reconcile the extractor's row count
  against a raw count of `transition`/`animation` declarations before trusting a
  total, and treat any denominator as a floor.
- **Static appearance is enumerable the same way, and has not been done.**
  Colour, size, shadow, border and font can be pulled through
  `getComputedStyle` on the live page at `6e06911`. A first sample still needs
  doing. (A draft of this doc claimed `.intent` diverged — 30px in
  the reference against 34 in the port. It does not: the chip is 30. The 34 was
  the crown ROW, which adds a 4px separation to an empty status row. The claim
  was mis-attributed and is withdrawn; the static pass is still owed.)
- **Canvas and WebGL are not CSS.** `vfx.js`, `mesh.js` and the `drain.js`
  timings have to be read from source. The same discipline applies — quote
  `file:line`, do not infer from a function name — but the extractor will not
  see them. The project has already paid for that confusion once: `ring()` and
  `slashArc()` exist in source and never reach the screen, because they push
  particles with no `vx`/`vy` while the draw loop advances `p.x += p.vx * dt`
  unconditionally (`docs/wrong-reference-audit.md`).
- **MATCH does not prove attachment.** A number can agree and still be wired to
  the wrong node. Row 505 in the census is UNRESOLVED for exactly this reason:
  `.card-inner` and the hand seat both animate `transform`, and matching a
  tween on one against a transition on the other is answering a different
  question. Enumeration finds candidates; a screenshot or a live capture still
  has to confirm that the motion landed on the element the player watches.

  That confirming step has two preconditions of its own, and this census was bitten
  by both on the same rows. The surface you capture from must drive the subject the
  way production drives it — the enemy lab did not call `set_profile`, so rows
  1612-1615 were graded the strongest MATCH in the census off a constant that
  resolved to zero on the only sheet anyone would have looked at. And for
  loop-shaped behaviour a *capture mode* has to exist before a confirmation is even
  possible; a still cannot falsify a per-frame claim. See
  [Drive the lab the way the game drives it](../tooling-decisions/drive-the-lab-the-way-the-game-drives-it.md).

Do not apply the method as a substitute for reading the running page when the
question is whether a declaration fires. Brace depth and overrides are visible
in the stylesheet if you look for them; whether a canvas path draws is not.
And do not apply it against `~/Coding/roguecardv2` on `main` — that tree is
284 commits ahead of the benchmark and post-Pixi. The agent contract states the
rule; the census is only meaningful against `6e06911`.

## Examples

### Caveat one: a declaration existing is not evidence it fires

`.stage-breath` declares a seven-second breathing animation at
`roguecardv2-benchmark src/styles.css:696` (`6e06911`):

```css
.stage-breath {
  position: absolute; width: 34cqw; height: 26cqh; border-radius: 50%;
  /* ... */
  animation: breath 7s ease-in-out infinite alternate;
}
```

A first audit marked it ABSENT in the port. It is N/A. At
`src/styles.css:719`, a top-level rule at brace depth 0 kills it for every
viewer:

```css
.stage-ledge, .stage-breath { opacity: 0; animation: none; }
```

The reduced-motion media query at line 717 is a separate override; line 719 is
unconditional. The reference never shows the animation. Reporting a port defect
against a declaration the reference itself disables is the same trap this
project already named for canvas code — a function existing in the source is
not evidence that it renders. The census marks the row N/A and keeps the port's
documented decision to leave the glow off. Check brace depth before you write
ABSENT.

### Caveat two: a transition is only worth what triggers it

Row 619 was first ranked second on the fix list: *the playability grey-out
snaps*. The transition is real, at `src/styles.css:619-622`:

```css
.hand-zone .card {
  transition: transform 0.28s cubic-bezier(0.25, 0.9, 0.3, 1.2),
              filter 0.2s, opacity 0.12s;
}
```

Tracing the classes that change `filter` on a hand card is what corrected the
ranking (`da8ffa2`). The grey-out is
`.card.unplayable-now .card-inner { filter: saturate(0.35) brightness(0.7); }`
at `src/styles.css:609`. That selector targets `.card-inner`. The hand card's
`.card-inner` transition is `box-shadow 0.2s` at `src/styles.css:632` — no
`filter`. So the grey-out is instant in the reference too, and the port writing
`modulate` straight is correct.

What `filter 0.2s` on `.hand-zone .card` actually covers is one class:
`.will-burn` at `src/styles.css:1125`,
`filter: sepia(0.35) saturate(1.45) brightness(1.08)` — the kindle preview.
`opacity 0.12s` covers `.draw-pending` at `src/styles.css:640`, which the port
answers with a flight rather than a fade. The bigger finding replaces the one
it displaced: the port has no `.will-burn` tint at all. `kindle_mode` exists on
`hand_view.gd` and nothing tints the cards it would burn. There is no point
transitioning a filter that is never applied, so 619's filter half is blocked
behind a missing appearance, not a missing animation. Ranking by the transition
alone ranked a no-op second; ranking by the trigger found the real gap.

### Worked example: census entry to fix — the HP rails

The census ranked `.hpbar > .fill` (`styles.css:834`) and `.hud-hpbar > div`
(`styles.css:182`) first on the fix list. Both declare a width transition on
the same curve; they differ by fifty milliseconds:

```css
/* src/styles.css:182 */
.hud-hpbar > div {
  /* ... */
  transition: width 0.4s cubic-bezier(0.3, 1, 0.4, 1);
}

/* src/styles.css:834-835 */
.hpbar > .fill {
  /* ... */
  transition: width 0.35s cubic-bezier(0.3, 1, 0.4, 1);
}
.hpbar > .ghost {
  /* ... */
  transition: width 0.9s ease 0.25s;
}
```

Before `4e78410`, the port assigned both fills. `_hp_fill.size.x` became the
new width; the plate fill did the same. The ghost rail beside them already
glided — 0.25s of hold then 0.9s of fall — so on every hit the red fill jumped
while the pale ghost slid out from under it. That reads as the ghost being the
thing that moved rather than the damage. HP is the most-watched number on the
screen; it was also the most visible place to be wrong, and the census is what
put it at the top of the list instead of leaving it for another notice.

The fix holds the value as a ratio, not a width, because `_layout_plate`
re-measures the plate's rail whenever the ward chip appears or leaves — a tween
writing a width would be overwritten by the next layout, and a tween writing
the ratio the layout reads survives it. The first sync snaps: a CSS transition
does not fire on first render, and without that guard a fight resumed at half
health would open with both rails sweeping down from full. Measured after the
fix, seeding at 50/72 then dropping to 30/72: first sync lands with no sweep;
the second travels and settles on `170 × 30/72`. Two rails, two durations, one
curve — `HP_BAR_TIME 0.4`, `HP_PLATE_TIME 0.35`, `HP_EASE [0.3, 1.0, 0.4, 1.0]`
in `presentation/combat/hud_bar.gd:80-82`, driven by `_glide_hp` at
`presentation/combat/hud_bar.gd:643` (`_glide_hp`). That is
the whole loop the method is for: extract the declaration, audit it as ABSENT
with quoted evidence, rank it by how often a player sees it, then close the row
with the numbers the stylesheet already named.

## Related

- [`docs/motion-census.md`](../../motion-census.md) — the output of running this
  method on the combat surface: 1297 rules down to 62 in-scope declarations,
  with verdicts and the ranked fix list. Landed in `2c683fa`; ranking corrected
  in `da8ffa2`.
- [`docs/wrong-reference-audit.md`](../../wrong-reference-audit.md) — sibling
  discipline for non-CSS paths: a function existing in source is not evidence
  it renders (`ring` / `slashArc`).
- [`docs/benchmark-divergence.md`](../../benchmark-divergence.md) — why audits
  must read `~/Coding/roguecardv2-benchmark` @ `6e06911`, not the post-Pixi
  tree 284 commits ahead.
- [Derive authored compensations instead of transcribing them when porting](../design-patterns/derive-authored-compensations-when-porting.md)
  — what to do with a divergence once the census has named it: design ports,
  compensations get derived.
- Commits reachable from `main` that carry this learning:
  `2c683fa` (census), `da8ffa2` (trigger-ranking correction), `4e78410` (HP
  rails), `a9eb324` / `8101382` / `13f9536` (earlier notice-driven fixes the
  census reframes as the old method's yield).
