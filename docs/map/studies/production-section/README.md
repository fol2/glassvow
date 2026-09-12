# The Ashen Woods — playable section candidate

Status: Act I Step 3 is owner-approved. This is the subsequent Step 4 candidate,
with Step 5 inspection and bounded Step 6 experiments in progress. It does not
claim all-layout qualification, completed chapter production or campaign integration.

The approved native workshop and all preceding reviews are saved in local commit
`bf47880c4c90f90973b4e7ade7cfa98d8f215c68` on `jamesto/map-journey-rebuild`.
Current work remains in the same worktree. The ordinary game entry point is unchanged.

## Selected change

- Grade the rounded roads used by the visible surface and traveller. Blend
  neighbouring grading segments continuously and separate paving coverage from
  structural elevation. Dry bridges retain a real opening beneath their crowns.
- Seat physical waystones on measured surface contacts, with individually
  grounded footings, encounter engravings, current/reachable/cleared/selected
  states and the domain's unlit encounter and bounty values.
- Animate an anonymous cloaked traveller along the legal compiled road. Local
  turns go around the waystones; small paved landings provide room on bridges.
  Nearly buried paving remnants do not acquire unnecessary wide platforms.
- Keep the 55-degree Journey / Whole act camera. Whole act is an area-inspection
  view: selecting an area zooms closer without selecting or entering an encounter.
  Close encounter controls retain their 48 px rectangles. Keyboard selection and
  a reduced-motion mode are exercised through native input.
- Resolve a preview encounter only after the visible walk completes. Repeat
  activation during travel and revisiting the current node cannot advance twice.
  This isolated study still resolves encounters immediately on arrival and does
  not save campaign progress. Production commands through `GlassvowGame.apply`
  remain Step 8 work.

## Decisive checks

All figures below are from the selected source after the waystone landings and
local walking turns. Raw logs are kept beside this document.

| Check | Seed 717 | Seed 17634 |
| --- | --- | --- |
| Actual road collision probes | 19,704; pass | 18,009; pass |
| Greatest sampled centreline rise/run; limit 0.50 | 0.4953 | 0.4832 |
| Smallest dry crossing headroom; minimum 2.2 m | 2.261 m | 3.373 m |
| Walking path samples across 76 legal edges | 22,441; pass | 20,637; pass |
| Smallest traveller-centre / waystone-centre distance | 0.849 m | 0.849 m |
| Greatest walking surface height error | 0.0195 m | 0.0132 m |
| Whole bridgehead surface probes | 276,480; no intersections | 149,130; no intersections |
| Current + successor camera contexts | 195; pass | 210; pass |
| Whole-act framing | 3 reference shapes; pass | 3 reference shapes; pass |
| Grounded asset contacts | 200; pass | 200; pass |
| Water coverage and dry routes | pass | pass |

Walking volume probes start above the 12 cm boots: sole-level capsules also
contact ordinary uphill paving, as recorded in `journey-routes-before-clearance.log`.
Ground support is checked separately against the rendered surface. The body
capsule extends to 1.78 m; the independent underpass audit retains its existing
adult capsule and 2.2 m minimum headroom. No original physical limit was relaxed.

The earlier `grade-*.log` files are experimental results, including failures;
their names do not establish acceptance. The selected grade report is
`physical-routes.log`. Widening virtually invisible paving remnants caused a
new lip; restricting the widening to the actual paved coverage resolved it.
Reducing excavation grades was tried, failed and reverted.

Native captures exercise desktop 1458 × 820, pad 1180 × 820, phone 844 × 390,
and reduced motion. `journey.mp4` is a 14-second recording of native frames:
inspection, legal travel, Whole act, then Journey. It uses the same movement
clock and rendering as the interactive study, at 30 frames per second.
`underpass.mp4` replays a legal path to `8,4` before recording the lower route
to `9,3`; it uses the same runner and clock. The cursor is never assigned by hand.

These are desktop-rendered reference shapes, not physical phone performance
evidence. The current camera audit covers current/successor controls and global
route framing; it is not a complete state-dependent glyph/bounty/obstacle audit.

## Generator experiment and remaining boundary

Question: do the shared terrain and journey rules survive a second topology,
and can a dense additional graph be freshly compiled without changing inputs?

Inputs: current content and compiler, the current shipping quality registry,
shipping camera/asset profiles, Act I seeds 4 and 17634. Seed 4 was chosen from
the earlier small graph census for density; 17634 is an additional known corpus
seed. Neither modifies gameplay nodes, edges or seeded randomness. The exporter
accepts an explicitly named sample and fails rather than substituting one.

- **Seed 17634:** freshly compiled, 70 nodes and 76 edges; compiler hard pass.
  The common native terrain, water and journey checks above also pass. The
  gateway terrace is chosen from topology instead of seed 717's fixed location.
- **Seed 4:** `NO_FEASIBLE_NODE_ROUTE_LAYOUT` before native scene construction.
  Unary domains have survivors, but pairwise phone screen constraints empty
  `0,4` and `1,4` in refinement iteration 3. This then propagates to the reported
  `0,0` failure. See `generator-seed4-diagnosis.json`, the concise summary and
  the compressed complete compiler certificate. This failure is preserved.

The shipping evaluator is bound to the old 40-degree camera, fixed zoom stops
and a 25.76 px circular ink radius. The new study uses the agreed 55-degree
adaptive camera, physical engravings and separate area inspection in Whole act.
Changing only the registry's tilt value would not change the evaluator: it
reads `MapCameraRig` constants. The discrepancy is diagnosed, not resolved.

Do not shrink the old ink radius to rescue this seed: selected corner marks,
bounty pills, active targets and overview symbols have different bounds. The
next compiler adapter must explicitly describe those actual states, preserve
minimum touch sizes and zero overlap requirements where encounters are
selectable, and bind its version to the complete compiler input identity.
The same seed 4 must then be repeated under the declared new contract and
inspected natively; success on 17634 does not replace that result.

## Task capsule and next action

Goal: complete the agreed four-act visual renovation, starting with a sound
common playable section. No new concept approval is needed. Preserve the
approved woodland massing, quiet ground, joined roads, real relief and water.

Next: finish the native motion/reference-shape inspection, then implement and
qualify the state-aware camera and asset profile adapter for Step 6. Extend the
qualified rules through the drowned library, intact obsidian court and grand
empty sanctuary, one native chapter at a time, followed by a combined review.
Campaign integration, full local production gate, independent final-candidate
review, PR/CI/merge and cleanup remain later work. No production delivery or
commercial acceptance is claimed by this study.
