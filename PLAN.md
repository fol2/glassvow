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
| 4 — Finished playable section | 20% | Promote a representative generated section through the production presentation seam. Integrate relief, surfaces, banks, stairs/bridges where relevant, scenery, light and node interaction. Inspect close/journey/overview and moving camera; no broken joins, floating assets, clipping or stretched ground. | 0% |
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
