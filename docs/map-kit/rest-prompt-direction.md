# Rest kit — textured prompt direction

Status: **direction for the shared kit, four termini, and the Vigil**  
Act key: `rest`  
Wave-1 JSON: **empty** — this file still covers the billed eight. All eight dests are already on disk; this run **reshapes** them as Studio HD textured meshes. Do not add a 29th file. Keep billed dest paths.

Scope: concept language and Studio flags only. Do not generate images or meshes from this document.

| asset_id | billed dest | role | on disk now |
|---|---|---|---|
| `shared-road-slab-a` | `assets/art/map/geometry/shared/road-slab-a.glb` | ordinary | Smart Mesh, untextured clay |
| `shared-road-slab-b` | `assets/art/map/geometry/shared/road-slab-b.glb` | ordinary | Smart Mesh, untextured clay; two islands welded by hand |
| `shared-standing-monument` | `assets/art/map/geometry/shared/standing-monument.glb` | ordinary | Smart Mesh, untextured clay; fuse + isolate passes |
| `act1-terminus` | `assets/art/map/geometry/act1/terminus-amber-window-tower.glb` | hero | local parametric, untextured |
| `act2-terminus` | `assets/art/map/geometry/act2/terminus-flooded-threshold.glb` | hero | local parametric, untextured |
| `act3-terminus` | `assets/art/map/geometry/act3/terminus-broken-ring-arch.glb` | hero | local parametric, untextured |
| `act4-terminus` | `assets/art/map/geometry/act4/terminus-threshold.glb` | hero | local parametric, untextured |
| `act1-vigil` | `assets/art/map/geometry/act1/vigil-hall.glb` | threshold | Studio HD textured; hall + smoke |

Manifest rows and caps live in `assets/art/map/map-assets.json`. Ordinary: `triangle_max` 2500, `bytes_max` 196608. Hero / threshold: `triangle_max` 8000, `bytes_max` 786432. Vigil declares `components_max` 2 and `tex_mean` 0.252.

---

## 1. Visual language

The map is a horizontal pilgrimage, west → east, seen at `MapCameraRig.TILT_DEGREES` −55°. Shared modules sit in every act. Termini sit once, just past the boss, at world x = 40, scale 3.6. The Vigil sits once, west of row 0, Act I only, scale 7.0, yaw −46°.

**Shared kit (S1–S3).** Act-neutral road language. Weathered stone and ash, not crimson bark, drowned silt, obsidian facet, or rose-dawn marble. Chunky low-poly game-kitbash masses that still carry **painted** grain — HD bakes albedo from the picture, so a clay-grey block becomes plaster. Broad, readable silhouettes at zoom 28. No carved ornament, no letters, no faces, no thin crack lines, no grass, no moss. The two slabs are the road itself (`MapScene` kits 0 and 1). The standing monument is the fallen-walker read: a person-height stele, slightly wider at the base, blunt rounded top — a body that did not lie down. It must still be one geometric mass, not a statue.

**Act I terminus.** Crimson-forest east bookend: grounded masonry, one pointed amber-lit arched window, crenellated crown, tiered lower-right turret, continuous plinth. It is a window-tower as a **landmark**, not a climbable spire and not the road. One window, never six panes.

**Act II terminus.** Drowned-city east bookend: monumental pointed arch, uneven ruined wings, three or four broad masonry courses, two **fused** pendant masses (left larger and higher) joined to the soffit, coarse side apertures, one continuous silt slab. Silted stone and drowned masonry albedo. False-light is a mass, not a working lantern.

**Act III terminus.** Obsidian-court east bookend: deliberately **broken** monumental ring-arch, faceted court pylons, a central shard fused into the same volume (bridged to plinth or ring — not a second island), continuous grounded plinth. Violet-obsidian facet, no intact gold halo, no watching-eye iris.

**Act IV terminus.** Mirrored-road east bookend, inner face of the same threshold the player just walked: thick **four-aperture** wheel, tall faceted flanking pylons, broad stepped courses, one continuous plinth. Umber-to-rose inverted hearth-stone. Path stays `terminus-threshold.glb`. The wheel is architecture, not a shard-count diagram.

**Vigil (west bookend, Act I only).** Small ancient Gothic stone hall from outside, end-on: steep dark slate roof with visible courses, weathered coursed grey ashlar, heavy plinth, three deep flank buttresses, one shallow recessed pointed-arch doorway at the near gable, corbel course at eaves, ridge chimney and pale smoke. The chimney is the identity cue — it says *hearth*. Cold blue-grey low-contrast matte illumination. This is the map's one building; coursed ashlar and slate must be in the picture because triplanar cannot place them.

Hue still belongs to the per-act grade and ramp bands. Shared albedo stays near-neutral. Vigil albedo is dark stone (measured mean 0.252). Do not paint a key light, a cast shadow, or a rim into the albedo.

---

## 2. Foreshadow bans

`docs/story/05-foreshadow-ledger.md` rule 2: nothing discloses before its tier. `docs/story/01-world.md` grades 「彩窗成鏡,隊伍現形」 as **L3, the single reveal point**. Six panes **are** the shard count (`docs/story/00-truth.md` §2.2). Row 10 of the ledger is the model: `mirror.png` ships as L0 art with its meaning withheld.

**Never in any rest concept**

- The 彩窗 / Rose Window as six compartments, six glowing emberglass panes, a wheel of six, or a countable shard ledger.
- Rose, wheel, or circular windows on the **Vigil**. At most a narrow slit. The hearth-side window faces the fire; from the road you are outside it.
- Characters, Keeper, hooded seated figure, Queue of pilgrims, faces, hands, letters, runes, numerals.
- Climb / Spire / wrapping staircase / switchback stair / vertical building **as the road**. The Act I terminus may be a grounded window-tower landmark; it must not read as something you climb.
- Intact gold halo (Act III's ring is broken on purpose). Watching-eye iris as a readable eye.
- Water, kelp, coral, painted flood as a mesh. Chains, cages, bars, hanging lanterns, grout lines as separate strips.
- Gilded City / gold city at the west. Mirror that shows a person. Emberglass shards as props.
- Grass, moss, foliage, loose clutter, second pile, second log, detached chips.

**Act-specific**

| ID | Extra ban |
|---|---|
| shared-standing-monument | No carved walker, no lying-down corpse, no inscription. 碑 = standing mass. |
| act1-terminus | No six-pane rose. No forest, no roots as extra pieces. One pointed window only. |
| act2-terminus | No chains. No cage. No working lantern flame. No water plane. The on-disk PNG that shows hanging lanterns on chains is **not** the dest — do not reconvert it. |
| act3-terminus | Ring stays broken. No intact halo. No star-eye as a pupil. |
| act4-terminus | Four apertures, not six. Do not paint the L3 lighting of six panes. Do not label the wheel as 彩窗. Filename stays `terminus-threshold.glb`. |
| act1-vigil | No rose, no wheel, no circular window, no six lights in the gable. Blank east gable from the road. |

Act IV **kits** (not this file) also ban the rose. The Act IV **terminus** may be a rose-*shaped* wheel because the player is already past unsealing; it still must not count to six.

---

## 3. Converter framing

Paste this block into every concept prompt. It is for the converter, not for a pretty picture. Tripo reconstructs what it can see: a horizon or a contact shadow comes back as geometry.

```text
Square 1:1 frame. Entire object in frame, centred, even margin on all four sides,
large in frame. Orthographic three-quarter view from about 35–40° above.
Flat even studio lighting from above-front. Solid flat mid-grey background
(#8A8A8A). No ground plane, no floor, no horizon, no environment, no backdrop
set, no contact shadow, no cast shadow on the ground, no baked AO, no rim light,
no depth of field, no vignette. Isolated subject. No cropped limbs of the mass.
Not a tile texture, not a landscape, not a diorama.
```

Do not use the dark studio void on `act2-terminus-flooded-threshold.png` or `act4-terminus-rose-threshold.png`. Mid-grey, ground-free.

---

## 4. TEXTURED concept language — not clay-maquette

HD Model bakes albedo from the picture. The 2026-08-19 clay-maquette prompts (`matte untextured clay-maquette surface`) were for Smart Mesh with `texture=false`. Reusing them on `--textured` ships grey plaster.

Write **painted game-asset concept** language:

- Coursed ashlar, slate courses, silted stone, charred grain, obsidian facet, weathered paving — as **albedo**, not as a normal map and not as baked light.
- Low-contrast, planar, low-poly-friendly. Broad material regions the unwrap can keep.
- Cold or act-appropriate local colour, still matte. No PBR spec flash, no wetness, no emissive bloom except a dull amber in the Act I window glass (a darker pane, not a light source mesh).
- Forbidden phrases: `clay-maquette`, `untextured`, `clay render`, `normals-only`, `grey clay`.

Runtime still overrides ordinary kits and termini with the triplanar prop shader. Vigil is the row that binds baked albedo (`MapMaterials.bind_vigil_albedo`). Paint them all anyway: this run lands textured GLBs, and HD reconstruction follows the picture.

---

## 5. Studio — HD Model only

Generating product is **Tripo Studio** (`studio.tripo3d.ai`), paid Pro credits. Never the API. Forbidden hosts: `openapi.tripo3d.ai`, `platform.tripo3d.ai` generation, any `/v2/openapi` or `/v3/generation` call. Never **Generate Multi-Views**. Never AI Complete. Never 4K (blows `bytes_max`). PBR off: the unshaded map shaders sample one map.

Credit order, do not skip:

```bash
# 1. dry-run — no Chrome, no credits
bun tools/studio_image_to_glb.ts --dry-run --textured --privacy private \
  --image assets/art/map-concepts/<asset_id>.jpg \
  --out /tmp/glassvow-studio-<asset_id>.glb \
  --topology triangle --pbr off --faces <1500|6000> --texture-quality <1k|2k>

# 2. smoke-run — Chrome + form, Generate is not clicked
bun tools/studio_image_to_glb.ts --smoke-run --textured --privacy private \
  --image assets/art/map-concepts/<asset_id>.jpg \
  --out /tmp/glassvow-studio-<asset_id>.glb \
  --topology triangle --pbr off --faces <1500|6000> --texture-quality <1k|2k>

# 3. generate — spends quoted HD credits
bun tools/studio_image_to_glb.ts --textured --privacy private \
  --image assets/art/map-concepts/<asset_id>.jpg \
  --out /tmp/glassvow-studio-<asset_id>.glb \
  --topology triangle --pbr off --faces <1500|6000> --texture-quality <1k|2k>
```

| Role | Flags | Caps |
|---|---|---|
| Ordinary (three shared) | `--faces 1500 --topology triangle --texture-quality 1k --pbr off` | 600–2500 tris, GLB ≤ 192 KiB |
| Hero / threshold (four termini + vigil) | `--faces 6000 --topology triangle --texture-quality 2k --pbr off` | ≤ 8000 tris, GLB ≤ 768 KiB |

`--textured` stays on the HD Model tab. Smart Mesh has no texture stage. `--privacy private` needs a real mouse click on the combobox; the HD default is Sharing Only. After upload, **Generate Multi-Views** appears — do not click it.

One mesh, one triangulated surface, `POSITION+NORMAL+TEXCOORD_0`, no animation, skeleton, `TEXCOORD_1`, tangent, or joints. Export GLB. If the dest already exists, overwrite it with the new textured export — that is the reshape.

Vigil may keep `assets/art/map-concepts/act1-vigil-hall.png` as the image path.

---

## 6. Volume, axis, ground

- **One connected volume** after a position-weld. Closed or deliberately open broad forms only; no hidden internal islands, no chips, no second block.
- **Exception: Vigil only** — hall + chimney smoke, `components_max` 2. Smoke floats clear of the chimney. Nothing else may use that exception.
- **Y-up**, metres, pivot on ground contact, **min Y = 0** as exported.
- Pendants, shards, turrets, lips, and missing-chunks are **concave bites or fused masses** in the same solid, not separate pieces. Act II pendants join the soffit. Act III shard joins ring or plinth. Monument shoulder is a bite, not two islands (the 2026-08-19 Smart Mesh of this file came back as two, then three, islands).
- No floor island. If the picture has a ground slab under the subject, Studio will emit one and twenty copies will each carry a floor.

---

## 7. Per-id prompt skeletons

Each skeleton is: identity, reshape note, then a prompt the concept agent can paste after the framing block in §3. Save new pictures at `assets/art/map-concepts/<asset_id>.jpg` unless the Vigil reuses its PNG.

Shared tail for every prompt:

```text
Clean planar, low-poly-friendly textured game-asset concept. Painted matte
albedo with readable material regions — not clay, not untextured, not a
sculpture maquette. No people, no text, no foliage, no loose props, no
second object, no chains, no cage, no rose window, no six panes.
```

### `shared-road-slab-a` — ordinary — reshape

**Silhouette job.** Broad low paving block; flat-topped rectangle; slightly broken front-right corner.

**On disk.** Studio Smart Mesh, untextured, 1560 tris, 38 656 B, task `cc83bc21-…`. Concept `map-concepts/shared-road-slab-a.jpg` is clay-grey. 20-placement signed as same item, different size and angle (`docs/reviews/292/road-slab-a-20.png`).

**Reshape.** Keep the rectangle-plus-bite contour. Paint weathered road-stone albedo (neutral, slightly warmer than mid-grey, coarse grain, no moss). Drop clay. Do not add a second step — that is slab-b. Do not grow the bite into a detached chip.

**Prompt subject.**

```text
Single game-kitbash 3D prop: a broad low stone road slab, a short thick
paving block. Flat-topped rectangular mass, slightly broken front-right
corner as a concave bite in the same volume. Weathered pale road-stone
albedo, coarse matte grain, no carved ornament, no thin crack lines.
One connected volume sitting as if on the ground but with no ground drawn.
```

Studio: ordinary flags. Dest: `geometry/shared/road-slab-a.glb`.

### `shared-road-slab-b` — ordinary — reshape

**Silhouette job.** Broken / offset slab; left half a finger-width lower; far-left front corner missing; right edge a short raised lip. Distinct from slab-a.

**On disk.** Smart Mesh, 1453 tris. Provenance: two visible islands 4.4 mm apart, joined by remapping the nearest vertex pair. Concept `shared-road-slab-b.jpg` is clay-grey.

**Reshape.** Fuse the step, the missing chunk, and the lip into **one** painted volume in the picture so HD does not re-emit two islands. Same stone family as slab-a, different contour. No grass in the step.

**Prompt subject.**

```text
Single game-kitbash 3D prop: an offset road slab, not a single rectangle.
Left half sits a finger-width lower than the right half like a short step;
far-left front corner is a missing chunk bitten out of the same solid;
right edge is a short raised lip fused to the block. One connected weathered
pale road-stone volume, coarse matte albedo, no separate chips, no crack
lines as cuts.
```

Studio: ordinary flags. Dest: `geometry/shared/road-slab-b.glb`.

### `shared-standing-monument` — ordinary — reshape

**Silhouette job.** Fallen-walker read; broad standing mass; no carving noise. Person-height stele, wider at the base, blunt rounded top, concave bite off the upper-right shoulder.

**On disk.** Fused Studio Pro Export, accepted 2026-08-21. First Smart Mesh: two islands; retry: three, including 28–49 mm shoulder chips. Fuse pass made the missing chunk a bite; isolate pass dropped the ground. Concept `shared-standing-monument.jpg` is still clay.

**Reshape.** Keep the tall one-volume silhouette. Paint weathered stele stone, still act-neutral. Shoulder stays a concave bite. No face, no letters, no arms, no second block in the notch, no ground plane.

**Prompt subject.**

```text
Single standing monument: one broad upright weathered stele, thick
person-height stone that reads as a fallen walker who is still standing.
One chunky vertical mass, slightly wider at the base, blunt rounded top,
upper-right shoulder a concave bite in the same solid — no gaps, no chips,
no second block. Weathered pale-ash stone albedo, matte, no carved faces,
no letters, no ornament, no arms.
```

Studio: ordinary flags. Dest: `geometry/shared/standing-monument.glb`.

### `act1-terminus` — hero — reshape

**Silhouette job.** Shipped crimson-forest east bookend: pointed window surround, grounded masonry, crenellated crown, tiered lower-right turret, one plinth.

**On disk.** Local parametric + manifold union, 4446 tris, 107 504 B, untextured, one watertight component. **No concept PNG** under `map-concepts/`. Review: `docs/reviews/294/act1-terminus/`.

**Reshape.** New 1:1 textured concept from the dest silhouette, not a new identity. Paint coursed masonry and a dull amber pane in the single pointed window. Crenellations stay chunky (thin merlons become 20-copy comb-teeth). Turret fused to the mass. Not a climbable spire, not six panes, no forest.

**Prompt subject.**

```text
Monumental game-kitbash landmark: a grounded masonry window-tower, squat
and wide, sitting on one continuous plinth. One pointed arched window in
the near face with a dull amber glass pane (darker glass, not a lamp mesh).
Crenellated crown as a few thick merlons, not a comb. Tiered lower-right
turret fused into the same volume. Weathered ashlar albedo, warm-grey
stone with a hint of ember in the pane only. One connected volume.
No wrapping stair, no spire shaft, no second window, no rose, no six panes.
```

Studio: hero flags. Dest: `geometry/act1/terminus-amber-window-tower.glb`.

### `act2-terminus` — hero — reshape

**Silhouette job.** Flooded threshold: thick pointed arch, uneven ruined wings, through-apertures, silt courses, two fused pendant masses (left larger and higher).

**On disk.** Local parametric, 5568 tris, 134 416 B, untextured, one component. Concept `map-concepts/act2-terminus-flooded-threshold.png` is **not converter-ready**: dark void background, hanging lanterns on **chains**, trefoil in the arch. The signed dest dropped the chains and fused the pendants.

**Reshape.** Draw the dest, not that PNG. Mid-grey ground-free frame. Pendants are stone masses fused to the soffit — no links, no cages, no flame. Drowned masonry + silt albedo. No water plane, no kelp, no coral, no grout strips.

**Prompt subject.**

```text
Monumental drowned pointed arch with uneven ruined wings, three or four
broad masonry courses, two fused pendant masses hanging from the soffit
(left larger and higher) as part of the same solid, coarse side apertures,
and one continuous silt slab as the object's own base — not a ground plane.
Drowned masonry albedo, silted stone, cold blue-grey local colour, matte.
No chains, no cages, no lanterns, no painted water, no kelp, no coral, no grout.
One connected volume.
```

Studio: hero flags. Dest: `geometry/act2/terminus-flooded-threshold.glb`. New concept file: `map-concepts/act2-terminus.jpg`.

### `act3-terminus` — hero — reshape

**Silhouette job.** Broken ring-arch, faceted court pylons, central shard, continuous plinth.

**On disk.** Local parametric, 5504 tris, 132 952 B, untextured, one component. **No concept PNG.** Review: `docs/reviews/294/act3-terminus/`.

**Reshape.** Ring stays broken — an intact halo is a canon error (abandonment's light went out). Central shard must **touch** ring or plinth in the picture so HD cannot emit a second island. Obsidian-facet albedo, violet-black, no gold, no pupil.

**Prompt subject.**

```text
Monumental broken ring-arch on a continuous grounded plinth, flanked by
faceted court pylons fused to the plinth. The ring is incomplete — a
deliberate gap. A central faceted shard is bridged into the same volume
(joined to the plinth or the ring), not floating. Obsidian-facet albedo,
dark violet-black matte glass-stone, no glow mesh, no intact halo, no
carved eye. One connected volume.
```

Studio: hero flags. Dest: `geometry/act3/terminus-broken-ring-arch.glb`. New concept: `map-concepts/act3-terminus.jpg`.

### `act4-terminus` — hero — reshape

**Silhouette job.** Thick four-aperture wheel, faceted flanking pylons, stepped threshold courses, continuous plinth. Path stays `terminus-threshold.glb`.

**On disk.** Local parametric, 5460 tris, 156 660 B, untextured, one component. Concept `map-concepts/act4-terminus-rose-threshold.png` is a **six-lobe** rose on a **dark** void. The signed dest is a **four-aperture** wheel. Six lobes would read as the shard count.

**Reshape.** Draw the dest: four apertures, two pylons, stepped plinth. Mid-grey background. Umber-to-rose inverted hearth-stone albedo. No six panes, no glowing emberglass, no character, no foliage. Architecture, not a diagram of L3.

**Prompt subject.**

```text
Monumental rose-threshold as a thick four-aperture wheel (four openings
only, never six), tall faceted flanking pylons, broad stepped courses,
one continuous plinth. All parts fused. Inverted hearth-stone albedo,
umber-to-rose matte masonry, no glow, no glass-shard props. No people,
no text, no foliage, no loose props. One connected volume.
```

Studio: hero flags. Dest: `geometry/act4/terminus-threshold.glb`. New concept: `map-concepts/act4-terminus.jpg`.

### `act1-vigil` — threshold — keep or reshape

**Silhouette job.** West bookend hall from outside: gabled, end-on, blank east gable, shallow recessed pointed doorway, flank buttresses, chimney with smoke.

**On disk.** Studio HD, task `5f44379a-…`, 5615 tris, 604 608 B, 2K JPEG albedo, Y min 0.0, two welded components (hall + smoke). Concept `map-concepts/act1-vigil-hall.png` is already square, mid-grey, ground-free, no rose. fol2 approved the building in-engine 2026-08-24.

**Reshape.** Optional. Reuse the PNG if the next HD pass is a pipeline proof. If you paint a new picture, keep hall+smoke as the only two masses, keep the chimney, keep the door, **keep the rose off**. Albedo must stay dark coursed stone (manifest `tex_mean` 0.252). Do not add a ground plane under the plinth as a separate slab that Studio will duplicate.

**Prompt subject (if reshaping).**

```text
Small ancient Gothic stone hall, exterior three-quarter view from 35–40°
above; entire building centred with even margin in a square frame. Steep
dark slate roof with visible courses; weathered coursed grey ashlar, heavy
plinth, three deep flank buttresses, one shallow recessed pointed arch
doorway at the near gable, corbel course at eaves, ridge chimney and pale
smoke as a second small mass above the chimney only. Cold blue-grey
low-contrast matte illumination. No rose window, no wheel window, no
circular window, no six lights, at most one narrow slit. Flat neutral
mid-grey background with no ground or cast shadow.
```

Studio: hero flags (`--faces 6000 --texture-quality 2k --pbr off`). Dest: `geometry/act1/vigil-hall.glb`. Two components only.

---

## 8. Twenty-placement failure modes

The scalar gate is eight yaws at tilt −55° and zoom 28, `silhouette_noise` ≤ 0.04. That is not the visual clause. Review is a **lit 5×4 clay grid**, 1280×720, seed 292, gap 2.6 m, yaw `rng.randf() * TAU`, scale `0.82 + rng.randf() * 0.27` (`docs/solutions/tooling-decisions/a-signable-20-placement-review-is-a-lit-clay-grid.md`). Existence of a PNG is not a Gate. Heroes still run this capture even though runtime places each terminus and the Vigil once.

Fail the reshape if any of these twenty show up:

1. **White unshaded scatter.** Owner already refused that picture. Relight or it is unsigned.
2. **Ground / horizon island.** Twenty floors. Framing in §3 was ignored.
3. **Cast-shadow volume.** Twenty dark wedges glued to the mass.
4. **Detached chips.** Monument shoulder, slab bite, cairn stones — 20× floating debris. Fuse in the picture.
5. **Chains, bars, lantern hangers, merlon combs.** Noise above 0.04 and spaghetti in the grid. Act II PNG is the warning.
6. **Stamp contour on a hero.** Twenty identical crenellated crowns, four-aperture wheels, or broken rings dominating the frame even when noise passes. Broaden merlons, thicken the wheel, break symmetry — or accept that a unique landmark will look like a stamp and do not add extra unique teeth.
7. **Identity failure.** Twenty *different* objects. Shared slabs must stay the same item at different size and angle.
8. **Pivot not at Y = 0.** Lattice floats or buries. HD export must ship min Y = 0.
9. **Overlap blob.** Terminus 20-placement is already tight (`docs/reviews/294/act1-terminus/twenty-placements.png`). Extra wings or a floor slab merge the grid into one mass.
10. **Clay albedo.** HD baked the maquette. The grid looks like twenty plaster casts, and the shipping JPEG is useless.
11. **Baked key light / AO / rim in the texture.** Twenty copies stamp the same lighting under the map sun.
12. **Generate Multi-Views.** Backsides disagree; yaw 180 fails the mask.
13. **AI Complete.** Invented unseen backsides change the −55° silhouette.
14. **Quad / default 2 000 000 faces.** Ordinary blows 2500 tris; heroes blow 8000. Triangle @ 1500 / 6000 only.
15. **PBR on or 4K.** Metallic/roughness/normal or a 4K JPEG miss 192 / 768 KiB. Vigil 2K JPEG already spends ~413 KiB of 768.
16. **Closed arch.** Threshold holes filled — Act II / Act III / Act IV lose the doorway read.
17. **Vigil rose / six panes.** L3 handed to L0, twenty times, at the start of every run.
18. **Carved faces or letters on the monument.** L1 leak plus silhouette noise.
19. **Water / kelp / coral as mesh** on Act II, or a hanging-lantern island that is not fused to the soffit.
20. **Second connected component** that is not Vigil smoke. Slab-b's 4.4 mm gap, monument chips, Act III floating shard, Act I turret sitting beside the tower — the weld count will fail, and twenty copies will shed parts.

A reshape is not landed until inspect is clean **and** a new readable 20-placement exists for fol2 to sign. Do not pass `--reviewer fol2` or `--accept-signed-capture` from this direction; provenance is a later step.

---

## Concept-agent checklist

- [ ] Square 1:1, whole object, centred, mid-grey, no ground, no horizon, no cast shadow.
- [ ] Painted albedo, not clay-maquette.
- [ ] Foreshadow bans in §2 hold on a blind read of the picture.
- [ ] One volume (Vigil: hall + smoke only).
- [ ] Dest path unchanged; reshape, not a 29th GLB.
- [ ] Ordinary vs hero flags match the table in §5.
- [ ] Never Multi-Views, never the API.
