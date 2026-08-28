# Issue #421 progress — Reaper's Bell death-chain closure

## Decision

Close the existing Reaper's Bell non-final-enemy-death chain without telemetry,
implementation or simulator spend. This is preregistered decision boundary 2.
Issue #421 remains open and continues with a materially different mechanism.

## Source and capacity result

After removing the closed cadence, Shatter, Ward and Kindle families,
current-main source uniquely selected Reaper's Bell as the natural-pool relic
whose positive action-economy payoff is gated by an enemy death while another
enemy remains alive. The authored trigger adds exactly one Energy and draws one
card. Selection used no ownership, path or outcome field.

The necessary-capacity condition deliberately overstated exposure: final
whole-run ownership plus any multi-enemy fight. Forty of 64 policies acquired
the relic in at least one frozen row, and all 64 were chain-capable, but only
nine were robust owners/potential-active against the fixed minimum of 16. Only
five were viable potential-active against eight.

The same policy identities also failed both shared interference anchors.
Reaper's Bell had five candidate-only policies against Scoreline and one
against Afterimage, each below eight. Its low Jaccard values do not rescue the
missing absolute support. No exact acquisition/proc telemetry, causal factor,
rarity/score change or hand-picked kill card is authorised.

## Frozen design and budgets

This was one immutable observational cell, not a factorial. Scoreline and
Afterimage were separate fixed factors with exact preregistered policy sets.
Acquisition priority, Faultline rarity and Ward setup priority were also fixed.

- Source commit: `c4130163c7fb8edd865c0adc95732aae03e1bad2`
- Exact cached current trace: 64 policies × 4 seeds = 256 rows
- Protocol SHA-256: `fc17c6eac833bb9a2951145f276928ea44c275a2d1ad50be8ebd0fbfdef4487d`
- Summary SHA-256: `0c8ed919c183c0a8255bbec2c1c24d0c78818d39005d5d0b07224d69dfe3ff05`
- New simulator observation rows: 0
- New ledger rows: 0; ledger remains 480,372 records at `4563f536…`
- Maximum model-context tokens during execution and decision: 0
- Protected-seed rows: 0

## Remote heads at preparation

- `origin/main`: `c4130163c7fb8edd865c0adc95732aae03e1bad2`
- `research/issue-421-p9-recovery-evidence`: `222a6e3b2ab9eafaab2a9d9af87094baceb201e4`
- `research/issue-524-causal-slate-evidence`: `f305b95d9e1d173e5d8150289afab9688c0ea7f0`
- `research/issue-525-mechanism-package-synthesis-evidence`: `7132e5e0d6e6e6dc196dda3ed90ad2be292608d6`
- `work/421-h34`: `4a94d155400162289a84f416336ff407f55b3cf6`
- `work/421-landscape-retune`: `ad4b99b1538d7200e9b228051a029e554e9b9912`
- `work/421-s009-exam`: `b30b290813d88109c5b9bc34354babefdc406f8d`

This is a review-only evidence snapshot, not product promotion, acceptance or a
#108 P9 receipt.
