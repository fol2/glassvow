# #458 F1/F2 search — racing, surrogate validation and finalist hand-off

Issue: [fol2/glassvow#458](https://github.com/fol2/glassvow/issues/458).
Part of [#454](https://github.com/fol2/glassvow/issues/454) and hands candidates to
[#421](https://github.com/fol2/glassvow/issues/421). Engine:
**4.7.2.stable.official.ed1daf0bf**. Primary worker: qualified **M1 Max, 8
workers**. Independent replay: qualified **M4, 4 workers**.

This is development search evidence, not the frozen acceptance exam. It emits no
C1–C4 PASS/FAIL result and changes no live content.

## Outcome

Two materially different Tier-0 candidates survive, in this order:

1. **`c029`** — the only survivor with a development C3-clear grid (Ash V0),
   while all four paired mini-CEM effects are positive.
2. **`s009`** — the strongest Layer-3 C1 point on the development frontier,
   retained as the higher-Ward / higher-Smolder trade-off.

Both retain Dusk shatter-fat / Ash smolder-fat identity, clear the development
C2 proxies with uncertainty, and keep both Vow-5 mini-CEM ceilings below 90%.
The complete path-level patches and every intended English and Traditional
Chinese hydrated catalogue/locale string are in
[`data/458/finalists.json`](data/458/finalists.json).

**Confidence is blocked for both finalists by the one-time non-gating audit.**
Each produced one planned-play Dusk V5 stall where `c000` produced none. This is
a material contradiction, explicitly retained rather than explained away. It
does not redefine or consume the frozen #215/#216 exam; #421 must still run its
unchanged Phase A and full exam on whichever exact patch it tries.

## F2 — surrogate adequacy

The diagnostic fit used the 31 complete candidates from the 32-candidate F0
design. Validation was leave-one-candidate-out; no response from a held-out
candidate entered its training fold. The estimator predicted all 28 raw response
components (seven for each grid), with a per-component calibrated interval. The
transparent comparator was a five-nearest inverse-Hamming mean.

| Candidate-held-out metric | ExtraTrees | Baseline | Pre-registered requirement | Result |
|---|---:|---:|---:|---|
| normalised MAE | 0.1772 | 0.1887 | ratio ≤ 0.95 | clear |
| deficit Spearman | **0.4783** | 0.3932 | **≥ 0.50** and lift ≥ 0.05 | **inadequate** |
| top-quartile recall | 0.625 | 0.375 | ≥ 0.625 and lift ≥ 0.125 | clear |
| interval coverage | 0.9505 | — | 0.80–0.98 | clear |

The absolute ranking threshold failed, so the model proposed **zero** candidates.
Instead, the pre-registered 16-candidate balanced maximin supplement ran. It has
16 unique vectors, marginal imbalance at most one per level, minimum Hamming
distance **4** within the supplement and from F0, and used all 8,192 deterministic
restarts. The complete held-out raw responses, intervals, model/baseline
predictions and package versions are in
[`data/458/surrogate.json`](data/458/surrogate.json); the exact 19-candidate
racing catalogue is [`data/458/candidate-manifest.json`](data/458/candidate-manifest.json).

`regrowthHeal` was the only clearly dominant importance signal (ordinary
permutation p50 0.0438, 95% interval 0.0294–0.0573; conditional p50 0.0505,
0.0420–0.0560). `ironSkinWard`, `flareDamage` and `duskMaxHp` followed at much
smaller scales. Every one of the 28 pairwise interaction intervals crossed zero;
none supports an interaction claim from this sample.

## F1 — progressive sequential racing

All ranking used common random numbers, arms 1–2, the frozen #215 axes and paired
seed-block bootstrap. A candidate needed a credible paired path to improve C1a
or C1b and no clear C2 regression. Confidence-envelope dominance, simulator
faults and the pre-registered layer cap were fail-closed stops.

| Layer | Controls | Mini-landscape | B | Entered | Promoted |
|---|---|---|---:|---:|---|
| 1 | 6200–6231 | 128 policies × 6200–6207 | 2,000 | 19 | `c029`, `s004`, `s009`, `s013`, `s016`, `s015` |
| 2 | 6200–6263 | 256 policies × 6200–6215 | 2,000 | 7 incl. `c000` | `s009`, `s013`, `c029` |
| 3 | 6200–6327 | 512 policies × 6200–6231 | 4,000 | 4 incl. `c000` | `s009`, `c029` |

Layers 2 and 3 inherited the preceding raw rectangle and simulated only the
disjoint additions. Layer 1's original sweep also emitted arms 3–4 as unused
diagnostics; the ranking ignored them, and the driver was then narrowed so all
additional control spend requested arms 1–2 only. No candidate was stopped by a
clear hard regression, missing credible path or non-overlapping dominance
envelope; all non-promotions were the bounded layer cap. Every decision retains
the point evidence, paired intervals, simulator identity and raw observation
SHA available at that moment:

- [`Layer 1 summary`](data/458/layer1-summary.json) and
  [`decisions`](data/458/layer1-decisions.json)
- [`Layer 2 summary`](data/458/layer2-summary.json) and
  [`decisions`](data/458/layer2-decisions.json)
- [`Layer 3 summary`](data/458/layer3-summary.json) and
  [`decisions`](data/458/layer3-decisions.json)

Layer-3 finalist proxy evidence:

| Candidate | deficit sum | C1a | C1b | max arm-2 | min top−arm-2 | identity |
|---|---:|---:|---:|---:|---:|---|
| `c029` | 3.500 | 2.000 | 1.500 | 26.6% | 51.8 pp | Dusk shatter / Ash smolder |
| `s009` | **3.167** | **1.667** | 1.500 | 28.9% | 56.7 pp | Dusk shatter / Ash smolder |

For both candidates, every arm-2 p025 is below 50% and every margin p975 is at
least 35%; these are development uncertainty checks, not exam verdicts.

## Development mini-CEM

Only the two final racing survivors and paired `c000` entered mini-CEM. The
protocol used root **2454**, policy root **1454**, 24 islands per candidate,
population 16, elite 4, at most six generations, training seeds 6400–6447 and
holdout seeds 6800–6839. Roots 215/216 and every acceptance seed remained unused.

Paired deltas below are candidate minus `c000` holdout win rate; intervals use
4,000 holdout-seed block bootstraps.

| Candidate | Grid | paired delta (95%) | best ceiling | development C3 | development C4 |
|---|---|---:|---:|---|---|
| `c029` | Dusk V0 | +10.4 pp (+1.7, +19.2) | 70.0% | no | clear |
|  | Dusk V5 | +10.0 pp (+1.7, +17.9) | 45.0% | no | clear |
|  | Ash V0 | +10.0 pp (+2.9, +16.7) | 87.5% | **clear** | clear |
|  | Ash V5 | +21.7 pp (+13.3, +30.0) | 65.0% | no | clear |
| `s009` | Dusk V0 | +18.3 pp (+8.8, +27.5) | 82.5% | no | clear |
|  | Dusk V5 | +11.3 pp (+2.1, +20.4) | 47.5% | no | clear |
|  | Ash V0 | +11.3 pp (+4.6, +17.5) | 92.5% | no | clear |
|  | Ash V5 | +11.7 pp (+5.8, +17.5) | 60.0% | no | no |

The Vow-5 fail-closed ceiling is clear for both: `c029` Dusk/Ash **45%/65%**;
`s009` **47.5%/60%**. Raw-island hashes, candidate seed-packet hashes and the
paired report are in [`mini-cem-manifest.json`](data/458/mini-cem-manifest.json),
[`cem-seeds/`](data/458/cem-seeds/) and
[`mini-cem.json`](data/458/mini-cem.json).

## Exact finalist patches

The rows include unchanged coupled leaves so that the complete candidate identity
is explicit. `finalists.json` also carries the generated `text`/`textUp` values
for `content/full-content.json`, `locale/en.json` and `locale/zh-Hant.json`.

| Path | baseline | `c029` | `s009` |
|---|---:|---:|---:|
| `player.maxHp` | 64 | 60 | 60 |
| `aspects[0].maxHp` | 64 | 60 | 60 |
| `arts.flare.effects[0].n` | 9 | 11 | 10 |
| `arts.ashfall.effects[0].n` | 6 | 6 | 4 |
| `arts.ashfall.effects[1].n` | 5 | 6 | 5 |
| `cards.regrowth.effects[0].n` | 2 | 4 | 4 |
| `cards.regrowth.up.effects[0].n` | 3 | 5 | 5 |
| `cards.ironSkin.effects[0].n` | 3 | 2 | 4 |
| `cards.ironSkin.up.effects[0].n` | 4 | 3 | 5 |
| `cards.guardedStrike.effects[1].n` | 4 | 4 | 5 |
| `cards.guardedStrike.up.effects[1].n` | 6 | 6 | 7 |
| `cards.venomStrike.effects[1].n` | 4 | 2 | 5 |
| `cards.venomStrike.up.effects[1].n` | 5 | 3 | 6 |

`c029` sits on five Tier-0 boundaries (minimum HP, maximum Flare/heal, minimum
Iron Skin/Venom); `s009` sits on three (minimum HP, maximum heal/Venom). Tier 0
therefore appears sufficient for **two bounded Phase-A attempts**, not proven
sufficient for a gate pass. A Tier-1 expansion is not justified before those
exact patches sit the unchanged exam.

## One-time sealed audit

The registered audit used controls 8000–8199 once, arms 1–2, with a planned
128-policy × 8000–8007 mini-landscape. An initial invocation reached the sealed
stage guard and emitted **zero rows** because the finalist token was not forwarded
to the Godot driver; the propagation fix then passed `PASS (62 tests)`. The sole
data-bearing invocation ran at commit `7f4b8c9`.

`c000` completed 1,600 controls and 4,096 landscape rows with zero stalls.
Both finalists hit the existing fail-closed control rule before landscape spend:

| Candidate | exact contradiction | control rows | landscape rows | confidence |
|---|---|---:|---:|---|
| `c029` | arm 1, Dusk V5, seed **8078**, stall | 1,600 | 0 | **blocked** |
| `s009` | arm 1, Dusk V5, seed **8144**, stall | 1,600 | 0 | **blocked** |

The audit did not trigger an adaptive rerun or unseal any further data. Its raw
observation hashes, exact fault rows and fail-closed interpretation are in
[`audit-summary.json`](data/458/audit-summary.json) and
[`audit-comparison.json`](data/458/audit-comparison.json). The contradiction
means neither candidate may be described as expected to pass. The audit remains
non-gating and does not alter the signed #215/#216 acceptance contract.

## Independent M4 verification

The M4 replayed development control seed 6327 (arms 1–2) and landscape policy
511 / seed 6231 for both finalists. All **24 rows** matched the M1 evidence
byte-for-byte after canonical row ordering. Exact row hashes and both qualified
host-packet hashes are in
[`data/458/m4-verification.json`](data/458/m4-verification.json).

## Replay and non-effects

F2 fitting is reproducible with the pinned hash-locked package set:

```bash
python3 -m venv VENV
VENV/bin/pip install --require-hashes -r tools/requirements-balance-f2.txt
VENV/bin/python -B tools/balance_f1_f2.py --report REPORT --bundle BUNDLE
```

F1 raw evidence is regenerated layer by layer with `tools/balance_f0.py` and
`--evaluation layer1|layer2|layer3`; pass the preceding output through
`--inherit` for Layers 2 and 3. `tools/balance_f1_evidence.py decide` rebuilds
the paired evidence from raw shards before recording a decision. Mini-CEM replay
uses `cem-seeds`, `tools/balance_f1_cem.py`, then `cem-compare`. Every committed
product binds its protocol, catalogue, simulator/tool identity, input and raw
observation hashes.

No acceptance seed, reserve seed, or root 215/216 was used. No finalist patch,
hydrated text or locale string has been applied to the live catalogue. Applying
one patch and sitting the unchanged Phase A/full exam belong to #421.
