# Glassvow Agent Contract

Glassvow (琉璃誓言) is a Godot 4.7.2+ roguelite deckbuilder. Since 2026-08-16 it is detached from the former web implementation: this repository owns its behaviour, content, and port-owned regression goldens. The commercial rubric, not historical web parity, is the product standard.

This file is the small execution kernel. Load deeper material only when the task needs it. `docs/agents/ai-sdlc.md` is the development-process single source of truth.

## Authority and historical records

Use this precedence for current work:

1. the user's instruction or active issue acceptance and non-goals;
2. active product invariants, ADRs, and compatibility contracts for the affected surface;
3. this file and the one relevant domain skill;
4. `docs/agents/ai-sdlc.md` and the executable CI selection in `tools/ci_scope.py`.

Old status pages, review packets, evidence folders, handoffs, and `docs/session-ownership.md` may truthfully record commands, ownership, gates, or reference assumptions that applied at the time. They are historical evidence, not current default instructions, unless the active task explicitly binds that protocol. Preserve them instead of rewriting history.

## Start with the smallest sufficient context

1. Treat the user's instruction or the active GitHub issue as the task contract. A complete direct owner instruction does not need a mirror issue.
2. Inspect the owned or changed surface and search before opening long documents. Read only matching sections of `CONCEPTS.md`, ADRs, solution notes, and skills.
3. Load `.claude/skills/glassvow-godot/SKILL.md` only for Godot runtime, test, scene, resource, import, or visual work. Load the story, Suno, or ElevenLabs skill only when that domain is actually in scope.
4. Keep one task capsule: goal, non-goals, active constraints, acceptance, decisions, current head/diff/evidence, and next action.

Do not preload the repository, repeat settled context, or commission overlapping agents to rediscover the same facts.

## AI-SDLC operating rule

Maximise decision quality and delivery speed while minimising context, compute, and feedback latency. “No compromise” means every material claim receives the cheapest decisive evidence that can falsify it; it does not mean running every unrelated check.

- **Discovery and research:** state the question, hypothesis or competing options, immutable inputs, cheapest discriminating experiment, budget, success/stop rule, and decision. Keep experiments out of production truth. Do not create a ticket, branch, PR, or CI run for every trial. Promote only a selected result into delivery.
- **Delivery:** one owner, one independently mergeable outcome, one branch, one ordinary PR. Plan acceptance, affected surfaces, and proof once; implement the smallest complete change; batch review findings; avoid unrelated cleanup.
- **Concurrency:** parallelise only independent work with separate branches and no shared mutable files or evidence. Never have multiple agents or machines mutate the same branch or worktree.
- **Context:** on handoff or compaction, transfer the task capsule and exact failing command—not the full transcript.
- **Automation:** use deterministic scripts for discovery, classification, mechanical checks, and evidence capture. Use model judgement for design, trade-offs, and review.

## Autonomy by default

Human escalation is the exception, not a routine stage. When the owner instruction or active issue is complete and permissions allow, the owner agent continues end-to-end: orient, plan, implement, validate, perform the risk-required independent review, batch-fix findings, open or update the PR, observe the relevant gates, merge, and delete the branch. A fully mechanical change with decisive deterministic proof does not spend tokens on a ceremonial model review. Stop before merge only when the task explicitly says so or repository policy blocks it.

Do not ask a person to approve a routine plan, choose among materially equivalent candidates, reconfirm settled acceptance, repeat a green gate, or press the merge button. Escalate one concise decision only when decisive evidence cannot resolve a contradiction in binding authority, a breaking compatibility change, an irreversible external or regulated action, provider terms or credentials, a genuinely product-defining subjective choice absent from the SSOT, or an unavailable/inconclusive relevant gate.

For semantic or policy changes, and for non-mechanical multi-file changes with interacting risks, delegate exactly one final-candidate review to `.claude/agents/ai-sdlc-reviewer.md`. Use it as a non-fork reviewer and provide only the task contract, base SHA, exact head SHA, active constraints, and already-produced deterministic evidence—not the author transcript or rationale. Record its exact-head verdict in the PR. If it returns `REQUEST_CHANGES`, batch-fix and review the new head once; if it returns `INCONCLUSIVE`, stop with the named missing evidence. The writing agent never uses the author identity to approve its own PR.

Active agent-instruction changes must pass `tools/check_agent_contracts.py`. It is a fast structural regression gate, not a substitute for the independent semantic review required when model judgement changed the operating contract.

## Validation and evidence

`tools/ci_scope.py` is the executable selection authority. It classifies the complete PR diff, permits overlapping scopes, fails closed on malformed or unknown production input, and records every selected and skipped check with its reason.

- Research and issue-comment work has no branch, PR, or CI run.
- During implementation, run the narrow deterministic check that answers the current question.
- For a production Godot delivery, run the complete local core gate once on the coherent final candidate before the first push:

  ```bash
  godot --version
  tools/check_imports.sh
  tools/check_scripts.sh
  godot --headless -s res://tests/run_all.gd
  ```

  Add only the specialist checks required by the changed surface. Stage every new `.gd` file first because the full script sweep deliberately uses `git ls-files`.
- Documentation-only and isolated balance/ML-tool changes do not inherit the Godot gate. Run their matching deterministic checks or self-tests.
- Feature-branch pushes do not start a duplicate CI run. A PR update starts one scope-aware run and cancels its superseded run. A push to `main` reclassifies the exact introduced tree diff and reruns only relevant checks on the integrated tree; unknown or CI-authority inputs fail closed. Scheduled and manual runs execute the complete maintained integration gate.
- Component evidence workflows prove only their component contract and capture. They must not replay unrelated repository suites already owned by normal CI.

Never grade `godot --check-only` by exit status; it can report parse failures on stderr while exiting zero. Use `tools/check_scripts.sh`. Do not substitute an unrelated green gate, weaken a test, or edit a golden merely to pass.

Presentation, animation, VFX, shader, camera, and composition changes require visual inspection at the affected reference shapes. Audio content or routing changes require actual playback or audition on an approved audio-capable evidence surface; waveform, spectrogram, metadata, and codec checks prove only technical properties. Put deterministic gates upstream of noisy rendering or playback, but never use numeric proof as an excuse not to inspect or audition the running result.

Exact-head artifact packets are required only when the task, release protocol, or external evidence contract requires them. Ordinary changes need truthful final-head commands and results, not ceremonial evidence bundles.

## Product invariants

- No new citations into the detached web repository. Historical citations remain frozen; `tools/check_benchmark_freeze.py` enforces the boundary.
- Measure running behaviour when the claim is visual or temporal; source presence alone is not proof that something renders.
- `domain/` stays pure game logic. Commands enter through `GlassvowGame.apply`; presentation consumes events and never owns game truth. No global EventBus or manager singleton.
- Internal IDs, seeded randomness, the v2 save lineage, and load validation remain stable. A breaking save change requires a new version and migration design.
- `port_fixtures/` are port-owned goldens. A deliberate behaviour change may update them in an explicit commit explaining why; never silently regenerate them.
- Never expose secrets. Sentry access remains Glassvow-bound as documented in `docs/release-signing.md`.

## Stop conditions

Stop and surface a concrete blocker instead of weakening acceptance when work requires a breaking save-schema or internal-ID change, native platform plugin integration, more than 600 additions plus deletions in one code file in one commit, an unavailable relevant gate, or a contradiction with an active architecture or product contract.

## Progressive-disclosure map

- AI-SDLC, research promotion, CI scopes, autonomy, evidence, and metrics: `docs/agents/ai-sdlc.md`
- Independent semantic review: `.claude/agents/ai-sdlc-reviewer.md`
- Godot engine, architecture, saves, editing, and visual proof: `.claude/skills/glassvow-godot/SKILL.md`
- Domain vocabulary lookup: `docs/agents/domain.md`
- Issue ownership and research/delivery tracking: `docs/agents/issue-tracker.md`
- Commercial invariants: `docs/commercial-game-delivery.md`, `docs/commercial-rubric.md`, `docs/rc-bar.md`
- Existing solved conventions: `docs/solutions/`
- Tools and capture methods: `docs/dev-tools.md`
- Reference detachment history: `docs/benchmark-divergence.md`, issue #317
- Art, music, and SFX authority: `docs/art-ledger.md`, `docs/music-ledger.md`, `docs/sfx-ledger.md`
