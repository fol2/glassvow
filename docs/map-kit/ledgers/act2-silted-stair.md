# `act2-silted-stair` — conversion concept

- **asset_id:** `act2-silted-stair`
- **billed_id:** A2-2
- **act:** II (`act_key=act2`)
- **role:** ordinary
- **dest:** `assets/art/map/geometry/act2/silted-stair.glb` (not generated this pass)
- **concept:** `assets/art/map-concepts/act2-silted-stair.jpg`
- **reshape vs new:** **new**. Dest was absent; `geometry/act2/` held only `terminus-flooded-threshold.glb`. First picture, not a reshape, and the kit concept was not seeded from `map-concepts/act2-terminus-flooded-threshold.png`.
- **silhouette job:** Broad descending stair that thickens and merges into a silt wedge at the bottom, treads readable as one fused mass not thin steps, silted-stone albedo; no railings, no climb-tower, no painted water.
- **direction:** `docs/map-kit/act2-prompt-direction.md` §9 A2-2
- **L3 risk:** yes (stair-as-the-road / climb-tower / wrapping stair is glossary Tier A). Checked `docs/story/05-foreshadow-ledger.md` rule 2: kits are L0–L1 scenery. A2-2 is a local silted stair mass, not the pilgrimage.


**GLB landed 2026-08-25** as Studio HD textured (`--textured`, ordinary 1500/1K/Ultra off). Dest is on disk. 20-placement: `docs/reviews/292/act2-silted-stair-20.png`. This ledger’s “no GLB / do not append art-ledger” lines are historical.
## Prompt (attempt 1, `image_gen` 1:1)

Shared preamble + A2-2 subject + shared negatives + species extra negatives, plus fuse language:

> Orthographic three-quarter view from 35–40 degrees above of a single game-kitbash 3D prop. Entire object centred with even margin in a square 1:1 frame. Whole object visible, nothing cropped. Flat neutral mid-grey background (#8A8A8A), ground-free: no floor plane, no horizon, no environment, no cast shadow, no contact-shadow puddle, no depth of field, no vignette, no rim light. Even cold studio illumination from above-front, low-contrast, no baked AO, no theatrical key slash.
>
> TEXTURED concept, not a clay maquette: the surface must show drowned-masonry / silted-stone colour and courses — weathered blue-grey ashlar, rust-stained joints, pale silt crust — large planar faces, low-poly-friendly, matte. One connected solid volume sitting as if on invisible ground. Clean silhouette. Isolated subject, large in frame. Not a tile texture, not a landscape, not a diorama.
>
> Subject: one broad descending stair mass. A short, wide flight of thick treads that thicken as they go down and melt into a silt wedge at the bottom — the stair and the silt are one fused volume, not a staircase planted in a puddle. Three to five chunky treads only, each a deep slab, readable as one stepped mass, not thin steps, not a ladder. The underside is filled — a solid stepped wedge, no hollow under-stair, no gaps between treads, no separate slabs. No railings, no newel posts, no stringers as extra pieces. Silted-stone albedo: drowned grey-blue treads with large coursed masonry faces, pale silt crust dominating the lower wedge, rust seeps at the sides. Distinct descending-wedge silhouette, wider than it is tall, sitting on invisible ground. One continuous volume — no gaps, no separate chips.
>
> No towers, no spires, no climb, no wrapping stair, no stair-as-the-road. No spiral, no switchback, no doorway at the top. No cage bars, no chains, no hanging lamps, no paired lanterns, no wick, no true flame, no fire, no ember. No kelp, no coral, no starfish, no fish, no bubbles, no painted water sheets, no caustic shafts, no water planes, no water sheet at the bottom. No grout lace, no thin crack lines, no moss hair, no grass. No readable text, no letters, no glyphs. No rose window, no wheel window, no circular six-pane disc, no trefoil, no broken halo, no obsidian star, no watching eye, no queue of standing figures, no person, no skeleton. No inverted hearth-amber, no gold-city, no sealed east door. No second prop. No floor disc. No cast shadow. No chips detached from the mass. No railings even as painted lines.

## Attempts

### 1 — fail (grout noise + stacked slabs)

- **tool:** `image_gen` `aspect_ratio=1:1`
- **sha256:** `053ea36289ff8e0302bc6f40f750d284eb692084252c4a97c4ded3f6e227af3a`
- **pixels:** 1024×1024 RGB JPEG

**Blind description (written after `read_file`, before re-checking the spec):** Square mid-grey void, no floor or horizon. Isolated four-tread masonry stair, three-quarter from above. Blue-grey coursed blocks with rust-stained joints; pale cracked silt on the treads and a silt ramp off the lowest step wrapping the right base. No railings, water, figures, or second props. No cast-shadow puddle. Treads read as stacked brick-scale slabs with peeling silt flakes.

**Review vs spec:** Framing holds (1:1, centred, ground-free grey, no floor disc). Foreshadow bans hold (no rails, water, climb-tower, rose, walkers). Fail on textured-surface noise and silhouette: brick-scale grout lace and silt craquelure (hard ban: grout lace / thin crack lines); treads as separate stacked slabs rather than one fused stepped wedge; mass not clearly wider than tall.

### 2 — fail (lipped slabs + dry grey)

- **tool:** `image_edit` of attempt 1
- **sha256:** `3a755937344cad076060e29d594322d168f2d4bcd214dc305462a42f8bcff54c`
- **pixels:** 1024×1024 RGB JPEG

**Edit prompt:** Keep the same isolated square 1:1 framing, mid-grey void, no floor or cast shadow. Rewrite as one fused descending-wedge mass, three or four very thick treads melted into the next with no gaps or overhanging lips, underside filled, wider than tall. Treads thicken into a pale silt wedge. Large planar ashlar courses only — no grout lace, no thin cracks, no craquelure. Blue-grey silted stone, pale silt on the lower wedge, broad rust seeps. No railings, water, spiral, tower, doorway, or second prop.

**Blind description (written after `read_file`, before re-checking the spec):** Square mid-grey void. Three chunky grey stone treads, three-quarter from above. Pale silt ramp at the front-left wrapping the right base as a plinth. Rust on the right edge. No rails, water, or shadow. Wider than tall. Large ashlar faces instead of brick. Top tread still a lipped slab sitting on the stack; silt still flake-textured; hue is dry grey rather than drowned blue-grey.

**Review vs spec:** Framing, no-water / no-rail / no-tower bans hold. Fail on silhouette_job melt: top tread is still a separate lipped slab; silt is a hard-edged ramp glued on rather than the stair thickening into it; remaining silt flakes plus dry-grey ashlar miss the drowned-masonry albedo.

### 3 — pass (landed)

- **tool:** `image_edit` of attempt 2
- **sha256 (landed file):** `fbd581749b39b54e8f754605ef58cd6deb032878f602b4b3d8f99897a90534f6`
- **pixels:** 1024×1024 RGB JPEG
- **bytes:** 147862

**Edit prompt:** Keep the same square 1:1 framing, camera, mid-grey void, no floor, no cast shadow. Fuse treads into one solid stepped wedge: terraces on a filled mass, no undercut, no floating top slab. Three or four thick treads, short and broad, wider than tall. Stair thickens as it descends and melts into a pale silt wedge — one continuous volume, lower third silt crust, not a separate glued ramp. Drowned blue-grey / brine-teal masonry on the upper treads, large planar coursed ashlar, broad rust seeps, pale silt crust, no thin cracks, no grout lace. No railings, water, people, towers, or second prop.

**Blind description (written after `read_file`, before re-checking the spec):** Square mid-grey void, no floor, no shadow. Short three-tread stair mass, three-quarter from above. Upper treads are muted teal / blue-grey drowned masonry with large block courses and rust along the edges and right side. Lowest third is a smooth pale silt wedge ramping down to the lower-left and wrapping the right base as a plinth, with an irregular melted edge where silt meets stone. Three chunky treads, filled underside, no rails, no water, no second object. Wider than tall. Isolated, centred, even margins, even studio light.

**Review vs spec (after re-read):**

| gate | result |
|---|---|
| silhouette_job | **pass.** Broad descending stair, three chunky treads as one filled stepped wedge, silt dominating the lower mass so the stair disappears into it. Not thin steps, not a wrapping climb-tower, not stair-as-the-road. |
| framing | **pass.** 1:1 1024², whole object, centred with even margin, 35–40° three-quarter, flat mid-grey ground-free background (corner samples ~#757575 family), no horizon, no cast-shadow puddle, no second prop. |
| textured surface | **pass.** Drowned blue-grey / brine-teal coursed ashlar, iron-oxide rust seeps, pale silt crust; large planar faces; not clay-maquette. Colour is in the material. |
| foreshadow bans | **pass.** No six-pane rose / wheel / circular disc; no walkers; no inverted hearth-amber; no court marks; no paired lanterns; no sealed east door; no climb-tower / wrapping stair / stair-as-the-road; no text; no cages, chains, kelp, coral, or painted water. |

Nits accepted, not fails: the top tread still has a shallow terrace lip (a stepped wedge must show treads; it is not a detached chip). The silt wedge stays a readable descending ramp rather than an amorphous melt — that is the species silhouette (`broad stair disappearing into silt`). Brine-teal is in the drowned-masonry family, not a neon grade wash.

## Last self-review

**Passed** on attempt 3. Concept and this ledger exist. No GLB generated. `docs/art-ledger.md` not appended.
