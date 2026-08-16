# Scene staging bake-off — Route A vs Route B (#263 Q3)

James asked for both staging routes rendered so the choice is made looking at
pictures, not prose (2026-08-16). Same two scenes, same style-bible block, same
settled copy ("You are awake." / "Stand at the Threshold."), landscape
1536×1024 against the 1180×820 viewport. **Decision mocks only — not game
assets**; nothing here ships or enters `assets/`.

| File | Route | Scene |
|---|---|---|
| `route-a-opening.png` | A — in-engine staging | Opening hearth beat as a game screen: HollowScreen-pattern figure+dialogue panel |
| `route-a-unsealing.png` | A — in-engine staging | Unsealing as a ceremony screen: centred mural-window, CTA panel (ThresholdScreen upgraded) |
| `route-b-opening.png` | B — illustrated panels | Opening as full-bleed cinematic painting + letterbox band |
| `route-b-unsealing.png` | B — illustrated panels | Unsealing as full-bleed cinematic painting + letterbox band |

## Trade-offs (as presented for the decision)

- **Route A**: zero distance from shipped patterns (HollowScreen /
  ThresholdScreen / DawnScreen); smallest asset bill (figures already billed
  on #283, mural shipped); the dialogue panel is the scene player's natural
  home. Less awe at the peaks; the UI frame stays visible.
- **Route B**: maximum impact at the four story-defining moments; panels
  double as store-presence material (#243). Much larger asset bill
  (~3–6 panels × 4 scenes at quality tier, longest-lead item on the RC path
  per #221; mocks measure 2.0–2.4 MB each against an art payload already at
  135 MB); style-drift risk across many panels.
- **Hybrid** (recommended): A's machine, grammar and staging as the backbone;
  B-grade full-bleed plates only for peak shots. Note the peaks already own
  shipped plates — `ascended.png` / `fallen.png` (endings) and the emberglass
  mural (unsealing) — so the hybrid's *new*-plate list is small and gets
  enumerated per scene in `docs/story/07-scenes.md` §8.

## Verdict [James, 2026-08-16]

**Hybrid** — Route A's machine/grammar as the backbone, Route B-grade plates
at the peaks. Two binding taste calls made off these renders: the plates'
visual bar is Route B's cinematic treatment (James preferred B "much much
more" of the four); Route A-unsealing's per-pane repeated-crowd treatment is
**rejected** as creepy — the mirror shows one queue across the whole window
(the literal 00 §2.6 「窗中站滿一排『你』」), never per-pane duplication.
Per-scene plate bill: `docs/story/07-scenes.md` §8 (9 new plates).
