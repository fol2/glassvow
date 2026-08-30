## Emberglass analysis-only result — scientific futility

The one authorised analysis-only correction ran the original v1 `_analyse` exactly once against the two immutable v2 probe outputs. It completed in 0.017448 seconds, returned `FUTILITY`, and reported no analysis fault.

Twelve of the 16 original v1 gates passed. Four failed:

- `omitted-off-boundary-exact`;
- `consume-ordinary-exact-unit`;
- `consume-after-cap-and-start-ember-effects`;
- `consume-saturated-cap-clears-once`.

This is a scientific futility result, not an inconclusive protocol result. The immutable baseline and candidate output hashes remained unchanged after analysis. No endpoint content was inspected outside the frozen deterministic runner.

Evidence is published at commit [`c2902d19`](https://github.com/fol2/glassvow/commit/c2902d1905f39fb39c0e9c363934feff17d8d2a7) on ref `research/issue-421-post-c69b2752-persistent-contract-evidence`:

- preregistration comment: `5470613352`;
- protocol SHA-256: `3726136358dcbc055d3cc8fd4b15666f3f4e0a25326c65a2ace76255ac212c0b`;
- deterministic summary SHA-256: `7517a39c0b6d6f77fae5f036f4b2ba484a3feef1725f64ef4ad947e76cf63aa9`;
- execution audit SHA-256: `1075993d5fcfc0860e28da9134db82f1526d670d9283ef6521f989cd53902301`;
- reused direct controlled executions: `40`;
- new analysis executions: `1`;
- new Godot processes, rows, seed identities, candidates, grammar changes, simulator rows, ledger reads/writes, protected-seed rows, product mutations, identity-gate repairs and reruns: all `0`.

### Frozen disposition

The exact preregistered Emberglass one-carry source/identity contract is closed without repair or rerun. Source identity is not established. The success-only fixed-policy non-causal shadow-capacity screen is not unlocked because the frozen success rule required all 16 gates to pass.

Ash prohibited options B and C. This result therefore unlocks no eligible autonomous #421 gate under the current authority. Any continuation would widen scope and must fail closed back to Ash; no replacement mechanism or successor is inferred here.

### Safe state

Product `main` and the development worktree remain unchanged. #421 remains open and unaccepted; #108 P9 has no receipt. No product branch, PR, Actions run, protected seed, optimiser, candidate substitution or grammar widening exists. Keep #421 at `needs-info` pending a new explicit Ash authority delta or a decision to leave this scientific closure in force.
