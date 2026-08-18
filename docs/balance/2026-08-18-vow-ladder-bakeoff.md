# Vow ladder bake-off — 2026-08-18

Issue: [fol2/glassvow#211](https://github.com/fol2/glassvow/issues/211).
Frame: [fol2/glassvow#206](https://github.com/fol2/glassvow/issues/206).
Pilot `p8-d0-v1` on profile `mature-three-act-no-side-state-v1`. Godot
`4.7.1.stable`. Content SHA-256
`736090f18546738a2e38b756d81f6ad715a808c4ea321220443f839862cdb102`.
Bake-off seeds **7000–7079** (cells, n = 80 / aspect) and clock seeds
**9000+**. Overlay knobs on `RewardRules` stay identity until `apply()`.
James signed **`A_modest_linear` as drafted** on 2026-08-18 — live runs call
`VowIncentives.shipping()`. This file's tables are the bake-off, not a retune.

**Signed (James, 2026-08-18):** deploy catalog A with no number changes. The
Dusk v2 67.5% both-cuts cell is accepted. F is declined. Mythic rates remain
authored on the mix and unrolled here (#210 / #212).

**Scope (charter, 2026-08-13):** best of these candidates under this
instrument, not "safe". Concentration is reported next to every cell. The
pilot is a hand-written heuristic; a mix that hands a human a degenerate
line is outside this ticket.

Raw files: `docs/balance/data/211/penalties.json`, `…/mixes.json`,
`…/clock.json`, plus the matching CSVs.

## Metric

The #206 success criterion is mean runs to 6 Shards / the Act IV threshold,
per vow. That clock is **unmeasurable in this domain-only sim**.
`BalanceSim.simulate` still initialises `quests: {}` and `shards: []` unless
a `VigilState` is threaded through, and a 3-act run never completes a
journey, so `shardHits` is 0 in every clock cell (20 vigils × 6 arms).
Counting a fake 6-shard total would have been a number about nothing.

Replacement, implemented in `tools/vigil_clock.gd` (`expected_wins`,
`chain`):

- **Primary:** expected runs to N wins, `N / p`, with N = 10 (the last
  `progression.emberglass.armWins` rung). Emitted on every cell as
  `eRunsTo10`.
- **Empirical check:** chain 3-act sims into a real `VigilState` ledger,
  20 vigils, cap 30, and record mean / median runs to 10 wins plus the
  arming checkpoints 1, 2, 4, 6, 8, 10. `armWins` itself is not changed.
- **Secondary:** `expected_own_shade(p) = 2/p + 3/(1-p)` — two wins then
  three losses; reported, not gated.

`eRunsTo10` from the n = 80 win rates matches the 20-vigil chain on the
penalty-only arms (Dusk v0 11.43 vs 10.8; Dusk v5 15.69 vs 16.05). The
instrument is the closed emberglass clock, read as expected wins, not a
fabricated shard count.

## Finding: `startHex` is dead

`content/full-content.json` marks Vow of the Mark with `startHex: true`.
`CombatRules._vow_mods` collects that flag and nothing reads it. The Hex
that actually enters the deck is `run.vow >= 4` in
`domain/state/run_state.gd` (`new_run`).

Isolate cells (all other mods stripped):

| Isolate | Vow | Hex in start deck | Combined win rate | Mean gold Dusk / Ash |
|---|---:|---|---:|---|
| `empty1` | 1 | no | 144 / 160 = **90.0%** | 928.7 / 951.0 |
| `deadhex` (`startHex` planted at vow 1) | 1 | no | 144 / 160 = **90.0%** | 928.7 / 951.0 |
| `mark` (`startHex` + vow 4) | 4 | **yes** (vow ≥ 4) | 146 / 160 = 91.2% | 905.4 / 932.6 |
| `iron` | 1 | no | 144 / 160 = 90.0% | 924.4 / 974.8 |

`deadhex` and `empty1` are bit-identical on these seeds, including gold.
The Mark isolate is slightly *easier* than empty1 — Hex-at-vow-4 is not a
detectable tax on this pilot at n = 80. Tests pin the identity
(`tests/test_vow_ladder_bakeoff.gd`).

## Penalty cost and monotonicity

Cumulative ladder, mix = none, n = 80 / aspect, seeds 7000–7079.

| Vow | Dusk wins | Dusk % | Wilson 95% | Ash wins | Ash % | Wilson 95% | Combined | eRunsTo10 D / A | Gold D / A |
|---:|---:|---:|---|---:|---:|---|---:|---|---|
| 0 | 70 / 80 | 87.5 | [78.5, 93.1] | 74 / 80 | 92.5 | [84.6, 96.5] | **90.0%** | 11.43 / 10.81 | 928.7 / 951.0 |
| 1 Iron | 70 / 80 | 87.5 | [78.5, 93.1] | 74 / 80 | 92.5 | [84.6, 96.5] | **90.0%** | 11.43 / 10.81 | 924.4 / 974.8 |
| 2 Malice | 64 / 80 | 80.0 | [70.0, 87.3] | 67 / 80 | 83.8 | [74.2, 90.3] | **81.9%** | 12.50 / 11.94 | 891.6 / 947.2 |
| 3 Deep | 56 / 80 | 70.0 | [59.2, 78.9] | 65 / 80 | 81.2 | [71.3, 88.3] | **75.6%** | 14.29 / 12.31 | 837.8 / 922.0 |
| 4 Mark | 53 / 80 | 66.2 | [55.4, 75.7] | 66 / 80 | 82.5 | [72.7, 89.3] | **74.4%** | 15.09 / 12.12 | 784.1 / 890.5 |
| 5 Waning | 51 / 80 | 63.8 | [52.8, 73.4] | 59 / 80 | 73.8 | [63.2, 82.1] | **68.8%** | 15.69 / 13.56 | 755.1 / 844.8 |

**Combined rate is monotone non-increasing.** Dusk is monotone (tied 0–1).
Ash is not: v3 81.2 → v4 82.5, inside noise. Vow 0 and Vow 1 are the same
70 / 80 and 74 / 80 — Iron's `hpMult 1.12` does not flip a single outcome
on this seed band.

Isolated single-mod cost versus `empty1` (90.0% combined):

| Isolate | Combined | Δ vs empty1 | Note |
|---|---:|---:|---|
| Iron `hpMult 1.12` | 90.0% | 0.0 pp | same win counts |
| Malice `enemyDmgBonus +1` | 86.9% | **−3.1 pp** | largest isolated drop |
| Deep `bossFacetDelta +1` | 91.2% | +1.2 pp | inside noise; not a tax |
| Mark Hex (vow ≥ 4) | 91.2% | +1.2 pp | startHex field unused |
| Waning `restHealFrac 0.2` (Hex stripped) | 88.8% | −1.2 pp | inside noise |

The five inherited mods are **not a monotone isolated difficulty sequence**.
The stacked ladder still walks down, and almost all of the walk is Malice
plus accumulation, not five equal rungs. n = 80 Wilson half-widths are
±7–10 pp per aspect; only the v0-to-v5 combined gap (−21.2 pp) sits
comfortably outside that.

Every strong cell concentrates on `hollowCrown` at 87–91% of wins. That
smell is already on the penalty-only ladder; it is not introduced by a mix.

## Mix bake-off

`VowIncentives.catalog` in `tools/vow_incentives.gd` (`catalog`). Apply is
identity at vow 0 (0 rarity steps, `gold_mult = 1`, no second relic), so
every mix's vow-0 cell is the penalty-only control: 87.5 / 92.5, gold
928.7 / 951.0. Vow 0 is not trivialised.

A first mixes pass called `isolate()` with the mix id and stripped every
penalty. Those numbers are discarded. The table below is the rerun with
the stacked ladder intact, plus a penalty-only **vow-5 weak** control so
the #206 crossover can be read.

| Mix | v2 D / A | v5 strong D / A | v5 weak D / A | Δ v5s vs none | Δ v5w vs none | v5 gold D / A | v5s `hollowCrown` |
|---|---|---|---|---|---|---|---|
| none (ladder / extra weak) | 80.0 / 83.8 | 63.8 / 73.8 | 21.2 / 37.5 | — | — | 755 / 845 | 87.3% |
| A modest linear | 67.5 / 83.8 | 63.8 / 76.2 | 27.5 / 43.8 | 0 / +2.5 | +6.2 / +6.2 | 937 / 1024 | 91.1% |
| B steep rarity | 67.5 / 76.2 | 55.0 / 67.5 | 21.2 / 40.0 | −8.8 / −6.2 | 0 / +2.5 | 909 / 974 | 93.9% |
| C compound gold | 67.5 / 85.0 | 63.8 / 75.0 | 25.0 / 41.2 | 0 / +1.2 | +3.8 / +3.8 | 953 / 1030 | 92.8% |
| D gold-heavy | 71.2 / 86.2 | 67.5 / 66.2 | 22.5 / 35.0 | +3.8 / −7.5 | +1.2 / −2.5 | **1073 / 1119** | 86.0% |
| E relic-heavy | 67.5 / 83.8 | 60.0 / 71.2 | 26.2 / 41.2 | −3.8 / −2.5 | +5.0 / +3.8 | 931 / 1008 | 89.5% |
| **F uncommon-only** | **85.0 / 82.5** | **70.0 / 75.0** | 28.7 / 41.2 | **+6.2 / +1.2** | +7.5 / +3.8 | 965 / 933 | 89.7% |

Wilson intervals at n = 80 all overlap the matching none cell. Point
estimates are what discriminate:

- **Both-cuts rarity (A/B/C/E) sits Dusk v2 at 67.5%** against none 80.0%.
  The intervals [56.6, 76.8] and [70.0, 87.3] overlap, but the four mixes
  that share the #206 both-cuts shift all land on the same 54 / 80. F
  (uncommon-only, no rare shift) is 85.0%. D (3 pp both-cuts) is 71.2%,
  between them. The rarity-shift half of #206 is the knob this dusk pilot
  does not want.
- **No catalog mix produces the #206 crossover** (strong lift larger than
  weak lift) on the point estimates. A/C/E lift weak more than strong. B
  taxes strong. F lifts both, weak slightly more on Dusk.
- **B is the only mix that looks actively harmful** at v5 strong
  (−8.8 / −6.2 pp).
- **D buys the most gold** and drops Ash v5 strong to 66.2%.
- Concentration does not move. Strong cells stay `hollowCrown` ~86–96%.
  Weak cells diversify because random play does not hunt that relic.

Mythic curves on rungs 3–5 (and the post-Act-IV stack-or-replace delta)
are authored on each mix and **not rolled** in this sim. #210 / #212 own
that number.

## Clock

20 vigils, win target 10, cap 30, seed 9000. `shardHits = 0` on every arm.

| Arm | mean runs | median | capped |
|---|---:|---:|---:|
| Dusk v0 none | 10.80 | 10 | 0 / 20 |
| Ash v0 none | 10.45 | 10 | 0 / 20 |
| Dusk v5 none | 16.05 | 16 | 0 / 20 |
| Ash v5 none | 12.65 | 13 | 0 / 20 |
| Dusk v5 A modest | 16.00 | 15.5 | 0 / 20 |
| Dusk v5 A modest, weak | 29.95 | 30 | **19 / 20** |

A does not move the Dusk v5 clock (16.05 → 16.00). Weak A almost never
arms emberglass inside 30 runs. Implied F Dusk v5 `eRunsTo10` from the
mix cell is 14.3; that chain was not re-run.

## Recommended mix

Bake-off recommendation was **`F_uncommon_only`**. **Not shipped.** James
signed **`A_modest_linear`** as drafted (#206 modest: 5 pp both-cuts, 5%
linear gold, 15% second elite relic at Mark).

**`F_uncommon_only`** — uncommon-only 8 pp rarity, 3% linear gold, 15%
second elite relic at Mark, mythic `[0, 0, 0, 0.01, 0.02, 0.04]` with
+1 pp post-Act-IV stack.

Why this one, with these numbers:

- Vow 0 is identical to none (87.5 / 92.5). The easy-tutorial failure
  mode does not fire.
- It is the only catalog mix that does **not** sit Dusk v2 on 67.5%.
  v2 Dusk 85.0% vs none 80.0%; v5 strong 70.0 / 75.0 vs none 63.8 / 73.8.
- v5 strong stays below v0. This is not a power ramp that erases the
  ladder for skilled play.
- v5 weak is 28.7 / 41.2 against none 21.2 / 37.5. Weak is still far from
  strong (gap 41.3 / 33.8 pp). The mix does not make bad play win.
- Gold at v5 is 965 / 933 against none 755 / 845 — a real purse, not D's
  1073 / 1119 at the cost of Ash wins.
- Implied Dusk v5 `eRunsTo10` 14.3 vs none 15.7. Modest pace change on
  the closed clock.

It does **not** satisfy the #206 crossover on the point estimates (weak
Dusk lifts +7.5 pp, strong +6.2 pp). n = 80 cannot resolve a 5 pp effect.
The recommendation is "least-wrong catalog mix under this instrument",
not "proven crossover".

**Do not ship A as drafted** was the bake-off's advice. James overrode it
and shipped A with no retune. Compound gold (C) was indistinguishable from
A at this sample. B taxes strong play.

**Follow-up, not in the catalog:** F's uncommon-only rarity + A's 5%
linear gold, both-cuts rare shift left at 0. Only worth a cell if James
wants a second round.

**Shipping none was declined.** James signed A as drafted.

## What this does not decide

- Numbers in `content/full-content.json`. Tables stay identity. The live
  overlay is `A_modest_linear` via `VowIncentives.shipping()` on
  `GlassvowGame`. Vow 0 is still the #204 digest. Vow ≥ 1 live play
  diverges from the identity holdout — that is the signed deploy.
- Iron / Deep / Mark as authored values. Isolated, they do not tax this
  pilot; retuning those mods is a different ticket.
- Whether `startHex` should be wired or deleted. Dead field, recorded.
- Post-Act-IV mythic and the elite pull (#210, #212, #223).
- Human degenerate lines (#213). Concentration is the cheap smell and it
  is already maxed on `hollowCrown`.
