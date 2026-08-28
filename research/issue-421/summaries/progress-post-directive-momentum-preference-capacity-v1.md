# Issue #421 progress — exact Honing repeat and policy-remap closure

## Decision

Close the `momentumPolicyPreference` remap and the Honing Edge same-instance
repeat family. Do not implement the repeat payoff, tune the mapping, weaken the
support gates, replace the cohort or add ML/RL.

This is decision boundary 2 of the preregistered protocol. Issue #421 remains
open and continues only with the next source- and evidence-backed structural
Duskblade mechanism.

## Scientific narrowing

The preceding zero-row studies closed two proposed mechanisms before
implementation:

- same-enemy reseam break was active for 51 of 64 policies and inactive for
  only one, so it was another broad Shatter reward rather than a repertoire
  discriminator;
- aggregate Honing Edge repeat capacity reached 16 active and 34 inactive
  policies, but only five were independent of the Scoreline route against the
  frozen minimum of eight.

The Honing shortfall exposed a specific repertoire alias: current policy code
mapped both `momentum` and `execute` to `special.execute`. A single binary
research remap reused the existing immutable `special.shatterEchoDusk` field;
no new policy dimension, optimiser, model, product effect or payoff was added.
The exact protocol was frozen before any new simulator row.

## Identity and CRN proof

The focused preflight passed. Omitted and explicit-null paths were exact;
Ashwarden scores and every Duskblade card score except Honing Edge remained
exact; only the registered Momentum score changed; policy identity remained
exact; and invalid level 2 failed closed with exit 2 and no output.

All 256 traced current rows reproduced the cached current-main path, RNG and
result exactly after trace-only fields were removed. Current and remap arms used
the same 64 root-551 policy identities, the same four simulation seeds, Vow 5,
baseline content, first look, estimator and stop rule. Exact repeat required two
Honing Edge plays with the same fight identity and the same `CardInst.uid`.

## Fixed first-look result

The complete 515-observation run stopped at the frozen first look:

| Gate | Current | Remap | Required | Result |
|---|---:|---:|---:|---|
| exact-repeat active policies | 13 | 14 | at least 16 | fail |
| exact-repeat inactive policies | 40 | 34 | at least 16 | pass |
| Honing-only policies | 5 | 7 | at least 8 | fail |
| natural offer policies | 62 | 62 | at least 8 | pass |
| natural acquisition policies | 30 | 35 | at least 8 | pass |
| Scoreline-route active policies | 31 | 32 | at least 8 | pass |
| newly repeat-active and Scoreline-inactive in both arms | — | 5 | at least 3 | pass |
| added fault identities | — | 0 | 0 | pass |

The remap produced measurable independent decision value, but it still missed
both absolute support gates. That is decisive futility: the family cannot be
rescued by another preference field, threshold, cohort, payoff level or
adaptive candidate iteration.

## Provenance and budgets

- Protocol SHA-256: `ac2202a945a88d2067eb55cb51e93e541653cb541aba73f7a965b935296214dc`
- Runner SHA-256: `c3d87254121e3f14188a8574e81764211822134f813867eaf2988eeb3b67e465`
- Summary SHA-256: `fdc51ca09f103f53528afb4f3b641a0c330db3dff1935287e1981b40a2dfd73b`
- Telemetry output SHA-256: `ac86dac85f5398e6c8e4d63ef10cf5d57d85739f9cc62fb1ffdf1b9b21b06ed2`
- Exact engine: Godot `4.7.1.stable.official.a13da4feb`
- Source commit: `c4130163c7fb8edd865c0adc95732aae03e1bad2`
- Observation rows: 515 of 515
- Ledger: 479,853 → 480,372 records, exactly 519 new records
- Wall time: 27.027261 seconds of the frozen 900-second ceiling
- Model-context tokens during execution and decision: 0
- Protected-seed rows: 0

## Remote heads at preparation

- `origin/main`: `c4130163c7fb8edd865c0adc95732aae03e1bad2`
- `research/issue-421-p9-recovery-evidence`: `aed48f51fedcb66edc75e600bd31f01bd2e09bbb`
- `research/issue-524-causal-slate-evidence`: `f305b95d9e1d173e5d8150289afab9688c0ea7f0`
- `research/issue-525-mechanism-package-synthesis-evidence`: `7132e5e0d6e6e6dc196dda3ed90ad2be292608d6`
- `work/421-h34`: `4a94d155400162289a84f416336ff407f55b3cf6`
- `work/421-landscape-retune`: `ad4b99b1538d7200e9b228051a029e554e9b9912`
- `work/421-s009-exam`: `b30b290813d88109c5b9bc34354babefdc406f8d`

The evidence carrier is review-only. It is not a product PR, acceptance packet
or #108 P9 receipt.
