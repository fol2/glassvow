# 04 — Delivery: surfaces, beat budget, volume plan

> Derives from `00-truth.md` and `docs/commercial-rubric.md` story criteria.
> Volume decision [SETTLED — Q5, 2026-08-14]: **~50K zh chars committed,
> aiming 100K**, en full rewrite in parallel. Fable drafts, James reviews.

## Rubric mapping (A-criteria → mechanism)

| Criterion | Mechanism |
|---|---|
| A1 nameable beginning/turn/resolution | Opening scene (L0 hearth shot) / sixth-shard mirror scene (L3) / swap finale + queue entry (L4) — all on-screen scripted scenes |
| A2 unheard beat every run, won or lost | WIN: whisper (walker's last words, queue order) at dawn — the win-gated counter stays as-is. LOSS: a line from the loss pool, written as a **defeat epitaph into the Vigil ledger** (see A3); selection per § Loss pool semantics. Engine trigger: #270 [SETTLED — Q4 + #262 Q1/Q2]. |
| A3 defeat leaves residue referencing the defeat | Same write as A2-loss: the epitaph enters a defeat ledger in `VigilState`, readable in the Vigil in later runs — in fiction, the leaver's inherited memory of the dying moment (00 §3.7), so no new metaphysics. Roadside monuments stay **art/scene layer** (region art, fallen.png, the L3 unsealing) — never per-defeat spawns: the map regenerates per run, so a map-node monument has no persistent home [SETTLED — #262 Q1, option C]. |
| A4 recurring character references prior meeting | Hollow Lamplighter, five meetings, explicit "last time" lines (deliberately ambiguous — see 00 §3.6) |
| Vigil shows held Shards + open quests mid-playthrough | Rose Window, already shipped: complete panes lit (= shards held), armed/revealed/dormant panes visually distinct, per-pane quest detail (`presentation/run/rose_window_view.gd`). Legibility verified at the Vigil surface sign-off [SETTLED — #262 Q4a]. |
| Sixth-shard scripted scene | L3 mirror scene: Rose Window fully lit → becomes mirror → queue revealed → door pushed open by the monuments. Centrepiece art already shipped (emberglass-mural + masks). |
| Quest memories as full prose in Vigil | Dawn-ceremony prose per quest milestone, archived in Vigil |
| A8 bilingual, no calque | zh-Hant source (HK 書面語, 着/裏 per #177), en rewritten not translated. Gates: locale-coverage lint #300 (pipeline + CI) and the en native-read pass (pipeline step 6) [SETTLED — #262 Q6]. |
| Onboarding: story before mechanics | Content: the L0 opening script (this plan). First-run sequencing + hint system + veteran skip: onboarding design ticket #176 [SETTLED — #262 Q4b]. Amended #263 Q2: the tap-one-line / distinct-skip grammar belongs to the shared scene player (`07-scenes.md` §1); #176 consumes it. |
| Story-arc audio (per-scene soundscape shift; sixth-shard unique sting) | Cue requirements written into each scene script's **brief** (opening, sixth-shard, Act IV); audio production itself belongs to each hosting surface's audio criteria [SETTLED — #262 Q4c]. |

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
| Loss pool (A2/A3) | dying walkers' last words → defeat epitaphs in the Vigil ledger | pool 50 | +50 |
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
| Opening scene | L0 | visual-only foreshadow; zero textual confirmation **of the truth** (00 §5 note). The script must name the journey's destination in dialogue before first combat (rubric; [SETTLED — #262 Q3]) |
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

## Line table schema [SETTLED — #262 Q5]

All narrative pools author into **one flat line table** (per the narrative-
pipeline research, `docs/research/2026-08-14-narrative-pipeline.md`):

```
{id, speaker, slot, conditions, priority, once, cooldown_runs, weight, zh, en, asserts}
```

- Selection is **most-specific-wins** with a generic fallback per slot — a
  line always fires.
- Phase 1 condition vocabulary is deliberately small: **shard-count / act /
  quest-state**. `priority`/`weight` default; columns may sit empty.
- The engine (#270) implements selection; its shard gate **is** the
  `conditions` column, not a parallel mechanism.
- Scripted scenes (opening, Lamplighter, sixth-shard, Act IV) are scripts,
  not table rows; the table serves the pools.

## Loss pool semantics [SETTLED — #262 Q2]

- A draw excludes lines used in the most recent ~3 runs (`cooldown_runs`).
- On pool exhaustion, recycle — but never repeat consecutively.
- Light conditions (act/region) prefer a matching line; the generic fallback
  guarantees an epitaph always exists.
- The chosen line is written into the Vigil defeat ledger at run end (#270);
  the `whispers` win counter is untouched.

## Volume measurement [SETTLED — #262 Q7]

The ~50K commitment is a **measured outcome, not a per-surface quota**: James
records the zh char count at each batch review; if two consecutive batches
trend under the 50K trajectory, Phase 2 items (per-enemy fragments, item
lore) pull forward. The pool table above stays the plan of record.

## Batch order [SETTLED — #262 Q8]

1. **Batch 1** (#301): six quest lines + 24 whispers — all shipped copy, so
   the climb purge and the per-walker table land first; feeds #228/#232.
   `story-draft.js` is created with this batch.
2. **Batch 2**: opening scene + Lamplighter ×5 — unlocks #176; lands the
   explicit「上次」line (00 §3.6).
3. **Batch 3**: the three pools (hearth / waystone / loss) — schema live.
4. **Batch 4**: dawn-ceremony prose + sixth-shard scene + Act IV scripts +
   top-5 event scripts.

## Drafting pipeline (how a batch ships)

1. **Brief**: batch scope + the bible files it may lean on + max ladder level
   (+ audio cue requirements for scene scripts, #262 Q4c).
2. **Draft**: written against the bible only; anything missing goes back to
   the bible first.
3. **Canon lint** (agent pass): every line checked against 00-truth rules,
   cast voice sheets, glossary terms, ladder level, 着/裏 orthography.
4. **Twist-safety** (agent pass): no line leaks above its ladder level; every
   line survives post-twist rereading (the dual-reading test).
5. **Locale-coverage lint** (mechanical, #300): en/zh-Hant key parity; no
   English-fallback string in any zh-Hant narrative leaf. Also runs in CI.
6. **en native-read pass**: en read on the page as written prose (step 3's
   orthography check covers zh only).
7. **James review**: tone + canon judgment. Only then does copy enter
   `content/` / `locale/`.

Steps 3–4 run as a saved workflow (`.claude/workflows/story-draft.js`,
created when the first batch starts). **Simulation-verified planting** —
headless N-run assertion that every twist-critical plant fires in ≥2
independent slots before its payoff — is #270's acceptance gate, not a
per-batch step [SETTLED — #262 Q6c].
