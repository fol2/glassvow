# Glassvow AI-Native SDLC

**Status:** development-process single source of truth. `AGENTS.md` is the concise execution kernel; this document owns the full operating model.

This model adapts the principles in Anthropic's [AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) to Glassvow's Godot, procedural-map, and balance-research workload. Its objective is not less testing. It is the highest decision quality and delivery throughput with the least irrelevant context, compute, duplicated work, and feedback latency.

## 1. Optimisation target

A change is effective when it reaches the intended player or engineering outcome, preserves product invariants, and is supported by evidence that could genuinely falsify the claim. The cost to minimise is total lead time and waste across the whole loop: agent context, repeated investigation, CI runner time, human review time, reruns, and escaped defects.

The governing equation is qualitative but strict:

> **smallest sufficient context + smallest decisive experiment + smallest relevant gate + one integration boundary**

“No compromise” means no material risk is left without relevant evidence. Running an unrelated green suite is not extra safety; it is noise that delays the evidence that matters.

## 2. Two loops with an explicit promotion boundary

### Discovery and research loop

Use this for balance or ML search, visual exploration, architecture investigation, uncertain requirements, and prototype comparisons.

Before running anything, record a compact research contract:

- question and decision to be made;
- falsifiable hypothesis or competing options;
- immutable inputs and owned output location;
- cheapest experiment that separates the options;
- budget for runs, wall time, and context;
- success, stop, and inconclusive criteria.

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

## 3. Composable CI scopes

`tools/ci_scope.py` is the executable selection authority. It classifies the complete PR diff, permits a path to activate several scopes, emits named check decisions, and explains every selection and skip in the workflow summary.

| Scope | Typical inputs | Assurance selected |
|---|---|---|
| `docs` | Markdown, instructions, docs, anchor/freeze tooling | document anchors and detached-reference freeze; no Godot by default |
| `balance_ml` | `tools/balance_*`, balance tests/protocols and governed balance docs | balance/ML self-tests; no Godot unless another scope also requires it |
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

Feature-branch pushes do not create standalone CI. A pull request has one scope-aware run; a newer head cancels the superseded run. Pushes to `main` and manual dispatches run every maintained check, so expensive whole-repository assurance happens once at the integration boundary rather than after every exploratory or corrective edit.

Special evidence workflows own only their component proof. They must not duplicate general integration work. For example, the waylight workflow parses and tests the tracer surface and captures its route states; normal CI owns repository integration. The frozen build-4 map corpus regenerates only when its capture workflow or generator inputs change, not when someone edits the evidence packet.

## 4. Agent execution protocol

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

### Execute narrowly

Change only owned paths. Use deterministic scripts for mechanical transformations. Keep production and research outputs separate. Avoid speculative abstractions, opportunistic cleanup, and evidence infrastructure that acceptance does not require.

### Validate progressively

During iteration, run the narrow check that answers the current question. Do not run the complete repository gate after every edit, and do not defer all checking until the end.

For production Godot delivery, run the complete local import, full-script parse, and discovered-test gate once against the coherent final candidate before first push, plus only the affected specialist checks. Documentation and isolated balance/ML tooling run their own deterministic checks and do not inherit Godot.

### Review and integrate

Review the final diff against acceptance, invariants, and unintended scope—not against stylistic preference alone. Batch concrete findings, fix them together, and rerun only the checks invalidated by those fixes. Another review loop requires a new defect or new evidence, not a generic opinion pass.

The PR body stays compact: outcome, key design decision, selected scopes, final-head commands or CI, visual evidence when applicable, and residual risk. Exact-head evidence packets are reserved for tasks or release protocols that require them.

## 5. Context and token discipline

- Root instructions contain only permanent first-day rules. Details live in skills and domain docs loaded on demand.
- Search `CONCEPTS.md`; do not read the complete glossary for an unrelated task.
- Load one relevant skill, not every installed skill. A docs change does not need the Godot contract; pure Python research does not need visual instructions.
- Batch independent reads and tool calls. Do not narrate or re-summarise information already present in the task capsule.
- Prefer a deterministic query, classifier, or checker to model-based reinspection of mechanical facts.
- Keep one source of task state. Do not maintain competing issue comments, scratch plans, and PR narratives that drift independently.
- On handoff or context compaction, transfer the capsule, exact head, diff, and failing command. Do not replay the full conversation.
- Use parallel agents only for questions with independent outputs. Never ask several agents to review the same surface without distinct hypotheses.
- Stop when evidence is decisive. More tokens after the decision boundary usually reduce clarity rather than risk.

## 6. Concurrency without nonlinear rework

Parallel work is safe only when all of these are true:

- tasks are independently mergeable;
- files and mutable evidence do not overlap;
- each task has one owner and branch;
- dependencies are explicit and ordered;
- no worker assumes unlanded behaviour from another branch.

Multiple machines must not share a branch or worktree. If work depends on an unmerged authority, either wait for it to land or pin the exact prerequisite commit and integrate it once. Do not let several tickets repeatedly absorb moving `main` and invalidate one another's evidence.

Research runs may parallelise over immutable inputs and separate output directories. Consolidation happens once, before promotion. The old lane table in `docs/session-ownership.md` is historical; it does not allocate current files.

## 7. Evidence design: strong, relevant, economical

Map each claim to evidence that observes the claimed property:

- pure transformation or geometry: deterministic unit or property comparison;
- parser/import integrity: the shared fail-closed checker;
- gameplay behaviour: deterministic regression test or replay;
- probabilistic/balance claim: predeclared experiment, seed policy, uncertainty, and holdout or replay;
- composition/perception: running capture and human visual decision;
- performance: measured budget on the governed environment;
- compatibility: migration/load fixtures and explicit version boundary.

A screenshot cannot prove deterministic routing cost. A full gameplay suite cannot prove a statistical balance hypothesis. A numeric resolver test cannot prove that a composition looks commercially acceptable. Use the right evidence once.

Tests are not edited merely to make an implementation pass. Goldens move only for deliberate behaviour changes with an explanation. If a relevant gate cannot run, stop with a blocker rather than replacing it with an unrelated check.

The existing convention [Put the gate where the change is deterministic](../solutions/conventions/put-the-gate-where-the-change-is-deterministic.md) remains binding: move proof upstream when the renderer is noisy, while retaining visual inspection for the separate composition claim.

## 8. Scientific feedback and governance

Optimise the system from measurements, not ritual. Review these trends by scope over a meaningful sample of merged PRs:

- median and p95 time to first decisive failure;
- CI runner minutes per merged PR and proportion spent in the full integration gate;
- superseded/cancelled runs and reruns per PR;
- review cycles caused by scope drift versus real defects;
- escaped defects and which dependency or check should have caught them;
- research experiments per promoted decision and inconclusive rate;
- handoffs or context reloads before merge.

A faster selection is accepted only if escaped-defect evidence does not worsen. When a dependency is missed, run the relevant gate immediately, add or widen the path rule, and add a focused classifier fixture. When a check runs repeatedly without observing any reachable risk, narrow its trigger with the same discipline.

Do not optimise vanity token counts by omitting thinking. Reduce tokens by reducing duplicate context, open-ended loops, and model work that deterministic tooling can do better.

## 9. Worked examples

**Balance search runs outside delivery:** use immutable candidates and a bounded experiment; no branch, PR, or product CI per run.

**A balance tool or protocol is promoted under `tools/balance_*` or its tests:** `balance_ml` runs the governed research contracts without map, locale, store, containment, or Godot work.

**A map GDScript and map test change:** `godot_code`, `map_code`, and possibly `presentation`; run import, changed-file parse, the complete Godot suite, map quality, and profile probe, while skipping the nine-minute asset gate unless a map asset also changed.

**A map GLB or manifest changes:** `map_assets`; run the complete asset/module gate and import.

**The CI classifier or workflow changes:** `ci_infra`; run the complete PR check set because narrowing the mechanism while changing it would be circular.

**A README correction:** `docs`; run anchor and detached-reference checks, not Godot.
