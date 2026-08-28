# Issue #421 Dusk mechanism source-and-policy screen

## Decision

Close the proposed Shatterer's Crown boss-offer inclusion mechanism at decision
boundary 2. Do not implement the offer knob, weaken the 16-policy gate, alter
tie handling or spend a simulator row.

This closes only guaranteed offer inclusion. It does not establish that the
existing natural Crown path lacks a causal effect, and it does not admit a
package, detector or product change.

## Source-first candidate selection

The candidate was selected before policy support was read. Immutable #524 has
78 authored Dusk-specific edges, all mediated by Shatter. Its tested
`dusk-shatter-relics` package used Prism Charm and Bell of Endings, so those
targets were excluded. The remaining 26 attack-card edges all target
Shatterer's Crown. Because the relic changes the shared facet threshold rather
than one card payoff, the 26 sources were collapsed as one alias family; no
source card was ranked or tuned.

The exact current-main mechanism already exists:

- Shatter is Dusk-only;
- Shatterer's Crown is in the unlocked boss relic pool;
- it reduces every enemy facet gauge by one and gives every enemy one Fervor;
- the frozen pilot applies a Dusk-specific preference bonus.

This is materially different from the tested Prism/Bell payoff package and
from every closed Ward, Kindle, Afterimage, package-order and scalar family.

## Frozen zero-row decision-value test

The screen reused the same complete root-551 current-main baseline: 64
Duskblade Vow-5 policies, four seeds each and 256 existing rows. It used no win
or duration endpoint.

For each frozen policy, deterministic code enumerated all six unordered pairs
from the other four boss relics and calculated the exact integer pilot score
for Shatterer's Crown. A strict pair win required Crown to beat both co-offers;
ties were not counted because live selection would depend on offer order.

- robust selector: Crown strictly wins all six pairs;
- robust decliner: Crown strictly wins none;
- projected active: robust selector, reaches a boss boundary and demonstrates
  at least one current-main Shatter.

The frozen gates required at least 16 robust selectors, 16 robust decliners,
16 projected-active, 16 boss-reachable and 16 Shatter-capable policies. The
budget was zero simulator rows, zero ledger rows, 60 seconds, zero model-context
tokens during execution and zero protected seeds.

## Result

The current natural path had substantial descriptive support:

- Crown acquired and Shatter active: 25 policies;
- Crown inactive: 39 policies;
- boss reachable: 50 policies;
- Shatter capable: 64 policies.

The guaranteed-offer decision-value gates nevertheless failed exactly as
preregistered:

| Strict wins across six possible co-offer pairs | Policies |
|---:|---:|
| 0 | 17 |
| 1 | 16 |
| 2 | 0 |
| 3 | 16 |
| 4 | 0 |
| 5 | 0 |
| 6 | 15 |

There were 15 robust selectors against the minimum of 16 and only 14 projected
active policies against 16. Robust decliners passed at 17; boss reach and
Shatter capacity also passed. The one-policy shortfall is still a hard failure:
the threshold, tie rule, candidate and cohort are frozen.

The deterministic decision was
`close-dusk-shatter-threshold-crown-screen`. The ledger remained byte-identical
at 479,669 records, SHA-256
`d96ee5162d5c7878f1e4b394791632e4cd514153c1510f4e8d055cbc4cb9834e`,
SQLite integrity `ok`, protected rows 0.

## Scientific boundary and next action

No offer-inclusion knob will be written. The preregistered descriptive support
does identify a narrower unresolved causal question: whether the existing
Crown threshold reduction plus Fervor cost, on its natural reward path, causes
route-specific Dusk complementarity rather than merely co-occurring with it.

The cheapest next step is an identity-safe research-only effect ablation. Its
null must reproduce current main exactly; its non-null may disable only the
existing threshold-and-Fervor mediator while leaving relic acquisition, policy,
path and RNG identities fixed at first look. Before any causal row, a small
identity panel must prove those boundaries. Failure closes the Crown mechanism;
success authorises one mechanism-blocked CRN discovery, not product promotion.

## Exact artefacts

- protocol SHA-256: `e882f66df0a21363a03d92333cea21fee79334ad3d392c981670613bd05af0b9`
- runner SHA-256: `86f98bec032865a21cb11640f988b86e2039b5652b9a3af05cc875d80885991f`
- summary SHA-256: `9ba14ec9a63ecb9a8e7cafa9b4edc0b5def546755c25e57234ee15dc251b2a64`

## Remote heads at publication preparation

- `origin/main`: `c4130163c7fb8edd865c0adc95732aae03e1bad2`
- `research/issue-421-p9-recovery-evidence`: `a0a050d0eb980a6be919e29e21fc9662c718fc14`
- `research/issue-524-causal-slate-evidence`: `f305b95d9e1d173e5d8150289afab9688c0ea7f0`
- `research/issue-525-mechanism-package-synthesis-evidence`: `7132e5e0d6e6e6dc196dda3ed90ad2be292608d6`
- `work/421-h34`: `4a94d155400162289a84f416336ff407f55b3cf6`
- `work/421-landscape-retune`: `ad4b99b1538d7200e9b228051a029e554e9b9912`
- `work/421-s009-exam`: `b30b290813d88109c5b9bc34354babefdc406f8d`
