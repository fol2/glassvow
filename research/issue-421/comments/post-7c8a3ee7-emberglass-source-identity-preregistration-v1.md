## Option 2 — Emberglass Memory source/identity preregistration

The zero-row persistent-contract grammar selected exactly
`emberglass-memory-one-carry`. Before any whole-run simulator row, this freezes
the two research knobs separately and tests that each is identity-safe.

Frozen source and provenance:

- current main: `7943e3c9360ed6920a8f4bba7a4c21d15ef4c1f1`;
- immutable archive parent: `7c8a3ee7d3f297bec0d2888a9a5d3fefa25378ce`;
- protocol: `research/issue-421/protocols/post-7c8a3ee7-emberglass-source-identity-v1.json`;
- protocol SHA-256: `b08e185903bbd0fdbf3b4cc29b065b9483e91b6e835ef6239d079537c47e4ef2`;
- runner SHA-256: `17fe491b8ad2589b57f678754893d40dff033da52b10263c71c12dc04bde6ba6`;
- direct probe SHA-256: `0bbd454216c59935a4d63cdf5666d9a88715066edeedbb07d0cd2e29aea97e96`;
- exact selected compliant binary: Godot
  `4.7.2.stable.official.ed1daf0bf`, SHA-256
  `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf`.

The complete first look is 20 frozen direct scenarios in both current-main and
candidate sources: 40 controlled scenario executions in exactly two Godot
processes. It covers omitted and explicit-off identity, wrong aspect, unowned,
missing and zero carriers, four invalid carriers, positive/zero/loss charge,
ordinary/cap-order/saturated consume, and uninterrupted versus save/resume
composition. Baseline and candidate use the same row and seed identities.

The only allowed differences are the namespaced carrier, exact candidate
events, and the realised one-Ember consume projection. The protocol forbids
normalising RNG, policy, content, save-envelope fields, neighbouring state,
cap, result or any canonical non-candidate event. `gain_embers()` is excluded
because it invokes quest tithe and would not preserve the exact carried unit.

Pre-freeze mechanical gates passed: the byte-identical probe parsed in both
sources, the candidate combat source parsed, the deterministic runner self-test
passed 4/4, the reproduction patch applies cleanly, and frozen preflight has no
fault. No scientific scenario has been run yet.

Ceilings are frozen at 40 controlled executions, two Godot processes, 45
seconds per process, 90 seconds total, zero post-freeze corrections, zero
whole-run simulator rows, zero ledger reads/writes, zero protected seeds, zero
product mutations and zero model-context tokens during execution and decision.

The decision boundary is exact:

1. all gates pass: freeze this representation only for a separately
   preregistered, non-causal fixed-policy shadow-capacity screen;
2. any complete exact gate fails: close this one-carry contract without repair
   or value substitution and continue inside #421; or
3. unavailable/incomplete at cap: record inconclusive without rerun.

This cannot establish capacity, causality, balance, product scope, #421
acceptance or the #108 P9 receipt.
