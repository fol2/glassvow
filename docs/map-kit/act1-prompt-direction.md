# Act I kit prompt direction

Status: **direction only**. This file is the prompt contract for Act I map-kit
concepts and their Tripo Studio HD conversion. It does not generate images or
meshes. Wave-1 slots for this pass are empty (`[]`); there is no subset — the
catalogue below is the whole Act I owned set.

`act_key`: `act1`. Manifest act index: `0`. Region: 灰燼樹林 / The Ashen Woods.
West bookend: the Vigil. East bookend of the act: the amber-window terminus.

Authoritative IDs and caps live in `assets/art/map/map-assets.json`. Motif
source lives in `docs/map-scene-asset-bill.md` (A1-1…A1-5, A1-H) and
`docs/story/03-acts.md` (Act I). Studio product and HD flags live in
`docs/solutions/tooling-decisions/the-textured-studio-path-is-the-hd-tab-not-the-script.md`.
Do not invent a 608th citation into the detached web reference.

## Catalogue

Act I on the map is eight ordinary kit groups (three **shared** + five **act**)
plus one terminus plus one threshold. This file owns the seven `act: 0` rows.
Shared dests sit on the Act I road but are not re-authored here.

| ID | Kind / role | Dest (on disk) | Concept on disk | Studio profile |
|---|---|---|---|---|
| `act1-ash-trunk-fork` | kit / ordinary | `geometry/act1/ash-trunk-fork.glb` | `map-concepts/act1-ash-trunk-fork.jpg` (clay) | ordinary HD |
| `act1-root-wedge` | kit / ordinary | `geometry/act1/root-wedge.glb` | `map-concepts/act1-root-wedge.jpg` (clay) | ordinary HD |
| `act1-charred-stump` | kit / ordinary | `geometry/act1/charred-stump.glb` | `map-concepts/act1-charred-stump.jpg` (clay) | ordinary HD |
| `act1-fallen-bough-arch` | kit / ordinary | `geometry/act1/fallen-bough-arch.glb` | `map-concepts/act1-fallen-bough-arch.jpg` (clay) | ordinary HD |
| `act1-ash-cairn-mass` | kit / ordinary | `geometry/act1/ash-cairn-mass.glb` | `map-concepts/act1-ash-cairn-mass.jpg` (clay) | ordinary HD |
| `act1-terminus` | terminus / hero | `geometry/act1/terminus-amber-window-tower.glb` | **none** | hero HD |
| `act1-vigil` | threshold / hero | `geometry/act1/vigil-hall.glb` | `map-concepts/act1-vigil-hall.png` (textured) | hero HD |

Shared, used in Act I composition, out of this file:

| ID | Dest (on disk) |
|---|---|
| `shared-road-slab-a` | `geometry/shared/road-slab-a.glb` |
| `shared-road-slab-b` | `geometry/shared/road-slab-b.glb` |
| `shared-standing-monument` | `geometry/shared/standing-monument.glb` |

Those three are already signed clay Smart Mesh. Do not regenerate them from
this document. Monuments on the Act I road are the shared stele, not a new
Act I carving.

---

## 1. Visual language

Act I is the stretch of road **closest to the hearth**. The woods grew on ash,
and the ash is two falls at once: west-drift of the original fire after it
broke on the eastern door, plus the ash of walkers who burned out on the first
leg — the highest stop-rate on the road (`docs/story/03-acts.md`, Act I;
`docs/story/01-world.md` fire physics: **灰 = 燒盡、無可凝者**). Bodies of
walkers do not lie down; they stand as monuments. The forest's heart lives on
that spent will. It does not eat the standing ones.

**Motif pool (use):** ash, spore-dust as surface grain, roots, charred wood,
fused ash-stone, paired *lit* lanterns as a lighting cue (act1-mid: someone
is still lighting lamps). Coursed grey gothic masonry and a single amber
pointed window are the terminus language, taken from
`assets/art/stage/act1-backdrop.png`. Weather is falling ash, not rain.

**Palette division of labour (do not collapse these into the concept):**

- Act hue lives on the grade and the ramp, never as a painted sky.
  `MapRegions` Act 0: crimson-dusk wrap (`GRADE_HUE_NEAR` 0.95 → `FAR` 0.88),
  night-glass shade, glass-blue key. Grade file:
  `assets/art/map/grades/act1-grade.png` — crimson dusk, amber key, dense
  early monument contacts.
- Ordinary kit *runtime* still projects a neutral scalar tile
  (`materials/act1-prop-charred-bark.png`, mean 0.50) via `map_prop.gdshader`.
  That is why clay was used the first time.
- **This pass paints real albedo anyway.** HD Model bakes the picture. A grey
  maquette bakes grey. Paint charred bark, ash crust, coursed ashlar, slate —
  mid-value, low-contrast, even light — so the converter sees material, not
  studio clay. Keep hue quiet: cool grey-brown charcoal, pale ash, slate, a
  little ember in cracks. Let the grade do crimson.

**Mass language (keep):** chunky low-poly-friendly volumes, one readable
silhouette per module, no lacework, no thin twigs, no carved letters. The
bill's silhouette job per row is the identity; albedo is the dress.

**Stage plates to steal from, not to copy into the frame:**

- `act1-backdrop.png` — crimson pine mass, one amber pointed window in a
  crenellated masonry tower (the terminus device). Distant twin amber lights
  are atmosphere, not a second mesh.
- `act1-mid.png` — paired lit lanterns, a ruined pointed arch. The quatrefoil
  in that plate is a four-lobe ruin, **not** the six-pane Rose Window. Do not
  put hanging chains or cage bars on a kit module (they become islands).
- `act1-ledge.png` — dark ashlar, ember in the joints, paired lanterns. Ember
  cracks are albedo, not extra geometry.
- `scenes/opening-hearth.png` — the Vigil **from inside**: hearth, east door,
  and the Rose Window on the hearth-side wall. The map shows that hall from
  **outside**. The chimney is the only identity cue that says *hearth*.

**Camera the mesh must survive:** production tilt `MapCameraRig.TILT_DEGREES`
(−55°) and widest zoom 28. Design the silhouette for that view, not for a
beauty three-quarter in a void.

---

## 2. Foreshadow bans

`docs/story/05-foreshadow-ledger.md` rule 2: a fact that discloses before its
tier is a leak. `docs/story/01-world.md` grades 「彩窗成鏡,隊伍現形」 as
**L3, the single reveal point**. An earlier parametric Vigil put the six panes
on the road-facing gable and handed an L3 count to a player at L0. Row 10 of
the ledger is the model: `mirror.png` ships as L0 art with its meaning
withheld. That the west face *has* six compartments does not license showing
them. The Rose Window also faces **in** at the fire; from the road you are
outside it.

**Banned on every Act I concept and mesh:**

| Ban | Why |
|---|---|
| Rose / wheel / circular window; six panes; six countable shards; stained-glass rose | L3 reveal. Prompt must say so. At most one narrow slit on the Vigil. |
| Queue of standing walkers / monument colonnade as the subject | The Queue becoming visible is the unsealing. Shared `standing-monument` is one stele, not a line. |
| Mirror, silvered glass, window-becoming-mirror | L3 / ledger rows 10 and 14. |
| Gilded City, gold cloud-sea city, reverse / inverted hearth-light | Act IV. The hearth is west, shown as a chimney, not as a golden destination. |
| Broken halo, broken gold ring, star-eye, watching eye as a readable iris | Act III court motif. |
| Obsidian (faceted black unlit glass), crown, throne, Sovereign silhouette | Act III material and boss. |
| Flood, standing water, silt stairs, rust blooms, lure-lantern (false unlit/green light), library shelves | Act II. Act I is ash, not waiting-water. |
| Empty / unlit lantern as a court symbol, Hollow Lamplighter figure, Keeper figure, player figure | Identity leak. Paired **lit** lanterns are the Act I mid motif; they are a lighting cue, not a kit mesh. |
| Pale acolyte masks, faces, skulls, carved walker portraits, letters, numbers | Kits have no carving noise (bill S3). 蒼白面具 is an enemy, not a tree. |
| Literal Rootheart, a heart in a trunk, a face in bark | Boss is the forest's heart in fiction, not a carved organ. |
| Spire / climb / summit / stair-as-the-road / vertical pilgrimage | Glossary banned vocabulary. The terminus is a **window-tower mass**, not a climb. |
| Corpses lying down, graves, coffins | Walkers die standing; they never leave a lying corpse. |
| Characters, animals, sporeling creatures, mushrooms as props, grass blades, moss beards, leaves, twigs | One object. Spore is *dust on a surface*, not a mob. |
| Ground plane, horizon, sky, forest backdrop, second building | Converter will emit them as geometry. |
| Cast contact shadow, baked AO puddle, rim light, beauty key | Same — they come back as mesh or as dirty albedo. |

**Allowed that looks like a neighbour but is not:** a **pointed** gothic
window with a warm amber interior (the shipped Act I key, one opening, not
six). A **quatrefoil** hole in a ruin is act1-mid, not the Rose. A **blank**
gable on the Vigil. **Paired lit lanterns** only as even studio lighting
described in prose, not as hanging cage geometry on a kit.

---

## 3. Converter framing

These constraints are for Tripo, not for a pretty picture. HD reconstructs
what it can see. A horizon, a floor, or a contact shadow returns as geometry.

Every concept, ordinary and hero:

- **Square 1:1.** No landscape crop. Vigil's signed concept is 1254×1254 RGB;
  match that class (square, RGB, no alpha silhouette).
- **Whole object in frame**, even margin, subject large and **centred**.
- **Flat mid-grey ground-free background** (studio `#8A8A8A` class). No
  gradient, no vignette, no environment.
- **No horizon. No ground plane. No cast shadow** on a floor that is not
  part of the object.
- Three-quarter view, about 35–40° above, matching the Vigil prompt and
  readable at production tilt.
- Flat even studio lighting from above-front. No beauty rim, no dramatic
  underlight, no depth of field, no fog, no falling ash as particles (ash is
  albedo grain, not extra blobs).
- No text, labels, watermarks, colour checkers, or scale figures.

If an edit pass is needed to kill a floor that the generator invented, isolate
the object onto mid-grey **before** Studio. Do not "fix it in the mesh."

---

## 4. TEXTURED concept language, not clay-maquette

The five Act I ordinary concepts on disk (`map-concepts/act1-*.jpg`) and the
three shared slabs were prompted as **matte untextured clay-maquette**. That
language is **banned** in this file. It was the Smart Mesh / triplanar
bargain. HD Model bakes albedo from the picture
(`docs/solutions/tooling-decisions/the-textured-studio-path-is-the-hd-tab-not-the-script.md`).
Feed it clay and you buy a grey rock with a 1K JPEG of clay.

**Write (and paint):**

- Named materials: charred bark, ash-crusted heartwood, fused ash-stone,
  weathered coursed grey ashlar, dark slate courses, pale chimney smoke.
- Broad, readable grain. A few large value masses. Not photographic bark
  pores, not hair-thin cracks, not 8K photogrammetry.
- Mid-value, low-contrast. Ordinary kits must still sit under a value-locked
  prop tile and a grade; hero albedo is sampled (`map_vigil.gdshader` is
  unshaded and samples **one** map; `tex_mean` on the Vigil row is **0.252**).
  Do not paint a white building or a soot-black hole.
- Colour in the material, not in the light. Ember only in joints or a window
  interior, never as a baked sun stripe.

**Do not write:** "clay-maquette", "matte untextured", "grey studio clay",
"untextured stone-or-wood surface", "normals-only", "triplanar will paint
this." Those sentences produce the JPGs already on disk.

Runtime note, so a later binder does not fight this file: ordinary kits are
still *projected* today (`map_prop.gdshader` ignores bought UVs on purpose —
23 unwrapped kits would drift). The Vigil is the one building whose unwrap is
sampled. HD albedo on ordinary rows is still required so the converter sees
form; whether a later bind samples it is not this document's job. Do not
strip the texture in Studio to "match the old kits."

---

## 5. Studio conversion

**Product: Tripo Studio only** (`studio.tripo3d.ai`), paid Pro credits.
**Never the API.** Forbidden hosts: `openapi.tripo3d.ai`,
`platform.tripo3d.ai` generation, any HTTP to `/v2/openapi` or
`/v3/generation`. A Studio subscription does not pay the API.
`assets/art/map/provenance.json` records `generation_surface: Studio` and
`api_forbidden: true`.

**Tab: HD Model** (`--textured`). Smart Mesh has no texture stage. Do not
click away from HD. **Never click Generate Multi-Views** (it appears after
upload). **Never `--ai-complete on`** — it invents unseen backsides (fatal
for the Vigil's blank gable and for any fork/arch crotch). Ultra Mesh stays
on. Privacy **private**. Topology **triangle**. PBR **off** (unshaded map
shaders sample one map; metallic/roughness/normal would spend the byte cap
on images the screen does not show). Do not export 4K (blows `bytes_max`).
Do not export FBX as the shipping file.

Driver:

```bash
# 1. dry-run — no Chrome, no credits
bun tools/studio_image_to_glb.ts --dry-run --textured --privacy private \
  --image <concept> --out <tmp.glb> [profile flags]

# 2. smoke-run — form only; Generate is not clicked
bun tools/studio_image_to_glb.ts --smoke-run --textured --privacy private \
  --image <concept> --out <tmp.glb> [profile flags]

# 3. generate — spends the quoted HD credits
bun tools/studio_image_to_glb.ts --textured --privacy private \
  --image <concept> --out <tmp.glb> [profile flags]
```

**Ordinary profile** (five act kits) — 192 KiB / 196608 bytes, 600–2500
triangles accepted, request 1500 faces:

```bash
--textured --privacy private --faces 1500 --topology triangle \
  --texture-quality 1k --pbr off
```

**Hero / threshold profile** (terminus, Vigil) — 768 KiB / 786432 bytes,
hard cap 8000 triangles, request 6000 faces, 2K albedo:

```bash
--textured --privacy private --faces 6000 --topology triangle \
  --texture-quality 2k --pbr off
```

Do not skip dry-run → smoke-run. Smoke prints `quoted_credits` and
`would_spend_credits: false`. Generate matching is price-agnostic; do not
hard-code a credit number. If Chrome builds the blob but writes nothing to
disk, re-export with `--task-id` — do not curl the API for the file.

Land only after GPU silhouette (eight yaws, noise ≤ 0.04 at tilt −55° /
zoom 28) and a **readable** 20-placement. Provenance `source` is `Studio`.

---

## 6. Topology, up-axis, ground

- **One connected volume** per ordinary kit and per terminus. No chips, no
  second block, no hidden internal islands, no floor island.
- **Exception: `act1-vigil` is two components by contract** — the hall, and
  the smoke above the chimney. The row declares `components_max: 2`. Smoke
  is not a second building. Any third island fails.
- **Y-up, metres, pivot on ground contact, min Y = 0.0** as exported. The
  signed Vigil came out at min Y 0.0 and needed no re-grounding; keep that.
- Closed or deliberately open **broad** forms only. An arch may have a
  doorway hole. A window may be an opening. Do not build cages, bars,
  chains, twigs, or grout lines as geometry.
- One mesh, one triangulated surface. Ordinary: POSITION + NORMAL, and HD
  will also write TEXCOORD_0 + a 1K baseColor. Hero: same, 2K baseColor.
  No animation, skeleton, morph, or extra materials.
- Do not boolean-union in the page. Do not voxel-remesh to "fix" islands
  (that path already rounded the Vigil chimney off). Fix the **picture**.

---

## 7. Per-id prompt skeletons

Shared prefix. Paste it, then the subject block. Never add clay-maquette
sentences.

```
Orthographic 3/4 view from 35–40° above of a single game-kitbash 3D prop,
the whole object centred with even margin in a square 1:1 frame. TEXTURED
game-asset concept — HD will bake albedo from this picture: paint real
material, not grey clay, not a maquette. Flat even studio lighting from
above-front, no cast shadow, no baked AO, no rim light, no depth of field.
Isolated subject, large in frame. Solid flat mid-grey background (#8A8A8A),
no horizon, no ground plane, no environment. One connected volume sitting
on the implied ground. Chunky low-poly-friendly masses, clean silhouette.
No text, no labels, no watermark, no people, no animals, no leaves, no
twigs, no grass, no moss beards. No rose window, no six panes, no wheel
window, no broken halo, no standing water, no obsidian facets, no gold
city, no climbable spire.
```

New concepts are square PNG (RGB). Do not send the on-disk clay JPG to
`--textured`.

### `act1-ash-trunk-fork`

- Bill: A1-1, forked ash-tree mass.
- Dest on disk: untextured Smart Mesh from the clay Y
  (`map-concepts/act1-ash-trunk-fork.jpg`). Signed 20-placement:
  `docs/reviews/292/act1-ash-trunk-fork-20.png`.
- **Reshape:** keep the short thick trunk that splits into two stubby
  branches as **one** volume. The clay read is a typeface **Y** — twenty
  copies look like a letter, not a wood. Make the fork slightly irregular
  (one arm thicker / a little shorter), crotch fused, no gap. Paint
  **charred bark and pale ash crust**, blunt burned ends, no growth-ring
  grooves, no twigs. Do not split the crotch; Smart Mesh already wanted
  two islands on cleaner meshes than this.

Subject block:

```
Subject: a single forked ash-tree trunk. Short thick charred trunk that
splits into two stubby branches, slightly irregular so it does not read
as a letter Y — one arm a little thicker and shorter, crotch fused into
the same volume, blunt burned tops, no leaves, no twigs, no second stem.
Albedo: dark charred bark with pale ash dust in the recesses, matte,
broad grain, no hair-thin cracks. Distinct tall forked silhouette, still
a simple game-kitbash mass.
```

Studio: ordinary HD command on a new `map-concepts/act1-ash-trunk-fork.png`.

### `act1-root-wedge`

- Bill: A1-2, roots cutting through the ground plane.
- Dest on disk: Smart Mesh that needed **13 vertex welds at 5 mm**
  (heel and wedge were 1.5 mm apart). Clay concept is two blocks, a
  triangle plus a cube, and the 20-placement reads as **A / 4**.
- **Reshape:** fuse the buried heel into the rising wedge — one volume,
  one silhouette. Do not draw a dirt clod or a ground slab (the converter
  will emit a floor). The "cutting the ground" read is the wedge's
  buried-looking base, not a second object. Paint wet-char root wood and
  ash-loam crust. No grass blades, no root hairs, no sporeling caps.

Subject block:

```
Subject: a single root wedge. One thick triangular root mass bursting
upward, fused to a short buried heel that is the same volume — not a
second block, not a dirt clod, not a ground plane. Sharp rising face,
blunt buried back, sitting as if it has broken the implied earth.
Albedo: charred root wood with pale ash-loam crust, matte, broad grain.
Distinct wedge silhouette, still a simple game-kitbash mass.
```

Studio: ordinary HD command on a new `map-concepts/act1-root-wedge.png`.

### `act1-charred-stump`

- Bill: A1-3, low charred mass.
- Dest on disk: one squat volume from the clay stump. 20-placement is the
  cleanest of the five (`docs/reviews/292/act1-charred-stump-20.png`).
- **Reshape:** keep wider-than-tall, blunt chopped top, collar fused into
  the same volume (no separate root chips). Add albedo: charcoal top,
  charred-bark sides, ash at the collar. Do not paint concentric growth
  rings as thin grooves (silhouette noise). Do not make a cake, a stool,
  a mushroom, or a standing monument.

Subject block:

```
Subject: a single low charred stump. One short thick burned tree-base,
wider than it is tall, blunt chopped top, a fused collar at the ground —
no separate chips, no second block, no extra roots. Albedo: charcoal-black
chopped face, dark charred bark on the sides, pale ash gathering at the
collar, matte, no growth-ring engraving. Distinct low squat silhouette,
still a simple game-kitbash mass.
```

Studio: ordinary HD command on a new `map-concepts/act1-charred-stump.png`.

### `act1-fallen-bough-arch`

- Bill: A1-4, threshold-shaped fallen tree.
- Dest on disk: fused bent log from a clay concept that already has bark
  striation and two spiral knots. 20-placement reads as a **horseshoe / C**
  from most yaws (`docs/reviews/292/act1-fallen-bough-arch-20.png`).
- **Reshape:** keep both ends on the ground, one doorway-shaped bent log,
  one volume. Drop the spiral knots (they read as eyes). Soften bark into
  **broad** albedo bands, not carved grooves. Make the two feet slightly
  different in thickness so a yaw does not always print the same C.
  No chains, no hanging lanterns, no second log, no masonry arch (that is
  act1-mid, not this kit).

Subject block:

```
Subject: a single fallen-bough arch. One connected threshold-shaped fallen
tree, a thick log that bends into a low doorway, both ends on the ground,
one fused volume — no separate branches, no second log, no chips, no
chains. The two feet differ slightly in thickness. No spiral knots, no
eye-like swirls. Albedo: charred bark in broad bands with pale ash in
the hollow of the arch, matte, no hair-thin grooves. Distinct arch
silhouette, still a simple game-kitbash mass.
```

Studio: ordinary HD command on a new `map-concepts/act1-fallen-bough-arch.png`.

### `act1-ash-cairn-mass`

- Bill: A1-5, ash/stone dab mass.
- Dest on disk: a single potato blob. The clay prompt asked for several
  stones melted into one mound; the picture lost the stones.
- **Reshape:** keep squat, wider than tall, **one** volume. Suggest three
  or four chunky stones **by albedo and shallow fused lobes**, not by gaps
  or stacked seams. No loose rocks, no second pile, no grass. Must not
  match the stump (stump = chopped cylinder; cairn = mound).

Subject block:

```
Subject: a single ash-cairn mass. One compact piled heap of fused
ash-stone, a short squat cairn — three or four chunky stones melted into
one connected mound, wider than it is tall, sitting on the implied ground.
No gaps between stones, no stacked seams, no separate rocks, no second
pile. Albedo: pale ash crust over dark stone, matte, broad facets.
Distinct mound silhouette, still a simple game-kitbash mass.
```

Studio: ordinary HD command on a new `map-concepts/act1-ash-cairn-mass.png`.

### `act1-terminus`

- Bill: A1-H, shipped crimson forest and lit arched window.
- Dest on disk: **local parametric**, untextured, 4,446 triangles, 107,504
  bytes, one watertight component, Y-up, Y=0. No vendor. No concept file.
  Signed: `docs/reviews/294/act1-terminus/`. Mass: pointed window surround,
  grounded masonry, crenellated crown, tiered lower-right turret.
- **Reshape:** this is the first HD concept for the row. Trace the **shipped
  stage device** (`act1-backdrop.png` left tower) and the **signed mesh
  mass**, not the clay kits. Paint coursed grey ashlar, a crenellated crown,
  one **pointed** window with a warm amber interior (the Act I key). Keep
  the lower-right turret fused. Do not reproduce the parametric top as five
  identical radiator fins if a simpler crenellated crown reads. Do not add
  a forest, a second tower, a clock, a rose, six panes, or a climbable
  shaft. One authored placement in game; 20-placement is review only.

Subject block:

```
Subject: a single grounded gothic window-tower, the Act I map terminus.
One connected masonry mass: a short thick tower, pointed-arch window
surround on the near face, one warm amber interior in that pointed window
only (not a rose, not a wheel, not six panes), crenellated crown, a
smaller tiered turret fused on the lower right, heavy plinth. Weathered
coursed grey ashlar, dark mortar as albedo not as grooves, matte, low
contrast. No forest, no horizon, no second building, no flags, no clock,
no broken ring, no spire shaft. Distinct tower-and-window silhouette,
still a simple game-kitbash mass.
```

Studio: **hero** HD command on a new
`map-concepts/act1-terminus-amber-window-tower.png`.
`--faces 6000 --texture-quality 2k --pbr off`.

### `act1-vigil`

- Kind `threshold`, the west bookend, the map's **one textured runtime
  asset**. Dest on disk already HD: 5,615 triangles, 604,608 bytes, 2K
  JPEG baseColor, POSITION+NORMAL+TEXCOORD_0, min Y 0.0, two components
  (hall + smoke). Concept
  `map-concepts/act1-vigil-hall.png` is the signed conversion picture.
  Provenance task `5f44379a-face-4238-a5eb-4d2ec18a5663`. In-engine
  approval is `docs/reviews/156/round2/vigil-hall-in-map.png`.
- **Reshape only if regenerating.** Keep: gabled hall, end-on, **blank
  road-facing gable**, shallow recessed pointed doorway, three deep flank
  buttresses, corbel course at eaves, steep dark slate roof with visible
  courses, ridge chimney, pale smoke. The chimney is the hearth cue.
  Do not put the Rose Window on any face. At most one narrow slit on a
  flank (the signed concept has one). Do not let AI Complete invent a
  rose on the far gable. Do not ground-plane. Smoke stays a light plume
  above the chimney, not a cloud island the size of the hall, not a
  second building. `tex_mean` target 0.252 — stay dark-mid ashlar, not
  white stone. `components_max` stays 2.

Subject block (regeneration only; the signed prompt is also in
`docs/art-ledger.md` under `map-concepts/act1-vigil-hall.png`):

```
Subject: a small ancient Gothic stone hall, exterior three-quarter view
from 35–40° above; entire building centred with even margin in a square
frame. Steep dark slate roof with visible courses; weathered coursed grey
ashlar, heavy plinth, three deep flank buttresses, one shallow recessed
pointed-arch doorway at the near gable, corbel course at eaves, ridge
chimney and a small pale smoke plume. Road-facing gable is blank — no
rose window, no wheel window, no circular window, no six panes; at most
one narrow slit on a flank. Cold blue-grey low-contrast matte
illumination. TEXTURED: coursed ashlar that lines up along the wall,
slate on the roof not the walls, darker door leaf in the recess.
Two parts only: the hall, and the smoke. Flat mid-grey background, no
ground, no cast shadow.
```

Studio: **hero** HD command on `map-concepts/act1-vigil-hall.png` (or a
replacement PNG that still obeys the bans).
`--faces 6000 --texture-quality 2k --pbr off`.

---

## 8. Twenty-placement failure modes

Review evidence is a **lit 5×4 clay grid** (1280×720, seed 292 yaws and
scales, tilt −55°, review zoom 20), not a white scatter. The scalar gate
(eight alpha masks, `silhouette_noise` ≤ 0.04) can pass while the picture
fails. Owner language that closed #292: **"same item, different size and
angle."** A file existing is not a gate. Terminus and Vigil are **one**
authored placement in the world; their 20-placement is still the repetition
test, not an invitation to tile halls down the road.

Fail the review if any of these hold:

1. **Unreadable harness.** White unshaded blobs, a distant scatter, or an
   upscaled silhouette mask offered as the 20-placement. fol2 already
   rejected that picture once.
2. **Wallpaper contour.** One recognisable outline dominates the frame even
   though every yaw scored ≤ 0.04. The bill's 20-placement exists for this.
3. **Identity loss.** Twenty *different* objects. The module is meant to be
   reused; if the grid does not read as one item, the mesh failed identity.
4. **Letter-Y forest.** `act1-ash-trunk-fork` tiles as typography. Irregular
   fork in the concept did not survive conversion.
5. **A / 4 / two-block wedge.** `act1-root-wedge` still has a detached heel.
   Copies print a numeral or a letter, or a chip floats beside the wedge.
6. **Horseshoe / C arch.** `act1-fallen-bough-arch` is the same C at every
   yaw. Feet are identical; knots read as eyes; the grid looks like a
   staple pack.
7. **Potato cairn.** `act1-ash-cairn-mass` is indistinguishable from a
   pebble or from the stump. No mound identity, or it has fallen apart into
   loose stones (islands).
8. **Cake / mushroom stump.** `act1-charred-stump` grew a lid, a stem, or
   floating collar chips. Twenty cakes fail.
9. **Radiator terminus.** `act1-terminus` copies as a chess rook or a bank
   of identical fins. The amber window is gone, or six panes appeared.
   Twenty towers is already a harsh test — a repeated *wrong* tower fails
   twice.
10. **Floor island.** A ground plane or horizon in the concept became a
    slab under every copy. Isolate the object and regenerate.
11. **Shadow mesh.** A cast contact shadow became a second island. It
    copies twenty times as a dark wing.
12. **Glittering thin work.** Twigs, chains, bars, grout-line trenches, or
    hair-thin cracks push any yaw's `silhouette_noise` above 0.04, or they
    sparkle as a lace overlay on the grid.
13. **Ungrounded pivot.** Min Y ≠ 0, or the pivot is mid-volume. Copies
    hover or bury. Production seats on Y=0.
14. **No scale variation.** Seed-292 scale is `0.82–1.09`. If the mesh is
    so symmetric that scale does not change the read, the grid is wallpaper.
    Fail and thicken an asymmetry in the concept, not in twenty unique GLBs.
15. **AI Complete backsides.** Unseen faces grew a second fork, a second
    turret, a rose on the far gable, or a closed arch that was meant to be
    a doorway. `--ai-complete` stays off; if Studio invented it anyway,
    the picture (or the generate) is wrong.
16. **Multi-view fusion.** Generate Multi-Views was clicked. Extra angles
    melted into one confused mass. The grid will not match a single
    three-quarter identity. Never that button.
17. **Vigil as a village.** Twenty halls, or smoke that reads as a second
    building, or a third island (door leaf, slit plug, loose slate).
    Threshold `components_max` is 2: hall + smoke. A 20-placement of the
    Vigil is a topology/silhouette check, not a street.
18. **Hidden internals.** Intersecting shells that look closed until a yaw
    shows a hole or a floating inner chunk. The bill forbids hidden
    internal islands. Voxel remesh to hide them is also a fail (it already
    ate a chimney).
19. **Foreshadow tiled.** Six-pane roses, broken rings, flood water,
    obsidian blades, a queue of walkers, or a gold city — even faint —
    become obvious when printed twenty times. Ban list in §2 is not
    optional at review.
20. **Byte / triangle cap break that "looks fine."** Ordinary >192 KiB or
    outside 600–2500 triangles; hero >768 KiB or >8000 triangles; 4K or
    PBR maps stuffed into the GLB. The grid can still look pretty. The
    row still fails `map-assets.json`. Drop texture quality or faces;
    do not ship the oversize file.

Pass language, when it is earned: **same item, different size and angle**,
on a lit 5×4 grid, plus eight yaws ≤ 0.04, plus the row's byte and triangle
caps, plus one connected volume (Vigil: two). That is the whole of the
visual close. Do not generate from this file until a later wave names an
id.
