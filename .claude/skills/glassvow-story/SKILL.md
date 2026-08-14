---
name: glassvow-story
description: Binding contract for all glassvow narrative work — story bible discipline, canon precedence, foreshadow-ledger rules, drafting pipeline. Load before writing or reviewing any game copy, scene script, or lore.
---

# Glassvow Story Contract

Narrative counterpart to `glassvow-godot` (which binds engine work). Any
session that writes, edits, or reviews story content loads this first.

## 1. The bible is law

`docs/story/` is the single source of truth. Read order for a story session:
`README.md` → `00-truth.md` → whichever derived files the task touches.
`00-truth.md` wins every conflict. A fact the bible lacks is added to the
bible **before** any copy leans on it — never invented inline.

## 2. Review states are binding

- **[SETTLED]** — James decided it. Changing it requires reopening the
  decision with James, never a silent edit.
- **[PROPOSED]** — draft canon. May be rewritten, but downstream copy built
  on it is at-risk until James confirms.
- **[OPEN]** — no copy may lean on it. Full stop.

## 3. Foreshadow-ledger discipline (the twist survives by this)

Every line of copy — new or edited — enters `05-foreshadow-ledger.md` with:
surface reading, post-twist reading, reveal-ladder level (00 §5), leak risk.

- A line whose post-twist rereading fails is rewritten until it passes.
- A line that reveals above its ladder level is rewritten or rescheduled.
- Vertical-pilgrimage vocabulary (climb/spire/ascend/above) is banned in new
  copy and tagged `[REWRITE:climb]` where shipped.

## 4. Language pipeline (inherits ticket #177)

zh-Hant is the source language: HK 書面語 register, 着/裏 orthography.
English is a full rewrite, never a calque. Fable drafts, James reviews —
copy enters `content/` or `locale/` only after James's review.

## 5. Voice sheets

Dialogue must pass the cast sheet's voice test (`02-cast.md`): "only this
character could say this line." Keeper lines additionally pass the dual-
reading test — true before the twist, colder after — and the Keeper never
urges departure.

## 6. Assets are immutable; names are not

Story may reinterpret any shipped image but never requires changing one.
Unlocked names stay in 【brackets】 per `06-glossary.md`; "Spire/尖塔" is
retired. No rushing nomenclature — story first, names later.

## 7. Drafting pipeline

Mass copy is produced in batches per `04-delivery.md`: brief → draft against
the bible → canon-lint agent pass → twist-safety agent pass → James review.
Batch workflow lives at `.claude/workflows/story-draft.js` (created with the
first batch). No freehand additions outside a batch.

## 8. Scope boundaries

- Engine/code changes implied by story (e.g. the loss-gated whisper pool)
  follow `glassvow-godot` and the normal verification gates — this skill
  governs only the words.
- Wayfinder map #156 tracks story decisions as tickets; one ticket per
  session, decisions recorded on the map.

## 9. Fair-play decalogue (#258 R1 Q5)

Twist-craft rules; the canon-lint and twist-safety passes enforce them line
by line.

1. A reveal may only reinterpret shipped lines — never import a fact the
   player couldn't have met before it.
2. Every dual-reading line must fully work on its surface reading alone;
   a line that only functions post-twist is a leak.
3. The Keeper may mislead, never lie: every Keeper line is literally true
   under `00-truth.md`.
4. No character may voice knowledge above their information-matrix row
   (00 §4); the matrix, not the cast sheet, is the authority.
5. A line's reveal-ladder level (00 §5) may not exceed its channel's
   spoiler ceiling (04-delivery).
6. Contradictions are resolved from existing canon or taken to James —
   never patched with new metaphysics invented inline.
7. Legend-drift (in-fiction wrong beliefs: the Lamplighter's testimony,
   the Second Page's motive clause) is ledgered as drift — the ledger
   records both the false surface and the true mechanism.
