# Art ledger — port-authored raster assets

Companion to `music-ledger.md` and `sfx-ledger.md`, and the same shape: the
**generation ledger for the shipped art pack lives upstream**, and this file is
the port-facing record only.

## Where the prompts live

Almost every PNG under `assets/art/` was generated upstream in
`roguecardv2@6e06911` and carried into this port verbatim. Its prompt rules,
style block, per-category sizes, and review gates are already written, in
`../roguecardv2-benchmark/docs/`:

| File | Governs |
|---|---|
| `style-bible.md` | the master style block, readability priority, per-category composition and max sizes, naming, QA — **read this before generating or replacing any raster asset** |
| `refs/style-master.png` | the approved Duskblade portrait; the reference for palette, lead-line weight, glass texture and lantern lighting |
| `meta-art-bible.md` | `meta/`, `deeds/`, `bequests/`, and the Emberglass Rose Window |
| `card-art-bible.md` | `cards/` |
| `icon-art-bible.md`, `status-art-bible.md` | icon and status emblems |
| `potion-art-bible.md`, `prop-art-bible.md`, `relic-art-bible.md` | `potions/`, `props/`, `relics/` |
| `ui-chrome-art-bible.md` | UI chrome |
| `act3-theme.md` | Act 3 enemy direction |
| `generated-art-workflow.md`, `imagegen.md` | the render pipeline |
| `art-study-bible.md`, `prop-taxonomy.md` | study notes and prompt rationale |

Do not restate their contents here. Cite them.

## What this file is for

The assets upstream never made. A port-authored asset has no prompt anywhere,
so nothing records how to regenerate it, and nothing notices when it is still a
placeholder. That is not hypothetical: `meta/hollow-lamplighter` sat as an
823-byte flat-vector SVG for the whole port because no ledger listed it as
missing art.

Every asset below is one this port authored. Add a row whenever a new one is
made, with the prompt that made it.

### `meta/hollow-lamplighter.png` — 682×1024 RGBA

The Hollow Lamplighter, the keeper who takes five prices along the Unlit Way.
Shown by `presentation/run/hollow_screen.gd` twice: as the main figure, and as
a faint full-bleed wash behind the copy panel. Both use
`STRETCH_KEEP_ASPECT_CENTERED`, so aspect ratio is free; the display box is
336×558.

Upstream defines this character only as panel 6 of the Rose Window ("a gaunt
keeper surrendering the last flame") — there is no upstream figure prompt.

Style block, verbatim from `style-bible.md`:

> Serious cartoon-gothic stained-glass game art: chunky dark outer silhouette,
> simplified exaggerated proportions, one iconic readable prop or pose, 3-5
> large jewel-tone glass colour masses with very few thick lead dividers, matte
> painterly texture, warm amber rim light, soft controlled inner glow. Designed
> to remain readable at 128px. Fully transparent background (alpha channel). No
> text, no labels, no watermark.

Construction clause — **this paragraph is the load-bearing one**. A first pass
without it returned painted cloth with a little glass texture, not a leaded
figure, because the subject text said "robe" and never said the robe *is*
glass:

> CONSTRUCTION, this is the most important instruction: the figure is not
> painted cloth. His entire robe and body are built from large flat panes of
> coloured glass separated by thick black lead came lines, exactly like a
> cathedral stained-glass window rendered as a character. Each fold of the robe
> is a distinct glass pane with a hard lead border, not a soft painted fold.
> Only a few big panes, never lacework or many small pieces. The lead lines are
> heavy, black, and clearly visible across the whole figure. Glass is cold
> grey-green and deep teal, lit from within by a faint cold glow, with thin
> worn gold edging on the lead. Readable as a solid black shape if all internal
> detail were removed.

Subject:

> The Hollow Lamplighter, a gaunt keeper NPC, tall and skull-thin, in a long
> floor-length robe. Bare head, no raised hood, face a deep black void with no
> glowing eyes. Full body, feet grounded, single complete figure, no cropped
> limbs, calm and still, about 15 percent margin, portrait framing taller than
> wide. The one warm colour in the frame is an amber rim light falling on him
> from outside the frame, from a fire he is not carrying. He holds a tall iron
> lantern pole in one hand. The lantern hanging from it is DARK AND EMPTY: its
> glass panes are cold and dead with no flame inside, the single unlit object in
> a frame where everything else catches light. His other hand is open and empty,
> held forward and low, as though he has just given something away. Facing
> slightly left in three-quarter view.

Two decisions worth keeping:

- **The unlit lantern is the whole character.** 空燈 means the empty lamp; he is
  the one who asks for fire and never carries any. Everything else in the frame
  catches the amber rim light and the lantern does not. Unlit lanterns are
  already in the art language — `deeds/darkWalker` is "an unlit lantern
  silhouette on a black path".
- **He is allowed the keeper silhouette that enemies are forbidden.**
  `style-bible.md` tells enemy art to avoid "noble cloaks, elegant armour,
  upright protagonist poses, clean symmetry, and knight/priest/warden
  silhouettes". He is a meta NPC, not an enemy, so that silhouette is exactly
  what separates him from every creature on the road.

Generated 2026-08-14 through `~/.claude/scripts/subagents/run-imagegen.sh`
(codex first, Cursor fallback; Cursor served it). Five candidates were made and
three were technically shippable — see the rejection note below.

### `enemies/fx/burst.png` — 512×512 RGB, `enemies/fx/ember.png` — 128×128 RGB

Death-rite particle sprites, sampled by `presentation/combat/enemy_view.gd`
(the path is built at `enemy_view.gd:4171`). Both are **RGB with no alpha
channel** — that is deliberate and `enemy_view.gd:4197` documents why.
Introduced by 26b49af. **Prompt not recorded** — reconstruct and add it here
the next time these are touched.

### `scenes/night-stall.png` — 1512×1040 RGB — the approved landscape master

The Night Stall, the shop's whole screen: concept C1 makes the painting the
layout, so this is not decoration but the surface every ware is positioned
against (`presentation/run/stall_layout.gd`). **James approved this file as the
landscape master on 2026-08-15** (#242, "use that").

**It was not generated from a prompt. It is the fourth step of an edit chain**,
and the chain is the provenance — each step took the previous image as input:

1. **The signed C1 concept** — #163's render, still in the design record at
   `docs/design/2026-08-14-ui-direction/stall-scene.png` (1600×1100, gpt-image
   lineage, **prompt never logged**). #242 slice 1 copied it verbatim to this
   asset path as an explicit interim. James rejected its visual state on
   2026-08-15 on four counts: generation noise, one-asset-per-aspect, zero
   chrome over the painting, and ware scale — and specifically ruled that
   **phials hanging on canopy hooks reads wrong; the hooks become a shelf**.
2. **Cursor/grok partial update** — image-to-image over step 1: canopy hooks
   replaced by a wooden shelf, carrying **two deliberately big potions** as a
   scale reference. Edit instruction (verbatim core, `cursor-agent`,
   `cursor-grok-4.6-high`, 2026-08-15): *"PARTIAL UPDATE of an approved image …
   THE ONE CHANGE: in the area under the canopy where hanging hooks are,
   replace the hooks with a wooden potion SHELF (same wood/gothic vocabulary as
   the stall), holding EXACTLY TWO BIG potion bottles — large enough to read
   clearly at game scale, standing on the shelf, glass glinting in the lantern
   light. Nothing else on the shelf. No other goods appear anywhere. ALSO: a
   gentle global cleanup/denoise pass — clear up AI generation noise and muddy
   strokes across the image, without changing any composition, colors, or
   elements."*
3. **James hand-cleaned the strokes himself** on step 2's output. **His cleaned
   file is the canonical step 1 of the two-step pipeline he specified**, and it
   is the file committed as the scale reference (below).
4. **Cursor removal pass** — the two potions painted out of James's cleaned
   image, leaving the empty shelf. This file. James's own denoise attempt on
   step 2 failed and was abandoned; the Cursor output stands as approved.
   Edit instruction (verbatim core, same tool/model): *"PARTIAL UPDATE, one
   removal only … THE ONE CHANGE: remove the TWO potion bottles (red and
   purple) standing on the wooden shelf. The shelf itself stays exactly as it
   is — same wood, same gothic arch backboard, same shadows and lantern light —
   just EMPTY where the two bottles stood, showing bare shelf plank and
   backboard behind. Do not add anything in their place."*

**The scale reference is a committed artefact, not a scratch file.** Step 3
lives at `docs/design/2026-08-14-ui-direction/night-stall-2potions-reference.png`
(1512×1040) and is the ONLY measured datum for how large a ware reads on this
shelf: two bottles 206 image px tall (in this master's own vertical scale —
the reference's content sits 3.2% shorter, fitted `empty_y = potions_y * 1.0331
+ 2.1`, correlation 0.994), standing at u 0.6521–0.6997 and 0.7255–0.7705 with
their bases on the shelf's lit line. `StallLayout`'s region book derives the
phial columns from it and records, in the same docstring, why the runtime flask
lands at 79% of that height rather than 100%. Do not delete or crop that file;
re-measuring the book means re-measuring against it.

Anything that replaces the bytes at this asset path is bound by the numbers the
layout depends on, not by taste alone. All of them are measured off this file by
column/row luminance profile, not eyeballed:

- **1512×1040** (aspect 1.4538), or `StallLayout.IMAGE` moves with it.
- **The counter's front lip at v = 0.7721** — the horizon the whole crop pivots
  on, dead straight from u 0.32 to 0.91.
- **The shelf's lit top face at v = 0.5250**, board u 0.5377–0.885 — the seat
  every phial stands on.
- **Nothing load-bearing outside `StallLayout.SAFE_BAND`** — u ∈ [0.0415,
  0.9585], v ∈ [0.2672, 0.9210]. Shelf, both counter stands, the counter's
  right end and the stair treads are all painted inside it, because a 20:9
  frame crops the rest away.

**Portrait is still open.** James's per-aspect ruling gives 9:20 its own
composition (canopy → shelf → counter → foreground rack), through the same
two-step pipeline once this landscape settles. It is not this file cropped.

### `scenes/` — the ten scripted-scene plates, 1536×1024 palette PNG

The full-bleed plates behind the four scripted scenes (#310), billed by
`docs/story/07-scenes.md` §8 after James's Hybrid verdict on the staging
bake-off. Loaded by path from `content/scenes.json`, never by `preload`.

| Shipped | Winning candidate | Scene |
|---|---|---|
| `opening-hearth.png` | `opening-hearth-c` | Opening, beats ①③④ |
| `unsealing-mirror-queue.png` | `unsealing-mirror-queue-b` | Unsealing, full |
| `unsealing-monuments-push.png` | `unsealing-monuments-push-a` | Unsealing, full |
| `unsealing-door-open.png` | crop of `unsealing-monuments-push-a` | Unsealing, short |
| `act4-node1.png` | `act4-node1-b` | Act IV node 1 (and the entry beat) |
| `act4-node2.png` | `act4-node2-b` | Act IV node 2 |
| `act4-node3.png` | `act4-node3-a` | Act IV node 3 |
| `act4-node4.png` | `act4-node4-b` | Act IV node 4 |
| `act4-node5.png` | `act4-node5-a` | Act IV node 5 |
| `finale-swap.png` | `finale-swap-a` | Finale |

**Prompts are not restated here — they are in
`docs/design/2026-08-16-scene-plates/README.md`**, one per plate, under the
shared style block, with the canon anchor each was derived from. That file is
also the candidate table and the rejection record. Generated 2026-08-16 through
`~/.claude/scripts/subagents/run-imagegen.sh`; candidates in
`docs/design/2026-08-16-scene-plates/candidates/`;
`install_plates.py` reproduces the shipped bytes from them.

Four decisions worth keeping:

- **The frame is fixed by the engine, not by taste.** `project.godot:45` is
  `window/stretch/aspect="keep"`, so every device sees one 1180×820 box. A plate
  meets exactly one aspect ratio — none of `night-stall.png`'s per-aspect safe
  band applies. Rendered at 1536×1024, cover-cropped to 1.4390, which takes 2% of
  width off each side; the dialogue band covers the bottom 12%. Nothing
  load-bearing goes in either.
- **A round lobed window structurally invites the treatment James rejected.**
  The unsealing mirror must show 窗中站滿一排「你」 as *one* queue; the first
  candidate restarted the crowd inside every lobe, which is the per-pane
  duplication ruled creepy on the bake-off. Escalating the negative prompt was
  the wrong lever. Restaging the window as six tall lancets under one arch made
  the correct reading the only one the geometry allows — a single row crosses all
  six at one height with the mullions passing in front.
- **These plates carry no figure that the scene player also supplies.** The
  opening's first candidates baked in the seated hooded figure; the #283 Keeper
  overlays the same plate for beat ②, so that put two bodies on screen. James
  ruled one, and the plate is now an empty hall with a bare hearth step composed
  as the seat. 爐前仍坐着一個兜帽身影 is the overlay's job in every beat that
  needs it.
- **Quantize on the way in, and measure at the `.ctex`, not the PNG.**
  `compress/mode=0` means Godot stores these losslessly, so the packed texture
  tracks image content. Measured on `act4-node5`: RGB `.ctex` 2,205,462 B,
  256-colour `.ctex` 949,946 B — **57% off the shipped texture**, not just the
  repo file. Ten plates land at 11.99 MB of PNG against 26.21 MB unquantized.
  Inspected at full size first; the sunset gradient and cloud sea in `act4-node5`
  are the hardest case in the set and show no visible banding.

### `title/splash.png` — 2360×1640 RGBA

The Godot boot splash, wired at `project.godot:20`. Last corrected by 4007c11
("the splash stops clipping its own name"). **Prompt not recorded** —
reconstruct and add it here the next time it is touched.

### `title/title-zh.png` — 1536×512 RGBA

The zh-Hant title wordmark — 琉璃誓言 cut in the same stained glass as the
English raster, shown in its seat by `choice_screen.gd` whenever the catalogue
title is exactly that string; every other non-English locale keeps the
display-face text fallback. Generated 2026-08-14 through
`~/.claude/scripts/subagents/run-imagegen.sh` with `title/title.png` attached
as the style reference. Prompt (abridged to its binding clauses): "the four
traditional Chinese characters 琉璃誓言 written horizontally, as ornate
stained-glass letterforms — faceted panes in amber, gold and honey with deep
blue and violet panes near the lower stroke edges, dark lead-line (came)
outlines forming a strong kai calligraphic stroke skeleton with sharp tapered
ends, backlit inner glow, thin gold rim light on the outer contour, transparent
RGBA background, no backdrop, no ornaments, no watermark; the characters must
read exactly 琉璃誓言 with correct stroke structure." First candidate accepted:
all four characters structurally correct, transparency real (514,654 fully
transparent pixels, corner alpha 0).

### `meta/keeper.png` — 682×1024 RGBA — hearth seated figure

The Keeper as met at run start: hooded, seated, void face. Overlay for
opening-hearth beat ② (and the every-departure L0 linger) — the plate itself
is an empty hall; this cutout is 「爐前仍坐着一個兜帽身影」 (`00-truth.md`
§5 L0; `07-scenes.md` §8). Shown by the scene player once wiring lands
(#309). Spec: `docs/story/02-cast.md` › Keeper › 資產
(`[SETTLED — #260 Q7]`).

James picked candidate `hearth-d` on 2026-08-16 (#283).

Style block, verbatim from `style-bible.md`:

> Serious cartoon-gothic stained-glass game art: chunky dark outer silhouette,
> simplified exaggerated proportions, one iconic readable pose, 3-5 large
> jewel-tone glass colour masses with very few thick lead dividers, matte
> painterly texture, warm amber rim light, soft controlled inner glow. Designed
> to remain readable at 128px. Fully transparent background (alpha channel). No
> text, no labels, no watermark.

Construction clause — same load-bearing paragraph as `hollow-lamplighter`:

> CONSTRUCTION, this is the most important instruction: the figure is not
> painted cloth. The entire robe, hood and body are built from large flat panes
> of coloured glass separated by thick black lead came lines, exactly like a
> cathedral stained-glass window rendered as a character. Each fold of the robe
> is a distinct glass pane with a hard lead border, not a soft painted fold.
> Only a few big panes, never lacework or many small pieces. The lead lines are
> heavy, black, and clearly visible across the whole figure. Glass is blue,
> violet, teal and deep red, lit from within by a faint cold glow, with thin
> worn gold edging on the lead. Readable as a solid black shape if all internal
> detail were removed.

Subject:

> The Keeper — a seated hooded figure. Full body, sitting with knees drawn in,
> hands folded in the lap, completely still and calm. Raised hood; the hood
> opening is a deep black VOID with NO face, NO eyes, NO glowing points inside
> the hood. Single complete figure, no cropped limbs, about 15 percent margin,
> portrait framing taller than wide. Facing slightly left in three-quarter
> view. The silhouette is a LOW WIDE hooded seated mass — sitting, not
> standing. Warm amber rim light falling on the figure from the RIGHT, from a
> fire outside the frame. The figure holds NOTHING: no lantern, no staff, no
> weapon, no prop. Do NOT draw a hearth, chair, floor, hall, fire, or any
> background object.

Generated 2026-08-16 through the quality `image-gen` tier. Five hearth
candidates; table and rejection record in
`docs/design/2026-08-16-keeper-figures/README.md`. Alpha gate (non-transparent
pixels ≥240 ≥90%, corners 0, `sips -Z 1024`): A/B/D/E pass, C fail (64.5%,
washed — same class as Lamplighter B/E).

### `enemies/eternalKeeper.png` — 682×1024 RGBA — Act IV boss form

The Eternal Keeper, same silhouette as `meta/keeper.png`. Recognition at the
Act IV reveal *is* the design. Lighting is inverted hearth-amber from the
left; the glass goes cold (violet-grey, teal). Hands still folded; hood still
a void; no lantern, crown, halo, or weapon.

**Waiver.** `style-bible.md` tells enemy art to avoid "noble cloaks, elegant
armour, upright protagonist poses, clean symmetry, and knight/priest/warden
silhouettes". This file is an enemy and uses a keeper silhouette on purpose
— `#260 Q7` / `#283`. Do not "fix" it toward a monster read.

James picked candidate `boss-c` on 2026-08-16 (#283), as an image-to-image
edit of `hearth-d`.

Subject delta from the hearth prompt (pose/hood/panes locked to the
reference):

> INVERTED hearth light: warm amber now arrives from the LEFT / far side
> (the wrong direction), catching the lead edges. The rest of the glass goes
> cold — violet-grey, deep teal, less of the domestic warm gold. The glass
> panes glow from within a little more (monumental, not cute).

Four boss candidates from the same reference. Alpha: A 98.4% pass (rim still
from the right — lighting miss), B 84.9% fail (washed), C 98.5% pass, D
98.6% pass. C shipped.

The enemy id `eternalKeeper` landed in `content/full-content.json` with #369.
The raster shipped earlier with #283 at the conventional `enemies/<id>.png`
path. `char-meta.json` has a boss block so combat sizes it without falling
through to `layoutDefault`.

### `stage/act4-backdrop.png` — 1536×1024 RGBA
### `stage/act4-mid.png` — 1536×1024 RGBA
### `stage/act4-ledge.png` — 1536×789 RGBA

Act IV combat plates for 鏡中歸途 / The Mirrored Road. Cutouts, not the
cinematic scene plates: sky is true alpha so `SkyField`'s dawn row shows
through. Motif from `docs/story/03-acts.md` Act IV — monuments queued into
a road, inverted hearth-light from ahead. One set for the whole act.

**James picked these on 2026-08-17 (#221):** backdrop C, mid C, ledge B.
Candidates and the verbatim prompts are in
`docs/design/2026-08-16-act4-combat-art/README.md`. Installer: `install.py`.
Do not regenerate from taste; swap a `PICKS` row and re-run.

First landing used `act1-mid.png` as a style reference and shipped a
lantern-arch. That was a miss, not canon — Act IV combat plates take the
rose-window inner face and monument-road, not Act I's paired lanterns
(those belong to Act IV *node 4* as a mirror, not to the whole-act set).

| Path | Candidate | ≥240 alpha | Notes |
|---|---|---|---|
| `act4-backdrop` | C | 100% | Stelae road, inverted amber; B rejected (Act I left ruin) |
| `act4-mid` | C | 100% | Circular rose window + sentinel stelae; B rejected (lantern-arch) |
| `act4-ledge` | B | 100% | Wide slab, thick front face, two standing-stone posts |

Generated 2026-08-17 through Cursor `GenerateImage`. Stage voids keyed
from the edges (true `#000000` in the render). Character voids are a
**magenta field** — see `unwalkedSelf` below.

### `enemies/unwalkedSelf.png` — Act IV tracer self

The Unwalked, Slice 1's silent counterfactual self (`unwalkedSelf`,
III-prime / broken-ring). Hero silhouette vocabulary (#261 Q5), not a
monster and not the seated Keeper. Void hood, stained-glass scepter, a
broken gold halo. Inverted amber rim from the left; body glass cold
violet / teal.

**James picked D on 2026-08-17 (#221).** A was generated on black
and failed the same way as a boxed sprite: GenerateImage emits RGB with a
near-black haze, the hood is also black, and a flood-fill from the edges
cannot eat the haze without eating the face. Corners-clear + ≥240-of-nonzero
does not catch that — the haze is fully opaque. D uses a magenta field;
`install.py` keys magenta (hood stays) and punches large enclosed magenta
arm-gaps. Gate: leftover field-magenta < 32, and opaque near-black in the
8px canvas frame < 400.

Combat box is `tierSizes.normal * 1.6` (296px) — at least 50% above the
first landing's `1.05` (194px). The painting already sits on the 1024 max
edge; on-screen size is the char-meta knob, not a bigger PNG.

Prompt (binding clauses):

> BACKGROUND is a FLAT SOLID MAGENTA #FF00FF field, edge to edge. No black
> vignette. CONSTRUCTION: the body IS leaded stained-glass panes. The
> Unwalked, silent counterfactual pilgrim, full body, 15 percent magenta
> margin. Raised hood; hood opening is a deep BLACK VOID with NO face —
> black exists ONLY inside the hood. Tall stained-glass scepter, not a
> lantern. BROKEN golden halo snapped at the top. INVERTED hearth light:
> amber rim from the LEFT; remaining glass cold violet / teal / court
> purple. No text, no watermark.

### `enemies/uncrossedSelf.png` — Act IV II-prime self

The Uncrossed (`uncrossedSelf`, II-prime / false-light). Same hero
silhouette and void hood as the Unwalked; prop is a hand-held teal
false-lamp and a closed library folio — water, lying light, unread page.
No broken halo (that is III-prime). Combat box `1.6` like the tracer.

**James picked B on 2026-08-17 (#221).** A is the same props,
narrower. Magenta field; gate as `unwalkedSelf`.

Prompt (binding clauses):

> BACKGROUND is a FLAT SOLID MAGENTA #FF00FF field. CONSTRUCTION: the
> body IS leaded stained-glass panes. The Uncrossed, full body, 15
> percent magenta margin. Void hood; black ONLY inside the hood. HAND-HELD
> false lamp with a cold teal flame, NOT hanging, NOT paired, NOT an
> arch. Closed library folio. NO golden halo, NO scepter. Brine teal /
> sea-green glass; amber rim from the LEFT.

### `enemies/unopenedSelf.png` — Act IV threshold-prime self

The Unopened (`unopenedSelf`, threshold-prime / stained-glass). Handheld
six-petal rose-window disc, some petals dark, some amber; wax seal at
the belt. Intact rose, not a broken halo. Combat box `1.6`.

**James picked A on 2026-08-17 (#221).** B's gothic tablet reads
as a door-arch. Magenta field; gate as `unwalkedSelf`.

Prompt (binding clauses):

> BACKGROUND is a FLAT SOLID MAGENTA #FF00FF field. CONSTRUCTION: the
> body IS leaded stained-glass panes. The Unopened, full body, 15 percent
> magenta margin. Void hood; black ONLY inside the hood. Circular
> SIX-PETAL rose-window PANE held as a disc — intact, unopened. Wax seal
> at the belt. NO scepter, NO broken halo, NO hanging lanterns. Honey /
> amber / dark unlit violet; amber rim from the LEFT.

### `enemies/unlitSelf.png` — Act IV I-prime self

The Unstruck (`unlitSelf`, I-prime / paired-lanterns). English display
avoids colliding with locked "the Unlit Way". Two hand-held unlit lamps
(dark wicks, no flame); ashroot glass at the hem. Distinct from the
Uncrossed's one teal lying lamp. Combat box `1.6` like the tracer.

**James picked B on 2026-08-17 (#221).** A failed leftover
field-magenta (94) in the right arm-gap — the enclosed punch only eats
blobs ≥200. Magenta field; gate as `unwalkedSelf`.

Prompt (binding clauses):

> BACKGROUND is a FLAT SOLID MAGENTA #FF00FF field. CONSTRUCTION: the
> body IS leaded stained-glass panes. The Unstruck, full body, 15 percent
> magenta margin. Void hood; black ONLY inside the hood. TWO HAND-HELD
> UNLIT lamps, dark wicks, NO flame, NOT hanging, NOT an arch. Ash / root
> glass at the hem. NO teal lying lamp, NO halo, NO scepter. Grey-ash /
> worn gold; amber rim from the LEFT.

### `enemies/unsunkSelf.png` — Act IV II-prime elite

The Unsunk (`unsunkSelf`, II-prime / library, `elite: true`). Held
drowned book-stack; still-tide water-glass at the hem. No lantern.
Combat box is `tierSizes.elite * 1.4` (322px) — a step above the tracer
self (296px) and the hero (285px). 1.6 (368px) overshot both and crowded
the END button.

**James picked A on 2026-08-17 (#221).** B's standing unread-shelf
reads as furniture beside the pilgrim. Magenta field; gate as
`unwalkedSelf`.

Prompt (binding clauses):

> BACKGROUND is a FLAT SOLID MAGENTA #FF00FF field. CONSTRUCTION: the
> body IS leaded stained-glass panes. The Unsunk, full body, slightly
> broader pilgrim, 15 percent magenta margin. Void hood; black ONLY
> inside the hood. Drowned BOOK-STACK held against the chest. Still-tide
> water-glass at the hem. NO lantern, NO halo, NO scepter. Brine teal /
> indigo; amber rim from the LEFT.

### `enemies/uncarvedSelf.png` — Act IV threshold-prime elite

The Uncarved (`uncarvedSelf`, threshold-prime / seal-relief,
`elite: true`). Blank rectangular relief tablet with an unfinished
circular seal — the door-face of the same threshold whose window-face
is the Unopened's rose disc. Combat box `tierSizes.elite * 1.4` (322px),
same as `unsunkSelf`.

**James picked C on 2026-08-17 (#221).** A is a stone tome (library
collision with Unsunk). B's rounded carved tablet reads as a door
fragment. Magenta field; gate as `unwalkedSelf`.

Prompt (binding clauses):

> BACKGROUND is a FLAT SOLID MAGENTA #FF00FF field. CONSTRUCTION: the
> body IS leaded stained-glass panes. The Uncarved, full body, slightly
> broader pilgrim, 15 percent magenta margin. Void hood; black ONLY
> inside the hood. RECTANGULAR unfinished seal-relief TABLET, mostly
> blank, one faint circular indent. NOT a book, NOT a rose disc, NOT a
> door-arch. Amber / sandstone / umber; amber rim from the LEFT.

### `enemies/unobsidianSelf.png` — Act IV III-prime remaining normal

The Unobsidian (`unobsidianSelf`, III-prime / obsidian-star). Handheld
eight-point obsidian star; court-violet glass going black. Distinct from
the Unwalked: no broken halo, no scepter. Combat box `1.6` like the
tracer.

**James picked A on 2026-08-17 (#221).** B's hanging star-chain
failed leftover field-magenta (222). Magenta field; gate as
`unwalkedSelf`.

Prompt (binding clauses):

> BACKGROUND is a FLAT SOLID MAGENTA #FF00FF field. CONSTRUCTION: the
> body IS leaded stained-glass panes. The Unobsidian, full body, 15
> percent magenta margin. Void hood; black ONLY inside the hood. HANDHELD
> eight-point obsidian STAR, not a scepter, not a hanging lantern. NO
> broken halo, NO books. Court-violet going black; amber rim from the
> LEFT.

### `enemies/unwoodedSelf.png` — Act IV I-prime remaining normal

The Unwooded (`unwoodedSelf`, I-prime / ash-root). Held unburned ash-root
branch bundle (wood-glass, not a crystal scepter); cinders at the hem.
Distinct from the Unstruck: no paired lamps. Combat box `1.6`.

**James picked B on 2026-08-17 (#221).** A's staff+rooted hem
failed leftover field-magenta (108) — the enclosed punch only eats
blobs ≥200. Magenta field; gate as `unwalkedSelf`.

Prompt (binding clauses):

> BACKGROUND is a FLAT SOLID MAGENTA #FF00FF field. CONSTRUCTION: the
> body IS leaded stained-glass panes. The Unwooded, full body, 15 percent
> magenta margin. Void hood; black ONLY inside the hood. Unburned
> ASH-ROOT branch bundle, not a crystal scepter. Cinders at the hem. NO
> lantern, NO star, NO books, NO paired lamps. Warm amber / ash-grey;
> amber rim from the LEFT.

### `title-background/background.png` — 1536×1024 RGB — title banner plate

The translucent title banner (`choice_screen.gd`, opacity 0.35) that sits
over the living `TitleWorld`. Import `compress/mode=0`, no mipmaps, **RGB
with no alpha** — the banner drop-shadow is a closed-form blur of an opaque
rectangle; an alpha channel would change that contract.

Replaced 2026-08-17 for #304. The previous plate was a gothic lathed spire
wreathed in a lit switchback stair (Tier A banned: stair as *the road*).
The new plate is the same world the procedural backdrop now draws: a
horizontal pilgrimage road receding east to a sealed gothic door, lanterns
along both verges, forest closing the frame, cloud sea, night sky. No
tower, no spire, no wrapping stair.

Style block, landscape (not a character cutout):

> Serious cartoon-gothic stained-glass game art: night landscape, chunky
> dark silhouettes, 3-5 large jewel-tone colour masses, matte painterly
> texture, warm amber lantern light, soft controlled glow. No text, no
> labels, no watermark, no UI.

Subject:

> A HORIZONTAL pilgrimage road receding toward a distant SEALED gothic
> pointed-arch door, night, dark forest of bare pines closing left and
> right. Warm amber lanterns in two ranks along the road, leading the eye
> to the door. The door is a solid near-black silhouette with a faint
> six-petal rose-window hint in its upper arch — sealed, not open. Cloud
> sea around the door, deep midnight-blue sky, a thin pale crescent moon
> far left. Ember motes in the near air. The road is packed earth, slightly
> warmer than the ground, running from the bottom of the frame to the
> door at the vanishing point. NO tower, NO spire, NO castle, NO wrapping
> staircase, NO switchback stair, NO vertical building as the subject.
> Opaque RGB, edge to edge, no transparency.

Generated 2026-08-17 through Cursor `GenerateImage`. Cropped/resized to
1536×1024 RGB so the banner's contain-fit and drop-shadow stay valid.

## Rejection note — what "technically shippable" means

Judging generated character art by eye is not enough; two of the five
Lamplighter candidates looked correct against a dark viewer background and were
measurably unusable. Measure the alpha distribution over non-transparent pixels
before accepting any cutout:

| Candidate | ≥240 alpha | Verdict |
|---|---|---|
| A, C, D | 94.7%, 94.4%, 94.0% | solid figures, real cutout, corners clear |
| B, E | 5.6%, 7.3% | the whole figure is semi-transparent — fine on black, washed out on any lighter ground |

D shipped: the only candidate that was both technically clean and built from
leaded panes rather than painted cloth.

## Contract

- Max edge for a full-body character is **1024** (`style-bible.md`
  per-category table); normalise with `sips -Z 1024`.
- Transparent background, single complete figure, no cropped limbs, no baked
  text.
- After adding or replacing any asset: `tools/check_imports.sh`, then
  `tools/check_scripts.sh` if a script path changed, then
  `godot --headless -s res://tests/run_all.gd`. A wrong `res://` path makes
  `load()` return null, and the suite is what catches it.
