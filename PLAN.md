# Map visual renovation — Steps 4–8

## Task capsule — 7 September 2026

Owner: James. Execution: one agent and one owned worktree. All four chapters are
owner-approved at Step 3, including Act IV on 7 September. The owner authorises
moving forward autonomously; this document is the execution contract for Steps
4–8, expanding the agreed visual-renovation-rough-plan.md sequence.
The preceding chapter plan is preserved at
`docs/map/studies/act4-step3/accepted-plan.md`.

Starting HEAD: `8ac26a91d3c5a54715bf94938cd8973063e6c7cf`.
Starting branch: `jamesto/map-journey-rebuild`.
Known delivery topology: draft PR #540 is based on the Act III checkpoint branch,
not main. Refresh actual refs, PR state, ownership and prerequisite ancestry before
integration. Never merge an incomplete prerequisite chain or delete unsaved work.
Preserve unrelated untracked Act II/III experiments and sidecars.

Goal: deliver the approved four-act top-down map experience inside the real Godot
campaign, driven by the map generator, with coherent production visuals, reliable
navigation and encounters, stable saves and relevant performance evidence. Finish
validation, independent review, PR, CI, merge and safe branch cleanup. Provide a
playable review surface and a concise final completion/usage report.

Non-goals: new story, encounter rules, node IDs, save schema, a replacement map
generator, a web implementation, store release, new native plugins, unrelated
cleanup or reopening approved art direction. No Ponytail hook. Execution uses normal long-running mode, as explicitly requested by James.
Goal remains off; do not create a goal or a continuation automation. Continue
within the active run through completion, retaining this capsule across compaction.

## Authority and chapter identity

Follow AGENTS.md, docs/agents/ai-sdlc.md, the Godot skill and tools/ci_scope.py.
The user's accepted chapter direction overrides older concepts or status notes.
Use current native approved evidence, not obsolete root review pages:

- I: `docs/map/studies/step3-review/`, Review 10; substantial ash woodland,
  natural grouping and relief, crisp quiet ground, integrated river and bridges.
- II: `docs/map/studies/act2-step3/`, scenery-v2; drowned architecture, restrained
  water, supported stone crossings, meaningful node-linked ruins and scenery.
- III: `docs/map/studies/act3-step3/precinct-v4/`; intact obsidian precinct,
  terraced courts and stairs, severe architecture and concentrated magenta light.
  Preserve accepted contextual navigation; do not restore arbitrary road ribbons.
- IV: `docs/map/studies/act4-step3/void-v1/`; visually unbounded void, only the
  raised processional path, five existing stops/four edges, immense arrival window,
  sparse echoes, small hearth, quiet cosmic haze and embers. No surrounding floor.

Shared quality does not require equal density or identical structures. Water,
bridges, roads and vegetation appear only where the chapter calls for them.
Preserve combat/map material alignment, including real shader alpha/modulation.

## Ordered delivery and acceptance

Percentages measure accepted deliverables, not elapsed time, code volume or an
agent's confidence. Existing studies are reuse inputs, not completed production.
Freeze a finite acceptance checklist during the initial audit; assign progress
from completed checklist items and change it only with an explained scope change.

| Step | Weight | Deliverable and completion gate | Accepted progress |
| --- | ---: | --- | ---: |
| 4 — Finished playable section | 20% | Promote a representative generated section through the production presentation seam. Integrate relief, surfaces, banks, stairs/bridges where relevant, scenery, light and node interaction. Inspect close/journey/overview and moving camera; no broken joins, floating assets, clipping or stretched ground. | 20% |
| 5 — Visual acceptance | 10% | Judge the running section against approved chapter evidence, at all reference proportions, with navigation visible and hidden. Fix known defects before expanding. Record the actual visual verdict and rejected defects. Agent-owned gate; no routine owner approval. | 0% |
| 6 — Generator generalisation | 25% | Generalise placement and chapter profiles over the maintained map corpus plus explicit dense branches, merges, crossing levels, long routes and edge cases. Retain node/edge truth, repeatability and walkable geometry. Resolve the preserved dense seed 4 failure rather than substitute an easier seed. | 0% |
| 7 — Four-act production | 25% | Integrate all four approved identities into runtime assembly using qualified shared modules and chapter recipes. Verify per-chapter composition, combat alignment and transitions across the whole journey. No preview-only paths or palette-swap substitute. | 0% |
| 8 — Integration and delivery | 20% | Real campaign entry/travel/encounter return/save-load, shapes/input/accessibility/performance, selected gates and independent review pass. Deliver review surface, merge the final reviewed outcome, observe integrated checks and clean only safely saved task branches. | 0% |

Overall implementation acceptance starts at 0% for Steps 4–8; Step 3 is 100%
owner-approved separately. Overall = sum(weight × accepted step fraction).
Steps 4/5 establish the common section; Step 6 proves generalisation before Step 7
expands it. Run narrow integration checks as seams change rather than defer all
runtime failures to Step 8. Reuse already-qualified work after checking its inputs.

## First execution checkpoint and owned surfaces

First 60–90 minutes: refresh Git/PR topology, inspect runtime map assembly and the
saved production-section candidate, reproduce its recorded dense-layout failure,
map workshop-to-production dependencies and preflight native capture/input and
available device evidence. Produce a bounded file ownership list, acceptance
checklist, applicable performance thresholds and an evidence-based delivery ETA.
This is execution within the plan, not another approval round.

Likely surfaces: presentation/map/, relevant application composition, chapter
assets/materials and tools/map_workshop/ shared modules/profiles; focused tests
and docs/map/ evidence. Verify actual paths before editing. Keep domain logic pure;
commands enter through GlassvowGame.apply and presentation only consumes truth.
Promote reusable runtime modules without shipping capture tools or fixture-only
assumptions as runtime dependencies. Avoid a second parallel renderer or framework.

Prefer one independently mergeable production outcome and ordinary PR. Reconcile
already-approved prerequisite work once; record its actual integration boundary.
Do not create PRs, CI runs or permanent infrastructure per visual experiment.

## Evidence map

| Claim | Cheapest decisive evidence |
| --- | --- |
| Generator truth and determinism | Compare node IDs/types/edges and RNG/save state before/after presentation; deterministic profile replay over maintained corpus and named stress cases. No silent omissions or post-compile node relocation. |
| Supported routes and scenery | Probe actual rendered walking width, landings, stair flights, headroom and lowest asset contacts; inspect native turns, merges, banks and bridge approaches. Reproduce failures unchanged before repair. |
| Commercial visual coherence | Native unretouched captures at 1458×820, 1180×820 and 844×390; close/default/overview, overlays on/off, plus actual pan/zoom/travel footage. Compare all chapters and combat. Numeric gates do not replace seeing the result. |
| Navigation and real flow | Actual legal selection/travel/current-next-visited states, encounter entry and return, chapter transition and save/resume in application/main.tscn. Include unavailable actions and input containment. No immediate-resolution workshop shortcut as campaign proof. |
| Performance and memory | Record renderer/hardware, frame intervals and CPU where available, draw calls, memory and repeated chapter entry/exit. Use existing governed budgets and a matched baseline; establish any missing target before claiming a pass. Desktop viewport sizes do not prove physical touch or mobile performance. |
| Shared module safety | Focused affected-chapter regression when a shared material, geometry or camera contract changes; actual authored alpha/modulation checks where relevant. |
| Delivery correctness | Complete local core once on coherent candidate, classifier-selected specialists, one exact-head independent review, hosted and integrated CI results. Preserve negative and inconclusive evidence. |

Use existing geometry probes, capture, profile and test harnesses where they
observe these claims. Add focused regression tests for real defects; do not write
implementation-mirroring tests or build a new evidence system without necessity.
Preflight physical-device requirements early. If a relevant mandated gate cannot
be observed, report the missing evidence and do not label it passed or 100%.

## AI-SDLC and the four rules in practice

1. Anthropic DNA: accepted owner intent → this design/plan capsule → bounded
   build experiments → progressive tests → independent review/integration →
   final handover and maintained regression coverage. Do not duplicate intent/spec
   documents or reopen settled art choices.
2. Minimise wall time / maximise effectiveness: diagnose upstream, batch native
   captures, run independent read-only checks together where safe, reuse modules
   and stop investigating once evidence decides. One writer; no shared mutations.
3. Minimise tokens: targeted reads, concise tool output, one current capsule,
   deterministic mechanical checks and one non-fork final reviewer. No repeated
   transcript scans, overlapping reviews, heartbeat polling or status-only pushes.
4. No quality compromise: every material claim retains decisive evidence. Failed
   visuals, dense seeds, save compatibility and required performance gates cannot
   be waived to fit a forecast. Do not call a study or PR merge a shipped campaign.

For each unresolved design question record hypothesis, immutable input, cheapest
experiment, 30–60 minute initial budget and a decision/stop rule. At budget expiry,
record what was learned and narrow the next experiment or expose the blocker;
never repeat the same failed attempt without new evidence. Routine repairs proceed
without owner permission. Do not create artificial stopping points at small wins.

## Validation and integration sequence

During iteration: targeted parse/test/probe, then native inspection for affected
visuals. Stage new .gd files before the full tracked-file parser sweep.
At the coherent production candidate, before first production push:

- godot --version
- tools/check_imports.sh
- tools/check_scripts.sh
- godot --headless -s res://tests/run_all.gd
- Specialists selected by tools/ci_scope.py for the complete intended PR diff.

Run exactly one final-candidate independent review using
`.claude/agents/ai-sdlc-reviewer.md`, non-fork, read-only and isolated. Supply task
contract, base/head, constraints and produced evidence. Batch concrete findings;
rerun invalidated checks and review the corrected head if required. INCONCLUSIVE
means name the missing evidence, not manufacture approval. Never approve our own
PR through the author's identity. Observe relevant PR and integrated-main checks;
merge when authorised and green. Delete only task-owned branches with saved work.

## Delivery forecast and resource controls

Initial planning allowance: 12–20 active engineering hours plus required CI and
any external gate wait. This is a low-confidence conditional forecast, not a
committed completion time or a token entitlement; production seam/device access
and dense-layout qualification are not yet audited. Replace it at the first
60–90 minute checkpoint with a bottom-up estimate, without a new approval request.

Initial allocation: Step 4 2–3h, Step 5 1–2h, Step 6 3–5h, Step 7 3–5h,
Step 8 3–5h. These are planning ranges; shared work is counted once.
At each step completion or 90 minutes of active work, whichever comes first,
update this capsule with evidence, accepted percentages, elapsed time, remaining
range and the cause of any change. Provide concise meaningful progress during
execution; do not leave the user without an update for more than 60 seconds.
Forecast overruns trigger diagnosis/reforecast, not lower quality or routine pauses.

Capture platform-provided usage at execution start and stage boundaries only:
input, cached input, uncached input, output and elapsed wall time when available.
Do not add reasoning tokens twice or equate cache hit rate with monetary/Pro-quota
savings. No numeric token budget has been authorised; do not invent one or create
a token-estimation system. If usage is unavailable say so. Investigate repeated
context reloads or reruns when they occur; do not burn tokens measuring tokens.

## Completion and exceptions

100% means all five gates above pass, the real four-act campaign presentation is
integrated, independent review and relevant CI pass, the deliverable can be
reviewed, and final status/limits/usage are reported. No routine human review at
Step 4 or Step 5. James may give steering at any time without becoming a dependency.

Escalate only a material unresolvable departure from approved art, conflicting
binding authority, breaking save/ID changes, native platform integration, provider
access/terms, or an unavailable/inconclusive required gate. Observe the repository
600-line per-code-file per-commit stop; design bounded modules, not artificial
commit slicing to evade it. Preserve evidence and state the precise decision.

## Execution checkpoint — started 7 September 2026

Owner explicitly starts normal long-running execution, including regular coherent
commits and pushes. Goal remains off. No routine stage relaunch is required.

- Verified engine: 4.7.2.stable.official.ed1daf0bf.
- Fetched origin: main is 2ed6cdb0302ba3aab5845a18d862841165e8aaf7,
  also the merge base; the current branch contains 29 additional commits.
- PR #540 remains open against the Act III checkpoint. The complete approved
  prerequisite chain is present in this branch; integration will target main
  once the complete production outcome has passed its gates.
- Production still uses MapScene/WorldMapScreen and the previous landscape.
  Approved workshop assets have not yet been promoted into campaign assembly.
- Started the unchanged Act I seed 4 exporter before any code edits. Evidence:
  /tmp/glassvow-steps4-8/seed4-baseline.log and associated result/certificate.
- Initial ownership: presentation/map runtime assembly, promoted geometry and
  materials, affected application composition, focused map tests and this capsule.
  Unrelated untracked experiments and generated sidecars remain untouched.

Next: finish baseline reproduction and runtime dependency audit; promote the
representative Act I section without importing workshop capture or fixture logic.
All implementation acceptance percentages remain 0% until the relevant gates pass.

### Initial implementation evidence (not a stage acceptance)

- Saved shared-module promotion: 7f10a4df. Twenty-two existing woodland modules
  now live under presentation/map/landscape; maintained study callers use the
  same code. Pure relocation and reference updates preserve rendering behaviour.
- Native relocation capture inspected: /tmp/glassvow-steps4-8/promoted-act1.png.
- Running full core on isolated exact commit 7f10a4df in
  /tmp/glassvow-map-promotion-check before its first push; implementation continues
  in the owned checkout. This prevents moving code from invalidating the check.
- Unchanged seed 4 reproduces NO_FEASIBLE_NODE_ROUTE_LAYOUT, input
  dc9ce44058f18539d75337c5420b5348cb0a21d19790b228ff59c3167e5e673c,
  selection_screen_preflight/domain_empty. Full certificate is retained under
  /tmp/glassvow-steps4-8/act1-seed4-baseline.json.failure.json.
- First production assembly renders the approved woodland in WorldMapScreen.
  Native phone input exercise passes drag, wheel, keyboard, travel start,
  exactly one arrival and frozen return. This is component navigation evidence,
  not actual encounter/save-load acceptance.
- Current assembly has known defects: old circular UI and old camera contract;
  6.4–7.6 s construction; the small elevated synthetic fixture cannot place the
  study's mandatory gateway; old plinth/bridge-node-name assertions need to be
  replaced by equivalent actual geometry observations once the production
  assembly contract is settled. These failures are not waived or marked passed.
- Camera experiment: shared 55-degree local framing must fit raised choices AND
  keep ink/touch regions separate; overview is non-interactive. Initial pure
  regression passes all three reference shapes and rejects coincident targets.
  It is not wired into the compiler/runtime yet. Next decisive check: actual
  native projection and full current/successor groups from the preserved seed 4.

### Camera experiment decision

The native Godot projection agrees with the shared 55-degree equation to
0.000184 px. Of 603 authored current/successor shape contexts across seeds 4,
717 and 17634, 598 fit the strict local ink/touch contract. The five failures are
all the initial spread of alternative entrances, before any current node exists;
all ordinary journey choice groups fit. This is authored-anchor evidence only.

Decision: opening entrance selection needs an explicit area-inspection state.
Overview selects an area and frames its entrance; it must not directly enter an
encounter or pretend that tiny global icons are valid touch targets. Local
confirmation remains a distinct legal action. Keep the full entrance set available
through overview/area navigation. Do not shrink glyphs or touch sizes to force the
wide opening group to pass. Qualify this state in the compiler camera identity and
native input before claiming seed 4 or Step 6 completion.
Evidence: /tmp/glassvow-steps4-8/camera-groups.json.

### Saved checkpoint qualification

- Exact 7f10a4df isolated local core passes: Godot 4.7.2; complete import;
  scripts OK (442 checked); PASS (102 tests). Log:
  /tmp/glassvow-steps4-8/promotion-core.log. No implementation changed in that
  verification worktree during the run.
- The subsequent unused camera contract and its focused test at 9ddf20c3 pass
  their explicit parser/test gate. They do not yet replace the live compiler.
- Native confirmation in isolation succeeds through real mouse events and
  requests the correct node. The remaining combined input failure depends on
  preceding drag/wheel actions, so investigation is narrowed to that sequence;
  direct method calls are not substituted for actual input.


### First-hour audit — 13:24 UTC, 7 September

The following finite checklist fixes the acceptance denominator: five equally
weighted items within each step. An item passes only with its complete evidence;
partial implementation does not receive fractional credit.

- Step 4: [x] approved shared woodland geometry promotion with native comparison
  and exact-commit core; [ ] truthful production geometry/asset identity and
  grounded traversal; [ ] local inspection/confirmation and overview throughout
  the section; [ ] scene construction and lifecycle within the applicable budget;
  [ ] complete playable section inspected in all required poses.
- Step 5: [ ] desktop composition; [ ] tablet composition; [ ] phone composition;
  [ ] moving camera and overlays on/off; [ ] all observed material visual defects
  resolved and accepted against the approved woodland reference.
- Step 6: [ ] camera and physical presentation share the compiler contract;
  [ ] preserved seed 4 qualified; [ ] maintained corpus repeatability/truth;
  [ ] dense branches/merges/long routes; [ ] crossing levels, contacts and bounds.
- Step 7: [ ] Act I final recipe; [ ] Act II final recipe; [ ] Act III final recipe;
  [ ] Act IV final recipe; [ ] whole-journey/combat alignment and transitions.
- Step 8: [ ] actual campaign/encounter/save-load; [ ] input/accessibility and
  physical-device evidence; [ ] performance/lifecycle and selected local gates;
  [ ] exact-head independent review and PR CI; [ ] integrated checks, review
  surface, safe cleanup and final usage/completion report.

Accepted progress: Step 4 20%; Steps 5–8 0%; overall 4%. This credits the
qualified shared-module promotion, not the unfinished production renderer.

Native combined input now passes on phone and tablet reference shapes, including
balanced wheel events, drag, inspection before confirmation, and exactly one
arrival despite repeated travel input. The earlier failure was the preview
harness retaining wheel-button capture; the fix sends the missing release rather
than bypassing the real button. Current navigation remains a component result.

Measured on Apple M1 Max, Metal Mobile renderer, phone reference viewport:
construction 6249 ms; terrain 3533 ms (ground 1183, roads 1977, river 327), scenery
1197 ms. Runtime frame p95 16.687 ms, 336 draw calls, renderer 312.72 MiB; GPU timer
unavailable. This does not pass the governed 16 ms frame ceiling or establish
physical-mobile performance. Logs: /tmp/glassvow-steps4-8/journey-phone-profile.log.
Paired physical iPhone 16 Pro Max and iPad 8th generation are available; neither
has yet provided this candidate's device evidence.

Remaining forecast: 12–20 further active engineering hours plus external gates,
conditional on compiler/camera and terrain integration and physical-device access.
The first hour exposed real production seams absent from the studies, including
per-return reconstruction and obsolete asset/geometry metadata. The forecast is
not a committed completion time. Re-estimate after the representative section and
seed 4 are qualified; do not defer these risks to the last stage.

Usage checkpoint at 13:07 UTC, relative to 12:19 start: 16,832,292 input tokens,
16,621,824 cached input, 210,468 uncached input; 60,397 output tokens, including
30,002 reasoning tokens. These are platform counters, not a price or Pro allowance
conversion; reasoning is not added twice. Keep subsequent reporting at stage or
material forecast checkpoints, with focused reads and no overlapping reviewers.

Next: make the production assembly contract truthful, qualify the camera against
actual terrain, reduce measured construction cost without degrading the approved
surfaces, and save the resulting coherent section checkpoint. All known failing
binding assertions and the elevated gateway fixture remain unresolved.

### Surface identity and dense-layout experiment — 13:46 UTC

Saved navigation checkpoint: 7384b910 (local, not yet pushed; coherent core gate
still pending). Native balanced input passes with indexed terrain and the quieter
navigation panel. Ground equivalence covers 138,240 triangle corners: zero
position, normal and colour error; 23,353 shared vertices. A separate arithmetic
micro-optimisation gave no meaningful gain and was discarded.

The final surface stage now records actual supported waystone heights, sampled
roads and every instantiated scenery transform in the returned MapLayoutResult.
The upstream proposal remains immutable and its digest is retained separately.
No graph IDs or connections change. The surface stage belongs to compilation;
it must finish and qualify before the scene becomes navigable. Upstream hard
measurements are explicitly removed from this derived result, rather than
misrepresented as surface proof. Real imported geometry supplies the surface asset
profiles. The regression checks actual instances, not an unrelated legacy list.
The former scenery filter described 201 objects while the actual approved recipe
contained 487 scenery objects and one gateway. Removing this unused filter reduces
observed construction from about 6.2 to 5.4 seconds, still outside acceptance.

Dense-layout question: can the shared current/successor camera contract qualify
seed 4 without changing its topology, and does the already-maintained layered
ordering remove its physical congestion? Inputs are seed 4, current generator and
existing physical clearances. The unchanged failure certificate is preserved.
The first journey-camera trial gets past the old empty screen domain but exhausts
the bounded selection search at an obstructed route endpoint near rows 12–13.
Do not increase search limits or substitute another seed.

Cheapest next experiment: apply the existing layered-order DP to the same 96×60 m
woodland footprint, retaining lane spacing, terrain scale and all graph edges.
Budget: at most three declared first-attempt spatial variants, then one bounded
full compile of the selected candidate. Success requires passing source physical
and camera gates, followed by actual surface/contact/camera qualification; source
pass alone cannot complete Step 6. If ordering alone fails, inspect its named
geometric blocker before selecting wider row reservations. Trial recipes stay
under /tmp/glassvow-steps4-8 and do not become production authority.


### Integration checkpoint — 14:36 UTC, 7 September

The ordinary long run continues with Goal off. The accepted denominator remains
4%; navigation, actual surface identity and scene residency are implemented but
not yet complete-section acceptance. No completion or merge claim is made.

The local journey source recipe still fails bounded compilation. Fresh seed 717
and seed 4 runs both returned SELECTION_WORK_EXHAUSTED after the measured-fanout,
blocked-guide diagnosis, direct-route and minimum-node-reserve repairs. The final
seed-717 obstruction was reproduced from its actual selected candidate IDs,
not from an earlier ground attempt. Its stone marker was clear but its swept road
portal blocked another route's source. A regression now covers those coordinates.
Candidate-domain bounds provide a conservative minimum two-sided portal envelope;
this is a necessary physical constraint, not extra aesthetic spacing. Script
validation and the regression pass. An earlier attempted run had parser errors
and is not compilation evidence, even though the dynamic test runner exited zero.

The corrected full seed-717 run still exhausts selection work, now at
12,2 -> 13,1 blocked by node 12,1. It is preserved at
/tmp/glassvow-steps4-8/seed717-swept-port-qualified.json.failure.json.
The selected seed-4 spatial variant is being rechecked after the same causal
repair; no fourth spatial trial, search-limit increase or seed substitution has
been introduced. This unresolved source gate remains critical-path work.

The component suite reports one real failure: test_map_compose's elevated fake
layout has no eligible gateway site under the new woodland recipe. Several
resume-route cases also log that failed assembly although their route-state
assertions pass. Neither is accepted as complete native campaign evidence.
Full local core is running on the staged checkpoint so the draft branch can be
saved with explicit incomplete status. Source/compiler failures and the fake
layout binding failure block integration acceptance and merge.


### Conflict-learning result and next discriminating experiment

The isolated unit-propagation trial preserves all 16 feasible synthetic answers,
reduces first-solution assignments from 36 to 6, and passes the existing iterator
regressions. Fresh complete-map trials no longer exhaust assignment work: seed
717 uses 2,242 assignments, seed 4 uses 2,906. Both instead reach the existing 64
local-substitution limit with no qualified route result. Thus the original three
spatial variants and subsequent causal repair checks have a negative conclusion;
none is promoted as a production spatial recipe. The trial remains outside the
production compiler until the frozen checkpoint core finishes.

Next hypothesis: the original candidate displacement envelope, inherited from the
small proxy lattice, allows route portals to consume the entire inter-row channel.
One analytical candidate reserves the existing full portal/inflation dimensions
against authored jitter and the maximum candidate offset. Candidate movements are
bounded to 0.6 m longitudinally and 0.8 m laterally; physical road clearances and
camera/touch criteria do not change. Exact derivation and input are retained in
/tmp/glassvow-steps4-8/woodland-analytic-port-trial.json. This is a new explicitly
bounded geometry experiment after the earlier negative decision, not an
undeclared fourth random tuning trial. Budget: one first-attempt grade-aware
probe per preserved seed, followed by a complete compile only for a passing
probe. Failure is retained with its named geometry; do not increase search limits.
A source pass still needs dynamic landscape bounds, actual surface proof, visual
inspection and runtime/performance qualification before promotion.


Frozen checkpoint core (code head 7c640c704c503bdb17abc605f7593c5ff36fc1ef):
Godot 4.7.2, imports and the 457-script sweep pass. The complete suite finishes
with five assertions failing in live locale switching, map composition and
mid-glide shape changes. The locale failure exposes a real cache invalidation
requirement: a language transaction must rebuild map chrome as well as RunHud.
The elevated fake layout/gateway failure remains separately recorded. Log:
/tmp/glassvow-steps4-8/integration-checkpoint-core.log. This checkpoint is safe to
retain as an explicitly unfinished draft backup, not a qualified release/merge.

The analytic spacing probe reaches grade separation. Its first failure identifies
missing approach room: the actual terrace fitter reserves landing plus half the
road width at each turn. Including that footprint, authored jitter and candidate
movement in the existing crossing interval makes the physical probe pass. The
remaining first-attempt failures are branch fanout and a small legacy terminus
silhouette overlap. No complete compile is launched for that failing probe.
An isolated fork regression proves that aiming both exits directly towards two
same-side destinations can make them nearly parallel; angular exit repair passes
that fixture while leaving already-readable forks unchanged. Final source input
must describe the actual production assets; unused legacy landmarks cannot be
carried forward as real surface qualification.


### Qualified component promotion — 7 September, after frozen core

The locale-cache fix and explicit proxy-recipe fixtures pass the six affected
lifecycle/composition/locale/realisation tests. The five frozen-core assertions
are resolved in that focused rerun; no final whole-game pass is claimed. The new
map-residency test covers retention, inactivity, bounded replacement and release
at run end.

Known-conflict unit propagation and measured angular fork exits are promoted from
the isolated trials. Their five focused iterator/fork/router regressions pass,
including exhaustive feasible-set preservation. Iterator version advances to v2
and compiler version to v2 so old cached results cannot silently represent a new
algorithm. Limits and gameplay identities remain unchanged.

The analytic approach/fork trial passes a complete seed-717 compilation with all
65 nodes and 76 edges and zero hard violations. Artifact:
/tmp/glassvow-steps4-8/seed717-analytic-full.json. This is a source result from the
recorded isolated trial, not a production surface/native acceptance receipt.
Seed 4 now fails only legacy-hero silhouette checks in the first-attempt probe.
Next: construct the production recipe from the actual approved assets, bind its
spatial bounds to terrain/paint/planting, qualify seed 4 and inspect the native
section. The ordinary unqualified default input must not be mistaken for this
selected analytic recipe.


### Production recipe and extended landscape — 7 September, 15:37 UTC

The actual-asset woodland recipe passes both retained complete source compiles:
seed 717 (65 nodes, 76 edges, input 658e5078f526a35ec649b19b022fdf33f8e2baacf75dde67f2b2402ca4160914)
and seed 4 (66 nodes, 74 edges, input 6ef91f706fe7b92fb2a768c65de24d82e51c4a470eae5952fc5440aee32f8c29).
Both reports have all hard criteria passing. Runtime now consumes that same
recipe and actual imported asset bundle; the terminus memorial is instantiated
and recorded, not replaced by an unrelated legacy landmark.

Terrain, road-distance paint, habitat, planting and river coverage follow generated
world bounds. Metre-scale mesh and texture sampling remains unchanged. The new
translation/extent/contact regression and four affected runtime tests pass.
The original approved fixture remains valid with default bounds.

Native phone-landscape evidence: journey-production-v1.png/log under
/tmp/glassvow-steps4-8. Actual source input matches the qualified seed-717 input.
Drag, wheel, keyboard inspection, explicit travel and exactly-one arrival pass.
Visually inspected: the local woodland journey renders, but full section visual
acceptance is still open. 2,612 scenery instances, 264 visible draw calls and
336.56 MiB renderer memory. Bind 18,142 ms, scenery 11,376 ms, terrain 4,879 ms.
Frame p95 72.275 ms was captured while background tests ran and is not an isolated
performance verdict. The cold assembly time is nonetheless unacceptable and must
be reduced without reducing accepted asset scale or replacing the approved art.
Next: finish compiler regression, retain this draft checkpoint, profile expensive
placement queries, then inspect crossings and later journey positions. No further
Step 4-8 acceptance percentage is awarded from a source-only pass.

### Placement cost and physical qualification — 7 September, 15:42 UTC

The complete compiler regression passes at the v2 algorithm checkpoint. Draft
906d342e is committed and pushed. The extended default ground remains exactly
identical to the approved original: zero position, normal or colour error over
138,240 corners (23,353 indexed vertices).

A missed old accent boundary is corrected before the performance comparison;
this produces 2,617 placements. Instrumentation measures 20,773 clearance queries:
9,668.029 ms total, only 746.236 ms in road distances. A conservative spatial index
now supplies nearby scenery to the unchanged exact overlap rules. The exhaustive
boundary/negative-coordinate/late-large-object regression passes. Native replay
keeps the exact complete surface digest
965bfcaca01711c910c509b5897f6fb7eb8c571e6fe1fba05d7b096bae04768c
and all 2,617 placements. Query time falls to 1,105.692 ms; scenery assembly falls
from 12,362 to 3,228 ms. Full bind is still 10,632 ms and not accepted as final
performance. No asset reduction or spacing change is hidden in this optimisation.

The existing physical triangle/capsule probe now accepts generated bounds. Seed
717 passes 39,072 road contact probes and 51 adult-body probes, no discontinuities
or body collisions; minimum crossing headroom 3.402 m, maximum measured grade
0.3985, maximum 0.03975 m step. This proves those physical criteria, not every
visual junction or all seeds. Seed 4 and an explicitly fresh source compilation
are next, followed by isolated native timing and visual inspection of the later
crossing and final grove.

### Search priority and moving-frame repair — 7 September, 15:55 UTC

A fresh original-order woodland source compilation takes 121.65 s. The bounded
priority experiment runs the existing grade-aware candidate through every hard
criterion first: both preserved seeds pass in 5.24/5.59 s including asset/input
and report work. Its anchors differ from the earlier deferred-search result, so
old physical receipts are not reused as acceptance for this candidate.

Promoted opt-in `grade-priority-v1` under woodland recipe v2: one fully evaluated
grade candidate precedes the unchanged complete ground/deferred fallback. Default
recipes retain their old order; unknown strategies fail closed. The fallback and
unknown-policy regression passes. Fresh complete recipe-v2 runs pass both seeds
in 7.08/7.82 s with concurrent test work. Their physical replays pass respectively
38,850/44,463 contact probes and 51/102 adult-body probes. Minimum headroom is
3.395/3.366 m, maximum grade 0.4041/0.4604; no contact or body failures.

A separate actual frame bottleneck was whole-record serialisation in the camera
anchor lookup. Every moving frame copied and canonicalised all scenery merely to
read node positions. It now reads the immutable binding snapshot. The targeted
snapshot regression plus map/composition/locale tests pass. Matched native seed-4
phone crossing: identical surface digest, 3,205 scenery instances, 896 draw calls,
326.08 MiB renderer memory; frame p95 falls from 87.612 to 9.637 ms. Waystone update
p95 is 0.610 ms, viewport CPU p95 1.158 ms. This is an isolated desktop/native
component performance result, not physical mobile or full-campaign qualification.
Full bind still takes 10.841 s; cold save-load and first assembly remain open.
The host also now uses one explicit sizing authority, removing the conflicting
full-rect/manual-size warning. Preview terminus/crossing views target generated
geometry rather than obsolete fixed coordinates.

### Derived surface reuse and actual camera inspection — 7 September, 16:53 UTC

A disposable, bounded presentation cache now retains terrain meshes, bridge-field
inputs and deterministic scenery placements. Its key includes canonical graph,
quality, actual asset geometry and export-safe appearance fingerprints, engine,
recipe/surface and cache versions. A checksum manifest rejects changed bytes;
only four entries survive. Source results still validate their full identities,
and the realised record is rebuilt from actual instances on every construction.
Gameplay saves and RNG do not depend on this cache.

Native new-process seed 4: fresh 11,987 ms; reload 2,389 ms. Both produce the same
surface digest 4e86e0e102cb4b4fcd03af2f0533a0a47282458865ae8351c7f92d8bd8a032af
and 3,205 scenery instances. The cached actual meshes pass 44,463 contact probes,
102 adult-body probes, minimum 3.366 m headroom, no discontinuities/collisions.
The regenerated source identity matches the preserved dense seed. Three focused
cache/realisation/canonical tests and three cache/canonical/live-locale tests pass.
Resource pooling and native packed-array vertex transforms preserve geometry.

Rejected experiments: caching the final result merely moved validation cost;
packing all scenery reduced instantiation but increased load cost and leaked
3,207 renderer instances on exit. Both experiments are removed. Cache v5 returns
to individual source-asset instances; successful native reload has no exit leak.
The production wrapper now only overrides compilation when explicitly injected,
so the normal campaign can use the same validated cache path as the preview.
A full Continue timing is still required: 2,389 ms component binding is not a
passing two-second cold save-load receipt.

Corrected preview inspection uses the actual journey camera and generated node
contexts, including the whole-act view. Terminus/crossing/overview captures have
been inspected. The straight outer ground cut remains a visual defect at the
periphery; close bridge/road continuity is present. Next: soften the world edge
without altering routes or approved asset scale, finish all shape/pose inspection,
then qualify the maintained corpus. Section construction/whole-stage acceptance
remain open. Overall accepted progress stays 4%; no unobserved gates are credited.

### Actual targets, save identity and campaign entry — 7 September, 17:23 UTC

The native camera audit exposed a footer collision: an in-frame target centre did
not imply its full hit area was clear of navigation. It also exposed legacy
waystone scaling: the old Control footprint differed from the declared journey
hit envelope. Journey controls now have a real 60×60 target at all reference
shapes, with centred, legible engravings and restrained focus brackets. Native
raster measurement covers 27 glyph/state combinations: maximum painted radius
29.707 px inside the declared 30 px envelope. The camera reserves full targets
above the 88 px footer and below the HUD, with the same projection in compiler
and runtime. Dragging now uses the actual camera pitch. The native peripheral
haze removes the hard landscape cut without changing geometry or route truth.

The initial chrome-only experiment failed both retained source compiles; the
certificates remain under /tmp/glassvow-steps4-8/chrome-v2-source-*. After binding
the actual controls/paint envelope and seating the terminus clear of it, the v4
recipe passes both complete source compiles and native assembly. Four focused
camera/target/catalogue tests pass. The shipped 3.6 KiB geometry catalogue matches
all actual imported model measurements; the corresponding native reload falls
from 2,389 to 1,924 ms with identical surface identity.

The actual application probe uses application/main.tscn and only its own v2 test
profile. Real title Continue, native inspection, explicit Travel and real combat
entry pass, with one current node and the parked map viewport stopped. The first
probe also catches save-round-trip identity loss: JSON changes jitter by about
5.5e-15, causing an unnecessary cache miss. A regression reproduces the failure.
Only the selected journey presentation input now rounds jitter to 1e-9 lane units;
legacy input binding, domain records, IDs, RNG and the save schema are unchanged.
The regression passes four acts × seven seeds × three JSON round-trips, including
unchanged game truth and a maximum 5.01e-10 jitter deviation. Existing binding and
locale tests also pass. The production recipe is now woodland-journey-v5.

Actual fresh-process application receipts: first build without derived data
11,909 ms; subsequent cold-process Continue with derived data 2,353 ms. Both keep
the entire restored RunState unchanged and use the normal compiler path. The
second run has matching input/surface identities and enters combat successfully.
The two-second application load budget is still NOT passed. Next: reduce repeated
static scenery instantiation/draw submission with a bounded native comparison,
then finish section poses and corpus coverage. No scene, seed or quality gate is
omitted to turn this negative timing into a pass.


### Static drawing and real Continue checkpoint — 7 September, 17:56 UTC

- Spatial MultiMesh batches retain all original placement anchors and source
  mesh/material properties. The native independent source-scene comparison
  passes 3,214 draw instances across 13 mesh templates with zero transform error.
  A deliberately displaced GPU instance is rejected; the original transform is
  restored before capture. Native phone crossing inspected; no geometry or
  palette change from batching. Source and surface identities remain a220a66a…
  and 761b5397… respectively.
- The title requests only immutable resources for the saved woodland chapter.
  Scene construction remains on the main thread; abandoned requests are drained.
  The isolated real Continue probe confirms unchanged run data, normal compiler
  routing and the matching derived cache. The latest instrumented measurement is
  2,063.896ms on M1 Max: still above the 2s cold-save-load requirement. The earlier
  uncached construction took 11.9s. Neither is credited as passed. The title probe
  now waits for its actual visible entrance rather than an arbitrary frame count.
- Component moving-camera p95 was 9.94–10.96ms, approximately 326MiB renderer
  memory. This does not establish physical-device or whole-campaign performance.
  All ten changed scripts pass the diagnostic-aware parser check. Logs and
  native images: /tmp/glassvow-steps4-8/batching-final.*,
  batching-checkpoint-parse.log and campaign-profile.*.
- The bounded load experiment has produced decisive component gains and a
  remaining failure. Stop repeated load-only tuning at this checkpoint: complete
  current-surface geometry, visual and corpus qualification next, then address
  the common load path with the four chapter recipes in view.
- Accepted percentages remain 20/0/0/0/0 (overall 4%). Do not turn partial
  engineering into accepted sections. Current conditional remaining allowance:
  Step 4 2–4h, Step 5 1–2h, Step 6 3–5h, Step 7 4–7h, Step 8 3–5h: 13–23 active
  hours plus external gates. This replaces the earlier remaining forecast.
  The increase reflects actual load/save identity/camera contract repairs and
  unqualified chapter-specific assembly, not a change to accepted art scope.
- Usage counter at 17:34 UTC versus the 12:19 start: input 97,527,208; cached
  input 96,432,640; uncached input 1,094,568; output 356,997. Reasoning 197,026
  is included in output, not added again. Cache fraction 98.88%; these are API
  counters, not a claim about Pro allowance or billing. Keep subsequent context
  reads bounded and stop profile experiments once their decision is made.

Current v5 seed 4 actual restored geometry also passes 44,463 contact rays and
102 adult-body probes, minimum bridge headroom 3.366m, maximum local step 0.046m
and maximum grade 0.461. No failures; journey-v5-physical-4.log. This supersedes
older-input physical evidence for this seed, without claiming a full corpus pass.


### Framing and corpus findings — 7 September, 18:04 UTC

The native 12-view seed 4 sweep exposed a clipped terminus memorial on tablet.
A regression reproduced that exact framing failure before repair. Terminal
framing now includes the actual imported landmark AABB transformed by its final
placement, while only waystones participate in target-separation constraints.
The same framing inputs feed the realised-surface camera audit and runtime focus,
including travel arrival. Surface version is woodland-surface-v3; topology and
all placement transforms remain unchanged. Tablet native recapture now includes
the complete memorial. Camera and realisation tests pass (2); six-script parse
passes. Desktop and phone native recaptures also retain the complete landmark.

The maintained second seed 17634 fails current production compilation. Preserve
journey-v5-source-17634.json.failure.json: the opt-in grade-priority candidate
produces ALL_GROUND, but the deferred-only guard rejects it before quality
measurement; ground fallback also exhausts 64 substitutions on a phone branch
fan-out measurement. Next experiment: distinguish the inappropriate deferred
search guard from an actual geometric failure. Do not relax fan-out clearance
or claim the seed passes merely because a guard was removed.


### Measured forks and normal corpus compilation — 7 September, 18:11 UTC

The all-ground priority guard was an inappropriate pre-evaluation rejection for
this explicitly selected strategy. Its default deferred-search restriction is
preserved. A valid flat priority regression failed before repair and now passes;
full geometry/quality evaluation remains mandatory. Removing the guard alone
still rejected seed 17634 at 29.847px fork separation, as recorded in
flat-priority-17634.json.failure.json. This negative result prevented a false fix.

Journey fork guides now widen only a measured failing branch, selecting the
smallest 5-degree increment (bounded at 85 degrees) that passes the unchanged
fan-out evaluator at every shipping shape. Default non-journey routing is
unchanged. The preserved three-way phone case and existing short/lateral forks
pass; five changed scripts parse and two focused test modules pass.
Recipe woodland-journey-v6 invalidates derived caches for the changed route
selection. Normal fresh compilation now passes all three seeds 4, 717 and 17634,
not just the first-attempt diagnostic. Source anchors, edges and hero placements
for 4 and 717 compare exactly to v5. Actual native v6 assemblies of 717 and 17634
also succeed; physical probes are running. No corpus percentage is awarded until
those actual surfaces, determinism and retained graph truth are checked.

The production input/travel film uses native Godot movie recording, 170 frames
at fixed 30fps. The --steps=1 capture travels a real edge, unlike the first-entry
capture whose arrival starts at the initial stop. Three sampled moving frames
were inspected: figure, lane and camera remain aligned. This is presentation
motion evidence, not a gameplay encounter-completion or performance benchmark.
Files: woodland-route-input.avi/.mp4 and route-motion-*.png under the current
/tmp/glassvow-steps4-8 evidence directory.
