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

## Composition and emotional sequence

Grand, empty, sad and dark. Massive visibly thick rose-window wall and only a
few structural piers enclose a recessed mirror court. A bent raised procession
connects the arrival window to a modest hearth. The hearth is familiar and
unsettling, not a glorious palace reward. Warm light travels back towards us;
cool open shadow and restrained glass accents connect it to combat.

The five stops follow the settled reverse journey: threshold, obsidian court,
sunken city, ash woods, hearth. Echoes are subordinate spatial/material marks,
not five furnished rooms. Sparse stelae carry meaning; do not fill unused space
with repeated scenery. Grandeur must read from structure and human scale.

Relief is architectural: broad recessed court, thick perimeter, measured
platform heights and short supported stair transitions. No flat prop sheet;
no unnecessary bridge kit. Keep one legible generated route. Mirror-ground is
quiet polished stone, not an ocean; reflection should reinforce space and light.

## Ordered execution and proof

| Work package | Result and acceptance | Initial progress |
|---|---|---:|
| 1. Bind chapter and establish native baseline | Actual five-node/four-edge input validated; current wide combat captured and inspected; blockout will establish human scale | Baseline complete |
| 2. Whole-place blockout | All five stops on generated geometry; window, court, bend and hearth read at close/whole views; verify stairs and structural thickness | 0% |
| 3. Finished representative section | Window-to-court entry and one level change with final stone/glass/reflection treatment; native close and travel inspection | 0% |
| 4. Complete chapter composition | Sparse reverse-act echoes, piers, stelae, small hearth, grounded scenery and coherent light; full uncut journey | 0% |
| 5. Navigation, regression and delivery | Actual node/input/travel tests, all routes supported, three reference proportions, performance, selected gates and exact-head independent review; tailnet page/report | 0% |

Resolve blockout before producing detailed assets. At each internal stage inspect
the running result and fix failures before presenting it to the owner. Do not
stop at a single asset, still image, successful probe or provisional page.
No routine additional owner approval is needed within the accepted direction.

## Reuse and ownership

Act IV owns `tools/map_workshop/act4/`: spatial recipe, local assembly, architectural
kit, palette, reflection settings and capture entry point. Use the generator's
existing spatial/profile seam; do not move final nodes manually after compilation.
First inspect the fixed-journey compiler constraints before designing a profile.

Reuse `common/` walking surfaces, resolved stairs, relief, occupancy/footprint
checks, floor/headroom audit, camera/input inspection, route Travel/guidance and
capture/profiling tools. Keep chapter style opt-in. Water and bridge modules are
available only if actual composition calls for them; neither is the default.
For reflection, test the cheapest convincing option first: static/cached mirrored
landmark geometry with restrained fade; add a render pass only if native evidence
shows it necessary. No SSR or water distortion by default.

Godot remains the final visual authority. Existing Blender tooling may produce
new architectural assets after its current source is checked. Shared improvements
must preserve Act I–III entry points and receive affected-chapter regression.
One owner and worktree; exactly one required independent final-candidate review,
with a batched correction review only for concrete blockers.

## Discovery budget and delivery forecast

First discriminating experiment: native five-stop blockout, judged against v6
at journey/whole cameras. Hypothesis: an enclosed recessed court and a single
bent raised route can deliver grandeur without dense scenery or heavy reflection.
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
not the future Act IV recipe. No production code has changed.
Next action: prove the whole-place spatial recipe and native blockout.
