# Act II native Step 3 study

This isolated scene consumes the immutable seed-717 map and its accepted height
profile. It does not alter campaign navigation, saves or the generated graph.

## Ruin attachments

`ruin_plan.gd` owns the eight presentation-only assignments. The largest library
uses the generated boss node. The remaining three wards and four quarters each
use a distinct node. Deterministic candidate placement reserves the footprint,
entrance corridor and separation from other attachments. If the bounded search
cannot place every ruin, it fails explicitly; it is not an all-seed layout solver.

`causeways.gd` adds these decorative spurs to the fitted lower surface before
meshing, including shared junctions, parapets and slope-triggered stairs. The
original `sampled_routes` dictionary remains the 76 gameplay connections;
`ruin_links` is a separate presentation dictionary. Smaller ruins stay at their
original vertical positions and their arrival roads end underwater. Only the
largest library has a raised, dry entrance.

`run.gd` assembles the planned buildings and publishes their node assignments in
the geometry receipt. The overview marks the eight owners. Deck and masonry
probes include decorative spurs. Architectural body checks exclude underwater
spur portions, which are scenery rather than playable corridors.

```sh
tools/check_scripts.sh tools/map_workshop/act2/ruin_plan.gd tools/map_workshop/act2/causeways.gd tools/map_workshop/act2/run.gd
godot --headless -s res://tools/map_workshop/act2/verify_ruin_plan.gd
python3 tools/map_workshop/act2/capture_review.py --prefix candidate --views whole boss submerged precinct library phone pad --film
```

Capture serially on the GPU. Inspect the native images before publishing a page.
The fixed-site `drowned_city.gd`, `submerged_city.gd` and old library `forecourt.gd`
remain historical studies; the current runner uses the node-bound plan instead.
Act II owner approval still precedes Act III Step 3, Act IV Step 3 and Step 4.

## Aquatic scenery

`scenery_assets.gd` builds six reusable families with three distinct shapes each:
wet slate, reeds, kelp, floating leaves, driftwood and drowned snags. Vertex
colours use sRGB interpretation to fit the chapter lighting. One material and
18 shared meshes serve the placements; there are no new texture maps.

`scenery.gd` uses deterministic presentation-only habitat groups, measured mesh
footprints and exclusions around original routes, decorative links and ruin
foundations. Floating leaves and wood retain their waterline when scaled.
The selected sample contains 127 placements. Native architectural obstruction
checks include their actual mesh bounds. This is bounded seed-717 art evidence,
not target-device performance or campaign qualification.

`verify_scenery_assets.gd` checks distinct finite geometry and floating-leaf
heights. `scenery_gallery.gd` captures a native contact sheet; the review page
labels its six columns. The initial bright, ring-shaped v1 arrangement was
rejected before owner review. v2 uses quieter colour and asymmetric beds.
