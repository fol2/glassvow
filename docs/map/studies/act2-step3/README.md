# Act II — Step 3 native study

Status: James approved Act II Step 3, including the scenery-v2 native scene. The approved review and receipts are retained. Act III Step 3 is next; Act IV follows its approval. Step 4 remains parked.

## Aquatic scenery — scenery-v2 candidate

The owner requested scenery assets following the Act I approach. Six aquatic
families provide 18 distinct shared meshes: wet slate, reeds, kelp, floating
leaves, driftwood and drowned snags. The scene places 127 instances in asymmetric
beds around foundations and selected bridge-side pockets, with open water
between groups. Footprint exclusions protect original routes, decorative
approaches and ruin entrances. All eight ruin assignments are preserved.

The initial v1 view was rejected because the colours were too bright and the
placement read as ornamental rings. v2 correctly interprets vertex colours as
sRGB and groups the plants into offset beds. The model library has 3,723 triangles
across all 18 variants, one shared material and no additional texture maps.
This is not a target-device performance certification.

Asset geometry checks and the focused five-script gate pass. All seven native
reference views and the asset gallery were captured and visually inspected.
Every reference contains the same 127 scenery placements; all 13,305 sampled
dry architectural body positions remain clear. Phone and tablet input checks
passed. The eight-second film was observed playing through Tailnet at 1.748734
seconds with no media error, and the asset-gallery lightbox was exercised.
`index.html` and `review-scenery-v2.html` publish this scenery candidate with
a previous-scene comparison. James subsequently approved Act II Step 3.

## Ruin connections — ruins-v3 candidate

The owner requested one generated-node attachment per ruin and the largest ruin
at the boss. A subsequent clarification permits decorative approaches to end
underwater. `ruin_plan.gd` assigns eight distinct node owners, reserves one
entrance corridor per ruin and places the largest library beyond boss `14,3`.
The three wards and four submerged quarters retain their original vertical
positions. Their decorative roads descend to 1.0 m and 0.7 m respectively,
below the unchanged 1.18 m water surface. They are scenery, not playable edges.
The generated 65 nodes, 76 routes, node types and source fixture are unchanged.

Approaches join the lower surface before deck meshing, so node junctions share
one outline. The existing stone bridge module supplies masonry, parapets and
incline steps. Quarter coping has an entrance opening. The former fixed `2,0`
library apron is no longer used. Overview markers identify the eight assigned
nodes; native selection identifies their ruin attachment.

The plan probe passes eight unique owners, boss ownership, unchanged source
JSON, unchanged smaller-ruin heights and seven submerged endpoints. The focused
11-script gate passes. Native deck coverage and added-masonry probes include
all decorative links; architecture probes include original routes and dry link
portions. Submerged decorative endpoints are explicitly excluded from body
walkability checks. All seven v3 native views passed their bounded checks and were visually inspected.
There are 31,633 covered deck samples and zero added-masonry hits at 22,595
corridor samples; 13,305 dry architectural body samples found zero bounds hits.
Phone and tablet native input checks passed. The eight-second film was observed
playing through Tailnet at 1.756817 seconds with no media error.
`index.html` and `review-ruins-v3.html` publish the revised review.

The v1 trial raised all ruins to route height and was rejected after visual
inspection. v2 restored smaller ruins to water level with dry entrance pads;
the owner's underwater-road clarification superseded that trial. Their completed
captures remain historical; incomplete trial batches are not acceptance proof.

## Selected B application — bridge-b1 candidate

The owner selected B from the controlled parapet comparison. `pointed_parapets.gd` now fits complete two-opening bays to accepted continuous boundary runs. It replaces nearest-route UV-based hole placement, uses continuous lofted coping, tests full post footprints, and uses upright balusters on inclines. Short returns are solid. In this sample, 600 fitted bays include 67 incline bays. The 22 existing stair flights and the committed water module are preserved.

Triangle-level probes passed for two true openings, solid sill/mullion/coping and outward-facing tops in either boundary direction. The focused 11-script sweep passed. All seven native reference views were captured and visually inspected. Geometry, obstruction and phone/tablet input checks passed. The eight-second film was observed playing through Tailnet at 1.684094 seconds with no media error. `index.html` and `review-bridge-b1.html` present the selected B application, retaining a bridge-v10 comparison. This is application review, not chapter approval.

## Stair flights and parapet rhythm — bridge-v10 history

The owner requested slope-triggered procedural stairs and less repetitive parapets. The shared flight grader now fits complete sustained inclines before the structural deck is built, retaining their endpoint heights. Hard-edged tread meshes follow those grades with equal risers, instead of individually accumulated stones. The sample contains 17 lower and 5 upper flights, 172 treads in total, with a maximum riser of 0.16845 m. Gentle slopes remain paved and node/crossing exclusion zones retain their landings.

Parapets alternate solid masonry and open stone balustrades, with capped rhythm posts. Vertical coping sections replace tilted boxes. Actual-geometry checks exposed one new post footprint intruding at a tight bend; testing the whole footprint resolves that case. Earlier bridge-v8/v9 receipts preserve the rejected iterations. The staircase mesh checks cover ascending/descending slopes, gentle slopes, curved-ramp grading, flat normals and equal riser/tread dimensions; their comparison tolerance accounts for ArrayMesh 0.1 mm position quantisation.

The native candidate retains 65 nodes and 76 edges, 28,315 covered deck samples, 609 crossing-width samples with minimum clearance 2.3596 m, coincident sampled joins, and zero added-masonry hits at 20,225 body positions. Fitting the flights deliberately changes intermediate deck heights (the largest sampled difference from the original route is about 0.48 m). The whole-deck triangle-grade metric includes very small transition triangles and is not a walkability certification; wider production qualification remains deferred. All seven native views have been captured and visually inspected. The focused ten-script sweep and stair mesh checks passed; phone/tablet input checks passed. The eight-second film was observed playing through Tailnet at 1.755503 seconds with no media error, and the stair-image lightbox was exercised. `index.html` and `review-bridges-v10.html` now present this candidate with bridge-v7 comparisons. Owner review remains pending.

## Stone-bridge revision — bridge-v7 history

The shared `tools/map_workshop/stone_bridge/` kit adds real arch profiles and substantial pier intervals, continuous parapets/coping, intrados stones, buttresses/newels, physical incline treads and shared masonry/paving materials. Presets separate city and woodland proportions/colours; Act I is not migrated in this study. The water module has not changed since its milestone commit.

Investigation history is retained in `bridge-v1` through `bridge-v6` captures and diagnostics. Initial tiny boundary pieces were too costly, so the outline is simplified within 2 cm before masonry assembly. Arch stones needed their own curved sampling rather than interpolation between straight deck-outline endpoints. The first combined deck audit dropped the unindexed deck when mixed with indexed treads; it now retains separate ArrayMesh surfaces. The new actual-geometry corridor audit exposed newel footprints and partial rail overlaps at layer joins. Full cap-footprint checks and clipped join margins resolved them, rather than weakening the corridor test.

The current candidate uses complete segmental arches at the raised crossings. Its last deterministic pass retained all 65 nodes and 76 connections, complete sampled deck coverage, 609 crossing-width samples with a minimum main-intrados clearance of approximately 2.36 m, and zero decorative obstructions across 20,225 body samples. These are bounded geometry checks; all seven native near/whole/reference views have now been visually inspected. The narrow script sweep passed (30 scripts), as did Python compilation and phone/tablet input checks. The eight-second native film was verified playing through Tailnet at 1.761226 seconds with no media error. `index.html` and `review-bridges-v7.html` present this candidate, including stairs and a previous-bridge comparison. Production performance and wider layout qualification remain later work.

## Toon-water revision — v9 history

All six native views and the eight-second film have been visually inspected. Bounded geometry and phone/tablet input checks passed. The actual Tailnet video was observed playing at 1.772409 seconds without a media error. At that milestone, `index.html` presented v9, including a comparison with v6; `review-v9.html` preserves that page. This is a Step 3 review, not final production acceptance.

The owner requested convincing, low-cost stylised water, citing the NekotoArts Wind Waker shader and Megalithium's Godot 4 adaptation. The shared module now generates a periodic rounded distance field once, reuses the existing foam-texture slot and animates two drifting pattern layers. This is an independent implementation of the visual idea, not a copied shader. Sources and rendering decisions are in `tools/map_workshop/water/README.md`.

v7's oversized complete circles were rejected as too graphic. v8 improved the close view with smaller elongated broken crests, but the whole-act view was too busy; its capture batch was stopped. v9 adds a world-pixel-footprint fade so close crests remain readable while the overview becomes quiet. The underlying geometry, water level and routes are unchanged.

The shared-resource contract passes, including first-frame readiness, per-body settings/clock isolation, periodic pattern seams and 786,429 bytes of source texture data including mipmaps. There are still seven texture lookups per water fragment, no circle/noise loops in the fragment stage, and no extra viewport or wave subdivision. No target-device performance certification is claimed.

## Previous shared-water revision — v6 history

The owner's corrected research attachment (6 September 2026) supersedes the earlier pasted reference. The current candidate uses `tools/map_workshop/water/`: one shared shader and cached procedural noise textures, independent per-body materials, chapter presets and a deterministic capture clock. Act II has migrated; the approved Act I study is preserved. Later chapters can use the same module without duplicating rendering code.

The active Act II runner no longer creates the planar-reflection viewport or camera. Earlier reflection scripts and v4 captures are retained as study history. The new water reconstructs scene depth, uses world-space dual normals, rejects foreground refraction and controls a narrow broken foam band. A first capture exposed overly broad foam across shallow steps; the city preset now narrows and reduces it before review.

`v5-*` records the first module candidate; its whole-act view exposed an over-bright specular highlight, so its capture batch was stopped. `v6-*` is the revised candidate with a rougher, lower-reflectance city preset. The resource contract passed: textures ready with mipmaps, shared texture identity, independent materials/presets and independent capture clocks. All six native reference captures and the eight-second film are complete and visually inspected. Phone and tablet native input checks passed. The Tailnet film was observed playing at 1.742801 seconds with no media error. `index.html` now presents v6 for owner review. Step 4 remains parked.

## Previous v4 candidate and investigation history

### Final-candidate capture in progress (v4 history)

The current profile is `profile-library-waterline.json`: the source graph is
uniformly spaced at 1.8, while the library arrival is held at 2.15 m. This puts
its reading court close to the water without sacrificing the bridge crossings.
`v4-*` is the coherent candidate capture set being completed. It adds four broad
submerged civic quarters in sampled-route-free spaces, using three quiet forms.
`v4-whole` already passed coverage and placement checks with 4,434 architecture
meshes and zero hits among 12,135 sampled body positions.

The apparent cut-off foreground bridge was a detail-camera near-plane clip.
Moving the orthographic camera further along the same sightline retained the
composition and restored the complete structure (`bridge-frustum-fixed.png`).
It was not a water-reflection defect. The separate library entrance overlap was
real: `forecourt.gd` now clips one apron against the actual road footprint;
`v2-library.png` verifies its clean join. `v3-library.png` additionally verifies
the lowered flooded court. Earlier failed profiles and captures remain below.

The first v4 tablet replay failed to observe the Journey switch, although its
final image had returned to Journey. `input-before-frame-fence.json` retains the
failure. The replay now sends pointer motion, flushes queued input events, and
awaits a completed render before inspecting camera-dependent marker visibility.
It still uses native input events and does not invoke button actions directly.
Fresh tablet and phone results are pending; old green receipts do not substitute.

Pending before owner review: complete the v4 reference captures and native film,
inspect them, verify the review page and Tailnet media, then present the chapter.
Act III and Step 4 must not start before the agreed chapter approval gates.

## Authority and required outcome

- Approved art: `../../concepts/act2-combat-aligned-v3.png`.
- Native sample graph: `../camera-composition/act2-seed717.json`, containing
  65 nodes and 76 edges, including upper/lower crossings.
- Establish a drowned Gothic library, quiet slate floors, blue glass and jade
  lanterns, substantial architecture, supported causeways and integrated water.
- Preserve every generated node and route. No game RNG, IDs or save changes.
- Inspect close, default and whole-act native views and the supported phone/pad
  shapes. Resolve known visual defects before the owner's chapter review page.
- Complete Act II's owner review before Act III; complete all four before Step 4.

## Current candidate — wider spatial layout and continuous landings

`profile-turn-platforms.json` is the current optional presentation candidate:
uniform X/Z scale 1.8, identical 65 node identities and 76 connections. This is
a visual spacing decision within the owner's design freedom, not a change to
the generator or campaign graph. The unchanged-scale trials remain below.

The solver now holds complete incident footprints and tight turn platforms at
compatible heights. `turn-full-support-geometry.json` confirms 28,315 actual
rendered-deck samples across a 1.2 m corridor with no missing surface, effectively
zero sampled bridgehead separation, and minimum sampled crossing headroom
2.538 m. Centreline sampled grade is 0.484 after surface interpolation; the
solver's 0.44 source-profile limit is not a claim about the finished mesh.
The maximum triangle grade across the entire deck, including clipped edges,
remains 1.041 on a 0.00253 square-metre boundary triangle. This is retained as
an inspection item rather than hidden by a centreline-only check.

Two further causes were isolated: clipping interpolated unrelated outside-grid
heights into road edges, and a narrow search index truncated the smoothing
support around widened landings. `smooth_surfaces.gd` now samples actual clipped
boundaries and indexes its full compact interpolation support. The older
boundary-only and small-support receipts preserve those failed trials.

`causeways.lines` now exposes the uniformly scaled lines to scenery placement;
precinct preferences follow that same transform. The native `spacious-city`
receipt confirms all three precincts and zero sampled architecture bounds hits.
`candidate-bridge.png` is now a fresh native close capture on the smoothed
candidate. The main bridge opening is continuous and its approach is markedly
better, but the foreground junction/reflection silhouette still looks split.
It has not passed visual inspection. Next isolate water/reflection from actual
geometry at that junction, and sample the full overlapping footprint beyond
the existing 1.5 m landing audit. Do not conceal it by tightening the camera.
Fresh library and reference-shape captures are still required. Review page imagery is not yet refreshed; do not publish it
as the passing candidate. Step 4 remains parked.

## Presentation-height experiment — not accepted

The bounded height solver found a feasible centreline profile without moving
any X/Z sample (`profile-feasibility.json`). Native inspection of
`profile-bridge.png` still shows split bridgeheads. Its mesh receipt records
0.482 m maximum landing separation, despite zero missing route samples,
0.440 sampled grade, 2.391 m minimum sampled crossing headroom and zero
sampled architecture bounds hits. These metrics do not establish a sound join.
The optional profile is therefore an experiment, not the new accepted default.

Freezing complete incident approach footprints was also tested at 2.85 m and
2.1 m proximity radii; both were infeasible under the present grade and clearance
constraints (`profile-footprints.json`, `profile-footprints-tight.json`). Those
failures are retained. The solver exposes `--footprint-radius` for replay and
leaves that constraint disabled by default. Next: resolve continuous full-width
junction geometry, then repeat the close bridge inspection before refreshing
any owner-review imagery. Do not trade away crossing headroom to clear a join.

## Current internal review failure — bridgehead surfaces

The latest close bridge inspection (`review-bridge.png`) revealed exposed seams,
overlapping landings and disconnected-looking masonry that whole-act captures
and route-centre checks had missed. The candidate has **not** passed internal
Step 3 review. `index.html` is an internal draft, explicitly labelled not ready;
it has not been presented to the owner as the approval page.

This iteration produced current phone and pad native-input receipts (all listed
checks true), complete overview and three detail captures, with logs named
`review-*`. Those checks do not excuse the bridgehead defect.

`audit.gd` now measures upper/lower surface separation within 1.5 m of each
bridgehead. A flat-start trial (`joint-flat-trial-geometry.json`) still had about
0.717 m separation. A single-owner clipping/conformance trial
(`joint-union-trial-geometry.json`) removed overlapping top ownership but
introduced a sampled grade of 2.886 and visible abrupt transitions. Zero overlap
samples in that trial is not proof of successful joins. **That trial is rejected.**

The active `causeways.gd` has been restored to its earlier crown and independent
surfaces. Fresh `joint-baseline-geometry.json` verifies sampled grade 0.440 and
minimum width-sampled headroom 2.391 m, but also confirms a maximum 1.252 m
upper/lower surface separation among the bridgehead overlap samples. The
restored baseline is therefore still defective, not a passing candidate.
`joined_surfaces.gd` remains an unused experimental implementation;
do not enable it as a fix. The reduced bridgehead parapets and diagnostic/detail
tools remain. No generated nodes or routes were changed.

Next action: diagnose and repair complete bridgehead geometry. The failed trial
consulted the entire lower surface near an abutment, which can include nearby
non-incident routes. Carry explicit source-edge/endpoint identity into spans,
resolve only incident landing geometry, preserve genuine upper/lower crossings,
and verify both the rendered seam and sampled grade/clearance after changes.
Do not merely flatten a radial patch, hide a gap with props, or accept centreline
checks as full-surface evidence. Only after the repair passes should the final
six captures and water film be refreshed and the Tailnet review page completed.

## Latest candidate — precincts, reflection and clear forecourt

The latest inspected native still is `forecourt-current.png` (1458 x 820).
Three connected civic precincts now replace the six isolated roofs/towers:
centres (-6,-27), (18,-25), (26,0). Each contains a faceted glass tower,
reading wings and a flooded low court. Exact source-segment/expanded-rectangle
intersection rejects occupied sites; the subsequent body audit checks the
constructed architecture, not just the advertised footprint.

`forecourt-current-placement.json` reports zero conservative architecture-AABB
hits across 12,135 body samples against 3,200 architecture meshes. Earlier
`precincts-current-placement.json` exposed 550 hits at the main library's front
buttresses. The library was set back 2.5 m and given a fitted forecourt meeting
the unchanged `2,0` anchor. This resolves those sampled obstruction hits without
moving any generated node or edge. Neither AABB samples nor this static study
prove campaign movement or exhaustive continuous collision behaviour.

The flood now has a half-resolution planar reflection pass. It reflects actual
above-water scene geometry, clipped at the waterline; reflection colours are
simplified, while main-scene materials remain unchanged. The 3,336 reflected
mesh sources merge into 16 colour batches. Refraction rejects foreground depth
samples to avoid pulling bridge faces into the water. Camera framing now uses
projected library bounds and keeps the rear windows below the header.

`water-study.mp4` is an eight-second, 240-frame, 1458 x 820 / 30 fps native film.
It predates the forecourt setback, so it is water-development evidence, not the
final chapter film. Its internal `water-study.html` player returned HTTP 200,
played from 0 to 8 seconds in the in-app browser and ended without media errors.
Short warm-render samples on the M1 Max were about 71–103 fps; these are not
sustained performance qualification or measurements on a phone device.

Next: inspect the revised scene at desktop/pad/phone reference shapes, exercise
the final inspection controls, capture close asset/bridge/water details and
refresh the film after the forecourt correction. Then make an explicit internal
Step 3 art assessment against the approved concept and combat references. Only
a passing candidate should receive the owner-facing Tailnet review page. The
current internal water page is not that approval page. Do not enter Step 4.

The sections below retain earlier iteration evidence; their older scene counts,
placement descriptions and next-action notes are superseded by this section.

## Current assembled chapter

The chapter runner now supports `--chapter` and `--whole`. `causeways.gd`
assembles all 76 source edges and 65 anchors, with separate upper/lower clipped
deck fields. `levels.gd` reuses graph grading without the Act I river incision.
The roofless library is positioned at the real `2,0` arrival, and its foundations
and central court use the global flood level. Six drowned roof groups are
selected from route-free pockets. No production map code or graph data changed.

The current geometry receipt is `current-geometry.json`. It reports:

- 65/65 anchors and 76/76 edges; no missing sampled route coverage.
- Maximum sampled rise/run: 0.440.
- Minimum sampled dry margin above water: 0.596 m.
- Maximum endpoint height mismatch: approximately 0.0000021 m.
- Three crossing-centre clearances: 3.512 m, 2.779 m and 2.863 m.

These are centreline/centre checks, not whole-surface proof. Earlier receipts
preserve the failed low-clearance and steep-approach candidates. The correction
uses broader bridge crowns and nearest-route weighting of the existing graded
segments; a radial bridgehead height patch was removed because it steepened
nearby roads. The explicit script gate passes for the changed scripts.

Native captures `chapter-current.png` and `whole-district.png` preceded the last
route-weight correction; `whole-current.png` is the final recapture for this
iteration. They remain internal studies. Known visual work: excessive repeated
bridge rhythm, insufficient civic architecture, weak submerged-city character,
water appearance/motion, and detailed library/route obstruction checks.
No review page, owner approval or Step 3 completion is claimed.

## Current inspection and rendered-width evidence

- `width-geometry.json` samples actual rendered lower-deck and upper-underside
  triangles at all three crossings: 611 overlap samples, across +/-0.9 m at
  0.15 m spacing and along each crossing at 0.125 m spacing. Minimum sampled
  headroom is 2.391 m, with no samples below 2.2 m. This is sampled evidence,
  not an exhaustive collision or mesh-watertightness proof.
- `inspect.gd` adds read-only Library / Journey / Whole act views, pan/zoom and
  selectable 44 px waystones. State colours and descriptions read the existing
  sample's current/history/reachable data; inspection does not enter nodes.
- `phone-input-input.json`: actual 844 x 390 render and native input events
  verify whole/journey buttons, visible current location, selection, pan and
  zoom. This validates this saved state, not every generated view or touch OS.
- The first phone capture was actually 561 x 390 because inherited stretch
  settings constrained it. It is retained as failed evidence. The runner now
  sets physical window size and content-scale size explicitly, matching the
  established workshop convention. `phone-journey.png` is verified 844 x 390.
- Current combat skyline inspected: `assets/art/stage/act2-backdrop.png`.
  `gothic_spire.gd` begins replacing generic roofs with faceted Gothic glass
  towers. `pad-whole.png` exposed incorrectly world-positioned roof ribs;
  the local-basis correction is recaptured in `pad-whole-current.png`.
- Art is still not ready for owner review. The overall scene remains too much
  like a repeated bridge network with isolated props. Improve the architectural
  masses and water, and inspect tower scale closely. No Tailnet review page
  has been published and no chapter approval has been requested.

## Earlier architecture experiments

`tools/map_workshop/act2/` is an isolated native study. The new roofless library
contains masonry window bays, buttresses, pointed arch geometry, blue leaded
panes, actual book spines, stepped aisles, a lowered reading court, gateway and
jade lanterns. Masonry and glass use separate world/local-space materials.

Godot 4.7.2, native Metal / Forward Mobile captured `library-first.png` and
`library-materials.png`. The explicit script gate passed for `library.gd` and
`run.gd`. Both native processes exited successfully after saving their images.
These are architecture experiments, not chapter completion evidence.

Inspection of the first capture exposed outward-facing bookshelves, flat glass
and an incorrect water normal coordinate space. The second capture verifies
visible inward-facing shelves and leaded glazing. Water, shadow artefacts,
architectural hierarchy and composition still need work. `library-current.png`
recaptures the later shadow-distance and bay-height adjustments successfully.
Inspection shows reduced fine shadow stippling but overly hard, jagged shadow
edges and excessive glass repetition; these remain internal revision items.

## Next action

1. Inspect the final whole-act recapture against the approved concept and actual
   combat art. Improve architectural hierarchy and the drowned roof groups;
   the current sparse groups and bridge network do not yet establish a city.
2. Verify whole-width bridge headroom, deck contacts and library/route clearance,
   including the courtyard stairs and arrival at `2,0`. The centreline receipt
   does not prove these boundaries.
3. Refine and inspect water depth, reflection character, shore contacts and
   native motion. Do not accept repetitive bands or a static-looking flat fill.
4. Expand inspection evidence beyond the single phone snapshot: desktop close
   views, pad input, other current/next contexts and native water footage. Then
   build and verify the Tailnet chapter review page.
5. Obtain Act II approval before starting Act III. Step 4 remains parked.

## Reproduce current architecture experiment

```sh
tools/check_scripts.sh tools/map_workshop/act2/library.gd tools/map_workshop/act2/run.gd
godot --path . --rendering-method mobile --resolution 1458x820 \
  -s res://tools/map_workshop/act2/run.gd -- --output=/tmp/act2-library.png
```

For the assembled graph, add `--chapter`; add `--whole` for the overview.
For geometry without rendering, use `--headless` with `--audit-only`. The runner
exits before viewport capture in this mode; headless output is not visual proof.
