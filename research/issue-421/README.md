# Issue #421 P9 recovery evidence snapshot

> Archive-only evidence branch. Do not merge or apply this directory as a
> product change.

This directory publishes the reviewable evidence from the active scientific
issue [#421](https://github.com/fol2/glassvow/issues/421) campaign at the V38
freeze. It is a progress snapshot, not a terminal finding, detector admission,
product candidate or P9 receipt. The branch is a remote evidence carrier only:
it has no pull request, triggers no product CI and is not intended to enter
`main`.

## Current decision

V38 is rejected and frozen. Its complete discovery controls found 0.125
Duskblade Vow-0 RandomBuild movement against the 0.10 limit and one
candidate-added stall.

The post-V38 audit used zero new simulator rows. None of the V33-V38 one-lever
pairs shared policies and simulation seeds, so none identifies a between-level
causal effect. Exact path invariance establishes only that acquisition priority
and rarity have zero effect on fixed-deck local combat. It does not identify
their whole-run effects.

The result is therefore `inconclusive`: V33-V38 are combination-level bounded
negatives and cannot select another candidate. No V39 candidate exists. The
next experiment must be one preregistered common-random-number identification
design; causal factorial analysis, ML or RL must earn rows by measured decision
value rather than adaptive hand-tuning.

## Reading order

1. [`summaries/progress-v38-identification-v1.md`](summaries/progress-v38-identification-v1.md)
   — concise progress, scope and current scientific decision.
2. [`summaries/post-v38-identification-v1.json`](summaries/post-v38-identification-v1.json)
   and [`protocols/post-v38-identification-v1.json`](protocols/post-v38-identification-v1.json)
   — zero-new-row identifiability result and preregistration.
3. [`summaries/combined-finalist-v38-scoreline-rarity.json`](summaries/combined-finalist-v38-scoreline-rarity.json)
   and [`protocols/combined-finalist-v38-scoreline-rarity.json`](protocols/combined-finalist-v38-scoreline-rarity.json)
   — the frozen V38 rejection.
4. [`task-capsule.json`](task-capsule.json) — current outcome, invariants,
   authoritative priors, decisions and next action.
5. [`artifacts/ledger-freeze-v38.json`](artifacts/ledger-freeze-v38.json) —
   append-only ledger identity, record counts and protected-seed proof.

All earlier protocols and summaries from this campaign are retained in their
respective directories. The deterministic research programs are under `tools/`.

## Detached prototype

`prototype/` records the exact V38 detached content, combat, pilot, simulator
and probe files. These copies are research evidence only. They are not applied
to the archive branch's product paths and have not crossed the promotion
boundary.

## Evidence cache and ledger

`raw/cache/sha256/` contains all 212 content-addressed cache objects referenced
by the published protocols, summaries and task capsule, totalling 7,212,968
bytes before Git compression.

The append-only SQLite ledger is 2.0 GB and is deliberately not copied into Git
history. It remains immutable at
`/Users/jamesto/Research/glassvow-p9-421/ledger/research.sqlite` with:

- SHA-256 `78651f5d2b51b5f11bd4466500542643083e3def1c56a705463d3b323adcd493`;
- SQLite integrity `ok`;
- 412,502 unique records, sequence 1 through 412,502;
- zero observations in acceptance seeds 3000-5199 or reserve seeds 5200-5399.

The omission prevents a 2.0 GB raw research database from becoming permanent
product-repository baggage. The ledger freeze, all decision outputs and every
referenced compact cache object remain remotely reviewable.

## Frozen identities

- source and archive base: `c4130163c7fb8edd865c0adc95732aae03e1bad2`
- live content SHA-256: `a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1`
- V38 research content SHA-256: `e475482c76a405814dba4638860bb799f610a220fcde5d931c78d1a447e18f48`
- research runner SHA-256: `0480163456dc6693e90d5f87163918d8452e4dd5c2c822c60543ab03efe3d6a9`
- post-V38 protocol SHA-256: `5a4fdfd9c24331430d08b239fd4c62edb884c16728e6e09afe15909b137eb3c1`
- post-V38 result SHA-256: `7541976e28e1bfb70f422b109cc4e965e1961883ad5eb42ce93af8554afe9c63`
- Godot: `4.7.2.stable.official.ed1daf0bf`

## Remote heads at publication preparation

- `origin/main`: `c4130163c7fb8edd865c0adc95732aae03e1bad2`
- `research/issue-524-causal-slate-evidence`: `f305b95d9e1d173e5d8150289afab9688c0ea7f0`
- `research/issue-525-mechanism-package-synthesis-evidence`: `7132e5e0d6e6e6dc196dda3ed90ad2be292608d6`
- `work/421-h34`: `4a94d155400162289a84f416336ff407f55b3cf6`
- `work/421-landscape-retune`: `ad4b99b1538d7200e9b228051a029e554e9b9912`
- `work/421-s009-exam`: `b30b290813d88109c5b9bc34354babefdc406f8d`

Research is continuing under #421. A negative or inconclusive experiment is not
a human hand-off and does not authorise a successor ticket.
