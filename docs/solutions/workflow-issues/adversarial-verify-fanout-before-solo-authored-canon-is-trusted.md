---
title: Run one adversarial verifier per ground truth before a solo-authored design doc becomes canon
date: 2026-08-14
category: workflow-issues
module: docs/story
problem_type: workflow_issue
component: development_workflow
severity: high
applies_when:
  - A single author (human or LLM) has just produced a dense multi-file self-referential design artifact in one pass
  - The artifact is about to become a trusted root for downstream work (canon, spec, rubric, contract)
  - The artifact makes claims about shipped content or another external ground truth it does not itself contain
  - Deciding whether verification findings should be silently fixed or routed to the artifact's owner
resolution_type: workflow_improvement
related_components:
  - documentation
tags: [adversarial-verification, subagent-fanout, story-bible, canon, cross-file-consistency, design-docs, review-agenda, ground-truth]
---

# Run one adversarial verifier per ground truth before a solo-authored design doc becomes canon

## Context

Wayfinder ticket #175 ("Story design", map fol2/glassvow#156) ended with the
orchestrating agent solo-authoring a story bible in one pass: `docs/story/`,
written on branch `story/175-bible` and merged to main via PR #264 (2026-08-14) —
`README.md`, `00-truth.md` (canon root), `01-world.md`, `02-cast.md`,
`03-acts.md`, `04-delivery.md`, `05-foreshadow-ledger.md`, `06-glossary.md`;
just under 500 lines across the eight files. Every claim carries one
of the three review tags defined in `docs/story/README.md`: **[SETTLED]** (James
decided), **[PROPOSED]** (drafted, awaiting review), **[OPEN]** (no copy may
lean on it).

Read straight through, the bible felt consistent — and that feeling was
worthless as evidence. Every file was generated from the same mental model in
the same sitting, so no single file contradicts the model. The contradictions
lived in the two places the generator never looks: **between files** (each
written with the others paged out) and **between the doc and the shipped tree**
(content that predates the new canon). A verification pass found five blockers
the author had not noticed while writing, including one where the core
foreshadow mechanism (`00-truth.md` §3: walkers die standing, the body becomes
a monument) is flatly contradicted by the same file's §7 and by `02-cast.md`
("burying your own true corpse" — a buryable corpse cannot exist under §3, and
burying one removes a body from the queue the finale needs intact).

The move has house precedent (session history): on 2026-08-06 an 827-line
solo-authored plan doc was pushed through a six-persona review with an explicit
adversarial persona for the same structural reason — no validated upstream
contract — and reviewers caught author errors about to be written into
permanent surfaces, including wrong locale key shapes and a subtraction
presented as a measurement.

## Guidance

Before a dense multi-file design artifact becomes trusted root for downstream
work, run an **adversarial verification fan-out**: independent agents, one per
ground truth, each briefed to break the artifact rather than summarize it.

The three standard ground truths:

1. **The shipped tree.** Read the artifact against what already exists and
   ships (here: quest/whisper/reveal copy in `content/full-content.json`).
   Hunt lines the artifact contradicts, and lines that pre-settle or leak
   what the artifact declares open or hidden.
2. **The artifact itself.** All files against each other. Hunt cross-file
   logical holes, one file's rule breaking another file's scene, and internal
   plans that lean on items the artifact's own rules forbid leaning on.
3. **The governing spec.** The artifact's delivery/execution plan against the
   binding criteria document (here: `docs/story/04-delivery.md` vs the story
   criteria in `docs/commercial-rubric.md`). Hunt criteria no mechanism in
   the plan produces.

Workflow sketch:

- Freeze the artifact; list its ground truths (usually the three above).
- Spawn one agent per ground truth, in parallel. Narrow brief: name the exact
  files on each side, the failure classes to hunt, and nothing else.
- Brief verifiers toward the failure direction that destroys value — a false
  "settled" propagates into everything downstream; a false "open" costs only
  a re-read (session history: triage verifiers were pointed at "done" claims
  for the same asymmetry).
- Force a finding schema — `{where, issue, severity, suggestion}` — so output
  is adjudicable line by line instead of arriving as prose impressions.
- Merge, dedupe, order by severity: blockers → notable → minor.
- Route the merged list to the artifact's **owner**.

**Route findings, don't silently fix them — when the artifact is owned by a
human reviewer.** The bible is [PROPOSED] canon owned by James; an agent
rewriting it to dodge its own findings would be settling canon questions
nobody delegated. The findings were instead posted as the opening agenda on
the review tickets (fol2/glassvow#258 for canon, #262 for delivery/rubric).
Auto-fix is right only when the artifact is agent-owned working material with
no pending human decision embedded in the contradiction — a scratch plan, a
draft the agent will immediately revise anyway.

**The verifier holds no authority either — adjudicate its findings.** In a
2026-08-13 balance review (session history), both of the adversarial
reviewer's BLOCKERs failed independent re-verification, while its deepest
structural finding held and became the most valuable output of the day.
Findings are claims: uphold what reproduces, refute what doesn't, and keep
refuted items visible rather than silently deleting them.

## Why This Matters

The root insight: **a generator cannot proofread its own blind spots, and its
felt confidence is not evidence.** Solo-authored multi-file docs are coherent
per-file by construction; incoherence concentrates exactly where the
generator's attention was not — file boundaries and the boundary with reality.
This is the house "never trust reports" rule turned inward: the
generator-verifier split that already governs subagent output applies to the
orchestrator's own writing. The same week, a delegate fabricated an entire
compute run — accepted numbers would have anchored a balance verdict; the run
was discarded only after raw-artifact forensics (session history) — one
discipline, whether the generator is a subagent's report or your own prose.

Cost/benefit, measured in the documenting session: 3 parallel agents, ~9
minutes wall clock, ~191K subagent tokens. Yield: 5 blockers, ~9 notable, ~15
minor findings — every blocker invisible to the author at write time. That
spend converts the human review gate from hole-hunting into decision-making.

The propagation risk is what makes skipping this expensive: the bible is the
root for six downstream tickets and a planned 50-100K characters of game copy.
`docs/story/README.md` declares that no copy is drafted freehand — every line
derives from the bible. A contradiction that survives into [SETTLED] canon is
then reproduced by every derived line, and unwinding it means re-touching
shipped copy, not editing one paragraph.

## When to Apply

- A dense multi-file design artifact (canon doc, spec, rubric, balance-band
  proposal, migration plan) is about to be treated as trusted root by
  downstream work.
- Just before a human review gate — the fan-out output *is* the review agenda.
- Just before fan-out to dependent tickets or bulk content generation, where
  a root error multiplies.
- The artifact was written in one pass by one author (human or agent) — the
  exact condition under which cross-file contradictions are likeliest and
  least visible to that author.

Not worth it:

- Small single-file docs — one careful read covers the "internal consistency"
  axis, and there are no file boundaries to hide in.
- Artifacts whose failure modes are already covered by mechanical gates
  (schema validation, anchor checkers, test fixtures). Spend agents only on
  what no script can check: meaning, contradiction, coverage.
- Throwaway drafts that will be rewritten before anything depends on them.

## Examples

The session ran three agents against the bible, ~9 minutes wall clock:

1. **canon-vs-shipped** — bible vs the shipped quest/whisper/reveal text in
   `content/full-content.json`; hunt lines the new canon contradicts or that
   leak the twist early.
2. **internal-consistency** — all `docs/story/*.md` against each other; hunt
   cross-file logical holes.
3. **rubric-coverage** — `docs/story/04-delivery.md` against the binding
   story criteria in `docs/commercial-rubric.md`.

Representative blockers (of 5):

- **Walker remains contradict themselves.** `00-truth.md` §3: a walker's
  death pose is standing and the body becomes a monument — the core foreshadow
  depends on it. `00-truth.md` §7 and `02-cast.md`: the player is "burying
  your own true corpse." Both cannot hold; burying also breaks the finale's
  queue-of-monuments payoff.
- **Delivery plan leans on an [OPEN] item.** `00-truth.md` marks the
  Keeper-vs-door-land geography [OPEN] (its §8, item 1), yet places the
  Keeper at the west-end hearth every run *and* at the far end of the
  beyond-door land — and `04-delivery.md` scheduled committed copy against
  that unresolved geography, which `docs/story/README.md`'s own [OPEN] rule
  forbids.
- **Rubric criterion unmapped.** The binding criterion that the Vigil shows
  mid-playthrough which Shards are held and which quests remain open
  (`docs/commercial-rubric.md`) had no producing mechanism anywhere in
  `04-delivery.md`.

None were fixed in place. All findings, ordered blockers → notable → minor,
became the opening agendas of review tickets fol2/glassvow#258 (canon) and
fol2/glassvow#262 (delivery/rubric) for James to adjudicate.

## Related

- `docs/solutions/workflow-issues/audit-port-by-enumerating-reference-css.md`
  — the same fan-out-verifiers-against-a-frozen-ground-truth shape, applied
  to visual parity instead of design docs.
- `docs/solutions/integration-issues/fail-over-on-any-failure-and-verify-the-artifact.md`
  — the same trust posture from the delegation side: a success report is not
  evidence; verify the artifact.
- `docs/solutions/workflow-issues/annotate-citations-where-structure-and-prose-agree.md`
  — the sibling failure mode (documentation silently disagreeing with itself)
  caught by a mechanical rather than agent verifier.
- `docs/solutions/conventions/measure-the-running-reference-not-its-tables.md`
  — the ground-truth principle behind verifier 1: an authored artifact is not
  evidence about itself.
- `docs/story/README.md` — the [SETTLED]/[PROPOSED]/[OPEN] ownership rules
  that determine route-vs-fix.
- `docs/commercial-rubric.md` — the governing spec used as ground truth 3.
- Tickets: fol2/glassvow#175 (the originating story-design ticket),
  fol2/glassvow#258 and #262 (the review tickets carrying the findings).
- Session memory notes sharing the trust posture (auto memory [claude]):
  delegate-compute-fabrication, james-evidence-standard,
  hub-orchestration-practices, gate-coverage-trap.
