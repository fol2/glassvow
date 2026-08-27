# Issue #524 research evidence archive

> Archive-only branch. Do not merge or apply this directory as a product change.

This directory publishes the reviewable evidence from issue
[#524](https://github.com/fol2/glassvow/issues/524), which returned one bounded
scope-insufficiency finding to [#421](https://github.com/fol2/glassvow/issues/421).
The branch is a remote evidence carrier only: it has no pull request, contains
no applied runtime or content change, and is not intended to enter `main`.

## Outcome

Verdict: `SCOPE_INSUFFICIENT_AT_CAUSAL_MECHANISM_PACKAGE_GATE`.

The preregistered Stage-B gate admitted only the Ashwarden
`hand-size-payoff` package. The required minimum was three packages overall,
with two for Duskblade and two for Ashwarden; observed counts were 1/3 overall,
0/2 for Duskblade and 1/2 for Ashwarden. The campaign therefore stopped before
full-run mutation construction, detector calibration or contextual slate work.

## Reading order

1. [`summaries/campaign-close-v1.md`](summaries/campaign-close-v1.md) — concise
   campaign report and scope boundary.
2. [`artifacts/scope-insufficiency-finding-v1.json`](artifacts/scope-insufficiency-finding-v1.json)
   — the one promoted result.
3. [`artifacts/stage-a-mediation-audit-v1.json`](artifacts/stage-a-mediation-audit-v1.json)
   — planned-versus-RandomBuild mediation and failed legacy labels.
4. [`artifacts/authored-mechanism-graph-v1.json`](artifacts/authored-mechanism-graph-v1.json)
   and [`artifacts/stage-b-mechanism-package-gate-v1.json`](artifacts/stage-b-mechanism-package-gate-v1.json)
   — authored graph, controlled probes, micro-deck contrasts and short-panel gate.
5. [`protocols/preregistration-v1.json`](protocols/preregistration-v1.json),
   [`immutable-manifest-v1.json`](immutable-manifest-v1.json) and
   [`publication-manifest-v1.json`](publication-manifest-v1.json) — frozen method
   and integrity maps.

The six exact Stage-B plans and outputs are under `work/`. The deterministic
campaign program and focused Godot probe are under `tools/`.

## Detached research mechanism

[`artifacts/research-runtime-and-mediation-v1.patch`](artifacts/research-runtime-and-mediation-v1.patch)
records the detached RewardRules and ContentDB research mechanism. It is evidence
only and is not applied on this branch.

## Raw evidence

[`raw/raw-evidence-v1.tar.gz`](raw/raw-evidence-v1.tar.gz) contains the immutable
SQLite ledger and all eight content-addressed cache objects, preserving their
original relative paths:

```text
ledger/experiments-v1.sqlite
cache/sha256/*
```

- archive SHA-256: `f9aabdd36756bc59179946d21cec1a76c5a733d738999121d621826efee53986`
- ledger SHA-256: `e021028a92cf42be968abdd048605509398d64fb3be63a94561e0518c6ce34b2`
- SQLite integrity: `ok`
- unique ledger rows: `7,040`; duplicates: `0`
- permanently excluded #519 identities: `504`
- quarantined #521 readouts used in confirmatory inference: `0`

## Primary identities

- source and branch base: `0f005282e8881d970da284f4868caedf60cc8142`
- Godot: `4.7.2.stable.official.ed1daf0bf`
- final finding SHA-256: `acecbae3171e739aeae4fe71dde2d0635ce98c453c58400de9bde627b2368fa2`
- campaign manifest SHA-256: `f486ae4550cc06ceb96341eb78f2a53281bcea100bb493082d0e39243c515ebb`

This negative is bounded to the frozen mediation graph, ten tested package
families, controlled and micro-deck interventions, paired short-panel contexts,
grouped-ridge and ExtraTrees sign checks, legacy real-economy profile and
recorded budgets. It says nothing about untested mechanisms, mutations,
detectors or slate families.
