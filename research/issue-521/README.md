# Issue #521 research evidence archive

> Archive-only branch. Do not merge or apply this directory as a product change.

This directory publishes the reviewable evidence from issue
[#521](https://github.com/fol2/glassvow/issues/521), which returned one bounded
negative to [#421](https://github.com/fol2/glassvow/issues/421). The branch is a
remote evidence carrier only: it contains no applied runtime or content change,
has no pull request, and is not intended to enter `main`.

## Outcome

The preregistered cheap native-mechanism gate stopped the campaign before detector
admission:

- selective RandomBuild regression was `0.000`, against a required delta of at
  most `-0.150`;
- single-route and multi-route mean viable-policy counts were both `6.75`, so the
  required separation was `0.00` rather than at least `1.00`;
- single-route and multi-route exposure produced `99` and `11` 30-turn stalls,
  against zero for identity control.

The complete seven-direction suite, adaptive QD/BO, beam/MCTS/RL, acceptance
seeds and reserve seeds therefore received zero rows.

## Reading order

1. [`summaries/campaign-close-report-v1.md`](summaries/campaign-close-report-v1.md)
   — concise campaign report.
2. [`artifacts/bounded-negative-final-v1.json`](artifacts/bounded-negative-final-v1.json)
   — the one promoted result.
3. [`artifacts/post-stop-audit-v1.json`](artifacts/post-stop-audit-v1.json)
   — identifies the readouts quarantined from the final finding.
4. [`protocols/stage-c-cheap-gate-v1.json`](protocols/stage-c-cheap-gate-v1.json)
   and [`artifacts/native-candidate-freeze-v1.json`](artifacts/native-candidate-freeze-v1.json)
   — preregistration and exact candidate identities.
5. [`immutable-manifest-v1.json`](immutable-manifest-v1.json) and
   [`publication-manifest-v1.json`](publication-manifest-v1.json) — campaign and
   remote-publication integrity maps.

`artifacts/cheap-gate-result-v1.json` is retained as the raw automatic decision.
Its full-catalogue identity comparison and aspect event proxy are confounded;
review it only alongside the post-stop audit and final bounded finding.

## Prototype and candidates

The eventual runtime semantics were prototyped only in a detached research copy.
[`artifacts/research-runtime-prototype-v1.patch`](artifacts/research-runtime-prototype-v1.patch)
records that diff without applying it on this branch. The deterministic campaign
program, focused Godot check and all five simulated content files are available
under `tools/` and `candidates/`.

## Raw evidence

[`raw/raw-evidence-v1.tar.gz`](raw/raw-evidence-v1.tar.gz) contains the checkpointed
SQLite ledger and all six content-addressed simulation objects, preserving their
original relative paths:

```text
ledger/experiments-v1.sqlite
cache/sha256/*
```

- archive SHA-256: `d8f1eafd159d17cf63baff24391e89fbaa5c2655a8d646915cf950d3bc85b49e`
- ledger SHA-256: `ac75cb864b5dee88c3dc4292fde2bebfc34cf0bce6e5dd26413aaba1739aab75`
- SQLite integrity: `ok`
- simulator rows: `6,912`
- permanently excluded #519 identities: `504`; simulator intersection: `0`

## Primary identities

- source and branch base: `0f005282e8881d970da284f4868caedf60cc8142`
- Godot: `4.7.2.stable.official.ed1daf0bf`
- final output SHA-256: `ae29ebbf8f6a9c3660e0b47e00d2e107ca657345318c14103762c0299b20837d`
- campaign manifest SHA-256: `eb188e0305eb0ec2cc09a0806bb5dc4262648c04969a39abab86a8b5917fa709`

The result remains bounded to the frozen #520 conditioning, the
`keyed-exponential-race-v1` sampler, the v3 policy cohort, four aspect-by-vow
grids and research seeds 20300–20315. It is not evidence that native weighted
exposure or autonomous balance is generally impossible.
