# Act IV combat art — #221 candidates

Combat stage plates and the one counterfactual-self painting whose id is
stable on `main`. Scene plates (nodes 1–5, unsealing, finale) already
shipped under `docs/design/2026-08-16-scene-plates/`. The Eternal Keeper
raster shipped with #283. This record is the **combat** bill.

James reviews the proposed picks before they are treated as signed. The
installer writes the current `PICKS` into `assets/`; swap a row and
re-run to change the bytes without regenerating.

    python3 docs/design/2026-08-16-act4-combat-art/install.py
    python3 docs/design/2026-08-16-act4-combat-art/measure.py
    python3 docs/design/2026-08-16-act4-combat-art/contact_sheet.py

## Binding

- Combat plates are **cutouts**, not the cinematic scene plates. Sky and
  empty space are true alpha so `SkyField`'s Act IV dawn shows through
  (`sky_field.gd`). Match `assets/art/stage/act1-*.png`: 1536×1024
  backdrop/mid; ledge is shorter (act1 761, act3 574; ours 797).
- Motif from `docs/story/03-acts.md` Act IV: 站立的碑列隊成路, 倒轉的爐光.
  One plate set for the whole act — per-node look stays on the scene
  plates.
- No spires, no climb, no vertical pilgrimage. Horizontal road.
- Character: style-bible construction clause (the body *is* glass panes),
  max edge 1024, alpha ≥240 over ≥90% of non-transparent pixels, corners
  clear. `unwalkedSelf` reuses **hero silhouette** vocabulary (#261 Q5)
  with a III-prime broken halo; it is not a monster and not the seated
  Keeper.
- Generated 2026-08-17 through Cursor `GenerateImage` (the image-gen
  tier this environment has). Lossless RGB candidates stay in
  `candidates/`; `install.py` flood-fills the void from the edges, hardens
  character alpha after LANCZOS, and writes the shipped RGBA.

## Proposed picks

| Shipped | Candidate | Why |
|---|---|---|
| `act4-backdrop` | **B** | Asymmetric left ruin (act1's fragment language); inverted amber at the far vanishing point; shadows fall toward the camera. A is a centred tunnel. |
| `act4-mid` | **B** | One connected gate with unlit hanging lanterns, amber through the glass from behind — act1-mid's shape. A is three disconnected pieces. |
| `act4-ledge` | **B** | Wide platform with a thick front face and two standing-stone posts. A is a round disc. |
| `unwalkedSelf` | **A** | Leaded panes, void hood, inverted rim from the left, broken halo. B reads more as gold-trimmed armour than glass. |

These are the installer's `PICKS`. They are **proposed**, not James-signed.

## Candidates

| File | Piece | Cut size | ≥240 alpha | Notes |
|---|---|---|---|---|
| `act4-backdrop-a.png` | backdrop | 1536×1024 | see measure.py | centred monument road; rejected for symmetry |
| `act4-backdrop-b.png` | backdrop | 1536×1024 | pass | **proposed.** Bottom corners opaque — same as act1-backdrop |
| `act4-mid-a.png` | mid | 1536×1024 | pass | three separate structures |
| `act4-mid-b.png` | mid | 1536×1024 | pass | **proposed.** |
| `act4-ledge-a.png` | ledge | — | — | round arena |
| `act4-ledge-b.png` | ledge | 1536×797 | pass | **proposed.** |
| `unwalked-self-a.png` | enemy | 622×1024 | pass | **proposed.** |
| `unwalked-self-b.png` | enemy | — | — | gold-trim armour read |

## Prompts

Shared void clause, all plates:

> GAME ASSET cutout, not cinematic key art. Empty space is pure #000000
> so a later flood-fill can become true alpha. Painterly matte dark
> fantasy, chunky weathered stone. NO characters, NO text, NO UI, NO
> watermark. NO mountain spires, NO needle peaks, NO vertical climb.

### Backdrop B

Reference: `act1-backdrop.png`, `act3-backdrop.png`. 4:3 render, fitted
1536×1024.

> UPPER 50 percent is empty pure #000000 void — no sky, clouds, stars, or
> gradient. BOTTOM: an ASYMMETRIC horizontal monument-road, not centred,
> not a tunnel. A ruined stone wall fragment occupies the LEFT foreground
> (like the attached act1 tower fragment), with one gothic window glowing
> cold teal. From mid-left a road of standing monuments recedes toward
> the RIGHT-DISTANCE where a warm amber hearth-glow sits low on the
> horizon. Two staggered ranks of tall weathered stelae with small
> stained-glass insets. Long shadows thrown TOWARD the viewer because the
> light comes from ahead. Cold slate-violet near, amber far.

### Mid B

Reference: `act1-mid.png`.

> ONE connected stone structure floating in pure #000000 void, not three
> separate pieces. A single ruined gothic GATE: two heavy pillars joined
> by one pointed arch, a rose/quatrefoil in the arch head, stained glass
> in the opening glowing warm amber FROM BEHIND (inner face of a window,
> light coming through toward us). Two hanging dark lanterns, one on each
> side, but they are UNLIT and cold — the only warmth is the amber
> through the glass. Chunky cracked grey-violet stone. Thin gold rim on
> the lead of the glass. Small rising ember specks.

### Ledge B

Reference: `act1-ledge.png`, `act3-ledge.png`. 16:9 render, sky cropped,
fitted 1536 wide.

> A WIDE HORIZONTAL stone fighting platform, NOT a circle, NOT a round
> arena. Viewed slightly from above and in front, showing a thick jagged
> front face. Chunky irregular stone tiles. Cracks glow warm hearth-amber.
> The FAR back edge is brighter amber (inverted hearth); the NEAR front
> lip is colder slate-violet. Two standing-stone posts at the left-back
> and right-back, each with a small cold teal glass inset — not lanterns.

### Unwalked Self A

Reference: `duskblade.png`, `ashwarden.png`, `eternalKeeper.png`. 3:4
render, max-edge 1024.

Style block + construction clause as `docs/art-ledger.md`
(`hollow-lamplighter` / Keeper): the body *is* large flat stained-glass
panes with thick black lead came.

> Full-body standing pilgrim-warrior, hero silhouette, 15 percent margin,
> no cropped limbs. Raised hood; the hood opening is a deep BLACK VOID
> with NO face, NO eyes, NO glowing points. Holds a tall stained-glass
> scepter in one hand (unused court power). Behind the head, a BROKEN
> golden halo / ring snapped clean through, two ends not meeting.
> INVERTED hearth light: warm amber rim arrives from the LEFT, catching
> lead edges. The rest of the glass is cold — violet-grey, deep teal,
> court purple. Readable as a solid black silhouette if internal detail
> were removed.

## Held

- Remaining 7 counterfactual-self paintings: ids wait on #220 / PR #364.
- `act4-combat` / `act4-boss` / unsealing sting: briefs in
  `docs/music-ledger.md` and `docs/sfx-ledger.md`. No files yet — Suno /
  ElevenLabs are not in this environment.
