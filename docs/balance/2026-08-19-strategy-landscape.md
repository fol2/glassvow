# Strategy landscape — live SHA re-run — 2026-08-19

Issue: [fol2/glassvow#412](https://github.com/fol2/glassvow/issues/412). This ticket **measures**. It does not retune. Protocol, arm definitions, sampling distributions, and C1–C4 / Vow-5 gates are those of [`2026-08-14-strategy-landscape.md`](2026-08-14-strategy-landscape.md) (#215 / #216). This file is the dated sibling so the 2026-08-14 readout stays intact.

**Hypothesis-1 retune:** [fol2/glassvow#421](https://github.com/fol2/glassvow/issues/421) measured content SHA `c96ed73196eafaec6c68cca27f0dafd784e810278d53d07fd995d3bd20f446aa` on 2026-08-19. Readout: [`2026-08-19-421-hypothesis-1.md`](2026-08-19-421-hypothesis-1.md). This file stays the #412 measurement on SHA `736090f1…` and is not rewritten.

Content SHA-256 (`FileAccess.get_sha256` of `res://content/full-content.json`):
`736090f18546738a2e38b756d81f6ad715a808c4ea321220443f839862cdb102`.
Game-under-test commit `101e7d956bda30848399aa02833e09cbe339495e`.
Godot used: `4.7.2-stable (official)` at `/opt/homebrew/bin/godot` (project pin remains 4.7.1; this host's installed binary is 4.7.2).
Live shipping mix `A_modest_linear` (no `--mix`). Sampler root **215**. CEM root **216**.

Every published ceiling below is **holdout-only** (seeds 5000–5199). Training-seed fitness is shown only as a convergence curve.

## Layer 1 — sampled plurality

2,000 sampled policies, 40 common run seeds (3000–3039), both aspects × vows {0, 5}. Four control arms use seeds 4000–4199. The sweep retained 320,000 rows: **121,494** wins, **198,490** losses, **16** stalls (counted as non-wins), and zero errors.

Layer-1 wall **2,571 s (42 min 51 s)** on ten Godot processes. Shard manifests name commit `101e7d9` and the content SHA above.

### Four control arms

Random build / random play as defined in the 2026-08-14 doc. Each cell is 200 runs; there were no stalls or errors.

| Arm | Build / play | Dusk V0 | Dusk V5 | Ash V0 | Ash V5 |
|---:|---|---:|---:|---:|---:|
| 1 | planned / competent | 178/200 (89.0%) | 114/200 (57.0%) | 185/200 (92.5%) | 136/200 (68.0%) |
| 2 | random / competent | 175/200 (87.5%) | 87/200 (43.5%) | 176/200 (88.0%) | 114/200 (57.0%) |
| 3 | planned / random | 146/200 (73.0%) | 59/200 (29.5%) | 181/200 (90.5%) | 119/200 (59.5%) |
| 4 | random / random | 117/200 (58.5%) | 42/200 (21.0%) | 148/200 (74.0%) | 84/200 (42.0%) |

Arm 2 still beats or matches the planned-build top cell in both Vow-0 grids (see C2). That is measured, not a positive control.

### Frozen axes (this sweep)

Global empirical tertiles of these 320,000 final deck sizes: **thin = 8–24**, **mid = 25–34**, **fat = 35–60**. Fitted on this sweep, not inherited from the 2026-08-14 cuts (then thin ≤25 / mid ≤35).

Per-aspect medians across both vows:

| Aspect | shatters/fight median | smolder kills/fight median |
|---|---:|---:|
| Duskblade | 1.0714 | 0.1111 |
| Ashwarden | 0.5714 | 0.8462 |

Both-above-median tie uses the same mechanical order as 2026-08-14: Shatter-lean first, otherwise Smolder-lean, otherwise damage/attrition. Both were above median in 19,709 / 17,517 Dusk V0/V5 rows and 16,531 / 13,538 Ash V0/V5 rows.

Cell format is **distinct policies; runs; win rate [Wilson 95% CI]**. Every cell is valid (≥20 policies and ≥400 runs).

### Duskblade — Vow 0

| Win condition | Thin | Mid | Fat |
|---|---|---|---|
| Shatter-lean | 1,273; 7,133; 42.17% [41.03, 43.32] | 1,840; 14,350; 65.52% [64.74, 66.29] | 1,635; 23,268; **82.82%** [82.33, 83.30] |
| Smolder-lean | 1,543; 5,014; 4.71% [4.15, 5.33] | 1,714; 5,540; 19.80% [18.77, 20.87] | 1,183; 3,938; 65.44% [63.94, 66.91] |
| Damage/attrition | 1,723; 8,618; 5.04% [4.59, 5.52] | 1,808; 7,683; 23.35% [22.42, 24.31] | 1,281; 4,456; 66.67% [65.28, 68.04] |

### Duskblade — Vow 5

| Win condition | Thin | Mid | Fat |
|---|---|---|---|
| Shatter-lean | 1,949; 11,085; 4.95% [4.56, 5.37] | 1,937; 10,396; 29.54% [28.67, 30.42] | 1,735; 13,704; **68.99%** [68.21, 69.76] |
| Smolder-lean | 1,993; 14,519; 0.08% [0.04, 0.14] | 1,746; 6,221; 2.22% [1.88, 2.61] | 893; 1,663; 36.68% [34.40, 39.03] |
| Damage/attrition | 1,988; 15,253; 0.18% [0.12, 0.26] | 1,760; 5,738; 3.05% [2.64, 3.53] | 851; 1,421; 37.72% [35.24, 40.27] |

### Ashwarden — Vow 0

| Win condition | Thin | Mid | Fat |
|---|---|---|---|
| Shatter-lean | 1,178; 5,403; 42.46% [41.15, 43.78] | 1,894; 14,282; 64.00% [63.21, 64.79] | 1,683; 26,177; **85.35%** [84.92, 85.77] |
| Smolder-lean | 1,463; 6,182; 12.96% [12.14, 13.82] | 1,819; 9,086; 40.69% [39.68, 41.70] | 1,444; 6,240; 76.70% [75.63, 77.73] |
| Damage/attrition | 1,210; 3,563; 8.73% [7.85, 9.70] | 1,720; 5,536; 29.08% [27.90, 30.29] | 1,199; 3,531; 71.06% [69.54, 72.53] |

### Ashwarden — Vow 5

| Win condition | Thin | Mid | Fat |
|---|---|---|---|
| Shatter-lean | 1,844; 7,126; 6.19% [5.65, 6.77] | 1,948; 10,730; 26.07% [25.25, 26.91] | 1,788; 15,039; **71.23%** [70.50, 71.95] |
| Smolder-lean | 1,970; 14,741; 0.69% [0.56, 0.83] | 1,896; 9,446; 9.31% [8.74, 9.91] | 1,354; 3,830; 58.46% [56.89, 60.01] |
| Damage/attrition | 1,917; 9,362; 0.35% [0.25, 0.49] | 1,851; 7,336; 4.02% [3.60, 4.50] | 1,161; 2,390; 47.95% [45.95, 49.95] |

## C1/C2 verdicts

The viability floor is `(arm 2 + top cell) / 2` for the same aspect and vow. C1a requires at least three cells within 10 pp of the top; C1b requires at least four cells at or above the floor; C2 requires both a gap of at least 35 pp and arm 2 below 50%.

| Grid | Top cell / rate | Cells within 10 pp | Floor / viable cells | Arm 2 / gap to top | C1a | C1b | C2 |
|---|---|---:|---:|---:|---|---|---|
| Dusk V0 | Shatter-fat 82.82% | 1 | 85.16%; 0 | 87.5%; −4.68 pp | **FAIL** | **FAIL** | **FAIL** |
| Dusk V5 | Shatter-fat 68.99% | 1 | 56.24%; 1 | 43.5%; 25.49 pp | **FAIL** | **FAIL** | **FAIL** |
| Ash V0 | Shatter-fat 85.35% | 2 | 86.67%; 0 | 88.0%; −2.65 pp | **FAIL** | **FAIL** | **FAIL** |
| Ash V5 | Shatter-fat 71.23% | 1 | 64.11%; 1 | 57.0%; 14.23 pp | **FAIL** | **FAIL** | **FAIL** |

No under-sampled high-scoring cell exists, so no top-up was permitted or needed.

No sampled policy exceeded 90% at Vow 5: maxima were Dusk **80.0%** (policy 1971, 32/40) and Ash **87.5%** (policy 1822, 35/40). Report-only Vow-0 maxima were Dusk **97.5%** (policy 846, 39/40) and Ash **100%** (policy 109, 40/40). Those maxima are training-seed rates on 3000–3039 and are **not** published ceilings.

## Top-decile auditor

Each row compares the top 200 of 2,000 policies with the other 1,800, using per-policy win rate over the same 40 seeds. Values are median top/rest.

| Grid (top-decile cutoff) | Largest recurring magnitude shifts | Largest threshold shifts |
|---|---|---|
| Dusk V0 (75.0%) | draw/energy 2.39×; regen 1.77×; Hollow Crown 1.65×; rare rarity 0.61× | `cardDecline` 13.97/20.42; `restHpPct` 66/56 |
| Dusk V5 (35.0%) | draw/energy 2.38×; regen 1.96×; Hollow Crown 1.79×; power 0.56× | `restHpPct` 65.5/56; `cardDecline` 15.44/20.16 |
| Ash V0 (82.5%) | draw/energy 2.11×; regen 1.78×; ritual 0.59×; rare rarity 0.60× | `restHpPct` 69/56; `cardDecline` 15.83/20.12 |
| Ash V5 (45.0%) | draw/energy 1.90×; regen 1.89×; power 0.54×; ritual 0.56× | `restHpPct` 68/56; `cardDecline` 16.95/19.87 |

The common fingerprint is still high draw/energy and regen valuation, lower decline thresholds (fatter decks), and higher rest thresholds. All four top cells are shatter-fat.

## Layer 1 raw data and replay key

- shards: `/private/tmp/glassvow-412-landscape/sweep/shard-0.ndjson` through `shard-9.ndjson`;
- merged dataset: `/private/tmp/glassvow-412-landscape/sweep/merged.ndjson` (320,001 lines);
- analysis (committed): `docs/balance/data/412/layer1-analysis.json`;
- controls (committed): `docs/balance/data/412/controls.json`.

To replay a row, retain this content SHA, `aspect`, `vow`, `seed`, `policyIndex`, sampler root seed **215**, and the row's resolved `policy`. `BalancePolicy.sample_range(215, policyIndex, 1)[0]` must equal that vector. Then call `BalanceSim.simulate(content, aspect, seed, vow, PackedStringArray(), policy)`. CLI: `balance_sweep.gd` with `--policyFirst=POLICY_INDEX --policyCount=1 --seeds=40 --seed0=3000 --rootSeed=215` (all flags after `--`, `--name=value`). Live mix is the default; do not pass `--mix=none` unless as a labelled control.

## Layer 2 — CEM islands

24 islands (2 aspects × vows {0, 5} × 6), population 60, elite 15, up to 20 generations, 40 CRN training seeds per generation (`4200 + g×40 … +39`; never ≥5000). Published ceilings are holdout seeds **5000–5199** (200 runs). CEM Gaussians are Box–Muller over `Rng(216 + island ordinal)`.

Wall clock: first session 13:21–16:34 BST (islands 00–19, 22, 23 `final`; 20 and 21 killed mid-run, overwritten). Resume 16:42–18:08 BST, islands 20 and 21 only, **5,176 s**. CEM has no intra-island resume. All 24 islands exit 0. Per-island `ms` is that process's own clock.

Seeding table (top-6 cells by layer-1 win rate with ≥20 policies). Representative `policyIndex` = highest in-cell per-policy win rate, ties to lower index. Copied from `docs/balance/data/412/island-seeds.json`.

| Grid | Island | Cell | Layer-1 cell rate | policyIndex | in-cell rep rate (n) |
|---|---:|---|---:|---:|---|
| Dusk V0 | 0 | shatter:fat | 82.82% | 2 | 1.000 (5) |
| Dusk V0 | 1 | attrition:fat | 66.67% | 3 | 1.000 (1) |
| Dusk V0 | 2 | shatter:mid | 65.52% | 20 | 1.000 (6) |
| Dusk V0 | 3 | smolder:fat | 65.44% | 0 | 1.000 (1) |
| Dusk V0 | 4 | shatter:thin | 42.17% | 159 | 1.000 (4) |
| Dusk V0 | 5 | attrition:mid | 23.35% | 24 | 1.000 (1) |
| Dusk V5 | 6 | shatter:fat | 68.99% | 2 | 1.000 (9) |
| Dusk V5 | 7 | attrition:fat | 37.72% | 3 | 1.000 (1) |
| Dusk V5 | 8 | smolder:fat | 36.68% | 10 | 1.000 (1) |
| Dusk V5 | 9 | shatter:mid | 29.54% | 20 | 1.000 (5) |
| Dusk V5 | 10 | shatter:thin | 4.95% | 393 | 0.750 (28) |
| Dusk V5 | 11 | attrition:mid | 3.05% | 26 | 1.000 (1) |
| Ash V0 | 12 | shatter:fat | 85.35% | 2 | 1.000 (16) |
| Ash V0 | 13 | smolder:fat | 76.70% | 7 | 1.000 (3) |
| Ash V0 | 14 | attrition:fat | 71.06% | 7 | 1.000 (1) |
| Ash V0 | 15 | shatter:mid | 64.00% | 1 | 1.000 (3) |
| Ash V0 | 16 | shatter:thin | 42.46% | 46 | 1.000 (2) |
| Ash V0 | 17 | smolder:mid | 40.69% | 1 | 1.000 (2) |
| Ash V5 | 18 | shatter:fat | 71.23% | 19 | 1.000 (6) |
| Ash V5 | 19 | smolder:fat | 58.46% | 4 | 1.000 (2) |
| Ash V5 | 20 | attrition:fat | 47.95% | 6 | 1.000 (3) |
| Ash V5 | 21 | shatter:mid | 26.07% | 65 | 1.000 (1) |
| Ash V5 | 22 | smolder:mid | 9.31% | 24 | 1.000 (1) |
| Ash V5 | 23 | shatter:thin | 6.19% | 1161 | 1.000 (1) |

Islands are unconstrained after seeding. End cell = majority cell over the 200 holdout rows, using this sweep's deck cuts (thin ≤24, mid ≤34) and per-aspect shatters/smolder medians. Tie-break is `Counter.most_common`.

### Drift map, holdout ceilings, fitness curves

Holdout is wins/200 on seeds 5000–5199. `bestEver` is **training** fitness on that generation's 40 seeds and is shown only as the convergence curve; it is not a ceiling. Floor = layer-1 midpoint(arm 2, top cell).

#### Duskblade — Vow 0 — floor 85.16%

| Isl | start → end (holdout majority) | holdout | gens / stop | wall | bestEver by gen |
|---:|---|---:|---|---:|---|
| 0 | shatter:fat → shatter:fat (83) | 158/200 (79.0%) | 7 stall | 1556 s | .88 .97 .97 .97 .97 .97 .97 |
| 1 | attrition:fat → shatter:fat (186) | 178/200 (89.0%) | 13 stall | 4037 s | .75 .78 .88 .90 .90 .90 .95 1.0 1.0 1.0 1.0 1.0 1.0 |
| 2 | shatter:mid → shatter:fat (89) | 179/200 (89.5%) | 16 stall | 5611 s | .68 .82 .88 .93 .93 .95 .95 .95 .95 .95 1.0 1.0 1.0 1.0 1.0 1.0 |
| 3 | smolder:fat → shatter:fat (180) | 181/200 (90.5%) | 16 stall | 4039 s | .88 .88 .93 .93 .95 .95 .95 .97 .97 .97 1.0 1.0 1.0 1.0 1.0 1.0 |
| 4 | shatter:thin → shatter:mid (149) | **184/200 (92.0%)** | 15 stall | 3971 s | .72 .85 .88 .88 .95 .95 .95 .97 .97 1.0 1.0 1.0 1.0 1.0 1.0 |
| 5 | attrition:mid → shatter:mid (124) | 155/200 (77.5%) | 14 stall | 3717 s | .60 .72 .72 .80 .88 .88 .88 .88 .95 .95 .95 .95 .95 .95 |

Stayed in start cell with holdout ≥ floor: none (island 0 stayed but 79.0% is below 85.16%). Close to best (92.0%) within 15 pp: none of the stayed-viable set. **C3 FAIL.** End-cell ceilings: shatter:mid 92.0%, shatter:fat 90.5%. Best−second = 1.5 pp. **C4 PASS.**

#### Duskblade — Vow 5 — floor 56.24%

| Isl | start → end | holdout | gens / stop | wall | bestEver by gen |
|---:|---|---:|---|---:|---|
| 6 | shatter:fat → shatter:fat (112) | 124/200 (62.0%) | 11 stall | 2731 s | .57 .60 .65 .65 .78 .82 .82 .82 .82 .82 .82 |
| 7 | attrition:fat → shatter:fat (170) | 156/200 (78.0%) | 20 maxGen | 5619 s | .38 .38 .38 .40 .47 .53 .68 .72 .78 .78 .82 .85 .85 .85 .88 .88 .90 .97 .97 .97 |
| 8 | smolder:fat → shatter:fat (127) | 148/200 (74.0%) | 14 stall | 3219 s | .47 .47 .50 .60 .68 .68 .75 .80 .88 .88 .88 .88 .88 .88 |
| 9 | shatter:mid → shatter:fat (54) | 114/200 (57.0%) | 14 stall | 3669 s | .40 .50 .53 .62 .70 .70 .70 .72 .85 .85 .85 .85 .85 .85 |
| 10 | shatter:thin → shatter:mid (107) | 141/200 (70.5%) | 7 stall | 2178 s | .72 .88 .88 .88 .88 .88 .88 |
| 11 | attrition:mid → shatter:mid (141) | **166/200 (83.0%)** | 18 stall | 4559 s | .75 .82 .82 .82 .85 .85 .85 .88 .90 .90 .90 .93 .95 .95 .95 .95 .95 .95 |

Stayed ≥ floor: island 6 only (1). Close to best (83.0%) within 15 pp: none (island 6 is 21.0 pp behind). **C3 FAIL.** End-cell ceilings: shatter:mid 83.0%, shatter:fat 78.0%. Best−second = 5.0 pp. **C4 PASS.** Best holdout **83.0% ≤ 90%**. **Vow-5 ceiling PASS** (fail-closed).

#### Ashwarden — Vow 0 — floor 86.67%

| Isl | start → end | holdout | gens / stop | wall | bestEver by gen |
|---:|---|---:|---|---:|---|
| 12 | shatter:fat → shatter:mid (74) | **185/200 (92.5%)** | 10 stall | 2875 s | .82 .95 .95 .95 1.0 1.0 1.0 1.0 1.0 1.0 |
| 13 | smolder:fat → shatter:fat (166) | 173/200 (86.5%) | 9 stall | 2507 s | .97 .97 .97 1.0 1.0 1.0 1.0 1.0 1.0 |
| 14 | attrition:fat → shatter:fat (180) | 182/200 (91.0%) | 8 stall | 2288 s | .93 .97 1.0 1.0 1.0 1.0 1.0 1.0 |
| 15 | shatter:mid → shatter:thin (156) | 183/200 (91.5%) | 14 stall | 3249 s | .80 .90 .90 .93 .95 .97 .97 .97 1.0 1.0 1.0 1.0 1.0 1.0 |
| 16 | shatter:thin → smolder:thin (41) | 167/200 (83.5%) | 8 stall | 2193 s | .82 .90 1.0 1.0 1.0 1.0 1.0 1.0 |
| 17 | smolder:mid → shatter:thin (155) | 169/200 (84.5%) | 12 stall | 2765 s | .80 .85 .85 .93 .93 .95 1.0 1.0 1.0 1.0 1.0 1.0 |

Stayed ≥ floor: none. Close to best (92.5%) within 15 pp: none. **C3 FAIL.** End-cell ceilings: shatter:mid 92.5%, shatter:thin 91.5%, shatter:fat 91.0%, smolder:thin 83.5%. Best−second = 1.0 pp. **C4 PASS.** Vow 0 is report-only.

#### Ashwarden — Vow 5 — floor 64.11%

| Isl | start → end | holdout | gens / stop | wall | bestEver by gen |
|---:|---|---:|---|---:|---|
| 18 | shatter:fat → shatter:mid (97) | 146/200 (73.0%) | 19 stall | 3888 s | .38 .53 .68 .68 .72 .72 .80 .85 .85 .85 .85 .85 .88 .93 .93 .93 .93 .93 .93 |
| 19 | smolder:fat → shatter:fat (75) | 103/200 (51.5%) | 20 maxGen | 3031 s | .30 .35 .35 .45 .53 .53 .53 .53 .62 .62 .62 .70 .70 .70 .72 .72 .82 .82 .82 .82 |
| 20 | attrition:fat → shatter:fat (130) | 156/200 (78.0%) | 20 maxGen | 5167 s | .55 .55 .57 .70 .72 .88 .88 .88 .90 .90 .90 .93 .93 .93 .93 .93 .97 .97 .97 .97 |
| 21 | shatter:mid → shatter:fat (111) | 169/200 (84.5%) | 17 stall | 4329 s | .65 .80 .80 .80 .80 .88 .88 .88 .90 .93 .93 1.0 1.0 1.0 1.0 1.0 1.0 |
| 22 | smolder:mid → shatter:thin (89) | 153/200 (76.5%) | 8 stall | 1515 s | .78 .88 .90 .90 .90 .90 .90 .90 |
| 23 | shatter:thin → shatter:mid (92) | **179/200 (89.5%)** | 11 stall | 2219 s | .95 .95 .95 .95 .95 .97 .97 .97 .97 .97 .97 |

Stayed ≥ floor: none. Close to best (89.5%) within 15 pp: none. **C3 FAIL.** End-cell ceilings: shatter:mid 89.5%, shatter:fat 84.5%, shatter:thin 76.5%. Best−second = 5.0 pp. **C4 PASS.** Best holdout **89.5% ≤ 90%**. **Vow-5 ceiling PASS** (fail-closed).

### Verdicts

| Grid | C3 | C4 | Vow-5 >90% | Skill headroom (holdout ceiling − gen-0 median) |
|---|---|---|---|---|
| Dusk V0 | **FAIL** (0 stayed) | **PASS** (1.5 pp) | n/a (report-only; 92.0%) | 18.25 pp (73.75% → 92.0%) |
| Dusk V5 | **FAIL** (1 stayed, 0 close) | **PASS** (5.0 pp) | **PASS** (83.0%) | 30.50 pp (52.50% → 83.0%) |
| Ash V0 | **FAIL** (0 stayed) | **PASS** (1.0 pp) | n/a (report-only; 92.5%) | 10.00 pp (82.50% → 92.5%) |
| Ash V5 | **FAIL** (0 stayed) | **PASS** (5.0 pp) | **PASS** (89.5%) | 29.50 pp (60.00% → 89.5%) |

Island drift is the primary signal: **22 of 24** islands left their start cell; **21 of those 22** landed in a shatter cell. That is the same "optimisation has one destination" signature as #216, now on the live mix and live content SHA. Combined with layer 1 (C1a/C1b/C2 **FAIL** on all four grids), P9 cannot be declared.

Median generations until stop: 14 (range 7–20). Stop reasons: 21 stall, 3 maxGen (islands 7, 19, 20).

### Replay key

- Content SHA and Godot as in each island manifest line (`736090f1…`, `4.7.2-stable (official)`, commit `101e7d9`).
- Seed policy: `BalancePolicy.sample_range(215, policyIndex, 1)[0]` with `policyIndex` from the seeding table.
- CEM draws: `Rng.new(216 + island)`, island ordinal 0–23 as in the table.
- Converged vector: the `policy` field of the `{"t":"final"}` row in `/private/tmp/glassvow-412-landscape/layer2/island-NN.ndjson`.
- Holdout replay: `BalanceSim.simulate(content, aspect, seed, vow, PackedStringArray(), policy)` for seed in 5000–5199.
- Readout: `python3 tools/balance_cem_report.py /private/tmp/glassvow-412-landscape/layer2 /private/tmp/glassvow-412-landscape/sweep/analysis.json OUT.json`.

Driver: `tools/balance_cem.gd`. Analysis JSON (committed): `docs/balance/data/412/layer2-analysis.json`. Raw island NDJSON stays under `/private/tmp/glassvow-412-landscape/layer2/` (not committed).

### Tier 2 stays open

Cross-turn card holding, target selection and Art timing are not searched by this layer. The 2026-08-14 "what a negative result does not claim" list still applies verbatim.

### Combined gate

| Gate | Result |
|---|---|
| C1a (all four grids) | **FAIL** |
| C1b (all four grids) | **FAIL** |
| C2 (all four grids) | **FAIL** |
| C3 (all four grids) | **FAIL** |
| C4 (all four grids) | **PASS** |
| Vow-5 ≤90% fail-closed | **PASS** (Dusk 83.0%, Ash 89.5%) |

A FAIL does not park TestFlight. It parks declaring RC (`docs/rc-bar.md` P9). The retune is [#421](https://github.com/fol2/glassvow/issues/421); [#204](https://github.com/fol2/glassvow/issues/204) stays closed.
