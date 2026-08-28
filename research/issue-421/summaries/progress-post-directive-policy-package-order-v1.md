# Issue #421 policy-selective package-order progress

## Decision

Close the exact positive-median `policyPackageOrder` grammar without a new
simulator row. Continue inside issue #421 with a structural mechanism that can
reduce cross-package acquisition saturation rather than merely decide when to
apply producer-first ordering.

## Exact current-main toolchain

The current-main contract requires Godot 4.7.1, while the preceding archived
experiments reported 4.7.2. The official macOS universal 4.7.1 archive was
downloaded into an isolated research toolchain, verified against the official
SHA-512 file and checked with macOS codesign. The exact binary reports
`4.7.1.stable.official.a13da4feb` and has SHA-256
`ecc8da2d60100102cfca6e833d3860d7436b46ae062fa072ce89a6c95d664a3f`.

Before changing the research grammar, that engine replayed the frozen 20-row
package-order identity plan. All canonical policy, path, RNG and result rows
were exactly equal to the 4.7.2 evidence. No ledger row was written.

## Identity result

Protocol
`6c406f831b0db224a7c9478a24f831b4e5a835bd71d611567a3b9380118f0bbc`
froze four separate policy-preference gates at their sampler geometric medians:

| Package | Preference | Median |
|---|---|---:|
| Dusk Scoreline | `special.execute` | 13 |
| Dusk Afterimage | `special.doubleBlock` | 9 |
| Ash Bloodfire | `special.leech` | 12 |
| Ash Poison | `special.catalystAsh` | 30 |

The exact 4.7.1 preflight passed. Null and the closed universal grammar remained
exact after removing only the declared new null and observational fields. Every
value 0.001 below its median was ineligible; every exact-median value was
eligible. Eligible mediator-absent cells selected the producer, while all
below-threshold and mediator-present cells retained the off choice. Resolved
policy, combat scores, eligibility and RNG were exact within every contrast.
The unregistered level and the universal-plus-selective alias both failed
closed. The ledger remained byte-identical.

## Zero-row decision-value boundary

Identity safety did not justify spending simulator rows. A declared
retrospective screen reused only the complete root-550 universal and
same-content null policy rectangles. Revision 1 stopped before any estimand
because its rectangle helper was referenced from the importing module; that
inconclusive is retained. Revision 2 changed only the helper reference and
inherited the evidence, thresholds, estimands, gates, budget and stopping rule.

The corrected screen rejected the grammar:

- all four eligibility splits were balanced;
- Poison was active in 109 policies under both observed endpoint sets, so any
  per-policy selection between those endpoints can leave at most 19 inactive,
  below the fixed minimum of 32;
- the no-interference Scoreline splice left 30 inactive;
- the Ash splice retained only six Bloodfire-only policies.

The exact grammar therefore has no measured repertoire decision value. No
beneficial cross-package interference may be assumed to rescue it, and its sign
or thresholds may not be retuned.

## Current boundary

The universal and positive-median producer-first grammars are closed. The
remaining measured problem is cross-package acquisition saturation, especially
Poison, not local causal support or action-order identity. The next cheapest
discriminator is a zero-row audit of whether independently sampled within-aspect
payoff preferences and the frozen reward/economy traces support a deterministic
package-commitment mechanism. ML/RL, protected seeds, detector admission and
product promotion remain unauthorised.
