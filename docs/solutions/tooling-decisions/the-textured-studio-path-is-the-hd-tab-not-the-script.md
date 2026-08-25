---
title: "The textured Studio path is the HD Model tab the script clicks away from"
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
  - "Implementing a --textured mode in tools/studio_image_to_glb.ts"
root_cause: wrong_tool_surface
resolution_type: documented_workaround
related_components:
  - "development_workflow"
  - "documentation"
tags: [tripo, studio, texture, glb, hd-model, smart-mesh, download, implementation-spec]
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

## Implementation spec: adding `--textured` to `tools/studio_image_to_glb.ts`

Everything below is written against the script's existing shape so it can be
implemented without re-walking the site. **Read the confidence markers.**
`[measured]` was observed directly in a driven browser session on 2026-08-24.
`[in-tree]` is already proven by code in this repo. `[PROBE FIRST]` is not
known and must be established before writing the branch — implementing it from
a guess is how this doc would become the thing it warns about.

### What the flag changes, and what it must not

`--textured` stays on the HD Model tab and drives the `Geometry & Texture`
popover. It shares everything else with the existing path: cookie login, the
warm Chrome on port 9335, `--out`, the `createObjectURL` download hook, and the
`--task-id` re-export. It must **not** touch the Smart Mesh branch: that branch
is correct for the 23 untextured kits and is the one the map still generates
scenery with.

### Step 0 — the one unknown, and how to settle it

The script already reads the active tab from the Pinia store rather than from
button text (`tools/studio_image_to_glb.ts:445`) `[in-tree]`:

```js
document.querySelector("#__nuxt").__vue_app__.config.globalProperties
  .$pinia._s.get("workspace-generate-store").$state.tab
```

Smart Mesh reports `low_poly` `[in-tree]`. **The value HD Model reports was
never read** `[PROBE FIRST]` — evaluate the expression above on a cold
`/workspace/generate` and record it. Every `tab` comparison in the new branch
keys off that literal. Do not assume `"hd"`, `"default"` or `""`.

The tab **button** needs no probe: the script already clicks it by exact label
in its `reset_via_hd` action (`tools/studio_image_to_glb.ts:546-549`)
`[in-tree]`:

```js
[...document.querySelectorAll("button")]
  .find(x => (x.innerText || "").replace(/\s+/g, " ").trim() === "HD Model")
```

### Step 1 — what `detect()` must additionally return

Extend the existing flat state object; do not build a second loop. The
`Geometry & Texture` controls live in a **popover that is closed by default**
`[measured]`, so `detect()` reports `geomOpen` and every control reads as
`null` while it is shut — the decide step opens it first and re-detects.

| Key | Source | Notes |
|---|---|---|
| `tab` | Pinia, as above | compare against the Step 0 literal |
| `geomOpen` | is the popover mounted | its trigger is a row labelled `Geometry & Texture` under a `General Settings` heading `[measured]` |
| `texture` | `[role=switch]` in the popover | ON by default `[measured]` |
| `pbr` | `[role=switch]` in the popover | ON by default `[measured]`; must end OFF |
| `texQuality` | the selected one of `2K` / `4K` / `8K` | `4K` by default `[measured]`; `8K` is trial-gated and must not be chosen |
| `topology` | `Quad` / `Triangle` | `Triangle` by default `[measured]` |
| `polycount` | the numeric text input beside the slider | **2000000** by default `[measured]` |
| `privacy` | existing combobox probe | HD defaults to `Sharing Only`, not `Public` `[measured]` |
| `genLabel` | the Generate button's text | see Step 3 |

`[role=switch]` and `[role=combobox]` are both present on this page
`[measured]` — the accessibility tree exposed them — but **which switch is
which was not disambiguated** `[PROBE FIRST]`. Two more switches (`Generate in
Parts`, `8K Texture`) sit outside the popover in a `Members Only` block
`[measured]`, so index-based selection across the whole document will pick the
wrong control. Scope the query to the popover subtree and identify each switch
by its adjacent label text.

### Step 2 — the act blocks, and which need a real mouse

Two click mechanisms already exist in the script: `ev(cdp, "...btn.click()")`
for elements that honour a synthetic click, and `clickxy(cdp, x, y)` for those
that do not. The existing header records that the privacy listbox is in the
second class `[in-tree]`. From this session:

- **Tab, toggles, quality/topology segment buttons, popover trigger** —
  synthetic `.click()` was sufficient `[measured]`.
- **Privacy combobox and its options** — real mouse, unchanged from the
  existing branch `[in-tree]`.
- **Polycount box** — triple-click, `Input.insertText`, then `Tab` to commit,
  exactly as the existing faces box; `.value =` does not drive Vue `[in-tree]`,
  and the same sequence worked here `[measured]`. `Escape` closes the popover
  `[measured]`.

Target state: Texture ON, PBR **OFF**, quality **2K**, topology Triangle,
polycount **6000**, privacy Private.

### Step 3 — do not gate on the Generate label

The existing branch waits for a literal `Generate 100 65`. On HD the label
carries a price that **moves with the settings**: `Generate 55` at the 4K/PBR
defaults, `Generate 40` after 2K + PBR off `[measured]`. Match the leading word
and treat the number as data, or the branch breaks the first time Tripo
reprices.

### Step 4 — ordering constraints that are not obvious

1. Set the popover controls **before** Generate; the price change is the
   confirmation they took.
2. Upload **after** the tab is settled. `Generate Multi-Views` appears
   post-upload and must not be clicked `[measured]` — same trap as Smart Mesh.
3. Two **first-run dialogs** fire after Generate on this tab and are not the
   Smart Mesh `Retry for better results` dialog `[measured]`: `View Your Model`
   (rotate/pan/zoom tutorial, dismissed by an `OK` button) then `Guide` (a
   numbered list, dismissed by its close control). They are first-run, so a
   profile that has seen them will not show them — the branch must tolerate
   both presence and absence rather than waiting for either.
4. Generation is **minutes, not seconds** `[measured]`. The existing
   readiness signal is unchanged and correct: a visible `Export` button in the
   DOM. Do not treat the absence of `Generating` text as done.

### Step 5 — the export panel

Simpler than Smart Mesh, and the existing format-switching code is dead here:
`Format` already defaults to **GLB** and `Texture Resolution` to **2k
(Current)** `[measured]`. The toolbar `Export` only **opens the panel**; a
second `Export` inside the panel does the work `[measured]`. `File Name` is a
plain text input and is worth setting so the blob's `download` attribute is
meaningful.

### Step 6 — getting the bytes out

Unchanged from the existing branch, and this is the part not to redesign: the
CDP `createObjectURL` hook is what writes `--out`. The alternatives were tried
and both fail — see **The export downloads, but not to disk** above. Under a
browser-extension surface the blob is built and Chrome writes nothing, and a
page `fetch` to `http://127.0.0.1:<port>` hangs without resolving or rejecting.

### Step 7 — what to assert before believing it works

`tools/map_asset_checks.py` will not catch a mis-driven form; it validates the
artifact, not the route. Check the exported GLB directly for: exactly one mesh
and one primitive; attributes `POSITION`/`NORMAL`/`TEXCOORD_0`; `images` length
1 with a `mimeType` of `image/jpeg`; triangle count at the requested polycount's
order of magnitude, not 2,000,000. A GLB with `textures: 0` means the run
silently drove Smart Mesh — which is exactly the failure this whole document
exists to describe.

### One reporting bug to fix while in here

On a `--task-id` re-export the script prints `"Studio Smart Mesh Export"` and
reports `faces` and `topology` from its own form state, which it never set for
that run. For a hand-generated task those two fields are fiction — measured at
`faces: 800, topology: quad` for a 5,615-triangle triangle mesh. Either omit
them when `--task-id` is supplied or read them back from the exported GLB.

