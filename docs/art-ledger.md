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
(the path is built at `enemy_view.gd:4212`). Both are **RGB with no alpha
channel** — that is deliberate and `enemy_view.gd:4238` documents why.
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

**Shipping is landscape only** (`docs/design/2026-08-18-landscape-only.md`).
Identity is pad-landscape 1180×820; phone-landscape's short 844×390 stage and
4:3 iPad (flexed pad-landscape) hold this same composition — one rack row,
scaled, not a restack. `phone-portrait` and `pad-portrait` are retired. This
file is the landscape master, not a portrait source.

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

### `title/splash.png` — 2360×1640 — frame 0 of the launch rite

The Godot boot splash (`project.godot` `boot_splash/image`, fullsize, on the
`#05070e` ground the title's veil uses). Since 2026-10-02 it is not a logo
card: it is the first frame of the kindling (docs/design/2026-10-02-opening-
start §7 T0) — night and one ember at the lantern's wick — rendered from the
production TitleScreen, so the splash and the first frame register:

    godot --path . --position 0,0 -s res://tools/capture_title.gd -- \
        --shape=pad-landscape --locale=en --state=fresh --rite=0 --scale=2 \
        --out=assets/art/title/splash.png

No model made it; re-run the command after any change to the lantern's wick
or the ember. The wick sits at 0.918 of the stage height on pad and phone so
the fitted splash's ember lands on it. The previous splash (the wordmark on
black; prompt never recorded) is in git history at 4007c11.

### `title/lantern-hero.png` — 1024×1024 RGBA — lane pick, owner re-pick open

The hero's lantern on the title (`LeadlightLantern`, docs/design/2026-10-02-
opening-start): the combat HUD lantern (`ui/lantern.png`) repainted at hero
size, so the title's flame is the same object as the HUD's. Four candidates
and a labelled contact sheet live in `docs/design/2026-10-02-opening-start/
lantern/`; candidate 1 (closest to the HUD art) is the pick. Generated
2026-10-02 by the `image-gen` agent (it routed to the Codex image tool,
image-to-image with `ui/lantern.png` attached as the identity reference),
1024×1536 with real alpha. Prompt (binding clauses): "the SAME Gothic
hexagonal hanging iron lantern as the reference, front view, perfectly
centred, upright, symmetrical … chain ring and connecting link at the top,
tiered pointed hexagonal roof with its small corner finials, dark chunky
hexagonal cage, exactly three visible pointed-arch glass lights … thick
black lead came and diamond-like pointed lead tracery, faceted bottom ledge
and short downward spike … serious cartoon-gothic stained-glass game art,
matte painterly texture … glass exclusively bright warm saturated amber-gold
… iron predominantly dark grey-black with ONLY thin restrained worn gold
edging … genuine alpha transparency … Candidate 1: closest faithful copy of
the reference." The full prompts for all four are in
`lantern/generation-prompts.txt` beside the candidates.

**Registered, not cropped.** `lantern_flame.gdshader` lights the art in its
own UV (wick 0.5, 0.785; panes 0.31–0.69 × 0.43–0.795) and finds the glass by
colour. `lantern/register.py` measured the pick's centre light with the
shader's own glass test and placed it with one uniform scale onto the HUD
art's set-out at twice its resolution: centre light 0.474–0.782 (HUD
0.475–0.785), lights 0.344–0.401 / 0.441–0.554 / 0.595–0.651 (HUD .344–.400 /
.441–.553 / .594–.650). The shader lights it unchanged.

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

The translucent title banner (`title_screen.gd`, opacity 0.35) that sits
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

### `map-journey/` — Act I journey kit, revived 3 Oct 2026

The September journey rebuild's Act I woodland kit (owner-approved at its
Step 3, Review 10), revived on the production map by the map lane on 3 Oct
2026 (`docs/design/2026-10-02-map-living-land/revival.md`). Copied unchanged
from the archive (`archive/superseded-20260929/jamesto/map-journey-rebuild`
at `7d64678b`): 15 GLBs built by the Blender recipes in
`tools/map_atelier/journey/` (`build_kit.py`, `foliage.py`,
`natural_variants.py`, `stone_finish.py`; `.blend` sources beside them), and
the three painted sources in `textures/`, generated 5 Sep 2026 with the
built-in image generator against the approved Act I concept
(`textures/README.md` records the source outputs).

**Changed on revival, pixels untouched:** the GLBs import without their
embedded images (every GLB carried its own copy of one of the three
sources), the per-GLB extracted PNGs are gone, and the three sources import
VRAM-compressed with mipmaps. `presentation/map/landscape/asset_surfaces.gd`
gives each kit material the shared source its authored name calls for.

**R2 additions (the living land, 3 Oct 2026), lane picks, owner re-pick open:**

| Asset | Recipe | Notes |
|---|---|---|
| `lantern-post.glb` | `tools/map_atelier/journey/living_kit.py` (Blender, `blender -b -P`), master `sources/lantern-post.blend` | A stone post (plinth, shaft, cap in the kit's ash stone, `stone_finish`) carrying the gateway's amber lantern (`build_kit.lantern`, without its chain). 296 triangles, no textures of its own. The flame sits at the glass centre, 1.38 m up (`Kit.LAMP_ANCHORS`). Candidate kept: this is the only one. |
| `bridge-banner.glb` | `tools/map_atelier/journey/living_kit.py` (`bridge_banner`), master `sources/bridge-banner.blend` | A red cloth banner (the kit's ash-leaf red, deepened) with a gold band and centre stripe on an iron bar with finials, after the owner's target's bridge banners; the cloth is subdivided 4×12 with a swallowtail hem so `banner.gdshader` has rows to ripple. 232 triangles, no textures. Hung from the bridge parapets on the camera's side. Candidate kept: this is the only one; the target's tree emblem is not drawn (owner re-pick open). |
| `textures/flame-flipbook.png` | `tools/map_atelier/journey/flame_flipbook.py` (numpy, Pillow; seed 7411) | 256×256, sixteen 64×64 frames of one looping flicker (value noise sampled round a circle in time, so the loop closes). Imports VRAM-compressed with mipmaps. Drawn additively on every lamp by `presentation/map/landscape/flame.gdshader`. |

`build_kit.py` gained a `__main__` guard (importing it builds nothing) and a
`chain` switch on `lantern()` that defaults to the R1 lamp; rebuilding the R1
kit gives byte-identical GLBs.

**R3.1 additions (the wood, 3 Oct 2026), lane picks, owner re-pick open:**

| Asset | Recipe | Notes |
|---|---|---|
| `impostors/wood-albedo.png` | `tools/map_atelier/journey/impostors/bake_impostors.gd` (Godot, windowed: renders each kind from the journey camera's one direction), then `pack_impostors.py` (numpy, OpenCV, Pillow) | 2048×1408 RGBA: 13 kinds at 3–4 yaws (42 tiles) at 56 texels a metre, alpha the coverage, transparent texels filled from their nearest covered neighbour so mips never darken a cut edge. Imports VRAM-compressed with mipmaps (3.8 MB ETC2). |
| `impostors/wood-normal.png` | the same bake and pack | 1024×704 RGBA, half the albedo's resolution: world normal in RGB (raw), and in alpha how much of the key light reaches each texel through its own crown, darkened where a leaf shows through a gap. Imports VRAM-compressed, not as a normal map (0.9 MB ETC2). |
| `impostors/wood-tiles.json` | `pack_impostors.py` | Per tile: kind, atlas rect, picture-plane rect, reach toward the camera, height, and the silhouette as row spans (the planting's occlusion mask). 20 KB. |

**Sources, kept:** the kit's own models (`assets/art/map-journey/*.glb`, the
R1 kit above) and the bake recipe. The recipe stacks turned copies of the
kit conifers into fuller spruce, composes four broadleaf kinds from the kit's
bare snag crowned with heath and copse leaf clumps in sprays (crimson
`ember-oak` and `ember-round`, `rust-oak`, `amber-round`), and repaints two
undergrowth kinds (`olive-heath`, `dark-copse`) at their own luminance in a
new hue. The bake is deterministic: re-running it reproduces the atlas byte
for byte. A crafted Blender source per kind replaces a recipe as a data-only
re-bake (`docs/design/2026-10-02-map-living-land/r3/r3-1b-wood/README.md`
lists what each kind needs).

**R3.2 additions (the floor, 5 Oct 2026), lane picks, owner re-pick open:**

The floor's bake (`presentation/map/landscape/floor_bake.gd`) paints Act I's
ground with these at run time; only `floor-detail.png` is drawn live. The four
covers and the scatter were generated on 5 Oct 2026 with the built-in image
generator (ChatGPT's image tool through the lane's runner), one candidate each,
kept as the lane's pick; the prompts are in
`tools/map_atelier/journey/floor/sources/prompts.txt`, and the pictures as
generated (the covers as JPEG at quality 95, the scatter as PNG) beside them.
`tools/map_atelier/journey/floor/prepare_floor.py` (numpy, Pillow; seed 717)
makes every shipped file from them, byte for byte on a re-run.

| Asset | From | Notes |
|---|---|---|
| `floor/floor-moss.png` | `sources/floor-moss.jpg` | Dark forest moss, top-down. Slow light divided out, edges wrapped by a half-tile roll, saturation 0.62 and a bronze-olive grade (never a lawn green), 512×512 RGB. The bake spans it over 2.6 m. |
| `floor/floor-litter.png` | `sources/floor-litter.jpg` | Fallen ash and maple leaves, scarlet to rust, partly decayed. Same treatment, saturation 0.9, 512×512 RGB, over 3.2 m. |
| `floor/floor-soil.png` | `sources/floor-soil.jpg` | Ash-grey soil with grit and needles. Saturation 0.8, 512×512 RGB, over 2.4 m. |
| `floor/floor-road.png` | `sources/floor-road.jpg` | Packed earth with pebbles, the worn road. Saturation 0.85 (the bake takes it to 0.45), 512×512 RGB, over 2.2 m. |
| `floor/floor-splats.png` | `sources/floor-splats.png` | The scatter: a 4×4 sheet of pebbles, twigs, leaves and clumps (a cone, dry grass, a mossy stone) generated on a flat green key; the key cut to alpha, its spill pulled back, the colour bled under the cut so mips keep each sprite's own edge, 512×512 RGBA. |
| `floor/floor-detail.png` | `prepare_floor.py` from the soil and road covers | The live floor's micro detail: grain (r) from the two covers' fine structure, sparse glint speckles (g) and their twinkle phases (b), 512×512, wrapping; the floor tiles it every 10 m. |

All import VRAM-compressed with mipmaps.

**R3.3 additions (the stone, 9 Oct 2026), lane picks, owner re-pick open:**

Act I's granite outcrops, the ravine's cliff kit and its ruins, crafted in
Blender 5.2.2 (background, 4 threads) from one recipe per kind in
`tools/map_atelier/journey/stone/` (`outcrops.py`, `cliffs.py`, `ruins.py`,
the shared workshop `sculpt.py`, entry `build_stone.py`); the masters are in
`tools/map_atelier/journey/sources/<kind>.blend`. Each kind is sculpted from
fused masses, cut on its joints, cracked by seeded Voronoi noise, reduced to
its triangle budget and baked in Cycles (normals, occlusion, colour). The two
source pictures were generated on 5 Oct 2026 with the built-in image
generator (ChatGPT's image tool through the lane's runner), one candidate
each, kept as the lane's pick; the prompts are in
`tools/map_atelier/journey/stone/sources/prompts.txt`, the pictures (JPEG at
quality 95) beside them. `prepare_stone.py` (numpy, Pillow) makes the tiles
the kit paints with and the shipped strata, byte for byte on a re-run. A
re-run of `build_stone.py` reproduces every shipped and source file byte for
byte except the `.blend` masters, which Blender writes with bytes of its own.

| Asset | From | Notes |
|---|---|---|
| `stone/stone-albedo.png` | `build_stone.py` (Blender, Cycles), the granite and strata tiles | 2048×1536 RGB, 4×3 cells of 512: the five outcrops (`granite-bank`, `-ridge`, `-shard`, `-tor`, `-boulder`) and the six cliff pieces (`cliff-wall`, `-notch`, `-buttress`, `-bend`, `-step`, `-tall`), each kind's colour baked into its own cell and darkened by its baked occlusion (a share of 0.75). Granite: a cool mid grey under the warm key, its lichen muted; strata: warm grey-browns. 2.1 MB ETC2. |
| `stone/stone-normal.png` | the same bake | 1024×768: the tangent-space normals at half the colour's size, renormalised. Imports as a normal map (RG): 1.0 MB ETC2. |
| `stone/stone-pieces.res` | `pack_stone.gd` (Godot, headless) from `tools/map_atelier/journey/stone/glb/<kind>.glb` | The eleven hero kinds' reduced meshes as plain arrays (vertex, normal, tangent, UV, index), 874–1,400 triangles an outcrop and 1,074 a cliff piece; the land merges them on its worker. 0.47 MB. The GLBs do not ship. |
| `stone/strata.png` | `prepare_stone.py` from `sources/strata.jpg` | 512×512 RGB, the strata the floor's bake lays on the ravine's steep banks (`floor_paint.gdshader`), 1.6 m a tile. 0.17 MB ETC2. |
| `stone/manifest.json` | `build_stone.py` | Every kind's triangles, footprint circle, top and foot, atlas cell and description. Not loaded by the game. |
| `impostors/wood-albedo.png`, `wood-normal.png`, `wood-tiles.json` | `bake_impostors.gd` and `pack_impostors.py` (R3.1's), with ten new recipes | The ruins as impostor kinds, re-baked into the woodland's atlas, which grows from 2048×1408 to 2048×1776 (79 tiles, 37 of them the ruins'): four gravestones (`grave-arched`, `-cross`, `-broken`, `-tablet`) and three broken walls (`wall-run`, `-corner`, `-pier`) at four yaws, three rubble clusters (`rubble-blocks`, `-scree`, `-mossy`) at three. Their sources are the kit's own sculpts at 2,500–6,000 triangles with their colour baked onto their own UVs (`tools/map_atelier/journey/impostors/stone/`, not shipped). The woodland's 42 tiles are the same as before on every covered texel. +1.25 MB ETC2. |

The moss on the outcrops is the floor's own `floor/floor-moss.png`, sampled
in world space and lifted to an olive green by `stone.gdshader`: nothing new
ships for it.

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

### `map-concepts/shared-road-slab-a.jpg` — 1:1 concept, not a shipping texture

Tripo Studio image-to-3D input for kit module `shared-road-slab-a` (#292).
Lives outside `assets/art/map/` so `tools/check_map_assets.py` does not treat
it as undeclared payload. Not imported by Godot.

Prompt (2026-08-19, Grok Imagine):

> Orthographic 3/4 view of a single game-kitbash 3D prop: a broad low stone
> road slab, like a short thick paving block. Simple geometric mass only — a
> flat-topped rectangular slab with slightly broken front-right corner, no
> carved ornament, no cracks as thin lines, no grass, no moss. Flat even
> studio lighting from above-front, no cast shadow on the ground, no baked
> AO, no rim light. Isolated subject centered, large in frame. Solid flat
> medium-gray background (#8A8A8A), no horizon, no environment. Clean
> silhouette, chunky low-poly look, matte untextured clay-maquette surface.
> Not a tile texture, not a landscape.

sha256 `619d97054471996410be36370d1ec128d0f90489e7c55dc00e47bc0d8a31d54a`.

### `map-concepts/shared-road-slab-b.jpg` — 1:1 concept, not a shipping texture

Tripo Studio image-to-3D input for kit module `shared-road-slab-b` (S2 in
`docs/map-scene-asset-bill.md`: broken/offset slab). Same clay-maquette
language as `shared-road-slab-a.jpg`; derived from that file with `image_edit`
so lighting and material stay put. Lives outside `assets/art/map/`.

Edit prompt (2026-08-19, Grok Imagine, seeded from slab-a):

> Keep the exact same clay-maquette look, medium-gray studio background, even
> above-front lighting, 3/4 orthographic view, and matte untextured stone
> surface. Change only the slab mass: this is a different road slab — offset,
> not a single rectangle. The left half sits a finger-width lower than the
> right half like a short step, the far-left front corner is a missing chunk,
> and the right edge is a short raised lip. Same chunky low-poly geometric
> mass, no carved ornament, no grass, no moss, no thin crack lines, no cast
> shadow on the ground. Isolated, centered, large in frame. Distinct
> silhouette from a single clean block.

sha256 `662b5213fca5a475feb2bf7e9a3ebf9cb44e94f90a799a511a716c3bc2b202c9`.

### `map-concepts/shared-standing-monument.jpg` — 1:1 concept, not a shipping texture

Tripo Studio image-to-3D input for kit module `shared-standing-monument` (S3 in
`docs/map-scene-asset-bill.md`: fallen-walker read; broad standing mass, no
carving noise). Same clay-maquette language as `shared-road-slab-a.jpg`;
derived from that file with `image_edit` so lighting and material stay put.
Lives outside `assets/art/map/`.

Edit prompt (2026-08-19, Grok Imagine, seeded from slab-a):

> Keep the exact same clay-maquette look, medium-gray studio background, even
> above-front lighting, 3/4 orthographic view, and matte untextured stone
> surface. Replace the low road slab with one different prop: a single standing
> monument, a broad upright weathered stele like a thick person-height stone
> that reads as a fallen walker who is standing — one chunky vertical mass,
> slightly wider at the base, a blunt rounded top, one missing chunk off the
> upper-right shoulder. No carved faces, no letters, no ornament, no arms, no
> grass, no moss, no thin crack lines, no cast shadow on the ground. Isolated,
> centered, large in frame. Distinct tall silhouette, still a simple geometric
> kitbash mass.

Fuse pass (2026-08-21, Grok Imagine, seeded from the 2026-08-19 concept). The
first Studio Smart Mesh output from that file was two islands (2026-08-19);
a 2026-08-21 retry on the same bytes was three islands, two of them 28–49 mm
chips in the shoulder notch. The fuse makes the missing chunk a concave bite
in one volume:

> Keep the same clay-maquette look, medium-gray studio background, even
> above-front lighting, and 3/4 orthographic view. Fuse the standing monument
> into one continuous upright stone — no gaps, no separate chips, no second
> block sitting in the shoulder. The missing upper-right chunk is a concave
> bite in the same solid volume. One connected stele, slightly wider at the
> base, blunt rounded top, sitting on the ground. Distinct tall silhouette,
> still a simple game-kitbash mass.

Isolate pass (same day, seeded from the fuse): drop the ground plane, horizon,
and cast shadow so Smart Mesh does not emit a floor island.

sha256 `b4b0ddfaa07e2b6f5083e9185413931123154ee5bd6ec7cb59f2c68aef80d2b3`.

Accepted by fol2 on 2026-08-21. Shipping mesh is the fused Studio Pro Export
GLB at `geometry/shared/standing-monument.glb`. Studio Pro is the generating
product; API generation is forbidden. Canonical 20-placement capture:
`docs/reviews/293/shared-standing-monument-20.png`.

### `map-concepts/act1-ash-trunk-fork.jpg` — 1:1 concept, not a shipping texture

Tripo Studio image-to-3D input for kit module `act1-ash-trunk-fork` (A1-1 in
`docs/map-scene-asset-bill.md`: forked ash-tree mass). Same clay-maquette
language as `shared-road-slab-a.jpg`; derived from that file with `image_edit`.

Edit prompt (2026-08-19, Grok Imagine, seeded from slab-a):

> Keep the exact same clay-maquette look, medium-gray studio background, even
> above-front lighting, 3/4 orthographic view, and matte untextured
> stone-or-wood surface. Replace the low road slab with one different prop: a
> single forked ash-tree trunk mass. Short thick charred trunk that splits into
> two stubby branches like a Y, chunky low-poly geometric volumes, no leaves,
> no twigs, no bark grain, no grass, no moss, no thin crack lines, no cast
> shadow on the ground. Isolated, centered, large in frame. Distinct tall
> forked silhouette, still a simple game-kitbash mass.

sha256 `c39952778ebf599d91ab5c9a22d2ab4b74941d52f418b0f407b433c5c2d0ad24`.

### `map-concepts/act1-root-wedge.jpg` — 1:1 concept, not a shipping texture

Tripo Studio image-to-3D input for kit module `act1-root-wedge` (A1-2 in
`docs/map-scene-asset-bill.md`: roots cutting through the ground plane). Same
clay-maquette language as `shared-road-slab-a.jpg`; derived from that file with
`image_edit`.

Edit prompt (2026-08-19, Grok Imagine, seeded from slab-a):

> Keep the exact same clay-maquette look, medium-gray studio background, even
> above-front lighting, 3/4 orthographic view, and matte untextured
> wood-or-stone surface. Replace the low road slab with one different prop: a
> single root wedge. Thick triangular root mass cutting up through a ground
> plane, like a buried root bursting the dirt — chunky low-poly geometric
> volumes, one sharp wedge rising, a short buried heel. No leaves, no twigs,
> no bark grain, no grass blades, no moss, no thin crack lines, no cast shadow
> on the ground. Isolated, centered, large in frame. Distinct wedge silhouette,
> still a simple game-kitbash mass.

sha256 `d0c0e3652fa0f84c85a5e5236f21e41545a50a097d781a5c10bfba1d92cdc2e7`.

### `map-concepts/act1-charred-stump.jpg` — 1:1 concept, not a shipping texture

Tripo Studio image-to-3D input for kit module `act1-charred-stump` (A1-3 in
`docs/map-scene-asset-bill.md`: low charred mass). Same clay-maquette language
as `shared-road-slab-a.jpg`; derived from that file with `image_edit`. One
connected volume (no detached chips) so Smart Mesh is less likely to emit two
islands.

Edit prompt (2026-08-19, Grok Imagine, seeded from slab-a):

> Keep the exact same clay-maquette look, medium-gray studio background, even
> above-front lighting, 3/4 orthographic view, and matte untextured
> wood-or-stone surface. Replace the low road slab with one different prop: a
> single low charred stump. One short thick burned tree-base mass, wider than
> it is tall, a blunt chopped top, the whole thing one connected volume sitting
> on the ground — no separate chips, no second block, no roots as extra pieces.
> Chunky low-poly geometric volumes. Isolated, centered, large in frame.
> Distinct low squat silhouette, still a simple game-kitbash mass.

sha256 `2d07f80575b526291692e31e7410132f8c30ae4a347c8d2a3e5dc9df9313c9c5`.

### `map-concepts/act1-fallen-bough-arch.jpg` — 1:1 concept, not a shipping texture

Tripo Studio image-to-3D input for kit module `act1-fallen-bough-arch` (A1-4 in
`docs/map-scene-asset-bill.md`: threshold-shaped fallen tree). Same clay-maquette
language as `shared-road-slab-a.jpg`; derived from that file with `image_edit`,
then a second edit fused segmented blocks into one log so Smart Mesh is less
likely to emit islands.

Edit prompt (2026-08-19, Grok Imagine, seeded from slab-a):

> Keep the exact same clay-maquette look, medium-gray studio background, even
> above-front lighting, 3/4 orthographic view, and matte untextured
> wood-or-stone surface. Replace the low road slab with one different prop: a
> single fallen-bough arch. One connected threshold-shaped fallen tree, a thick
> log that bends into a low doorway arch, both ends on the ground, the whole
> thing one fused volume — no separate branches, no second log, no chips.
> Chunky low-poly geometric volumes. Isolated, centered, large in frame.
> Distinct arch silhouette, still a simple game-kitbash mass.

Fuse pass (same day, seeded from the first edit):

> Keep the same clay-maquette look, medium-gray studio background, even
> lighting, and 3/4 view. Fuse the arch into one continuous bent log — no gaps
> between blocks, no separate stones, one solid threshold-shaped fallen tree.
> Both ends on the ground, one connected volume.

sha256 `9f1b95c8e01b49cc516e971722d8d99a1b0e7fb1f72399fd4153d0f74307ec98`.

### `map-concepts/act1-ash-cairn-mass.jpg` — 1:1 concept, not a shipping texture

Tripo Studio image-to-3D input for kit module `act1-ash-cairn-mass` (A1-5 in
`docs/map-scene-asset-bill.md`: ash/stone dab mass). Same clay-maquette
language as `shared-road-slab-a.jpg`; derived from that file with `image_edit`.
One connected mound (no loose stones) so Smart Mesh is less likely to emit
islands.

Edit prompt (2026-08-20, Grok Imagine, seeded from slab-a):

> Keep the exact same clay-maquette look, medium-gray studio background, even
> above-front lighting, 3/4 orthographic view, and matte untextured
> stone-or-ash surface. Replace the low road slab with one different prop: a
> single ash-cairn mass. One compact piled heap of fused ash-stone, a short
> squat cairn — several chunky stones melted into one connected mound, wider
> than it is tall, sitting on the ground. No separate rocks, no stacked gaps,
> no second pile, no grass, no moss, no thin crack lines, no cast shadow on
> the ground. Isolated, centered, large in frame. Distinct mound silhouette,
> still a simple game-kitbash mass.

Fuse pass (same day, seeded from the first edit):

> Keep the same clay-maquette look, medium-gray studio background, even
> lighting, and 3/4 view. Fuse the cairn into one continuous squat mound — no
> gaps between stones, no stacked seams, no separate rocks. One solid
> connected ash-stone heap, wider than tall, sitting on the ground. Distinct
> mound silhouette, still a simple game-kitbash mass.

sha256 `c1d4d34d6f1299f2a162a3fafb9d76ec61ec4e635914aedfd65e5493774447dd`.


### `map/grades/act1-grade.png` — 512×256 RGBA — Act I grade (#294)

Locally authored low-frequency crimson-dusk to amber-key grade following the
Act I palette arc, with alpha used only for prop and terminus contact darkening.
No vendor or paid generation. Godot 4.7.2 generated the VRAM-compressed mode 2,
high-quality, mipmapped import sidecar from a temporary importer-default profile;
the sidecar was not hand-edited. sha256
`e9c74f792dec12d4c70940d651b611c341940320f1544d440cafdb523aaf3fa7`. fol2 accepted the final asset on 2026-08-21; evidence is in `docs/reviews/294/act1-grade/`.

### `map/geometry/act1/terminus-amber-window-tower.glb` — Act I hero terminus (#294)

Locally authored against the shipped Act I amber arched-window tower: pointed
window surround, grounded masonry, crenellated crown and tiered lower-right
turret. Parametric surfaces were combined with a manifold boolean union so the
shipping payload is one watertight connected component rather than overlapping
parts. It is Y-up, grounded at Y=0, one mesh and one triangulated surface with
POSITION+NORMAL only: 4,446 triangles, 107,504 bytes. No vendor, textures or
paid credits. sha256
`81904b2421f0ad2f2d03689e7062801dc87a8928e8de733030c4d67a36f0dfbc`. fol2 accepted the final asset on 2026-08-21; evidence is in `docs/reviews/294/act1-terminus/`.

### `map/geometry/act1/vigil-hall.glb` — the Vigil, west bookend (#156)

Converted by Tripo Studio from `map-concepts/act1-vigil-hall.png` (below). The
subject was settled in prose and in shipped art before any picture existed:
`docs/story/01-world.md` puts 【守夜之爐 Vigil】at the west end of the road, and
`assets/art/scenes/opening-hearth.png` — the still shown at the start of every
run — is unmistakably the inside of a tall gothic hall. So the map shows that
hall from outside: gabled, end-on, blank east gable, a shallow recessed pointed
doorway, flank buttresses, and a chimney with its smoke. The chimney is the only
identity cue, and it is deliberate — it says *hearth*, which is what the place is
named for.

**What it does not show, on purpose.** An earlier cut of this asset put the
六格 rose window on the road-facing face. That was wrong twice. It was a
spoiler: `01-world.md` grades 「彩窗成鏡,隊伍現形」 as **L3, the single reveal
point**, and `05-foreshadow-ledger.md` rule 2 defers anything disclosing before
its tier — the six panes ARE the shard count, and standing them at the start of
every run hands an L3 fact to a player at L0. That the fiction says the west
face HAS six compartments does not license showing them; row 10 of the ledger is
the model, where `mirror.png` ships as L0 art with its meaning withheld. It was
also the wrong side of the wall: 爐邊彩窗 faces in at the fire, so from the road
you are outside it and could not see it in any case.

**This was the map's first textured asset (2026-08-24).** On 2026-08-25 the
other 27 dests joined it as Studio HD textured kits; see the inventory at the
end of this file. The Vigil remains the west bookend hero. The 2026-08-24
reason still holds for why a building cannot live on triplanar projection
alone: coursed ashlar, a corbel band and slate have to sit on UVs. The
predecessor trim sheet and its two generator scripts were deleted with this
replacement.

Y-up, grounded at Y=0 as exported. One mesh, one triangulated surface,
POSITION+NORMAL+TEXCOORD_0: 5,615 triangles, 3,824 verts, 604,608 bytes, of
which a 2048×2048 JPEG baseColor is 413,216. Texture 2K and PBR off were chosen
against this repo's budgets, not Studio's defaults — 4K would not fit
`bytes_max`, and the unshaded shader samples exactly one map, so
metallic/roughness/normal would be three more images inside the same cap for
nothing on screen. Polycount was set to 6,000 against a Studio default of
2,000,000. Tripo Studio Pro commercial grant, 40 credits.

**Two connected components, and that is the asset, not a defect.** The hall
(2,683 v / 5,362 t) and the smoke above the chimney (142 v / 253 t), which
floats clear of it. In raw index space the gate counted 118, which was UV seams
rather than geometry — an unwrap splits a vertex at every chart cut, and
3,824 → 2,825 verts on a weld is exactly the Euler prediction for a closed
surface at 5,615 triangles. `map_asset_checks._connected_components` now welds by
position before counting, and the row declares `components_max: 2`.

sha256 `6ee66212ddd504f92f5de896c5b5c3d053a8ab1bc5b692103a6bd0d2a0098f13`.

### `map-concepts/act1-vigil-hall.png` — the Vigil, conversion concept (#156)

Generated 2026-08-24 with the built-in image tool, as the input to a Tripo
image-to-3D conversion. Not a shipping texture, and not a shipping asset: the
map gate scans `assets/art/map/`, and concepts live outside it.

**Why there is no window on it.** The subject is the hall the player walks out
of at the start of every run, and `docs/story/01-world.md` grades 「彩窗成鏡,
隊伍現形」 as L3, the single reveal point. The rose window's six panes are the
shard count, so an earlier parametric cut of this asset that showed them handed
an L3 fact to a player at L0; `05-foreshadow-ledger.md` rule 2 defers exactly
that. It is also 爐邊彩窗 — the hearth-side face, turned in at the fire — so from
the road you are outside it regardless. The prompt therefore bans rose, wheel
and circular windows outright and allows at most a narrow slit.

The framing constraints in the prompt are for the converter, not for the
picture: whole object in frame, centred, square, flat mid-grey ground-free
background, no cast shadow, no depth of field. Tripo reconstructs what it can
see, and a horizon or a contact shadow comes back as geometry.

Prompt, verbatim:

> Small ancient Gothic stone hall, exterior three-quarter view from 35–40° above;
> entire building centred with even margin in a square frame. Steep dark slate
> roof with visible courses; weathered coursed grey ashlar, heavy plinth, three
> deep flank buttresses, one shallow recessed pointed arch doorway at near gable,
> corbel course at eaves, ridge chimney and pale smoke. Cold blue-grey
> low-contrast matte illumination; clean planar, low-poly-friendly game-asset
> concept; flat neutral mid-grey background with no ground or cast shadow.

1254×1254 RGB. sha256 `8c6f47f7442798a67408789b5c69aa8cc9ae137fcda86fcc91283f119d724087`.

### `map-concepts/act2-terminus-flooded-threshold.png` — Act II hero concept (#294)

Project-authored concept generated from the Glassvow brief: a monumental drowned
pointed arch with uneven ruined wings, three or four broad masonry courses, two
fused pendant masses (left larger and higher), coarse side apertures and one
continuous silt slab; no chains, cages, grout, kelp, coral or painted water.
fol2 accepted the concept on 2026-08-21. sha256 `7286e70e628b9c29d98c8037769e7ab1784fc7f7ee24f1b9076d4f42772ba9b0`.

### `map/grades/act2-grade.png` — 512×256 RGBA — Act II grade (#294)

Locally authored low-frequency blue-night to cyan-distance flooded-corridor
grade, with alpha restricted to contact darkening. Godot 4.7.2 generated its
VRAM mode 2, high-quality, mipmapped sidecar; it was not hand-edited. No vendor
or paid generation. sha256 `b992ae08e638080e39aa32221edb6c811d9bfc4d9f4a8ede1a0a05f500f95906`. fol2 accepted the Act II slice on
2026-08-21; evidence is in `docs/reviews/294/act2-grade/`.

### `map/geometry/act2/terminus-flooded-threshold.glb` — Act II hero terminus (#294)

Locally modelled from the accepted flooded-threshold concept. Parametric arch
surfaces, ruined wings, through-apertures, silt courses and two fused pendant
masses were reduced by manifold boolean union to one watertight component. The
shipping GLB is Y-up and grounded at Y=0, one mesh and one triangulated surface,
POSITION+NORMAL only: 5,568 triangles, 134,416 bytes. No vendor, textures or
paid credits. sha256 `d093ccc134faa8118e5a724bef33c4ee8a0fda15fc95826a0b608541ab58aa99`. fol2 accepted the final hero on 2026-08-21;
evidence is in `docs/reviews/294/act2-terminus/`.


### `map/grades/act3-grade.png` — 512×256 RGBA — Act III grade (#294)

Locally authored low-frequency violet-storm to obsidian-court broken-ring
grade, with alpha restricted to contact darkening. Godot 4.7.2 generated its
VRAM mode 2, high-quality, mipmapped sidecar; it was not hand-edited. No vendor
or paid generation. sha256 `56d9bb012038351f35fe2ea28086e2633b5d7811fc42cefeeb2fd67f155de332`. fol2 accepted the Act III slice on
2026-08-21; evidence is in `docs/reviews/294/act3-grade/`.

### `map/geometry/act3/terminus-broken-ring-arch.glb` — Act III hero terminus (#294)

Locally modelled as a deliberately broken monumental ring-arch with faceted
court pylons, a central suspended shard and a continuous grounded plinth.
Manifold boolean union reduced the construction to one watertight component.
The shipping GLB is Y-up and grounded at Y=0, one mesh and one triangulated
surface, POSITION+NORMAL only: 5,504 triangles, 132,952 bytes. No vendor,
textures or paid credits. sha256 `607615ca3bd5a5d5ffa382ab19866891a49f220685fe6c2f4272427b6ea423fe`. fol2 accepted the final hero on
2026-08-21; evidence is in `docs/reviews/294/act3-terminus/`.

### `map-concepts/act4-terminus-rose-threshold.png` — Act IV hero concept (#294)

Project-authored concept generated from the Glassvow brief: a monumental rose
threshold with a thick four-aperture wheel, tall faceted flanking pylons, broad
stepped courses and one continuous plinth; no character, text, foliage or loose
props. fol2 accepted the concept on 2026-08-21. sha256 `44b5ee7dec5d6ef10c732a03190923ddbe6df1d26b5f4148e3a6146e7b9af00d`.

### `map/grades/act4-grade.png` — 512×256 RGBA — Act IV grade (#294)

Locally authored low-frequency umber-to-rose dawn reversed hearth-light grade,
with alpha restricted to contact darkening. Godot 4.7.2 generated its VRAM mode
2, high-quality, mipmapped sidecar; it was not hand-edited. No vendor or paid
generation. sha256 `abc2371033603c4f927d0a225c28b1cf36d2c10e03c8719f03d3d20b2ee8ad5a`. fol2 accepted the Act IV slice on 2026-08-21;
evidence is in `docs/reviews/294/act4-grade/`.

### `map/geometry/act4/terminus-threshold.glb` — Act IV hero terminus (#294)

Locally modelled from the accepted rose-threshold concept as a thick
four-aperture wheel, faceted flanking pylons, stepped threshold courses and a
continuous plinth. Manifold boolean union reduced the construction to one
watertight component. The shipping GLB is Y-up and grounded at Y=0, one mesh and
one triangulated surface, POSITION+NORMAL only: 5,460 triangles, 156,660 bytes.
No vendor, textures or paid credits. sha256 `137fdfe77386ff02b8c825ec1b2d9fb14315f2c09409dd30b629d1e6570c0d9f`. fol2 accepted the final
hero on 2026-08-21; evidence is in `docs/reviews/294/act4-terminus/`.

### Map kit textured Studio library (2026-08-25)

The 28 dest GLBs under `assets/art/map/geometry/` are now Studio HD `--textured`
payloads (baked JPEG albedo + `TEXCOORD_0`). Ordinary kits: `--faces 1500`,
export 1K, Ultra Mesh Quality off. Heroes (four termini + Vigil): `--faces 6000`,
2K, Ultra on. PBR off, Private, triangle topology. Generate is the HD tab, never
Smart Mesh and never the Tripo API. `tools/kit_from_concept.py` is the one-shot
CLI (`--asset ID` or `--remaining`).

This supersedes the 2026-08-21 untextured terminus write-ups above and the
claim that Vigil was the map's only textured asset. Vigil is still the west
bookend hero (`components_max: 2`); it was not regenerated on 2026-08-25.

Act I / shared concept prompts remain in the rows earlier in this file. Act II–IV
concept prompts live in `docs/map-kit/` (per-act direction + per-kit ledgers).
20-placement captures: `docs/reviews/292/<asset_id>-20.png`.

Operator: `python3 tools/land_map_glb.py --asset <id> --src <dest> --concept <jpg>
--accept-signed-capture docs/reviews/292/<id>-20.png --reviewer fol2`.


### Reassembled landscape (5 September 2026)

`assets/art/map-atelier/` is the active map renderer's new asset set: thirteen
original painted images and one original Blender slate outcrop. Its
`provenance.json` records each final payload SHA-256, dimensions, generation
source and final authoring brief. No Tripo generation was performed in this
reassembly. The previous library remains available to other tools.

Painted landmarks and vegetation are real transparent RGBA, mounted on
camera-aligned two-triangle meshes at the fixed 40-degree view. Terrain images
are opaque RGB. All textures have runtime mipmaps; mirrored world coordinates
keep tile boundaries continuous. Each PNG is limited to 4 MiB and 1536 pixels
per side, and the complete package to 40 MiB. Only the current act's resources
are held. The new slate is one closed connected mesh, 1,228 triangles and
61,064 bytes, with a grounded Y-up pivot and one material. Rebuild it with
`blender --background --python tools/map_atelier/build_slate.py`.

`assets/art/ui/map-glyphs.svg` is original native vector artwork: nine consistent
waystone symbols. It carries no generated raster or external icon dependency.
The Vigil's rose window remains concealed; the visible rose threshold belongs
to Act IV. Native captures and final validation are recorded in
`docs/reviews/map-reassembly/direction.md`; the concept image is not game proof.

### `assets/icon/glassvow-icon-ios.png` and `assets/icon/glassvow-icon.png` — 1024×1024 — the app icon, C7 dusk rose (#545)

The app icon, one mark for both locales: a leaded stained-glass rose window with
six spokes and a worn-gold ring, a sealed pointed-arch door at the hub and one
hairline of warm light down its seam, lit from behind at dusk (amber and honey by
the door, cooling to violet and cobalt at the rim). No figures, stairs or text.
James picked it on 2026-09-29 from eight candidates in two rounds; the
reviewer's recommendation was C6. The brief is #243's resolution as #409
restates it. The inspection, the ranking and the sheets are in
`docs/design/2026-09-29-icon-check/README.md`; `landed-c7.png` there renders both
masters.

| File | Used by | Format | sha256 |
|---|---|---|---|
| `assets/icon/glassvow-icon-ios.png` | both iOS presets, `icons/icon_1024x1024` and `icons/app_store_1024x1024` | 1024×1024 RGB, opaque and full-bleed; C7 byte for byte | `5d4004c03040f08fc05ed07bb19e29c1294b440a3553629b68d3ab198b082f08` |
| `assets/icon/glassvow-icon.png` | `config/icon`; the macOS grid master and the source of the icns | 1024×1024 RGBA; 824 px live area, transparent margin | `9a2a1268280ec0726341bc8ee83ab25209418a97aed0a735d9fb292e9a194bc3` |
| `assets/icon/glassvow.icns` | the macOS preset's `application/icon`; `config/macos_native_icon` | icns ladder, 16 to 512 px at 1x and 2x | `ab527d136b1cc453e148f1c92ae8999bf70b61b2c2ebf6e7da682793b0360184` |

Rebuild the macOS pair from the iOS master, which is C7 itself, with
`python3 tools/make_icon_master.py assets/icon/glassvow-icon-ios.png assets/icon/glassvow-icon.png`
and then `tools/make_icon.sh`. The tool keeps C7's own scale (no zoom) and
anti-aliases the grid corners.

Generated 2026-09-29, London time, by Codex CLI 0.159.0's built-in `image_gen`,
through `~/.claude/scripts/subagents/run-imagegen.sh`, which runs `codex exec` on
the newest Terra model at run time (`gpt-5.6-terra`, low reasoning effort,
workspace-write sandbox). One call, `transparent_background` false, with the
then-shipped icon (sha256 `4e4309be…`, replaced by this landing and still held
as `assets/icon/candidates/icon-A-full-rose.png`) passed as Image 1, the style
reference. The call ran at 21:03:35 and the image was created at 21:03:55. The
tool takes no size and returned a 1254×1254 opaque RGB PNG (sha256
`e1b9b183117a35752f24159bbd8543dd0e780f3f52258f6805a509709804603d`, kept in
Codex's generated-images folder under session
`01a0eec3-791b-7c33-aa5e-708bb316c6d4`); one retry, with a note that 1024 was
required, also came back at 1254. The iOS master is that first output resized to
1024×1024 with Pillow 10.4.0's Lanczos and otherwise unchanged. The original
carries OpenAI's C2PA content credentials (software agent ChatGPT `gpt-image`,
action `c2pa.created`, signed by OpenAI OpCo, LLC); the resize drops the
manifest, so the shipped masters do not carry it.

The request Codex received, verbatim from the design record. `{OUT}` was the
output path in a scratch folder and `{PROMPT}` is the prompt that follows;
`{IMAGES}` was the single line
`Image 1 (style reference): <the then-shipped icon's absolute path>`.

> Generate one image with your built-in image_gen tool and save it as a PNG at exactly this absolute path: {OUT}
>
> Steps:
> 1. First view the input image(s) at these absolute paths (read-only):
> {IMAGES}
> 2. Make exactly one image_gen call. Pass the input image(s) in referenced_image_paths, in the order listed. Do not ask for a transparent background: this is an opaque App Store icon. Pass the prompt between the markers verbatim.
> 3. Copy the generated file to the output path unchanged: no resizing, cropping, re-encoding or flattening, and no second generation.
> 4. Reply with the output path, its pixel size and its colour mode (for example RGB or RGBA).
>
> Write no other file.
>
> --- PROMPT ---
> {PROMPT}
> --- END PROMPT ---

The C7 prompt as sent to Codex, verbatim. Codex dropped the final clause of the
Avoid line, "; an empty hub", before calling the tool; the door at the hub makes it
moot.

> Use case: stylized-concept
>
> Asset type: the iOS App Store app icon for Glassvow (琉璃誓言), a stained-glass roguelite deckbuilder; a 1024 x 1024 px opaque, full-bleed square master.
>
> Input images: Image 1 is the game's current icon, the STYLE REFERENCE. Take from it the rose's six-spoke layout, how its glass is rendered (painterly stained glass in irregular cut pieces, dark lead cames with narrow worn-gold edge highlights) and its cold cobalt, violet and teal glass. It has four faults this icon must not repeat: five of its six panes tell stories with figures (robed people, a gloved hand, a crown over a lantern, rising pages); one pane holds a staircase; its hub is an empty dark disc; and it sits on a rounded tile inside a transparent margin.
>
> Primary request: remake the rose window so that its hub is a sealed door with a hairline of light. The icon must read as one to three shapes when shrunk to 60 x 60 px: the rose, the door, the line of light.
>
> Subject: a circular leaded stained-glass rose window seen straight on. Exactly six straight dark lead spokes divide it into exactly six equal wedge panes, as in Image 1: one spoke runs horizontally through the hub and the other two cross it at 60 degrees, so one pane sits directly above the hub and one directly below it. A thin worn-gold ring edges the rose. Every pane is plain, unpictured glass. The hub is a sealed door: a closed Gothic pointed-arch (lancet) door of two leaves, seen straight on, standing upright where the spokes meet; the spokes end at its frame. The leaves are plain, dark, almost black glass framed in lead with a worn-gold edge, with no handles, hinges, studs, tracery or keyhole. Along the whole seam where the two leaves meet, from the threshold to the point of the arch, runs one hairline of warm light.
>
> Composition/framing: centred and symmetrical about the vertical axis. The rose's outer ring spans about 86 % of the canvas width, on a dark warm-black surround. The door is about two fifths of the rose's diameter tall.
>
> Lighting/mood: dusk, with the rose lit from behind: warm amber light glows through the panes, so the glass is luminous, amber and honey nearest the door and cooling to the violet and cobalt of Image 1 toward the rim. The door stays dark and unlit, a clean silhouette against the glowing glass. The hairline down its seam is the brightest point in the whole image: near-white gold at its core, brighter than any pane, crisp and about 1 % of the canvas wide, with a faint warm glow either side. No other light leaves the door: no glow around the arch and no light beneath it. The glow stays inside the ring; the surround stays dark.
>
> Color palette: amber and honey light through the glass, blending into violet and cobalt at the rim; worn gold on the lead and the ring; a near-black door; a dark warm-black surround (about #0c0907).
>
> Materials/textures: painterly stained glass with faint streaks and seeds, dark lead cames with narrow worn-gold edge highlights, as in Image 1. Keep the pieces large, a few to each pane rather than a fine mosaic, and the texture inside each piece quiet, so nothing turns to noise at 60 px.
>
> Constraints: exactly six spokes and six panes (not eight, not twelve); a pointed arch, not a round one; the door is the focal point; one opaque square whose surround runs unbroken to all four edges and corners, with no rounded tile, frame, border, drop shadow or transparent margin (iOS applies its own mask).
>
> Avoid: figures, people, faces or hands; stairs or steps; pictures, scenes or story panes; a crown, lantern, candle, flame, cards, pages, sun or star motif; text, letters, numerals or a signature; an empty hub.

**Open caveat.** At 60 px the amber glow outshines the hairline, so the mark can
read as light behind a door, or as a sun, rather than a sealed door with a
hairline. On the design record's 60 px render the hairline is 2.8 : 1 against the
leaves (WCAG 2.1 SC 1.4.11 asks 3 : 1) while the door is 8.5 : 1 against its glass,
and the hairline is the brightest point only at 1024, by 1.29×. It stays open
for the owner's phone check at TestFlight.

## Shipped — the Edge way's crown and deed (2026-09-30)

### `relics/crownOfTheEclipse.png` — 512×341 RGBA; `deeds/faultInGlass.png` — 512×512 RGBA

The Edge way's last two Owed rows (Flame lock PR 6, #583): its crown, Crown of
the Eclipse, and its deed, Fault in the Glass. Each file is keyed by its content
id, so the run HUD's relic row (`presentation/run/run_hud.gd` through
`HudBar.icon`), the reward, shop and crown screens, and the Vigil's deed row
(`presentation/run/vigil_screen.gd`) find them, and no code changed. Both match
their siblings' format: 8-bit RGBA PNG with a fully transparent background, the
relic on the relics' 512×341 canvas and the deed on the deeds' 512×512.

The prompts follow `relic-art-bible.md` and the deed emblems of
`meta-art-bible.md` under `style-bible.md`'s style block and readability
priority, in the step 1 prompt shape of `generated-art-workflow.md`, with
`refs/style-master.png` loaded as the master reference. The crown also loads two
shipped crowns (`shatterersCrown`, `crownOfTheHearth`) for the crown family's
read, silhouette first, and `cards/totality.jpg` for its eclipse. The deed loads
three shipped deeds (`darkWalker`, `firstDawn`, `untouched`) and
`cards/totality.jpg` for the crack light. Each subject is the one its Owed row
gave, in the Edge palette that Totality set: a black disc in a violet-crimson
corona, dark violet and plum glass, black lead, a thin amber rim. The exact
requests are in `docs/reviews/edge-crown-deed-2026-09-30/prompts/`.

Generated 2026-09-30 through `~/.claude/scripts/subagents/run-imagegen.sh`: Codex
CLI 0.159.0 with `gpt-6.1-sol` at xhigh reasoning effort, drawing with Codex's
built-in image tool, one image per call. Codex served every call, and none fell
back. The crown renders are 1536×1024 as asked; the deed renders came back
1254×1254 where 1024×1024 was asked, which the landing step absorbs. Two
workflow departures, both deliberate. The chroma key is flat `#00ff00`, not the
workflow's default `#ff00ff`, because both subjects are violet-crimson and the
workflow asks for another key colour when the subject needs magenta. And, as for
the card plates, there is no Nano Banana Pro pass: the Codex render is landed
directly.

Landing, identical for every candidate: alpha from greenness `G − max(R, B)`,
opaque at 24 or below and clear at 120 or above, linear between; green despilled
by clamping `G` to `max(R, B)`; crop to the box where alpha exceeds 16; one
uniform premultiplied Lanczos scale; centred on a transparent canvas. The crown
fits a 440×331 box on 512×341 and lands at 440×307: deliberately a little wider
and shorter than the other five boss crowns (292 to 404 px wide, 327 to 338 px
tall); fitted to their height, its broad outline would be 475 px wide. The deed fits 484×484 on
512×512, the height the shipped deeds fill (94 to 96%); it lands at 218×484.
Neither file carries a visible green cast. Where green still edges past red and
blue it is resampling ringing on near-black pixels, 5 levels at most, plus five
faint pixels (alpha 35 or less) at the deed's apex tip.

Each asset had two candidates in deliberately different shapes. The deed has a
third, `c`: after `a` and `b` were judged too narrow for the Vigil's slot, one
more render repeated `a`'s request with only the pane's proportions changed. Each
pick was judged at the size the UI shows it, against shipped siblings, with a
black silhouette: the relic at 64 and 32 px (the run HUD seats it in a 34 to
44 px circle, where the 512×341 plate draws about 44×29), the deed at the Vigil
row's 48 px slot (40 on phone) and at 32 px.

The review folder `docs/reviews/edge-crown-deed-2026-09-30/` holds a contact
sheet per asset with its runners-up and two shipped siblings
(`sheets/<id>.jpg`); `prompts/sources.txt` maps every candidate to its
full-resolution original in Codex's store on the authoring Mac, so a swap only
repeats the landing step. `capture/crownOfTheEclipse-pad.jpg` is the Act I shop
at pad-landscape with the crown held, in the run HUD's relic row beside
Emberheart (`-hud-x5.jpg` is that row enlarged); combat hides the row, so the
shop is where it shows. `capture/faultInGlass-pad.jpg` is the Vigil at
pad-landscape, its deed list scrolled to the end (`-row-x3.jpg` is the row
enlarged).

| Shipped | Pick | Content | Why this one |
|---|---|---|---|
| `relics/crownOfTheEclipse.png` | `a` | Crown of the Eclipse 蝕月冠, Edge boss relic, the way's crown | Five thin, tall lancet points give the crown family's silhouette first. Totality's ringed black disc sits in a rose-window medallion on the band, and its cracks run out through the glass: the rule, Cracked that no longer wears off, drawn as cracks that stay open. The disc still reads at 32 px. `b` is the Owed row's literal circlet, but its low band and single arch read as an eye or a helmet at 32 px, not as a crown. |
| `deeds/faultInGlass.png` | `c` | Fault in the Glass 裂痕, Edge deed | One bright fault runs the pane from apex to base, and the pane is broad enough (width 0.45 of height) to read as a window in the 48 px slot. `a` is the same design only a third as wide as it is tall, 15 px wide in the slot. `b` hangs the fault from a small eclipse, which shortens the fault and becomes a dot at 32 px. |

## Shipped — card art for the Edge way, the way walls and the Unreadable Page (2026-09-30)

### `cards/` — ten plates, 2048×1374 JPEG

Ten cards that played on a bare pane now carry art: the Edge way's seven (Flame
lock PR 6), Spall and Hearthfall (the way walls, #602), and The Unreadable Page,
the Trail quest's curse card, which had shipped without art and without an Owed
row. Each file is keyed by its content id, so `presentation/combat/card_view.gd`
finds it and no code changed.

The prompts follow `card-art-bible.md`'s template under `style-bible.md`'s style
block and readability priority, with `refs/style-master.png` and two shipped
cards (`eclipseSlash`, `lunge`) loaded as style references. Each subject is the
one its Owed row gave, in the colour and shape the Flame lock's §6 gives its way.
The Page had no row, so its subject is new: a book of dark glass bound shut by a
padlocked chain, one leaf void-purple with its lead knotted into an illegible
tangle, and a thin line of dawn light at the leaf's edge. The exact requests are
in `docs/reviews/card-art-2026-09-30/prompts/`.

Generated 2026-09-30 through `~/.claude/scripts/subagents/run-imagegen.sh`: Codex
CLI 0.159.0 with `gpt-6.1-sol` at xhigh reasoning effort, drawing with Codex's
built-in image tool, one 1536×1024 image per call. Codex served every call, and
none fell back. Each card had two candidates in deliberately different
compositions. Splinter Cut has a third, `a0`, the trial render made before the
shared block was tightened to put glass on every surface and to thicken the
mechanic's light. Each pick was judged against the style bible's readability
priority on the 148×91 cover crop the card view makes, on a 64 px thumbnail and
under a luminance threshold. It was then landed by a uniform Lanczos scale to
2061×1374, a centre crop to 2048×1374, and JPEG quality 95 at 4:2:0: the
siblings' size and quality, with no other processing.

The review folder `docs/reviews/card-art-2026-09-30/` holds a contact sheet per
card with its runners-up (`sheets/<id>.jpg`) and one sheet of all of them
(`index.jpg`). `prompts/sources.txt` maps every candidate to its full-resolution
original in Codex's store on the authoring Mac, so a swap only repeats the
landing step. `capture/<id>-pad.jpg` is a real Act I fight at pad-landscape whose
deck is five copies of the card, and `capture/hands.jpg` is each centre card at 2×.

| Shipped | Pick | Content | Why this one |
|---|---|---|---|
| `splinterCut.jpg` | `b` | Splinter Cut 裂痕斬, Edge common attack | One violet-crimson crack is the whole read and survives at 64 px. `a` and `a0` read as arm and blade at card size, lose the crack, and sit close to `lunge`. |
| `dimTheGlass.jpg` | `a` | Dim the Glass 暗琉, Edge common skill | The veil across a half-dulled crimson rose window is the Owed subject, and the grey-against-crimson split carries Dimmed. In `b` the snuffed enemy glass reads as a lantern, the Lantern way's emblem. |
| `cleft.jpg` | `a` | Cleft 裂隙, Edge uncommon attack | The blade forces an existing crack wide on the attack diagonal, with Fervor's red-gold in the blade. `b` is busier and its blade lies flat. |
| `eclipseStep.jpg` | `a` | Eclipse Step 蝕影步, Edge uncommon skill | A black crescent with a violet-crimson rim is the Ward arc. In `b` the crack on the claw sparks blue-white, Shatter's colour. |
| `tremor.jpg` | `a` | Tremor 震紋, Edge uncommon attack | Exactly three rings from one impact, clean under the threshold. `b` drew four, which read as a spiral. |
| `totality.jpg` | `a` | Totality 全蝕, Edge rare attack, the capstone | The eclipse is the heart of a rose window cracked through: the rare grammar's one ceremonial moment. `b` repeats `eclipseSlash`'s blade across a black disc. |
| `emberEye.jpg` | `a` | Ember Eye 燼瞳, rare skill, the Lantern and Edge duo | A round amber lantern holds an ember eye with a violet-crimson slit and cracks every foe around it. In `b` the cracks read as beams and the eye is small at card size. |
| `unreadablePage.jpg` | `b` | The Unreadable Page 無法辨讀之頁, special curse | The padlocked chain says it can be neither played nor removed; no letters are drawn. `a` is a dark slab at card size and its knot is decorative. |
| `spall.jpg` | `a` | Spall 璃屑, Shatter common attack | One blue-white flake springs clear of the notch with a dark gap round it. `b`'s flake crowds the edge, and the card window crops it. |
| `hearthfall.jpg` | `a` | Hearthfall 爐火墜, Lantern common attack | Lantern, pour and blade make one round amber shape, the cleanest silhouette of the ten. In `b` the figure competes with a thinner pour. |

**For the device check.** The Unreadable Page, like every unplayable card, is
dimmed in the hand. There its art window measures a mean luminance of 0.062
against the shipped `hex`'s 0.067, so it is as dark as the existing curse, not
darker; the book and chain still read. Dim the Glass is the quietest of the ten
at hand size.

## Shipped — dialogue stagecraft portraits (2026-09-29)

### `portraits/` — Keeper and Hollow Lamplighter moods, 682×1024 RGBA

Eight of the nine mood portraits commissioned below for the Keeper (#560) and
the Hollow Lamplighter (#561), moved here when they landed. The ninth,
`portraits/lamplighter-grieving.png`, stays commissioned: its pick was
withdrawn. Each file is an image-to-image edit of its actor's shipped figure on
the same canvas, so the actor's one bust crop in `content/actors.json` fits
every mood. That file already named every path, so landing them changed no game
code. `tests/test_stagecraft.gd` asserts that each is the texture its bust
draws.

James picked them on 2026-09-29 from the candidates recorded in
`docs/design/2026-09-29-stagecraft-art/README.md`, with its contact sheets, gate
tables, ranking and rejection record. Rank is that README's ranking across both
tools' rounds. The other survivors stay on the branch
`art/stagecraft-candidates-2026-09-29` at 44ce8a61. Stills of each mood on its
stage cut are in `docs/reviews/559/`.

| Shipped | Pick | Rank | Used by |
|---|---|---|---|
| `keeper-tender.png` | `keeper-tender-c2` | #1 | opening b2 l3 (「到了那裏，你便到家了。」) |
| `keeper-offering.png` | `keeper-offering-c3` | #1 | opening b2 l1 (the boon: 「帶上這個。」) and b2 lantern |
| `keeper-weary.png` | `keeper-weary-c2` | #1 | declared for the hearth pool and future hearth scenes; no scene casts it yet |
| `keeper-beckon.png` | `keeper-beckon-c4` | #1 | act4-node5 l4 (「坐下。」) |
| `lamplighter-wary.png` | `lamplighter-wary-c1` | #2, after `c4` | m1-pre, m3-pre l3, m3-post, m4-pre l4 |
| `lamplighter-asking.png` | `lamplighter-asking-c1` | #1 | m2-pre l3, m5-pre l2 |
| `lamplighter-recognising.png` | `lamplighter-recognising-c4` | #2, after Grok's `b` | m1-pre l3, m2-pre l2, m3-pre l2, m4-pre, m5-pre l1, m5-post l2 |
| `lamplighter-urgent.png` | `lamplighter-urgent-c1` | #1 | m4-pre l3 (「上次站在這裏的，是不是你?」) |

Generated 2026-09-29 in the candidates' round 4, through
`~/.claude/scripts/subagents/run-imagegen.sh`: Codex CLI 0.159.0 with
`gpt-5.6-terra` at low reasoning effort, drawing with Codex's built-in image
tool, one image per call. Codex served every call, and none fell back. On
James's instruction, round 4 drew each figure on a transparent background
instead of the magenta field the portrait contract below names, so the alpha is
the render's own and was not keyed. The candidates branch gated each render
with `tools/key_magenta.py --no-key`. Re-graded as landed against the
contract's full gate, magenta row included, all eight pass: leftover
field-magenta 0–22 px, opaque near-black in the frame 0–151 px, corners at
alpha 0, and 93.8–98.1% of visible pixels at alpha ≥ 240. Each keeps its own
anti-aliased alpha (256 levels); neither of the two renders whose alpha Codex
replaced was picked.

**The request that rendered each file** is its issue's prompt, verbatim, with
round 4's one change: the background clause's first two sentences became
"Output a PNG with a TRANSPARENT background (alpha 0 outside the figure); no
magenta, no floor, no shadow, no vignette. Black exists ONLY inside the hood
void." The Lamplighter's keeps "head void", as he wears no hood. `<repo>` stands
for the working copy and `<scratch>` for the session's scratch directory, and
each request's last line names its own file. The Keeper's, as sent for tender:

```text
Read the reference image at <repo>/assets/art/meta/keeper.png and produce an edited variation of it.

Serious cartoon-gothic stained-glass game art: chunky dark outer silhouette, simplified exaggerated proportions, one iconic readable pose, 3-5 large jewel-tone glass colour masses with very few thick lead dividers, matte painterly texture, warm amber rim light, soft controlled inner glow. Designed to remain readable at 128px. No text, no labels, no watermark.

CONSTRUCTION, this is the most important instruction: the figure is not painted cloth. The entire robe, hood and body are built from large flat panes of coloured glass separated by thick black lead came lines, exactly like a cathedral stained-glass window rendered as a character. Each fold of the robe is a distinct glass pane with a hard lead border, not a soft painted fold. Only a few big panes, never lacework or many small pieces. The lead lines are heavy, black, and clearly visible across the whole figure. Glass is blue, violet, teal and deep red, lit from within by a faint cold glow, with thin worn gold edging on the lead. Readable as a solid black shape if all internal detail were removed.

Output a PNG with a TRANSPARENT background (alpha 0 outside the figure); no magenta, no floor, no shadow, no vignette. Black exists ONLY inside the hood void. EDIT THE ATTACHED REFERENCE: keep the exact same canvas size, figure scale, position, bounding box, hem line, pane layout and palette; change ONLY the pose described below. Single complete figure, no cropped limbs. The hood opening is a deep black VOID with NO face, NO eyes, NO glowing points.

The Keeper — a seated hooded figure, knees drawn in, completely still and calm. Low wide hooded seated mass. Warm amber rim light falling on the figure from the RIGHT, from a fire outside the frame. The figure holds no lantern, staff or weapon. Do NOT draw a hearth, chair, floor, hall, fire, or any background object.

POSE CHANGE: the hood tilts slightly toward the viewer's left, as if toward someone seated near; the shoulders soften; the hands stay folded in the lap. The inner glow is a touch warmer. Stillness, fondness, fatigue.

Canvas: exactly 682x1024 pixels.

Save the result as a PNG file at <scratch>/stagecraft-raw/keeper-tender-<x>.png
```

- `keeper-offering` and `keeper-weary` send the same request with the POSE
  CHANGE paragraph replaced by their own, verbatim:
  - offering: "POSE CHANGE: the right hand is lifted from the lap and held forward at chest height, palm up, cupping one small ember of warm amber glass, the only bright point on the figure. The other hand stays in the lap. The hand OFFERS; it does not point, and it gestures toward no road, door or direction."
  - weary: "POSE CHANGE: the hood bows low toward the lap, the shoulders sink, the hands rest loose. The amber rim light is low and faint and the glass a little dimmer, as if the fire has burned down."
- `keeper-beckon` reads `<repo>/assets/art/enemies/eternalKeeper.png`, drops
  "Warm amber rim light falling on the figure from the RIGHT, from a fire outside the frame." from the Keeper paragraph, and replaces the POSE CHANGE
  paragraph with: "INVERTED hearth light: warm amber arrives from the LEFT, the wrong side, catching the lead edges; the rest of the glass is cold violet-grey and deep teal. POSE CHANGE: one hand is lifted from the lap, palm up and open, and turned toward the empty space beside the figure: an invitation to sit down. Gentle, not a command."

The Lamplighter's, as sent for wary. Its POSE CHANGE paragraph ends with the
sentence round 2 added after three of round 1's four wary renders lost the rim:

```text
Read the reference image at <repo>/assets/art/meta/hollow-lamplighter.png and produce an edited variation of it.

Serious cartoon-gothic stained-glass game art: chunky dark outer silhouette, simplified exaggerated proportions, one iconic readable pose, 3-5 large jewel-tone glass colour masses with very few thick lead dividers, matte painterly texture, warm amber rim light, soft controlled inner glow. Designed to remain readable at 128px. No text, no labels, no watermark.

CONSTRUCTION, this is the most important instruction: the figure is not painted cloth. His entire robe and body are built from large flat panes of coloured glass separated by thick black lead came lines, exactly like a cathedral stained-glass window rendered as a character. Each fold of the robe is a distinct glass pane with a hard lead border, not a soft painted fold. Only a few big panes, never lacework or many small pieces. The lead lines are heavy, black, and clearly visible across the whole figure. Glass is cold grey-green and deep teal, lit from within by a faint cold glow, with thin worn gold edging on the lead. Readable as a solid black shape if all internal detail were removed.

Output a PNG with a TRANSPARENT background (alpha 0 outside the figure); no magenta, no floor, no shadow, no vignette. Black exists ONLY inside the head void. EDIT THE ATTACHED REFERENCE: keep the exact same canvas size, figure scale, position, bounding box, hem line, pane layout and palette; change ONLY the pose described below. Single complete figure, no cropped limbs.

The Hollow Lamplighter, a gaunt keeper, tall and skull-thin, in a long floor-length robe. Bare head, no raised hood, face a deep black void with no glowing eyes. The one warm colour in the frame is an amber rim light falling on him from outside the frame, from a fire he is not carrying. He holds a tall iron lantern pole; the lantern hanging from it is DARK AND EMPTY, with cold dead glass panes and no flame inside, the single unlit object in the frame, in every pose.

POSE CHANGE: he leans back a little, weight on the rear foot; the lantern pole is drawn in close across his body like a staff held between; the empty hand is lowered and closed. The amber rim light from outside the frame and the thin worn gold edging on the lead stay exactly as in the reference.

Canvas: exactly 682x1024 pixels.

Save the result as a PNG file at <scratch>/stagecraft-raw/lamplighter-wary-<x>.png
```

- `lamplighter-asking`, `lamplighter-recognising` and `lamplighter-urgent` send
  the same request without that sentence and with their own POSE CHANGE
  paragraph, verbatim:
  - asking: "POSE CHANGE: the shipped pose, sharpened. The open empty hand is held forward and low, palm up, asking a price; the lantern pole stands upright at his side."
  - recognising: "POSE CHANGE: he leans forward toward the viewer's left with his head tilted, as if studying a face; the dark empty lantern is raised high beside his head, as though to light a face it cannot light."
  - urgent: "POSE CHANGE: both hands come forward, one gripping the lantern pole hard; the body is tense and pitched in; the hem swings with the movement."

**Caveats, recorded rather than fixed.** Each file landed as rendered. The
figures are the candidates README's: S and V are the figure's mean HSV
saturation and value (0–100), and the warm edge is the amber share of the
silhouette's outer 12 px.

- **The Keeper's glass is brighter than `keeper.png`.** Tender and offering
  read V 24 against the reference's 18, so each cut between them and the
  default figure in the opening's second beat shows a step: offering to
  default, then default to tender. #560's "a touch warmer" allows some of it
  for tender. Beckon reads S 68 and V 30 against `eternalKeeper.png`'s 62 and
  27. That is a smaller step on the revealed-to-beckon cut in act4-node5, where
  its chest pane runs a little hotter and its amber still comes from the left.
- **Weary's rim is not dimmed.** #560 asks for "the amber rim light low and
  faint and the glass a little dimmer". `keeper-weary-c2` has the deepest bow
  of both tools (the hood 95 px lower), but its warm edge is 14.8% against
  `keeper.png`'s 9.5%, and its glass reads V 20. Nor does the stage dim it any
  more: `StagePortrait` grades a mood down only while its art is missing.
- **Recognising holds the pole in his other hand.**
  `lamplighter-recognising-c4` raises the pole and the dark lantern on the
  viewer's left, where the shipped figure and the other landed moods hold them
  on the viewer's right. The pole therefore changes sides on every cut to or
  from recognising, in all six scenes that cast it. All four Codex recognising
  renders did this; Grok's `b`, ranked first, keeps the usual side.
- **Wary stands upright.** `lamplighter-wary-c1` draws the pole across the
  body and lowers the closed hand, as briefed, but does not lean back; `c4`,
  ranked first, does.

## Commissioned — dialogue stagecraft portraits and plates (2026-09-27)

**Not yet landed.** Eight of the nine Keeper and Lamplighter moods shipped on
2026-09-29 and moved to "Shipped — dialogue stagecraft portraits" above; what
remains below has not landed. Billed by the stagecraft system
(`docs/design/2026-09-27-stagecraft/README.md`): the JRPG two-shot stands a
speaking cast as glass busts beside the dialogue pane, and every mood a scene
asks for is declared in `content/actors.json`. Until a file below lands, the
stage carries that mood with the actor's shipped figure plus posture and
light (`StagePortrait.MOOD_LOOKS`), so nothing is broken while these wait.
**Landing a file at its path is the whole integration** — no game code
changes. Its mood then joins `LANDED_MOODS` in `tests/test_stagecraft.gd`,
which asserts that the landed portrait is the one drawn.

Tracking: #559 (parent) — Keeper #560, Lamplighter #561, Queue #562,
Unlit Way plates #563; the audio cues are #564. Every candidate goes through James's review before it enters
`assets/`, as every asset in this ledger has.

### Portrait contract — binding for every `portraits/` file

- **Image-to-image from the named reference, same canvas, same framing.**
  682×1024 RGBA (Queue: 1024×1024). The figure keeps the reference's scale,
  bounding box, hem line and silhouette mass; only the pose delta named in
  the subject changes. One crop per actor in `content/actors.json` must fit
  every mood — a re-framed variant breaks every bust it is cut from.
- **The face is never drawn.** Hood openings and the Lamplighter's head stay
  a deep black void: no eyes, no glowing points, no mouth (`02-cast.md`;
  heroes are faceless by canon).
- **Magenta keying, not black.** Generate on a flat `#FF00FF` field and key
  it out: a black field cannot be separated from a black hood void (the
  `unwalkedSelf` lesson above). Gate: leftover field-magenta < 32 px, opaque
  near-black in the 8 px canvas frame < 400 px, corners alpha 0, and ≥ 90% of
  non-transparent pixels at alpha ≥ 240 (the Lamplighter B/E washed-cutout
  failure). Normalise with `sips -Z 1024`.
- **Shipped assets are never modified.** These are new files beside the
  references, never replacements.
- **Verify in the running stage**, not only the PNG: `godot --path . --
  --stagecraft --cursor=N --shot=…` and the scene's own `--scene=<id>
  --cursor=N` still, at pad, desktop and phone shapes.

Style block for every portrait, verbatim from the shipped figure prompts:

> Serious cartoon-gothic stained-glass game art: chunky dark outer silhouette,
> simplified exaggerated proportions, one iconic readable pose, 3-5 large
> jewel-tone glass colour masses with very few thick lead dividers, matte
> painterly texture, warm amber rim light, soft controlled inner glow. Designed
> to remain readable at 128px. No text, no labels, no watermark.

Construction clause, verbatim (the load-bearing paragraph — without it a pass
returns painted cloth, not a leaded figure):

> CONSTRUCTION, this is the most important instruction: the figure is not
> painted cloth. The entire robe, hood and body are built from large flat panes
> of coloured glass separated by thick black lead came lines, exactly like a
> cathedral stained-glass window rendered as a character. Each fold of the robe
> is a distinct glass pane with a hard lead border, not a soft painted fold.
> Only a few big panes, never lacework or many small pieces. The lead lines are
> heavy, black, and clearly visible across the whole figure. Readable as a solid
> black shape if all internal detail were removed.

Background and framing clause (new, shared by every portrait):

> BACKGROUND is a FLAT SOLID MAGENTA #FF00FF field, edge to edge, no vignette,
> no floor, no shadow. Black exists ONLY inside the hood void. EDIT THE ATTACHED
> REFERENCE: keep the exact same canvas size, figure scale, position, bounding
> box, hem line, pane layout and palette; change ONLY the pose described below.
> Single complete figure, no cropped limbs. The hood opening (or bare head) is a
> deep black VOID with NO face, NO eyes, NO glowing points.

### The Keeper — four moods (reference `meta/keeper.png`, hearth-d)

Glass blue, violet, teal and deep red; warm amber rim from the RIGHT, from a
fire outside the frame — except the Act IV mood, which takes
`enemies/eternalKeeper.png` (boss-c) as its reference and its inverted light.
Voice rule that binds the pose: **the Keeper never urges departure**, so no
mood points at a road, a door or the east.

All four shipped on 2026-09-29; their rows moved to "Shipped — dialogue
stagecraft portraits" above, each with the request that rendered it.

`revealed` needs no new art: it is `enemies/eternalKeeper.png` itself, and the
recognition of that silhouette at node 5 is the design (`#260 Q7`).

### The Hollow Lamplighter — five moods (reference `meta/hollow-lamplighter.png`, D)

Cold grey-green and deep teal glass with worn gold edging; the one warm
colour is the amber rim from a fire he is not carrying; the lantern on its
iron pole is **dark and empty in every mood** — the unlit lantern is the whole
character. The five meetings tighten from outward things to the self
(`#260 Q3`), and the moods follow that arc.

Four of the five shipped on 2026-09-29; their rows moved to "Shipped —
dialogue stagecraft portraits" above. Grieving's stays here.

| Path | Used by | Subject delta |
|---|---|---|
| `portraits/lamplighter-grieving.png` | m5-pre l3, m5-post | Head bowed; the dark lantern lowered until it nearly rests on the ground by his feet; the free hand pressed flat to his chest. **Note: pick withdrawn 2026-09-29: pole differs from the shipped figure; redo in round 5.** |

### The Queue — one chorus portrait (new figure; L3/L4 only)

| Path | Used by | Subject |
|---|---|---|
| `portraits/queue-chorus.png` — 1024×1024 RGBA | act4-node1–3 (the Queue speaks) | Five hooded walker figures in stained glass standing in ONE single-file line that recedes from the centre-left toward the right, each a little smaller and dimmer than the one before; every hood a black void; each figure carries one small point of warm amber light at the breast (`07-scenes §3`: 每人胸口一點光). Figures cut at mid-thigh by the bottom edge (the stage dissolves the cut). Cold gold and slate glass. |

Binding: **one line, never a crowd per pane** — James ruled the per-pane
duplication creepy on the staging bake-off. The Queue is plural walkers, not
the Act IV counterfactual selves (those never speak). Seen only from the
unsealing (L3) onward; never shown in any L0–L2 scene.

### Plates for the Lamplighter's meetings (1536×1024, scene-plate contract)

The five meetings stand on graded ground today (`test_scene_script.gd` pins
"lamplighter meetings grew an art plate" — land these with that assertion
updated in the same commit). Shared style block: verbatim from
`docs/design/2026-08-16-scene-plates/README.md` § Shared style block, with its
frame contract (nothing load-bearing in the outer 4% of width or the bottom
12%). Two-shot addition: **keep the left and right 28% free of anything that
reads as a figure** — the busts stand there — and never bake the Lamplighter
or a walker into the plate (the stage supplies them; one body per character).

| Path | Meetings | Subject |
|---|---|---|
| `scenes/unlit-way.png` | m1–m4 (pre and post) | The Unlit Way at night: a long stone road running east into darkness toward a faint dawn-less horizon; a row of tall iron lamp posts along its verge, every lamp dead and dark; ash drifting in a low cold wind; one flat roadside stone composed as a seat just right of centre, empty. Raking amber light from low left, as if from a fire far behind the viewer. |
| `scenes/unlit-way-end.png` | m5 (pre and post) | Where the Unlit Way runs out: the paving breaks off into broken slabs and ash at the centre of the frame; the last dead lamp post stands at the end of the road; beyond it the ground falls away into mist toward a distant arch of light on the eastern horizon (the door, far off, never detailed). Emptier and colder than `unlit-way.png`. |

### Deferred — portraits for cast no scene yet casts

Sovereign (`enemies/sovereign.png`) and the Shade (`enemies/shade.png`) now
speak in battle (the Usurper's opening lines, the Shades' dying words) on
their shipped art as the `sovereign` and `shade` actors, one mood each. Mood
portraits wait until a scene needs more than one register from them; their
voice rules (`02-cast.md`: the Sovereign's avoidance of "walk", the Shade's
fragments) should shape the poses then.

## Owed — shipped content still on its fallback

Content that ships before its art exists. Each row renders today on the
existing fallback, so nothing is broken, but nothing is finished either: a card
without `cards/<id>.jpg` shows a bare pane (`presentation/combat/card_view.gd`),
a relic without `relics/<id>.png` shows no image on the reward, shop and crown
screens (each checks `ResourceLoader.exists` first), and a deed without
`deeds/<id>.png` leaves its Vigil row's art slot empty. Generate against the
bibles in the first section (`card-art-bible.md`, `relic-art-bible.md`, and
`meta-art-bible.md` for deeds) at the siblings' sizes: cards 2048×1374 JPEG,
relics 512×341 RGBA, deeds 512×512 RGBA. When an asset lands, delete its row
and give it a section of its own with the prompt that made it.

Nothing is owed at present (2026-09-30). The Edge way's last two rows, its crown
and its deed, shipped in the section of that date above.
