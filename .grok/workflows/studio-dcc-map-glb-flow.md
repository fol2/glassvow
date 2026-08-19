# studio-dcc-map-glb — observed flow

**Superseded 2026-08-20.** The live generate driver is
`tools/studio_image_to_glb.ts` (Chrome for Testing `--headless=new`,
port 9335). gstack `chrome-headless-shell` 500s on Export. Land with
`tools/land_map_glb.py`. Below is the original gstack walk, kept as
history of the clicks.

Walked 2026-08-19 on the **already-logged-in headless** gstack daemon
(`Mode: launched`, cookies from Chrome Default, header **3200**, member
`professional`, greeting `Hi, KMaster!`). No new Chrome. No API.

## Session

1. Chrome Default cookie DB is the source:
   `~/Library/Application Support/Google/Chrome/Default/Cookies`.
   Auth cookie is `ory_kratos_session` on host_key **`.tripo3d.ai`**.
2. `cookie-import-browser Chrome --domain .tripo3d.ai` imported **14**.
   `--domain studio.tripo3d.ai` imported **2**.
   `--domain .studio.tripo3d.ai` imported **1**.
   `--domain tripo3d.ai` (no dot) imported **0**.
3. After reload: no Sign up/Log in, credits 3200.

If the daemon is already on that session, do not disconnect and do not
import again.

## Generate form (clicked, not guessed)

Start: `https://studio.tripo3d.ai/` is the marketing home.
Click **3D Workspace** → `https://studio.tripo3d.ai/workspace/generate`.

A cold `browse goto https://studio.tripo3d.ai/workspace/generate` returned
`500 Internal Server Error / Error creating WebGL context` on this headless
daemon. Reloading that URL stayed 500. Going Home then clicking 3D Workspace
loaded the form (52 buttons). Do not deep-link the generate URL.

Pinia `workspace-generate-store` on arrival:

| field | value |
|---|---|
| mode | `imageToModel` |
| tab | `high_detail` (HD Model) |
| credits | 3200 |
| member | professional |

Visible: **HD Model** / **Smart Mesh**. HD Generate is **55**.
Privacy combobox default **Sharing Only**. File input
`accept=image/png,image/webp,image/jpg,image/jpeg`.

Click **Smart Mesh** (`@e25`). Store becomes `tab=low_poly`.
Generate button text **Generate 100 65**. Body: Topology, Privacy,
AI Model **P2.0 - Preview**.

Click **Topology**. Popover measured:

| control | Studio default | CLI default |
|---|---|---|
| Quad New | `aria-pressed=true` | on (`--topology quad`) |
| Triangle | `aria-pressed=false` | opt-in (`--topology triangle`) |
| slider | 5000 (min 500, max 25000) | `--faces` (default 1500) |
| textbox | 5000 | `--faces` |

CLI default is Quad, not Triangle. `--faces` is Studio's face slider.
Same image, same 1500: Triangle Export **1492** tris; Quad Export **3306**
tris. Kit cap is 600–2500 *triangles*. Pick `--faces` for that budget
(~700–1000 Quad, or 1500 Triangle). Face count can reset; set it
immediately before Generate. Escape closes the popover.

Click Privacy combobox. Options: **Public**, **Private**, **Sharing Only**.
Click `[role=option] Private`. Combobox reads **Private**.

Do **not** click Generate in this walk. Do **not** download
`project.model_url` — on task `38b53fc2-…` it ends with `_meshopt.glb`.

## Generate (walked 2026-08-19 18:01, headless)

Upload first image file input. Ready = `imageToModel.key` +
`image_audit_result=pass`. A **Generate Multi-Views** button also appears;
do **not** click it. Click **Generate 100 65**.

Credits 3200 → **3135** (65). URL
`/workspace/generate/e0f6f500-1b10-453b-b5c6-7b1fc70236d5`. Generating
finished in ~15s. `project.model_url` is `*_meshopt.glb`.

Headless: THREE.WebGLRenderer fails; **Export is not in the DOM**.

## Export (same task, headed gstack Chromium)

`hasExport=true`. Toolbar **Export** opens a dialog: File Name, Format
combobox, Send To, Export. Format options: **USD / FBX / OBJ / STL / GLB /
3MF**. Quad generate 2026-08-19 18:07 defaulted **FBX** — blob was a zip
of `low-poly+box+3d+model.fbx`, magic `PK`. Always click Format →
`[option] GLB` (measured selected after the click; combobox text `GLB`)
before the dialog Export. Hook `createObjectURL` first. Magic must be
`glTF`; reject zip.

Triangle walk blob 37648 bytes, 1492 tris. Manual GLB re-export of the
Quad task: 80960 bytes, 3306 tris. POSITION+NORMAL, no texture/animation.

CLI: `tools/studio_image_to_glb.py` (default `--headed`, `--topology quad`,
`--privacy private`, `--faces 1500`).

Headless `/assets` grid loads (no WebGL). Headless `/3d-model/<id>` and a
cold `/workspace/generate` both 500 `Error creating WebGL context`. Do not
treat the asset viewer as a headless download. Headed Export (Format GLB)
is the working blob path. Manage on `/assets` shows Batch Export; not yet
walked to a GLB.

Quad@1000 Smart Mesh (standing-monument, 2026-08-19 18:26): task
`ccdbeaff-…`, credits 3070→3005, privacy Private, Export GLB 45596 bytes,
1824 triangles (inside 600–2500). `inspect_glb` still flags 2 connected
islands.

## Driver

`.grok/workflows/studio-dcc-map-glb.rhai` only runs:

```
python3 tools/studio_image_to_glb.py --image … --out /tmp/glassvow-studio-<id>.glb \
    --faces 1500 --topology quad --privacy private --model smart-mesh
python3 tools/land_map_glb.py --asset … --src /tmp/… --gates
```

## Land (repo, already ran)

`python3 tools/land_map_glb.py --asset <id> --src /tmp/….glb --gates`
