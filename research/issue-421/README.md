# Issue #421 P9 recovery evidence snapshot

> Archive-only evidence branch. Do not merge or apply this directory as a
> product change.

This directory publishes reviewable evidence from the active scientific issue
[#421](https://github.com/fol2/glassvow/issues/421) campaign. It now covers the
V38 freeze, the zero-row identifiability audit, and the pre-directive
common-random-number experiment. It is a progress snapshot, not a terminal
finding, detector admission, product candidate or P9 receipt. The branch is a
remote evidence carrier only: it has no pull request, triggers no product CI
and is not intended to enter `main`.

## Current decision

V38 is rejected and frozen. Its complete discovery controls found 0.125
Duskblade Vow-0 RandomBuild movement against the 0.10 limit and one
candidate-added stall.

The post-V38 audit used zero new simulator rows. None of the V33-V38 one-lever
pairs shared policies and simulation seeds, so none identifies a between-level
causal effect. Exact path invariance establishes only that acquisition priority
and rarity have zero effect on fixed-deck local combat. It does not identify
their whole-run effects.

The result was therefore `inconclusive`: V33-V38 are combination-level bounded
negatives and cannot select another candidate. No V39 candidate exists.

One later five-factor 48-cell common-random-number experiment added 34,304
research observations before the owner tightened the design. All cells passed
RandomBuild, reliability and Vow-5 controls on both splits, but all failed the
policy-sensitivity panel through saturated route activation. A subsequent
zero-row policy-signal audit found no held-out predictive policy increment.

Those later outputs are frozen as pre-directive evidence, not promoted as a
compliant scalar-family decision. The active next gate is exact null identity
and intended-mediator isolation for both research knobs, followed by a
five-factor mechanism-blocked CRN preregistration. No new simulator observation
is authorised before both gates pass.

## Reading order

1. [`summaries/progress-pre-directive-factorial-v1.md`](summaries/progress-pre-directive-factorial-v1.md)
   — current progress, the directive boundary, results and remote heads.
2. [`protocols/post-v38-factorial-v1.json`](protocols/post-v38-factorial-v1.json),
   [`summaries/post-v38-factorial-v1.json`](summaries/post-v38-factorial-v1.json),
   [`protocols/post-v38-policy-signal-v1.json`](protocols/post-v38-policy-signal-v1.json)
   and [`summaries/post-v38-policy-signal-v1.json`](summaries/post-v38-policy-signal-v1.json)
   — exact pre-directive contracts and outputs.
3. [`artifacts/ledger-freeze-pre-directive-v1.json`](artifacts/ledger-freeze-pre-directive-v1.json)
   and [`raw/post-v38-factorial-raw-v1.tar.gz`](raw/post-v38-factorial-raw-v1.tar.gz)
   — ledger identity and complete raw plan/output evidence for the later run.
4. [`summaries/progress-v38-identification-v1.md`](summaries/progress-v38-identification-v1.md)
   — the earlier V38 freeze and identifiability decision.
5. [`summaries/post-v38-identification-v1.json`](summaries/post-v38-identification-v1.json)
   and [`protocols/post-v38-identification-v1.json`](protocols/post-v38-identification-v1.json)
   — zero-new-row identifiability result and preregistration.
6. [`summaries/combined-finalist-v38-scoreline-rarity.json`](summaries/combined-finalist-v38-scoreline-rarity.json)
   and [`protocols/combined-finalist-v38-scoreline-rarity.json`](protocols/combined-finalist-v38-scoreline-rarity.json)
   — the frozen V38 rejection.
7. [`task-capsule.json`](task-capsule.json) — current outcome, invariants,
   authoritative priors, decisions and next action.
8. [`artifacts/ledger-freeze-v38.json`](artifacts/ledger-freeze-v38.json) —
   append-only ledger identity, record counts and protected-seed proof.

All earlier protocols and summaries from this campaign are retained in their
respective directories. The deterministic research programs are under `tools/`.

## Detached prototype

`prototype/` records the exact V38 detached content, combat, pilot, simulator
and probe files. These copies are research evidence only. They are not applied
to the archive branch's product paths and have not crossed the promotion
boundary.

`raw/pre-directive-harness-v1.tar.gz` records the exact four-file harness used
by the later five-factor experiment. It intentionally preserves the
`_research421` policy-snapshot identity defect found before the next run; it is
evidence, not the repair.

## Evidence cache and ledger

`raw/cache/sha256/` contains all 212 content-addressed cache objects referenced
by the published protocols, summaries and task capsule, totalling 7,212,968
bytes before Git compression.

At the V38 freeze, the append-only SQLite ledger was 2.0 GB and was deliberately
not copied into Git history. That freeze remains immutable at
`/Users/jamesto/Research/glassvow-p9-421/ledger/research.sqlite` with:

- SHA-256 `78651f5d2b51b5f11bd4466500542643083e3def1c56a705463d3b323adcd493`;
- SQLite integrity `ok`;
- 412,502 unique records, sequence 1 through 412,502;
- zero observations in acceptance seeds 3000-5199 or reserve seeds 5200-5399.

The omission prevents a multi-gigabyte raw research database from becoming
permanent product-repository baggage. The ledger freezes, all decision outputs
and the compact evidence needed for remote review remain published.

After the pre-directive experiment the ledger is 2,396,471,296 bytes with
447,063 records and SHA-256
`5dafd3dbee1ce90ee12a5cd8ed9fd2a29559775b8dd5cbc3051251e18a040833`.
The complete 34,304-row experiment is available through the compressed raw
archive without placing the full multi-gigabyte campaign ledger in Git.

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
