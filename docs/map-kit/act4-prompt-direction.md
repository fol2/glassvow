# Act IV kit prompt direction — 鏡中歸途 / The Mirrored Road

Status: **prompt direction only**. This file does not order images or meshes.
Wave-1 slots: **none** (`[]`). Every Act IV id below is specified for a later
wave; an empty wave-1 list is not a licence to generate.

Act: `act4` (manifest `act: 3`). Region name locked: 鏡中歸途 / The Mirrored
Road (`docs/story/03-acts.md`, `docs/story/06-glossary.md`). The map kit is
one whole-act set — five ordinary modules plus one terminus — not a per-node
biome pack. Per-node look stays on the scene plates.

Authoritative dests: `assets/art/map/map-assets.json`. Motif source:
`docs/map-scene-asset-bill.md` A4-1…A4-5 and A4-H. Palette owner:
`presentation/map/map_regions.gd` row 3 (dawn arc). Grade already shipped:
`assets/art/map/grades/act4-grade.png` (umber-to-rose dawn, reversed
hearth-light road).

Do not generate from this file. Do not call the Tripo API. Do not click
**Generate Multi-Views**.

---

## 1. Visual language

Act IV is not a new biome. It is the same road walked back from the far side
of the threshold (`docs/story/01-world.md`: 窗門同體; 倒轉的爐光 is geography,
not metaphor). The kit must read as **standing monuments queued into a road**,
under **inverted hearth-light**: warmth arrives from ahead, the near field is
colder.

Carry these, and only these, as whole-act kit grammar:

- **Pale road.** Ground grain is `act4-ground-pale-road` — a reversed paving,
  paler than Acts I–III, not ash-loam, not silt, not obsidian dust.
- **Inverted-hearth stone.** Prop grain is
  `act4-prop-inverted-hearth-stone` — coursed masonry that could be a
  fireplace mouth scaled down, not charred bark, not drowned masonry, not
  obsidian facet.
- **Stelae as a road.** Tall weathered standing masses, slightly wider at the
  base, blunt tops, no carved faces. They stand *aside* (the middle of the
  road is kept clear). They are the Queue as stone, not walkers.
- **Small cold teal glass insets** on stelae are allowed (combat plates use
  them). They are not lamps, not paired lanterns, not hanging cages.
- **Warm amber on far faces, cold slate-violet / umber on near faces** —
  painted into albedo as a modest value shift, never as a cast shadow on the
  ground. Grade + ramp own the dawn; the concept must not be a sunset mural.
- **Rose-threshold as the hero only.** A thick wheel with through-apertures,
  flanked by faceted pylons on one continuous plinth. Ordinary kits do not
  each carry a rose window.
- **Reverse hearth-arch as a kit.** A fireplace-mouth opening at module
  scale, inverted (the bright side is the far side of the opening). It must
  not clone the terminus wheel and must not clone Act I's lantern-arch.

Palette the picture may *hint*, never *perform*:

| Token | Hex / value | Owner |
|---|---|---|
| Sky | `#16120c` | `MapRegions` / `SkyField` row 3 |
| Fog | `#241e14` | same |
| Dawn motes | `#ffc08a` | particles |
| Glow | `#f0a878` | glow |
| Accent | `#e8b890` | accent |
| Band shade | `(0.22, 0.19, 0.12)` residual umber | ramp |
| Band key | `(0.96, 0.82, 0.70)` rose-gold | ramp |
| Grade hues | near `0.08`, far `0.12`, corridor `0.10` | painted grade |
| Weather | `dawn` (rose-gold cinders rise) | veil |

Composition the converter will never see, and must not be baked into a
module: a vanishing-point road, a cloud-sea city, a seated Keeper, a walking
queue of hooded glass figures. Those belong to scene plates
(`act4-node1`…`act4-node5`, `finale-swap`), not to kitbash props.

Shared kit still sits in the Act IV scene (three shared + five act modules,
24–32 non-hero instances, each ordinary module used 2–5 times). Act IV
silhouettes must be **distinct** from `shared-road-slab-a`,
`shared-road-slab-b`, and `shared-standing-monument` at production tilt.

---

## 2. Foreshadow bans

Act IV play is L4 (`docs/story/01-world.md`: 機制細節全開). That does not
licence every L4 picture onto a reusable prop. Ledger rule 2 still applies
to anything this kit could be *seen with* before its tier, and the map
composition mixes Act IV modules with shared kit that also appears in Acts
I–III.

**Never put these on an Act IV concept or mesh:**

1. **Walkers, hoods, faces, hands, chests-with-lights.** The Queue never
   blocks (`docs/story/03-acts.md`; ledger row 355). Monuments stand; they
   do not walk. Counterfactual selves are combat enemies, not map props.
2. **The seated Keeper / Eternal Keeper, the seated Sovereign, a crown, a
   scepter, a broken gold halo.** Those are boss and III-prime language.
3. **A smiling figure in glass** (`mirror.png` is L0 art with meaning
   withheld; do not illustrate the smile on a slab).
4. **Six-pane shard counter as HUD, numbered panes, saint-filled lobes.**
   The rose belongs to the terminus and to node-1 plates; if the hero shows
   tracery it is architecture, not a quest tracker. Ordinary kits get **no
   rose**.
5. **Paired lanterns, hanging lanterns, lantern-arches.** Those are Act I
   (`act1-mid`) and Act IV *node 4* as a mirror. The first combat-plate
   miss was exactly this (`docs/art-ledger.md` act4-mid B). Standing stones
   are not lamps.
6. **Act II water, silt as a flood, chains, cages, kelp, a lure-lantern
   post.** False-light is node 3, and even there the kit must not grow
   bars.
7. **Act III obsidian blades, broken-halo rings, star-eyes, court plinths
   as the whole-act mass.** Node 2 may *rhyme* with III; the kit library
   must not *be* III.
8. **Ashen woods as the whole-act silhouette** — forked trunks, hanging
   lanterns, paired lamps. Node 4 is I′; the kit is not.
9. **A Gilded City skyline, gold spires, cloud-sea towers as a module.**
   金城 is the Vigil's true face, not a new place (`docs/story/01-world.md`
   #259 Q3; glossary). Do not invent a city kit.
10. **The west-face six-pane rose on a hall gable.** That leak is why the
    Vigil concept bans rose/wheel/circular windows (`docs/art-ledger.md`
    `act1-vigil-hall.png`). Act IV's hero is the *inner* face after
    stepping through, which is allowed **on the terminus only**.
11. **New canon symbols** on `act4-pale-fractured-mass` (bill: "neutral
    broad mass; no new canon symbol"). No eighth omen, no shard glyph, no
    eye, no crown, no numbered mark.
12. **Letters, runes, UI, watermarks, climb/spire/summit/above-as-a-place
    architecture.** Vertical pilgrimage vocabulary is banned
    (`docs/story/06-glossary.md` Tier A). A needle tower is a fail even as
    a "distant" silhouette.
13. **Carved faces or names on stelae.** Shared monument contract: fallen-
    walker *read*, no carving noise.
14. **The Vigil hall, its chimney, or its smoke** cloned as an Act IV
    module. The west bookend is one threshold for the whole map
    (`kind: threshold`, Act I only). Act IV's end is the hearth *from the
    other side*, carried by the reverse-hearth-arch + terminus, not by a
    second hall.

Surface-readable and post-reveal-true at once, or it does not ship.

---

## 3. Converter framing

Framing is for **Tripo Studio HD Model**, not for a picture that looks like
a still from the game. The converter reconstructs what it can see. A
horizon, a contact shadow, or a ground plane comes back as geometry.

Every concept, including a reshape of a dest already on disk:

- **Square 1:1.**
- **Whole object** in frame, even margin, nothing cropped.
- **Centred.**
- **Flat mid-grey ground-free background** (`#8A8A8A`), no environment.
- **No horizon.**
- **No cast shadow** on the ground (and no ground).
- Three-quarter view from about 35–40° above, orthographic-leaning. One
  object. Not a tile texture, not a landscape, not a vanishing-point road.

The Vigil concept (`assets/art/map-concepts/act1-vigil-hall.png`) is the
framing exemplar: square, centred hall, mid-grey void, no floor island.
The Act IV terminus concept on disk (`act4-terminus-rose-threshold.png`)
**fails this framing** — dark environment, implied ground. See §7 reshape.

---

## 4. TEXTURED concept language — not clay-maquette

HD Model **bakes albedo from the picture**. Clay-maquette language
(matte untextured grey, "game-kitbash mass") is the Smart Mesh input used
for shared and Act I rocks. It is the wrong input for this path: a grey
clay render bakes grey clay.

Paint the object as **the thing it is**:

- Coursed ashlar, slate, pale paving, inverted-hearth stone, small teal
  glass insets, amber glass only where an aperture is glass rather than
  air.
- Low-contrast, de-lit, even studio illumination from above-front. No
  baked AO, no rim light, no key-light streak, no dusk sky.
- Readable planar masses, low-poly-friendly, few large colour fields —
  not lacework, not a stained-glass mural wrapped onto a boulder.
- Colour stays in the umber / pale-road / rose-gold / cold-teal family,
  desaturated. Hue on the map still belongs to the ramp and the grade;
  a concept that is already a full dawn painting will stamp twenty times.

Exemplar for *material language*: `assets/art/map-concepts/act1-vigil-hall.png`
(coursed grey ashlar, slate courses, corbel, even light). Exemplar **not**
to copy for Act IV kits: `assets/art/map-concepts/shared-road-slab-a.jpg`
and the Act I clay row (those are Smart Mesh). The on-disk Act IV terminus
concept is clay on a dark void — reshape it before any HD convert (§7).

Do not write "matte untextured clay-maquette surface" into an Act IV
prompt.

---

## 5. Studio conversion

Generating product is **Tripo Studio** (`studio.tripo3d.ai`), paid Pro
credits, image-to-3D on the **HD Model** tab. The driver is
`tools/studio_image_to_glb.ts`. Smart Mesh has no texture stage.

```bash
# Always --textured --privacy private. Never Generate Multi-Views. Never the API.

# Credit order. Do not skip.
bun tools/studio_image_to_glb.ts --dry-run --textured --privacy private \
  --image assets/art/map-concepts/<id>.png \
  --out /tmp/glassvow-studio-<id>.glb
bun tools/studio_image_to_glb.ts --smoke-run --textured --privacy private \
  --image assets/art/map-concepts/<id>.png \
  --out /tmp/glassvow-studio-<id>.glb
# Generate only after smoke prints quoted_credits and would_spend_credits: false
# was true on the smoke step.

# Ordinary kit (A4-1…A4-5): 192 KiB / 600–2500 triangles.
bun tools/studio_image_to_glb.ts --textured --privacy private \
  --faces 1500 --topology triangle --texture-quality 1k --pbr off \
  --image assets/art/map-concepts/<id>.png \
  --out /tmp/glassvow-studio-<id>.glb

# Hero / threshold (A4-H terminus; Vigil is Act I and is not this act):
# 768 KiB / ≤8000 triangles.
bun tools/studio_image_to_glb.ts --textured --privacy private \
  --faces 6000 --texture-quality 2k --pbr off \
  --image assets/art/map-concepts/act4-terminus-rose-threshold.png \
  --out /tmp/glassvow-studio-act4-terminus.glb
```

| Flag | Ordinary | Hero / threshold |
|---|---|---|
| `--textured` | required (HD Model) | required |
| `--privacy` | `private` | `private` |
| `--faces` | `1500` | `6000` |
| `--topology` | `triangle` | `triangle` (HD default) |
| `--texture-quality` | `1k` | `2k` |
| `--pbr` | `off` | `off` |
| `--ultra-mesh` | on (HD default) | on |
| `--ai-complete` | **off** (invents unseen backsides) | **off** |
| Byte cap | **192 KiB** (`bytes_max` 196608) | **768 KiB** (`bytes_max` 786432) |
| Triangle cap | 600–2500 (request 1500) | ≤8000 (request 6000) |

**Never Generate Multi-Views** (the button that appears after upload).
**Never the API** — no `openapi.tripo3d.ai`, no `platform.tripo3d.ai`, no
`/v2/openapi`, no `/v3/generation`. A Studio subscription does not pay
the API.

1k / PBR-off is the ordinary byte gate: a 2k JPEG will not fit 192 KiB
next to the mesh (the Vigil's 2k albedo alone was ~413 KiB inside a 604
KiB hero). 4K is wired on the script and blows even the hero cap. PBR
metallic/roughness/normal are three more images the unshaded shaders do
not sample.

`--task-id` re-export does not set the form; do not report its JSON
`faces` as the task that ran.

Land with `tools/land_map_glb.py` after a readable 20-placement PNG
exists. Provenance `source` is `Studio` when Studio produced the file.
`api_forbidden` stays true.

---

## 6. Topology and orientation

- **One connected volume.** Default `components_max` is 1. Hidden
  internals and loose chips fail `inspect_glb`.
- **The only exception in this library is the Vigil** (`act1-vigil-hall`,
  hall + chimney smoke, `components_max: 2`). Act IV has **no** threshold
  hall and **no** smoke. Every Act IV dest is one body.
- **Y-up**, metres.
- **Ground contact at Y = 0** (accessor min Y ≈ 0; gate allows
  −0.001…0.05). Pivot on the ground, not at the mesh centroid.
- One mesh, one triangulated surface, `POSITION` + `NORMAL` required.
  `TEXCOORD_0` is expected on this textured path. Banned:
  `TEXCOORD_1`, `TANGENT`, `JOINTS_0`, `WEIGHTS_0`, animation, skeleton.
- Closed or deliberately open **broad** forms only. Through-apertures on
  the arch / terminus wheel must be holes in **one** solid, not a second
  disk, not a floor under the hole.
- `standing-pair` is two stelae **fused on one plinth** — a gap you can
  see is not two islands.
- Do not emit a ground plane, a horizon wall, or a contact-shadow slab.

---

## 7. Per-id prompt skeletons

Wave-1: **no ids**. Shared prefix and suffix wrap every subject. Paste as
one block.

### Shared prefix (every id)

> Square 1:1 game-asset concept for image-to-3D. Orthographic-leaning
> three-quarter view from 35–40 degrees above. Entire object centred with
> even margin; whole object in frame, nothing cropped. TEXTURED painted
> surfaces — coursed pale stone and inverted-hearth masonry with visible
> courses, not clay, not a maquette, not untextured grey. Flat even studio
> lighting from above-front; no baked AO, no rim light, no key-light streak,
> no dusk sky. Isolated subject, large in frame. Solid flat mid-grey
> background (#8A8A8A), no ground plane, no horizon, no environment, no
> cast shadow. Clean chunky low-poly-friendly silhouette, few large colour
> masses.

### Shared suffix (every id)

> One connected volume sitting on an implied ground at the bottom of the
> object, not a floor you can see. No second block, no chips, no internal
> islands. No characters, no hoods, no faces, no hands, no text, no letters,
> no runes, no UI, no watermark. No paired lanterns, no hanging lamps, no
> chains, no cages, no water, no kelp, no ashen woods, no forked trunks, no
> broken halo, no star-eye, no crown, no scepter, no gold city, no spires,
> no needle towers, no climb. Not a tile texture, not a landscape, not a
> vanishing-point road.

### Dest inventory (this checkout)

| id | Bill | Manifest path | On disk now |
|---|---|---|---|
| `act4-mirror-road-slab` | A4-1 reversed-road language | `geometry/act4/mirror-road-slab.glb` | **no** |
| `act4-standing-pair` | A4-2 queue of standing monuments | `geometry/act4/standing-pair.glb` | **no** |
| `act4-reverse-hearth-arch` | A4-3 inverted hearth-light threshold | `geometry/act4/reverse-hearth-arch.glb` | **no** |
| `act4-threshold-buttress` | A4-4 door/threshold support mass | `geometry/act4/threshold-buttress.glb` | **no** |
| `act4-pale-fractured-mass` | A4-5 neutral broad mass; no new canon symbol | `geometry/act4/pale-fractured-mass.glb` | **no** |
| `act4-terminus` | A4-H final threshold; path stays neutral | `geometry/act4/terminus-threshold.glb` | **yes** (parametric, untextured) |

Concept on disk: `assets/art/map-concepts/act4-terminus-rose-threshold.png`
(clay, dark void). No Act IV ordinary concepts on disk. No Act IV vigil.

---

### `act4-mirror-road-slab` — ordinary, 1k / 1500 / 192 KiB

Silhouette job: reversed-road language. Must not be a recolour of
`shared-road-slab-a` or a step-clone of `shared-road-slab-b`.

**Reshape:** dest absent. New concept.

**Subject:**

> A single broad low PALE ROAD SLAB, a short thick paving block of inverted-
> hearth stone. The top is a pale smooth road face; the broken corner is the
> BACK-LEFT, the reverse of a normal kerb, as if the slab had been turned
> around on the same road. A shallow raised lip runs the NEAR edge, not the
> far. Slightly thicker at the far side so the top plane tilts a few degrees
> toward the camera — the road running back. Visible pale-stone courses, no
> carved ornament, no thin crack lines, no grass, no moss. One connected
> rectangular mass, wider than it is tall.

---

### `act4-standing-pair` — ordinary, 1k / 1500 / 192 KiB

Silhouette job: a queue-of-two. Distinct from `shared-standing-monument`
(one stele) by reading as **two uprights on one plinth** at every yaw.

**Reshape:** dest absent. New concept. The pair is the failure-prone id:
HD will emit two islands unless the picture fuses them.

**Subject:**

> A single kitbash prop: TWO standing monuments on ONE shared low plinth,
> fused into one volume. Two broad upright weathered stelae, person-height,
> slightly wider at the base, blunt rounded tops, a hand-width gap between
> them like a path kept clear. The plinth is continuous under both; the gap
> does not cut through to the background at ground level — stone fills the
> bottom of the gap. Small cold teal glass insets on the inner faces, not
> lamps. Pale inverted-hearth stone, no carved faces, no letters, no arms,
> no third stone. One connected pair, tall silhouette with a notch, still a
> simple mass.

---

### `act4-reverse-hearth-arch` — ordinary, 1k / 1500 / 192 KiB

Silhouette job: inverted hearth-light threshold. Fireplace mouth at module
scale. Must not clone the terminus rose-wheel and must not clone Act I
`fallen-bough-arch` or the rejected combat lantern-arch.

**Reshape:** dest absent. New concept. Through-opening must stay a hole in
one solid (both feet on the implied ground).

**Subject:**

> A single reverse-hearth arch: a thick low stone fireplace-mouth opening,
> inverted. The arch is a squat rounded hearth opening, not a pointed gothic
> door, not a circular rose window, not a tree. Both jambs sit on the same
> continuous hearth-slab; the opening is empty air, not a filled panel, not
> a second disc. The FAR inner face of the opening is painted warmer amber
> stone; the NEAR lips are colder umber. Keystone mass sits slightly LOW in
> the opening, as if the hearth had been turned around. Chunky low-poly
> masonry courses. One connected threshold-shaped mass. No grate, no fire
> logs, no chimney, no smoke, no hanging lantern.

---

### `act4-threshold-buttress` — ordinary, 1k / 1500 / 192 KiB

Silhouette job: door/threshold support mass. A flying-buttress chunk without
a hall attached. Must not be a Vigil flank-buttress clone (that hall is Act
I, west bookend).

**Reshape:** dest absent. New concept.

**Subject:**

> A single threshold buttress: one heavy masonry support mass, a short
> diagonal brace fused to a vertical pier on a wide foot. The pier is the
> tall side; the brace steps down in two chunky courses toward the low
> side, like a door-jamb's support with the door omitted. Pale inverted-
> hearth stone with visible courses and a simple plinth. No arch attached,
> no hall wall, no window, no statue niche, no second pier. One connected
> wedge-and-pier silhouette, grounded, wider at the foot.

---

### `act4-pale-fractured-mass` — ordinary, 1k / 1500 / 192 KiB

Silhouette job: neutral broad mass. Dab / boulder family. **No new canon
symbol.** Must not be Act I's cairn, Act III's star-eye, or a broken halo
lying down.

**Reshape:** dest absent. New concept.

**Subject:**

> A single pale fractured mass: one compact squat boulder of fused pale
> stone, wider than it is tall, sitting as one mound. A few large planar
> breaks, as if the stone had split and melted shut — concave bites, not
> separate rocks, not stacked gaps. No carved symbol, no eye, no star, no
> ring, no rune, no shard glyph, no crown. Pale road-stone colour, faint
> umber in the recesses, no grass, no moss, no thin crack lace. One
> connected heap. Distinct low mound silhouette, still a simple kitbash
> mass.

---

### `act4-terminus` — hero, 2k / 6000 / 768 KiB / ≤8000 tris

Silhouette job: the signed rose-threshold. One authored placement per act,
not a kit instance.

**On disk:**

- Mesh: `assets/art/map/geometry/act4/terminus-threshold.glb` —
  local parametric + manifold union, **untextured** POSITION+NORMAL,
  5,460 triangles, 156,660 bytes, one watertight component, Y-up, min Y
  0. fol2 accepted the hero on 2026-08-21 (`docs/reviews/294/act4-terminus/`).
  Provenance sha256
  `137fdfe77386ff02b8c825ec1b2d9fb14315f2c09409dd30b629d1e6570c0d9f`.
- Concept: `assets/art/map-concepts/act4-terminus-rose-threshold.png` —
  clay-maquette, **dark** environment, six-petal rose with hub, flanking
  pylons, stepped plinth. fol2 accepted the concept the same day. sha256
  `44b5ee7dec5d6ef10c732a03190923ddbe6df1d26b5f4148e3a6146e7b9af00d`.

The signed **mesh** is a **thick four-aperture wheel**, not the concept's
six petals. That reduction is the shipping contour. A six-petal HD remake
is a different 20-placement and needs a new sign-off.

**Do not replace the signed untextured hero** unless a textured remake is
explicitly ordered. This file does not order it.

**Reshape notes (only if a textured HD remake is ordered):**

1. **Keep the signed silhouette:** thick four-aperture wheel (through-
   holes, not filled petals), two faceted flanking pylons, broad stepped
   threshold courses, **one continuous plinth**. Do not restore the
   concept's six-petal flower.
2. **Reframe the picture:** square 1:1, whole object centred, **flat
   mid-grey `#8A8A8A` ground-free background**. Drop the dark void, the
   implied floor, and any contact shadow (the isolate pass used on
   `shared-standing-monument`).
3. **Fuse:** pylons + wheel + plinth are one volume. No gap at the pylon
   feet. No second disc behind the wheel. Apertures are holes in the
   wheel, not a backboard.
4. **Repaint clay → textured:** coursed inverted-hearth stone on pylons
   and plinth; pale-road steps; wheel rim heavy masonry; the four
   apertures either empty (preferred, matches the signed mesh) or a
   single amber glass pane per aperture **without saints, numbers, or
   six-lobe tracery**. Even studio light; no dusk; no gold city behind.
5. **Do not add** characters, smoke, a chimney, a hall, a fifth/sixth
   aperture, a pointed gothic gate around the wheel, hanging lamps, or
   AI-Complete backsides.
6. **Budget:** `--faces 6000 --texture-quality 2k --pbr off`; stay inside
   768 KiB and 8000 triangles. The Vigil at 2k / 5615 tris / 604 KiB is
   the byte proof, not a silhouette to copy.
7. New provenance record if Studio produces the file (`source: Studio`).
   The parametric sha256 must not be quietly overwritten.

**Subject (textured remake only):**

> Monumental rose threshold: a thick FOUR-aperture stone wheel (cross of
> four through-openings around a heavy hub), tall faceted flanking pylons
> left and right, broad stepped threshold courses, one continuous plinth
> under wheel and pylons. Painted coursed inverted-hearth masonry, pale
> road steps, even studio light. No six-petal flower, no saints in the
> glass, no characters, no foliage, no loose props, no hall, no chimney.
> One connected heroic mass, grounded.

---

## 8. Twenty 20-placement failure modes

Review evidence is a **lit 5×4 clay grid** at seed 292, yaw and scale
jitter, production tilt −55°, review zoom 20, 1280×720
(`docs/solutions/tooling-decisions/a-signable-20-placement-review-is-a-lit-clay-grid.md`).
Scalar masks are a different job (eight yaws, zoom 28, `silhouette_noise`
≤ 0.04). A noise pass does not close this list. Terminus is **one**
authored placement; its 20-copy sheet is identity/contour evidence, not
a licence to instance it on the map.

Fail the review if any of these dominate:

1. **Stamped contour.** One recognisable outline repeats so hard the
   frame reads as wallpaper even though scales and yaws differ.
2. **Unreadable capture.** White unshaded scatter, tiny chips on a huge
   ground, or a mask upscaled and called review — owner will not sign.
3. **Identity collapse.** Twenty *different* objects. One module must
   still read as the same item at different size and angle.
4. **Ground-plane island.** A floor disk under every copy (horizon or
   contact shadow from the concept, reconstructed as mesh).
5. **Cast-shadow slab.** A second thin volume stuck to the foot of each
   instance.
6. **Split pair.** `standing-pair` comes apart into two islands; the grid
   fills with twice the uprights, half of them hovering.
7. **Filled apertures.** Reverse-hearth-arch or terminus wheel bakes
   solid; copies read as coins / loaves, not thresholds.
8. **Backboard behind a hole.** A second wall closing the arch, so
   rotations flash a slab that the front view hid.
9. **Hero-as-kit.** Terminus contour used as if it were an ordinary
   module; twenty rose-wheels dominate any composition.
10. **Shared-kit clone.** Mirror-road-slab indistinguishable from
    `shared-road-slab-a/b`, or standing-pair indistinguishable from
    `shared-standing-monument`, at tilt −55°.
11. **Lantern-arch leak.** Reverse-hearth-arch reads as Act I paired-lamp
    gateway (the combat-plate miss).
12. **Act III leak.** Pale-fractured-mass or any ordinary module reads as
    star-eye, broken halo, or obsidian blade when twenty are present.
13. **Figure leak.** Hoods, faces, or walker-silhouettes appear once
    yawed; twenty copies become a crowd (the Queue must not block).
14. **Mural stamp.** Unique painted illustration (sunset, city, six-pane
    saints) tiled across the grid instead of material grain.
15. **Silhouette noise.** Thin crack lace, twigs, or tracery that fails
    the 0.04 mask gate on any of the eight production yaws.
16. **Centroid pivot.** Copies hover or bury because min Y is not ~0;
    the lattice no longer sits on one ground.
17. **Chip hail.** Detached shoulder-notch chips (the standing-monument
    island bug) sprinkled through the grid.
18. **AI-Complete backside.** Invented far side disagrees with the near
    side; 180° yaw looks like a different prop.
19. **Scale-lock.** Jitter too small, or uniformly huge, so the grid
    cannot answer "same item, different size".
20. **Byte/topology cheat that still looks wrong:** Quad explosion,
    4K albedo, or PBR extras stripped at land-time leaving UV seams as
    contour — twenty copies flicker a chart-cut the clay grid was meant
    to catch.

Pass language for one ordinary module, when the owner signs: **"same
item, different size and angle."** Map-level repetition still needs all
five act modules plus shared kit in the real Act IV bind; twenty copies
of one signed slab cannot test that.
