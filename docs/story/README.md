# Story Bible — how this directory works

This directory is the **single source of truth for glassvow's narrative**. Every
line of game copy — quests, whispers, keeper lines, monument epitaphs, scene
scripts — derives from these documents. No copy is drafted "freehand"; if a
line needs a fact the bible doesn't hold, the bible gets the fact first.

Born from wayfinder ticket #175 (story design). Spine: candidate #8
《行嗰個從來冇返嚟》, chosen by James on 2026-08-14.

## Layers, in derivation order

| File | Holds | Derives from |
|---|---|---|
| `00-truth.md` | **Canon root.** The hidden truth, full timeline, fission rules, information-control matrix, reveal ladder, endings. Spoils everything. | the chosen spine + settled Q&A |
| `01-world.md` | Surface fiction vs. truth — what the player is told, layer by layer | 00 |
| `02-cast.md` | Character sheets: background, wants, knowledge state, voice, asset refs | 00 |
| `03-acts.md` | Per-act deep background (I–IV), motif vocabulary from the asset survey | 00 |
| `04-delivery.md` | Delivery surfaces, per-run beat budget, content volume plan, rubric A-criteria mapping | 00 + rubric |
| `05-foreshadow-ledger.md` | Every line's dual reading: surface / post-twist / leak risk | all copy, shipped and new |
| `06-glossary.md` | Bilingual canonical terms + placeholder register | 00, domain-modeling discipline |
| `07-scenes.md` | Scripted-scene blueprints (opening / unsealing / Act IV / finale) + the shared scene player spec | 00 + 03 + 04 (#263) |

## Review states

Every claim in these files carries one of three tags:

- **[SETTLED]** — decided by James in a grilling round; cite which. Changing it
  reopens the decision with James.
- **[PROPOSED]** — drafted by the writer, awaiting James's review. May be
  freely rewritten until reviewed; becomes [SETTLED] when James confirms.
- **[OPEN]** — a known canon question nobody has answered. Copy MUST NOT lean
  on an [OPEN] item.

## Precedence

`00-truth.md` wins over every other file. A derived file that contradicts 00
is wrong by definition — fix the derived file, or take the conflict to James
if 00 itself looks wrong.

## Standing constraints (from #175 grilling, all [SETTLED])

- **Assets are immutable; names are not.** Story may reinterpret any shipped
  image but never requires changing one. Placeholder names in 【brackets】.
- "Spire/尖塔" is retired as a landmark name — replaced by 黑曜王庭 / The
  Obsidian Court (#261 Q8); the game-wide vertical-vocabulary sweep is #232.
- zh-Hant is the source language (HK 書面語 register, 着/裏 orthography per
  ticket #177); en is a full rewrite, not a calque. Fable drafts, James reviews.
- The reference implementation's English copy is inherited but not sacred:
  climb-language conflicts with the horizontal pilgrimage and is queued for
  rewrite (tracked line-by-line in the foreshadow ledger).
