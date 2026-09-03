---
title: Preflight evidence capabilities and separate scientific corrections from delivery repairs
date: 2026-09-03
last_refreshed: 2026-09-03
category: workflow-issues
module: agents
problem_type: workflow_issue
component: ai-sdlc
severity: high
applies_when:
  - "A research protocol depends on a runner, oracle, device, permission, syscall, evaluator, provider or evidence channel that has not yet been proven on the actual target path"
  - "A bounded programme contains several predictable PASS/FAIL/INCONCLUSIVE gates and keeps returning to the owner between them"
  - "A frozen scientific experiment finds an ordinary implementation bug in independently mergeable tooling"
  - "A hash, file-open event, synthetic workload or surrogate executable is being offered as proof that production semantics were actually consumed"
  - "A long research chain has produced stable reusable process knowledge that should be compounded without turning its live issue history into permanent instructions"
tags:
  - ai-sdlc
  - capability-preflight
  - finite-decision-graph
  - autonomous-delivery
  - scientific-contract
  - implementation-repair
  - test-oracle
  - provenance
  - fail-closed
  - knowledge-compounding
---

# Preflight evidence capabilities and separate scientific corrections from delivery repairs

## Context

A difficult programme can appear to be one problem while actually containing
four different claims:

1. **Product claim** — the player-facing or release property that must be true.
2. **Scientific claim** — the representation, causal hypothesis, metric or
   experiment used to decide the product claim.
3. **Evidence-capability claim** — whether the available runner, oracle,
   evaluator or observation path can see the evidence the scientific claim
   requires.
4. **Delivery claim** — whether the implementation of that capability or product
   change satisfies an already stable contract.

The Glassvow P9 programme exposed the cost of allowing those claims to blur.
Issue [#421](https://github.com/fol2/glassvow/issues/421) asks for durable
strategy diversity. Several bounded campaigns correctly stopped before product
mutation or simulation, but the programme repeatedly returned to the owner
because each next evidence capability was specified only after the prior one
failed. Later, a scientific correction limit was mistakenly applied to an
ordinary delivery-code defect, causing the same issue, branch and pull request
to be closed even though the acceptance contract had not moved.

The useful result is not a rule to be less strict. It is a stricter separation
of responsibilities:

> **Prove that the evidence surface exists before freezing a protocol that
> depends on it. Freeze safe transitions once. Keep scientific-contract changes
> separate from delivery implementation repairs.**

This note records the reusable pattern. It is not the live status authority for
P9, #421, [#535](https://github.com/fol2/glassvow/issues/535), or any later
campaign. Active issues and exact receipts own live state. Historical failures
remain immutable evidence; they are not rewritten here into a cleaner story.

The governing repository contracts already contain the concise rules:

- [`docs/agents/ai-sdlc.md`](../../agents/ai-sdlc.md) owns capability-first
  research, finite decision graphs, autonomous delivery and correction
  boundaries.
- [`docs/agents/issue-tracker.md`](../../agents/issue-tracker.md) owns issue,
  branch, PR and handoff structure.
- [`docs/balance/p9-strategy-diversity-system.md`](../../balance/p9-strategy-diversity-system.md)
  owns the P9 scientific sequence.

This note explains how to apply those rules and why they exist.

## The four-layer claim model

Before designing a workflow, write the active claim at the correct layer.
Failure at one layer does not automatically establish a result at another.

| Layer | Example question | Valid negative result | Invalid inference |
|---|---|---|---|
| Product | Does the release support the required strategic plurality? | Exact P9 acceptance fails on qualified evidence | The product is impossible because an oracle could not be built |
| Scientific | Does the frozen grammar contain a non-reducible, source-realizable package? | Complete scoped `NO_SURVIVOR` or a causal falsification | No package exists because enumeration was never executed |
| Evidence capability | Can the actual production path be observed with the required provenance and oracle independence? | `CAPABILITY_UNAVAILABLE` or bounded `INCONCLUSIVE` with an exact missing witness | The scientific hypothesis is false |
| Delivery | Does the runner implementation satisfy the unchanged capability contract? | Architecture failure or delivery budget exhausted | One copy/permission/serialization bug invalidates the scientific contract |

This classification should appear in the task capsule and terminal receipt. It
prevents three recurring errors:

- calling unavailable evidence a product failure;
- using a green internal test as proof that the instrument observes production;
- treating an implementation defect as permission to change the experiment.

A terminal word is incomplete without its claim boundary. Prefer:

```text
PREEXECUTION_INCONCLUSIVE
claim: exact merged inert profile cannot attest the actual Godot M09 path
not established: M09 adequacy, source expressibility, P9 feasibility
```

rather than:

```text
A1 failed
```

## Rule 1 — preflight the evidence capability before protocol freeze

A protocol should not freeze an assumption that the environment can perform the
measurement. First run the cheapest non-authoritative probe that can answer:

> **Can this exact venue, tool, permission and observation channel see every
> material fact the later experiment will claim?**

### Build a claim-to-observable map

For every acceptance statement, name the evidence surface and how it is
observed.

```text
Claim:
  the actual runtime consumed the frozen corpus bytes

Required observables:
  exact input identity
  actual access mechanism
  consumed byte ranges
  process and descendant identity
  same-invocation output

Observer:
  external supervisor / OS provenance channel

Unsupported mechanisms:
  named explicitly; fail closed
```

Do this for executable identity, arguments, environment, semantic inputs,
identity-only dependencies, stdout/stderr, output files, process lineage,
random-state or clock evidence, and dropped-event accounting where relevant.

### Measure the actual target path

A surrogate may be useful for developing a tracer, but it cannot qualify a
claim about a materially different production path. If the target is Godot,
measure Godot. If the target is an audio judgement, use an approved
playback-capable evaluator. If the target is a signed iOS build, inspect the
signed build rather than a desktop approximation.

Diagnostic tools may inform the contract without becoming acceptance evidence.
For example, a permissive syscall trace can reveal the minimum runtime profile;
it does not by itself prove zero-loss provenance or semantic-byte consumption.

### Classify inputs correctly

Not every file touched by a process needs the same proof.

- **Semantic inputs** influence the scientific or product result. Their actual
  consumed bytes or an equivalent strong semantic witness must be bound.
- **Identity-only dependencies** establish the runtime implementation, such as a
  loader or shared library. Their exact content identity and observed use may
  be sufficient when their internal bytes are not the measured scientific
  input.
- **Incidental operating-system activity** may be allowed only through a narrow,
  measured profile that cannot smuggle undeclared semantic input.

This classification keeps the profile minimum without pretending that an open
or mapping event proves semantic consumption.

### Preflight output

A capability preflight produces one of three decisions:

- `PASS`: the measured venue and backend can support a bounded protocol;
- `CAPABILITY_UNAVAILABLE`: one required observable is structurally unavailable
  under the authorised venue/backend; or
- `INCONCLUSIVE`: the probe cannot distinguish availability from omission
  within its finite cap.

It does not produce a product, balance or scientific result. Only a PASS permits
freezing the dependent experiment.

## Rule 2 — freeze one finite decision graph, not a series of owner handoffs

When the next safe steps are foreseeable, specify them together. A node should
contain:

```text
Node identity and claim layer
Immutable inputs and exact authorities
Preflight dependency
Cheapest decisive experiment
Run / time / compute budget
Correction rule
PASS transition
FAIL transition
INCONCLUSIVE transition
Terminal human-authority boundary
```

A declared PASS transition is execution authority. The same owner continues
without asking a person to restate acceptance, approve a routine plan, select an
already ranked equivalent option, permit a rerun, press merge, or start the
next named node.

The graph is not permission for open-ended autonomy. It reduces ambiguity by
making stop conditions explicit in advance.

```text
Capability preflight
  PASS -> freeze capability profile
  unavailable -> terminal capability receipt

Capability qualification
  PASS -> scientific instrument check
  architecture failure -> terminal receipt

Scientific instrument check
  PASS -> bounded synthesis / experiment
  mismatch -> one pre-authorised counterexample repair, if declared
  unresolved -> terminal INCONCLUSIVE

Scientific result
  survivor -> causal admission
  complete no-survivor -> declared next grammar or terminal owner choice
  incomplete proof -> terminal INCONCLUSIVE
```

### What still belongs to the owner

Do not pre-authorise across a genuine authority boundary. Escalate when the next
step requires a new provider or credential, paid resource, hardware/TEE,
regulated or irreversible action, breaking compatibility, a product/P9
invariant change, a materially subjective product choice absent from the SSOT,
or release approval.

The owner should receive one decision package after the finite graph is
exhausted, not a stream of implementation updates.

## Rule 3 — scientific corrections and delivery repairs are different budgets

A scientific freeze prevents adaptive movement of the question after seeing
results. It must not freeze defective delivery code forever.

### Scientific or evidence-contract correction

This changes what is being tested or what counts as success. Examples:

- adding or replacing a hypothesis, mutation class or candidate;
- changing the threat model, trusted parties or observation closure;
- changing protocol cases, expected verdicts or error allocation;
- changing a product law, grammar, descriptor or P9 threshold;
- excluding a newly inconvenient context;
- weakening actual-consumption evidence to hash or open intent.

Such a change uses the research contract's declared correction rule or requires
new authority. Prior results are not silently carried across it.

### Delivery implementation repair

This changes code or focused tests only so the implementation meets unchanged
acceptance. Examples:

- copying replay evidence into a fresh writable attack packet instead of
  overwriting sealed evidence;
- fixing serialization, path construction, permission handling or cleanup;
- repairing a parser that misreads a frozen receipt;
- adding a regression for a deterministic bug;
- rerunning invalidated cases from fresh output.

This is normal autonomous test-driven delivery. It does not spend or renew a
scientific correction limit. It is bounded instead by an explicit delivery
budget such as complete qualification attempts, hosted-runner minutes or
wall-clock time.

### Architecture failure

Some failures are not ordinary bugs. If the unchanged attack matrix proves that
the selected trust architecture cannot observe a required mechanism, report
`ARCHITECTURE_FAIL` or `CAPABILITY_UNAVAILABLE`. Do not continue patching until
it appears green.

### Preserve every failed attempt

A repaired implementation does not make the earlier failure disappear. Keep
its exact head, workflow run, artefact and terminal classification. Later PASS
evidence starts from fresh output and does not reinterpret partial earlier
passes as qualification.

This distinction allowed #533 to retain its failed N05 run while continuing the
same issue, branch and PR to an exact-main PASS. The evidence got stricter; the
workflow stopped confusing code debugging with hypothesis movement.

## Rule 4 — prove actual use, not mutually consistent paperwork

A set of hashes can be perfectly consistent while referring to a shadow input
that production never consumed. An instrument must bind the chain that carries
the claim.

For an execution-provenance claim, record at least:

```text
protocol / authority identity
supplied logical role and bytes
actual consumed path, object and bytes
executable and process/descendant identity
arguments and bounded environment
actual stdout/stderr and outputs
external monotonic interval
provenance completeness / dropped events
unchanged verifier verdict and reason
one invocation identity binding the above
```

For mutation adequacy, add the complete RIPR chain:

1. **Reachability** — the actual mutated surface executed.
2. **Infection** — the relevant semantic state differed.
3. **Propagation** — that difference reached the bound receipt, provenance or
   oracle input.
4. **Revealability** — the unchanged validator rejected it for the intended
   semantic reason.

The following are useful diagnostics but insufficient acceptance by themselves:

- source presence;
- an input hash that was never tied to use;
- an `open` event without byte or semantic binding;
- a literal diagnostic string;
- a surrogate executable that emits the desired error;
- a statement generated by the same projection it certifies;
- an output copied from a prior invocation;
- child-reported elapsed time when the child is under test;
- an archive entry or model score without untouched confirmation.

A matched treatment and baseline generated by the same incomplete projection
can agree exactly and still share the same omission. Independence must exist at
the implementation and evidence-source level, not only in filenames or agent
roles.

## Rule 5 — keep research, capability delivery and product delivery in their proper homes

### Research programme

Keep bounded hypotheses, rows, negative results and terminal receipts under one
programme issue or external research ledger. Do not create a child ticket or PR
per experiment.

### Independently mergeable capability

Create a separate delivery issue only when the result is reusable tooling,
infrastructure or another independently mergeable outcome that genuinely
blocks the research programme. It gets one owner, one branch and one PR.

A reproducible implementation defect does not create a replacement issue or
PR. Continue the same delivery lane unless the outcome or architecture changes.

### Product promotion

Research evidence does not become product truth. Promote at most the selected
minimum packet into one clean current-main branch, run relevant exact-head
review and CI, merge once, verify exact main, then delete the branch.

### Live status versus durable knowledge

Use different homes deliberately:

| Information | Home |
|---|---|
| Current node, blocker, receipt and authority | Active GitHub issue |
| General operating rule that every task must follow | `AGENTS.md` or `docs/agents/ai-sdlc.md` |
| Reusable mechanism, failure pattern and examples | `docs/solutions/` |
| Literature, external evidence and scoped synthesis | `docs/research/` |
| Historical run and exact result | Immutable issue comment, PR, workflow or artefact |

Do not turn a solution note into a second live roadmap. Do not rewrite historical
receipts when the programme learns a better method.

## Rule 6 — compound stable learning while the programme is still active

Knowledge compounding should not wait for an entire multi-month programme to
finish when a reusable lesson is already stable and independently valuable.
It should also not encode a provisional guess merely because the issue is busy.

Compound when at least one of these is true:

- the same owner handoff or capability assumption has recurred;
- an escaped process defect has a general fix;
- an independently mergeable tool has established a reusable boundary;
- future tasks would otherwise replay a long issue history;
- a deterministic fixture can prevent the same regression; or
- the programme has reached a stable claim boundary even though the product
  outcome remains open.

Use a four-part compounding pass:

1. **Extract** the smallest general rule from the exact evidence.
2. **Place** the rule in the correct authority layer; do not promote task-local
   detail into the execution kernel.
3. **Enforce** only what can be checked deterministically and cheaply.
4. **Link** the reusable note to the immutable case evidence while leaving live
   state in the issue.

Do not copy the whole transcript, all hashes, every rejected hypothesis or the
current status sentence into permanent instructions. The purpose is to lower
the context and decision cost of the next occurrence.

A useful test is:

> If the active issue disappeared, would this document still tell a future
> owner what pattern to use, what it protects, and where its limits are?

If not, it is a status report rather than compounded knowledge.

## Reusable end-to-end workflow

### 1. Classify the active claim

State product, scientific, evidence-capability and delivery claims separately.
Name which one the current node may decide.

### 2. Map claim to evidence

For each material claim, identify the actual production surface, required
observable, independent observer, and unsupported mechanisms. Reject proxy
evidence that cannot falsify the claim.

### 3. Preflight capability

Measure the actual venue, permissions and target path before protocol freeze.
Stop early if the required observation is unavailable.

### 4. Freeze the finite graph

Declare nodes, identities, budgets, correction categories, automatic
transitions and terminal owner boundaries. Do not insert a person between safe
named transitions.

### 5. Separate research from delivery

Keep exploratory evidence outside production. When a reusable capability is
required, create one delivery outcome. Fix implementation defects under stable
acceptance in that lane.

### 6. Validate progressively

Run the cheapest deterministic check that answers the current question. A
coherent capability candidate receives the complete frozen matrix, exact-head
review and relevant CI. Partial passes remain diagnostic.

### 7. Promote once

After exact-main capability or scientific PASS, continue to the already named
next node. Product changes still cross one clean integration boundary and the
release authority remains unchanged.

### 8. Compound the stable lesson

Update only the appropriate active contract, deterministic fixture and solution
note. Remove duplicate prompt instructions rather than adding another SSOT.

## Checklists

### Research-graph author

- [ ] What claim layer can this node decide?
- [ ] Has the exact target evidence surface been preflighted?
- [ ] Are immutable inputs and negative evidence named?
- [ ] Are PASS/FAIL/INCONCLUSIVE distinct and bounded?
- [ ] Is any counterexample repair declared before results?
- [ ] Do safe PASS transitions continue automatically?
- [ ] Is the final human boundary genuinely non-routine?

### Capability-delivery owner

- [ ] Is this outcome independently mergeable and reusable?
- [ ] Is there one issue, branch and PR?
- [ ] Does the narrow profile preserve already qualified profiles?
- [ ] Are semantic inputs separated from identity-only dependencies?
- [ ] Do focused regressions precede hosted/full qualification runs?
- [ ] Are ordinary implementation defects repaired without moving acceptance?
- [ ] Is the delivery budget finite?
- [ ] Are exact-head review, relevant CI, exact-main verification and cleanup
      included in the same autonomous lane?

### Reviewer

- [ ] Does the evidence observe actual production behaviour rather than a
      surrogate?
- [ ] Could treatment and comparator share the same omission?
- [ ] Are hashes tied to actual use?
- [ ] Does one unchanged verifier judge valid and negative cases?
- [ ] Can a stale receipt, alternate path, cached output or child-reported time
      false-pass?
- [ ] Is a code defect being mislabeled as scientific failure—or vice versa?
- [ ] Does the claimed conclusion stay inside the executed evidence boundary?

### Human owner

- [ ] Define outcome, hard invariants and genuine authority boundaries.
- [ ] Approve a finite graph, not every routine transition.
- [ ] Demand one decision package only when the graph is exhausted.
- [ ] Do not choose implementation details that deterministic evidence can
      resolve.
- [ ] Do not infer product failure from unavailable evidence.

## Anti-patterns and corrections

| Anti-pattern | Why it fails | Correct response |
|---|---|---|
| Freeze first, discover required permissions later | The protocol may depend on a capability that does not exist | Preflight venue/tool/permission/target path before freeze |
| Ask the owner after every gate | Human becomes the workflow router | Pre-authorise the finite safe graph and terminal boundaries |
| Use one correction limit for all code defects | Normal delivery cannot converge | Separate scientific correction from finite delivery repair budget |
| Open a new issue/PR after each implementation bug | Duplicates ownership and history | Continue the same outcome, branch and PR |
| Count hashes or open intent as consumption | Shadow inputs can false-pass | Bind actual bytes or strong semantic evidence to the invocation |
| Use a synthetic diagnostic for a production-runtime claim | Tests the surrogate, not the target | Execute and observe the actual runtime path |
| Generalise a qualified narrow runner into arbitrary execution | Expands trust and proof burden without need | Add the minimum separately qualified workload profile |
| Carry partial case passes into final qualification | Cases may depend on changed code or output | Rerun the full frozen matrix from fresh output |
| Call `INCONCLUSIVE` a `NO_SURVIVOR` | Converts instrument limits into scientific findings | State exact missing evidence and excluded claims |
| Paste the issue history into prompts and permanent docs | Creates stale competing SSOTs | Point to the issue; compound only stable reusable rules |

## Case study — #421, #533 and the Godot profile boundary

This table records the reusable causal sequence, not the current execution
status. Follow the linked issues for live state.

| Stage | Decisive observation | Correct conclusion | Workflow lesson |
|---|---|---|---|
| Early topology campaigns | Candidate behaviour reduced to tags/unordered history | Scoped candidate or grammar closure | Canonicalise observable behaviour before runtime rows |
| Source-feasibility campaign | A formal survivor required a producer contradicted by actual Exhaust/Ember/Verdant Branch semantics | Source/product contradiction for that frozen law | Bind real source semantics before promotion |
| Shared projection | Treatment and comparator came from the same semantic projection | Evidence could share an omission | Internal agreement is not independent validation |
| Mutation/oracle attempts | Mutants or inputs were not proven through the actual bound validator path | Pre-execution inconclusive | Require actual application, RIPR and input-to-execution binding |
| Local attestation attempt | macOS environment lacked the required OS provenance backend | Local capability unavailable | Preflight the environment before protocol freeze |
| [#533](https://github.com/fol2/glassvow/issues/533) / [PR #534](https://github.com/fol2/glassvow/pull/534) | A narrow inert Linux profile passed a frozen valid/attack matrix on exact head and exact main | Bounded provenance capability PASS for that workload only | Build one independently mergeable capability and preserve its claim boundary |
| #533 N05 delivery defect | Replay construction tried to overwrite sealed evidence | Implementation bug under unchanged acceptance | Do not spend a scientific correction on ordinary delivery repair |
| A1-v1 preflight | Qualified inert runner could not execute or attest the actual Godot M09 path | Exact profile mismatch; no mutation result | Reuse the architecture through a new narrow workload profile, not a surrogate |
| [#535](https://github.com/fol2/glassvow/issues/535) | Live delivery applies the pattern to the actual Godot path | Outcome intentionally not recorded here | Active issue owns current state; solution note owns the method |

At the #533 handoff, exact main was
`5c5f2d325725b0a04e060c1ffe0b40a76f2e0928`. That SHA is a historical evidence
anchor, not a command to future work. Future owners resolve current main and
read the active issue before acting.

## Fit with AI-SDLC and the four operating rules

### AI-native SDLC DNA

The human defines outcome and genuine authority boundaries. One owner agent
carries each independently mergeable delivery through implementation, focused
proof, exact-head review, CI, merge, exact-main verification and cleanup. Safe
scientific transitions are encoded once rather than manually relaunched.

### Minimum wall time / maximum effectiveness

Capability preflight stops impossible experiments before expensive freeze,
implementation or simulation. Progressive checks find copy, permission and
interface defects before full hosted qualification. A narrow workload profile
avoids proving arbitrary execution.

### Minimum model-token and compute

Deterministic code owns enumeration, tracing, hashing, evidence capture,
comparison and stop/go. Model judgement is reserved for claim architecture,
product meaning and adversarial review. Prompts point to the task SSOT instead
of replaying the programme history.

### No compromise

`INCONCLUSIVE` stays distinct from scientific failure. Synthetic or shadow
evidence cannot replace actual production consumption. Delivery repair cannot
move scientific acceptance. A PASS remains exact-head/exact-main and
claim-bounded.

## Prompt boundary

When the issue is complete, the launch prompt should remain small:

```text
@GitHub <owner/repo>

Claim #<issue> and own it end-to-end under the current-main AI-SDLC.
Resolve current main and refresh active repository instructions before acting.
Treat the issue as the accepted intent and task SSOT.
Continue autonomously through its pre-authorised graph; escalate only at a
terminal result or genuine repository human-authority boundary.
```

Do not repeat the issue body, thresholds, review process, CI commands or merge
steps. Add only a genuine owner delta or exception. A longer prompt does not
make an already complete issue safer.

## Limits

- A finite graph cannot anticipate an unknown product-defining decision. It
  must still stop at the declared authority boundary.
- A capability PASS is bounded by its workload, threat model, venue and
  observation closure. Reuse requires compatibility or a separately qualified
  profile.
- Provenance does not establish semantic correctness by itself. It proves what
  executed and what evidence was consumed; the oracle and causal claim still
  require their own validation.
- A deterministic fixture can prevent a known structural regression but cannot
  replace semantic review of a changed operating contract.
- Knowledge compounding reduces future context and handoffs; it does not make
  historical negative evidence disappear or guarantee the product goal is
  feasible.

## Related

- [`docs/agents/ai-sdlc.md`](../../agents/ai-sdlc.md)
- [`docs/agents/issue-tracker.md`](../../agents/issue-tracker.md)
- [`docs/balance/p9-strategy-diversity-system.md`](../../balance/p9-strategy-diversity-system.md)
- [Formal subsystem-synthesis literature review](../../research/2026-09-02-p9-formal-subsystem-synthesis-literature-review.md)
- [Strategy-diversity literature review](../../research/2026-09-02-p9-strategy-diversity-literature-review.md)
- [Continuous-certification frontier note](../../research/2026-09-02-p9-continuous-certification-frontier-note.md)
- [Issue #421](https://github.com/fol2/glassvow/issues/421)
- [Issue #533](https://github.com/fol2/glassvow/issues/533)
- [PR #534](https://github.com/fol2/glassvow/pull/534)
- [Issue #535](https://github.com/fol2/glassvow/issues/535)
