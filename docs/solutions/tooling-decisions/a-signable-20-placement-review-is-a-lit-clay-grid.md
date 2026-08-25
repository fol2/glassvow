---
title: "A signable 20-placement review is a lit 5×4 clay grid, not white scatter"
date: 2026-08-20
last_refreshed: 2026-08-25
category: tooling-decisions
module: assets/art/map
problem_type: tooling_decision
component: tooling
severity: high
applies_when:
  - "Capturing 20-placement review evidence for a map kit GLB"
  - "Asking a human to sign a same-item or repetition review from a PNG"
  - "Choosing silhouette-mask rendering versus lit clay for a review capture"
  - "Changing tools/raster_map_silhouette.gd --review= output"
  - "Claiming a kit module's visual review is closed"
root_cause: missing_tooling
resolution_type: tooling_addition
related_components:
  - "development_workflow"
  - "documentation"
tags:
  - "20-placement"
  - "review-capture"
  - "clay-grid"
  - "map-glb"
  - "evidence-harness"
  - "human-review"
  - "verification"
---

# A signable 20-placement review is a lit 5×4 clay grid, not white scatter

## Context

#292 required a deterministic 20-placement capture so a human could reject
recognisable contour repetition even when the scalar silhouette-noise Gate
passed. The first PNG the harness wrote for that clause was unreadable:
twenty unshaded white blobs on a large ground at production tilt and review
zoom. The owner rejected that capture as unreadable and refused to sign.

A file existing is not a [Gate](../../../CONCEPTS.md). GPU silhouette had already
passed (eight yaws, max noise 0.0021 ≤ 0.04 in
`docs/reviews/292/gate-report.json`). The missing signal was human contour,
not the scalar. This is the *visual* half of that ticket. The *scalar* half
(SKIP is not a raster; generate on Studio not the API) lives in
[The generating product is Studio; a SKIP is not the silhouette gate](studio-not-api-is-the-map-kit-generating-product.md)
and must not be folded into this capture-style rule.

## Guidance

Keep the white unshaded shader for the eight alpha masks. For `--review=`,
do not scatter unshaded instances. Write a 5×4 lit clay grid a human can
read. Seed 292 still picks yaw and scale; position is a lattice, not a
distant scatter.

The two jobs share `tools/raster_map_silhouette.gd`. They do not share a
material, a zoom stop, or a layout.

**Masks (scalar Gate).** `SILHOUETTE_SHADER` is unshaded white
(`tools/raster_map_silhouette.gd:22-25`). Transparent 1024×1024 target,
one centred mesh, `WIDEST_STOP` 3 → `ZOOM_STOPS[3] = 28.0`, tilt
`MapCameraRig.TILT_DEGREES` −40° (`presentation/map/map_camera_rig.gd:12-15`).
`silhouette_noise` fails above 0.04. Lighting is a contaminant here.

**Review (human picture).** Non-transparent 1280×720 viewport, opaque
background, dim ambient, two directional lights, `_clay_material`
(`StandardMaterial3D` gray, roughness 0.82, specular off,
`tools/raster_map_silhouette.gd:265-272`), `_add_review_light` (key 0.72 /
fill 0.22, `tools/raster_map_silhouette.gd:275-287`), `REVIEW_STOP` 2 →
zoom 20. Twenty instances on a 5×4 lattice, gap 2.6 m, seed 292 for yaw
(`rng.randf() * TAU`) and scale (`0.82 + rng.randf() * 0.27`)
(`tools/raster_map_silhouette.gd:303-325`).

```gdscript
# tools/raster_map_silhouette.gd:316-323
var col: int = i % COLS
var row: int = i / COLS
var yaw: float = rng.randf() * TAU
var scale: float = 0.82 + rng.randf() * 0.27
var origin: Vector3 = Vector3(
        (float(col) - 2.0) * GAP,
        0.0,
        (float(row) - 1.5) * GAP)
```

`tools/land_map_glb.py` (`review_png`) only asserts the PNG exists.
Existence is a land-step, not a Gate. Default landing still captures under
`docs/reviews/292/` and does **not** write provenance. Accepted provenance
is a later provenance-only step (`tools/land_map_glb.py` (`validate_signed_acceptance`)):

```
python3 tools/land_map_glb.py --asset ID --src GLB
python3 tools/land_map_glb.py --asset ID --src DEST \
  --accept-signed-capture docs/reviews/TICKET/ID-20.png --reviewer fol2
```

`--src` on accept must already be the landed dest (no copy). Recapture is
skipped automatically; `--no-review` is not required. Reviewer must be
`fol2`. The PNG must be the canonical non-symlink
`docs/reviews/<positive-ticket>/<asset_id>-20.png`, 1280×720 RGB/RGBA.
`pending` is not a shipping verdict. The Gate is `human_review.verdict`
in `docs/reviews/292/gate-report.json`.

Do not ask a human to sign an unreadable capture. Do not upscale a mask
and call it review. Do not close a one-module ticket as if it had passed
map-level repetition.

## Why This Matters

The mask question is: does this mesh, at production tilt and widest zoom,
stay ≤ 0.04 noise? Unshaded white is the right instrument.

The review question is: when this module is placed twenty times the way a
kit is used, does a recognisable contour dominate, or is it the same item
at different size and angle? That needs shading, size on the page, and a
written verdict. The white scatter supplied none of those, so it could not
fail when repetition was present and could not pass when it was not. A
SKIP and an unreadable PNG are the same disease: a named check with no
failure signal.

**Why "same item, different size and angle" is the right signature for one
module.** A kit module is meant to be reused. Twenty copies of
`shared-road-slab-a` at seed-292 yaws and scales should read as one
contour, resized and turned. If the owner had seen twenty *different*
objects, the mesh would have failed identity, not repetition.

**Why we still need more modules.** Map-level contour repetition is a
composition defect. The bill's floor is five act-specific modules
(`docs/map-scene-asset-bill.md`). Twenty copies of one signed slab cannot
test that. One kit does not replace placeholders. Further acts stay on
#293.

## When to Apply

- Any `--review=` recapture under `docs/reviews/292/`.
- Any ask for a human to sign "same item" or "contour repetition" from a PNG.
- Any edit that "simplifies" review back onto `SILHOUETTE_SHADER`.
- Landing the next ordinary GLB with `tools/land_map_glb.py` (it writes the
  review PNG from this harness). Write accepted provenance only with
  `--accept-signed-capture` and `--reviewer fol2` after that PNG is signed.

## Examples

**Before (not a Gate):** `docs/reviews/292/road-slab-a-20.png` was twenty
unshaded white chips on a 48×24 ground at zoom 20. The owner rejected that
picture as unreadable and would not sign.

**After (signed):** the same seed, lit clay, 5×4 lattice. Owner (fol2,
2026-08-20): "same item, different size and angle"
(`docs/reviews/292/gate-report.json`). #292 closed on that signature, not
on the noise number. PR #423 later merged the harness.

## Related

- GitHub #292 (closed) — first paid module; 20-placement signed on the clay grid, then the harness landed in #423
- GitHub #423 (merged) — harness writes the lit 5×4 clay grid
- GitHub #293 (open) — remaining act kits still owe a *readable* 20-placement
- GitHub #289 (closed) — asset bill: silhouette masks versus 20-placement visual
- [The generating product is Studio; a SKIP is not the silhouette gate](studio-not-api-is-the-map-kit-generating-product.md) — scalar half; do not merge this capture rule into that document
- [Put the gate where the change is deterministic](../conventions/put-the-gate-where-the-change-is-deterministic.md) — noise numbers belong on the masks; contour belongs on a picture a human can read
- `CONCEPTS.md` Gate, Evidence Harness
