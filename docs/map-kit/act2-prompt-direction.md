# Act II kits — prompt direction (wave 1)

Status: **binding for concept pictures and Studio conversion.**  
Act: **II — 沉沒之城 / The Sunken City** (`act_key=act2`).  
This file does not generate images or meshes. It is the prompt contract for
the five ordinary kit rows in `assets/art/map/map-assets.json`. The Act II
terminus is already shipped and is **not** a wave-1 dest.

Wave-1 slots:

| billed | `asset_id` | dest | role |
|---|---|---|---|
| A2-1 | `act2-drowned-wall-corner` | `assets/art/map/geometry/act2/drowned-wall-corner.glb` | ordinary |
| A2-2 | `act2-silted-stair` | `assets/art/map/geometry/act2/silted-stair.glb` | ordinary |
| A2-3 | `act2-library-arch` | `assets/art/map/geometry/act2/library-arch.glb` | ordinary |
| A2-4 | `act2-sunken-shelf-mass` | `assets/art/map/geometry/act2/sunken-shelf-mass.glb` | ordinary |
| A2-5 | `act2-lure-lantern-post` | `assets/art/map/geometry/act2/lure-lantern-post.glb` | ordinary |

Concepts land under `assets/art/map-concepts/` (outside `assets/art/map/`, so
`tools/check_map_assets.py` does not treat them as undeclared payload). Prefer
square PNG, Vigil-sized (~1254² RGB), named `act2-<short-id>.png`.

---

## 1. Visual language

Act II is the city's third refusal: **停在中途等** (`docs/story/03-acts.md`).
The people who lived here are 眾人, not walkers. They stopped on the pilgrimage
road and waited for a door whose true condition they never knew. Water is not
weather. Water is the material of that wait (`docs/story/00-truth.md` §8.6;
`docs/story/01-world.md` 火的物理):

- **水 = 不燒也不凝的意志 =「等」** — will that will not burn and will not
  freeze into memory, so it rises.
- **鏽** — waiting's slow etch on vessels.
- **假光** — light-shaped imitation that does not transmit will (deepmaw's
  lamp).
- **圖書館** — the records they left; a library of plans for the day the door
  opened, never a page about setting out.

The map kits are **silted masonry masses**, not an aquarium and not a stained-
glass combat plate. Combat `assets/art/stage/act2-*.png` may keep kelp, coral,
hanging cage-lanterns, and drowned spires; those plates are a different
surface. The kit bill forbids towers, bars, chains, kelp, coral, and painted
water (`docs/map-scene-asset-bill.md` A2-1…A2-5; terminus concept brief: no
chains, cages, grout, kelp, coral, or painted water).

**Read as:**

- Broad, fused, low-poly-friendly volumes that still carry **coursed drowned
  masonry** — ashlar that knows which way is up, rust blooming in the joints,
  silt crust where the wait has settled.
- Cold blue-grey / brine-teal stone, iron-oxide rust, pale silt wedges. Hue
  stays in that drowned-masonry family. Act night-cyan and flooded-corridor
  grading belong to `grades/act2-grade.png` and `MapRegions` (near 0.62 / far
  0.55 / corridor 0.50), not to a neon wash on the concept.
- Chunk scale: each kit is one reusable landmark the MultiMesh will place 2–5
  times with yaw and scale. It must stay readable as a **species** at
  `MapCameraRig` tilt −55° and zoom 20–28, not as a unique monument.

**Do not read as:**

- Clay-maquette grey (`map-concepts/shared-road-slab-a.jpg` and the Act I kit
  jpg set). Those pictures fed Smart Mesh, which has no texture stage.
- Stained-glass lead-came character construction (`docs/art-ledger.md` style
  block). Kits are buildings and furniture-masses, not leaded figures.
- The superseded horizon-Spire / half-submerged glass-tower band in
  `docs/map-concept-brief.md` §3. Climb, Spire, and stair-as-the-road are
  banned vocabulary (`docs/story/06-glossary.md`).
- The Act II combat mid-plate: gothic arch, trefoil, **two lanterns on
  chains**, kelp, coral, starfish. That silhouette is the combat boss gate,
  not a kit.

The shipped Act II terminus (`geometry/act2/terminus-flooded-threshold.glb`)
is the one monumental drowned arch: fused pendant masses, ruined wings, silt
slab. Wave-1 kits **support** that skyline; they do not clone it. A2-3 in
particular must be a **smaller, chunkier** flooded-library threshold.

---

## 2. Foreshadow bans

`docs/story/05-foreshadow-ledger.md` rule 2: nothing discloses before its
tier. Map kits sit on every run of Act II, so they are **L0–L1 scenery**. They
must not hand the player a later fact as architecture.

**Hard bans on every Act II kit concept and mesh:**

| Ban | Why |
|---|---|
| Six-pane rose, wheel window, circular rose disc, shard-count as architecture | L3: 彩窗成鏡, 隊伍現形. The Vigil already had to drop the six panes from its road face (`docs/art-ledger.md` vigil rows). At most a **narrow slit** or a **blind masonry bite**. |
| Queue of standing walkers / person-shaped stelae as the subject | L3 queue; Act IV monument-road. Shared `standing-monument` already covers the fallen-walker read. |
| Inverted hearth-amber key from the left / rose-gold dawn | Act IV lighting. Act II key is cold cyan, not swapped hearth. |
| Broken gold halo, obsidian star, watching-eye disc, faceted court pylons | Act III court. |
| Paired hanging lanterns, paired Act I lamps, lantern-arch | Act I motif; Act IV node 4 as a **mirror**, not Act II's whole-act set. A2-5 is **one** post. |
| Sealed east door, Gilded City gold, cloud-sea citadel | L3/L4 threshold and legend-drift city. |
| Spire, climb-tower, wrapping stair, stair-as-the-road | Glossary Tier A. A2-2 is a **local silted stair mass**, not the pilgrimage. |
| Readable text, glyphs, page-spreads with letters | Converter bakes letters into albedo; also leaks library copy the event already owns at L1. |
| Cage bars, chains, wick, open flame, hanging lamps | Islands at 1500 faces; copies the combat mid-plate; A2-1 / A2-3 / A2-5 silhouette jobs forbid them. |
| Kelp, coral, starfish, fish, bubbles, caustic water shafts, painted water sheets | Become geometry; aquarium read, not waiting-made-stone. |
| Drowned figures, walking dead, Leviathan, deepmaw angler as a creature | Combat cast, not kitbash. |
| Grout lace, brick-scale noise, thin crack lines | Silhouette noise; HD will try to sculpt them. |

The on-disk hero concept `map-concepts/act2-terminus-flooded-threshold.png`
still shows **chains and two hanging lanterns** (combat-plate leftover). The
accepted hero **mesh** fused those into pendant masses and dropped the chains
(`docs/reviews/294/act2-terminus/`). **Do not seed any kit prompt from that
PNG.** Do not "fix" a kit toward it.

---

## 3. Converter framing

Framing is for Tripo HD reconstruction, not for a pretty illustration.
Whatever the picture shows, HD will try to mesh. The Vigil prompt recorded
the same rule (`docs/art-ledger.md` `act1-vigil-hall.png`): a horizon or a
contact shadow comes back as geometry.

Every concept:

- **Square 1:1.**
- **Whole object in frame**, even margin, nothing cropped.
- **Centred.**
- **Three-quarter view from 35–40° above** (same camera as the Vigil
  conversion concept), object sitting as if on an invisible ground.
- **Flat mid-grey ground-free background** (`#8A8A8A` family, Vigil-like).
  No horizon, no sky, no fog band, no environment.
- **No cast shadow** on the ground or on the backdrop.
- **No depth of field**, no vignette, no rim light, no baked key-light
  slash, no ambient-occlusion puddle under the mass.
- One subject. No second prop, no scale figure, no watermark, no label.

If a first render grows a floor disc, a shadow blob, or a backdrop wall,
edit those out **before** Studio. Do not send them in.

---

## 4. TEXTURED concept language — not clay-maquette

Wave-1 Act II kits use the **HD Model** path. HD bakes **albedo from the
picture** and unwraps `TEXCOORD_0`. A clay-maquette jpg (the Act I / shared
kit set) gives HD nothing to bake except grey plastic.

Paint the surface that should exist in the GLB:

- Visible **coursed drowned masonry** or **silted stone** — large planar
  courses, rust-stained joints, silt crust, not faceted clay.
- Matte, low-contrast, even studio illumination from above-front. Colour is
  in the **material**, not in a theatrical light.
- Opaque lure-glow on A2-5 is **painted albedo** (a cold teal-glass bulge),
  not a light source, not fire, not bloom that HD will turn into a second
  shell.
- Ask HD for `POSITION + NORMAL + TEXCOORD_0` and a single baseColor. No
  normal map, no roughness, no metallic, no emissive plane.

**Do not write** "matte untextured clay-maquette surface", "untextured
stone", or "chunky clay kitbash" into these prompts. That language is the
Smart Mesh kit dialect and it is wrong here.

Vigil is the textured reference: coursed ashlar, slate courses, even cold
light, mid-grey void. Act II swaps dry grey ashlar for **drowned masonry +
silt + rust**, and it never gets a chimney or smoke.

---

## 5. Studio conversion

Generating product is **Tripo Studio** (`studio.tripo3d.ai`), paid Pro
credits. **Never the API.** Forbidden hosts: `openapi.tripo3d.ai`,
`platform.tripo3d.ai` generation, any `/v2/openapi` or `/v3/generation`
call. A Studio subscription does not pay an API task.

Driver: `tools/studio_image_to_glb.ts`. `--textured` stays on the **HD
Model** tab (`tab=high_detail`) and drives Geometry & Texture. Smart Mesh
has **no** texture stage; do not send these pictures there.

**Never click Generate Multi-Views.** It appears after upload and is not
this pipeline (`docs/solutions/tooling-decisions/the-textured-studio-path-is-the-hd-tab-not-the-script.md`).
Leave **AI Complete** off (invents unseen backsides). Privacy **Private**.

Credit order — do not skip:

```bash
# 1. dry-run — no Chrome, no credits
bun tools/studio_image_to_glb.ts --dry-run --textured --privacy private \
  --faces 1500 --topology triangle --texture-quality 1k --pbr off \
  --image assets/art/map-concepts/act2-drowned-wall-corner.png \
  --out /tmp/glassvow-studio-act2-drowned-wall-corner.glb

# 2. smoke-run — Chrome + login + form. Generate is not clicked.
bun tools/studio_image_to_glb.ts --smoke-run --textured --privacy private \
  --faces 1500 --topology triangle --texture-quality 1k --pbr off \
  --image assets/art/map-concepts/act2-drowned-wall-corner.png \
  --out /tmp/glassvow-studio-act2-drowned-wall-corner.glb

# 3. generate — spends the quoted HD credits
bun tools/studio_image_to_glb.ts --textured --privacy private \
  --faces 1500 --topology triangle --texture-quality 1k --pbr off \
  --image assets/art/map-concepts/act2-drowned-wall-corner.png \
  --out /tmp/glassvow-studio-act2-drowned-wall-corner.glb
```

Replace the image / out names per id. Re-export of an existing task is
`--task-id <id> --out <path>` (form unset; do not treat JSON `faces` as the
run that already happened).

### Ordinary (this wave)

```text
--textured --privacy private
--faces 1500 --topology triangle --texture-quality 1k --pbr off
```

Caps from the bill / manifest: **600–2,500 triangles**, hard **192 KiB**
(`bytes_max` 196608). Request 1,500 faces; do not confuse that with the
shipping triangle count. 1K albedo is the ordinary texture; 2K / 4K will
not fit 192 KiB (the Vigil's 2K JPEG alone was ~413 KiB inside a 768 KiB
hero). If a 1K export still blows `bytes_max`, stop and reopen the budget —
do not silently raise `--texture-quality`.

### Hero / threshold (not this wave; recorded so the flags cannot drift)

```text
--textured --privacy private
--faces 6000 --topology triangle --texture-quality 2k --pbr off
```

Caps: **8,000 triangles**, hard **768 KiB**. Act II terminus is already a
local untextured hero and is not regenerated by this file. The Vigil is the
textured threshold precedent (`components_max: 2` for hall + smoke only).

PBR stays **off**: the map's unshaded path samples one map;
metallic/roughness/normal are three more images inside the same byte cap
for nothing on screen.

---

## 6. Mesh contract

- **One connected volume.** Weld-by-position count is 1. The only shipping
  exception in this library is the Vigil (hall + chimney smoke). Act II kits
  have no smoke and no second island.
- **Y-up, metres, pivot on ground contact, min Y = 0** as exported.
- One mesh, one triangulated surface. Ordinary: `POSITION + NORMAL +
  TEXCOORD_0` plus the baked 1K baseColor.
- Closed or deliberately open **broad** forms. Missing crenel, broken tread,
  or shelf step is a **concave bite in the same solid**, not a chip sitting
  in the notch (the standing-monument island failure:
  `docs/art-ledger.md` shared-standing-monument fuse pass).
- No animation, skeleton, rig, morph, or extra node.
- Ground the mass. A hovering lantern-head, a floating book, or a stair that
  starts above Y=0 will scatter on the 20-placement lattice.

---

## 7. Disk state and reshape notes

`assets/art/map/geometry/act2/` currently holds only
`terminus-flooded-threshold.glb` (hero, #294, local parametric, 5,568 tris,
one watertight component). **Not a wave-1 dest. Do not reshape it into a
kit. Do not run Studio against its concept PNG for these five rows.**

| dest | on disk? | note |
|---|---|---|
| `geometry/act2/drowned-wall-corner.glb` | no | first concept, not a reshape |
| `geometry/act2/silted-stair.glb` | no | first concept, not a reshape |
| `geometry/act2/library-arch.glb` | no | first concept, not a reshape |
| `geometry/act2/sunken-shelf-mass.glb` | no | first concept, not a reshape |
| `geometry/act2/lure-lantern-post.glb` | no | first concept, not a reshape |

`assets/art/map-concepts/` has no `act2-drowned-wall-corner` /
`act2-silted-stair` / `act2-library-arch` / `act2-sunken-shelf-mass` /
`act2-lure-lantern-post` pictures. The only Act II concept on disk is the
hero PNG named above — combat-plate chains and paired hanging lamps. Ignore
it for kits.

If a later conversion lands and fails silhouette, islands, or 20-placement:
**reshape the concept picture** (fuse, thicken, turn chips into bites, drop
floor/shadow) and reconvert. Do not Blender-sculpt a shipping mesh as the
first move, and do not keep a 66-shell Smart Mesh leftover. Fuse language
that already worked on this tree: "one continuous volume — no gaps, no
separate chips, the missing piece is a concave bite in the same solid."

---

## 8. Shared prompt preamble

Paste this block in front of every per-id subject. It is the converter +
textured contract. Then paste the species subject. Then paste the shared
negative block.

**Preamble (every id):**

> Orthographic three-quarter view from 35–40° above of a single game-kitbash
> 3D prop. Entire object centred with even margin in a square 1:1 frame.
> Whole object visible, nothing cropped. Flat neutral mid-grey background
> (#8A8A8A), ground-free: no floor plane, no horizon, no environment, no
> cast shadow, no contact-shadow puddle, no depth of field, no vignette, no
> rim light. Even cold studio illumination from above-front, low-contrast,
> no baked AO, no theatrical key slash. TEXTURED concept, not a clay
> maquette: HD Model will bake albedo from this picture, so the surface must
> show drowned-masonry / silted-stone colour and courses — weathered
> blue-grey ashlar, rust-stained joints, pale silt crust — large planar
> faces, low-poly-friendly, matte. One connected solid volume sitting as if
> on invisible ground. Clean silhouette. Isolated subject, large in frame.
> Not a tile texture, not a landscape, not a diorama.

**Shared negatives (every id):**

> No towers, no spires, no climb, no wrapping stair, no stair-as-the-road.
> No cage bars, no chains, no hanging lamps, no paired Act I lanterns, no
> wick, no true flame, no fire, no ember. No kelp, no coral, no starfish, no
> fish, no bubbles, no painted water sheets, no caustic shafts, no water
> planes. No grout lace, no thin crack lines, no moss hair, no grass. No
> readable text, no letters, no glyphs, no page-spreads with writing. No
> rose window, no wheel window, no circular six-pane disc, no trefoil as a
> counted emblem, no broken halo, no obsidian star, no watching eye, no
> queue of standing figures, no person, no skeleton, no Leviathan. No
> inverted hearth-amber, no gold-city, no sealed east door. No second prop.
> No floor disc. No cast shadow. No chips detached from the mass.

---

## 9. Per-id prompt skeletons

### A2-1 `act2-drowned-wall-corner`

- **Silhouette job:** L-plan drowned city wall corner: two thick masonry
  walls meet at a right angle on a silt-bitten plinth, one missing upper
  crenel as a concave bite, rust-stained courses, `TEXCOORD_0` plus
  drowned-masonry albedo; no towers, bars, chains, kelp, or water sheets.
- **On disk:** dest absent. First picture.
- **Reshape:** none. If HD emits a second block in the crenel notch, fuse
  the bite into the wall (standing-monument lesson) and reconvert.

**Subject:**

> Subject: one L-plan drowned city wall corner. Two thick masonry walls meet
> at a right angle on a low silt-bitten plinth, the whole thing one fused
> mass. Walls are short and chunky, not a tower — about as tall as two or
> three broad ashlar courses plus a blunt merlon line. One upper crenel is
> missing as a concave bite in the same solid, not a separate chip. Rust
> stains run down the courses; pale silt crusts the plinth and the inner
> angle. Drowned-masonry albedo, blue-grey stone, iron-oxide joints.
> Distinct L-shaped silhouette, still a simple kitbash volume.

**Species extra negatives:** no keep, no turret, no flag, no arrow-slit
lace, no through-arch (that is A2-3), no lantern (that is A2-5).

---

### A2-2 `act2-silted-stair`

- **Silhouette job:** Broad descending stair that thickens and merges into
  a silt wedge at the bottom, treads readable as one fused mass not thin
  steps, silted-stone albedo; no railings, no climb-tower, no painted
  water.
- **On disk:** dest absent. First picture.
- **Reshape:** none. If treads come back as separate slabs, fuse them in
  the concept (one stepped wedge) before a second Studio run.

**Subject:**

> Subject: one broad descending stair mass. A short, wide flight of thick
> treads that thicken as they go down and melt into a silt wedge at the
> bottom — the stair and the silt are one fused volume, not a staircase
> planted in a puddle. Three to five chunky treads only, each a deep slab,
> readable as one stepped mass, not thin steps, not a ladder. No railings,
> no newel posts, no stringers as extra pieces. Silted-stone albedo:
> drowned grey-blue treads, pale silt crust dominating the lower wedge,
> rust seeps at the sides. Distinct descending-wedge silhouette, wider than
> it is tall, sitting on invisible ground.

**Species extra negatives:** no spiral, no switchback, no tower, no
doorway at the top, no water sheet at the bottom, no railings even as
painted lines.

---

### A2-3 `act2-library-arch`

- **Silhouette job:** Flooded-library threshold: low pointed through-arch
  with thick jambs and a fused book-course lintel, smaller and chunkier
  than the Act II terminus, drowned-masonry albedo; no readable text,
  cages, chains, or water sheets.
- **On disk:** dest absent. First picture.
- **Reshape:** none. Do not trace `terminus-flooded-threshold`. If the
  first picture comes back terminus-scaled (wide ruined wings, two hanging
  pendants), cut it down to a **low fat doorway** and reconvert.

**Subject:**

> Subject: one flooded-library threshold. A LOW pointed through-arch, thick
> jambs, squat — smaller and chunkier than a monumental city gate. The
> lintel is a fused book-course: a few drowned folio slabs melted into the
> masonry as one band of thick blocks, not a shelf of separate books, not
> readable spines. Both feet on invisible ground, the opening a simple
> pointed hole through one solid. Drowned-masonry albedo, rust in the
> joints, silt at the bases. Distinct small-arch silhouette, one connected
> volume.

**Species extra negatives:** no hanging pendants, no chains, no paired
lanterns, no trefoil in the spandrel, no rose, no side wings, no silt
runway as wide as the Act II terminus slab, no cages, no bars in the
opening, no letters on the books.

---

### A2-4 `act2-sunken-shelf-mass`

- **Silhouette job:** Stacked-slab sunken shelf mass: three fused drowned
  book-stack shelves melted into one squat stepped mound, wider than tall,
  no thin slats or gaps, silt-and-masonry albedo; no loose books, lanterns,
  or water sheets.
- **On disk:** dest absent. First picture.
- **Reshape:** none. If HD separates three boxes, fuse in the picture
  (cairn-mass lesson: "several chunky stones melted into one connected
  mound").

**Subject:**

> Subject: one stacked-slab sunken shelf mass. Three drowned book-stack
> shelves melted into one squat stepped mound, wider than it is tall,
> sitting on invisible ground. Each 'shelf' is a thick fused slab, no thin
> slats, no gaps, no separate books poking out. The stack reads as a
> terraced masonry heap that used to be a bookcase, not as furniture with
> openings. Silt-and-masonry albedo: blue-grey stone faces, pale silt
> pooling on the steps, rust at the risers. Distinct stepped-mound
> silhouette, one connected volume.

**Species extra negatives:** no loose books, no lantern, no candle, no
ladder, no cage, no readable titles, no through-gaps that become stripes
when yawed, no water around the base.

---

### A2-5 `act2-lure-lantern-post`

- **Silhouette job:** False-light landmark: one thick upright post with a
  blunt globular lantern head fused on top, opaque lure-glow as albedo not
  true flame, no cage bars, chains, wick, or Act I paired lamps.
- **On disk:** dest absent. First picture.
- **Reshape:** none. If the globe detaches, fuse head to post in the
  picture (one lollipop volume). If HD invents a second lamp, that is an
  Act I paired-lamp leak — kill it in the concept, do not keep the mesh.

**Subject:**

> Subject: one false-light landmark. A single thick upright masonry-and-iron
> post with a blunt globular lantern head fused on top — one lollipop, not
> a hanging lamp, not a pair. The head is a closed opaque glass bulge, cold
> teal lure-glow painted as albedo, not a flame, not a wick, not an
> emissive flare. No cage, no bars, no chain, no hook, no cross-arm. Post
> slightly wider at the silted foot, sitting on invisible ground. Drowned
> masonry on the post, rust streaks, silt at the base; the globe a smooth
> brine-teal glass mass. Distinct single-post silhouette, one connected
> volume.

**Species extra negatives:** no second lamp, no arch, no hanging pair, no
Act I lantern language, no angler-fish, no creature, no open flame, no
bars.

---

## 10. Twenty-placement failure modes

Review evidence is a **lit 5×4 clay grid**, seed 292, yaw and scale jitter,
zoom stop 20, tilt −55°
(`docs/solutions/tooling-decisions/a-signable-20-placement-review-is-a-lit-clay-grid.md`).
The scalar GPU mask (`silhouette_noise` ≤ 0.04 at zoom 28, eight yaws) can
pass while the grid still fails. Owner signature for one module is **"same
item, different size and angle"** — not twenty different objects, and not a
recognisable contour dominating the frame.

Fail the wave-1 kit if any of these fire:

1. **Repeated contour dominates** the 5×4 even after yaw/scale — the
   species is a logo, not a kit (bill: "a recognisable repeated contour
   dominates the frame even when the scalar gate passes").
2. **Floor island.** Horizon, ground plane, or contact shadow in the
   concept came back as a disc under every instance.
3. **Cast-shadow mesh.** A grey blob beside the mass, twenty times.
4. **More than one connected component** after position-weld (chips in the
   crenel, loose books, globe off the post, railing posts). Vigil hall+smoke
   is not a license here.
5. **Thin bars / chains / railings / kelp fronds** that either vanish at
   1,500 faces or survive as a barcode of identical stripes across the
   grid.
6. **A2-3 clones the terminus.** Monumental wings, two hanging pendants,
   wide silt runway — twenty small copies of
   `docs/reviews/294/act2-terminus/twenty-placements.png`.
7. **A2-5 yaws into Act I paired lamps** or a hanging lantern-arch. One
   post must still read as one post at 45° steps.
8. **A2-1 reads as a climb-tower / keep / spire** at production tilt.
   L-plan wall, not a vertical building as the subject.
9. **A2-2 reads as the road** (banned stair-as-the-road) or as a
   climb-tower with a wrapping flight.
10. **A2-4 slat-gaps** become twenty striped furniture blocks; thin shelves
    fail identity and repetition at once.
11. **Painted water sheet** under the stair or arch becomes a translucent
    plane instanced twenty times.
12. **Kelp / coral silhouettes** wave as the same frond on every seat
    (combat-plate leak).
13. **Readable text or spine-letters** brand every library-arch / shelf
    copy.
14. **Cage, trefoil-as-count, or six-pane rose** appears in the opening of
    A2-3 or the wall of A2-1 — L3 architecture on an L0 kit.
15. **True flame / wick / open cage** on A2-5; HD sculpted a fireball that
    twenty copies turn into a field of torches.
16. **Too-unique landmark** (one unmistakable bite + one globe + one L) so
    the grid screams "the same prop stamped" rather than "same family,
    different size and angle". Soften only by **fusing and thickening**,
    not by adding a second species into one GLB.
17. **Too-generic brick** so A2-1…A2-4 collapse into one silted box; the
    five-module floor exists to pass map-level repetition, and a brick
    wastes a row.
18. **Not grounded.** min Y ≠ 0, or a hovering head, so lattice instances
    float at mixed heights and the clay grid looks broken rather than
    reviewed.
19. **Hidden internal islands / inverted shells / non-manifold pockets**
    that the weld count still reports as extra components, or that explode
    the triangle cap without changing the outer silhouette.
20. **Hero-scale mass.** Terminus-sized arches or wall-corners fill the
    review frame as a solid hedge; ordinary kits must stay kit-scale so
    2–5 MultiMesh uses can share a seat with the shared slabs.

A file existing under `docs/reviews/` is not a pass. `tools/land_map_glb.py`
only asserts the PNG exists; `fol2` signs the clay grid. This prompt file
does not land GLBs.

---

## Stop conditions

- Do not generate images or meshes from this document.
- Do not call the Tripo API.
- Do not click Generate Multi-Views.
- Do not convert `map-concepts/act2-terminus-flooded-threshold.png` as a kit.
- Do not touch `domain/`.
- Do not write new citations into the detached web reference.
- If 1K HD albedo cannot meet 192 KiB, stop and reopen the payload bill;
  do not bump to 2K.
)
