# Native map workshop: reusable technology and art decisions

Act I, Act II and Act III have owner approval at Step 3. Preserve their approved captures
and source compatibility entry points. This is a reusable study toolkit, not a
claim of completed campaign integration or all-seed qualification.

| Reuse surface | Owner and contract |
| --- | --- |
| Water | `tools/map_workshop/water/`: shared shader and cached textures; per-body materials, level, palette and capture clock. Seven fragment texture lookups; no extra reflection viewport. River presets still need their own visual qualification. |
| Bridges | `tools/map_workshop/stone_bridge/`: fitted outlines, real intrados, piers, continuous coping, opening clips and measured clearances. Callers supply surface queries and chapter materials. B proportions are approved for Act II, not automatically every chapter. |
| Stairs | `stone_bridge/flight_grade.gd` and `stairs.gd`: fit whole sustained inclines before mesh generation; equal risers and hard horizontal treads; protect junctions, endpoints and crossings. |
| Fitted route assembly | `common/fitted_routes.gd`: caller supplies destination plan, terrace grading, bridge settings and optional material factory. Act II retains a thin composition wrapper. |
| Height profiles | `common/profile.gd`: validates fixture digest, route count and unchanged planar coordinates. Scale is an explicit presentation decision. The bounded solver remains an experimental tool. |
| Surface interpolation | `common/smooth_surfaces.gd`: continuous fitted deck heights and optional shared flight grading. |
| Geometry evidence | `common/mesh_probe.gd`: actual rendered triangle heights. Act II's deck, walkway and placement audits show the integration contracts; chapter-specific counts and obstruction scopes remain explicit. |
| Inspection | `common/inspection.gd`: native selection, pan, zoom, landmark/journey/overview framing and reference-size exercise. Chapter heading and landmark label are configurable. |
| Scenery | `act2/scenery_assets.gd` and `scenery.gd`: reusable aquatic models, shared meshes/material, footprint-aware habitat groups and preserved waterline. Reuse the placement method across chapters; choose chapter-appropriate assets. |
| Capture | Act II's serial native capture script, film encoder and browser review page establish the recipe. Every new chapter must validate its own counts and evidence, not inherit a green Act II receipt. |

## Art lessons to carry forward

- Design scale and grouping together. A good isolated model can still look
  artificial when small or evenly scattered. Use dominant groups, companions,
  different silhouettes and generous empty intervals.
- Keep broad ground areas quiet. Fine tiled texture, mottling and dense cracks
  blur at the map camera. Spend detail at deliberate focal points.
- Roads need coherent widths, bends, junctions and structural transitions.
  Sample the whole corridor and actual decorative geometry, not only centrelines.
- The ground needs relief. Piers, banks, shelves and recessed spaces explain
  how roads and buildings stand; a water shader cannot supply that structure.
- Ruins attach to one generated node, with the principal landmark at the boss.
  Decorative approaches may descend underwater. They do not add gameplay edges.
- Match combat through architecture, silhouette, floor, palette and lighting.
  A palette swap alone is insufficient. Act III remains intact; only its halo
  is fragmented. Act IV must remain grand, empty, sad and dark.
- Inspect close, journey, overview, phone and tablet views before owner review.
  Include an asset gallery and a prior-scene comparison when they help judgement.

## Implementation traps already observed

Keep indexed and unindexed geometry in separate SurfaceTool streams or mesh
surfaces. Fit complete parapet bays along continuous boundaries, not nearest
route UVs. Check complete newel-cap footprints. Use hard normals for stairs.
Interpret authored vertex colours as sRGB. Keep submerged decorative scenery
separate from dry walkability claims. A successful source check does not prove
rendering, input or media playback; observe the native result and review page.

## Next chapter

Act III Step 3 was approved on 7 September after precinct-v4 delivery, with optional
later polish. Act IV now uses `concepts/act4-grand-empty-v6.png` and its actual
combat art: grand, empty, sad and dark; structural relief; a fixed five-stop
journey towards the small unsettling hearth. Shared modules support construction
and verification; the obsidian precinct composition is not an Act IV template.
The active plan is `/PLAN.md`. Step 4 remains later, after Act IV Step 3 approval.

The Act III extension also contributes opt-in route guidance and exact selected
Travel through `common/route_guidance.gd`, plus a chapter-owned ObsidianFinish
recipe. Canvas shaders must preserve actual authored modulation; test real
layout opacity values rather than only 1.0. Complete core 102 and parser 431 passed
at the Act III delivery; these receipts do not qualify new Act IV changes.
