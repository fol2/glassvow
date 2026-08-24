---
title: "The textured Studio path is the HD Model tab the script clicks away from"
date: 2026-08-24
last_updated: 2026-08-24
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
root_cause: wrong_tool_surface
resolution_type: documented_workaround
related_components:
  - "development_workflow"
  - "documentation"
tags: [tripo, studio, texture, glb, hd-model, smart-mesh, chrome, download, pna]
---

# The textured Studio path is the HD Model tab the script clicks away from

## Context

`tools/studio_image_to_glb.ts` drives Studio's **Smart Mesh** tab
(`tab=low_poly`). Everything it does there is correct, and its walked-path
header is still accurate for that tab. But Smart Mesh has **no texture stage at
all**, so every GLB the script has ever produced is bare geometry — which was
invisible as a limitation for the 23 map kits, because those are deliberately
bought untextured and surfaced by triplanar projection.

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

**`HD Model` is the DEFAULT tab on a cold `/workspace/generate`.** The script
actively clicks away from it. It carries a `General Settings > Geometry &
Texture` popover that Smart Mesh does not have at all:

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
after 2K + PBR off — so the script's hardcoded `"Generate 100 65"` label match
would not fire on this tab even if it went there.

Everything else matches the script's existing notes: privacy needs a real mouse
click (`element.click()` does not open the listbox; the HD default is
`Sharing Only`, not `Public`), the numeric box needs triple-click → type →
`Tab`, `Escape` closes the popover, and `Generate Multi-Views` appears after
upload and must not be clicked. One new dialog: a first-run **`View Your
Model`** rotate/pan/zoom tutorial fires right after Generate, with an `OK`
button. It is not the `Retry for better results` dialog and needs its own
dismissal. A **`Guide`** panel follows it.

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

Read its JSON summary with care. For a `--task-id` re-export it still prints
`"Studio Smart Mesh Export"` and reports `faces` and `topology` **from its own
form state, which it never set for this run** — those fields were `800` and
`quad` for a 5,615-triangle triangle mesh. The path and the byte count are real;
those two are not.

## The export panel differs too

`File Name` / `Format` / `Texture Resolution`, with Format already defaulting to
**GLB** and resolution to **2k (Current)** — so the script's FBX→GLB combobox
dance is dead code on this tab. The toolbar `Export` only opens the panel; a
second `Export` inside it does the work.

## If the script is ever extended

The gap is a tab choice and a settings popover, not an architecture problem.
What it would need: a `--textured` flag that stays on `HD Model`, drives the six
`Geometry & Texture` controls above, dismisses the two first-run dialogs, and
drops the `"Generate 100 65"` label match for something that does not encode a
price. The export loop and the download hook already work unchanged.
