# 04 — Delivery: surfaces, beat budget, volume plan

> Derives from `00-truth.md` and `docs/commercial-rubric.md` story criteria.
> Volume decision [SETTLED — Q5, 2026-08-14]: **~50K zh chars committed,
> aiming 100K**, en full rewrite in parallel. Fable drafts, James reviews.

## Rubric mapping (A-criteria → mechanism)

| Criterion | Mechanism |
|---|---|
| A1 nameable beginning/turn/resolution | Opening scene (L0 hearth shot) / sixth-shard mirror scene (L3) / swap finale + queue entry (L4) — all on-screen scripted scenes |
| A2 unheard beat every run, won or lost | WIN: whisper (walker's last words, queue order) at dawn. LOSS: the fallen walker's own last words, spoken at the newly raised monument — a loss-gated pool that cannot repeat [SETTLED — Q4]. Requires code change: today whispers advance only on win. |
| A3 defeat leaves residue referencing the defeat | Same event as A2-loss: the defeat raises a **monument on that map node**; later runs can read its epitaph. One mechanism serves both criteria. |
| A4 recurring character references prior meeting | Hollow Lamplighter, five meetings, explicit "last time" lines (deliberately ambiguous — see 00 §3.6) |
| Sixth-shard scripted scene | L3 mirror scene: Rose Window fully lit → becomes mirror → queue revealed → door pushed open by the monuments. Centrepiece art already shipped (emberglass-mural + masks). |
| Quest memories as full prose in Vigil | Dawn-ceremony prose per quest milestone, archived in Vigil |
| A8 bilingual, no calque | zh-Hant source (HK 書面語, 着/裏 per #177), en rewritten not translated |
| Onboarding: story before mechanics | Opening beat lands before first mechanics hint; tap = one line; distinct skip |

## Surfaces and pool sizes

Phase 1 = the committed ~50K zh chars. Phase 2 = expansion toward 100K.
Every line enters `05-foreshadow-ledger.md` with its reveal-ladder level
before it ships.

| Surface | In-fiction source | Phase 1 | Phase 2 adds |
|---|---|---|---|
| Keeper hearth lines (run start) | 留低嗰個 | pool 60 | +60 (shard-count-aware variants) |
| Waystone interstitials | walker monologues | pool 60 | +60 |
| Lamplighter meetings ×5 | dialogue scenes | 8–12 lines each, incl. the explicit「上次」line (#258 R2 Q13) | reactive variants |
| Whispers | 24 walkers' last words | rewrite/assign all 24 — full per-walker table with mini-bios, method per 00 §8.5 (#258 R3 Q16) | — |
| Loss pool (A2/A3) | dying walkers' last words + epitaphs | pool 50 | +50 |
| Dawn-ceremony prose | Vigil memory archive | 1 passage per quest milestone (~25) | act-transition passages |
| Quest line rewrites | six quests | full pass (climb-language purge) | — |
| Sixth-shard scene | L3 script | full script | — |
| Act IV five nodes + finale | L4 scripts | full scripts | — |
| Opening scene | L0 script | full script | — |
| Per-enemy walker-memory fragments | 34 enemies × 2–3 | — | ~100 lines |
| Relic/card/status/potion lore | item flavor | — | ~115 entries (needs the un-surveyed icon groups: cards 60, relics 31, statuses 17, potions 7) |
| Event scripts (library, shrine, knight, traders…) | scene dialogues | top 5 events | remainder |

## Per-channel spoiler ceiling [SETTLED — #258 R1 Q5 + R2 N3]

Every surface records the maximum reveal-ladder level (00 §5) it may carry.
Canon-lint checks each line's ledger level against its channel's ceiling.
*When* a level unlocks in play: shard-count **code gating** — engine child
task #270 [SETTLED — #258 R2 Q12].

| Surface | Ceiling | Note |
|---|---|---|
| Opening scene | L0 | visual-only foreshadow; zero textual confirmation |
| Keeper hearth lines | L1 | dual-reading, never confirming |
| Waystone interstitials | L1 | |
| Lamplighter meetings | L1 | the「上次」ambiguity lives here |
| Whispers | L1 | last words may unsettle, never explain |
| Loss pool (A2/A3) | L1 | shard-0 reachable — see R2 gating decision |
| Per-enemy fragments | L1 | |
| Relic/card/status/potion lore | L1 | |
| Event scripts | L1 | Silvered Mirror motif ruled L1 |
| Dawn-ceremony prose | L2 | quest-milestone keyed |
| Quest line rewrites | L2 | closers only; quest bodies stay L1 |
| Sixth-shard scene | L3 | the only L3 surface |
| Act IV five nodes + finale | L4 | |

## Drafting pipeline (how a batch ships)

1. **Brief**: batch scope + the bible files it may lean on + max ladder level.
2. **Draft**: written against the bible only; anything missing goes back to
   the bible first.
3. **Canon lint** (agent pass): every line checked against 00-truth rules,
   cast voice sheets, glossary terms, ladder level, 着/裏 orthography.
4. **Twist-safety** (agent pass): no line leaks above its ladder level; every
   line survives post-twist rereading (the dual-reading test).
5. **James review**: tone + canon judgment. Only then does copy enter
   `content/` / `locale/`.

Steps 3–4 run as a saved workflow (`.claude/workflows/story-draft.js`,
created when the first batch starts).
