# Act IV Step 3 — The Mirrored Road

## Task capsule — 7 September 2026

Act III Step 3 was explicitly approved by James after delivery 462b66e5, with
optional later polish. Act I/II approvals remain intact. The owner now authorises
Act IV Step 3. This plan records the next chapter before implementation; it does
not reopen the approved concept or require routine permission to proceed.
The preceding Act III plan is preserved in
[accepted-plan.md](docs/map/studies/act3-step3/accepted-plan.md).

Goal: translate the approved grand-empty v6 concept into a convincing native,
interactive five-stop journey, coherent with the other chapters and actual Act IV
combat. Complete Step 3, report the evidence and present the chapter review page.
Non-goals: Step 4 campaign integration, new story/canon, encounter/save changes,
revisiting approved Act I–III, cinematic ocean simulation or new visual systems
without a concrete need. Goal stays off. No Ponytail hook or reviewer.

## Binding art and gameplay inputs

- `docs/map/concepts/act4-grand-empty-v6.png`, inspected again this turn.
  Earlier flat v2 and crowded sanctuary v4 are historical, not active targets.
- `docs/story/00-truth.md` sections 1, 2.4, 2.6 and `03-acts.md` Act IV.
- Actual `assets/art/stage/act4-{backdrop,mid,ledge}.png` and native combat
  capture, not concept colour sampling alone.
- `MapLayoutInputBinding`: exactly five established nodes and four ordered
  edges. Preserve IDs/types, game RNG, reachability and save truth.
- AGENTS.md, Godot skill, AI-SDLC and executable CI scope selection.

## Owner direction update — unbounded space

The owner rejected the bounded courtyard/ground treatment during blockout.
This instruction supersedes v6's floor and enclosure. Act IV must read as an
unlimited/infinite visual space: no ground plane, no perimeter, only the path.
Keep the fixed five-stop journey. Height variation belongs to the processional
way, stairs and destination structures. Remove detached court piers and enclosing
walls; monuments stand on the way. Grandeur comes from the surrounding absence,
the enormous arrival window and the distant intimate hearth. No visible floor,
water sheet, landscape silhouette, horizon or rectangular display base.

Align the actual combat spatial language too where needed; the owner explicitly
permits a combat presentation update. Preserve combat behaviour, actors and UI.
The previous v6 enclosure is a historical input, not authority to restore ground.
First decisive new experiment: native path-in-void composition and combat pair.

## Composition and emotional sequence — revised


Grand, empty, sad and dark. A massive visibly thick rose-window wall marks the
arrival into an unbounded dark space. One supported-looking sculpted path travels
through five stops towards a modest hearth. Its underside disappears into the
void without a surrounding floor. Warm light travels backwards; cool stone,
restrained teal/amber glass and absence preserve the combat world's identity.

The five stops follow the settled reverse journey: threshold, obsidian court,
sunken city, ash woods, hearth. Echoes remain subordinate marks on the path,
not five furnished rooms. Sparse stelae accompany the traveller. Height changes
are expressed through platforms and short complete flights, with no ground plane
or enclosing walls. Reflection is not required; do not reintroduce a mirror floor.

## Ordered execution and proof

| Work package | Result and acceptance | Current progress |
|---|---|---:|
| 1. Bind chapter and establish native baseline | Actual five-node/four-edge input validated; current wide combat captured and inspected; blockout will establish human scale | 100% |
| 2. Whole-place blockout | All five stops on generated geometry; window, void, bend and hearth read at close/whole views; verify stairs and structural thickness | 100% |
| 3. Finished representative section | Window-to-path entry and one level change with final stone/glass/surface treatment; native close and travel inspection | 100% |
| 4. Complete chapter composition | Sparse reverse-act echoes, path-bound stelae, small hearth, supported scenery and coherent light; full uncut journey | 100% |
| 5. Navigation, regression and delivery | Actual node/input/travel tests, all routes supported, three reference proportions, performance, selected gates and exact-head independent review; tailnet page/report | 100% — local gates and independent review passed |

Resolve blockout before producing detailed assets. At each internal stage inspect
the running result and fix failures before presenting it to the owner. Do not
stop at a single asset, still image, successful probe or provisional page.
No routine additional owner approval is needed within the accepted direction.

## Reuse and ownership

Act IV owns `tools/map_workshop/act4/`: spatial recipe, local assembly, architectural
kit, palette, void atmosphere and capture entry point. Use the generator's
existing spatial/profile seam; do not move final nodes manually after compilation.
First inspect the fixed-journey compiler constraints before designing a profile.

Reuse `common/` walking surfaces, resolved stairs, relief, occupancy/footprint
checks, floor/headroom audit, camera/input inspection, route Travel/guidance and
capture/profiling tools. Keep chapter style opt-in. Water and bridge modules are
available only if actual composition calls for them; neither is the default.
The void uses one slow canvas haze shader and 42 instanced drifting embers.
No reflection buffer, floor, horizon, SSR or particle simulation is required.

Godot remains the final visual authority. Existing Blender tooling may produce
new architectural assets after its current source is checked. Shared improvements
must preserve Act I–III entry points and receive affected-chapter regression.
One owner and worktree; exactly one required independent final-candidate review,
with a batched correction review only for concrete blockers.

## Discovery budget and delivery forecast

First discriminating experiment: native five-stop blockout, judged against v6
at journey/whole cameras. Hypothesis: an unbounded void and a single
bent raised route can deliver grandeur without ground or dense scenery.
Success: all five stops and four edges preserved; window/hearth hierarchy and
relief read; one usable close journey and overview; no unsupported joins.
Stop/redesign internally if framing needs hidden edges, invented stops, filler
assets or a stronger reflection system merely to make the space understandable.

Working forecast, not a committed finish time: first native composition 45–75
minutes; complete Step 3 approximately 4–6 hours if the spatial seam and shared
geometry fit. Reforecast from the blockout, rather than repeating an untested ETA.
Time checkpoint after each package and at most 90 minutes without a design
verdict. Batch captures and run narrow checks during iteration. Run the full core
once on the coherent delivery candidate, after native inspection has removed
visible defects. Preserve failed experiments without counting them as passes.
Record real wall time, measured root-session cached/uncached/output token deltas,
reviewer availability limits and any repeated work in the delivery report.

## Acceptance and final boundary

Native 1458×820, 1180×820 and 844×390, plus uninterrupted window-to-hearth travel.
Check every stop and complete walking width, ground contacts, stairs and camera
occlusion. Inspect current/next/visited readability without decorating a permanent
graph across the court. Qualify actual shader modulation and alpha at authored
layout values before final review; the Act III regression must not recur.

Measure native CPU/frame interval, draw calls and renderer allocation, plus GPU
where tooling supports it. Desktop proportions are not physical-device evidence.
Core and selected tests must pass; retain expected headless diagnostics honestly.
Presentation evidence must be native and unretouched. Update the chapter report
and all-act comparison. Stop after delivering Act IV Step 3 for its chapter approval;
Step 4 begins only after all four Step 3 approvals.

Current base: `462b66e517ad0ad6e5dd10038f802f7737a8d28b`.
Current branch: `jamesto/map-journey-rebuild`.
Baseline evidence: `docs/map/studies/act4-step3/`. Godot 4.7.2 native combat
captured at 1458×820. Seed 717 exports five nodes/four edges with hard_pass=true
through validated current-input cache reuse; this qualifies the existing input,
not the future Act IV recipe.

Checkpoint 10:18 UTC: the replacement path-in-void candidate preserves all five
stops/four routes. Native wide input/guidance passes; 2,240 floor/headroom probes
and 189 lowest asset-vertex contacts pass. Phone input also passes; its final
material/capture matrix remains due. Native combat ground comparison is inspected
at 1458×820 with original alpha/modulation retained. The image-generated alternate
had a baked checkerboard and was rejected. Orthographic sky radiating artefacts
and an obstructing echo foot were also rejected and corrected before delivery.
Remaining: final three-shape inspection, uncut tour, profiling, core, independent
review and review page/report. Working remaining forecast: 90–150 minutes,
conditional on the final gates; not a committed delivery time.

The owner's background addition is binding: restrained cosmic haze and slow
sparse embers give the absence intentional atmosphere without filling the void.


Checkpoint after candidate validation: core 102 suites passed (1,430.59 seconds),
complete parser sweep 442 passed, imports and selected specialist gates passed.
The 28.77-second native film reaches the hearth through actual Walk all input;
Tailnet playback, comparisons and 390 px responsive layout are verified. Source
candidate: c0570e4ba664a7d531d19e52ce6216540d41cb87. The final independent review
is next; no runtime edits have been made while the core gate was running.


Final local acceptance: Act IV Step 3 engineering is complete. Independent review
APPROVE at ac4a3d8dd4ad2a533cb472d87ddb85b78382338c has no findings. Implementation
and native media remain unchanged from the measured source candidate. The report,
reusable lessons and private Tailnet page are delivered. A draft review PR is
scoped from the accepted Act III checkpoint; its hosted CI state is recorded live
in that PR, without adding another status-only push that reruns unchanged code.
The remaining human boundary is Act IV art approval. Step 4 is not started.
