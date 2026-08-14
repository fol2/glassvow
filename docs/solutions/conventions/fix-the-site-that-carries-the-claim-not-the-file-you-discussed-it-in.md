---
title: Fix the site that carries the claim, not the file you discussed it in
date: 2026-08-02
category: conventions
module: docs
problem_type: convention
component: documentation
severity: high
applies_when:
  - "A review finds a wrong word, figure or claim in a comment or doc and you are about to correct it"
  - "The finding was raised against one file but the text it names may live in another"
  - "Writing a self-referential correction — \"this used to say X\" — about your own prose"
  - "A number in a paragraph was copied from a neighbouring number in the same paragraph"
tags:
  - documentation
  - code-review
  - corrections
  - git-log-s
  - verification
  - self-reference
---

# Fix the site that carries the claim, not the file you discussed it in

## Context

PR #84's second review round returned four findings. **Three of them were the
same mistake**, and the reviewer named it in their closing line better than the
findings themselves did:

> a figure or a word recorded next to the discussion rather than at the site that
> carries it

The first round had been told that `#69 C5` should not be described as "settled",
because the residual was real and calling it closed is how the same arithmetic
gets re-litigated in six weeks. That was correct and the fix went in — into
`WorldMapScreen.bed_half`'s docstring, which is the file the *finding was
discussed in*.

The word itself was somewhere else. It sat at the `trail/bedRate` **schema field
declaration** in `presentation/stage/layout_book.gd` — the first thing anyone
opening the layout book to retune the road actually reads. So after the "fix",
the tree held both a careful residual and a flat claim that the question was
closed, in two files, contradicting each other. A tuner who read the field
declaration and stopped had been told the opposite of what the fix intended.

Two further findings in the same round were the same shape:

- The corrected docstring asserted "**the word this docstring used**" — about its
  own history. `git log -S` shows `world_map_screen.gd` first gained the word in
  the fix commit itself. It had never carried it. The self-reference was false
  the moment it was written.
- A paragraph said an excess had been "reduced by **40%**". The real figure is
  47.9%. 40% is the *spread's* improvement — a different quantity, two sentences
  earlier in the same paragraph. The number had been borrowed from the wrong row
  of its own table.

## Guidance

**Before correcting a wrong word or figure, find every site that carries it.**
The file where a reviewer raised it is evidence that it is wrong, not evidence of
where it lives.

```bash
# Where does this text actually live, and which commit put it there?
git log -S'the exact wrong phrase' --oneline -- path/to/suspected/file.gd
git grep -n 'the exact wrong phrase'
```

Three rules follow:

1. **Locate before editing.** `git grep` for the phrase across the tree. If it
   appears at more than one site, decide which is authoritative — usually the one
   a reader reaches *first*, which is rarely the one under discussion. Fix that
   one, and make the others point at it.
2. **Never write a self-referential history you have not checked.** "This used to
   say X", "an earlier draft claimed Y", "corrected in round N" are claims about
   the repository, and `git log -S` answers them in one command. Writing one from
   memory is how a correction becomes a new error with a citation attached.
3. **A figure quoted next to other figures must be re-derived, not read across.**
   When a paragraph carries several numbers of similar shape, state the inputs
   the figure comes from so the reader recomputes rather than trusts. A number
   that cannot be re-derived from its own paragraph is the one that will be wrong.

## Why This Matters

A correction that lands in the wrong file is worse than no correction. It leaves
the authoritative site unchanged *and* adds a second, contradicting statement —
so the tree now disagrees with itself, and the reader who takes the shortest path
gets the version you meant to retire. Nothing in the toolchain catches this: both
files parse, both read well in isolation, and the anchor checker verifies that
citations resolve, not that a claim is made where it counts.

The self-reference case is sharper still, because the sentence's whole job is to
stop the error recurring. A false account of what went wrong is a durable, cited,
confidently-worded lie about the repository's own history — and the next reader
has no reason to doubt it.

The reason all three slipped through is the same cognitive one: **during a
review, the file under discussion feels like the subject.** It is not. The
subject is the claim, and the claim has an address.

## When to Apply

- Correcting any word, number or assertion raised by a review — before the edit,
  not after.
- Writing a sentence that describes the history of the code it sits in.
- Retiring a term (`settled`, `TODO`, `temporary`, a deprecated name) that may
  have been written at several sites by the same change.
- Quoting a percentage or ratio in a paragraph that already contains others.

Cheap enough to apply always: two commands before an edit that was going to
happen anyway.

## Examples

**The mislocated fix** — `presentation/stage/layout_book.gd:180`, where the word
actually lived, now carries the verdict and routes onward:

```gdscript
## **Improved, not settled**, and the residual is on
## `WorldMapScreen.bed_half` — read it before retuning these three. The
## clamps bind at two of the five shapes, phone-landscape is still 1.57×
## wider in proportion than the reference, and measured against LANE PITCH
## the rate is less consistent than the constant it replaced.
```

`presentation/map/world_map_screen.gd` (`bed_half`) — the file the finding was discussed
in — now names where the word lived instead of claiming it as its own, and the
cross-reference runs both ways so neither end can rot silently.

**The verification that caught all three**, and the reason it is the whole
technique:

```bash
$ git log -S'settled in #70' --oneline -- presentation/stage/layout_book.gd
2b68a03 feat(map): the bed becomes a road — tapered, and it ends somewhere

$ git log -S'settled' --oneline -- presentation/map/world_map_screen.gd
9c24607 fix(map): three copies of one projection, and a gate the road could flare past
```

The second result is the finding: the only commit that ever put the word in that
file is the commit that claimed to be removing it.

**The borrowed figure** — the correction states its inputs so the next reader
re-derives instead of trusting:

> `bedMin` floors it at 6.0 where the rate wants 3.82, so the excess over what
> the rate asks for falls from 4.18 px to 2.18, **48% of it removed, not all**.
> (That figure read 40% until PR #84 DL R2: 40% is the SPREAD's improvement,
> 3.03× → 1.82×, two sentences above.)

## Related

- [Annotate a citation only where structure and prose agree](../workflow-issues/annotate-citations-where-structure-and-prose-agree.md)
  — the same discipline one level down: verify against the tree, never against
  the prose describing the tree.
- [Cite the symbol, not the line](cite-the-symbol-not-the-line.md) — about
  keeping a pointer accurate; this doc is about putting the correction where the
  pointer aims.
- [Every number matched and the declaration still did not](every-number-matched-and-the-declaration-still-did-not.md)
  — a figure agreeing with its neighbours is not evidence it is right.
