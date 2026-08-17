# Act IV combat art — #221 candidates

Combat stage plates and the one counterfactual-self painting whose id is
stable on `main`. Scene plates (nodes 1–5, unsealing, finale) already
shipped under `docs/design/2026-08-16-scene-plates/`. The Eternal Keeper
raster shipped with #283. This record is the **combat** bill.

James picked these on 2026-08-17 (#221). The installer writes the current
`PICKS` into `assets/`; swap a row and re-run to change the bytes without
regenerating.

    python3 docs/design/2026-08-16-act4-combat-art/install.py
    python3 docs/design/2026-08-16-act4-combat-art/measure.py
    python3 docs/design/2026-08-16-act4-combat-art/contact_sheet.py

## Binding

- Combat plates are **cutouts**, not the cinematic scene plates. Sky and
  empty space are true alpha so `SkyField`'s Act IV dawn shows through
  (`sky_field.gd`). Match `assets/art/stage/act1-*.png`: 1536×1024
  backdrop/mid; ledge is shorter (act1 761, act3 574; ours 789).
- Motif from `docs/story/03-acts.md` Act IV: 站立的碑列隊成路, 倒轉的爐光.
  One plate set for the whole act — per-node look stays on the scene
  plates.
- No spires, no climb, no vertical pilgrimage. Horizontal road.
- Character: style-bible construction clause (the body *is* glass panes),
  max edge 1024, alpha ≥240 over ≥90% of non-transparent pixels, corners
  clear, leftover field-magenta < 32, opaque near-black in the 8px frame
  < 400. `unwalkedSelf` reuses **hero silhouette** vocabulary (#261 Q5)
  with a III-prime broken halo; it is not a monster and not the seated
  Keeper. Generate on a **magenta field**, not black — a void hood is
  also black.
- Generated 2026-08-17 through Cursor `GenerateImage`. Lossless RGB
  candidates stay in `candidates/`. Stage plates: flood-fill near-black
  from the edges. Characters: **magenta field**, not black — a void hood
  is also black, so a black-void flood cannot tell them apart (A boxed
  the sprite). `install.py` keys magenta globally from the edges, punches
  large enclosed magenta arm-gaps, hardens character alpha after LANCZOS.

## Signed picks

| Shipped | Candidate | Why |
|---|---|---|
| `act4-backdrop` | **C** | Monument road, inverted amber at the vanishing point, no left tower. B cloned Act I's ruin fragment. |
| `act4-mid` | **C** | Circular rose-window inner face, two sentinel stelae. B was an Act I lantern-arch (referenced `act1-mid.png` — a miss, not canon). |
| `act4-ledge` | **B** | Wide platform with a thick front face and two standing-stone posts. A is a round disc. |
| `unwalkedSelf` | **D** | Magenta field, void hood, mosaic glass, cracked halo. A was unkeyable black haze. C punched holes in the chest. |

These are the installer's `PICKS`. James picked them on 2026-08-17 (#221).

Act IV node 4 mirrors Act I's 雙燈 / paired lanterns, but combat plates
are **one set for the whole act**. They take the act motif (monuments as
a road, inverted hearth, rose-window inner face), not Act I's lantern-arch.

## Candidates

| File | Piece | Cut size | ≥240 alpha | Notes |
|---|---|---|---|---|
| `act4-backdrop-a.png` | backdrop | 1536×1024 | — | centred monument road; rejected for symmetry |
| `act4-backdrop-b.png` | backdrop | 1536×1024 | — | **rejected.** Left gothic ruin = Act I fragment language |
| `act4-backdrop-c.png` | backdrop | 1536×1024 | pass | **James picked 2026-08-17.** Stelae road, no left tower |
| `act4-mid-a.png` | mid | 1536×1024 | — | three separate structures |
| `act4-mid-b.png` | mid | 1536×1024 | — | **rejected.** Act I lantern-arch clone |
| `act4-mid-c.png` | mid | 1536×1024 | pass | **James picked 2026-08-17.** Rose window + sentinel stelae |
| `act4-mid-d.png` | mid | 1536×1024 | — | rose window in a door-arch; kept as runner-up |
| `act4-ledge-a.png` | ledge | — | — | round arena |
| `act4-ledge-b.png` | ledge | 1536×789 | pass | **James picked 2026-08-17.** |
| `unwalked-self-a.png` | enemy | — | fail | **rejected.** Black void + black hood → opaque haze box |
| `unwalked-self-b.png` | enemy | — | — | gold-trim armour read |
| `unwalked-self-c.png` | enemy | — | — | magenta field, but pane-holes under a global key |
| `unwalked-self-d.png` | enemy | — | pass | **James picked 2026-08-17.** |

## Prompts

Shared void clause, **stage plates only** (black is fine: no enclosed black cavity we must keep):

> GAME ASSET cutout, not cinematic key art. Empty space is pure #000000
> so a later flood-fill can become true alpha. Painterly matte dark
> fantasy, chunky weathered stone. NO characters, NO text, NO UI, NO
> watermark. NO mountain spires, NO needle peaks, NO vertical climb.
> NO hanging lanterns, NO paired lamps, NO chains, NO ashen woods.

Do **not** pass `act1-*.png` as image references. Motif reference is
`assets/art/scenes/act4-node1.png` (threshold' / inner rose window).

### Backdrop C

4:3 render, fitted 1536×1024.

> UPPER 55 percent is empty pure #000000 void — no sky, clouds, stars, or
> gradient. BOTTOM: a horizontal monument-road of standing stelae receding
> to a vanishing point. Two staggered ranks of tall weathered slabs with
> small stained-glass insets, teal nearby and amber farther. At the FAR
> vanishing point a warm inverted hearth-amber glow sits LOW — light comes
> from ahead so long shadows fall toward the camera. Cold slate-violet
> near, amber far. No architecture other than the standing stones. NO
> ruined tower on the left, NO gothic window-in-a-wall.

### Mid C

Reference: `act4-node1.png`. 4:3 render, fitted 1536×1024.

> ONE connected stone structure floating in pure #000000 void. The INNER
> FACE of a cathedral ROSE WINDOW after stepping through: a large CIRCULAR
> six-petal rose window of stained glass in a heavy stone roundel — not a
> pointed door-arch. Warm amber hearth-light shines THROUGH the glass FROM
> BEHIND toward the camera. TWO standing monument stelae flank it, left
> and right: tall weathered slabs with small cold teal glass insets. They
> are standing stones, not lamps. NO hanging lanterns, NO chains, NO
> pointed gothic GATE doorway, NO quatrefoil inside a pointed arch.

### Ledge B

Reference: `act1-ledge.png`, `act3-ledge.png` (platform *shape* only).
16:9 render, sky cropped, fitted 1536 wide.

> A WIDE HORIZONTAL stone fighting platform, NOT a circle, NOT a round
> arena. Viewed slightly from above and in front, showing a thick jagged
> front face. Chunky irregular stone tiles. Cracks glow warm hearth-amber.
> The FAR back edge is brighter amber (inverted hearth); the NEAR front
> lip is colder slate-violet. Two standing-stone posts at the left-back
> and right-back, each with a small cold teal glass inset — not lanterns.

### Unwalked Self D

Reference: `eternalKeeper.png` (void hood, leaded glass — not duskblade).
3:4 render. **Magenta field**, not black.

> GAME ASSET character cutout. The entire BACKGROUND is a FLAT SOLID
> MAGENTA field, hex #FF00FF, edge to edge. No black background, no grey
> vignette, no dark halo. Magenta touches the silhouette directly.
> CONSTRUCTION: the body IS large flat stained-glass panes with thick
> black lead came, not painted cloth. Full-body standing pilgrim-warrior,
> 15 percent magenta margin. Raised hood; hood opening is a deep BLACK
> VOID with NO face, NO eyes — black exists ONLY inside the hood. Holds a
> tall stained-glass SCEPTER (geometric crystal head, NOT a hanging
> lantern). Behind the head a BROKEN golden halo snapped at the top.
> Warm amber rim from the LEFT; remaining glass cold violet / teal /
> court purple. No text, no watermark.

## Held

- Remaining 7 counterfactual-self paintings: ids wait on #220 / PR #364.
- `act4-combat` / `act4-boss` / unsealing sting: briefs in
  `docs/music-ledger.md` and `docs/sfx-ledger.md`. No files yet — Suno /
  ElevenLabs are not in this environment.
