# Step 3 asset sample assessment

The owner checkpoint is the **coherent asset sample** in the agreed plan.
James reviews asset direction before Step 4 assembles the finished section.
The original commercial map goal and subsequent gates remain unchanged.

## Agent assessment

The current native group is suitable for the Step 3 discussion:

- The edited gateway has substantial piers, layered stone mouldings and a
  readable trefoil under the 55-degree camera. Both sides have been inspected.
  Its matte material accepts the same light as the original kit. Separate
  bronze lamps supply restrained amber accents and actual local light.
- The conifer and ash copse use dimensional stems and curved painted foliage
  cards. Their transparent spaces survive export and native cut-out rendering.
  Charcoal, ash red and amber preserve the accepted Act I identifiers.
- Stone bank, memorial, waystone and bridge bay use quieter broad forms and
  mineral colour. Detail is concentrated in the landmark and lit memorial
  niche. Shared scale and lighting are visible in the group turntable.
- The gateway follows an actual compiled route. Pier clearance and projected
  node reserves select its site; 25 mesh ray probes additionally cover the
  road-width passage. The native placement view confirms the opening reads.
- Contact heights use the rendered land triangles. Two hundred independent
  physics rays give a maximum error of 0.000046 world units, compared with
  0.48553 for the previous smooth-function placement. Physical stone footings
  meet the surface; small soil beds provide material context at vegetation roots.

## Scope of this judgement

This is asset-direction readiness, not completed landscape acceptance. The
placement study deliberately retains temporary ground and route surfaces.
The wider map's vegetation distribution, road treatment, relief, bridge
assembly and integrated waystones are Step 4 deliverables. The full scene must
then pass Step 5 at close and ordinary viewing distances before generalisation.
No production map, campaign behaviour, save lineage or combat assets changed.

The seven visible asset types include a bridge bay and waystone sample. Those
samples have not replaced procedural bridges or navigation presentation yet.
The current 501-plus placement study is not a mobile performance qualification.

## Evidence

- `../native-workshop/step3-assets-front.png`: current native group.
- `../native-workshop/step3-turntable.mp4`: full native rotation, no retouching.
- `../native-workshop/gateway-contacts-v12.png`: generator-bound placement and
  physical contact study.
- `../native-workshop/ground-contact-audit.log`: independent land-height rays.
- `../native-workshop/tripo-trial/passage-verified.log`: gateway mesh probes.
- `../native-workshop/step3-{phone,pad,desktop}.log`: native pan, wheel zoom,
  selection and legal preview travel; all four checks pass at each shape.

Earlier rejected images/logs remain iteration history. They are not the review
candidate. Work pauses for James's Step 3 discussion before Step 4.

## Review service recovery

On 5 September the Tailnet URL returned an empty HTTP 502 because no process
was listening on localhost:8766. Tailscale's existing proxy remained healthy.
The server now runs independently under the user LaunchAgent
`~/Library/LaunchAgents/ai.glassvow.map-review.plist` (label
`ai.glassvow.map-review`), with RunAtLoad and KeepAlive enabled. It retains the
existing localhost bind and worktree directory. Logs are in
`~/Library/Logs/Glassvow/`. The restored Tailnet HTML matched the local file
byte-for-byte; the complete review video returned HTTP 200.

Before deleting or moving this worktree, update or unload this review service.


## Review 02 — owner response and placement revision

James accepts the models themselves and the gateway scale. He requests larger
and richer trees, bushes and stones, a more natural path, and another review
page before continuing. This authorises the bounded placement/surface revision;
it does not record acceptance of the finished landscape.

The current page defaults to a same-camera before/after comparison. The earlier
page is retained as `review1.html`. Current setting evidence is
`../native-workshop/review2-final-banks.png`.

Changes:
- Gateway scale remains 1.0. Broad-scatter conifers increase from 0.45–0.85 to
  0.95–1.35; copses increase from 0.38–0.72 to 0.85–1.25, and roadside copses
  from 0.28–0.50 to 0.70–1.05. Rock banks use 1.0–1.45, with larger authored
  companion banks. Large forms are placed before undergrowth.
- Canopy envelopes can interleave, with roots kept clear of the walking lane.
  Node reserves use a yaw-independent projected envelope generated from actual
  conifer vertices. The initial cone approximation failed 3,176 projections
  and was rejected. The replacement passes 49,944 native vertex projections
  across eight yaws (`review2-envelope.log`) and is bound to the mesh SHA-256.
- Earth roads are part of the land material, using a world-sized distance
  field derived from all original centrelines. Width, edge and broad colour
  variation replace the constant flat ribbon. Node positions and route
  centrelines are unchanged; elevated crossings retain their geometry.
- The mask audit covers 3,858 earth-route samples, with maximum sampled distance
  0.0865 against a 0.25 limit (`review2-route-paint.log`). This establishes
  centreline coverage, not final aesthetic acceptance or all-seed qualification.
- Enlarged vegetation no longer receives the previous separate soil polygons;
  physical stone footings remain.

The three `review2-{phone,pad,desktop}.log` input exercises pass pan, wheel zoom,
node selection and legal preview travel. The corresponding native images were
inspected. Chrome's before/after buttons and Tailnet image loading were also
observed. The scene is ready for the requested second comparison; James has
not yet accepted this revision.


## Review 03 — woodland variety (5 September 2026)

Owner requested roughly doubled natural model variety and varied road textures/shapes, then explicitly requested a revised review page. The natural family now contains six models: conifer, conifer-spire, ash-copse, ash-heath, slate-bank and slate-ridge. Three new Blender masters and GLBs retain the original painted atlases. The spire changes branch count and crown reach; heath changes stem count, spread and height; ridge uses a different low elongated rock arrangement. Gateway scale and selected position remain unchanged.

Placement now mixes the variants and groups undergrowth around tree roots and rock masses. Current sample has 460 props, 65 nodes and 76 edges. Painted earth corridors soften interior corners by at most a 0.35-unit corner approach and add a small bounded lateral wear curve. Width/shoulder variation and low-contrast mineral patches alternate with worn stone close to the selected gateway. Elevated bridge geometry is unchanged. This does not yet constitute arbitrary terrain-aware route generation or finished bridge production.

Rejected the first isolated scatter capture and increased grouped undergrowth. The first curve trial exceeded the existing route-distance limit (0.26653 against 0.25); reduced the bend and corner radius, preserving the limit. Final 3,858 source-centreline samples: maximum distance 0.21946. The new tree envelope is mesh-derived and SHA-bound; 31,984 yawed vertex projections are inside. The original tree envelope was regenerated after export and audited separately.

Focused script checks passed before final native capture. Phone, pad and desktop native input exercises passed pan, wheel zoom, selection and legal preview travel. Inspected all three captures plus the shared gateway frame and six-model gallery. Final selected image: `../native-workshop/review3-final.png`. New 8-second native turntable: `../native-workshop/review3-turntable.mp4`. Review 02 HTML preserved as `review2.html`. Tailnet returned the exact current HTML and all linked media with HTTP 200; native Chrome showed Review 03 and successful before/after toggles.

Awaiting James's judgement on this revised composition. The models' prior acceptance does not imply acceptance of the three new variants or the full production map.


## Review 04 — twelve forms and connected road surfaces (5 September 2026)

Owner requested another doubling of natural scenery, more road variation and better transitions at turns, bridges and junctions. Added six distinct original Blender forms: wind-bent pine, forked snag, trailing thorn bramble, divided fern, split slate blade and part-buried scree. Twelve natural model IDs are present in the native sample; gateway scale/position remains unchanged. The final sample has 467 props, 65 nodes and 76 connections. New tree projection envelopes are generated from the exact GLBs and each of the four tree types passes independent vertex projection probes at eight yaws.

The road regression had two visible causes. Inline colour literals were mixed with source-colour uniforms, causing overly pale stone patches. All artist palette colours now use the same conversion. Deck segments and tight end stubs overlapped at bends, producing black triangles and small gaps. Coplanar footprints are now unioned before triangulation, with open junction landings and continuous mitred edge masonry. The first bridge audit found 11 misses among 1,659 centre/shoulder probes; the joined final surface has zero misses under the same audit.

Six blended surface treatments now cover earth, leaf litter, gravel, exposed slate, threshold paving and damp bridge approach/deck stone. A habitat field follows actual placed vegetation and rocks. At measured deck/earth boundaries a dirt mask continues across the first stones. The route mask resolution increased to preserve edge definition. The unchanged earth-route coverage limit remains 0.25; all 3,858 samples pass, maximum 0.19187. No route IDs, node anchors or graph connections changed.

Rejected the first pale fern treatment, overly frequent bare trees, and the initial overlapping deck candidate. Selected final native images are `review4-final.png`, `review4-bridge.png` and `review4-junction.png`. The six new forms have a native 240-frame / eight-second turntable, alongside the previous six in the page. Original Review 03 page preserved as `review3.html`.

Evidence: ten affected scripts pass the focused script gate. Phone, pad and desktop viewport input exercises pass pan, wheel zoom, native selection and legal preview travel; all captures were visually inspected. The exact Tailnet HTML and every linked image/video return HTTP 200. Chrome displays Review 04, switches correctly between Reviews 03 and 04, and plays the new turntable.

This is the current owner-authorised sample revision. Broad seed/layout qualification, including complex bridge footprint loops and varied elevation transitions, remains Step 6 work; these receipts do not claim production-map completion. Original models retain their prior acceptance; the twelve-form composition is awaiting James's judgement.


## Review 05 — restore the preferred woodland balance (5 September 2026)

James preferred Review 03's scenery to Review 04, except for roads, and approved the recommendation to restore its canopy and shrub mass while using new forms as minor accents. This revision changes placement only. The six main natural forms again establish the complete woodland before an independent accent pass can use remaining spaces. Restored the earlier landmark companions, alternating main variants, twelve undergrowth candidates per group and the original copse/heath verge selection. Road, bridge and shader implementations remain those of Review 04; the habitat field follows the revised plants as designed.

The main pass contains 460 props. Afterwards 22 ferns and 10 brambles fit into the remaining pockets, for 492 total. Review 04 used 124 ferns and 56 brambles. No new wind trees, snags, blades or scree fit the reserved composition under the unchanged clearance rules; these remain available in the twelve-model library. The page explicitly distinguishes the eight natural forms in this scene from the twelve available assets. No model rebuild, forced substitute or clearance relaxation was used.

Selected native capture: `review5-final.png`. Fresh bridge/junction and phone/pad/desktop images all use the `review5-` prefix. The focused kit script check passed before capture; all three native viewport input exercises passed pan, wheel zoom, selection and legal preview travel. Visually inspected the shared site, bridge/junction and all three viewport captures. All 65 nodes, 76 connections and 194 current bridge spans remain present. Prior road/bridge geometry audit evidence still applies to those unchanged surfaces.

Preserved Review 04 HTML as `review4.html`. The current page compares Review 05, preferred woodland Review 03 and previous Review 04 using the same camera. Tailnet returned exact current HTML and every linked image/video with HTTP 200. Native Chrome verified all three buttons resolve to the correct image and caption; left Review 05 selected. Asset videos remain the clearly labelled earlier library turntables. Owner judgement pending; broad production acceptance is unchanged.


## Review 06 — put the six additions into the map (5 September 2026)

James found Review 05 better but asked where the new assets were. The response correctly acknowledged that only fern and bramble had been placed; the other four new types remained in the library. This revision adds all six types to the restored woodland, with marked native scene close-ups for each. The review rings and labels are rendered overlays pointing to actual model ground pivots, not retouched placement evidence.

The missing placements exposed an insertion-order defect. A shrub beside an existing tree used the intended canopy-interleaving clearance, whereas a tree beside an existing shrub used the full separation. The same asymmetry affected rocks. Both relations now use the same rule in either order. Road and projected node clearances are unchanged. The accent pass searches more local pockets; it retains the per-type caps and uses an independent seed. A focused regression checks conifer/copse and slate-bank/copse in both orders: too-close pairs fail and valid undergrowth pairs pass (`review6-planting-order.log`).

All twelve natural model IDs now occur. The 42 accents are 22 ferns, ten brambles, three wind pines, two snags, three slate blades and two scree groups. The earlier 460 main props are unchanged. An independent one-off native audit loaded the saved Review 05 kit and compared the first 460 kinds, positions, radii and actual model transforms against the revised kit: zero changes (`review6-base-audit.log`). The old kit snapshot and one-off comparison runner remain temporary diagnosis inputs; the retained log records this iteration result and is not a reusable qualification fixture.

Selected shared frame: `review6-final.png`. Six `review6-{conifer-wind,conifer-snag,slate-shard,slate-scree,ash-fern,ash-bramble}.png` images frame each marked asset in its real scene context. Fresh bridge/junction and phone/pad/desktop captures were visually inspected. All three input exercises pass pan, wheel zoom, native selection and legal preview travel. Four affected scripts pass the focused script gate, with a subsequent framing-only runner check also passing. The compiler still binds 65 nodes and 76 connections; 194 bridge spans remain. Road/bridge implementations and model files are unchanged.

Preserved Review 05 HTML as `review5.html`. This remains a bounded Step 3 owner review. The later full-section, varied-layout, physical-device and production gates are unchanged.


Review 06 delivery check: Tailnet served the exact HTML and all 17 linked media files with HTTP 200. Native Chrome then exposed intermittent broken images during concurrent loading. A synchronised 24-request burst reproduced nine HTTP 502 responses with the standard HTTP server's listen queue of five. The existing LaunchAgent now uses `tools/map_workshop/serve_review.py`, retaining its same localhost address, port, directory and Tailnet configuration, with a queue of 128. The same 24-request burst passes with exact image bytes for every response (`review6-media-burst.log`). A hard reload in Chrome shows all six location images correctly; all three comparison buttons resolve to their expected image and caption. The page is left on the new-asset section with Review 06 selected. The original LaunchAgent configuration is backed up beside the plist as `.plist.before-review6`.


## Review 07 — roads, ramps and crossings (5 September 2026)

James requested a substantial improvement to unnatural and sometimes broken roads, with freedom over the approach and another review page. This is the current bounded Step 3 revision. The woodland kit, its twelve natural types, gateway scale/site, 502 main placements, generated anchors and 76 graph connections remain in place. No domain, save, compiler or production scene is changed.

**Diagnosis.** The former surface combined separate flat footprint unions with independent ramp triangles. Their edges and landing heights were inconsistent. Elevated classification also abruptly stopped decking before the bank surface reached it. A new independent collision audit samples all original route centrelines and both shoulders against actual land/deck meshes. Before changes it recorded 35 excessive height jumps, with a maximum of 0.368409 world units (`review7-road_contacts-before.log`). The previous bridge-only ray check missed these earth-to-deck transitions.

**Reconstruction.** `road_paths.gd` supplies bounded curves to both painted trails and bridge construction, preserving generated endpoints and elevation-change planes. A single clipped grid now constructs decks, bends and ramps; shared vertices give adjacent cells identical heights, and zero-area clipping remnants are excluded. Approach weights extend along adjoining bank routes, so a graph junction cannot leave a side entrance unsupported. Deck thickness and external kerb stones follow the surface; open route entrances remain unobstructed. Low supports are retained where the deck crosses the stream. The terrain height function is memoised without changing its values, avoiding repeated full-route searches during surface sampling.

**Surface direction.** Earth paths have a narrower transition at their worn edge, restrained soil variation and fine normal relief. Bridge courses follow the route, with broad uneven stone joints and dirt wear continuing into their ends. Threshold paving remains within the travelled ground. A separate, deterministically seeded surface-detail pass adds 256 small fragments, 61 part-buried slate remnants and 305 fallen leaves across 189 groups. This supplements the route verge without replacing or reducing the accepted large vegetation. Rejected the early gateway paving halo and an exaggerated relief trial that made the path resemble a cut-out edge; neither is the selected result.

**Final deterministic evidence.** `review7-scripts.log` records ten focused scripts passing. `review7-road_contacts.log` records all 18,297 probes passing the unchanged 0.15 height-jump limit: maximum 0.146767 including shoulders, 0.082776 on the centre. The 1,659 bridge centre/shoulder probes pass (`review7-bridge_continuity.log`). All 3,858 earth-route samples retain the unchanged distance limit of 0.25, maximum 0.193165 (`review7-route_paint.log`). Three additional geometric cases cover joined branches, a closed loop with an open interior and a sloping bend. Their 1,465 probes and 3,368 triangles pass with no invalid/duplicate triangles (`review7-bridge_surface_cases.log`). The initial loop case caught degenerate clipping remnants; its failure log is preserved separately.

**Visual evidence and delivery.** Thirteen fresh native captures use the `review7-` prefix: gateway setting, river bridges, gateway junction, woodland bend, raised crossing, eastern turn, three close-ups at the camera's existing closest interactive zoom, three reference dimensions and the complete act. Every capture was inspected. Phone, pad and desktop input exercises pass pan, wheel zoom, native selection and legal preview travel. The page supplies six same-camera Review 06 / Review 07 pairs and three additional close-ups. Review 06 is preserved as `review6.html`, including the marked asset locations. Tailnet serves the exact current HTML and all 20 image/archive targets with exact local bytes (`review7-tailnet.log`). Native Chrome displays the new page; all six location buttons and both version settings resolve to the expected image/caption. Left the revised river bridges selected.

**Scope.** These checks establish the current generated sample and the three named geometric cases. They do not qualify arbitrary layered deck intersections, all generated seeds, physical-device performance or completed landscape production. Further terrain finishing, chapter expansion, full production gates and final-candidate independent review remain in their agreed later steps. Awaiting James's road review before broader section production.

## Review 08 — terrain, bridgeheads and usable openings

### Owner direction and scope

James's photograph of Review 07 identified rough road/bridge blending, a bridge
without convincing clearance, and the underlying flat terrain. This expands
this Step 3 revision to physical landforms. Review 07 remains archived in
`review7.html`; its screenshots and evidence have not been replaced.

The fixture retains all 65 node IDs, 76 connections and its X/Z layout. Its
mostly-zero Y values and three 0.384-high overpasses are semantic source tags,
not metre-scale clearance requirements. `landform.gd` now derives physical
presentation elevations. Domain behaviour, generator inputs and saves remain
unchanged. All twelve natural model types are present, with 492 placements
regrounded and rechecked against the elevated navigation anchors. This is not
an assertion that all previous scenery transforms are unchanged.

### Result

- Rolling woodland carries the earth roads; an incised river exposes banks,
  piers and real space below the bridges. Land sampling improves from 1.5 m
  to 0.5 m, with contacts interpolated from the actual rendered triangles.
- Three dry passes derive from actual upper/lower route intersections. Ground
  approach heights propagate through the connected road graph, while bridge
  landings share the upper route's height. A level saddle retains the gateway.
- Arch soffits, tops and outer walls are clipped into one joined mesh. Kerbs
  have a separate mesh: appending imported BoxMesh geometry to the arch
  SurfaceTool had discarded the pre-existing custom barrel geometry. Collision
  probes and the lower camera exposed that defect before this candidate.
- Bridgeheads include adjoining branches. Deck elevation uses one continuous
  spatial profile, avoiding nearest-segment height switches around corners.
  Four short bridge probes initially missed the analytic height by 0.043–0.061 m;
  wider diagnostic rays found intact surfaces. The profile was corrected,
  preserving the original ±0.04 m bridge coverage tolerance.
- The 55-degree play camera remains the default. Two additional 25-degree
  inspection views expose the river section and a dry crossing. Two 1.75 m
  figures are explicitly labelled scale references, not final characters.

### Deterministic evidence

- `review8-scripts.log`: all 31 workshop scripts parse.
- `review8-physical-routes.log`: 19,704 centre/shoulder mesh probes, no missing
  contacts or excessive adjacent steps; 153 adult capsule positions pass
  beneath the three dry crossings without contacting masonry.
- Measured minimum clearances over each checked central walking aperture:
  3.0779, 2.3624 and 2.4009 m. These are physical rays against the soffit mesh.
- `review8-bridge-continuity.log`: 1,887 centre and ±0.5 m shoulder rays pass.
- `review8-route-paint.log`: 3,782 source earth-centreline samples pass the
  unchanged 0.25 m coverage limit; maximum deviation is 0.193165 m.
- `review8-grounding.log`: 200 independent land rays, maximum contact error
  0.0000415 m. `review8-camera.log`: all 195 journey contexts and three whole-act
  reference shapes pass with the new physical anchor elevations.
- `review8-bridge-cases.log`: all three joined/bend/loop cases pass 1,465 rays;
  their 3,368 top triangles remain finite, non-degenerate and non-duplicated.
- Desktop, pad and phone reference captures pass pan, wheel zoom, node choice
  and legal preview travel. Each capture verifies the live generated graph.

The updated physical-route gate samples the shared rounded presentation curve,
not discontinuous shoulder offsets at a raw sharp corner. Source X/Z coverage
remains independently checked against the original fixture. The legacy road
contact entry point now delegates to this physical-landform audit. Earlier
flat-height evidence is historical, not silently claimed for new elevations.

### Visual assessment and limits

Thirteen native captures cover the six previous review locations, the closest
bridgehead, both lower inspection cameras, the whole act and all three input
reference shapes. The banks, arch openings and supported bridgeheads are now
readable as spatial relationships. The owner can compare the same locations
with Review 07; the camera framing follows the revised ground height, so the
pairs are not claimed to be pixel-aligned.

This is a meaningful Step 3 landscape revision for owner discussion, not final
commercial landscape acceptance. Terrain-led heights currently qualify this
seed-717 study; additional compiler layouts, richer environmental composition,
production performance and full campaign integration remain in Steps 4–8.
The steepest short rendered centreline gradient is 0.819 rise/run (about 39°):
the contact audit proves continuity, not an accessibility or maximum-gradient
standard. Full layout production must author longer approaches or steps where
that compact arrangement calls for them. The new body references do not prove
character animation or gameplay movement physics.

### Review service verification

The existing Tailnet service returns the current HTML and all 21 linked or
selectable media/archive resources with HTTP 200 and exact local bytes
(`review8-tailnet.log`). Native Chrome displays Review 08 and all six locations
switch correctly between revisions 07 and 08. The lower inspection section,
full-resolution links and default revised river-bridge view are available.
Awaiting James's requested Step 3 discussion; no production switch, PR or merge.


## Review 09 — road and bridge joints

### Owner request and observed defect

James asked whether the blend glitch was fixed. The Review 08 bridgehead still
showed a smeared earth-to-stone strip and visible construction seams. The agent
confirmed it was not fully fixed; James instructed: "Fix it pls". This revision
addresses that joint within the existing Step 3 sample.

Inspection found two independent causes:

- The ground and deck used different stone coordinates. Deck coordinates could
  reset at a nearest-span change, while the whole paving pattern was faded into
  earth by the geometric approach weight.
- The deck's unrelated .22 m grid could cross the land between contact vertices.
  The nominal bridge profile could also be below the hillside at an approach.
  The new triangle-interior audit reproduced 5,533 intersections in 103,155
  Review 08 samples, reaching 0.11646 m below the rendered land. Existing route
  centre/shoulder probes had not covered those surface interiors.

### Selected repair

`terrain_paint.gdshader` now uses one world-space layout through landings,
bends and joins. Unequal staggered stone flags have worn corners and shallow
bevels. Soil coverage depends on each flag, its edges and the verge: individual
stones emerge through the earth instead of an entire slab pattern becoming
translucent. The palette remains quiet and matte.

`bridge_surfaces.gd` keeps the approach above the rendered land and subdivides
its .5 m terrain grid with matching diagonals. The final .125 m spacing also
retains the existing 4 cm bridge-profile agreement. An intermediate .25 m grid
passed the ground-intersection check but missed one bridge-width probe by
4.2032 cm; that failure and diagnostic are preserved. The tolerance was not
relaxed. Vertex data additionally supplies the distance inside the deck edge
for the material's soil coverage.

`audit_landing_overlay.gd` checks the actual generated approach triangles at
vertices, edges and interior barycentric points. It fails on intersections or
an empty sample set. The original generator graph, source X/Z routes, terrain
landforms, woodland kit, lighting and camera configuration are unchanged.

### Final candidate checks

All paths below are relative to `docs/map/studies/native-workshop/`.

- `review9-overlay-before.log`: the reproduced Review 08 failure above.
- `review9-overlay-after.log`: 284,310 approach samples, zero intersections;
  minimum separation 0.0119982 m above the rendered land.
- `review9-physical-routes.log`: 19,704 physical route/shoulder contacts and
  153 adult-body positions pass. Minimum checked clearances are 3.08370,
  2.36546 and 2.40165 m. Maximum adjacent contact step is 0.12468 m.
- `review9-bridge-continuity.log`: all 1,887 bridge-width probes pass.
- `review9-bridge-cases.log`: all three branch/bend/loop cases pass 1,465 rays;
  9,864 finite, non-degenerate, non-duplicated top triangles.
- `review9-scripts.log`: both changed/new GDScripts pass the focused script
  gate. The material compiles in all thirteen fresh headed native captures,
  with no shader or runtime errors in their logs.
- `review9-{phone,pad,desktop}.log`: drag, wheel zoom, node selection and legal
  preview travel pass at all three reference dimensions. Every capture checks
  the live generator's 65 nodes and 76 edges; all twelve natural model types
  remain and there are 492 large placements.

Thirteen final native captures were visually inspected, including the closest
bridgehead, both banks, raised crossing, eastern turn, gateway, lower inspection
angles, whole act and all three reference dimensions. The stone/soil boundary
now has readable exposed flags without the previous smeared pattern or the
junction's coordinate reset. Geometry checks support this inspection; they are
not substituted for it.

### Review page and remaining boundary

The page starts with the bridgehead and compares 09/08 at six identical camera
positions. Review 08 is preserved as `review8.html`. The Tailnet service returns
the HTML and all 20 linked/selectable image/archive resources with HTTP 200 and
exact local bytes (`review9-tailnet.log`). Native Chrome displays the revised
close-up and all twelve location/version combinations select the correct image.

The current blend repair is ready for James's Step 3 review. It does not close
the full commercial landscape task. Wider layout production, campaign
integration and performance qualification of the denser bridge surface remain
in Steps 4–8. The previously recorded 0.819 rise/run maximum short path gradient
is unchanged; the physical-route gate proves contact continuity, not a walkable
maximum gradient. No production scene switch, push, PR or merge was performed.


## Review 10 — a filled, flowing river

### Owner request and selected direction

James requested the best water effect and a filled river. Review 09 had a single
flat, dark plane at -3.3 m. Review 10 uses a bounded, curved channel at -2.3 m,
following the existing riverbed. The cooler, desaturated water retains the
Ashen Woods' dusk palette. The generator graph and repaired bridge geometry
are unchanged.

The selected material combines shallow transmission and depth tint, moving
wave normals, a soft overcast-sky reflection, broken shore wash, five small
support wakes and actual bridge shadows. The current coordinates bend around
the immersed support nodes. These are authored water effects, not a fluid
simulation or planar scene-mirror implementation. No new images or models were
needed. The wider terrain and established road art remain intact.

### Implementation and discarded trials

- `river.gd` owns the single water level, a bounded channel mesh and a
  256 × 1120 floating-point riverbed field sampled from rendered land triangles.
  It also identifies five submerged support nodes from the existing bridge
  profile. Planting checks now apply the water level only inside this channel.
- `river.gdshader` uses a shared eight-second animation period, view-dependent
  sky sheen, guarded screen refraction and depth-dependent banks. The initial
  bright streaks and dense reflected pattern were rejected and reduced before
  preparing the review. The wet bank band lives in `terrain_paint.gdshader`.
- A cubemap ReflectionProbe trial produced seven texture-RID shutdown warnings
  (`review10-probe-trial.log`). It was removed; final native captures and both
  films have no warning or error diagnostics. The final view/environment setup
  matches Review 09, rather than adding another scene render for reflections.
- The original 128-wide field missed the 3 cm field-agreement limit at 20
  sampled points (maximum 4.647 cm, `review10-field-before.log`). Doubling its
  cross-channel resolution resolved those failures without changing the limit.
- `river_capture.gd` records the native material at 1/30-second intervals.
  `run.gd` also adds a labelled close inspection camera. Its smaller inspection
  zoom does not change the playable journey zoom limits.

Shader built-in and depth-coordinate conventions were checked against the
[Godot spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)
and [screen-reading documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html).

### Final evidence

Evidence files below are in `docs/map/studies/native-workshop/`.

- `review10-scripts.log`: six changed/new scripts pass the focused parse gate
  on Godot 4.7.2. Final headed captures use Metal 4 / Forward Mobile.
- `review10-river.log`: 13,818 channel-surface probes and 24,381 riverbed-field
  comparisons pass. Maximum filtered field error is 0.02324 m against a 0.03 m
  limit. Minimum checked wet width is 4.3 m. All 556 route probes within the
  river corridor are dry, with at least 2.22455 m between the nominal water
  level and the route surface. All three dry crossing centres are outside the
  bounded water mesh.
- `review10-motion.log` and `review10-close-motion.log`: each records 240
  playback frames and one closing frame. Their eight-second, 30 fps H.264
  videos preserve the material's authored pace and contain no retouching.
- The two motion-check JSON files find 52,739 and 94,881 visibly changed pixels
  between phases. Mean RGB loop-closing error is below 0.000020 of one 8-bit
  channel value. Only two/five pixels differ by more than two channel values,
  supporting an effectively continuous loop rather than a visible reset.
- Nine final still captures and the close-camera film frame were inspected.
  Phone, pad and desktop logs pass pan, wheel zoom, selection and legal preview
  travel. Native startup verifies all 65 nodes and 76 edges. The twelve natural
  model types remain; dry-bank placement now yields 491 large props rather
  than 492, so identical scenery transforms are not claimed.

### Review delivery and boundary

Review 09 is preserved as `review9.html`. Review 10 starts with the close water
film, includes an expandable journey-camera film and six same-camera 09/10
comparisons. The existing Tailnet service returns the HTML and all twenty media/
archive resources with exact local bytes and HTTP 200 (`review10-tailnet.log`).

Chrome initially reported the page unresponsive. Exiting only that review page
and loading it again restored it; the cause was not established. The fresh load
played the close film and remained responsive through all twelve comparison
selections. The journey film was also started and inspected in Chrome. This
recovery is recorded rather than silently claiming the first attempt passed.

This completes the water revision for the current Step 3 owner review. It does
not qualify wider seeds, physical-device performance, river gameplay physics
or the full campaign. The long-standing short-path gradient limitation and the
agreed Step 4 production boundary remain. No production scene switch, push,
PR or merge was performed.

## Owner decision after Review 10 — Act I Step 3 approved

James accepts the Act I sample as sufficient for Step 3, while explicitly
noting that it is not perfect. This fulfils the agreed owner checkpoint and
authorises progression into the remaining production steps. It does not
approve final commercial quality, additional seeds or the full campaign.

James also authorises the agent to apply the lessons from the Act I revisions
to Acts II–IV. Their previously approved concepts remain current. The agent
will finish and qualify the common foundation, then produce the chapters in
II → III → IV order. Each chapter should be presented as a coherent native
scene after internal inspection, followed by a combined four-act comparison;
individual model iterations do not require renewed owner approval. These
presentations provide feedback opportunities without adding routine blocking
approval gates to the agreed autonomous Steps 4–8.

The [renovation plan](../../visual-renovation-rough-plan.md) records the
carry-forward standards, distinct chapter targets and remaining production
sequence. All preceding review findings and evidence remain historical records.
