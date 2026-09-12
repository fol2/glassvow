# act3-court-plinth — conversion concept

Wave-1 ordinary kit for Act III (黑曜王庭 / The Obsidian Court). Direction:
`docs/map-kit/act3-prompt-direction.md` §7 `act3-court-plinth`. Bill A3-3 in
`docs/map-scene-asset-bill.md`.

| Field | Value |
|---|---|
| `asset_id` | `act3-court-plinth` |
| `billed_id` | `act3-court-plinth` (bill A3-3) |
| `act_key` | `act3` |
| role | ordinary |
| dest | `assets/art/map/geometry/act3/court-plinth.glb` (not generated this pass) |
| concept | `assets/art/map-concepts/act3-court-plinth.jpg` |
| world scale seat | 2.2 |
| reshape-vs-new | **new** — dest was absent; `geometry/act3/` held only the signed hero `terminus-broken-ring-arch.glb`. First picture, not a reshape |
| silhouette job | Sovereign-court stacked slab dais, two or three fused terraces as one low rectangular mass, no separate steps |
| L3 risk | yes (stair-as-the-road / climb; seated king / throne). Checked `docs/story/05-foreshadow-ledger.md` rule 2: kits are L0 scenery. A symmetric fused dais is a local court mass, not a climb and not a Sovereign portrait |

Do not append `docs/art-ledger.md`. No GLB was generated on this pass.

The wave direction names the concept `.png`. This slot saved `.jpg` as the
conversion-concept task required. Square 1024×1024 RGB JPEG.

---


**GLB landed 2026-08-25** as Studio HD textured (`--textured`, ordinary 1500/1K/Ultra off). Dest is on disk. 20-placement: `docs/reviews/292/act3-court-plinth-20.png`. This ledger’s “no GLB / do not append art-ledger” lines are historical.
## Prompt (attempt 1, `image_gen`, aspect 1:1)

> Square 1:1 game-kitbash 3D prop concept, entire object centred with even margin, three-quarter view from 35-40 degrees above. Isolated subject, large in frame. Flat neutral mid-grey background (#8A8A8A), ground-free, no horizon, no environment, no cast shadow, no baked AO puddle, no contact darkening, no depth of field.
>
> Cold violet-black low-contrast matte illumination from above-front; even studio light; no rim light, no chrome spec, no emissive glow, no lantern, no flame.
>
> Material: faceted obsidian court-stone, coursed court ashlar fused into obsidian, dull violet-black glass-stone. Almost-black glass that does not transmit light. Broad planar facets, few of them. A faint dull magenta-violet sheen in the seams only — quiet albedo, not a glow, not neon, not gold. Weathered coursed faces as painted albedo, not carved micro-displacement, not brick-by-brick grout, not crack lines, not gold leaf, not runes.
>
> Subject: a single Sovereign-court stacked-slab dais. Two or three fused terraces as ONE low rectangular mass, much wider than tall. One connected volume. A short ziggurat melted into one blunt rectangular block. The upper terrace is a smaller rectangle fused onto a larger base rectangle; the join is melted, no gap, no undercut, no air. Terrace shoulders only — NOT a staircase, NOT separate steps, NOT a stair flight, NOT tiny risers, NOT stacked loose slabs, NOT a climb. Height about one-third of the long width. Grounded heel, sitting as if on implied ground but with no floor disc.
>
> No throne, no chair, no seated figure, no cushion, no crown, no scepter, no king. Not a road paving slab, not a single thin flagstone, not a tall podium, not an obelisk, not a monument stele, not a round stump. Blunt rectangular silhouette readable as a black filled shape with two terrace shoulders.
>
> Clean planar low-poly-friendly game-asset concept. One connected volume. No characters, hands, faces, text, glyphs, numbers, windows, rose lace, circular windows, stained glass, lanterns, water, ash, roots, sky, storm clouds, floating jewellery, hanging crystal, halo, ring, door, keyhole, lock.

## Prompt (attempt 2, `image_edit` of attempt 1)

> Keep the same square 1:1 framing, three-quarter view from 35-40 degrees above, centred isolated subject, large in frame, flat mid-grey #8A8A8A background, ground-free, no horizon, no cast shadow, no floor disc.
>
> FUSE the three stacked boxes into ONE connected low rectangular mass. Melt the terraces together: no air gaps, no undercuts, no separate slabs, no stair flight, no tiny risers. The silhouette must read as one blunt low rectangle with two terrace SHOULDERS — a short ziggurat fused into a single block, like dark obsidian that flowed together. Upper terrace is a smaller rectangle continuous with the larger base; the join is a beveled shoulder, not a gap.
>
> Remove brick-by-brick grout lines and masonry grid. Keep only broad planar facet planes and a faint dull magenta-violet sheen in the seams. Material: faceted obsidian court-stone, coursed court ashlar fused into obsidian as quiet albedo, not grout, not crack lines, not gold, not glow, not chrome.
>
> Still wider than tall, short dais, not a podium, not a paving slab, not a throne. No figures, crown, chair, windows, text, sky. One connected volume. Cold violet-black low-contrast matte even studio light.

## Prompt (attempt 3, `image_edit` of attempt 2) — shipping

> Keep the same square 1:1 converter framing: three-quarter view from 35-40 degrees above, whole object centred with even margin, large in frame, flat mid-grey #8A8A8A void, ground-free, no horizon, no floor disc, no cast shadow, no AO puddle.
>
> Completely rewrite the silhouette. This is ONE solid chunk of faceted obsidian, not three boxes. A single low wide rectangular dais, much wider than tall. TWO terrace levels only: a large grounded base rectangle and a slightly smaller top deck, melted together with a shallow 45-degree beveled shoulder all around — the join is a continuous slope, no 90-degree step, no air gap, no undercut, no lid, no cavity, no overhang.
>
> Delete the notched decorative corners, delete the floating top slab, delete any third layer. If filled black, the outline is one blunt low rectangle with two gentle terrace shoulders, like a short fused ziggurat or a melted cake, never a staircase.
>
> Solid throughout, one connected volume. Broad planar facets. Faceted obsidian court-stone, dull violet-black glass-stone, faint magenta-violet sheen only in facet seams. Quiet albedo, no grout grid, no brick lace, no crack lines, no gold, no glow, no chrome spec. No throne, chair, crown, figure, window, text, sky. Cold violet-black low-contrast matte even studio light.

---

## Attempts

Blind descriptions were written from `read_file` of the generated image
**before** scoring the spec.

### 1 — fail

- tool: `image_gen`, aspect 1:1
- sha256 `639396c359e89248e8848bc99cae1a8605727e29f23061e2865b1a5072616094`

**Blind:** Square mid-grey void. Three concentric dark rectangular boxes
stacked as a ziggurat, three-quarter from above, centred, large. Almost-black
stone with violet edge sheen. Each slab beveled; top slab has scalloped /
chipped corners. Regular ashlar grout grid on the faces. Layers have visible
gaps. No floor disc, no figure, no throne, no window. Wider than tall.

**Spec:** silhouette fail — three *loose* slabs, not fused (stair-farm /
second-island risk). Over-texture: brick-by-brick grout, banned. Framing
otherwise held. Foreshadow: no rose, six, door, crown, glow, glass pane;
the stacked loose slabs still read as a climb.

### 2 — fail

- tool: `image_edit` of attempt 1
- sha256 `9bb7c962e4b61369043584a39689aa8ba1bb2b52d886b4b1fee843908be96749`

**Blind:** Same converter framing. Grout grid gone. Dark violet-black matte
with edge sheen. Bottom-to-middle join closer to a flush shoulder. Top still
sits as a separate lid with notched decorative corners and a dark undercut
under the notches. Three-tier wedding-cake read. No floor, no figure.

**Spec:** grout pass; fusion still fail on the top lid (HD would split).
Notched corners are furniture-molding, not a kitbash mass. Stair-farm still
open.

### 3 — pass (shipping)

- tool: `image_edit` of attempt 2
- path `assets/art/map-concepts/act3-court-plinth.jpg`
- 1024×1024 RGB JPEG
- sha256 `a193652783ce71bba536a0742f47d52e11a018cac7b23068e88a8d371e740d3f`

**Blind:** Square mid-grey void, three-quarter elevated, centred, even
margin, no floor disc. One low wide rectangular dais of dull violet-black
stone. Concentric terrace shoulders fused with sloped bevels — no air gaps,
no lid, no notches, no grout. Wider than tall. Quiet edge sheen, no chrome,
no glow. No figure, throne, crown, window, glyph, sky.

**Spec (after re-read):**

| Gate | Result |
|---|---|
| silhouette job | **pass** — stacked-slab dais; fused terraces as one low rectangular mass; bevelled shoulders, not separate steps |
| framing | **pass** — 1:1, whole object, centred, #8A8A8A void, ground-free, no horizon, no cast-shadow puddle, ~35–40° three-quarter |
| textured surface | **pass** — faceted obsidian albedo, faint magenta-violet seam sheen, not clay-maquette, not grout, not gold |
| foreshadow bans | **pass** — no rose/six/wheel/lace, no keyhole, no gold halo, no terminus ring, no door, no tower, no seated king, no Act I/II/IV materials, no faces/glyphs/six/III, no emissive will-light, no transparent pane. Symmetric dais, not stair-as-the-road |
| paving collision | **pass** — not a single-layer road slab; terrace shoulders distinguish it from `shared-road-slab-a/b` |
| one volume | **pass** — solid fused chunk; no detached chip |

The generator still drew three terrace levels rather than the requested two.
The direction allows two *or* three fused terraces; they are melted, so this
is in-bounds.

---

## Last self-review

**Passed** on attempt 3. Concept and this ledger exist. No GLB generated.
`docs/art-ledger.md` not appended.

## Studio (not this pass)

Ordinary HD profile when a later slice converts: `--textured --privacy private
--faces 1500 --topology triangle --texture-quality 1k --pbr off`. Caps 192 KiB /
600–2500 triangles. Tripo Studio only; never the API.
