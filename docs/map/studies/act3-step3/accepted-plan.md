# Act III Step 3 — The Obsidian Court

## Accepted intent

Implement the owner's agreed plan: a coherent, imposing obsidian royal precinct,
judged against the approved Act III v5 concept and actual combat art. Close travel
is the default experience; zooming out supports whole-journey planning. Preserve
`774cb7375b38ca8bf81f7478aac4b6b8d1faedbd` as the comparison baseline.

The owner chose an **Act III-specific generated spatial layout**, preserving game
nodes, encounter types, edges, seeds and saves. Existing Act II coordinates are
not the new composition constraint. Coordinates must come from the generator,
not manual node movement or omitted edges to rescue a screenshot.

This is the complete Act III Step 3 outcome, not merely a successful test section.
Act I/II approval remains intact. Act IV, Step 4 and campaign integration retain
their agreed later order. Chapter approval remains the owner's checkpoint.

## Visual requirements

### Review reset: observed gap and priority

The saved `court-roads-v7-whole.png` and `court-roads-v7-passage.png`,
reviewed against the approved v5 concept, remain below the delivery bar.
The route diagram dominates the precinct; repeated detached buildings have little
spatial purpose; the circular royal annex weakens the journey's culmination.
The close view exposes pointed paving joins, overlapping stair surfaces and dark
passage artefacts. A passing layout evaluator cannot approve these qualities.

Execute in this order, with an explicit visual decision at each boundary:

1. **Whole-place composition:** establish entrance, enclosed cloisters, audience
   court and sovereign forecourt in one greybox. Compare the whole silhouette and
   three journey views with markers hidden. The hall must belong to the route's
   culmination; buildings must form spaces rather than occupy leftover gaps.
2. **Architectural circulation:** use terraces, court paving and stairs. Remove
   unnecessary crossing detours through generated layout. Where a crossing is
   necessary, make it an inhabited-scale passage within the architecture.
   Reject awkward loops even when they pass intersection checks.
3. **One representative finished section:** include a fork, merge, complete
   turning landing, passage and building entrance. Inspect actual full-width
   contacts and headroom, then surface treatment, light and camera movement.
   This is an internal proving section, not the owner's chapter deliverable.
4. **Architectural character and atmosphere:** develop meaningful kit variants,
   foundation continuity, pointed openings and recessed glass. Quiet ground,
   controlled cool highlights and concentrated magenta must recover the intact,
   sombre royal character shared with combat. More assets alone are not progress.
5. **Whole-chapter completion:** apply the proven construction rules throughout,
   inspect every route and landmark, then perform the reference-shape, input,
   performance, regression and independent review requirements below.

Neither new greybox surfaces nor a clean isolated hall constitute completion.
The recent passage experiment still has awkward route-end shapes; its shadow-off
capture only diagnoses lighting and cannot be the final lighting solution.
Retain the full-chapter composition checkpoint while resolving local geometry so
that component work cannot consume the project without improving the place.

- Rows 0–3 establish the outer entrance; 4–8 pass through cloister courts; 9–12
  approach the recessed audience court; 13–14 enter the sovereign forecourt.
  Preserve forward journey progress while varying enclosure, scale and sightlines.
- The royal precinct terminates the journey, with the boss on its usable forecourt.
  Entrance, recessed court, gallery, great stairs and hall share foundations and
  meaningful spatial relationships. Replace the detached circular annex.
- Produce controlled Blender geometry for the hall, gateway and reusable kit:
  substantial pointed arches, deep window recesses, blade-shaped buttresses,
  complete faceted roofs, retaining walls and finished platform edges. Secondary
  buildings vary by bays, depth and entrance arrangement, not only scale/rotation.
- Ordinary routes are court paving and stairs. Avoid crossings through layout
  where feasible. Required grade separations become short architectural passages
  with deliberate entrances, walls, roof and foundations, not enlarged bridge parts.
- Keep approximately 75% of open ground quiet. Arrange selected slab joints by
  architecture and platform boundaries rather than an all-over Voronoi network.
  Use broad obsidian planes, restrained bevels, cool edges and roughness variation.
- Establish foreground, middle ground and hall values. Retain readable dark forms;
  concentrate magenta in glazing, the halo and selected structural joints. Use
  purposeful grouped details such as empty stone seats, seal pillars and low
  ceremonial fixtures. Only the supernatural halo is deliberately fragmented.
- Retain the agreed controls. Resolve camera scale and occlusion in greybox using
  fixed close, journey and whole views; include any changed camera in its profile
  and evidence identity.

### Natural terrain relief — owner addition

Owner clarification: the courts themselves must also rise and fall as distinct
level platforms joined by stairs. Exterior relief and landscape openings are
supporting treatment, not substitutes for this architectural journey. Compose
an ascent into the cloisters, a lower audience court and a raised sovereign
forecourt; resolve their actual elevations through the spatial generator and
shared stairs, with level arrivals and consistent building foundations.

The landscape must have visible, continuous rises and falls. Flat court plates
at several heights alone do not satisfy this requirement. Establish broad land
forms, shallow depressions and sloping shoulders in the composition greybox,
before adding surface detail. Use restrained, directed relief rather than noisy
displacement; preserve the intact royal precinct and its quiet ground treatment.

- Keep usable courts and building pads level, blending their edges into the
  surrounding land through graded slopes or deliberate retaining structures.
- Roads follow a consistent elevation solution. Resolve slope changes with
  walkable gradients, level landings and stairs where needed; no floating paving,
  buried entrances, exposed gaps or terrain intersecting passage headroom.
- Provide one reusable, deterministic terrain-height contract with per-act
  parameters. Terrain, route contacts and foundations must agree on elevations;
  do not add an independent visual displacement layer that breaks those contacts.
  Bound this work to the study's required terrain and contact capabilities.
- Validate a representative rise, depression, court edge and route transition
  from close and whole views, including camera occlusion. Then inspect the whole
  chapter silhouette and compare neighbouring acts for compatible scale and style.
  Adopt the capability in approved acts only through explicit configuration and
  relevant regression checks; this addition does not reopen their approval.

## Cross-act consistency — owner constraint

Major visual renovation must not drift into an Act III-only rendering or
interaction system. This constraint governs the quality reset and subsequent
implementation choices.

- Keep chapter-specific composition, architecture, palette, atmosphere and
  generated region parameters in Act III assets and profiles.
- Implement generally useful road/stair construction, terrain contacts, passage
  supports, water, camera and interaction behaviour through shared modules with
  explicit per-act configuration. A file under `common/` alone is not proof of
  reuse: it must have a clear contract without hidden Act III assumptions.
- Prefer extending the existing shared module. If an ambitious improvement needs
  a separate framework or a broad migration across chapters, reduce this delivery
  to the smallest coherent change that fits the established system. Do not build
  a parallel Act III engine or speculative general-purpose framework.
- Preserve approved Act I/II appearance and behaviour by default. Reusable
  capability does not authorise automatically redesigning approved chapters;
  adoption can be opt-in through their profiles after appropriate validation.
- Before accepting a shared change, inspect its affected Act I/II views and run
  the relevant regressions. At the composition and final visual checkpoints,
  compare the acts side by side for camera scale, route readability, material
  treatment and detail density. Chapter identity may vary; the game's visual
  and interaction language must remain coherent.
- Next implementation action: classify the existing uncommitted additions as
  chapter content, reusable capability or avoidable duplication. Consolidate
  actual duplication and narrow unjustified scope before adding new systems.
  This is a bounded review of the current diff, not a repository-wide refactor.

## Implementation and interfaces

- Add a versioned spatial profile covering regions, row stations, candidate anchor
  domains, terrace heights and hero reserves. Candidates, routing and evaluation
  must consume the same profile. Include it in the input's quality digest/cache key.
  Default profiles must preserve the existing chapters' exact output. Keep game
  IDs and save schemas unchanged; issue fresh layout receipts for the new study.
- Reproduce stair overlap, pointed seams, passage striations and intersections
  using wireframe, unlit and depth inspection before attributing a cause. Construct
  paving, risers, walls and foundations from one resolved surface/flight plan,
  with one owner per walking surface rather than overlapping raised patches.
- Risers are at most 0.17 m, treads at least 0.28 m. Turns have complete landings.
  Preserve governed corridor widths. Passage clearance is at least 2.4 m above
  the finished walking surface. Adjacent components share contact boundaries.
- Reuse graph generation, routing, interaction and actual-mesh probes. Share
  meshes/materials and batch repeated architectural pieces. Reserve dense geometry
  for silhouettes, turns and curvature rather than broad planar floors.

## Execution and the four rules

Follow `docs/agents/ai-sdlc.md`, which adapts Anthropic's AI-native SDLC:
accepted intent -> design -> implementation with continuous decisive tests ->
independent exact-candidate review -> the agreed owner visual checkpoint.

1. Keep this single task capsule, with requirements, defects, decisions and evidence.
2. First resolve a real generated section containing a branch, merge, grade change,
   passage and architectural entrance. Pass composition, geometry, materials and
   light there, then apply the coherent rules to the full chapter.
3. Minimise wall time: one hypothesis per local experiment, narrow checks and fixed
   close captures first. Assemble once per candidate and batch views. Reuse only
   source/input-matched builds. Full movies, all shapes and the full core gate
   follow a coherent final candidate; rerun only evidence invalidated by changes.
4. Minimise tokens: mechanical checks use scripts; judgement focuses on design and
   defects. One implementation owner, then the repository-required independent
   reviewer. Two unsuccessful fixes of the same defect trigger renewed diagnosis,
   not more offsets. Time/token savings never lower visual or technical acceptance.

## Acceptance and deliverable

- Master seed 717, plus fixed smoke seeds 4 and 2026: deterministic layout identity,
  unchanged game graph, complete routes, no false junctions or unreachable segments.
- Probe full route width, actual treads, landing contacts, supporting terrain,
  passage headroom and architectural obstruction. Add meaningful regressions for
  observed defects. Preserve 44 px targets and verify selection, pan, zoom and the
  current position. Changes to shared compiler code require the complete Godot
  core gate once on the coherent candidate plus affected specialist checks.
- Profile scene construction, CPU/GPU frame time, draw calls and memory separately.
  Capture-loop elapsed time is not gameplay performance proof. Do not claim physical
  device qualification from desktop-host reference viewport tests.
- Inspect close, journey and whole views at 844x390, 1180x820 and 1458x820, with
  overlays hidden and shown. The place must remain coherent without its markers;
  choices and current position remain clear with them.
- Visible seams, intersections, floating structures, patchwork stairs, lighting
  artefacts, flicker and excessive floor noise are blockers. Inspect continuous
  panning, zooming, passage traversal and the sovereign approach, not selected stills
  alone. Every known defect needs same-view before/after evidence.
- Compare silhouette, scale, material, value and emotional character against the
  approved concept and combat. Author inspection and independent review must both
  assess visual quality as well as technical correctness.
- Deliver one coherent, unretouched native Act III review page: journey and hall
  views, critical junction close-ups, a continuous tour and concise verification.
  The full Act III chapter, not the representative section, goes to owner review.

## Owner-requested quality reset — next execution order

This section supersedes the older capsule's proposed next action. The current
request is to plan the improvement before further implementation. Preserve the
existing work and failed evidence; do not continue the input matrix as the next
creative milestone.

### Fresh visual judgement

Compared the approved v5 concept, the published `court-roads-v7-whole.png` and
`court-roads-v7-passage.png`, and the latest private
`/tmp/act3-precinct-whole.png`. The published study has diagram-like raised paths,
repeated detached structures, an isolated circular terminus, pointed contacts,
patchwork stairs and visible dark striations at the passage. The private study
has better integrated floor support but still reads as a long strip of grey
platforms with repeated edge arcades. It has not passed whole-place composition.
These are visual observations, not claims that every underlying cause is known.

The art objective is an intact, oppressive royal precinct: constrained arrival,
a measured procession through cloisters, an unexpectedly empty audience court,
and a sovereign hall that dominates the culmination. Empty space must be bounded
and deliberate. Maintain the approved combat-derived black-violet obsidian,
angular supports, recessed magenta glazing and broad quiet slabs. Only the halo
is broken. Reuse a component only where it serves that composition.

### Ordered work and decisive gates

| Order | Work | Evidence that permits progression |
| --- | --- | --- |
| 1 | Recompose the generated precinct around entrance, cloisters, audience court and hall. Establish their masses, enclosing walls, levels and procession; make the hall part of the boss forecourt. Derive node positions within those regions from the generator. | One master-seed greybox, markers hidden, at whole view and three journey positions. Each space is recognisable, architecture forms the space, and the destination dominates without becoming a detached annex. Reject another ribbon of platforms. Check the same rules on the two smoke seeds before detailed propagation. |
| 2 | Resolve one real generated fork, merge, turning stair, passage and building threshold. Floor, riser, retaining wall and entrance must share resolved boundaries. Remove unnecessary crossings; necessary crossings belong inside substantial architecture. | Same-camera lit, unlit and wireframe inspection plus full-width contact/headroom probes. No pointed fins, overlapping treads, light leaks, floating bases or unexplained black surfaces. Diagnose two failed hypotheses before attempting another fix. |
| 3 | Finish that section: faceted obsidian, broad quiet paving, deep lancets, strong structural edges, restrained reflected magenta and useful secondary details. Vary architectural purpose and bay arrangement. | Close and journey captures beside the approved concept and actual combat reference. Materials and silhouette agree; dark forms remain readable; ground texture and glow do not dominate the route. No extra asset count can substitute for this decision. |
| 4 | Apply the selected rules to the complete generated chapter. Shape enclosure and release across the four regions; finish the sovereign approach and halo setting. | Inspect every route and landmark, including edges of platforms, stair turns and building contacts. All nodes and connections remain intact. Recheck whole-place composition without markers after propagation. |
| 5 | Complete camera and interaction within the finished spaces. Keep current position and choices readable, with stable movement through passages and towards the hall. | Continuous unretouched pan/zoom/travel recording and input checks at all three reference shapes. Resolve the outstanding seed-4 phone drag failure. Verify actual controls against the commercial target-size requirement, not only the existing 44 px study check. |
| 6 | Qualify and present one coherent candidate. Bind actual assets/camera to the layout profile, measure performance, run applicable regression gates, then one independent exact-candidate review. | Separate construction cost, CPU/GPU frame times, draw calls and memory; do not infer device performance from desktop captures. Final native review page includes the whole journey, close defects before/after and continuous tour. Owner approval remains the Step 3 chapter checkpoint. |

### Four-rule execution discipline

- AI-SDLC: use the repository's Anthropic-adapted process as the authority. Link
  each change to an observed defect or intended player experience, its cheapest
  discriminating check, and the resulting decision. Preserve failed evidence.
- Wall time: one implementation owner; resolve the highest-impact composition
  uncertainty first. Prove one representative section before propagating it.
  Batch views from one build; repeat only checks invalidated by a change.
- Tokens: maintain this plan and a compact current capsule. Use scripts for
  measurements and identity checks; use visual judgement for composition,
  atmosphere and defects. Do not generate repeated reports or overlapping reviews.
- No compromise: neither a passing script nor a flattering camera exempts a
  visible defect. Do not send another owner review page while known visible
  blockers remain. Full relevant gates and the final independent review still
  apply once a coherent candidate exists.

### Current technical evidence to retain, not confuse with art acceptance

Overview grouping conserves IDs and avoids overlapping 44 px targets in completed
runs. Stable per-frame button visibility fixed a real press-reset issue; cluster
and singleton clicks pass in the observed runs. Seed 717 completed all three
reference shapes. Seed 4 at 844x390 still reports `drag_pan: false`, including
`/tmp/act3-overview-drag-corrected.log`; changing the test origin and adding pointer
motion did not resolve it. Diagnose event delivery and camera state before another
fix. The full overview matrix is incomplete. No study processes were running at
this inspection. The remote review page remains the older roads v7 study.

The commercial rubric specifies at least 60x60 px at the 1180x820 design
resolution. Existing 44 px study checks are partial evidence only; the final
reference-shape interaction qualification must respect that requirement.

## Execution mode and delivery control

The owner requested a transition from Goal-driven continuations to an ordinary,
sustained task on 7 September 2026. This changes execution mode only: implement
this entire plan through the agreed Act III Step 3 owner review, preserving all
visual, technical, cross-act and independent-review requirements. Goal shutdown
is controlled by the app/user. The owner confirmed Goal is off on 7 September
2026 and authorised this sustained ordinary run.
Never mark the unfinished objective complete or blocked merely to disable Goal.

- Continue authorised implementation and verification within the active run.
  Do not finish a turn merely because one small component passes. Platform
  interruption or an actual authority/evidence blocker may still require a handoff.
- Keep concise progress updates during work. Use this current capsule and targeted
  source reads; consult older receipts only when they answer a specific question.
  Avoid repeated full-plan reads, repeated status reports, unbounded experiments
  and large raw tool outputs. Disabling Goal does not itself guarantee token or
  prompt-cache savings, and those savings must not be claimed without evidence.
- The first recovery checkpoint closed the four route failures. For the next art
  phase, report a concrete visual decision within 60 minutes of resumed work;
  use 100,000 additional tokens as an earlier review point if task-level usage is
  available. If Goal accounting is unavailable, say so; account quota is not a
  substitute for task tokens. A checkpoint prompts evidence-based reforecasting,
  not an automatic end to the task or a relaxation of acceptance.
- The SLT report's 44% and 8–12 remaining hours were provisional estimates at the
  time of reporting, not current measured completion or a guaranteed deadline.
  Reforecast at the next substantive checkpoint, including elapsed time, remaining
  work and cost where measurable. Do not silently roll the delivery window forward.

Current delivery boundary: corrected Act III Step 3 native study and review page
are complete. Full-core validation completed: PASS (101 tests), exit 0, no
SCRIPT ERROR; retained headless diagnostics are documented in the verification report. Independent semantic review
approved candidate `0315abe3f07f7ad7b8885abb737ce10a1a23bd5d` with no blockers,
explicitly retaining the full-core delivery gate and owner chapter checkpoint.
Act IV and Step 4 remain outside this delivery.

## Act III Step 3 follow-up completion — 7 September

The owner clarified that route reading and combat alignment belong to this same
complete Step 3 delivery. No separate direction approval is required. Continue
until implementation, native validation, core checks, independent review and
report are complete. Do not stop at an intermediate comparison page.

Scope: opt-in shared route guidance wired to actual precinct node selection,
selected-branch travel and overview; shared Act III finish authority; quieter
combat ground with the original complete alpha footprint. Preserve game truth,
all generated edges, prior chapter styles and the native precinct composition.
Step 4 campaign-map integration and Act IV remain later work.

Implementation and native verification are complete. Nine seed/shape runs pass
15 actual next-event selections, full-network presentation, source immutability
and 112,656 floor samples. Final combat comparisons cover all three proportions;
294,912 alpha samples preserve authored opacity at 0.8/0.9/1.0. The native 21.266 s
movie was played to completion through the tailnet page. Host Metal overview
active GPU P95 is 4.359 ms across 503 complete frames; no physical-device claim.

Independent review APPROVE: `5e3e86429470eec07f2b545fff303f2519adaf11`, after
one batch corrected an actual CanvasItem-modulation regression and a report seed
label. All 11 scope-selected checks, imports, map-assets and store exclusion pass.
Final delivery gates complete: core PASS (102 tests), exit 0, zero SCRIPT ERROR;
parser PASS (431 scripts). Final report records known headless diagnostics,
completion percentages, measured time and root-session token deltas.
Final documentation and evidence are saved with the delivery on the owned branch.

## Current execution capsule

Owner review page:
`https://jamess-macbook-pro.tail55e87e.ts.net/docs/map/studies/act3-step3/precinct-v4/`.
Act III Step 3 engineering is complete. Save the final report and stop at the
agreed chapter checkpoint. Do not begin Act IV or Step 4.
Previous precinct-v2 receipts below are retained historical evidence; they do not
replace the current extension's final gates or the owner's chapter art judgement.

### Review correction in progress — 7 September

The corrected normal exports pass for all three seeds (65/66/54 nodes,
76/74/74 edges), preserving complete node records and edge IDs. All nine native
runs pass: 555 node focus/click checks and 30,927 route-camera samples, with
full-width support, foundation and covered-passage checks on each seed. The
shared surface simplifier now bounds positional deviation after a reproduced
0.24 mm corridor loss; the audit tolerance remains unchanged.

The 57.6-second native movie contains an uninterrupted 14-edge entrance-to-boss
walk (1,675 travel frames, zero measured occlusions). The tailnet page was opened
and the movie played to completion without a media error. Act I/II native visual
and input regressions pass. Final host Metal tracing measures 632 complete
frames: active GPU median 1.024 ms, P95 1.468 ms, maximum 6.289 ms. An initial
recorder crash was rejected; the successful five-second retry supplies the data.
Native frame-interval P95 is 8.49–8.564 ms and renderer allocation peaks at
131.78 MiB in the measured master views; these do not qualify physical devices.

Imports and 424-script parsing pass. The first corrected core run printed
PASS (101 tests), but a pre-existing Dawn fixture aborted before its assertions.
Its missing Vigil quest profile is now initialised exactly as application boot;
the unchanged focused assertions pass without errors. The complete rerun passes
101 tests, exit 0, with no SCRIPT ERROR. Existing headless material/tree and
shutdown diagnostics remain; see `docs/map/studies/act3-step3/precinct-v2-verification.md`.
All 11 selected checks, map asset validation and store exclusions pass. Independent review APPROVE binds corrected commit
`0315abe3f07f7ad7b8885abb737ce10a1a23bd5d`; owner chapter approval remains pending. The last conditional forecast was 45–75 minutes from
the start of final qualification if no new material finding emerged. Task token
accounting is unavailable without Goal; no cache-saving claim is made.

Candidate `221113500882cee35ab158c799aa386e212a1da1` received
`REQUEST_CHANGES` from the isolated final-candidate reviewer: patchwork stairs
and matte, undifferentiated masonry remain blocking visual findings. Do not
present `precinct-v1` as finished or silently relabel its existing evidence.

- Its core runner printed PASS (99 tests), exit 0, but retrospective log
  inspection found the same Dawn fixture abort; this was not a complete pass.
  Dummy-renderer material and shutdown resource/RID diagnostics were also present.
- A new opt-in transverse court stair mode and shared flight assembly replace
  narrow oblique flights/tall piers with complete grouped stairs and low retaining
  edges. Trial native support probes pass; these trial coordinates are explicitly
  diagnostic, not a compiler receipt. Formal samples must be regenerated.
- Initial formal export failed; a reduced regression exposed missing height
  normalisation for level routes and raw endpoints. Both failures were reproduced
  and fixed. Three focused regressions and a retained-route grade probe now pass.
  The corrected normal master export is in progress. Do not expand search limits.
- Obsidian material trials add selected cold glints and structural magenta seams.
  The excessive specular trial was rejected; floors/routes now share the same
  mapping to prevent mismatched slabs exposing route cut-outs.
- Separate Metal tracing works: the old candidate's 1,261 complete sampled frames
  show active GPU union median 1.684 ms / P95 3.183 ms on this M1 Max host. Other
  applications can contend; these are not device-floor qualification or final
  candidate measurements. Raw traces contain environment metadata and stay local.
- Next: complete formal exports, inspect the corrected native master, then repeat
  the affected seed/shape/contact/travel matrix and final checks; obtain the
  required review of the corrected head and deliver the review page. Chapter
  approval remains pending. No first-push, PR or merge has occurred.


- Ordinary run resumed after the owner confirmed Goal shutdown. The `precinct-v1`
  candidate adds sovereign side galleries, open foreground arcades, quieter route
  contrast, restrained architectural courses and faceted exterior relief. Native
  whole captures now fit the complete architecture at each reference aspect.
- Fresh normal exports: 717/4/2026 retain respectively 65/66/54 nodes and
  76/74/74 routes; all compiler hard checks pass. All nine native seed/aspect runs
  pass node selection and route visibility. Receipts and images are under
  `docs/map/studies/act3-step3/precinct-v1-*`.
- Fixed an obsolete covered-threshold audit assumption: open-air mode still
  requires walking samples and rejects low obstructions; covered mode still
  requires ceiling evidence. The new regression covers missing support, absent
  ceilings and low obstructions. All 26 added regression tests pass.
- The corrected continuous tour starts at generated entrance `0,0`, traverses
  14 edges to `14,3`, renders 1,779 travel frames with zero occlusions and leaves
  current game position unchanged. The earlier current-node-only recording is
  not full-journey evidence. The review page's MP4 plays over the tailnet.
- Native stationary frame-interval P95 is 8.6–9.8 ms on this desktop. GPU timers
  are unavailable on Metal, not zero-cost. Maximum sampled renderer allocation
  is 134.86 MiB; this is not process physical footprint. Tablet/wide construction
  without geometry-audit flags is approximately 1.85–1.86 seconds.
- Full import gate passes; full script sweep passes (420 checked). Full core
  tests are running. Act I and II native inspection and operation checks pass.
  All selected specialist checks pass. Final independent review, final delivery decision and owner
  chapter approval remain outstanding. No commercial-quality approval is claimed.
- The matrix used explicit sample paths. The only subsequent capture-entry
  changes replace its machine-local default with the checked-in master sample
  and share packed kit resources. The entrance movie validates the default;
  a later native sharing check repeats all master routes and timing. Journey,
  threshold and passage captures are pixel-identical; whole/court differences
  are confined to the animated halo. Do not rewrite matrix hashes.

- Hall regenerated after pane winding correction (20,424 triangles). Native kit
  quarter view and full sovereign court inspected: glazing visible, but roof and
  facade still need restrained surface detail and composition remains below v5.
  New authoritative master sample `/tmp/act3-glazed717-full.json` has input
  `bd0bf549de304fbc7c3b9faec3750a613a83d57051a4bafad9970364e5c98536`,
  layout `e15010635959abf2350c9efa6b7a209c7d2758990bfacc7a143dc9d35a25c4cb`,
  hero SHA `67fe81ebd14d7b31263afda1257580adef18a3723edaf939d8f845bd6a95743d`.
  Normal compiler hard_pass=true, 65 nodes/76 edges; anchors and edge IDs match
  previous master. Old samples are now stale for the hall source. Native master
  route audit passes with the new taller galleries: 3,011 samples, zero occlusions
  and heading changes (`/tmp/act3-glazed717-native.log`, exit 0). Continuous
  whole-chapter, smoke seeds, full-width and final gates remain outstanding.

- Gallery art iteration: taller pointed glazed returns now punctuate the low
  cloister, with finials and three recessed amethyst lancets. Initial view was
  still blank: face orientation alone was insufficient because the court camera
  sees the return from either side. Both faces now have real glazing and leadwork.
  Inspected `/tmp/act3-glazed-twoface-threshold.png`: glass reads clearly and the
  silhouette improves. Whole-chapter composition remains unfinished.
- Builder supports `--asset=glazed-gallery-bay` for bounded regeneration, leaving
  the source-bound hall unchanged. Native master capture exits 0 with occupancy
  checks; full route visibility is invalidated by taller geometry and must be
  rerun on the coherent art candidate. The pane winding helper changed; the hall
  must be regenerated and re-bound before final delivery, not treated as current.

- First delivery checkpoint result: four previously rejected master routes now
  pass without camera heading changes after render-consistent culling. Master
  phone current-road continuous travel also passes: 491 rendered frames, zero
  occlusions, completed/cancelled/current unchanged; `/tmp/act3-culled-travel717.log`
  exit 0. This is one outgoing road, not a complete continuous chapter tour.
- Re-inspected native whole view against Act III v5 concept: the current long
  rectangular precinct and small isolated hall still lack the concept's composed
  enclosure, architectural height rhythm and rich dark material separation.
  Next work is whole-place art/composition within generated route reserves, not
  another camera framework. Full final visual matrix/review/page remain pending.

- Delivery-control reset (7 September 2026, owner SLT report): estimated 44%
  complete, not acceptance. Conditional remaining effort 8–12 hours: diagnosis
  1–1.5 h, whole-chapter art 3–4 h, full visual/technical/performance coverage
  2–3 h, final gates/review/page 2–3.5 h. First checkpoint is 60 minutes or
  100,000 additional tokens, whichever comes first; reforecast from evidence,
  never silently extend. Baseline goal usage 2,399,269 tokens on resumption.
- Current discriminating fix: sightlines treated culled back faces as visible
  occluders. Native failure view and triangle probe identify a back-facing court
  wall. Regression fails before cull handling and passes afterwards. Explicit
  override materials now supply their cull mode; unknown/mixed materials remain
  conservatively double-sided. Exact segment tests and triangle batches remain.
  Three focused tests pass (`/tmp/act3-culling-regressions.log`). Full master
  route audit passes: 3,011 samples, no occlusions, no heading changes, no edge
  filter. All four previous failures cleared (`/tmp/act3-culled-routes.log`, exit 0).
  This proves sampled centre-line views, not full-width or continuous travel.

- Targeted native probe now supports `--route-edge=` and reports the filter, so
  local diagnostics cannot be mistaken for the whole-route audit. Zero rendered
  probes cannot pass. For `3:9,1>4:10,2`, `/tmp/act3-transition-probe.log`
  identifies CourtSurface triangle 5575 at (68.18388,.951794,-11.69339), reported
  back-facing; walking surface lies behind it. Next distinguish winding/contact
  defects from conservative two-sided sightline testing before changing geometry
  or culling. No architectural fix is established by this probe. Process exited 1.

- Latest court decision: level precinct platforms joined by real stairs and
  landings; surrounding landscape carries broad natural relief. Internal stairs
  now use open-air capped piers (shared threshold maximum arch span 0), keeping
  pointed vaults in the galleries. Inspected seed-4 threshold and midpoint images.
- Selected open-terrace seed-4 phone travel passes: 529 rendered frames, zero
  occlusions, completion/cancellation/current-state checks pass. Evidence:
  `/tmp/act3-open-terrace-travel4.log`. This supersedes the seed-4 failure below.
- Master all-route audit remains FAIL: 2,813 rendered samples; four rejected
  transitions: `3:9,1>4:10,2`, `3:9,3>4:10,3`, `4:12,5>4:13,4`,
  `4:12,5>4:13,5`. Evidence `/tmp/act3-open-terrace717-routes.log`.
  Component success is not chapter acceptance; the review page is unchanged.
- Sightline triangle batching preserves the exact intersection test, with 128
  triangles per candidate bounds. Corrected pure test passes 520 comparison rays
  without scene-tree errors. The previous initialisation-time test run emitted
  invalid-tree errors and is not valid evidence. Narrow parser and focused test
  pass; no measured performance claim yet.
- Next: inspect actual obstructing triangles at the remaining terrace transitions,
  then improve whole-court composition against the accepted concept. Overall art
  remains below the review bar; full gates and final independent review remain.

- Travel now limits both translation and angular speed through segment duration;
  short demanding turns slow travel instead of exceeding 40 degrees/second.
  Regression failed before the change and passes afterwards; existing heading
  and travel tests pass (`/tmp/act3-turn-time-{red,green}.log`). Seed-4 phone actual
  rate is 40.00214 degrees/second (floating tolerance .02), but 44 frames remained
  occluded (`/tmp/act3-travel4-timed.log`, exit 1). Timing alone is insufficient.
- Shared heading planner now validates interpolated positions/directions at
  <=5 cm / 1 degree and bans failed transitions, with cached visibility and eight
  bounded attempts. Tests reject clear endpoints with a hidden midpoint and find
  an alternative when available. Real seed-4 search exhausts; preview refuses it.
  `/tmp/act3-visible-travel-tests.log` passes; `/tmp/act3-travel4-visible.log` fails.
- Actual mesh probe `/tmp/act3-travel4-occluder.log` identifies the obstructing
  threshold vault: target (-35.50534,0,18.95726), heading 24 degrees; front-facing
  vault triangle 95 at (-33.64288,6.78955,23.14042), in front of the walking surface.
  Do not continue raising search/turn limits speculatively. Next evaluate local
  architectural visibility treatment for the vault (preserving its form and
  shared-module boundary), and inspect actual movement. No active processes.
- Route sampling audit's spatial turn bound is now 90 degrees/metre for the
  variable-speed plan; actual preview owns the 40 degrees/second comfort limit.
  The shared planner's default remains 12 degrees/metre for fixed-speed callers.
  This change is not whole-route or final chapter acceptance; seed-4 travel remains
  a known failure and no owner review page was updated.

- Added shared cancellable `route_travel.gd` and opt-in extra inspector controls;
  Act III has a Travel button previewing the selected/current node's first onward
  road without mutating progress. Unit tests cover distance interpolation, zero
  segments, endpoint stop and cancellation. Master actual button test passes:
  483 interpolated frames, no centre occlusions, Escape cancels, current unchanged
  (`/tmp/act3-travel-native.log`, `/tmp/act3-travel-tests.log`). Midpoint inspected
  at `/tmp/act3-travel717-midpoint.png`; not a continuous video review.
- Seed-4 phone all-node gate passes 66 nodes, but real travel exposes 39 occluded
  frames (`/tmp/act3-travel4-phone.log`, exit 1). Coarse 2 m planning was insufficient.
  Tightened sampling to 0.5 m and fallback headings to 1 degree. The preview now
  correctly refuses the infeasible plan rather than playing through occlusion.
- Diagnosis `/tmp/act3-travel4-diagnosis.log`: edge `3:3,5>3:4,6`, sample 31 at
  (-29.79674,1.8,22.19157), 147 visible headings, but none reachable under the
  chosen 12 degrees/metre bound. This is a turn-scheduling limitation, not proof
  of a geometrically invisible point. Next consider distance-and-angle timing:
  slow travel at demanding turns while preserving a bounded angular speed and
  validating interpolated visibility. Do not simply increase turn speed to pass.
  Shared planner default bound/tests remain intact. No active processes remain.
- Travel across other roads/seeds, full-width visibility, continuous recording,
  full candidate checks, final art/composition and owner review remain unfinished.

- Both bound-hall normal exports (seed 4/2026) completed with hard_pass=true;
  `/tmp/act3-bound-hall{4,2026}-full.json` are available. No compiler jobs remain.
- Added terrain to actual-triangle camera blockers and an opt-in rendered route
  camera audit. Original point-local focus: 1,099 samples, no occlusions, but
  20 heading changes up to 110 degrees (`/tmp/act3-route-camera-audit.log`, exit 1).
  Fixed heading per whole edge removed turns but failed seven samples on six
  routes (`/tmp/act3-stable-route-camera.log`, exit 1). Both failures retained.
- Shared `route_camera_heading.gd` now searches a bounded heading path only when
  one constant heading cannot cover the route. Dynamic programming minimises
  squared turn rate, with a 12 degrees/metre limit; clear directions come from
  actual triangle visibility. Focused tests cover look-ahead and impossible
  abrupt turns. Master native planned audit exits 0: 1,099 samples, no occlusions,
  six bounded changes, maximum 15.000004 degrees; actual camera basis measured.
  Evidence `/tmp/act3-route-heading-path-test.log`,
  `/tmp/act3-planned-route-camera.log`. This is sampled centre-line planning, not
  continuous animation, full-width visibility or an implemented tour control.
- Next integrate a cancellable shared route-travel preview using these plans,
  inspect interpolated movement and qualify the other actual generated maps.
  Chapter art/composition, remaining reference shapes, performance, final gates,
  independent review and owner review page remain unfinished. No active process.

- Actual-hall normal master export passes; layout
  `a986179dfca3537a27e72c24549a9c8e2c8ad9ddc90d058f0cf3282b46b7d04c`.
  Bound-hall recipe promoted to `act3/spatial-recipe.json`; study defaults to
  `/tmp/act3-bound-hall717-full.json`. Master native all-node input at 1180×820
  exits 0: 65 focus/clicks, no failures, basic/overview/target gates pass
  (`/tmp/act3-bound-hall717-input.log`). This is one shape, not the whole matrix.
- Lighting comparison rejected bright broken specular patches in
  `/tmp/act3-rejected-lighting-court.png`. Selected restrained filmic exposure,
  weaker non-specular rim and caller-configured stone roughness .60–.72.
  Shared shader defaults remain .68–.82 for other callers. Native capture exits
  0, `/tmp/act3-controlled-lighting-court.png` inspected. Incremental tonal change
  only; chapter art and composition remain unapproved.
- Bound-hall normal seed 4/2026 exports now running with the promoted recipe:
  `/tmp/act3-bound-hall{4,2026}-full.json`, matching logs. Resume those processes
  before further sample work. Continue geometry/input qualification on their
  selected outputs, then close outstanding camera movement and composition.
  No final core/import gate, independent review or owner review-page update yet.

- Both outstanding stepped normal exports completed successfully: seed 4 layout
  `4137bf86408d07a18d44e31e3b9c551272c14b548ad6f3bd96b620e7c6be257a`,
  seed 2026 `6b2e2a3b51b04e587baa67a4da92ff2446473b0302303ece0744a01ebf92750b`.
  Their native geometry still needs inspection. These still use the legacy hero
  profile and are not proof of the new binding below.
- Added opt-in shared workshop hero binding using actual glTF nested triangle
  transforms and the existing `MapAssetProfiles` profile/digest implementation.
  Recipe supplies asset ID/path, node-relative offset, scale and yaw. Source
  defaults for other acts remain unchanged. Exported hero source SHA and placement
  now govern the bound hall renderer; no separate hard-coded pose in that path.
- Trial `/tmp/act3-bound-hall-recipe.json` binds the actual hall 16 m beyond the
  boss. Diagnostic master passes all hard checks; native render exits 0 and court
  capture inspected (`/tmp/act3-bound-hall-court.png`). Geometry aggregation test
  passes; altered-source-hash negative control correctly exits 1 before capture.
  Logs `/tmp/act3-hero-binding-test.log`, `/tmp/act3-bound-hall-native.log`,
  `/tmp/act3-bound-hall-negative.log`. Appearance still needs substantial art work.
- Normal bound-hall master export started to `/tmp/act3-bound-hall717-full.json`,
  log `/tmp/act3-bound-hall717-full.log`. Resume its live handle/process. Once
  selected, promote this recipe and qualify other seeds with its actual hero
  reserve; do not treat earlier layout identities as equivalent. Review page
  remains unchanged and final candidate/gates are not complete.

- Selected stepped regional recipe is now in `act3/spatial-recipe.json`; native
  study defaults to `/tmp/act3-stepped-separated717-full.json`. Normal master
  compiler exits 0, layout `572d0c64172d317e22444b59efb1d6ee579157694b67031bfabc7f1379f29565`.
  It differs from diagnostic anchors/routes, so native geometry was rerun:
  `/tmp/act3-stepped717-full-native.log` exits 0, zero architecture conflicts,
  204 threshold probes pass (min 4.4201 m), 63 passage probes pass (min 2.45 m).
  Full and threshold captures saved as `/tmp/act3-stepped717-full-{whole,threshold}.png`.
- Restored pointed cloister silhouettes by lowering arch spring heights within
  unchanged module envelopes. Blender export exits 0; triangle counts unchanged.
  Native master and seed-4 threshold views inspected. This improves the arch
  character but does not resolve the whole composition or material/lighting gap.
- Seed 4 and 2026 diagnostic exports both pass all hard checks. Seed-4 native
  `/tmp/act3-stepped4-pointed.log` exits 0: 604 threshold probes and two passage
  checks pass. Normal exports now running for both to
  `/tmp/act3-stepped-separated{4,2026}-full.json` with corresponding `-full.log`.
  Resume these live jobs, then inspect their actual selected geometry. No owner
  review page updated; earlier flat-layout focus/performance receipts are not
  evidence for this newly selected layout.

- Stepped-court trial normal export terminated with exit 1: crossing row 8→9
  coincided with the descent; the shared passage requires level approaches.
  Failure certificate `/tmp/act3-stepped-courts717.json.failure.json` records
  exhausted bounded search, not a viable result. Moved the court boundary to
  row 9→10 in `/tmp/act3-stepped-courts-separated-recipe.json`; the study now
  derives its three regional divisions from the profile's region labels.
- This exposed a real camera defect: safe-frame focus ignored anchor elevation.
  `test_map_elevated_focus.gd` failed two actual projection assertions at Y=3 m
  before the fix. Shared `MapCameraRig.resolve_leading` now compensates elevation
  in its camera-Z bounds and preferred pose. New projection test and existing
  quality evaluator both pass (`/tmp/act3-elevated-focus-green.log`); zero-height
  behaviour remains covered by the original evaluator suite.
- Separated-transition diagnostic export passes all compiler hard checks:
  65 nodes / 76 edges, input `77193ba68d0969a25413978391615747ab54114ac32fe8e06cd86dee76997817`.
  Native render exits 0; sampled threshold 199 probes pass (min 4.6878 m), central
  passage 63 probes pass (min 2.45 m). Logs `/tmp/act3-stepped-native.log` and
  `/tmp/act3-stepped-separated-camera.log`; whole and threshold captures saved as
  `/tmp/act3-stepped-separated-{whole,threshold}.png`. Steps now visibly connect
  courts, but overall composition remains unapproved. These are diagnostic results.
- Started normal master export to `/tmp/act3-stepped-separated717-full.json`,
  log `/tmp/act3-stepped-separated-full.log`; inspect its live process/handle before
  continuing. No profile promotion or review page update yet. Other seeds, all
  affected views, final gates and whole-chapter art remain required.

- Built bounded court-opening selection and matched foundation subtraction.
  Master generated three openings; native render and two focused tests passed.
  Visual inspection shows plain rectangular recesses rather than a convincing
  landscape, so this experiment is now opt-in (`--landscape-openings`), not the
  default composition. It must not distract from the owner's stepped-court request.
- Trial generator recipe `/tmp/act3-stepped-courts-recipe.json` sets regional
  heights to 0 / 1.8 / 0.6 / 3.0 metres (up, down, then sovereign ascent).
  Normal compiler launched for seed 717, input digest
  `88e2af4ef55fd166170667b674de59c09d617df3f0706edf19dc24404ba29986`.
  Do not substitute prior flat-court receipts for this candidate. Inspect its
  generated routes and native stairs before promoting the recipe.

- Shoulder-relative relief now resolves landforms against generated rectangular
  reserves through the shared module, leaving the source profile immutable.
  Fixed world-space centres were removed from the Act III terrain profile.
  Narrow parsing (three scripts) and the focused terrain test pass; master native
  capture exits 0. Evidence: `/tmp/act3-relief-shoulders-test.log`,
  `/tmp/act3-relief-shoulders.log`, and matching `-whole.png` / `-journey.png`.
- Visual inspection: exterior slopes now read in the whole view, but the close
  journey remains a large flat court. Do not increase peripheral hill height as
  a substitute for resolving this. Next introduce bounded landscape openings in
  oversized court spaces, subtracting both paving and underlying foundation
  consistently while preserving route widths, building support and level courts.
  The whole chapter remains below acceptance; no owner review page changed.

- Natural-relief first experiment: added shared `landscape_relief.gd`, an Act III
  terrain profile and reserve-contact test. The native master capture exited 0;
  narrow parsing and the focused test passed. The height field keeps court
  reserves level and supplies broad rises/depressions outside them.
- Visual rejection: `/tmp/act3-precinct-whole.png` still reads as a flat rectangular
  slab. Fixed world-space landforms are poorly located against the generated wide
  court reserves, suppressing the useful relief. This does not satisfy the owner's
  landscape requirement. Next anchor landforms to generated precinct shoulders
  and reduce the uninterrupted court footprint where routes and architecture allow;
  inspect silhouette before treating this as an improvement. No review page updated.

- Diagnosed the remaining two triangular patches in the master current view.
  They persist with sun shadows disabled (`/tmp/act3-stair-no-shadows.log`).
  Actual triangle rays (`/tmp/act3-stair-screen-probe.log`) identify front-facing
  vertical CourtSurface retaining faces at y=0.437/0.392 between road y=0 and
  court y=0.9; the next surface is about 0.6 m behind. At these sampled pixels,
  this is neither a hole nor coplanar z-fighting. Do not keep adding geometry to
  hide them. Their angular appearance remains an art judgement, not proof of a
  missing mesh. Other unexamined pixels are not covered by this diagnosis.
- Added a shared diagnostic screen-to-triangle probe, active only through the
  study's diagnostic flag. Included the court mesh in the inspector's sightline
  cache so the new retaining walls participate in visibility checks.
- Three normal seeds at 1180x820 passed all-node focus/click tests after including
  the court: 65+66+54 = 185 nodes, no failures. Logs
  `/tmp/act3-cut-wall-sightlines{717,4,2026}.log`; all exited 0. This is the one
  reference size, not a new nine-case claim. Script checks pass.
- No live processes remain. Next complete continuous movement/visibility and
  actual asset-profile binding, while retaining the outstanding whole-chapter
  art judgement and final performance/core/independent-review requirements.

- Court cut-outs lacked retaining faces along their interior edges: only the
  outer patch boundary had walls. Added shared cut-boundary generation where
  the court is higher than the route. Outward probes remove internal tread seams;
  earlier masks own coincident boundaries, preventing duplicate faces.
- Focused regression now checks full retaining-side area, unobstructed passage
  ends, adjacent tread boundaries and duplicate masks. It passes in
  `/tmp/act3-cut-wall-test.log`. Corrected an initial test area calculation that
  included outer boundary fragments, and a typed-fixture parse error; terminated
  that malformed test process before the corrected run.
- Native master `/tmp/act3-cut-walls-native.log` exited 0 with basic input/overview
  gates passing. Inspected matching current view, saved as
  `/tmp/act3-cut-walls-current-view.png`. Earlier normal diagnostic:
  `/tmp/act3-stair-contact-normals.log`. The missing cut-side contract is fixed,
  but residual dark triangular stair/landing details remain visible and are not
  claimed resolved by this change. Other seeds and continuous-view inspection
  of these new walls remain due; final chapter acceptance remains incomplete.
- No intentional live process remains. Do not substitute this structural test
  pass for the unresolved close-view judgement or complete chapter composition.

- Shared inspector now exposes marker/control extents, with existing 44/48 px
  defaults preserved. Act III chooses max(44,60*viewport_height/820) and at least
  that control height. Marker offsets, radii, clipping margins and overview
  spacing follow the selected extent. No approved chapter opts into new sizes.
- Added actual target-size checks for markers, header controls and overview
  clusters. Updated all-node focus/click checks to the selected minimum. Native
  1180x820 master close and overview captures inspected: 60 px node targets,
  clear controls, all IDs represented, no overview overlaps.
- Full nine-case fixed-seed/reference-shape matrix completed with exit 0:
  `/tmp/act3-target-matrix-SEED-WxH.log`. 555 node focus/click cases pass, all
  basic drag/selection/zoom and overview gates pass. Measured targets 44 px at
  844x390, 60 px at both 1180x820 and 1458x820. Not physical device qualification.
- Visual inspection still exposes stair/landing contact artefacts in the current
  journey view. Passing target tests does not clear them. Before final visual
  acceptance, resolve those visible geometry contacts and complete continuous
  camera movement, hero-profile binding, performance/core/independent review.
  No processes live; remote review page unchanged.

- Fixed the outstanding seed-4 phone drag failure in the shared inspector.
  Diagnosis `/tmp/act3-drag-target.log` proved background down arrived, but the
  motion crossed marker `1,3` and never reached `_unhandled_input` (zero motion
  events, zero displacement). This was UI interception, not a bad origin.
- Background-started drags now capture motion/release in `_input`; control-started
  presses still follow normal GUI selection. Matched failing case now moves
  2.658 m with one received motion event. Added exercise evidence for preserved
  selection and released drag state; this is part of the Act III exit gate.
- Nine normal-seed/reference-size input runs completed and exited 0:
  `/tmp/act3-drag-matrix-SEED-WxH.log`, 717/4/2026 x
  844x390/1180x820/1458x820. All pass drag, preserved selection, existing basic
  input and overview clustering gates. These are desktop input exercises, not
  physical-touch tests; all-node focus matrix was not rerun for this pan-only fix.
- Act II shared-inspector phone regression also exited 0 with all basic input
  booleans true (`/tmp/act2-drag-regression.log`); screenshot inspected. It predates
  adding the extra selection-preservation reporting field, not the drag fix.
- No live processes remain. Next address the documented 60 px design-resolution
  target requirement through configurable shared sizing, then continuous camera
  and final chapter art/profile/performance/core/independent-review acceptance.
  No claim of completed Step 3; remote page remains unchanged.

- Retained stronger recessed glass emission (0.22 -> 1.1) and adjusted stone/roof
  roughness in the chapter's Blender asset source. Tested the existing combat
  sky-radiance lighting approach, but its benefit in the map view was insufficient;
  removed that extra environment configuration. Existing lighting stack retained.
- Replaced the hall's simple triangular roof profile with a complete concave,
  faceted vault rising to one ridge. Gable and roof seams follow the same profile;
  reduced seam courses from five to three. This is chapter-owned architecture,
  not a new renderer or shared behaviour change. Hall now 20,424 triangles;
  other kit counts unchanged (488/3,449/720).
- Blender build `/tmp/act3-vault-kit.log` exited 0; native seed-2026 run
  `/tmp/act3-faceted-vault.log` exited 0. Court capture inspected and saved as
  `/tmp/act3-faceted-vault-court.png`. Previous material view saved at
  `/tmp/act3-material-before-court.png`. Window emphasis and roof silhouette
  improved, but these do not establish whole-place composition acceptance.
- No live processes remain. Actual hero-profile binding still needs the rebuilt
  asset identity; gallery/interior composition, final camera/interaction,
  performance, full core, independent review and owner page remain outstanding.

- Added shared `foundation_audit.gd`, reusing actual-triangle route-width probes
  and conservative per-solid-piece/model bounds. Unlike the paired ceiling gate,
  no overhead hits is valid for this obstruction-only check; failures still
  reject. The paired ceiling gate remains separate and unchanged.
- `--audit-foundations` passes all normal samples with no road failures and no
  model-bounds overlaps: seed 717 has 76 routes/4 solid pieces, seed 4 has
  74 routes/8 pieces, seed 2026 has 74 routes/12 pieces. All exited 0; logs
  `/tmp/act3-all-foundations{717,4,2026}.log`. These are sampled route probes and
  conservative building bounds, not a general continuous collision certificate.
- Negative control `--audit-obstruct-foundation` inserts a low plate above the
  current route. It correctly exits 1 with 226 failures, first clearance 0.5 m
  (`/tmp/act3-foundation-negative.log`). No injected object exists in normal runs.
- Focused foundation geometry test passes after returning individual solid bounds
  (`/tmp/act3-foundation-bounds-test.log`). Changed scripts parse. No live process
  remains. The foundation's non-paired route/building check is now covered for
  the three fixed samples; final art, camera, profile, performance, full core and
  independent review remain unfinished. Next return to complete chapter visual
  composition instead of expanding this local audit beyond its named risk.

- Shared passage masonry has opt-in continuous foundations with configurable
  deck thickness; default callers retain the former abutments. Act III enables
  the foundation. It supports every elevated horizontal upper segment, clipping
  the paired lower route corridor out of the footprint.
- First candidate only filled the segment intersecting the lower route, leaving
  neighbouring level segments hollow. Unlit normal-colour inspection exposed
  those voids (`/tmp/act3-foundation-normals4.log`). Corrected the segment coverage.
  A second close view exposed coplanar overlap where foundation tops intruded
  into deck walls. Foundation now stops exactly at deck underside (0.65 m depth).
- Added `test_map_passage_foundation.gd`: adjacent spans supported, lower passage
  clear, no foundation vertex above the deck underside. Focused test passes
  (`/tmp/act3-foundation-test.log`). Shared/study scripts parse.
- Three normal-seed native runs exited 0 with masonry-inclusive paired-passage
  audits: `/tmp/act3-foundation-contact{4,717,2026}.log`; 130/63/221 overhead hits,
  minima approximately 2.45 m. Saved matching passage captures; seed-4 close view
  inspected. Side voids and the observed overlap striping are removed.
- Still required: check the enlarged foundations against non-paired routes and
  other scene structures, not only the paired lower passages; camera visibility;
  full chapter art/profile/performance/core/independent review. Do not infer that
  paired headroom results prove all architecture contacts or visual completion.
  No live processes remain. Remote review page unchanged.

- Resolved oversized threshold arches at their source: merged route envelopes
  produced spans up to 24.58 m, and the builder scaled an ordinary arch to that
  width. Shared threshold builder now accepts `maximum_arch_span` (default INF
  preserves callers); Act III chooses 8.5 m. Wider approaches retain capped side
  piers and open sky. Narrow passages retain arches. No graph geometry changed.
- Native captures and threshold audits pass on all three normal samples:
  `/tmp/act3-open-approaches717.log` (291 overhead hits, min 4.317 m),
  `/tmp/act3-open-approaches4.log` (240, min 4.415 m),
  `/tmp/act3-open-approaches2026.log` (90, min 6.353 m). These are sampled ceiling
  hits, not a count of every point in the open approaches. All runs exited 0.
- Inspected seed-2026 and seed-4 court views. Removing the oversized arch reveals
  the hall and improves scale; retain this candidate. The complete chapter is
  still below the art bar, notably bridge-like interior crossings and plain
  forecourt composition. Final camera visibility/input, profile, performance,
  regression and independent review are still incomplete.
- Narrow parse passes shared builder and study. No live processes remain. The
  review page is unchanged. Next integrate grade-separated crossings into the
  architectural ground rather than leave narrow elevated decks on visible piers.

- Shared stone shader now supports a disabled-by-default planar inlay, selected
  by centre/radius/colour; it uses existing walking surfaces and masks vertical
  faces and other elevations. Act III enables two restrained rings at the boss
  forecourt. No new mesh, texture or alternate rendering stack was introduced.
- Reduced paving/ground contrast. Rejected the first `282834` paving value after
  native inspection because branches became too faint; selected intermediate
  `2c2c38`, still requiring final marked-view readability qualification.
- Native master inlay capture succeeded (`/tmp/act3-court-inlay.log`), inspected
  court and journey. Subsequent seed-4 placement failed at threshold x=133.02:
  existing returns could not avoid both the outer gallery and roads with x-only
  search. Added bounded inward offsets of 0/1.5/3 m while retaining all support,
  route and building predicates. No gate relaxed.
- Final seed-4 and seed-2026 native runs exited 0, with five views each:
  `/tmp/act3-inlay-smoke4-inset.log`, `/tmp/act3-inlay-smoke2026.log`.
  Seed-4 journey and seed-2026 court inspected. Final master needs recapture after
  the inset search/contrast change; older master geometry evidence is not a full
  final-candidate receipt. No runtime remains live.
- The new floor hierarchy is only a local improvement. Seed-4 journey still
  exposes a bridge-like grade separation and insufficient architectural interior
  composition; the sovereign platform remains too plain. These remain blockers,
  together with full profile/camera/performance/core/independent-review acceptance.

- Added opposing inward-facing gallery groups to the first three court regions,
  retaining foreground gaps and the same generated sample. This is a private
  composition candidate, not an accepted whole-place composition: native whole
  view still has repetitive boundary masses and a diagram-dominated interior.
- Initial placement exposed a 15 cm building overlap. Added shared conservative
  building-bounds overlap checks (touching allowed) and a focused regression for
  contact versus 15 cm penetration. The first test attempt used scene nodes before
  the tree was ready; replaced it with a pure AABB test of the placement predicate.
  Final focused test passes (`/tmp/act3-building-contact-test.log`).
- Place threshold returns first, then fit optional opposing gallery bays around
  existing architecture. Omit an optional scenery bay if bounded fitting cannot
  avoid buildings/routes; game nodes and edges are never omitted. Initial all-
  required placement failed at x=37.68; preserve
  `/tmp/act3-opposing-galleries-contact.log` as rejected placement evidence.
- Final master run `/tmp/act3-opposing-galleries-fit.log` exited 0. Actual model
  bounds receipt has 36 buildings, zero pairwise AABB overlaps above 1 mm and zero
  route conflicts. Whole and journey captures inspected. Script checks pass.
  Smoke seeds, camera visibility and final art acceptance remain outstanding.
- Next resolve the interior composition and sovereign audience court, rather
  than adding more perimeter modules. Current gallery backs also need deliberate
  exterior treatment if this candidate is retained. All cross-act constraints
  and the full final acceptance remain active; remote page remains roads v7.

- Rejected the continuous high-wall threshold experiment after native visual
  inspection. Although 1,343 actual-mesh clearance probes passed (minimum 4.318 m)
  and the focused threshold regression passed, the whole view became three
  oversized partitions. Saved `/tmp/act3-rejected-enclosed-{whole,threshold}.png`,
  `/tmp/act3-rejected-enclosed-threshold.gd` and
  `/tmp/act3-enclosed-threshold.log`; removed the candidate implementation and
  restored the prior open-threshold construction. Do not cite rejected geometry
  results as evidence for the restored current candidate.
- This disproves increasing transverse wall mass as a sufficient composition
  fix. Next resolve courtyard/gallery placement and spatial proportions in the
  generated layout; do not iterate decorative additions to the same strip.

- Cross-act boundary audit completed for current builders and inspector. Spatial
  ordering/spacing, resolved flights, surface union and occupancy are parameterised
  capabilities; keep them shared. The precinct scene, Blender kit and sovereign
  halo are chapter content. Moved the halo from `common/` to `act3/`.
- Removed Act III stone-material construction from shared threshold/plinth
  builders. Their caller now supplies materials; the Act III caller retains the
  existing palette. Threshold trim defaults to the supplied body material for
  other callers. Existing approved acts have no callers of these new builders.
- Narrow parse passed four changed scripts. Native seed-717 study exited 0,
  occupancy reports zero route conflicts and all five views captured in
  `/tmp/act3-shared-boundary.log`. Threshold capture inspected: materials render,
  but repeated thin arches and exposed diagram-like routes remain art blockers.
  This refactor is not claimed as a composition improvement.
- Inspector clustering and sightline focus remain private Act III adaptations
  with reusable helpers. Before final adoption, either expose opt-in shared
  inspector configuration or remove unnecessary differences; do not create a
  second production interaction stack. The seed-4 drag failure remains open.
- Immediate next creative work: rebuild the threshold/outer-gallery relationship
  as substantial enclosing architecture within the generated envelopes, then
  judge the complete four-region silhouette. Keep the existing route graph and
  geometry probes; do not spend the next turn expanding the UI test matrix.


- Added cached real-triangle sightline queries in `common/precinct_sightlines.gd`.
  Orthographic rays originate at each projected point, not the camera centre.
  Tests prove an open doorway remains clear, a jamb blocks and a wall behind
  the target does not block (`/tmp/act3-sight-tests.log`, 1 test).
- Journey focus now chooses the first clear / least blocked of seven bounded
  headings using imported buildings, thresholds and passage masonry triangles.
  Master chooses +25 rather than -25 degrees, clearing the previously occluded
  current-node floor. Phone screenshot inspected. Queries currently cover node
  centres only, not whole route corridors or arbitrary pan positions.
- Added all-node focus/click exercise with selection/detail restoration. Nine
  normal-seed/reference-shape runs completed: 65+66+54 nodes times three sizes =
  555 cases, zero reported failures. Logs/screenshots:
  `/tmp/act3-input-matrix-SEED-WxH.{log,png}` for seeds 717/4/2026 and dimensions
  844x390/1180x820/1458x820. Basic input, 44 px focused targets and clear focused
  node-centre sightlines pass; representative phone/tablet captures inspected.
- Then made input-exercise process exit non-zero on false basic/all-node results
  or screenshot failure; parse check passes. This gate-hardening does not change
  the rendering/input behaviour exercised above. No live runs remain.
- Next: overview marker overlaps, continuous journey camera heading stability,
  route visibility between nodes, and remaining art/performance/profile/core/
  independent-review requirements. Remote review page still unchanged; do not
  present these component checks as completed Step 3 or polished final art.

- Smoke seeds 4/2026 passed new masonry-inclusive passage audits:
  `/tmp/act3-masonry4.log` (67+63 probes), `/tmp/act3-masonry2026.log`
  (74+75+72 probes), minima approximately 2.45 m.
- Added `act3/precinct_inspection.gd`, reusing the shared read-only inspector.
  Study supports `--interactive`, `--exercise-input`, `--viewport=WxH`.
  Precinct inspector extends far plane/zoom range for the generated domain and
  retains all node markers in whole view. Default journey uses -25 degree heading
  and minimum size 32 after the first phone capture exposed excessive closeness.
- Final basic desktop input exercise passes at 844x390, 1180x820, 1458x820:
  `/tmp/act3-input-final-WxH.log` and `.png`. Real input events exercise overview,
  journey, current-node selection, drag and wheel; 44 px current marker, matching
  viewport pixels and unchanged source current-node state verified. All three
  captures inspected. This does not prove all marker targets or physical touch.
- Visual finding from interactive captures: the current marker can project over
  a foreground glazed return even though its world footprint avoids the route.
  Next resolve camera/foreground occlusion for current and reachable nodes, then
  continuous travel/zoom and all-node hit targets. Do not call the basic input
  pass complete camera or chapter acceptance. Existing remote page is unchanged.
  Art completeness, asset-profile binding, full performance/core/review remain due.

- Added `common/precinct_plinth.gd`: one batched, closed dressed foundation mesh
  follows exposed court boundaries, omitting shared internal seams. Its stepped
  coping/base profile stays below walking level. Corrected exterior winding for
  Godot clockwise fronts; native final-flat capture inspected.
- Added `common/passage_masonry.gd`: stone side supports are intersected with the
  actual level upper-deck footprint and remain outside the lower route plus .35 m
  clearance. Study includes those meshes in the passage headroom audit. Master
  audit passes 63 probes, minimum 2.45 m (`/tmp/act3-masonry-native.log`). Other
  smoke seeds still need the new masonry audit; do not inherit older results.
- Added an actual-crossing close camera (`act3-precinct-passage.png`). Inspection
  exposed smooth normals making procedural stone piers look rounded. Threshold,
  passage and plinth builders now use flat face normals; final close rendering
  inspected (`/tmp/act3-dressed-flat-native.log`). Script checks pass. Stonework
  reads more clearly, but complete passage architecture and finished chapter art
  remain unapproved. Profile supports need broader route-interaction inspection,
  not just the selected lower passage's sampled ceiling.
- Native counters on master with these additions: whole 279 draws, passage close
  38 draws; these are capture counters only, not CPU/GPU frame-time qualification.
  No processes intentionally left running from this turn. Next inspect the two
  smoke seeds with masonry, then continue architectural composition and connect
  the normal generated sample to an interactive Step 3 review surface. Final
  reference-shape input/motion/performance/core/review gates remain outstanding.

- All normal compiler runs completed successfully: `/tmp/act3-full-pair{717,4,2026}.json`.
  IMPORTANT: their anchors/edges differ from diagnostic candidates; the native
  study now defaults to the normal 717 output. Normal layout digests:
  717 `bc136592c87d1d107085cb738446d9601741e42b6337e9fbfecd72c333dc7270`;
  4 `8b252b542b0b0f98d83ff87f56d4503aaae33ccca9b09f89d4975aee471d7939`;
  2026 `2cd40abe544bf29ff2628acc2a9308f7798499c9bb7af1e7b578576a28b5d6b5`.
- Dressed threshold candidate now uses .7-width pointed arch rise, explicit
  footings, spring capitals and crown stones. Native threshold inspected; wider
  spans are imposing but still need architectural integration rather than hoops.
  All NORMAL seeds were rebuilt and audited with this geometry:
  `/tmp/act3-normal717-native.log`: 703 threshold / 63 passage probes;
  `/tmp/act3-normal4-native.log`: 617 threshold / 67+63 passage probes;
  `/tmp/act3-normal2026-native.log`: 685 threshold / 74+75+72 passage probes.
  All pass, minimum passages approximately 2.45 m, imported building/route
  occupancy zero. Screenshots retained under `/tmp/act3-normal{717,4,2026}/`.
  Master court and both smoke whole views inspected; none is final art approval.
- Capture counters added (not performance qualification). Normal 2026 whole:
  203 draw calls, 261209 primitives, 136.73 MiB renderer memory; journey 50 calls.
  No live compiler/native handles remain from these completed runs.
- Next focus: make elevated passages part of architecture rather than naked
  bridge-like road decks; give perimeter terraces dressed depth and connect
  buildings into meaningful spaces. Preserve the now-proven normal generator
  outputs while completing art. Then actual reference-shape input/motion,
  performance, asset-profile binding, full core and final independent review.

- Normal compiler master 717 completed successfully (exit 0), not merely a
  diagnostic build: `/tmp/act3-full-pair717.json`, log of same stem, input digest
  `4b46e49f420f5d616bf65729a88d90e89674b80aef16d720ab620f1c51012e5c`.
  Normal exports for seed 4 and 2026 remain running: exec handles 49862 / 54708,
  outputs `/tmp/act3-full-pair4.json` / `/tmp/act3-full-pair2026.json`; resume
  those exact handles or inspect processes rather than restart on timeout.
- Building placement now checks complete footprint support across stepped court
  envelopes and avoids straddling terrace levels. Existing bounded placement
  search handles returns. `test_map_precinct_support.gd` proves a narrowing-edge
  overhang rejects and a supported seam passes; native master completes with
  zero route conflicts (`/tmp/act3-support-native.log`). Hall retains its own
  foundation; building-to-building joins still need visual completion.
- Added texture-free `common/precinct_stone.gdshader`: world-sized staggered slabs,
  restrained face/roughness variation, derivative-filtered sparse joints. Ground
  joint coverage .25; route .65. Native journey inspected, remains visually quiet
  (`/tmp/act3-stone-native.log`). Added modest magenta glazing spill with bounded
  local lights; explicit asset metadata selects gallery windows. Court inspected
  (`/tmp/act3-glazing-native.log`); no shader/runtime errors observed. Performance
  and light-leak review remain outstanding; this is an art candidate, not approval.
- Court diagnostic camera was then widened to size 52 and aimed at y=9 to stop
  clipping the hall roof; recapture that final camera change next. Continue the
  representative finished architectural section: dressed threshold surfaces,
  continuous foundations, passage integration, lighting and close motion. Full
  chapter, all reference shapes/input/performance and final gates remain open.

- Pair-local lateral reservations now replace uniform expanded row pitch.
  `lane_positions_m` records seven generated offsets; only gaps separating an
  inverted pair expand to its required distance, slot 3 remains centred, and
  unrelated gaps retain their authored spacing. Profile anchor/validation consume
  the same offsets, rejecting non-finite, unordered or out-of-bounds arrays.
  Focused schema/spacing suites pass (`/tmp/act3-pair-schema-tests.log`, 2 tests).
- All three actual-flight diagnostic builds pass on these tighter reservations:
  `/tmp/act3-pair-{717,4,2026}.json`. Master input digest is
  `4b46e49f420f5d616bf65729a88d90e89674b80aef16d720ab620f1c51012e5c`.
  Study default switched to this master. Actual master native meshes build and
  occupancy is zero; 705 threshold probes pass at minimum 4.09956 m, 63 passage
  probes at minimum 2.45 m (`/tmp/act3-pair717-native.log`). Whole inspected:
  oversized central wings have gone; still greybox, not finished chapter art.
- Normal compiler export, without first-attempt/diagnostic flags, is running for
  master 717: exec session 54623, output `/tmp/act3-full-pair717.json`, log
  `/tmp/act3-full-pair717.log`. Last poll confirmed live. Resume this exact handle
  or inspect its process; do not duplicate it on an observation timeout.
  Continue architecture/foundation continuity and representative finished section
  while this bounded compiler run executes. No full-compiler success yet claimed.

- Current selected recipe has optional passage crossing reservations: 20 m
  lateral and 45 m longitudinal. Spacing applies lateral expansion only to the
  two rows of each detected inversion, preserving other rows. Profile validation
  covers these parameters; focused spacing/profile tests pass (2 tests,
  `/tmp/act3-local-spacing-tests.log`). All three fresh diagnostic actual-flight
  builds now pass: `/tmp/act3-local-final-{717,4,2026}.json` and corresponding logs.
  This is still first-attempt diagnostic evidence, not full compiler search.
- Native study default now uses `/tmp/act3-local-final-717.json`. New
  `common/precinct_envelope.gd` computes each court region from continuous route
  segment extents plus architectural margin; floor patches and gallery positions
  follow those bounds. Master all route meshes build, imported architecture has
  zero route conflicts, and whole/journey were inspected
  (`/tmp/act3-enclosed717-native.log`). This is an unapproved composition study.
- Visual finding: trimming the global rectangular floor helps its silhouette,
  but the crossing's uniform 20 m row pitch still expands every unrelated lane
  and leaves the middle courts too broad. Next derive per-slot positions from
  only the inverted pair's required separation, retaining 8 m gaps elsewhere;
  bind them in the spatial profile and recheck the three seeds. Also check
  building/floor support at envelope steps and all affected mesh headroom.
  Do not treat route-clear occupancy as building/foundation-contact proof.

- Roomy 2026 native follow-up completed: all three actual passage meshes pass
  73/64/68 probes respectively, minimum headroom approximately 2.45 m; all route
  surfaces construct successfully (`/tmp/act3-roomy-passages-native.log`). Whole
  and journey captures were inspected. **Reject this as the final composition**:
  uniform global expansion leaves a vast empty foreground, distant hall and
  thin perimeter architecture; route diagram still dominates. Keep its physical
  construction evidence, not its global scale as an accepted art decision.
  Next use local crossing reservations / occupied lane envelopes rather than
  uniform expansion, and build architectural enclosure around those spaces.
  The current source recipe remains unchanged; master 717 must be rechecked
  under the new actual-flight grade resolver before any fresh acceptance claim.

- Latest smoke diagnosis: bounded ordinary/guided/bypass channels preserve 717
  (`/tmp/act3-bounds-717.log`); seed 4 retains the 31.49 px fork failure, and
  2026 now has only its three unavoidable crossings, without backward detours.
- A 14 m lateral-spacing experiment passed all three diagnostic layout builds
  (`/tmp/act3-wide-{717,4,2026}.log`), but actual 2026 mesh construction rejected
  an incline turning without a level landing. The evaluator previously accepted
  this; do not promote the wide recipe on that evidence alone.
- Added `map_passage_route.gd`: spatial grade approaches now reuse terrace flight
  construction, preserving level corners and discrete stair capacity; legacy
  grade interpolation remains unchanged. Failed approaches are retained in grade
  diagnostics. Narrow mesh-producing corner and spatial-grade suites pass
  (`/tmp/act3-passage-integrated-tests.log`, 2 tests). Parse checks pass.
- Bounded spatial experiments demonstrate that lateral-only 20 m and crossing-
  interval-only 45 m each still lack approach capacity. Combined 20 m lanes /
  45 m crossing intervals passes actual-flight layout generation for seed 2026
  (`/tmp/act3-roomy-physical.json`, digest
  `7a8c1d9a2b180b476915d69af3b5d08156d4adf40b667b47c4dbe39dc9b840d6`).
  This remains a temporary recipe `/tmp/act3-roomy.json`, not production spatial
  authority. Next derive reservations from physical geometry and judge composition.
- Native roomy 2026 builds all route meshes, has zero building/route conflicts,
  and passes 957 threshold probes with minimum 4.3125 m headroom
  (`/tmp/act3-roomy-native.log`). Its old master-only passage assertion was exposed
  and fixed: study now accepts `--sample=` and audits every crossing, saving
  `/tmp/act3-passage-audit-N.json`. Follow-up native process log is
  `/tmp/act3-roomy-passages-native.log`; inspect its completion and captures before
  making any further visual or passage claims.

- Forward-routing correction in progress: seed 4's extra crossings were caused
  by a bypass retreating into the preceding row. Spatial bypass stations and
  channels now stay within source/target X; impossible turning reservations
  reject explicitly. Guided and ordinary spatial channels now share those row
  bounds; legacy routing remains unchanged. Focused forward/egress suites pass
  (`/tmp/act3-forward-complete-tests.log`, 2 tests), explicit script check passes.
- Rejected global two-way fork spread 60 degrees: seed 4 passed diagnostic build
  (`/tmp/act3-openfork4.log`) but master 717 regressed. Restored 45 degrees.
  Before the final ordinary-channel clip, master 717 passed again
  (`/tmp/act3-forward-all717.log`), while 2026 still failed grade clearance
  (`/tmp/act3-forward-all2026.json.failure.json`). These are first-attempt
  diagnostic builds, not full compiler or final visual acceptance.
- Next: rerun smoke builds on the final ordinary-channel clip; inspect 2026's
  remaining early crossings and seed 4's 31.49 px fork separation without
  lowering governed thresholds. Native scene still consumes the earlier passing
  master sample; no new review page or chapter-completion claim is warranted.

- Added a covered cloister module with rear wall, closed pitched roof, continuous
  floor, half-pier interfaces and empty stone seats. Rebuilt original Blender kit;
  new module is 720 triangles (`/tmp/act3-covered-gallery.log`). Study replaces
  perimeter thin arcades with the covered version; native journey inspected and
  conservative building/route conflicts remain zero
  (`/tmp/act3-covered-gallery-native.log`). Model contacts and final asset-profile
  binding are still outstanding.
- Added the sovereign halo at the generated terminal anchor as the only broken
  architectural motif (`common/sovereign_halo.gd`). Six closed arc fragments have
  restrained emission and slow rotation; apparition casts no solid shadow.
  Native court inspected (`/tmp/act3-halo-native.log`). Court-only diagnostic
  camera now looks more towards the facade; this is not a change to certified
  runtime camera profiles. Continuous motion/reference-shape evidence still due.

- Adopted optional physical spacing into the active recipe and switched native
  assembly to `/tmp/act3-egress-reserved717.json`. Court bounds, gallery intervals,
  region thresholds and whole-view extent now derive from the generated profile;
  terminal architecture follows the terminal anchor. Passage audit selects the
  actual crossing pair instead of the old detour edge IDs. A runtime typed-array
  return failure in that selector was corrected before the successful capture.
  Fresh assembly/audits complete (`/tmp/act3-reserved-assembly.log`): 691 threshold
  probes, minimum 4.1172 m; 93 central passage probes, minimum 2.45 m; imported
  building/route occupancy zero. Joined route overlap removed 164.5584 m2 and
  court paving has 4496 triangles. Whole/journey inspected on this candidate:
  crossing is more direct, but elongated empty regions and weak architectural
  continuity remain below art acceptance. Do not publish this as an approved page.

- Root cause for seed2026's fan-out: blocked branch guide silently fell back to
  an ordinary route, losing the designed departure. Spatial-profile routing now
  returns the blocked guide to the compiler's retry/candidate mechanism; legacy
  fallback is unchanged. Focused regression proves both behaviours. Three
  egress/spacing/terrace suites pass (`/tmp/act3-egress-reservations-tests.log`).
- This exposed the short direct crossing on seed717: its old successful detour
  is no longer representative of current routing. The reservation experiment now
  includes both 4 m departure guides, corridor widths and margins in addition to
  the physical ramps. Fresh seed717 passes with 65 nodes/76 edges:
  `/tmp/act3-egress-reserved717.json`, matching log, input digest
  `01ed5e204c0777d758717672aa583de0d7947eea0507650ca0067ea223f162b7`.
  Added longitudinal space is 24.9327 m. The old active recipe without optional
  spacing no longer passes this first-attempt route policy. Do not present the
  older assembled mesh audits as evidence for this new generated candidate.
  Next: adopt the passing spacing recipe into current assembly, derive its bounds
  and thresholds from profile stations, and recheck actual geometry. Seed4/2026
  remain rejected under strict egress with earlier spacing; their cross-row
  detours still need candidate/routing work. Failure reports remain
  `/tmp/act3-egress{4,2026}.json.failure.json`. No smoke acceptance is claimed.

- Terrace resolver can now distribute rise across multiple straight flights with
  level turns if no single run fits. Integer tread capacity constrains each run;
  actual surface regression covers two flights around a corner. Seed2026 still
  failed its original route (only 0.17 m total capacity for 0.9 m required), proving
  that spatial reservation, not another stair offset, was needed.
- Added optional `physical-reservations-v1` spacing experiment in
  `map_spatial_spacing.gd`, profile validation and the exporter. It derives extra
  row spacing from height changes and unavoidable crossing pairs, preserves lane
  assignments/game graph, expands camera bounds and shifts hero translations by
  the added length. Three focused suites pass (`/tmp/act3-spacing-tests.log`).
  Trial recipe `/tmp/act3-spacing-recipe.json` is NOT active chapter acceptance.
  Seed4 adds 35.905 m and seed2026 50.678 m. Both first-attempt runs still fail:
  seed4's first crossing now fits, but another crossing combination remains
  infeasible; seed2026 passes terrace resolution and reaches complete evaluator
  failure at branch fan-out (5,2 -> 6,1 / 6,2, 9.6327 px).
  Evidence `/tmp/act3-spaced{4,2026}.json.failure.json` and matching logs.
  Next: inspect remaining grade options / complete fan-out violations, then use
  bounded candidate routing/search; do not claim smoke acceptance or promote
  spacing merely because it removes one earlier binding. Active master recipe
  and sample remain the previously passing v2/seed717 combination.

- Central passage actual mesh audit now passes: 49 probes, minimum 2.4499999 m.
  Threshold audit expanded to the full corridor edge: 800 probes, minimum
  4.1405083 m (`/tmp/act3-full-width-mesh-audit.log`; current JSON receipts include
  input identity). Exact boundary probing initially missed 38 floor hits; measured
  nearest mesh edges were 0.0000019–0.0000459 m away. The floor query now explicitly
  resolves edges within 0.0001 m, below the governed 0.001 m physical precision.
  Regression accepts a 0.00005 m contour discrepancy and rejects a real 0.002 m
  gap (`/tmp/act3-probe-precision-tests.log`, PASS 1). Ceiling queries retain zero
  edge tolerance. These remain sampled evidence, not continuous collision proof.
- Smoke seed first-attempt diagnostic runs completed and **failed**, preserving
  `/tmp/act3-terraced4.json.failure.json` and
  `/tmp/act3-terraced2026.json.failure.json` plus logs. Seed4 has three XZ conflicts;
  first pair `3:4,2>3:5,3` / `3:4,3>3:5,2` lacks the required 7.636 m approaches
  (available roughly 3.6–4.7 m). Seed2026 cannot fit the 6.181 m straight
  flight/landing run for `3:3,1>3:4,1`. These are real spatial feasibility failures,
  not numeric probe issues. Next generator work must resolve them through bounded
  spatial/candidate choices or full search; never remove edges or reduce physical
  requirements. No ordinary full-search or smoke acceptance is claimed.

- Actual threshold mesh audit added (`common/threshold_mesh_audit.gd`): probes
  rendered walking triangles against rendered threshold triangles at 0.35 m
  longitudinal spacing and seven lateral lanes (98% corridor width). The current
  scene reports 800 overhead probes, minimum sampled clearance 4.168931 m, no
  missing walking samples (`/tmp/act3-threshold-mesh-clear.json`,
  `/tmp/act3-threshold-mesh-audit.log`). This is sampled threshold evidence, not
  continuous collision proof or the separate central passage acceptance.
  Negative control `--audit-obstruct-threshold` adds a deliberately low slab:
  same 800 probes reject with 1.200000 m minimum and process exit 1
  (`/tmp/act3-threshold-mesh-obstructed.json`, `/tmp/act3-threshold-negative.log`).
  Failed audits now terminate the study before captures. Normal runs do not add
  this obstruction. Future audit receipts also include sample input/layout IDs.
  Architecture contacts, full chapter aesthetic acceptance and remaining gates
  remain open; do not broaden this local proof into chapter approval.

- Transverse thresholds now derive openings from every route's swept intersection
  with a finite wall-depth band (`common/precinct_threshold.gd`). Angled approaches,
  raised route height and domain rejection have a focused passing regression
  (`/tmp/act3-threshold-tests.log`). The study assembles three thresholds and writes
  `/tmp/act3-thresholds.json`. First native version rejected: continuous high
  spandrels read as three heavy obstructive bars. Revised to separate pointed
  circular-arc vaults, jambs and low connecting walls. Whole/journey plus a low
  oblique diagnostic capture now available (`/tmp/act3-precinct-threshold.png`,
  `/tmp/act3-precinct-thresholds.log`). These are new geometry and must receive
  actual-mesh passage and building-contact checks; the earlier zero-conflict AABB
  report covers imported buildings only, not these pass-through structures.
  Opening feasibility is not chapter acceptance; detailed masonry and coherent
  attachment to existing gallery ends remain outstanding.

- Kit glazing revised in `build_precinct_kit.py`: broad emissive panes replaced
  by dark recessed backing with three narrow framed lancets; glazed gallery bays
  now have recessed openings rather than flat coloured infill. Emission strength
  reduced from 0.8 to 0.22. Blender rebuilt all three assets successfully
  (`/tmp/act3-kit-glazing.log`): hall 20032 triangles, cloister 488, glazed bay 3449.
  Native court/journey inspected: narrow lights and stone reveals now read as
  architecture instead of bright plastic sheets. Triangle growth must be included
  in final scene performance evidence; it is not a free material-only change.
  Study ambient reduced and road/ground values brought closer together. Whole
  capture inspected (`/tmp/act3-precinct-values.log`): route contrast is quieter,
  but overall composition STILL fails the intended precinct character. Do not
  equate these art improvements with acceptance. The next composition requirement
  is transverse architectural thresholds/usable enclosures, which need actual
  openings for routes; conservative whole-building AABBs cannot certify a route
  through an arch. The rectangular mass and detached short panels remain weak.

- Court floor assembly now exists in `common/court_surface.gd`: subtracts the
  actual route/tread footprints at every height from spatial-row terrace patches,
  so raised paving cannot cover a lower passage. Patch perimeter retaining walls
  are clipped around the same route openings. Area, lower-passage exclusion and
  retaining-wall opening regression pass alongside walking union (2 tests,
  `/tmp/act3-court-tests.log`). Native chapter assembly yields 4141 court triangles
  (`/tmp/act3-precinct-courts.log`), with zero conservative building/route conflicts.
  Journey inspected twice: first exposed missing terrace perimeter walls and
  buried gallery bases; second confirms walls and profile-following gallery Y.
  This improves continuous ground, but is not complete terrain acceptance:
  staircase-side cut-out retaining details, internal road walls, building contacts,
  material character and composition remain outstanding. Court patch X boundaries
  derive from adjacent profile row stations; outer bounds are still study values
  and must be profile-bound with the final hero/architecture footprint.

- Coplanar walking surfaces now merge through convex polygon subtraction in
  `common/walking_surface_union.gd`, preserving separate elevation levels and
  empty regions. Regression covers overlapping squares, full duplicates and
  two stacked passage levels (`/tmp/act3-union-tests.log`, PASS 1 test).
  The precinct study uses the joined result for all 76 route surfaces. Native
  assembly removed 163.363457 m2 of duplicate top coverage in 214.192 ms
  (`/tmp/act3-precinct-union.log`); journey capture inspected after assembly.
  This timing is union construction only, not a frame-time claim. Vertical
  walls/risers remain source-owned: internal wall contacts and terrain/court
  ownership still require resolution. Continuous temporal inspection is also
  outstanding; a still capture cannot certify absence of every flicker.

- Architecture occupancy experiment now measures imported mesh world AABBs,
  including child transforms, with continuous segment-versus-inflated-footprint
  clipping (`common/architectural_occupancy.gd`). Long-segment crossing and swept
  width/tangency regression passes (`/tmp/act3-occupancy-tests.log`). The hall now
  faces -X towards the terminal anchor, with a foundation under its complete
  measured footprint. Return bays use a bounded location/orientation search;
  where a transverse return cannot fit, an outer-wall alignment is tried.
  Pure lateral shifting failed because the 8.8 m return occupies the outer lane;
  changing the architectural orientation resolves that geometric constraint.
  Final study reports zero building-versus-route footprint conflicts
  (`/tmp/act3-precinct-occupancy.json`, matching log), and native journey capture
  inspected. This is conservative route clearance only: building-to-building
  contacts, profile-bound reserves and complete ground support still need work.
  It remains a composition experiment, not a certified replacement of the hero
  profile. Actual surface sharing at graph junctions also remains outstanding.

- Terrace integration is now in `_build_attempt` before grade separation for
  spatial profiles. It resolves heights from generated anchors and reports a
  named infeasible terrace binding rather than emitting flat interior points.
  Grade separation supports a shared nonzero level baseline for custom profiles;
  sloping/mismatched crossing approaches still reject explicitly. Legacy zero
  baseline policy remains unchanged. Raised-passage/evaluator/terrace suites
  pass (3 tests, `/tmp/act3-raised-grade-tests.log`); anchor-binding regression
  passes separately (`/tmp/act3-terrace-binding-tests.log`).
- Active recipe v2 now binds 0/0.9/1.8 m rows and physical passage parameters.
  Fresh diagnostic first-attempt compilation of seed717 passes all evaluator
  hard checks: 65 nodes/76 edges, `/tmp/act3-terraced717.json`, matching log.
  Input digest `2bc757e38d868a36aeb7545511116e19c29fcd3a8adac6c27dc325e2f1852a9e`;
  layout digest `dfbda88c1becb099a10b6e93ee3346e72a63b7c4cc7849f7d3ab9a4392a5b89f`.
  This supersedes the zero-height sample for current study assembly; ordinary
  complete compiler search and smoke seeds remain outstanding.
- `precinct_study.gd` now consumes that fresh sample and resolves actual route
  surfaces rather than unjoined diagnostic ribbon segments. All route surfaces
  assembled and three native captures completed (`/tmp/act3-precinct-terraced.log`).
  Journey inspected: stairs and buffered corners read more coherently, but route
  strips still sit above unfinished terrain and architecture placement is not yet
  occupancy-certified. Gallery threshold intersects a route in this provisional
  composition. Next: terrain/court floor ownership and route-aware architectural
  placement, not material polish. Do not mistake evaluator pass for art acceptance.

- Terrace walking profiles now have a bounded resolver,
  `presentation/map/map_terrace_route.gd`: retain routed XZ, select a sufficiently
  long straight segment, reserve level node/corner approaches and resolve ascent
  or descent without bending stairs. It rejects infeasible runs explicitly.
  Actual surface generation exposed a discrete-step issue: a legal average slope
  could still give short treads after rounding the riser count. Run length now
  satisfies both the grade and the integer tread count; regression includes 0.9 m
  ascent/descent. Three focused suites pass (`/tmp/act3-terrace-tests.log`).
  `terrace_probe.gd` applies experimental heights 0 / 0.9 / 1.8 m at rows
  0–3 / 4–12 / 13–14 to all 76 ordered routes: zero resolver/surface failures
  (`/tmp/act3-terrace-probe.json`, matching log). This is a feasibility experiment,
  not a newly certified sample: it flattens the old passage before terrace
  resolution, so passage clearance, terrain support and compiler integration
  are explicitly outstanding. Bind selected heights to the spatial recipe and
  integrate the compiler before using this geometry as delivered map truth.

- Whole-place composition experiment now exists in
  `tools/map_workshop/act3/precinct_study.gd`. It preserves every edge of the
  ordered seed-717 sample and positions the new hall relative to the actual
  terminal anchor, with gallery groups and threshold returns. Explicit script
  check passed; Godot 4.7.2 captured three native 1458x820 views in one assembly
  (`/tmp/act3-precinct-{whole,journey,court}.png`, log
  `/tmp/act3-precinct-study.log`). Whole and court inspected: **composition fails**.
  The terminal hall is better connected, but the rectangular slab and perimeter
  galleries do not create convincing courts; routes still dominate. Do not
  promote these placements as certified reserves or publish this as a finished
  review. Next spatial revision must resolve enclosure, terrace/threshold
  relationships and the terminal approach before material detailing.
  Its diagnostic route ribbons also have unjoined segment ends; they are not the
  resolved walking-surface implementation and must not become final geometry.
- Passage surface experiment: `resolved_route_surface.gd` buffers complete flat
  runs and joins external-landing flights; `flight_mesh.gd` supports triangular
  and quadrilateral faces. Focused route/flight suites passed (2 tests,
  `/tmp/act3-surface-rounded.log`). Latest 496-triangle native shadow-off passage
  capture inspected: the earlier miter spikes are reduced, but awkward route-end
  geometry remains. Shadow-off removed the side stipple in the diagnostic; this
  isolates a shadow contribution, not a licence to omit final shadows. Full-width
  mesh contact, actual headroom and final lighting verification remain outstanding.

- Baseline: `774cb737`; Godot 4.7.2 stable and Blender available. No chapter
  acceptance or campaign behaviour has changed. Implementation remains uncommitted.
- Spatial authority: added `map_spatial_profile.gd`; connected candidate anchors,
  evaluator domains/cameras and route-channel bounds. Default arithmetic includes
  the original Vector2 precision; a regression caught and corrected a double-
  precision substitution. Quality digest binds the profile; hero contracts retain
  their existing separate input identity. Hero-reserve design is still outstanding.
- Component checks: spatial profile, candidate generator, quality evaluator and
  resolved flight pass (4 tests), `/tmp/act3-foundation-latest.log`. JSON round-trip, invalid act/version/stations/bounds, graph identity,
  routing footprint and deterministic generation are covered. Full core gate awaits
  the coherent candidate.
- Seed 717 initial spatial experiment: full search stopped at the 10-minute
  budget. A single attempt then built all routes but failed branch fan-out
  `12,5 -> 13,4 / 13,5` at 22.521 px on phone-landscape/z3. Certificate:
  `/tmp/act3-spatial717-first.json.failure.json`. Initial input digest:
  `05e39a9317134575d76c6a318ef5065cb811755b40a3f9a4febeffc2ba9dae82`.
  Original recipe preserved at `/tmp/act3-spatial-recipe-initial.json`.
  The shorter approach did not change the measured fork, so it was reverted.
  Full rejected geometry/violations are now retained by the study-only diagnostic
  option; `/tmp/act3-spatial717-diagnostic.json.failure.json` revealed 35 distinct
  violations: legacy camera clamping, jitter-compressed node pairs, same-side
  departures and four unrelated ground crossings. No inference of overall
  feasibility may be drawn from only the first reported binding.
- Spatial master now passes a complete evaluator pass in the **diagnostic first
  graded attempt**, not yet an ordinary full compiler run. Latest ordered sample:
  `/tmp/act3-spatial717-ordered.json`; log `/tmp/act3-spatial717-ordered.log`.
  Input digest `f8415fe8c77c15facf17ef9b8e3307bd4fc61b7d39caa8caf91c41550296d8de`.
  65 nodes/76 edges; one graded span, all existing compiler hard checks pass.
  Native `/tmp/act3-ordered-greybox.png` inspected at actual 1458x820. This is a
  route diagnostic, not a finished composition or road surface.
- `map_spatial_ordering.gd` performs bounded exact dynamic programming over row
  permutations. It proved the layered minimum is one crossing for seed 717
  (121322 transitions), down from three in the original order. It preserves IDs,
  graph and game columns, emitting profile-bound presentation lane assignments.
  Exporter derives these from each fresh graph when the recipe declares
  `ordering_version=layered-order-dp-v1`; never hand-edit assignments.
  The source game jitter stays unchanged, presentation jitter scale is 0.35.
  Previous un-ordered passing sample remains `/tmp/act3-spatial717-fourth.json`.
- Camera resolver accepts explicit profile bounds, including actual runtime rig
  pan bounds; regression covers coordinates beyond the legacy lattice. Spatial-
  only fork guides depart on opposite sides before routing towards destinations.
  Six foundation suites passed in `/tmp/act3-foundation-six.log`; after adding
  landing reservations, grade/evaluator suites also pass in `/tmp/act3-grade-landings.log`.
- Actual passage height policy is now supported in MapGradeSeparation through
  optional spatial-profile `passage` settings. Legacy constants/default outputs
  remain unchanged. New tests reject legacy low crossings against the new policy.
  `/tmp/act3-landed-headroom.json` successfully regrades the ordered route sample
  to 3.1 m centreline separation: 2.45 m intended headroom + 0.65 m deck, maximum
  grade 0.55 and 1 m straight landing reservations. Physical component checks pass
  (`/tmp/act3-grade-landings.log`). This is NOT actual-mesh passage acceptance.
  The active recipe does not yet contain `passage`; adopt only with the next
  complete sample/scene candidate. `grade_probe.gd` reuses routed geometry in
  under a second, avoiding another full route search for height experiments.
- Crucial next geometry gap: build and probe the actual stairs/platform/roof at
  `3:8,4>3:9,3` over `3:7,3>3:8,3`. Tall span has deck arcs ~8.0875..13.092;
  the full route is ~36.94 m. With 1 m reservations the envelope fits, but turning
  landings still need full-width geometry, not merely centreline length. The new
  resolved-flight helper owns its internal landings; a section assembler may need
  a bounded flight-between-external-landings API to avoid duplicate floor owners.
  Do not claim the headroom probe proves complete stairs or corner landings.
  `_apply_spans` still assumes zero-baseline input; `_span_option` rejects nonzero
  elevated routes. Route interior Y is still planar. Integrate profile terraces
  and their walking surfaces with that limitation explicitly resolved; do not
  silently warp renderer Y. Hero contract is still the translated old ring at
  X=91, not the hall's actual reserved footprint; replace/bind before final compile.
- Old passage diagnosis: native `/tmp/act3-baseline-unshaded.png` and
  `/tmp/act3-baseline-wireframe.png` retain jagged stair edges and excessive mesh
  density; lighting alone cannot repair them. `/tmp/act3-baseline-depth.png`
  was also inspected, but has insufficient contrast to resolve small stair seams;
  do not treat it as decisive contact proof.
- New structural experiment: `resolved_flight.gd` and `flight_mesh.gd` create one
  walking surface owner, landings, risers and walls. Actual mesh normals, station
  contacts, tread/riser limits and descending equivalence pass the focused test.
  `/tmp/act3-flight-study.png` inspected: clean native greybox, 112 triangles.
  Still needs adjoining terrain/turning landing integration and full-width probes;
  this isolated component is not architectural or chapter acceptance.
- Blender kit started: `tools/map_workshop/act3/build_precinct_kit.py`, Blender
  5.2.1. Outputs in `act3/kit/`: great hall (~10k triangles), open cloister bay
  (488), glazed bay (553). `kit_study.gd` imports current GLB directly via
  GLTFDocument, builds once and captures front/quarter/roof native views.
  `/tmp/act3-hall-{front,quarter,roof}.png` are private iteration views.
  V1 had transformed window groups outside walls and occluded glass. V2 fixed
  group matrices with one explicit local-to-site transform, opened tower recesses,
  removed the roof front cap hiding the gable, moved the door backing and darkened
  stone/roof. Quarter and front inspected: window placement is coherent. Narrow
  door lights disappear obliquely because of their deep reveal, visible head-on.
  This is a clean first architectural candidate, not final art acceptance: refine
  character/roof/spires/glass as needed against the concept after spatial assembly.
- Next: resolve actual terrace/2.4 m passage geometry in the hardest real section,
  bind new hero reserves, then assemble architecture/material/light into that
  section. The hall may face +Z (Blender -Y) behind the terminal forecourt, giving
  its facade to the agreed camera; validate placement against real route occupancy.
  Expand to the full chapter only after section inspection.
- Outstanding: profile reserves/heights and source-bound caching, smoke seeds,
  new architecture and scenery, all reference-shape/continuous visual proof,
  performance measurements, final gates and independent exact-candidate review.
