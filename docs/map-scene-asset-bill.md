# 3D map asset bill and payload contract

Status: **decision for ticket #289, before any geometry order**  
Verified: **2026-08-15**, against `main@d38ef7b4da9a51983b10b6149402309118ab9694`  
Scope: the rebuilt map surface in `presentation/map/`; no combat, story-copy, or domain changes.

## Decision

The shipping map asset library is bounded to:

- **27 untextured GLBs**: 23 reusable kit modules and 4 one-off termini;
- **8 neutral 1024×1024 tile textures**: one ground and one prop tile per act;
- **4 painted 512×256 RGBA grade textures**: one per act;
- **one manifest and one provenance ledger**, both machine checked;
- a **planning ceiling of 18.7 MiB** for the complete four-act package delta before
  container/export overhead, with **14–16 MiB expected** after real GLBs are measured.

Only one act is resident. One act sees eight kit meshes, one terminus, two material
tiles, and one grade. The map does not buy textures from the geometry vendor and no
module owns a private material.

This is deliberately the high end of #207's four-to-eight material allowance and the
middle of its 25–30-module allowance. It preserves the current renderer's cost shape:
one `surface_tex` fetch path in the ground shader, one in the prop shader, one grade,
and per-instance phase rather than per-object textures.

## Why this is the minimum complete bill

`MapScene` currently proves the composition with 25 prop placements split into flat
wedges, stacked slabs, and dab masses. `MapMaterials` proves one shared ground material,
one shared prop material, and one grade per active act. The real assets replace those
three placeholder shape families; they do not add a PBR material stack.

The signed visual language needs three independent kinds of variation:

1. **silhouette** — reusable GLB modules;
2. **surface grain** — neutral tile textures projected by the existing shaders;
3. **region and contact** — the per-act grade plus `MapRegions` ramp colours.

Adding object textures would duplicate variation already owned by (2) and (3), re-open
UV and de-light work, and break the draw/fetch budget that #233 measured. Fewer than five
act-specific modules makes the 20-random-placement repetition test fail by construction.
More than five per act is payload and draw-group growth before any on-device evidence
asks for it.

## Directory and manifest contract

Real assets land under one root:

```text
assets/art/map/
  map-assets.json
  provenance.json
  geometry/
    shared/
    act1/
    act2/
    act3/
    act4/
  materials/
  grades/
```

`map-assets.json` is authoritative. Checkers and runtime binding read the same rows;
filename conventions are for humans, never the classifier. Every row declares `kind`,
`act`, `role`, `path`, dimensions or triangle cap, and measured values needed by the
shader/checker. This is required because the present `tools/check_map_assets.py` applies
seam and de-light checks to every PNG. A painted grade is intentionally non-tileable and
value-varying, so it would false-fail both checks without a manifest distinction.

`provenance.json` records generation and human-edit history. It is not runtime data.

## Geometry bill — 27 GLBs

Filenames are internal production IDs, not player-facing canon. In particular, Act IV
naming remains owned by the story/content tickets; changing display copy must not churn
asset paths.

### Shared kit — 3

| ID | File | Silhouette job |
|---|---|---|
| S1 | `geometry/shared/road-slab-a.glb` | broad low slab, primary path rhythm |
| S2 | `geometry/shared/road-slab-b.glb` | broken/offset slab, avoids one repeated contour |
| S3 | `geometry/shared/standing-monument.glb` | the fallen walker read; broad standing mass, no fine carving |

### Act I — 5 kit + 1 terminus

| ID | File | Motif source |
|---|---|---|
| A1-1 | `geometry/act1/ash-trunk-fork.glb` | forked ash-tree mass |
| A1-2 | `geometry/act1/root-wedge.glb` | roots cutting through the ground plane |
| A1-3 | `geometry/act1/charred-stump.glb` | low charred mass |
| A1-4 | `geometry/act1/fallen-bough-arch.glb` | threshold-shaped fallen tree |
| A1-5 | `geometry/act1/ash-cairn-mass.glb` | ash/stone dab mass |
| A1-H | `geometry/act1/terminus-amber-window-tower.glb` | shipped crimson forest and lit arched window |

### Act II — 5 kit + 1 terminus

| ID | File | Motif source |
|---|---|---|
| A2-1 | `geometry/act2/drowned-wall-corner.glb` | drowned city wall mass |
| A2-2 | `geometry/act2/silted-stair.glb` | broad stair disappearing into silt |
| A2-3 | `geometry/act2/library-arch.glb` | flooded-library threshold |
| A2-4 | `geometry/act2/sunken-shelf-mass.glb` | stacked slab silhouette; no thin shelf slats |
| A2-5 | `geometry/act2/lure-lantern-post.glb` | false-light landmark; no cage bars or chains |
| A2-H | `geometry/act2/terminus-flooded-threshold.glb` | traced from the shipped Act II stage plates before modelling |

### Act III — 5 kit + 1 terminus

| ID | File | Motif source |
|---|---|---|
| A3-1 | `geometry/act3/obsidian-blade.glb` | large obsidian wedge |
| A3-2 | `geometry/act3/broken-halo.glb` | broken ring/halo mass |
| A3-3 | `geometry/act3/court-plinth.glb` | Sovereign-court stacked slab |
| A3-4 | `geometry/act3/shattered-wall-mass.glb` | broad ruined court wall |
| A3-5 | `geometry/act3/star-eye-mass.glb` | star/watching-eye motif as one coarse silhouette |
| A3-H | `geometry/act3/terminus-broken-ring-arch.glb` | shipped glowing broken ring-arch |

### Act IV — 5 kit + 1 terminus

| ID | File | Motif source |
|---|---|---|
| A4-1 | `geometry/act4/mirror-road-slab.glb` | reversed-road language |
| A4-2 | `geometry/act4/standing-pair.glb` | queue of standing monuments |
| A4-3 | `geometry/act4/reverse-hearth-arch.glb` | inverted hearth-light threshold |
| A4-4 | `geometry/act4/threshold-buttress.glb` | door/threshold support mass |
| A4-5 | `geometry/act4/pale-fractured-mass.glb` | neutral broad mass; no new canon symbol |
| A4-H | `geometry/act4/terminus-threshold.glb` | final concept held to #220/#261; path stays neutral |

### Per-act composition

An active act contains:

- 3 shared kit meshes + 5 act kit meshes, each as one `MultiMeshInstance3D` group;
- **24–32 non-hero instances** in total;
- each ordinary module used **2–5 times**, varied by translation, Y rotation, scale,
  and `INSTANCE_CUSTOM.xyz` phase;
- one terminus `MeshInstance3D`;
- no module-specific material or texture.

This is at most ten world draw groups before any measured need to split a `MultiMesh`:
one ground, eight kit groups, and one terminus. Spatial chunks are permitted only after
a capture proves that culling saves more than the added draw groups cost.

## Geometry acceptance contract

### Ordinary kit module

- Tripo request target: **1,500 faces**;
- accepted final range: **600–2,500 triangles**;
- hard GLB cap: **192 KiB**;
- one mesh, one surface, no animation, skeleton, texture, UV requirement, or tangent;
- normals required; material data is stripped or ignored by material override;
- pivot on ground contact, Y-up, metres, deterministic transform;
- closed or deliberately open broad forms only; no hidden internal islands.

### Hero terminus

- Tripo/concept request target: **5,000 faces**;
- hard final cap: **8,000 triangles**;
- hard GLB cap: **768 KiB**;
- at most two surfaces: opaque world and optional glass accent;
- no bought textures; any glass accent uses the game's own material;
- one authored placement per act.

### Silhouette gate

The first real module must land with the missing GPU raster gate. The gate imports the
GLB in Godot 4.7.1, renders alpha masks at the production camera tilt and widest zoom,
and evaluates the existing `_silhouette_noise` metric rather than inventing a second
criterion:

1. render eight Y rotations at 45° intervals;
2. use `MapCameraRig.TILT_DEGREES` and zoom stop 28;
3. render at intended world scale against a transparent target;
4. feed every mask to the checker threshold `0.04`;
5. fail when any intended view exceeds the threshold.

The module is then placed 20 times with deterministic random transforms. Review fails if
a recognisable repeated contour dominates the frame, even when the scalar gate passes.
That is a visual acceptance capture, not a unit-test substitute.

## Texture bill — 8 material tiles

All material tiles are **1024×1024 opaque RGB PNGs**. They are neutral scalar grain
duplicated into RGB: act hue belongs to ramp bands, never albedo. They contain no baked
key light, cast shadow, ambient occlusion, normal map, height map, roughness map, or
alpha. Stored-channel mean targets `0.50 ± 0.02`, allowing the existing value lock to
remain meaningful.

| Act | Ground tile | Prop tile |
|---|---|---|
| I | `materials/act1-ground-ash-loam.png` | `materials/act1-prop-charred-bark.png` |
| II | `materials/act2-ground-silted-stone.png` | `materials/act2-prop-drowned-masonry.png` |
| III | `materials/act3-ground-obsidian-dust.png` | `materials/act3-prop-obsidian-facet.png` |
| IV | `materials/act4-ground-pale-road.png` | `materials/act4-prop-inverted-hearth-stone.png` |

Every tile must pass the existing gates:

- `mipmaps/generate=true`;
- 8×8 downsampled linear-luminance spread `≤ 0.15`;
- seam ratio `≤ 3.0` on both axes;
- no alpha silhouette;
- ground↔prop value gap remains `≥ 0.272` after binding.

The later binding slice changes `MapMaterials` from one placeholder surface to an
act-row containing `ground_tile`, `prop_tile`, `grade`, and the measured tile means. It
does not add a sampler or a shader fetch.

## Grade bill — 4 painted textures

| Act | File | Direction |
|---|---|---|
| I | `grades/act1-grade.png` | crimson dusk, amber key, dense early monument contacts |
| II | `grades/act2-grade.png` | blue night, cyan distance, flooded corridor |
| III | `grades/act3-grade.png` | violet storm, obsidian court, broken-ring approach |
| IV | `grades/act4-grade.png` | umber-to-rose dawn, reversed hearth-light road |

Each grade is **512×256 RGBA**, matching the existing 2:1 world rect. RGB carries only
low-frequency top-down region/aerial grading; alpha carries contact darkening. The
procedural 256×128 `_grade_image` remains the fallback and test oracle until each painted
row lands.

Grades require mipmaps and high-quality VRAM compression, but **do not** take tile seam
or de-light gates. Their manifest kind receives grade-specific checks instead:

- exact 2:1 dimensions and RGBA channels;
- finite channel range and non-empty alpha contact mask;
- journey-axis value/saturation movement within the act's signed palette arc;
- contact blobs stay inside declared module footprints;
- no high-frequency noise that survives the widest zoom.

## Payload envelope

Godot's 4.7 import guide budgets a 1024×1024 RGBA8 VRAM-compressed texture with
mipmaps at about **1.33 MiB**. The same table scales a 512×256 grade to about
**0.167 MiB**. Those figures are planning estimates, not exported IPA byte counts.

| Component | Count × cap | Planning total |
|---|---:|---:|
| 1024² material tiles | 8 × 1.33 MiB | 10.64 MiB |
| 512×256 grades | 4 × 0.167 MiB | 0.67 MiB |
| ordinary GLBs | 23 × 192 KiB | 4.31 MiB |
| terminus GLBs | 4 × 768 KiB | 3.00 MiB |
| **complete library ceiling** | | **18.62 MiB** |

Expected real GLBs are below their hard caps, so the working package expectation is
**14–16 MiB**. Source PNG size, `.ctex` cache size, and final iOS package size are not
interchangeable. The payload slice records all three and treats the signed iOS export as
the source of truth.

One active act references at most:

- two material tiles: about 2.66 MiB;
- one grade: about 0.167 MiB;
- eight ordinary GLBs: at most 1.50 MiB of package bytes;
- one terminus: at most 0.75 MiB of package bytes.

That is a **5.1 MiB per-act file envelope**, excluding runtime vertex/index expansion,
the SubViewport, materials, and engine overhead. Those are measured rather than inferred
from GLB size. The runtime asset table must lazy-load the active act; preloading all four
would defeat the resident budget without improving the static screen.

## Godot 4.7.1 import contract

The project already enables `textures/vram_compression/import_etc2_astc=true`, but the
existing art sidecars are `compress/mode=0`. Every map PNG must be imported through the
Godot editor/import pipeline — never by hand-editing `.import` — and the generated
sidecar must assert:

```ini
compress/mode=2
compress/high_quality=true
mipmaps/generate=true
```

In Godot's importer enum, mode `2` is **VRAM Compressed**. On the Mobile renderer,
`high_quality=true` selects ASTC for mobile targets; disabling it falls back to ETC2.
Mipmaps are mandatory because the map has four discrete zoom stops and because the
current checker already treats their absence as a failure.

The ASTC slice extends `tools/check_map_assets.py` to require those three settings for
both `tile` and `grade` rows, while applying seam/de-light only to `tile`. It also fails
undeclared files under `assets/art/map/`.

## Tripo gate — independently verified 2026-08-15

### What the current API actually supports

The current generation documentation verifies that the general v2+/v3 path supports
`face_limit`, `smart_low_poly`, `quad`, `texture`, `pbr`, and `export_uv`.
`quad=true` forces FBX output. `texture=false` requests geometry without textures, and
`export_uv=false` avoids unnecessary unwrap work and model size.

The new low-poly model `P1-20260311` is different: it accepts only its listed
parameters. It supports `face_limit` from 48 to 20,000 plus `texture` and `pbr`, but it
does **not** list `smart_low_poly`, `quad`, or `export_uv`; passing them is documented to
return an error. Therefore the first trial uses P1 without those legacy switches.

The ticket's old statement that Godot 4.7.1 cannot read FBX without an external
converter is false. Godot 4.7 imports FBX through built-in `ufbx`; external FBX2glTF is
the legacy optional path. GLB is still the required shipping format because Godot marks
glTF 2.0 as recommended and Tripo's base OpenAPI model is GLB before optional conversion.

### First-trial parameter profiles

Preferred P1 trial:

```text
type=image_to_model
model_version=P1-20260311
file=<paid-account STS object for the approved concept>
model_seed=<recorded integer>
face_limit=1500 ordinary / 5000 hero
texture=false
pbr=false
```

Fallback v3.1 trial, only if P1 fails silhouette/topology review:

```text
type=image_to_model
model_version=v3.1-20260211
file=<paid-account STS object for the approved concept>
model_seed=<recorded integer>
geometry_quality=standard
face_limit=1500 ordinary / 5000 hero
smart_low_poly=true
quad=false
export_uv=false
texture=false
pbr=false
```

No request uses `quad=true`. If a generated mesh needs retopology, perform the edit in
Tripo's post-process or Blender, triangulate/validate there, and export one untextured
GLB. FBX is accepted only as a temporary interchange file, never committed.

### Paid-account and rights gate

Tripo's Terms, last updated 2025-07-11, reserve the free user's input/output rights to
Tripo, while paid users generally receive broad use and commercialisation rights and
paid inputs/outputs are excluded from AI training under the stated terms. The API FAQ
also says webapp and API billing are independent.

Operational rule: **the exact product that performs generation must be paid before the
first shipping task**. An active Studio subscription does not prove the API task is paid,
and API credits do not prove a Studio generation is paid.

No task is ordered until the ledger contains:

- current terms URL, last-updated date, and captured digest;
- product (`API` or `Studio`), paid tier/credit receipt, and account owner;
- approved input concept path and proof that Glassvow may submit it;
- task ID, model version, full parameters, prompt, negative prompt, and seeds;
- downloaded source checksum;
- Blender/hand-edit steps and tool versions;
- final GLB checksum and reviewer acceptance.

Free-tier experiments may be discarded, but their outputs, derivatives, or edited
meshes never enter the repository or become a concept source for a shipping asset.

## Delivery slices after this decision

1. **Import/manifest slice** — add `map-assets.json`, per-act lazy binding, and ASTC/
   grade-aware checker rules, with fixtures only.
2. **First-module slice** — after paid-account evidence, land one ordinary GLB plus the
   Godot GPU silhouette raster gate and deterministic 20-placement capture.
3. **Act kits** — land ordinary modules act by act, each under its own reviewable PR.
4. **Grades and termini** — painted grades and hand-curated hero assets, with device
   captures and no story-name dependency in file paths.
5. **Payload closeout** — measure source, imported cache, exported iOS package delta,
   and active-act runtime memory; update this envelope with evidence.

No visual asset order was placed in the decision slice.

## Primary sources

- [Tripo generation API](https://platform.tripo3d.ai/docs/generation)
- [Tripo post-process/conversion API](https://platform.tripo3d.ai/docs/post-process)
- [Tripo API FAQ — independent webapp/API billing](https://platform.tripo3d.ai/docs/faq)
- [Tripo Terms of User Agreement](https://www.tripo3d.ai/terms)
- [Godot 4.7 available 3D formats](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)
- [Godot 4.7 importing images](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_images.html)
- [Godot 4.7 ResourceImporterTexture](https://docs.godotengine.org/en/4.7/classes/class_resourceimportertexture.html)

Repo inputs: `docs/map-concept-brief.md`, issue #207's resolution,
`docs/story-candidates/outlines/asset-inventory.md`, `docs/story/03-acts.md`,
`presentation/map/map_scene.gd`, `presentation/map/map_materials.gd`,
`presentation/map/map_regions.gd`, and `tools/check_map_assets.py`.
