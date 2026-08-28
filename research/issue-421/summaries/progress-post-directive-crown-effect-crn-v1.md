# Issue #421 Shatterer's Crown natural-effect CRN

## Decision

Close the Shatterer's Crown effect family at preregistered decision boundary 2.
Do not reinterpret the strong threshold effect as a strategy package, remove
Fervor, add another Crown level, alter acquisition or send either frozen cell
to held-out confirmation.

This is a causal bounded negative for strategy differentiation, not a claim
that the relic has no mechanical effect. The threshold effect is large and
broad; that breadth is the fixed failure.

## Frozen factors and design

The existing relic has two separate causal components, so the protocol did not
use one combined on/off knob:

- `shatterersCrownFacetThreshold`: current one-facet reduction versus disabled;
- `shatterersCrownFervor`: current one enemy Fervor versus disabled.

Scoreline payoff, Afterimage payoff, Faultline rarity, acquisition priority and
every package-order knob remained separately fixed non-factors. The experiment
therefore used a complete, mechanistically justified 2x2 Crown-effect matrix,
not the retired four-factor design and not a blind Cartesian expansion.

The shared anchors were current `(1,1)`, both-off `(0,0)` and eight frozen
no-Crown policy-seed blocks. The only interaction was threshold by Fervor:
threshold timing can alter survival, turns and later Shatter opportunity while
Fervor alters incoming damage. There was no alias: both effect factors varied
independently within every common-random-number block; policy and seed were
blocking identities; acquisition did not vary.

The complete budget was frozen before execution:

- 10 focused surface rows;
- 8 whole-run null-identity rows;
- 128 naturally exposed discovery rows: 32 policy-seed blocks by four cells;
- 32 no-Crown rows: eight blocks by four cells;
- 178 total simulator observations, 600 seconds, 0 model-context tokens during
  execution and decision, and 0 protected seeds.

The exposed cohort was all 32 root-551 Duskblade Vow-5 baseline rows that
naturally acquired Crown, representing 25 policies. Selection used ownership
only. Both interventions first act after acquisition and cannot alter relic
offers or scoring.

## Identity preflight

Every preregistered identity check passed before the discovery rectangle ran:

- omitted and explicit-null focused Crown and no-Crown rows were exact;
- disabling threshold changed enemy facet maximum from 5 to 6 and nothing else;
- disabling Fervor changed enemy Strength from 1 to 0 and nothing else;
- queue, relic ownership, policy and RNG stayed exact;
- both invalid factor levels failed closed with exit 2, no output and the
  registered diagnostic;
- four whole-run omitted/null pairs were canonically equal to each other and
  their already cached current-main results.

Across the full discovery rectangle, all 40 current cells reproduced the
frozen baseline exactly after trace-only metadata was removed. All no-Crown
cells were canonically identical, all policy snapshots matched and every
natural Crown acquisition prefix was exact.

## Causal result

Inference used the frozen policy identity as the cluster. Repeated exposed
seeds were averaged within policy, then a deterministic 5,000-resample
percentile bootstrap estimated the cluster-mean paired contrasts.

| Contrast | Mean Shatters | 95% interval | Positive policies | Inactive policies |
|---|---:|---:|---:|---:|
| authored current minus both-off | +6.34 | [3.42, 9.80] | 23 | 1 |
| threshold at current Fervor | +7.16 | [4.06, 10.90] | 23 | 1 |
| threshold-only minus both-off | +6.80 | [3.80, 10.58] | 23 | 0 |

Both candidate cells cleared effect, mechanism, reliability, viability, Vow-5
and duration gates. Current had 12 viable policies and a 0.375 Vow-5 win rate;
threshold-only had 11 and 0.34375. Both had zero faults. Current-minus-both-off
duration was -0.027 turns per fight with interval [-0.106, 0.052];
threshold-only was +0.017 with interval [-0.052, 0.081].

The fixed package-sensitivity gate also required at least eight positive and
eight inactive exposed policy identities. Current had only one inactive policy;
threshold-only had none. The independent zero-row audit reproduced the raw
contrasts, exact identities and both hard failures. It added no simulator or
ledger row.

The correct scientific reading is therefore: Crown's facet reduction reliably
raises Shatters for nearly every exposed Dusk policy. It is broad threshold
power, not a policy-selective repertoire discriminator. Fervor removal does not
repair that failure. The preregistered inactive-policy gate cannot be weakened
after observing the result.

## Exact artefacts

- protocol SHA-256: `ca03b6ea0efe8d6da71399e70fd04be8d6ba4e1517fb6736cc36b01864fae31f`
- runner SHA-256: `d024df9beb7f1a261751de7a2c203906b3615cee0fcd6bd0c722d61976804b5c`
- summary SHA-256: `7b7a11a1f78f42dcdf7f8a1ccd2515c9ddb10b066ade66a04f66f486b4aafa14`
- independent audit SHA-256: `e8de4178d6f0dfe8546a1057f0b51822556fc12a7dcc672d6916e019ecd4f1dd`
- discovery output SHA-256: `632ec8619e37954741fe7d48bb695486a542332a67f60538b7b37c33c0fcc9a0`
- ledger after execution and audit: 479,853 records, SHA-256
  `2d4ee63ac8cd83664972da376b6a9bab09ebf741020ef159297a5a50a7bd4d2b`,
  SQLite integrity `ok`, protected rows 0.

## Remote heads at publication preparation

- `origin/main`: `c4130163c7fb8edd865c0adc95732aae03e1bad2`
- `research/issue-421-p9-recovery-evidence`: `b8983a53533efc8af9b49ffee8b068d197bf7b22`
- `research/issue-524-causal-slate-evidence`: `f305b95d9e1d173e5d8150289afab9688c0ea7f0`
- `research/issue-525-mechanism-package-synthesis-evidence`: `7132e5e0d6e6e6dc196dda3ed90ad2be292608d6`
- `work/421-h34`: `4a94d155400162289a84f416336ff407f55b3cf6`
- `work/421-landscape-retune`: `ad4b99b1538d7200e9b228051a029e554e9b9912`
- `work/421-s009-exam`: `b30b290813d88109c5b9bc34354babefdc406f8d`

## Next action

Follow the frozen boundary: close Crown, keep every protected seed unused and
continue inside #421 with the smallest new deterministic Duskblade structural
mediator justified by the now-exhausted existing grammar. Start with a
source-and-capacity contract; do not return to Crown, Ward, Kindle, Afterimage,
the tested #524 packages, ML/RL or adaptive candidate tuning.
