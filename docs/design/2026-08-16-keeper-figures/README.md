# Keeper figures — #283 candidates

Two new cutouts, one silhouette. James reviews before anything ships to
`assets/`. Spec: `docs/story/02-cast.md` › Keeper › 資產
(`[SETTLED — #260 Q7]`). Overlay seat: `docs/story/07-scenes.md` §8 +
`docs/design/2026-08-16-scene-plates/README.md` plate 1 (the hall is empty;
this figure sits on the bare hearth step).

## Binding

- Style block + **leaded-glass construction clause** from
  `docs/art-ledger.md` (`hollow-lamplighter` lesson: say the robe *is*
  glass panes, or you get painted cloth).
- Hooded, void face, no eyes — L0-safe. The 00 §5 L0 plant
  「爐前仍坐着一個兜帽身影」.
- Same silhouette on both pieces. Recognition at the Act IV reveal *is*
  the design. This deliberately breaks `style-bible.md`'s
  keeper/warden-silhouette ban for enemies; waiver goes in
  `docs/art-ledger.md` at ship.
- Transparent RGBA, single complete seated figure, max edge 1024
  (`sips -Z 1024`). Alpha ≥240 over ≥90% of non-transparent pixels.
- No lantern (Lamplighter owns that). No hearth in the cutout (the plate
  supplies it). Hands folded. Stillness is the pose.

## Candidates

Generated 2026-08-16 through the quality `image-gen` tier. Hearth pass
normalised with `sips -Z 1024`. Contact sheet: `contact-sheet.png`.

| File | Piece | Size | ≥240 alpha | Notes |
|---|---|---|---|---|
| `hearth-a.png` | hearth seated | 682×1024 | 98.7% | pass. Landed RGB-tall; sips produced a real RGBA cutout. |
| `hearth-b.png` | hearth seated | 768×1024 | 98.0% | pass. Native size. Not picked. |
| `hearth-c.png` | hearth seated | 682×1024 | 64.5% | **fail** — washed figure, same class as Lamplighter B/E. |
| `hearth-d.png` | hearth seated | 682×1024 | 98.6% | pass. **James picked 2026-08-16 — silhouette master.** |
| `hearth-e.png` | hearth seated | 683×1024 | 98.8% | pass. Peaked hood, red centre stripe. |
| `boss-a.png` | Act IV boss | 723×1024 | 98.4% | pass. Native size. Rim still from the right. |
| `boss-b.png` | Act IV boss | 682×1024 | 84.9% | **fail** — washed |
| `boss-c.png` | Act IV boss | 682×1024 | 98.5% | pass. **James picked 2026-08-16.** Inverted light from left. |
| `boss-d.png` | Act IV boss | 681×1024 | 98.6% | pass. |

Shipped 2026-08-16:

- `assets/art/meta/keeper.png` ← `hearth-d.png`
- `assets/art/enemies/eternalKeeper.png` ← `boss-c.png`

Overlay / combat wiring is not this ticket — scene player is #309, Act IV
roster is #220/#221. The rasters sit at the conventional paths.
