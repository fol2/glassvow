---
title: "The textured Studio path is the HD Model tab, now --textured on the script"
date: 2026-08-24
last_updated: 2026-08-25
category: tooling-decisions
module: assets/art/map
problem_type: tooling_decision
component: tooling
severity: high
applies_when:
  - "A Studio-converted GLB comes back with textures 0 / images 0"
  - "Wanting a baked albedo out of Tripo Studio rather than bare geometry"
  - "tools/studio_image_to_glb.ts output arrives in dozens of open shells"
  - "A Studio export blob is built in the page but never reaches disk"
  - "Spending Studio credits on a textured generate"
root_cause: wrong_tool_surface
resolution_type: tooling_addition
related_components:
  - "development_workflow"
  - "documentation"
tags: [tripo, studio, texture, glb, hd-model, smart-mesh, chrome, download, pna, dry-run]
---

# The textured Studio path is the HD Model tab, now `--textured` on the script

## Context

`tools/studio_image_to_glb.ts` is one driver with two tabs. The workflow is
still **image in → arguments → 3D model out**. Smart Mesh (`tab=low_poly`) is
the default and still has **no texture stage** — that is the 23 map kits,
bought untextured on purpose and surfaced by triplanar projection. Textured
game content uses `--textured`, which stays on **HD Model** (`tab=high_detail`)
and drives the Geometry & Texture popover.

Until 2026-08-25 the script always clicked away from HD Model. The Vigil
(`act1-vigil-hall.glb`) was generated on that tab by hand, then fetched back
through `--task-id`. That gap is closed: `--textured` is the HD path, and
`--dry-run` / `--smoke-run` exist so Generate is not clicked until the form
is proven.

It stopped being invisible when the map needed a BUILDING. A first attempt at
the Vigil through the script measured:

```
textures: 0   images: 0   materials: 1
attributes: ['NORMAL', 'POSITION']
```

and 66 connected shells. Welding barely moved it (66 → 62 at a 1 mm tolerance),
and `trimesh.boolean.union(..., engine="manifold")` refused outright with
"Not all meshes are volumes!" — only 2 of 70 pieces were watertight, so the
union trick that built the four termini does not apply. Voxel remeshing did
produce a single sealed body at 6,324 faces, but lost the chimney and rounded
every edge.

The conclusion drawn from that — "Tripo does not give us textures, extending
the pipeline to a textured mode is real work on a fragile automation" — **was
wrong**, and wrong in a specific way worth naming: it generalised from the one
tab the script happens to drive to the product as a whole.

## What is actually there

**`HD Model` is the DEFAULT tab on a cold `/workspace/generate`.** Until
`--textured`, the script actively clicked away from it onto Smart Mesh. It
carries a `General Settings > Geometry & Texture` popover that Smart Mesh does
not have at all:

| Control | Default | Chosen for this repo, and why |
|---|---|---|
| Ultra Mesh Quality | ON | kept |
| AI Complete | OFF | kept — it invents unseen backsides |
| **Texture** | **ON** | the whole difference |
| Texture Quality | 4K | **2K** — the GLB embeds it, and a hero row caps at 768 KiB |
| PBR | ON | **OFF** — `map_vigil.gdshader` is `unshaded` and samples one map, so metallic/roughness/normal are three more images inside the same byte cap for nothing on screen |
| Topology | Triangle | kept |
| Polycount | **2,000,000** | **6,000**, against `triangle_max: 8000` |

The Generate price moves with those choices — 55 credits at the defaults, 40
after 2K + PBR off. That is why Generate matching is price-agnostic
(`Generate 40` / `Generate 100 65`) and why `--smoke-run` prints
`quoted_credits` before anyone spends them.

Everything else matches the script's existing notes: privacy needs a real mouse
click (`element.click()` does not open the listbox; the HD default is
`Sharing Only`, not `Public`), the numeric box needs triple-click → type →
`Tab`, `Escape` closes the popover, and `Generate Multi-Views` appears after
upload and must not be clicked. One new dialog: a first-run **`View Your
Model`** rotate/pan/zoom tutorial fires right after Generate, with an `OK`
button. It is not the `Retry for better results` dialog and needs its own
dismissal (`dismiss_ok` in the export loop). A **`Guide`** panel follows it
and is left up — the 2026-08-25 generate reached Export without dismissing it.

Two file inputs exist on the page. The image one is
`accept="image/png,image/webp,image/jpg,image/jpeg"`, class
`opacity-0 cursor-pointer inset-0 absolute`; the other (`.fbx,.obj,.stl,.glb`,
carrying `z-2`) is the asset importer. Do not target either by index.

## What came out

One mesh, one surface, `POSITION / NORMAL / TEXCOORD_0`, 5,615 triangles,
604,608 bytes with a 2048×2048 JPEG baseColor embedded at 413,216 of them, and
`min Y` exactly 0.0 as exported. Two connected components once welded — the hall
and its smoke — against the 66 unusable shells the other tab gave for the same
concept image.

## The export downloads, but not to disk

Under the Chrome extension the page genuinely builds the file: hooking
`URL.createObjectURL` and `HTMLAnchorElement.prototype.click` catches a
604,604-byte blob with `download="act1-vigil-hall.glb"`. Chrome then writes
nothing. The profile has no override — `download.default_directory` unset,
`prompt_for_download` unset — and no `.glb` appears anywhere under the home
directory.

Piping the blob out to a local receiver does not work either: `fetch` from the
page to `http://127.0.0.1:<port>` **hangs forever**, neither resolving nor
rejecting, including with `Access-Control-Allow-Private-Network: true` on the
receiver. Two adjacent dead ends worth knowing before re-walking them: a
single-threaded `http.server.HTTPServer` is separately starved by Chrome
preconnects and must be `ThreadingHTTPServer`, and that was *not* the cause
here — a plain `curl` to the fixed server succeeds while the page's fetch still
hangs.

**So generate by hand, then take the bytes through the script:**

```bash
bun tools/studio_image_to_glb.ts --task-id <task-id> --out <path>
```

Its CDP `createObjectURL` hook writes the file (8.8 s warm), and the byte count
matched the in-page blob at 604,608 vs 604,604.

`--task-id` re-export does not set the form. JSON now omits `faces` /
`topology` on that path (`form_state: "unset_for_reexport"`) so they cannot be
mistaken for the task that ran. The path and the byte count are the real
fields.

## The export panel differs too

`File Name` / `Format` / `Texture Resolution`, with Format already defaulting to
**GLB** and resolution to **2k (Current)** — so the script's FBX→GLB combobox
dance is dead code on this tab. The toolbar `Export` only opens the panel; a
second `Export` inside it does the work.

## The script now takes that path

`--textured` stays on HD Model, drives the Geometry & Texture controls above,
dismisses **View Your Model** / **OK** (the existing export loop already had
`dismiss_ok`), and matches Generate without encoding a price. The export loop
and the download hook are unchanged.

Credit safety, in this order. Do not skip:

```bash
# 1. dry-run — no Chrome, no credits. Prints the planned arguments.
bun tools/studio_image_to_glb.ts --dry-run --textured \
  --image assets/art/map-concepts/act1-vigil-hall.png \
  --out /tmp/glassvow-studio-act1-vigil-hall-textured.glb

# 2. smoke-run — Chrome + login + form. Generate is not clicked.
bun tools/studio_image_to_glb.ts --smoke-run --textured \
  --image assets/art/map-concepts/act1-vigil-hall.png \
  --out /tmp/glassvow-studio-act1-vigil-hall-textured.glb

# 3. generate — spends the quoted HD credits (walked: 40 after 2K + PBR off).
bun tools/studio_image_to_glb.ts --textured \
  --image assets/art/map-concepts/act1-vigil-hall.png \
  --out /tmp/glassvow-studio-act1-vigil-hall-textured.glb
```

`--smoke-run` is `--stop-before-generate` plus a form snapshot, the live
Generate labels, and `quoted_credits` parsed from the last number on that
label. `would_spend_credits` is false until step 3.

HD defaults for this repo, not Studio's:

| Flag | Default with `--textured` |
|---|---|
| `--faces` | 6000 |
| `--topology` | triangle |
| `--texture` | on |
| `--texture-quality` | 2k |
| `--pbr` | off |
| `--ultra-mesh` | on |
| `--ai-complete` | off |
| `--privacy` | private |
| `--tab` / `--model` | hd-model |

Smart Mesh remains the no-flag default (`--faces 800 --topology quad`, no
texture). `--texture on` on Smart Mesh is refused.

## Remaining Studio features the script still does not drive

Logged so a later pass does not rediscover them as if they were missing from
the product. They are available in Studio; they are not this pipeline.

- **rig / animation**
- **Generate Multi-Views** (appears after upload; must not be clicked)
- **PBR metallic/roughness/normal maps** (`--pbr on` is wired, default off)
- **4K texture** (`--texture-quality 4k` is wired; blows hero `bytes_max`)
- **8K Texture trial** (Studio upsell; not a pipeline flag)
- **AI Complete** (`--ai-complete on` is wired; invents unseen backsides)
- **Ultra Mesh Quality off** (`--ultra-mesh off` is wired)
- **FBX / OBJ / STL / USD / 3MF** export — this driver writes GLB
- **Public or Sharing Only** privacy (`--privacy` is wired; default Private)
- **Godot DCC Bridge** auto-import
- **Tripo OpenAPI / platform generation** — forbidden; Studio is the paid product

The dry-run JSON field `remaining_studio_features` prints this same list.
`--help` documents the flags, not the leftover Studio surfaces.

## Measured 2026-08-25 (this tree)

Credit order was dry-run → smoke-run → generate. Smoke quoted **Generate 40**
and `would_spend_credits: false`. Generate then spent those 40 on HD Model
from `assets/art/map-concepts/act1-vigil-hall.png`:

| | this run | signed shipping Vigil |
|---|---|---|
| task | `4c5f8b19-c33d-4014-ade5-a38abc094c65` | `5f44379a-face-4238-a5eb-4d2ec18a5663` |
| bytes | 597,376 | 604,608 |
| triangles | 5,530 | 5,615 |
| attributes | POSITION, NORMAL, TEXCOORD_0 | same |
| textures / images | 1 / 1 JPEG (410,810) | 1 / 1 JPEG (413,216) |
| baseColor / PBR maps | yes / no | yes / no |
| min Y | 0.0 | 0.0 |
| `inspect_glb` vs `act1-vigil` row | no findings | accepted |

The signed shipping mesh is unchanged. This run is pipeline proof that
`--textured` writes a game-content GLB; replacing `vigil-hall.glb` still
needs a signed 20-placement.
