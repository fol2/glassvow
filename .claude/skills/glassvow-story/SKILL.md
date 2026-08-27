---
name: glassvow-story
description: Binding contract for Glassvow narrative work — story bible discipline, canon precedence, foreshadow-ledger rules, and the drafting pipeline. Load only for game copy, scene scripts, or lore.
---

# Glassvow Story Contract

Narrative counterpart to `glassvow-godot`, which binds engine work. A task that writes, edits, or reviews story content loads this skill; unrelated development does not.

## 1. The bible is law

`docs/story/` is the single source of truth. Read `README.md`, then `00-truth.md`, then only the derived files the task touches. `00-truth.md` wins every conflict. A fact the bible lacks is added to the bible before any copy leans on it—never invented inline.

## 2. Review states are binding

- **[SETTLED]** — James decided it. Changing it requires reopening the decision with James, never a silent edit.
- **[PROPOSED]** — draft canon. It may be rewritten, but downstream copy built on it is at risk until James confirms.
- **[OPEN]** — no copy may lean on it.

## 3. Foreshadow-ledger discipline

Every new or edited line enters `05-foreshadow-ledger.md` with its surface reading, post-twist reading, reveal-ladder level (`00-truth.md` §5), and leak risk.

- A line whose post-twist rereading fails is rewritten until it passes.
- A line that reveals above its ladder level is rewritten or rescheduled.
- Vertical-pilgrimage vocabulary is banned in new copy and tagged `[REWRITE:climb]` where shipped. The full ban is seven terms, not four: Spire/尖塔, climb/爬/攀, ascend/登臨, summit/頂點, above-as-a-place/之上, upward/向上, and stair-as-the-road/階梯. Check the keep-list in `06-glossary.md` before substituting anything.

## 4. Language pipeline

zh-Hant is the source language: HK written register with 着/裏 orthography. English is a full rewrite, never a calque. Fable drafts and James reviews; copy enters `content/` or `locale/` only after that review.

## 5. Voice sheets

Dialogue must pass the cast sheet's voice test in `02-cast.md`: only this character could say this line. Keeper lines additionally pass the dual-reading test—true before the twist, colder after—and the Keeper never urges departure.

## 6. Assets are immutable; names are not

Story may reinterpret any shipped image but never requires changing one. Unlocked names stay in 【brackets】 per `06-glossary.md`; “Spire/尖塔” is retired. Story comes before nomenclature.

## 7. Drafting and promotion

Mass copy is produced in batches per `04-delivery.md`: brief → draft against the bible → canon-lint pass → twist-safety pass → James review. The two review passes have distinct hypotheses and should not duplicate one another. The batch workflow lives at `.claude/workflows/story-draft.js`.

Drafts and alternatives are a bounded discovery loop. Keep them inside one batch; do not create an issue, branch, PR, or CI run for every candidate. Only selected copy and its ledger updates cross into the delivery loop.

When selected copy changes `content/`, `locale/`, or runtime scene files, normal scope-aware delivery applies. The story skill governs the words; `tools/ci_scope.py` selects the relevant locale/content and Godot checks from the actual PR diff.

## 8. Scope boundaries

- Engine or code changes implied by story also load `glassvow-godot`.
- Wayfinder map #156 may retain durable story decisions. Track one independently mergeable outcome, not one ticket per session or draft.

## 9. Fair-play decalogue

The canon-lint and twist-safety passes enforce these rules line by line.

1. A reveal may only reinterpret shipped lines—never import a fact the player could not have met before it.
2. Every dual-reading line must work on its surface reading alone; a line that only functions post-twist is a leak.
3. The Keeper may mislead, never lie: every Keeper line is literally true under `00-truth.md`.
4. No character may voice knowledge above their information-matrix row in `00-truth.md` §4.
5. A line's reveal-ladder level may not exceed its channel's spoiler ceiling in `04-delivery.md`.
6. Resolve contradictions from existing canon or take them to James; never patch them with new metaphysics invented inline.
7. Legend-drift is ledgered as drift: record both the false surface and the true mechanism.
