# Glassvow AI-Native SDLC

**Status:** development-process single source of truth. `AGENTS.md` is the concise execution kernel; this document owns the full operating model.

This model adapts Anthropic's [AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) to Glassvow's Godot, procedural-map, creative-production, and balance-research workload. Its objective is not less thinking or less testing. It is the highest decision quality and delivery throughput with the least irrelevant context, compute, duplicated work, human waiting, and feedback latency.

## 1. Optimisation target

A change is effective when it reaches the intended player or engineering outcome, preserves product invariants, and is supported by evidence that could genuinely falsify the claim. The cost to minimise is total lead time and waste across the whole loop: agent context, model tokens, repeated investigation, CI runner time, human review time, reruns, and escaped defects.

The governing equation is qualitative but strict:

> **smallest sufficient context + smallest decisive experiment + smallest relevant gate + one integration boundary**

“No compromise” means no material risk is left without relevant evidence. Running an unrelated green suite is not extra safety; it is noise that delays the evidence that matters. Cutting a relevant check to save time or tokens is compromise. Adding ceremony or repeated review after the decision is already supported is waste.

Use this decision test for every proposed document, agent, gate, harness, or workflow:

- **Under-engineered:** a material acceptance, compatibility, security, product, or operational risk has no evidence capable of falsifying it.
- **Over-engineered:** the activity cannot change a decision, catch a reachable defect, or remove recurring critical-path work at lower lifetime cost than it adds.
- **Right-sized:** it is the cheapest maintained mechanism that observes the material risk or removes the recurring bottleneck.

A new permanent mechanism must therefore name the decision or risk it observes, its trigger, its expected cost, and the condition for narrowing or deleting it. “More assurance” without an observable claim is not a reason.

### Autonomy target

Human judgement stays above the loop, not inside the routine critical path. A normal bounded task should run from accepted intent through implementation, risk-required independent review, relevant CI, merge, and branch cleanup without a person relaunching each stage or pressing routine approval buttons.

The owner agent continues autonomously when acceptance, authority, permissions, and evidence are clear. Human escalation is reserved for decisions the loop cannot resolve safely:

- contradictory binding authorities or acceptance criteria;
- breaking save, internal-ID, migration, or public-contract changes;
- irreversible external, legal, financial, regulated, or release authorization;
- new provider terms, credentials, or access grants;
- a product-defining subjective choice not encoded in the SSOT where materially different valid outcomes remain;
- an unavailable or inconclusive relevant gate.

Escalation asks one concise decision, includes the competing options and evidence, and does not hand routine execution back to the person. Once resolved, the same owner agent resumes the loop.

## 2. Anthropic stage and artifact chain without ceremony

Glassvow keeps the six non-linear Anthropic stages while compressing redundant handoffs:

| Anthropic stage | Glassvow operating artifact or action |
|---|---|
| Plan | direct owner instruction, issue, trigger, or incident record as accepted intent |
| Design | task capsule or durable spec when another owner, audit trail, or downstream trigger needs it |
| Build | smallest coherent diff plus tests and updated institutional knowledge |
| Test | progressive deterministic evidence and risk-required independent review |
| Deploy | ordinary PR, governed checks, merge, and rollback/release boundary where applicable |
| Maintain | event or control-band breach creates the next accepted intent and restarts the loop |

Anthropic's `intent.md` → `spec.md` → `plan.md` chain is a useful handoff pattern, not a requirement to create three files for every ticket.

A complete direct owner instruction or active issue is the intent artifact. The task capsule is the working requirements, design, and plan: goal, non-goals, active constraints, acceptance, affected surfaces, proof map, exact head, decisions, and next action.

Do not manufacture `intent.md`, `spec.md`, or `plan.md` for a bounded task whose contract already exists and whose owner remains the same. Commit a separate artifact only when at least one of these is true:

- the work crosses owners or sessions and the task capsule cannot remain authoritative;
- a programme spans several independently mergeable PRs;
- audit, release, or compliance requires a durable stage decision;
- a deterministic trigger consumes the artifact to start the next stage;
- the design is reusable institutional knowledge rather than task-local state.

An accepted artifact should trigger the next action automatically where tooling supports it. Otherwise the same agent continues immediately; it must not wait for a human to restate or relaunch the next stage.

### Triggered and proactive loops

Recurring, well-specified work should start from an event, issue label, schedule, CI failure, incident, or breached control band without a person in the invocation path. Every autonomous loop needs machine-verifiable exit criteria, bounded attempts/time/compute, least-privilege tools, and a rollback or fail-closed stop. Route mechanical classification and transformation to deterministic code or the smallest capable model; reserve the strongest model for architecture, ambiguity, and adversarial review. When a result fails, improve the governing skill, fixture, agent, or trigger instead of relying on a longer prompt next time.

## 3. Two loops with an explicit promotion boundary

### Discovery and research loop

Use this for balance or ML search, visual exploration, architecture investigation, uncertain requirements, and prototype comparisons.

Before running anything, record a compact research contract:

- question and decision to be made;
- falsifiable hypothesis or competing options;
- immutable inputs and owned output location;
- cheapest experiment that separates the options;
- budget for runs, wall time, and context;
- success, stop, and inconclusive criteria.

Preflight every required venue, tool, permission, and evidence channel before freezing a dependent protocol. Use one bounded capability ladder in declared order; record each measured rejection once, and freeze only after a venue can observe the claims the experiment will make. A capability preflight is not a scientific result and must not be relabelled as one.

Freeze the finite decision graph once: nodes, immutable inputs, budgets, correction limits, and PASS/FAIL/INCONCLUSIVE transitions. A declared transition inside that accepted graph is execution authority; continue without a new owner message. Escalate only when the finite graph and its safe capability ladder are exhausted, or a true human-authority boundary is reached.

Keep scientific-contract corrections separate from delivery implementation repairs. A scientific-contract correction changes the frozen question or acceptance; changes to immutable inputs, threat model, protocol cases, expected outcomes, or the semantic claim are in that category and follow the graph's authority rule. A delivery implementation repair changes code or focused tests only to satisfy unchanged acceptance. Fix reproducible delivery defects autonomously within the declared delivery budget; they neither consume nor renew a scientific correction limit. Stop only when the evidence invalidates the architecture or contract, the finite delivery budget is exhausted, or a genuine human-authority boundary is reached.

Run independent experiments in isolation. Reuse deterministic harnesses and immutable inputs. Do not modify production content to try a candidate, do not open a PR per run, and do not trigger product CI for pure research. An experiment may fail or remain inconclusive without becoming a delivery failure.

The output is a decision record: evidence, caveats, rejected alternatives, and the selected candidate—or an explicit stop. Raw exploration is not production truth.

### Delivery loop

Promotion begins only when a result is selected and acceptance is stable. Delivery owns production code or content, compatibility, tests, review, and merge.

One independently mergeable outcome gets one owner, one branch, and one ordinary PR. The delivery contract contains:

- intended outcome and non-goals;
- active architecture and product constraints;
- affected surfaces and likely dependency radius;
- acceptance criteria;
- proof mapped to each claim;
- concrete stop conditions.

Do not reopen research during implementation unless new evidence invalidates an assumption. When that happens, pause delivery, state the new question, and run a bounded research loop rather than mixing open-ended exploration into the PR.

### Promotion rule

Promote only the selected decision, required data, and reproducible acceptance into the delivery task. Do not carry every transcript, failed prompt, exploratory branch, or rejected candidate into implementation context.

## 4. Composable CI scopes

`tools/ci_scope.py` is the executable selection authority. It classifies the complete PR diff, permits a path to activate several scopes, emits named check decisions, and explains every selection and skip in the workflow summary.

| Scope | Typical inputs | Assurance selected |
|---|---|---|
| `agent_config` | `AGENTS.md`, `docs/agents/`, `.claude/skills/`, `.claude/agents/`, `.claude/workflows/`, `.grok/workflows/`, agent-contract checker/tests | fast active-instruction and active-automation structural regression; no Godot by default |
| `docs` | Markdown, instructions, docs, anchor/freeze tooling | document anchors and detached-reference freeze; no Godot by default |
| `balance_ml` | `tools/balance_*`, balance tests/protocols and governed balance docs | balance/ML self-tests; no Godot unless another scope also requires it |
| `provenance_evidence` | bounded execution-provenance tools, protocol and focused tests | deterministic policy/capsule fixtures; no Godot or live evidence campaign |
| `godot_code` | `.gd`, `.tscn`, `.tres`, project resources | import, changed-file parse, complete discovered Godot regression suite |
| `map_code` | map compiler, layout, routing, waylight, map tests/tools | map quality contract and shared profile probe; not the expensive asset gate |
| `map_assets` | map GLBs, textures, shaders, manifest, landing/checker tools | complete map asset/module validation and import |
| `locale_content` | locale, content, bundled fonts and locale checkers | font/locale coverage, import, and Godot regression |
| `presentation` | presentation surfaces | performance evidence and phone/pad containment in addition to core coverage |
| `release_platform` | export, signing, store, platform and release evidence | release/store/performance/containment checks |
| `dev_tools` | governed developer tooling | developer-tool contract |
| `ci_infra` | CI workflow, classifier, import/script gates | fail-closed complete PR check set |
| `conservative_core` | unknown production path | import plus complete Godot regression rather than skip-all |

Malformed or empty classifier input fails. Deleted GDScript keeps the Godot scope but is not passed to the parser. The classifier contract has focused fixtures in `tests/test_ci_scope.py`.

Changes to active instructions, skills, agents, and workflows run `tools/check_agent_contracts.py` and its focused fixtures before expensive gates. The checker protects progressive disclosure, the dedicated reviewer definition, required autonomy language, skill/agent frontmatter, active-workflow handoff rules, and known regressions. It does not claim to prove semantic quality: a material instruction or automation change still receives one independent model review. A token-consuming model eval does not run in CI by default; add one only when a documented escaped defect cannot be captured by a deterministic fixture.

Feature-branch pushes do not create standalone CI. A pull request has one scope-aware run; a newer head cancels the superseded PR run. Integrated `main` runs are not cancelled by a later push because the later diff does not subsume the earlier diff. A push to `main` classifies the exact old-main-to-new-main tree diff and reruns only the relevant checks on the integrated tree. Unknown production paths select `conservative_core`; CI-authority changes select every check. A daily scheduled run and manual dispatch execute the complete maintained gate as the cross-scope backstop, and release or milestone work invokes that full gate before shipping. This avoids replaying a long unrelated suite after every docs or isolated-tool merge without weakening reachable-risk coverage.

Special evidence workflows own only their component proof. They must not duplicate general integration work. For example, the waylight workflow parses and tests the tracer surface and captures its route states; normal CI owns repository integration. The frozen build-4 map corpus regenerates only when its capture workflow or generator inputs change, not when someone edits the evidence packet.

## 5. Agent execution protocol

### Orient

Create or refresh one task capsule:

1. goal and non-goals;
2. active constraints and authoritative sources;
3. acceptance and evidence map;
4. current branch/head, diff, and validation state;
5. decisions made and next action.

Use repository search and file manifests before opening files. Read targeted sections. Stop loading context when acceptance and affected surfaces are understood.

### Plan once

Choose the smallest complete implementation and the cheapest proof for each risk. Order checks from fast and diagnostic to slow and integrative. Identify what would make the plan wrong. Do not produce repeated plans that merely restate the ticket.

A plan is approved by the task contract and evidence map when they are unambiguous. Do not add a human plan-approval stop for routine work.

### Execute narrowly

Change only owned paths. Use deterministic scripts for mechanical transformations. Keep production and research outputs separate. Avoid speculative abstractions, opportunistic cleanup, and evidence infrastructure that acceptance does not require.

### Validate progressively

During iteration, run the narrow check that answers the current question. Do not run the complete repository gate after every edit, and do not defer all checking until the end.

For production Godot delivery, run the complete local import, full-script parse, and discovered-test gate once against the coherent final candidate before first push, plus only the affected specialist checks. Documentation and isolated balance/ML tooling run their own deterministic checks and do not inherit Godot.

### Review and integrate

Use one independent review pass when model judgement or policy is involved, or when a non-mechanical multi-file change creates interacting risks. A fully mechanical change with decisive deterministic proof does not need a ceremonial model review.

The default reviewer is `.claude/agents/ai-sdlc-reviewer.md`. Invoke it once as a non-fork, read-only, worktree-isolated subagent on the exact coherent final candidate. Give it only the task contract, base SHA, exact head SHA, active constraints, and already-produced deterministic evidence—not the author transcript, rationale, or confidence. Its distinct hypothesis is to find acceptance gaps, invariant violations, under-engineering, over-engineering, scope drift, human/token/wall-time regressions, and evidence that does not observe the claim.

The reviewer returns `APPROVE`, `REQUEST_CHANGES`, or `INCONCLUSIVE` for the exact head. Batch concrete findings, fix them together, and rerun only the checks invalidated by those fixes. A changed head that fixes a blocker receives one new reviewer verdict; another loop requires a new defect or invalidated evidence, not a generic opinion pass. Do not commission several reviewers to repeat the same hypothesis.

The writing agent fixes findings but does not approve its own PR using the author identity. When the independent AI reviewer shares the repository owner's connector identity, record its exact-head verdict as a PR `COMMENT`; do not manufacture a GitHub `APPROVE` event. The cognitive/context separation is the independent decision, while branch protection remains authoritative when it requires a surviving identity-based human approval. Unless the task explicitly says not to merge or repository policy blocks it, automation carries the ordinary PR through green checks, final-head verification, merge, and branch deletion. Human review is an escalation outcome, not the default handoff.

The PR body stays compact: outcome, key design decision, selected scopes, final-head commands or CI, visual evidence when applicable, independent reviewer verdict, and residual risk. Exact-head evidence packets are reserved for tasks or release protocols that require them.

## 6. Context and token discipline

- Root instructions contain only permanent first-day rules. Details live in skills, agents, and domain docs loaded on demand.
- Search `CONCEPTS.md`; do not read the complete glossary for an unrelated task.
- Load one relevant skill, not every installed skill. A docs change does not need the Godot contract; pure Python research does not need visual instructions.
- Batch independent reads and tool calls. Do not narrate or re-summarise information already present in the task capsule.
- Prefer a deterministic query, classifier, or checker to model-based reinspection of mechanical facts. Use the smallest capable model for bounded low-risk judgement and the strongest model only where its added reasoning changes the decision.
- Keep one source of task state. Do not maintain competing issue comments, scratch plans, and PR narratives that drift independently.
- On handoff or context compaction, transfer the capsule, exact head, diff, and failing command. Do not replay the full conversation.
- Use parallel agents only for questions with independent outputs. Never ask several agents to review the same surface without distinct hypotheses.
- Stop when evidence is decisive. More tokens after the decision boundary usually reduce clarity rather than risk.
- Record token or billable-unit usage only when the platform exposes real aggregate telemetry. Do not spend tokens estimating tokens or build a second telemetry system without a decision it will change.

## 7. Concurrency without nonlinear rework

Parallel work is safe only when all of these are true:

- tasks are independently mergeable;
- files and mutable evidence do not overlap;
- each task has one owner and branch;
- dependencies are explicit and ordered;
- no worker assumes unlanded behaviour from another branch.

Multiple machines must not share a branch or worktree. If work depends on an unmerged authority, either wait for it to land or pin the exact prerequisite commit and integrate it once. Do not let several tickets repeatedly absorb moving `main` and invalidate one another's evidence.

Research runs may parallelise over immutable inputs and separate output directories. Consolidation happens once, before promotion. The old lane table in `docs/session-ownership.md` is historical; it does not allocate current files.

## 8. Evidence design: strong, relevant, economical

Map each claim to evidence that observes the claimed property:

- pure transformation or geometry: deterministic unit or property comparison;
- parser/import integrity: the shared fail-closed checker;
- gameplay behaviour: deterministic regression test or replay;
- probabilistic/balance claim: predeclared experiment, seed policy, uncertainty, and holdout or replay;
- composition/perception: running capture and independent visual judgement;
- performance: measured budget on the governed environment;
- compatibility: migration/load fixtures and explicit version boundary;
- agent-policy change: deterministic structural contract plus one independent semantic review.

A screenshot cannot prove deterministic routing cost. A full gameplay suite cannot prove a statistical balance hypothesis. A numeric resolver test cannot prove that a composition looks commercially acceptable. A linter cannot prove that an instruction is wise. Use the right evidence once.

Tests are not edited merely to make an implementation pass. Goldens move only for deliberate behaviour changes with an explanation. If a relevant gate cannot run, stop with a blocker rather than replacing it with an unrelated check.

The existing convention [Put the gate where the change is deterministic](../solutions/conventions/put-the-gate-where-the-change-is-deterministic.md) remains binding: move proof upstream when the renderer is noisy, while retaining visual inspection for the separate composition claim. Escalate visual preference only when the governed rubric cannot discriminate materially different valid outcomes.

## 9. Scientific feedback and governance

Optimise the system from measurements, not ritual. Review these trends by scope over a meaningful sample of merged PRs:

- median and p95 wall time from accepted task to merge;
- median and p95 time to first decisive failure;
- CI runner minutes per merged PR, plus scheduled full-gate minutes amortised across merged outcomes;
- superseded/cancelled runs and reruns per PR;
- review cycles caused by scope drift versus real defects;
- escaped defects and which dependency or check should have caught them;
- research experiments per promoted decision and inconclusive rate;
- handoffs or context reloads before merge;
- human interventions and human-wait minutes per merged PR, distinguishing required escalation from avoidable routine touches;
- share of routine PRs completed end-to-end without human launch, plan approval, candidate selection, or merge action;
- aggregate model tokens or billable units per merged outcome when real telemetry is available.

A faster or cheaper selection is accepted only if escaped-defect evidence does not worsen. When a dependency is missed, run the relevant gate immediately, add or widen the path rule, and add a focused classifier fixture. When a check runs repeatedly without observing any reachable risk, narrow its trigger with the same discipline.

Do not optimise vanity token counts by omitting thinking. Reduce tokens by reducing duplicate context, open-ended loops, avoidable human handoffs, and model work that deterministic tooling can do better.

## 10. Worked examples

**A complete owner instruction or issue:** use it as intent, keep one task capsule, and continue to PR and merge without generating three duplicate planning files.

**An agent instruction, skill, reviewer, or active workflow edit:** select `agent_config` plus `docs` where applicable, run the fast contract checker and the dedicated independent reviewer once, and do not inherit Godot.

**Balance search runs outside delivery:** use immutable candidates and a bounded experiment; no branch, PR, or product CI per run.

**A balance tool or protocol is promoted under `tools/balance_*` or its tests:** `balance_ml` runs the governed research contracts without map, locale, store, containment, or Godot work.

**A map GDScript and map test change:** `godot_code`, `map_code`, and possibly `presentation`; run import, changed-file parse, the complete Godot suite, map quality, and profile probe, while skipping the nine-minute asset gate unless a map asset also changed.

**A map GLB or manifest changes:** `map_assets`; run the complete asset/module gate and import.

**The CI classifier or workflow changes:** `ci_infra`; run the complete PR check set because narrowing the mechanism while changing it would be circular.

**A README correction:** `docs`; run anchor and detached-reference checks, not Godot.
