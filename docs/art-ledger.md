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

### `scenes/night-stall.png` — 1600×1100 RGB — **INTERIM, concept-grade**

The Night Stall, the shop's whole screen: concept C1 makes the painting the
layout, so this is not decoration but the surface every ware is positioned
against (`presentation/run/stall_layout.gd`). Copied verbatim from the signed
design record at `docs/design/2026-08-14-ui-direction/stall-scene.png`, which
is where #163 generated it as a **concept** render; #242 slice 1 gave it a
`res://assets/` home so the production pass has a stable path to overwrite.

**This is a placeholder and is listed here so it cannot become the next
`meta/hollow-lamplighter`.** #242 slice 3 replaces the bytes at this same path
with a production render, and the replacement is bound by three numbers the
layout depends on, not by taste alone:

- **1600×1100** (aspect 1.4545), or `StallLayout.IMAGE` moves with it.
- **The counter's front lip at v = 0.7073** — the horizon the whole crop
  pivots on.
- **Nothing load-bearing outside `StallLayout.SAFE_BAND`** — u ∈ [0.042,
  0.958], v ∈ [0.245, 0.899]. The three canopy hooks, both counter stands, the
  right-hand ledge and the stair treads must all be painted inside it, because
  a 20:9 frame crops the rest away.

**Prompt not recorded** — #163 generated this without logging one. Slice 3 must
write its prompt here.

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
