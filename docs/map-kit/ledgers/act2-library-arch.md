# `act2-library-arch` — conversion concept

- **asset_id:** `act2-library-arch`
- **billed_id:** A2-3
- **act:** II (`act_key=act2`)
- **role:** ordinary
- **dest:** `assets/art/map/geometry/act2/library-arch.glb` (not generated this pass)
- **concept:** `assets/art/map-concepts/act2-library-arch.jpg`
- **reshape vs new:** **new**. Dest was absent; `geometry/act2/` held only `terminus-flooded-threshold.glb`. Not a reshape of that hero, and the kit concept was not seeded from `map-concepts/act2-terminus-flooded-threshold.png`.
- **silhouette job:** Flooded-library threshold: low pointed through-arch with thick jambs and a fused book-course lintel, smaller and chunkier than the Act II terminus, drowned-masonry albedo; no readable text, cages, chains, or water sheets.
- **direction:** `docs/map-kit/act2-prompt-direction.md` §9 A2-3
- **L3 risk:** yes (library copy, rose/six-pane, cages/chains from the combat mid-plate). Checked `docs/story/05-foreshadow-ledger.md` rule 2: kits are L0–L1 scenery.


**GLB landed 2026-08-25** as Studio HD textured (`--textured`, ordinary 1500/1K/Ultra off). Dest is on disk. 20-placement: `docs/reviews/292/act2-library-arch-20.png`. This ledger’s “no GLB / do not append art-ledger” lines are historical.
## Prompt (attempt 1, `image_gen` 1:1)

Shared preamble + A2-3 subject + shared negatives + species extra negatives, verbatim intent:

> Orthographic three-quarter view from 35–40 degrees above of a single game-kitbash 3D prop. Entire object centred with even margin in a square 1:1 frame. Whole object visible, nothing cropped. Flat neutral mid-grey background (#8A8A8A), ground-free: no floor plane, no horizon, no environment, no cast shadow, no contact-shadow puddle, no depth of field, no vignette, no rim light. Even cold studio illumination from above-front, low-contrast, no baked AO, no theatrical key slash. TEXTURED concept, not a clay maquette: the surface must show drowned-masonry / silted-stone colour and courses — weathered blue-grey ashlar, rust-stained joints, pale silt crust — large planar faces, low-poly-friendly, matte. One connected solid volume sitting as if on invisible ground. Clean silhouette. Isolated subject, large in frame. Not a tile texture, not a landscape, not a diorama.
>
> Subject: one flooded-library threshold. A LOW pointed through-arch, thick jambs, squat — smaller and chunkier than a monumental city gate. Overall mass is a short fat doorway, wider than it is tall, like a kitbash prop not a city monument. The opening is a simple low pointed Gothic hole punched clean through one solid so the same mid-grey background is visible through the arch; the opening is empty, not a door, not a back wall. Jambs are very thick chunky masonry piers, each about as wide as the opening, both feet planted on invisible ground. The lintel is a fused book-course: four or five drowned folio slabs melted into the masonry as one band of thick rectangular blocks sitting on the jambs, slightly different thicknesses like closed books fused into stone, blank faces with no titles, no letters, no spine labels, not a shelf of separate books. Drowned-masonry albedo: cold blue-grey / brine-teal stone, iron-oxide rust seeps in the joints, pale silt crust at the two bases only. Distinct small-arch silhouette, one connected volume. Coursed ashlar on the jambs, large planar blocks, not brick-scale noise.
>
> No towers, no spires, no climb, no wrapping stair, no stair-as-the-road. No cage bars, no chains, no hanging lamps, no paired Act I lanterns, no wick, no true flame, no fire, no ember. No kelp, no coral, no starfish, no fish, no bubbles, no painted water sheets, no caustic shafts, no water planes. No grout lace, no thin crack lines, no moss hair, no grass. No readable text, no letters, no glyphs, no page-spreads with writing. No rose window, no wheel window, no circular six-pane disc, no trefoil as a counted emblem, no broken halo, no obsidian star, no watching eye, no queue of standing figures, no person, no skeleton, no Leviathan. No inverted hearth-amber, no gold-city, no sealed east door. No second prop. No floor disc. No cast shadow. No chips detached from the mass. No hanging pendants, no paired lanterns, no trefoil in the spandrel, no rose, no side wings, no silt runway as wide as a monumental slab, no cages, no bars in the opening, no letters on the books. Not a tall ruined city gate. Not heroic scale. Kit-scale low fat doorway.

## Attempts

### 1 — fail (silhouette)

- **tool:** `image_gen` `aspect_ratio=1:1`
- **sha256:** `8567fb726030a4b929ff684f3170b303154d0e75cc784e88e9c7d70fc7941eac`
- **pixels:** 1024×1024 RGB JPEG

**Blind description (written after `read_file`, before re-checking the spec):** Square mid-grey void, no floor or horizon. Isolated masonry arch, three-quarter from above-front. Two thick vertical piers of large blue-grey ashlar with rust-stained joints and pale silt wrapping the feet. A pointed Gothic hole punches through; the same grey field shows in the opening. The arch ring is smaller wedge blocks. Across the top sit four large rectangular cap cubes, slightly stepped, with visible seams — they read as separate oversized blocks, not one fused band. Even studio light with self-shadow in the soffit. No figures, text, water, chains, lanterns, cages, or second props. The mass is about as tall as it is wide, with a relatively high pointed opening.

**Review vs spec:** Framing, textured drowned masonry, and foreshadow bans hold. Fail on silhouette: not a **low fat doorway** (five-course jambs plus a tall pointed opening), and the lintel is four **separate cap cubes** (island risk; not a fused book-course). Not terminus-scaled (no wings, no pendants) — the miss is height and lintel fusion.

### 2 — pass (landed)

- **tool:** `image_edit` of attempt 1
- **sha256 (landed file):** `76a787d2952f517004606535e95c2140d5bfed5ed3f7eba31f85c891f7ad96a3`
- **pixels:** 1024×1024 RGB JPEG
- **bytes:** 219169

**Edit prompt:** Keep the same square 1:1 mid-grey converter frame and drowned-masonry albedo. Shorten to three broad ashlar courses plus one fused lintel; thicken jambs; keep a low pointed through-hole with grey showing through; replace the four cap cubes with one fused book-course of folio slabs melted into a continuous band, no air gaps, no letters; no wings, pendants, chains, lanterns, trefoil, rose, water, or silt runway.

**Blind description (written after `read_file`, before re-checking the spec):** Same converter frame: square, mid-grey void, three-quarter from above, isolated. The arch is squatter. Left jamb is three large ashlar courses plus a silted plinth, then a lintel band. Right jamb matches. The top is now a continuous row of four rectangular blocks with tight joints — one lintel rather than stacked chips. Pointed through-arch; grey shows through. Silt crust at both feet. Blue-grey drowned masonry; rust in the joints quieter than attempt 1. No text, water, chains, cages, lanterns, people, or floor/contact shadow.

**Review vs spec (after re-read):**

| gate | result |
|---|---|
| silhouette_job | **pass.** Low pointed through-arch, thick jambs, fused four-block book-course lintel, kit-scale vs the Act II terminus (no ruined wings, no hanging pendants, no silt runway). Opening is empty. |
| framing | **pass.** 1:1, whole object, centred with even margin, 35–40° three-quarter, flat mid-grey ground-free background, no horizon, no cast-shadow puddle, no second prop. |
| textured surface | **pass.** Coursed blue-grey / brine-teal ashlar, rust-stained joints, pale silt at the bases; not clay-maquette. Colour is in the material. |
| foreshadow bans | **pass.** No six-pane rose / wheel / circular disc; no readable text or spine-letters; no cages, chains, hanging lamps, or paired lanterns; no kelp/coral/painted water; no walkers; no Act III court marks; no inverted hearth-amber. Lintel faces are blank. |

Nits accepted, not fails: the lintel still reads as thick ashlar rectangles more than obvious folios (spec allows “one band of thick blocks”); the pointed opening is still a short Gothic, not a depressed Tudor. Species identity is the squat through-door plus the fused lintel band, which is enough to keep A2-3 off the terminus clone failure mode.

## Last self-review

**Passed** on attempt 2. Concept and this ledger exist. No GLB generated. `docs/art-ledger.md` not appended.
