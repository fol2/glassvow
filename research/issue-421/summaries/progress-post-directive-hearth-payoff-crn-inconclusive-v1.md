# Issue #421 progress — Hearth payoff CRN boundary-3 evidence

Date: 2026-08-28
Purpose: remote-review-only scientific evidence; do not merge into product `main`

## Outcome

The selected Hearth payoff by acquisition-priority direction is **inconclusive at its preregistered cap**. This is not a negative payoff result and no candidate was selected.

The exact 2×2 common-random-number design reused the frozen 256-row current-payoff/priority-off anchor and executed the three preregistered new cells once: disabled/off, current/on and disabled/on. All 768 new observations completed in 26.89 seconds with no ledger change, protected seed, model, optimiser, ML, RL, joint Scoreline cell or joint Afterimage cell.

Analysis stopped before fitting because one row violated the frozen observation contract:

- cell: `H1Q1`;
- policy: `34`;
- seed: `346598`;
- fight: `19`;
- fight result: `win`;
- Crown of the Hearth owned: `true`;
- terminal Ember: `1`;
- queue-derived Crown proc: `false`.

The deterministic zero-row audit found no other schema fault across the four 256-row cells. The cached row does not contain the per-fight queue or HP transition needed to distinguish Crown branch execution from observation loss. Consequently the preregistered causal fit is unavailable, and the evidence cannot be repaired or reinterpreted post hoc.

## Frozen design

- Hearth payoff and acquisition priority were the only varied factors.
- Scoreline payoff and Afterimage payoff remained separate fixed factors.
- Faultline rarity and Ward setup priority remained fixed.
- The matrix was full rank for intercept, Hearth payoff, acquisition priority and their interaction.
- The same 64 policy identities, four simulation seed identities, baseline, capture, estimator, first look and stopping rule governed every contrast.
- Scoreline and Afterimage had separate route-stratum interference checks. No Cartesian completion or optional joint cell was authorised.
- Numeric cap: 768 new observations, three Godot processes, 300 seconds, zero ledger rows, zero protected seeds and zero model-context tokens during execution and decision.

Protocol SHA-256: `cb9d158f40efae0ff9b390e67222c8c1a3c8085efffabf52e2eafe11e31ca876`.

## Identity evidence before the causal rows

The observability/payoff source audit added no simulator row and selected only:

1. the existing capture-gated post-fight harvest location, with `fight`, `owned`, `terminalEmbers` and queue-derived `proc`; and
2. a three-versus-zero integer input at the existing Crown heal call.

The payoff/telemetry identity preflight then passed:

- 18/18 direct controls;
- 768/768 whole-run identity observations;
- zero omitted-versus-explicit-three mismatches;
- zero capture-off/core, capture-on/core, RNG, policy or prior-trajectory mismatches;
- zero schema faults on the priority-off identity cohort;
- zero disabled whole-run observations.

The exact identity source is retained as a content-addressed archive. Its null proof remains valid in its tested priority-off scope; the later priority-on row exposes a previously unobserved limitation of the four-field proc observation contract.

## Decision and authority boundary

The blocked experiment applied decision boundary 3 exactly:

`record-hearth-blocked-crn-inconclusive-at-cap`

The zero-row audit applied:

`confirm-hearth-crn-inconclusive-observation-contract-stop`

No causal endpoint was fitted, no cached `proc` value was recoded, and no success or futility decision was inferred. The experiment protocol forbids repair, repeat, cohort replacement, a joint rescue cell, an additional method or protected seeds.

Issue #421 lists an inconclusive relevant gate as a human-authority condition. The safe state is therefore:

- retain boundary 3;
- publish the immutable artefacts on the existing archive-only review ref;
- do not move this package to held-out confirmation;
- do not close the scalar family as futility or start a replacement experiment without the resulting authority decision;
- keep product `main`, product PRs, Actions and protected seeds untouched.

## Reproduction identity

- source commit: `c4130163c7fb8edd865c0adc95732aae03e1bad2`;
- exact Godot: `4.7.1.stable.official.a13da4feb`;
- Godot binary SHA-256: `ecc8da2d60100102cfca6e833d3860d7436b46ae062fa072ce89a6c95d664a3f`;
- baseline content SHA-256: `a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1`;
- experiment summary SHA-256: `cd11f2ea729cb4d02ded6911365337c269ee767c4a2ee943dac966599da5dddb`;
- zero-row audit summary SHA-256: `306ca21ca1144437482cfbec794494db79205905533de408136670461d591731`;
- raw 18-object archive SHA-256: `d4d3f60b5ca0c8da66ed0467382cfe5a9950aa65b7d5aa8df93189ca90a6722b`;
- exact causal-source archive SHA-256: `18f756f9b63ba348a13582b6f0b30c7b76e3339cf396a1254e94fadc629621a6`;
- ledger: 480,372 records, SHA-256 `4563f536f6a57e97ac7a5b51129f3967806e5bd445088547f0c874b1cd77b2e0`, SQLite integrity `ok`, protected rows `0`.

## Remote heads before publication

- `origin/main`: `c4130163c7fb8edd865c0adc95732aae03e1bad2`;
- `origin/research/issue-421-p9-recovery-evidence`: `d1e8c390b3be0b9b74d482cbc0f9a3d2f22f6caa`;
- `origin/research/issue-524-causal-slate-evidence`: `f305b95d9e1d173e5d8150289afab9688c0ea7f0`;
- `origin/research/issue-525-mechanism-package-synthesis-evidence`: `7132e5e0d6e6e6dc196dda3ed90ad2be292608d6`;
- `origin/work/421-h34`: `4a94d155400162289a84f416336ff407f55b3cf6`;
- `origin/work/421-landscape-retune`: `ad4b99b1538d7200e9b228051a029e554e9b9912`;
- `origin/work/421-s009-exam`: `b30b290813d88109c5b9bc34354babefdc406f8d`.

## Publication boundary

This packet updates only `research/issue-421-p9-recovery-evidence`. It creates no PR, runs no GitHub Actions, changes no product branch, consumes no protected seed and does not reconstruct or extend issues #524 or #525.
