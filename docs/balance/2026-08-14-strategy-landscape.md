# Strategy landscape — Slice C — 2026-08-14
Issue: [fol2/glassvow#215](https://github.com/fol2/glassvow/issues/215). This is layer 1: 2,000 sampled policies, 40 common run seeds (3000–3039), per aspect and per gated vow. The four control arms use seeds 4000–4199. Godot was `4.7.1-stable (official)` and content SHA-256 was `633408231840d4ba47e0680d1969982cdf1ded1a61213a51bfd2bdab00f35155`. The sweep retained 320,000 rows: 129,180 wins, 190,797 losses, 23 stalls (counted as non-wins), and zero errors.
## Pre-flight: T1a changes deck growth
The cheap gate used sampler root seed **215**, policies 0–99, seeds 3000–3003, both aspects and Vow 0: **800 runs**. For each policy, `cards added/fight = (final deck − 10) / fights` was averaged across its eight runs. The policy means ranged **0.315–1.325** (spread **1.010**, overall mean **0.936**). Pearson correlation with `cardDecline` was **r = −0.842** (n = 100, two-sided p < 1e-20). T1a therefore passed the stop gate.
The plot is ten equal-count threshold bands; the bar encodes mean cards added/fight and the bracket is the within-band policy spread.

```text
cardDecline       mean   spread          plot
 0.18– 2.31       1.184  [1.115, 1.325]  ████████████
 2.39– 5.95       1.143  [1.056, 1.251]  ███████████
 6.09–10.46       1.203  [1.068, 1.263]  ████████████
10.83–15.77       1.065  [0.971, 1.174]  ███████████
15.77–19.72       1.050  [0.720, 1.213]  ██████████
19.97–25.94       0.900  [0.596, 1.054]  █████████
26.45–29.09       0.861  [0.709, 1.033]  █████████
29.43–32.50       0.676  [0.471, 0.958]  ███████
32.61–35.10       0.620  [0.414, 0.858]  ██████
35.83–39.98       0.657  [0.315, 0.910]  ███████
```
The original 10–16 trial produced real spread but only r = −0.181 because card-score magnitudes themselves range from 0.25× to 4×. It did not span the resolved score distribution. The final 0–40 range deliberately covers near-take-all through heavy decline; this range is revisable.
## Sampling distributions
`BalancePolicy.sample_range(215, first, count)` advances one Mulberry32 `Rng` from root seed 215 through every preceding policy, so shards reproduce the same vectors as an unsharded run. Each row records both its resolved `policy` and `policyIndex`.
Every non-zero scalar in `card` (including non-zero rarity weights), `status`, `special`, `combat`, `route`, `relics`, and `relicRarity`, plus `potionShopDefault`, `potionHealing`, `relicFallback`, `relicDuskBonus`, and `relicAshBonus`, independently receives a log-uniform multiplier:
`multiplier = 0.25 × 16^U`, where `U ~ Uniform[0, 1)`, i.e. ×[0.25, 4). Zero defaults, notably starter rarity, remain zero.

| Threshold | Distribution |
|---|---|
| `cardDecline` | continuous uniform [0, 40) |
| `removalAppetite` | continuous uniform [4, 28) |
| `removalMinCopies` | discrete uniform {1, 2, 3} |
| `shopMinRatio` | continuous uniform [0.01, 0.12) |
| `restHpPct` | discrete uniform integers 25–90 inclusive |
| `potionHealMissing` | discrete uniform integers 5–40 inclusive |
| `routeLowHpPct` | discrete uniform integers 25–90 inclusive |
| `shopGoldLow` | discrete uniform integers 0–90 inclusive |
| `shopGoldHigh` | discrete uniform integers 100–250 inclusive |
The disjoint gold ranges preserve `shopGoldLow < shopGoldHigh`. These are the first-sweep distributions, not permanent balance constants.
## Four control arms
Random build uses only the run's seeded `run.rng`: equal weight per reachable route, per legal offered card/relic, and per affordable shop item/removal plus one stop choice at each purchase step. Random play gives equal weight to every legal card-target pair. Event choice and rest behaviour stay planned because the signed arm definition names draft/shop/route. Each cell below is 200 runs; there were no stalls or errors.

| Arm | Build / play | Dusk V0 | Dusk V5 | Ash V0 | Ash V5 |
|---:|---|---:|---:|---:|---:|
| 1 | planned / competent | 129/200 (64.5%) | 64/200 (32.0%) | 149/200 (74.5%) | 84/200 (42.0%) |
| 2 | random / competent | 161/200 (80.5%) | 75/200 (37.5%) | 175/200 (87.5%) | 90/200 (45.0%) |
| 3 | planned / random | 95/200 (47.5%) | 27/200 (13.5%) | 147/200 (73.5%) | 86/200 (43.0%) |
| 4 | random / random | 84/200 (42.0%) | 20/200 (10.0%) | 149/200 (74.5%) | 51/200 (25.5%) |
Arm 2 beating arm 1 in both Vow-0 cells is measured, not a positive control: it makes C2 fail there and shows that the current planned build rules are not a credible strategy baseline.
## Frozen axes
Global empirical tertiles of all 320,000 final deck sizes freeze the x-axis: **thin = 8–25**, **mid = 26–35**, **fat = 36–60**. These cuts are not re-fitted per aspect or vow.
For each run, shatters/fight and smolder kills/fight are compared with that aspect's medians across both vows:

| Aspect | shatters/fight median | smolder kills/fight median |
|---|---:|---:|
| Duskblade | 1.1111 | 0.1111 |
| Ashwarden | 0.6154 | 0.8519 |
The ticket did not specify the both-above-median tie. The listed mechanical order is frozen here: Shatter-lean first, otherwise Smolder-lean, otherwise damage/attrition. Both were above median in 18,146 / 19,553 Dusk V0/V5 rows and 13,845 / 16,302 Ash V0/V5 rows. A future third axis may replace this rule; this sweep is not silently re-cut.
Cell format is **distinct policies; runs; win rate [Wilson 95% CI]**. Every cell is valid (at least 20 policies and 400 runs).

### Duskblade — Vow 0

| Win condition | Thin | Mid | Fat |
|---|---|---|---|
| Shatter-lean | 1,220; 7,329; 47.85% [46.71, 49.00] | 1,833; 13,381; 68.49% [67.70, 69.27] | 1,543; 20,090; **83.85%** [83.34, 84.36] |
| Smolder-lean | 1,639; 5,982; 6.29% [5.70, 6.93] | 1,705; 5,764; 25.36% [24.26, 26.50] | 1,187; 4,309; 68.86% [67.46, 70.22] |
| Damage/attrition | 1,803; 10,245; 6.85% [6.38, 7.36] | 1,819; 7,968; 28.94% [27.96, 29.95] | 1,286; 4,932; 70.11% [68.82, 71.38] |

### Duskblade — Vow 5

| Win condition | Thin | Mid | Fat |
|---|---|---|---|
| Shatter-lean | 1,920; 12,908; 9.77% [9.27, 10.29] | 1,928; 11,544; 39.89% [39.00, 40.79] | 1,536; 14,243; **73.05%** [72.31, 73.77] |
| Smolder-lean | 1,987; 14,120; 0.45% [0.36, 0.58] | 1,574; 4,948; 5.72% [5.11, 6.40] | 798; 1,564; 46.87% [44.40, 49.34] |
| Damage/attrition | 1,992; 15,310; 0.50% [0.40, 0.62] | 1,539; 4,188; 6.45% [5.74, 7.23] | 698; 1,175; 48.00% [45.15, 50.86] |

### Ashwarden — Vow 0

| Win condition | Thin | Mid | Fat |
|---|---|---|---|
| Shatter-lean | 1,200; 5,553; 47.52% [46.21, 48.84] | 1,858; 13,083; 67.46% [66.65, 68.26] | 1,609; 22,483; **86.32%** [85.87, 86.77] |
| Smolder-lean | 1,567; 7,560; 15.93% [15.12, 16.77] | 1,827; 9,471; 45.51% [44.51, 46.51] | 1,405; 6,467; 78.91% [77.90, 79.89] |
| Damage/attrition | 1,405; 4,714; 11.77% [10.88, 12.72] | 1,757; 6,312; 34.82% [33.66, 36.01] | 1,261; 4,357; 74.55% [73.23, 75.82] |

### Ashwarden — Vow 5

| Win condition | Thin | Mid | Fat |
|---|---|---|---|
| Shatter-lean | 1,900; 10,184; 10.95% [10.36, 11.57] | 1,947; 12,052; 35.39% [34.54, 36.25] | 1,544; 16,255; **75.16%** [74.49, 75.82] |
| Smolder-lean | 1,945; 15,451; 1.95% [1.74, 2.18] | 1,829; 7,862; 17.22% [16.40, 18.07] | 1,072; 2,759; 65.75% [63.96, 67.50] |
| Damage/attrition | 1,872; 8,585; 1.27% [1.05, 1.53] | 1,712; 5,115; 9.99% [9.20, 10.84] | 896; 1,737; 54.92% [52.57, 57.25] |
## C1/C2 verdicts
The viability floor is `(arm 2 + top cell) / 2` for the same aspect and vow.

| Grid | Top cell / rate | Cells within 10 pp | Floor / viable cells | Arm 2 / gap to top | C1a | C1b | C2 |
|---|---|---:|---:|---:|---|---|---|
| Dusk V0 | Shatter-fat 83.85% | 1 | 82.18%; 1 | 80.5%; 3.35 pp | **FAIL** | **FAIL** | **FAIL** |
| Dusk V5 | Shatter-fat 73.05% | 1 | 55.27%; 1 | 37.5%; 35.55 pp | **FAIL** | **FAIL** | **PASS** |
| Ash V0 | Shatter-fat 86.32% | 2 | 86.91%; 0 | 87.5%; −1.18 pp | **FAIL** | **FAIL** | **FAIL** |
| Ash V5 | Shatter-fat 75.16% | 2 | 60.08%; 2 | 45.0%; 30.16 pp | **FAIL** | **FAIL** | **FAIL** |
C1a requires at least three cells; C1b requires at least four. C2 requires both a gap of at least 35 pp and arm 2 below 50%. No under-sampled high-scoring cell exists, so no top-up was permitted or needed.
No sampled policy exceeded 90% at Vow 5: maxima were Dusk **85.0%** (policy 1971, 34/40) and Ash **87.5%** (policy 109, 35/40). Report-only Vow-0 maxima were Dusk **97.5%** (policy 846) and Ash **100%** (policy 109).
## Top-decile auditor
Each row compares the top 200 of 2,000 policies with the other 1,800, using per-policy win rate over the same 40 seeds. Values are median top/rest.

| Grid (top-decile cutoff) | Largest recurring magnitude shifts | Largest threshold shifts |
|---|---|---|
| Dusk V0 (75.0%) | draw/energy 2.39×; regen 1.77×; Hollow Crown 1.65×; rare rarity 0.61× | `cardDecline` 13.97/20.42; `restHpPct` 66/56 |
| Dusk V5 (40.0%) | draw/energy 2.51×; regen 2.15×; Hollow Crown 1.69×; rare rarity 0.60× | `cardDecline` 13.92/20.45; `restHpPct` 62/57 |
| Ash V0 (82.5%) | draw/energy 2.11×; regen 1.78×; ritual 0.59×; rare rarity 0.60× | `restHpPct` 69/56; `cardDecline` 15.83/20.12 |
| Ash V5 (50.0%) | draw/energy 2.47×; regen 2.17×; common rarity 1.69×; power 0.59× | `restHpPct` 68/56; `cardDecline` 13.68/20.48 |
The common fingerprint is high draw/energy and regen valuation, lower decline thresholds (fatter decks), and higher rest thresholds. This agrees with all four top cells being fat and is evidence of collapse inside this grammar, not of a universal optimum.
## Raw data and replay key
The completed streaming sweep took **4,004 seconds (66 min 44 s)** on ten Godot processes. Host contention made it slower than the ticket's ~16-minute estimate. Each shard contains one manifest line followed by 32,000 JSON run lines: Shard manifests name `529d2b4` as the worktree base; exact replay also requires this Slice C diff/commit.

- shards: `/private/tmp/glassvow-215-slice-c/sweep/shard-0.ndjson` through `shard-9.ndjson` (177–178 MB each);
- merged dataset: `/private/tmp/glassvow-215-slice-c/sweep/merged.ndjson` (320,001 lines, 1.7 GB);
- analysis: `/private/tmp/glassvow-215-slice-c/sweep/analysis.json`;
- controls: `/private/tmp/glassvow-215-slice-c/controls/merged.json`;
- pre-flight: `/private/tmp/glassvow-215-slice-c/preflight/preflight.json` and `analysis.json`.
To replay a row, retain the source commit/content hash, `aspect`, `vow`, `seed`, `policyIndex`, sampler root seed **215**, and the row's resolved `policy`. `BalancePolicy.sample_range(215, policyIndex, 1)[0]` must equal that vector. Then call `BalanceSim.simulate(content, aspect, seed, vow, PackedStringArray(), policy)`. To replay every row for one policy through the CLI, run `balance_sweep.gd` with `--policyFirst=POLICY_INDEX --policyCount=1 --seeds=40 --seed0=3000 --rootSeed=215`; all flags follow the bare `--` and use `--name=value`.

## What a negative result claims — and what it does not
The following is copied verbatim from #213 §8.

**Does not claim** — and every one of these goes into the doc verbatim:

1. **No degenerate strategy exists.** Untestable universal negative. What is measured is landscape shape.
2. **Combo-shaped lines are unsearched** until C fires — cross-turn holds, target selection, Art timing.
3. Anything outside the pilot's grammar even after Tier 1 — deliberate losing/farming, multi-turn intent reading beyond the one-turn forecast (`_incoming`).
4. **Nothing about where human players sit.** James settled Q4: **no numeric human anchor.** Humans report "easy / fun / hard" and nothing more precise unless a purpose-built scientific test is made — which is a separate ticket, not this one. So the CEM ladder's rungs measure *distance from the optimum inside the grammar*, never *player skill*, and no rung may be labelled "human". The gen-0 → ceiling gap is reported as skill headroom precisely because it needs no human anchor to be meaningful.
