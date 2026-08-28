# Issue #421 progress — one-bit and two-stage setup grammar closures

## Decision

Close the complete one-bit producer-to-next-Attack family and its sole
evidence-justified two-stage extension. Do not subset producer cards, require a
specific setup order, change persistence, weaken support gates or alter the
one-Facet research payoff.

Both results are preregistered decision boundary 2. Issue #421 remains open and
continues with a materially different state representation.

## One-bit source inventory

Deterministic source filtering froze three native producer classes before any
count was read: reward Powers, direct Energy-gain cards and reward draw-Skills.
Each candidate used one combat-scoped setup bit consumed by the next Attack.
The screen reused only the 256 explicit-current traces that already reproduced
the cached current-main path, RNG, policy and result exactly.

| Candidate | Active | Inactive | Viable active | Candidate-only | Scoreline-only | Decision |
|---|---:|---:|---:|---:|---:|---|
| Power → Attack | 63 | 0 | 22 | 33 | 1 | fail inactive and two-sided separation |
| Energy → Attack | 21 | 27 | 6 | 9 | 19 | fail viability |
| Cycle Skill → Attack | 40 | 12 | 15 | 20 | 11 | fail inactive |

All source breadth, natural reachability and immutable reliability checks
passed. No candidate was selected merely for being closest to a threshold.

## Only justified two-stage extension

The one-bit result bounded every Energy conjunction to at most six viable
policies, below the required eight. Power was viable but saturated; Cycle was
viable and separated but three inactive identities short. The only conjunction
with measured decision value was therefore one reward Power plus one reward
draw-Skill, in either order, before a later Attack. It was frozen as a two-bit
AND state rather than expanded into pairwise or order-specific cells.

Power-cycle retained 35 active, 15 viable-active, 18 candidate-only and 14
Scoreline-only policies, with all 8 Power cards, all 4 cycle cards and all 32
exact pairs represented. It nevertheless had only 13 inactive policies against
the unchanged minimum of 16. That one hard failure closes the exact grammar;
the three-policy shortfall may not be rescued by an order, subset or threshold.

## Provenance and budgets

- One-bit protocol SHA-256: `294ce6b23792346ca62995411a89ad032e0171c5f69f8ba920e7921ad7675d95`
- One-bit summary SHA-256: `4eeda4d020539996106ea674d17acd7d0804a8181583c2cf4e856946febca3da`
- Power-cycle protocol SHA-256: `dfd47aea75b0662a048172ce83a0fb0db8e990667002ea0e79b11b2068d7e6cd`
- Power-cycle summary SHA-256: `bf3e927846079cf8e032ed82aac79be48a4249a02cbc49ea03a471fdde82ecd1`
- Source commit: `c4130163c7fb8edd865c0adc95732aae03e1bad2`
- Exact trace output: `ac86dac85f5398e6c8e4d63ef10cf5d57d85739f9cc62fb1ffdf1b9b21b06ed2`
- New simulator observation rows: 0
- New ledger rows: 0; ledger remains 480,372 records at `4563f536…`
- Model-context tokens during execution and decision: 0
- Protected-seed rows: 0

## Remote heads at preparation

- `origin/main`: `c4130163c7fb8edd865c0adc95732aae03e1bad2`
- `research/issue-421-p9-recovery-evidence`: `604d4baa9c0f26b08516fdf3ef0f734545a9feb6`
- `research/issue-524-causal-slate-evidence`: `f305b95d9e1d173e5d8150289afab9688c0ea7f0`
- `research/issue-525-mechanism-package-synthesis-evidence`: `7132e5e0d6e6e6dc196dda3ed90ad2be292608d6`
- `work/421-h34`: `4a94d155400162289a84f416336ff407f55b3cf6`
- `work/421-landscape-retune`: `ad4b99b1538d7200e9b228051a029e554e9b9912`
- `work/421-s009-exam`: `b30b290813d88109c5b9bc34354babefdc406f8d`

This is a review-only evidence snapshot, not product promotion, acceptance or a
#108 P9 receipt.
