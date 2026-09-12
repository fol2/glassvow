# `act2-drowned-wall-corner` — conversion concept

- **asset_id:** `act2-drowned-wall-corner`
- **billed_id:** A2-1
- **act:** II (`act_key=act2`)
- **role:** ordinary
- **dest:** `assets/art/map/geometry/act2/drowned-wall-corner.glb` (not generated this pass)
- **concept:** `assets/art/map-concepts/act2-drowned-wall-corner.jpg`
- **reshape vs new:** **new**. Dest was absent; `geometry/act2/` held only `terminus-flooded-threshold.glb`. First picture, not a clay copy, not a reshape of that hero, and the kit concept was not seeded from `map-concepts/act2-terminus-flooded-threshold.png`.
- **silhouette job:** L-plan drowned city wall corner: two thick masonry walls meet at a right angle on a silt-bitten plinth, one missing upper crenel as a concave bite, rust-stained courses, `TEXCOORD_0` plus drowned-masonry albedo; no towers, bars, chains, kelp, or water sheets.
- **direction:** `docs/map-kit/act2-prompt-direction.md` §9 A2-1
- **L3 risk:** yes (six-pane rose / wheel as architecture; queue of standing walkers). Checked `docs/story/05-foreshadow-ledger.md` rule 2: kits are L0–L1 scenery.


**GLB landed 2026-08-25** as Studio HD textured (`--textured`, ordinary 1500/1K/Ultra off). Dest is on disk. 20-placement: `docs/reviews/292/act2-drowned-wall-corner-20.png`. This ledger’s “no GLB / do not append art-ledger” lines are historical.
## Prompt (attempt 1, `image_gen` 1:1)

Shared preamble + A2-1 subject + shared negatives + species extra negatives, verbatim intent:

> Orthographic three-quarter view from 35–40° above of a single game-kitbash 3D prop. Entire object centred with even margin in a square 1:1 frame. Whole object visible, nothing cropped. Flat neutral mid-grey background (#8A8A8A), ground-free: no floor plane, no horizon, no environment, no cast shadow, no contact-shadow puddle, no depth of field, no vignette, no rim light. Even cold studio illumination from above-front, low-contrast, no baked AO, no theatrical key slash. TEXTURED concept, not a clay maquette: HD Model will bake albedo from this picture, so the surface must show drowned-masonry / silted-stone colour and courses — weathered blue-grey ashlar, rust-stained joints, pale silt crust — large planar faces, low-poly-friendly, matte. One connected solid volume sitting as if on invisible ground. Clean silhouette. Isolated subject, large in frame. Not a tile texture, not a landscape, not a diorama.
>
> Subject: one L-plan drowned city wall corner. Two thick masonry walls meet at a right angle on a low silt-bitten plinth, the whole thing one fused mass. Walls are short and chunky, not a tower — about as tall as two or three broad ashlar courses plus a blunt merlon line. One upper crenel is missing as a concave bite in the same solid, not a separate chip. Rust stains run down the courses; pale silt crusts the plinth and the inner angle. Drowned-masonry albedo, blue-grey stone, iron-oxide joints. Distinct L-shaped silhouette, still a simple kitbash volume.
>
> Show the inner L-corner clearly: both short wall arms visible, the right-angle join readable from 35–40° above, parapet merlons as blunt rectangular teeth, exactly one merlon-gap as a U-shaped concave bite in the parapet of one arm. Each wall only two or three huge coursed blocks tall. Thick fortress-wall thickness. Low plinth slightly wider than the walls, eaten by pale silt. Coursed ashlar like a weathered stone texture photo on large planar faces, rust-orange in the joints, brine-teal and blue-grey stone, matte, not shiny. No roof. Not a keep. Not a building. A short ruined wall-corner kit piece.
>
> No towers, no spires, no climb, no wrapping stair, no stair-as-the-road. No cage bars, no chains, no hanging lamps, no paired Act I lanterns, no wick, no true flame, no fire, no ember. No kelp, no coral, no starfish, no fish, no bubbles, no painted water sheets, no caustic shafts, no water planes. No grout lace, no thin crack lines, no moss hair, no grass. No readable text, no letters, no glyphs, no page-spreads with writing. No rose window, no wheel window, no circular six-pane disc, no trefoil as a counted emblem, no broken halo, no obsidian star, no watching eye, no queue of standing figures, no person, no skeleton, no Leviathan. No inverted hearth-amber, no gold-city, no sealed east door. No second prop. No floor disc. No cast shadow. No chips detached from the mass. No keep, no turret, no flag, no arrow-slit lace, no through-arch, no lantern, no doorway, no windows, no pointed gothic openings, no battlement tower, no chimney, no smoke.

## Attempts

### 1 — fail (silhouette + surface)

- **tool:** `image_gen` `aspect_ratio=1:1`
- **sha256:** `77a5bbd6bf2655538dde3189cbc027900011030e8a84884b652535371ad2a104`
- **pixels:** 1024×1024 RGB JPEG
- **bytes:** 242550

**Blind description (written after `read_file`, before re-checking the spec):** Square mid-grey void, no floor or horizon. Isolated L-shaped masonry wall corner, three-quarter from above, convex exterior toward camera. Two short thick walls meet at a right angle on a wider plinth. Blue-grey rectangular ashlar with rust-orange in the joints and pale beige silt crust on the plinth. Blunt merlons along the parapet. On the right arm a jagged whitish stone fragment sits in a broken merlon gap — a hanging chip, not a clean notch. Walls are four to five small-brick courses plus merlons. Even studio light. No figures, text, water, chains, lanterns, or second props.

**Review vs spec:** Framing holds (1:1, centred, grey void, no ground disc or contact-shadow puddle). Foreshadow bans hold (no rose, queue, water, cages, climb-tower). Fail on silhouette: the missing crenel is a **detached pale shard** in the notch, the standing-monument chip class. Fail on textured surface: **brick-scale grout** and thin crack lines on the plinth instead of two or three broad ashlar courses.

### 2 — fail (surface)

- **tool:** `image_edit` of attempt 1
- **sha256:** `53d1732ae9c29c7d7d57e713439de96607946acba299dbdf412481e2d9de229d`
- **pixels:** 1024×1024 RGB JPEG
- **bytes:** 227237

**Edit prompt:** Keep the L-plan, 35–40° camera, mid-grey void, no floor or cast shadow. Replace the hanging merlon chip with a clean U-shaped concave bite fused into the parapet. Rebuild walls as two or three broad ashlar courses plus a blunt merlon line — large planar drowned-masonry faces, rust-orange joints, pale silt crust, no grout lace, no thin crack web.

**Blind description (written after `read_file`, before re-checking the spec):** Same converter frame and L-plan. Merlons more regular. The right parapet now has a U-shaped gap between two merlons with rust in the notch — no hanging shard. Walls still a stack of many small bricks, four to five courses plus merlons. Plinth still shows a hairline crack web in the silt. Blue-grey stone, rust streaks, pale silt. No water, people, windows, roses, chains, or floor disc.

**Review vs spec:** Silhouette of the L and the fused crenel bite now hold. Framing and foreshadow still hold. Fail on textured surface: brick-scale noise and **thin crack lines** on the plinth remain; height is still more brick wall than two or three broad ashlar courses.

### 3 — pass (landed)

- **tool:** `image_edit` of attempt 2
- **sha256 (landed file):** `35eb8c35b37d66a5742d29d38607fa4562fc5b1034389c512d3b49d70a371683`
- **pixels:** 1024×1024 RGB JPEG
- **bytes:** 162780

**Edit prompt:** Keep the isolated L-plan, 35–40° three-quarter camera, centred square framing, flat mid-grey #8A8A8A void, no floor, no cast shadow. Rebuild as a low-poly kitbash with large planar faces: two or three very broad ashlar courses plus a simple blunt merlon line; wide rust-stained joints, not grout lace; silt-bitten plinth without a crack web; few blunt merlons; one missing crenel as a clean rectangular concave U-bite fused into the same solid.

**Blind description (written after `read_file`, before re-checking the spec):** Same converter frame: square, mid-grey void, three-quarter from above, isolated. L-plan wall corner, convex exterior to camera, both arms visible. Plinth is a low silt-bitten platform with pale crust and no crack web. Wall body is three smoother grey courses plus merlons. Rust-orange stains a course under the parapet and runs down joints. Right parapet has one U-shaped concave bite between merlons, fused, no chip. Merlons are blunt rectangular cubes. Blue-grey drowned masonry, matte, even light. No figures, text, water, chains, lanterns, windows, roses, or floor/contact shadow.

**Review vs spec (after re-read):**

| gate | result |
|---|---|
| silhouette_job | **pass.** L-plan of two thick short walls on a silt-bitten plinth; one missing upper crenel as a fused concave bite; not a tower/keep/spire; no bars, chains, kelp, or water sheets. |
| framing | **pass.** 1:1, whole object, centred with even margin, 35–40° three-quarter, flat mid-grey ground-free background, no horizon, no cast-shadow puddle, no second prop. |
| textured surface | **pass.** Coursed blue-grey drowned masonry, rust-stained joints, pale silt on the plinth; not clay-maquette. Colour is in the material. Brick-scale and crack-web from attempts 1–2 are gone. |
| foreshadow bans | **pass.** No six-pane rose / wheel / circular disc; no trefoil; no walkers; no Act III court marks; no inverted hearth-amber; no paired lanterns; no kelp/coral/painted water; no cages/chains; no readable text. |

Nits accepted, not fails: merlon count is still a short crenel line (more than three teeth) rather than two huge blocks; courses are still several slabs per arm rather than one slab spanning the wall. Species identity is the L plus the single fused crenel bite, which is enough to keep A2-1 off the generic-brick and climb-tower failure modes.

## Last self-review

**Passed** on attempt 3. Concept and this ledger exist. No GLB generated. `docs/art-ledger.md` not appended.
