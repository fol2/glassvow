# act2-sunken-shelf-mass — conversion concept

| field | value |
|---|---|
| asset_id | `act2-sunken-shelf-mass` |
| billed_id | A2-4 |
| act_key | act2 |
| role | ordinary |
| dest_path | `assets/art/map/geometry/act2/sunken-shelf-mass.glb` |
| dest_on_disk | no |
| reshape-vs-new | **new** — dest absent; first picture, not a reshape of an existing mesh |
| concept_path | `assets/art/map-concepts/act2-sunken-shelf-mass.jpg` |
| attempts | 3 |
| last_self_review | **fail** |
| sha256 | `bc9372f3885d2724be9cf938caa76121d8c33d066fe329cd0afd75a156c3df1a` |
| pixels | 1024×1024 RGB JPEG |

Silhouette job (claimed): Stacked-slab sunken shelf mass: three fused drowned book-stack shelves melted into one squat stepped mound, wider than tall, no thin slats or gaps, silt-and-masonry albedo; no loose books, lanterns, or water sheets.


**GLB landed 2026-08-25** as Studio HD textured (`--textured`, ordinary 1500/1K/Ultra off). Dest is on disk. 20-placement: `docs/reviews/292/act2-sunken-shelf-mass-20.png`. This ledger’s “no GLB / do not append art-ledger” lines are historical.
## Canonical prompt

Preamble + A2-4 subject + shared negatives + species extra negatives from `docs/map-kit/act2-prompt-direction.md` §8–§9.

> Orthographic three-quarter view from 35–40° above of a single game-kitbash 3D prop. Entire object centred with even margin in a square 1:1 frame. Whole object visible, nothing cropped. Flat neutral mid-grey background (#8A8A8A), ground-free: no floor plane, no horizon, no environment, no cast shadow, no contact-shadow puddle, no depth of field, no vignette, no rim light. Even cold studio illumination from above-front, low-contrast, no baked AO, no theatrical key slash. TEXTURED concept, not a clay maquette: HD Model will bake albedo from this picture, so the surface must show drowned-masonry / silted-stone colour and courses — weathered blue-grey ashlar, rust-stained joints, pale silt crust — large planar faces, low-poly-friendly, matte. One connected solid volume sitting as if on invisible ground. Clean silhouette. Isolated subject, large in frame. Not a tile texture, not a landscape, not a diorama.
>
> Subject: one stacked-slab sunken shelf mass. Three drowned book-stack shelves melted into one squat stepped mound, wider than it is tall, sitting on invisible ground. Each 'shelf' is a thick fused slab, no thin slats, no gaps, no separate books poking out. The stack reads as a terraced masonry heap that used to be a bookcase, not as furniture with openings. Silt-and-masonry albedo: blue-grey stone faces, pale silt pooling on the steps, rust at the risers. Distinct stepped-mound silhouette, one connected volume.
>
> No towers, no spires, no climb, no wrapping stair, no stair-as-the-road. No cage bars, no chains, no hanging lamps, no paired Act I lanterns, no wick, no true flame, no fire, no ember. No kelp, no coral, no starfish, no fish, no bubbles, no painted water sheets, no caustic shafts, no water planes. No grout lace, no thin crack lines, no moss hair, no grass. No readable text, no letters, no glyphs, no page-spreads with writing. No rose window, no wheel window, no circular six-pane disc, no trefoil as a counted emblem, no broken halo, no obsidian star, no watching eye, no queue of standing figures, no person, no skeleton, no Leviathan. No inverted hearth-amber, no gold-city, no sealed east door. No second prop. No floor disc. No cast shadow. No chips detached from the mass. No loose books, no lantern, no candle, no ladder, no cage, no readable titles, no through-gaps that become stripes when yawed, no water around the base.

## Attempts

Blind descriptions were written from `read_file` on the picture **before** scoring the spec.

### 1 — fail (ziggurat boxes + floor disc + moss)

- **tool:** `image_gen` `aspect_ratio=1:1`
- **sha256:** `e370265e3f5f0c25c016d7762b76f46be3812bcb8409afaa9bfb72111e95ca7c`
- **pixels:** 1024×1024 RGB JPEG

**Blind description (written after `read_file`, before re-checking the spec):** Three-quarter from above, square mid-grey void. Three nested square masonry terraces, concentric ziggurat. Blue-grey block sides, pale silt on each step with green stains, rust on some risers, a thin pale plinth under the lowest tier. Wider than tall. One subject. Even light. No second prop, no books, no lanterns, no water sheet.

**Review vs spec:** Framing mostly holds (square, centred, grey void, no horizon). Textured, not clay. Foreshadow bans hold. Silhouette fails: three stacked boxes plus a floor-slab, green moss, brick grout, ceremonial pyramid rather than a melted book-stack mound.

### 2 — fail (floor disc + unfused boxes)

- **tool:** `image_edit` of attempt 1
- **sha256:** `3d008f80888fd7c3aada407d42bcbb970771e37f3898b734c0e488e513dff6ea`
- **pixels:** 1024×1024 RGB JPEG

**Blind description (written after `read_file`, before re-checking the spec):** Same three nested square terraces. Green moss gone; silt tops are cream. Thin pale floor-plinth disc still under the mass, more prominent. Brick-scale courses remain. No books, lanterns, water, text.

**Review vs spec:** Textured surface and foreshadow still hold. Floor island remains (failure mode 2). Still three unfused boxes (HD will separate them). Still a ziggurat, not a cairn-mass.

### 3 — fail (roofed cubby / gap) — landed

- **tool:** `image_edit` of attempt 2
- **sha256 (landed file):** `bc9372f3885d2724be9cf938caa76121d8c33d066fe329cd0afd75a156c3df1a`
- **pixels:** 1024×1024 RGB JPEG
- **bytes:** 180569

Landed at `assets/art/map-concepts/act2-sunken-shelf-mass.jpg`.

**Blind description (written after `read_file`, before re-checking the spec):** Three-quarter from above, mid-grey void, no floor disc. Irregular stepped stone heap of about three terrace levels, blue-grey masonry with pale silt on the flats, rust streaks on the left. Edges more organic than the nested squares. A dark roofed recess / cubby under the top slab, silt-filled, reading as a bookshelf opening. Larger blocks than attempt 2. No plinth, no green, no books, no lanterns, no water, no letters.

**Score.**

| gate | hold? |
|---|---|
| framing (1:1, whole object, centred, 35–40° above, #8A8A8A void, no horizon, no floor disc, no cast-shadow blob, no DOF/vignette/rim) | yes — floor disc gone |
| textured surface (drowned masonry + silt + rust, not clay-maquette) | yes |
| foreshadow bans (no rose/six-pane, no queue, no paired lamps, no text, no water/kelp/coral, no figures, no Act III/IV marks) | yes |
| silhouette_job (three fused slabs, squat stepped mound, wider than tall, **no thin slats or gaps**) | **no** — roofed cubby is a furniture opening / gap. A2-4 species extra negatives and 20-placement mode 10 (slat-gaps become stripes) fire. HD will sculpt the hollow. |

**Verdict.** fail. Max 3 attempts; no further edit.

## Last self-review

**Failed** on attempt 3 (roofed cubby / gap). Concept and this ledger exist. No GLB generated. `docs/art-ledger.md` not appended.

## Why last review failed

Attempt 3 is the right *species family* (silted masonry stepped heap, kit-scale, grey void) but it is still furniture-with-an-opening. The silhouette job forbids gaps; the mesh contract allows a shelf step only as a **concave bite in the same solid**, not a roofed cubby. Do not send this picture to Studio until that hollow is fused shut.

A later reshape of the concept should: fill the cubby so the three slabs are one cairn-mound; keep the irregular terrace outline and the no-plinth framing; keep silt-and-masonry albedo.

## Foreshadow

Map kits are L0–L1 scenery (`docs/story/05-foreshadow-ledger.md` rule 2). This subject does not show a six-pane rose, walker-queue, paired lanterns, sealed east door, gold-city, inverted hearth, court halo/star/eye, readable library copy, or combat-plate kelp/cages. L3 risk on A2-4 is the spine-letters leak; none are in the landed frame.

## Not done here

No GLB. `docs/art-ledger.md` not appended. Dest `geometry/act2/sunken-shelf-mass.glb` remains absent.
