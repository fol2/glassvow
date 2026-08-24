---
title: "The generating product is Studio; a SKIP is not the silhouette gate"
date: 2026-08-19
last_updated: 2026-08-20
category: tooling-decisions
module: assets/art/map
problem_type: tooling_decision
component: tooling
severity: high
applies_when:
  - "Generating or landing any shipping map kit GLB"
  - "Choosing Tripo Studio versus the Tripo API"
  - "Scoring mesh silhouette quality for a present map GLB"
  - "Recording paid-account evidence in provenance.json"
root_cause: missing_tooling
resolution_type: tooling_addition
related_components:
  - "development_workflow"
  - "documentation"
tags: [tripo, studio, map-glb, silhouette, provenance, no-api, verification]
---

# The generating product is Studio; a SKIP is not the silhouette gate

## Context

The map library is 27 untextured GLBs. Tripo Studio and the Tripo API are
independently billed. The asset bill already states the operational rule: the
exact product that performs generation must be paid before the first shipping
task — a Studio subscription does not prove an API task is paid, and API
credits do not prove a Studio generation is paid
(`docs/map-scene-asset-bill.md:349-351`).

This session locked the generating product as **Studio**. The owner subscribed
Studio Pro (3000 monthly credits; header showed 3200 including leftover free)
and forbade `openapi.tripo3d.ai` / `platform.tripo3d.ai` generation. The
receipt lives on `assets/art/map/provenance.json` under `paid_product` with
`generation_surface: Studio` and `api_forbidden: true`
(`assets/art/map/provenance.json:27-28`). That receipt does not pay the API.

Until this work, a present kit GLB could not fail the production-camera
silhouette check: the checker printed SKIP. A named check that prints SKIP and
continues is not a Gate (`CONCEPTS.md`). Ticket #292 required the GPU
raster at `MapCameraRig.TILT_DEGREES`, widest zoom 28, eight Y rotations, noise
above 0.04 fails.

## Guidance

1. **Generate on the product you paid.** For this kit that is headed
   Studio (`studio.tripo3d.ai`), image-to-3D / Smart Mesh, using the monthly
   Studio credits. Do not send an `Authorization: Bearer` call to the OpenAPI
   hosts. Do not treat leftover free credits as a generation source.

2. **Record the product before the first mesh.** `paid_product` is the receipt;
   `records[]` is per-asset. A record's `source` must be `Studio` when Studio
   produced the file. Keep `api_forbidden` true while this receipt is the one
   on file.

3. **Ordinary profile (Studio UI equivalent of the bill's P1 trial).**
   Studio topology default **Quad**; privacy default **Private**;
   `texture=false`, `pbr=false`, no rig, no animation. `--faces` is the
   Studio slider (variable per asset), not the shipping triangle count.
   Measured on the same slab concept: Triangle@1500 → 1492 tris; Quad@1500
   → 3306 tris. Kit cap is 600–2500 *triangles*, so Quad needs a lower
   `--faces` (~700–1000) to stay inside it. Export Format must be **GLB**
   — the dialog can default FBX (a zip). The first landed module used
   Studio's **Smart Mesh P2.0 Preview** (task id on the accepted provenance
   record), not the API model id `P1-20260311`. That is a Studio-surface
   fact, not an API fallback.

4. **Land one untextured GLB** at the manifest path. The first ordinary row is
   `shared-road-slab-a` → `assets/art/map/geometry/shared/road-slab-a.glb`
   (`assets/art/map/map-assets.json:5`). Contract: 600–2500 triangles, GLB
   ≤192 KiB, one mesh, one surface, normals, no animation/skeleton/texture,
   pivot on ground Y, Y-up metres.

5. **Score silhouette at the production camera, not in SKIP.**
   `tools/raster_map_silhouette.gd` imports the GLB and writes eight alpha
   masks. Python scores each with `silhouette_noise` (3×3 opening residue /
   opaque area) and fails above `SILHOUETTE_NOISE` 0.04
   (`tools/map_asset_checks.py:24-25`, `tools/map_asset_checks.py:321-341`). Camera constants come from
   the shipping rig: `TILT_DEGREES = -55.0`, `ZOOM_STOPS[3] = 28.0`
   (`presentation/map/map_camera_rig.gd:12-15`; harness `WIDEST_STOP = 3`
   in `tools/raster_map_silhouette.gd:16-18`).

6. **Do not `--headless` the raster.** The dummy renderer returns an empty
   mask. The Python gate launches a positioned windowed Godot, and on Linux
   wraps `xvfb-run` (`tools/map_asset_checks.py:409-412`). CI installs xvfb
   for the same reason.

7. **A 20-placement PNG is review evidence, not the scalar gate.** The
   harness writes a *lit 5×4 clay grid* a human can read
   (`docs/reviews/292/road-slab-a-20.png`). A white unshaded scatter is not
   that evidence — see
   [A signable 20-placement review is a lit 5×4 clay grid](a-signable-20-placement-review-is-a-lit-clay-grid.md).
   Recognisable contour repetition is still a human verdict. The noise
   number passing does not close the visual clause. #292 closed after the
   owner signed the clay grid (same item, different size and angle).

8. **The Godot DCC Bridge is a land hop, not a generating product.** It is the
   Studio frontpage talking to a local editor plugin
   (https://www.tripo3d.ai/blog/tripo-dcc-bridge-for-godot). It does not call
   `openapi.tripo3d.ai` / `platform.tripo3d.ai` generation. Prefer it over a
   manual GLB download once the plugin is running in the Godot editor. Override
   its defaults: texture off, auto material off, auto placement off — this kit
   is untextured and lands at the manifest path, not wherever the plugin drops
   a scene. If the plugin is missing, Studio download to
   `/tmp/glassvow-studio-<asset_id>.glb` is the same generating product.
   Do not vendor the add-on until its license and hosts are inspected
   (`addons/tripo*` is gitignored). Workflow: `.grok/workflows/studio-dcc-map-glb.rhai`.

9. **Do not send an LLM to click Studio.** studio-dcc-map-glb-2 / studio-generate
   spent 19 min, 5.4M tokens, 66 tools, 54 reasoning loops on trial-and-error:
   multi-view (Generate disabled), Pinia dumps, `model_url` meshopt download,
   blob-hook Export. The sequence that worked is now
   `tools/studio_image_to_glb.ts` (generate; `studio_image_to_glb.py` is a
   bun wrapper) and `tools/land_map_glb.py` (land). The workflow agents run
   those commands; they do not browse. Default generate is **Chrome for
   Testing `--headless=new`** on port 9335 (Metal WebGL). gstack
   `chrome-headless-shell` 500s on `/workspace/generate` — do not use it.
   The old gstack clicker is archived at
   `tools/archive/studio_smart_mesh.py`. Cookies come from Chrome Default
   (`ory_kratos_session` on `.tripo3d.ai`) cached at
   `~/Library/Caches/glassvow/studio-cookies.json`. Never spawn extra
   Default Chrome. Never `--kill-chrome` unless asked.

## Why This Matters

Paying the wrong Tripo product produces meshes this repo cannot ship: free-tier
outputs stay Tripo's, and an API download against a Studio-only receipt is not
a paid generation of the product that ran. The first session that picked Tripo
over Meshy did not settle Studio vs API; that gap is how an agent reaches for
`curl` to OpenAPI with a Studio cookie.

The SKIP was the same silent-pass disease as grading `--check-only` by exit
code: the name of a gate with no failure signal. Once a GLB is present, the
checker must raster it or fail closed (`gpu-raster`), not print SKIP.

## When to Apply

- Any of the remaining kit/terminus GLBs (7 ordinary payloads are landed;
  the rest live on #293 / #294).
- Any temptation to "just hit the API, it is cheaper / scriptable."
- Any change to `tools/map_asset_checks.py` or `tools/raster_map_silhouette.gd`.
- Before landing the next module: provenance accepted, geometry gates,
  silhouette scores, and a *readable* 20-placement visual review.

## Examples

**Before (not a gate):** a present GLB printed `gpu-silhouette SKIP until #292`
and the checker exited 0.

**After (first module, this tree):** `shared-road-slab-a` is an accepted Studio
record (`source: Studio`, `verdict: accepted`, 1560 triangles, 38656 bytes,
Blender missing so the Studio download was kept as-is). Independent re-run of
`python3 tools/check_map_assets.py` printed eight `gpu-silhouette` lines per
present GLB, max noise on slab-a 0.0021 ≤ 0.04, then
`map assets OK (7 payload files; declared absence uses fallbacks)`.

**Do not claim from this session:** a measured Studio credit drop
(`paid_product.credits_balance` and `usage_history` still show only the
2026-08-19 +3000 top-up). Godot on PATH here printed `4.7.2.stable`; the
contract pin was still 4.7.1 during this session and changed to 4.7.2 on
2026-08-21. #292 is closed (owner signed the clay-grid
20-placement). Remaining generate is #293.

## Related

- [Put the gate where the change is deterministic](../conventions/put-the-gate-where-the-change-is-deterministic.md)
- [Capture through a long-lived host](./long-lived-capture-host-not-process-per-shot.md)
- [A signable 20-placement review is a lit 5×4 clay grid](a-signable-20-placement-review-is-a-lit-clay-grid.md)
- `docs/map-scene-asset-bill.md` — generating-product rule and ordinary contract
- GitHub #292 (closed), #293 (open), #289, #207, #291
