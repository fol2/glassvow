# Strategy landscape — Slice C — 2026-08-14
**Live-SHA re-run:** [fol2/glassvow#412](https://github.com/fol2/glassvow/issues/412) measured content SHA `736090f18546738a2e38b756d81f6ad715a808c4ea321220443f839862cdb102` on 2026-08-19. Holdout readout: [`2026-08-19-strategy-landscape.md`](2026-08-19-strategy-landscape.md). This file is the original #215 / #216 measurement on SHA `63340823…` and is not rewritten.
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
- analysis: `/private/tmp/glassvow-215-slice-c/sweep/analysis.json`, produced by `tools/balance_landscape.py` (committed; re-run it on the RC content SHA for the rc-bar pillar);
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

## Layer 2 — CEM islands — 2026-08-14
Issue: [fol2/glassvow#216](https://github.com/fol2/glassvow/issues/216). 24 islands (2 aspects × vows {0, 5} × 6), population 60, elite 15, up to 20 generations, 40 common-random-number training seeds per generation (`4200 + g×40 … +39`; never ≥5000). Published ceilings are holdout seeds **5000–5199** (200 runs). Godot `4.7.1-stable (official)`, content SHA-256 `633408231840d4ba47e0680d1969982cdf1ded1a61213a51bfd2bdab00f35155` (same as layer 1). CEM Gaussians are Box–Muller over `Rng(216 + island ordinal)`; no engine `randf`/`randi`.
Wall clock **15,067 s (4 h 11 min 7 s)** on ten Godot processes, all 24 islands exit 0. Per-run cost under this contention was ~150 ms (layer 1 on the same host was ~125 ms/run, against the ticket's 25–35 ms). Manifests name worktree base `30669b4`; replay also needs this #216 driver commit.
### Seeding (orchestrator, from layer-1 raw)
The ticket asked for one island per viable cell. Layer 1 found 0–2 viable cells per grid, so the orchestrator seeded **the top-6 cells by win rate with ≥20 policies**. Representative `policyIndex` = highest in-cell per-policy win rate, ties to lower index. Seed vector = `BalancePolicy.sample_range(215, policyIndex, 1)[0]`. Table copied from `/private/tmp/glassvow-216-layer2/island-seeds.json`.

| Grid | Island | Cell | Layer-1 cell rate | policyIndex | in-cell rep rate (n) |
|---|---:|---|---:|---:|---|
| Dusk V0 | 0 | shatter:fat | 83.85% | 18 | 1.000 (18) |
| Dusk V0 | 1 | attrition:fat | 70.11% | 61 | 1.000 (10) |
| Dusk V0 | 2 | smolder:fat | 68.86% | 135 | 0.938 (16) |
| Dusk V0 | 3 | shatter:mid | 68.49% | 26 | 1.000 (10) |
| Dusk V0 | 4 | shatter:thin | 47.85% | 703 | 0.968 (31) |
| Dusk V0 | 5 | attrition:mid | 28.94% | 797 | 1.000 (14) |
| Dusk V5 | 6 | shatter:fat | 73.05% | 80 | 1.000 (19) |
| Dusk V5 | 7 | attrition:fat | 48.00% | 18 | 1.000 (5) |
| Dusk V5 | 8 | smolder:fat | 46.87% | 1800 | 0.600 (10) |
| Dusk V5 | 9 | shatter:mid | 39.89% | 846 | 1.000 (14) |
| Dusk V5 | 10 | shatter:thin | 9.77% | 1633 | 0.684 (19) |
| Dusk V5 | 11 | attrition:mid | 6.45% | 1611 | 0.000 (10) |
| Ash V0 | 12 | shatter:fat | 86.32% | 2 | 1.000 (13) |
| Ash V0 | 13 | smolder:fat | 78.91% | 64 | 1.000 (14) |
| Ash V0 | 14 | attrition:fat | 74.55% | 789 | 1.000 (12) |
| Ash V0 | 15 | shatter:mid | 67.46% | 9 | 1.000 (17) |
| Ash V0 | 16 | shatter:thin | 47.52% | 506 | 1.000 (24) |
| Ash V0 | 17 | smolder:mid | 45.51% | 78 | 1.000 (11) |
| Ash V5 | 18 | shatter:fat | 75.16% | 0 | 1.000 (12) |
| Ash V5 | 19 | smolder:fat | 65.75% | 926 | 1.000 (11) |
| Ash V5 | 20 | attrition:fat | 54.92% | 254 | 1.000 (5) |
| Ash V5 | 21 | shatter:mid | 35.39% | 285 | 1.000 (10) |
| Ash V5 | 22 | smolder:mid | 17.22% | 846 | 1.000 (12) |
| Ash V5 | 23 | shatter:thin | 10.95% | 1964 | 0.846 (13) |

Islands are unconstrained after seeding. End cell = majority cell over the 200 holdout rows, using layer 1's frozen deck cuts (thin ≤25, mid ≤35) and per-aspect shatters/smolder medians. Tie-break is `Counter.most_common` (higher count; ties keep the first-seen key — none tied here).
### Drift map, holdout ceilings, fitness curves
Holdout is wins/200 on seeds 5000–5199. `bestEver` is **training** fitness on that generation's 40 seeds and is shown only as the convergence curve; it is not a ceiling. Floor = layer-1 midpoint(arm 2, top cell).

#### Duskblade — Vow 0 — floor 82.18%

| Isl | start → end (holdout majority) | holdout | gens / stop | wall | bestEver by gen |
|---:|---|---:|---|---:|---|
| 0 | shatter:fat → shatter:fat (159/200) | **196/200 (98.0%)** | 15 stall | 5708 s | .85 .85 .85 .93 .98 .98 .98 .98 .98 1.0 1.0 1.0 1.0 1.0 1.0 |
| 1 | attrition:fat → attrition:mid (72) | 170/200 (85.0%) | 6 stall | 2266 s | .98 .98 .98 .98 .98 .98 |
| 2 | smolder:fat → shatter:fat (93) | 188/200 (94.0%) | 16 stall | 7416 s | .75 .80 .83 .90 .90 .90 .93 .95 .95 .98 1.0 1.0 1.0 1.0 1.0 1.0 |
| 3 | shatter:mid → shatter:thin (162) | 193/200 (96.5%) | 7 stall | 2351 s | .95 1.0 1.0 1.0 1.0 1.0 1.0 |
| 4 | shatter:thin → shatter:thin (140) | 181/200 (90.5%) | 6 stall | 1992 s | 1.0 1.0 1.0 1.0 1.0 1.0 |
| 5 | attrition:mid → shatter:fat (123) | 183/200 (91.5%) | 10 stall | 4533 s | .90 .90 .98 .98 1.0 1.0 1.0 1.0 1.0 1.0 |

Stayed in start cell with holdout ≥ floor: islands 0 and 4 (2). Close to best ceiling (98.0%) within 15 pp: both. **C3 FAIL.** End-cell ceilings: shatter:fat 98.0%, shatter:thin 96.5%, attrition:mid 85.0%. Best−second = 1.5 pp. **C4 PASS.**

#### Duskblade — Vow 5 — floor 55.27%

| Isl | start → end | holdout | gens / stop | wall | bestEver by gen |
|---:|---|---:|---|---:|---|
| 6 | shatter:fat → shatter:fat (167) | 168/200 (84.0%) | 20 maxGen | 8463 s | .78 .80 .83 .90 .93 .93 .93 .95 .95 .95 .95 .95 .98 .98 .98 .98 .98 1.0 1.0 1.0 |
| 7 | attrition:fat → shatter:fat (128) | 124/200 (62.0%) | 16 stall | 5008 s | .48 .48 .58 .60 .60 .60 .60 .60 .70 .70 .73 .73 .73 .73 .73 .73 |
| 8 | smolder:fat → shatter:fat (153) | 166/200 (83.0%) | 18 stall | 7614 s | .58 .58 .80 .83 .83 .83 .83 .88 .93 .93 .93 .95 .98 .98 .98 .98 .98 .98 |
| 9 | shatter:mid → shatter:mid (86) | 132/200 (66.0%) | 7 stall | 2403 s | .90 .93 .93 .93 .93 .93 .93 |
| 10 | shatter:thin → shatter:thin (106) | 126/200 (63.0%) | 17 stall | 5570 s | .60 .65 .65 .65 .73 .73 .73 .75 .75 .75 .75 .83 .83 .83 .83 .83 .83 |
| 11 | attrition:mid → shatter:fat (176) | **182/200 (91.0%)** | 20 maxGen | 10362 s | .48 .63 .63 .68 .73 .73 .73 .78 .85 .88 .88 .95 .95 .95 .95 .95 .98 .98 .98 .98 |

Stayed ≥ floor: 6, 9, 10 (3). Close to best (91.0%) within 15 pp: island 6 only. **C3 FAIL.** End-cell ceilings: shatter:fat 91.0%, shatter:mid 66.0%, shatter:thin 63.0%. Best−second = 25.0 pp. **C4 FAIL.** Island 11 holdout **91.0% > 90%**. **Vow-5 ceiling FAIL** (fail-closed).

#### Ashwarden — Vow 0 — floor 86.91%

| Isl | start → end | holdout | gens / stop | wall | bestEver by gen |
|---:|---|---:|---|---:|---|
| 12 | shatter:fat → shatter:mid (78) | 185/200 (92.5%) | 10 stall | 3609 s | .83 .95 .95 .95 1.0 1.0 1.0 1.0 1.0 1.0 |
| 13 | smolder:fat → shatter:fat (157) | 191/200 (95.5%) | 12 stall | 4670 s | .85 .93 .95 .95 .98 .98 1.0 1.0 1.0 1.0 1.0 1.0 |
| 14 | attrition:fat → shatter:fat (131) | 188/200 (94.0%) | 9 stall | 3436 s | .90 .95 .98 1.0 1.0 1.0 1.0 1.0 1.0 |
| 15 | shatter:mid → shatter:mid (118) | 191/200 (95.5%) | 6 stall | 2299 s | 1.0 1.0 1.0 1.0 1.0 1.0 |
| 16 | shatter:thin → shatter:thin (114) | **196/200 (98.0%)** | 7 stall | 2873 s | .98 1.0 1.0 1.0 1.0 1.0 1.0 |
| 17 | smolder:mid → shatter:thin (47; next 44, 39) | 184/200 (92.0%) | 9 stall | 4300 s | .93 .98 .98 1.0 1.0 1.0 1.0 1.0 1.0 |

Stayed ≥ floor: 15 and 16 (2). Close to best (98.0%) within 15 pp: both. **C3 FAIL.** End-cell ceilings: shatter:thin 98.0%, shatter:fat 95.5%, shatter:mid 95.5%. Best−second = 2.5 pp. **C4 PASS.** Vow 0 is report-only.

#### Ashwarden — Vow 5 — floor 60.08%

| Isl | start → end | holdout | gens / stop | wall | bestEver by gen |
|---:|---|---:|---|---:|---|
| 18 | shatter:fat → shatter:fat (130) | 120/200 (60.0%) | 20 maxGen | 7256 s | .50 .53 .55 .55 .68 .68 .68 .68 .68 .70 .70 .80 .80 .80 .80 .83 .83 .88 .88 .88 |
| 19 | smolder:fat → shatter:fat (144) | **188/200 (94.0%)** | 14 stall | 7271 s | .78 .93 .93 .98 .98 .98 .98 .98 1.0 1.0 1.0 1.0 1.0 1.0 |
| 20 | attrition:fat → shatter:fat (148) | 177/200 (88.5%) | 17 stall | 7470 s | .43 .63 .70 .75 .83 .85 .85 .90 .95 .95 .95 1.0 1.0 1.0 1.0 1.0 1.0 |
| 21 | shatter:mid → shatter:mid (87) | 152/200 (76.0%) | 13 stall | 6243 s | .68 .68 .73 .88 .88 .90 .90 .98 .98 .98 .98 .98 .98 |
| 22 | smolder:mid → shatter:mid (121) | 167/200 (83.5%) | 13 stall | 6312 s | .78 .83 .85 .93 .93 .95 .95 .98 .98 .98 .98 .98 .98 |
| 23 | shatter:thin → shatter:thin (100) | 149/200 (74.5%) | 18 stall | 7098 s | .85 .88 .90 .90 .90 .93 .93 .95 .95 .95 .95 .95 .98 .98 .98 .98 .98 .98 |

Stayed ≥ floor: 18 (60.0% kisses the floor) and 23 (2). Close to best (94.0%) within 15 pp: neither (18 is 34 pp behind; 23 is 19.5 pp behind). **C3 FAIL.** End-cell ceilings: shatter:fat 94.0%, shatter:mid 83.5%, shatter:thin 74.5%. Best−second = 10.5 pp. **C4 PASS.** Island 19 holdout **94.0% > 90%**. **Vow-5 ceiling FAIL** (fail-closed).
### Verdicts
| Grid | C3 | C4 | Vow-5 >90% | Skill headroom (holdout ceiling − gen-0 median) |
|---|---|---|---|---|
| Dusk V0 | **FAIL** (2 stayed) | **PASS** (1.5 pp) | n/a (report-only; 98.0%) | 5.50 pp (92.5% → 98.0%) |
| Dusk V5 | **FAIL** (3 stayed, 1 close) | **FAIL** (25.0 pp) | **FAIL** (91.0%) | 32.25 pp (58.75% → 91.0%) |
| Ash V0 | **FAIL** (2 stayed) | **PASS** (2.5 pp) | n/a (report-only; 98.0%) | 6.75 pp (91.25% → 98.0%) |
| Ash V5 | **FAIL** (2 stayed, 0 close) | **PASS** (10.5 pp) | **FAIL** (94.0%) | 21.50 pp (72.5% → 94.0%) |

Island drift is the primary signal: 13 of 24 islands left their start cell; 11 of those 13 landed in a shatter cell (9 shatter:fat, 2 shatter:mid/thin). That is the "optimisation has one destination" signature on this grammar, measured without a human anchor.
Median generations until stop: 13 (range 6–20). Stop reasons: 21 stall, 3 maxGen (islands 6, 11, 18).
### Replay key
- Content SHA and Godot as in the island manifest line.
- Seed policy: `BalancePolicy.sample_range(215, policyIndex, 1)[0]` with `policyIndex` from the seeding table.
- CEM draws: `Rng.new(216 + island)` , island ordinal 0–23 as in the table (Dusk V0, Dusk V5, Ash V0, Ash V5 × local 0–5).
- Converged vector: the `policy` field of the `{"t":"final"}` row in `/private/tmp/glassvow-216-layer2/island-NN.ndjson`.
- Holdout replay: `BalanceSim.simulate(content, aspect, seed, vow, PackedStringArray(), policy)` for seed in 5000–5199.
- Readout: `python3 tools/balance_cem_report.py /private/tmp/glassvow-216-layer2 /private/tmp/glassvow-215-slice-c/sweep/analysis.json OUT.json`.
Driver: `tools/balance_cem.gd`. Analysis JSON: `/private/tmp/glassvow-216-layer2/analysis.json`.
### Tier 2 stays open
Cross-turn card holding, target selection and Art timing are not searched by this layer; they belong to a combat-lookahead escalation that is **triggered, not committed** (#213 §7 names the three triggers). This layer does not claim those lines were searched.
### Decisions beyond the brief
- Elite count is `min(15, popSize)` so the smoke (`popSize=6`) still refits.
- `σ` floor 0.02 applies at elite refit, not to the initial σ.
- Integer thresholds are Gaussian-sampled then `round` + clamp onto the layer-1 ranges.
- C4 is computed on **end-cell** ceilings (max holdout of islands that landed there). A grid whose islands occupy only one end cell fails C4 (vacuous "exceeds every other").
- C3's "best ceiling" is the grid's best holdout, including islands that drifted.
- Gen-0 median uses `statistics.median` (mean of the two central values when n=6).
- Manifest `commit` is `30669b4` because the driver was uncommitted during the sweep.
