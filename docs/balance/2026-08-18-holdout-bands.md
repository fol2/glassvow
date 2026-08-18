# Balance holdout — 2026-08-18

Issue: [fol2/glassvow#204](https://github.com/fol2/glassvow/issues/204).
Ruler: [fol2/glassvow#203](https://github.com/fol2/glassvow/issues/203) signed bands
(`docs/balance/2026-08-13-diagnosis-baseline.md`, James 2026-08-16).
Status: **PASS** — one joint hypothesis on a fresh holdout. **No content scalar
was changed.** Current `origin/main` already sits inside the signed envelope.

Instrument: headless `p8-d0-v1` on `mature-three-act-no-side-state-v1`.
Godot `4.7.1-stable (official)`. Content SHA-256
`736090f18546738a2e38b756d81f6ad715a808c4ea321220443f839862cdb102`.
Game-under-test commit `af2984eb57b50574ba8a29ed7511e793ba0a559a` (PR #395;
content SHA differs from the p8 diagnosis SHA only by later copy / Act IV
catalogue — seed-1000 duskblade digest is unchanged).

## Protocol (declared before the holdout was opened)

Diagnosis inner loop (not the proof): seeds **4000–4199**, n = 200 per cell.
On this SHA those four cells reproduced the p8 diagnosis bit-for-bit
(178 / 185 / 128 / 162). That block was already spent by #203.

Holdout block (the joint hypothesis): seeds **5000–5199** inclusive, n = 200
per aspect × gated vow. Exact list = `{5000, 5001, …, 5199}`. Untouched by
diagnosis, ablation design, or any retune.

Ablation: same holdout seeds, Vow 0, the eight p8 IDs, matched to the unbanned
Vow 0 holdout control.

Top-up: **none**. Bands are point-estimate gates. A fail would have spent this
block and reserved 5200–5399; that reserve was not used.

Out of bounds (untouched): map weights, potion probability, act-transition
heal, the five `vows` penalties (`hpMult` 1.12, `enemyDmgBonus` 1,
`bossFacetDelta` 1, `startHex`, `restHealFrac` 0.2), `locale/`, story copy.

## Four cells

| Cell | Wins / runs | Win rate | Wilson 95% | Signed band | Gate |
|---|---:|---:|---|---|---|
| Vow 0 Duskblade | 188 / 200 | **94.0%** | [89.807%, 96.535%] | 80–97% | **PASS** |
| Vow 0 Ashwarden | 187 / 200 | **93.5%** | [89.198%, 96.162%] | 80–97% | **PASS** |
| Vow 5 Duskblade | 133 / 200 | **66.5%** | [59.702%, 72.676%] | 55–85% | **PASS** |
| Vow 5 Ashwarden | 151 / 200 | **75.5%** | [69.096%, 80.943%] | 55–85% | **PASS** |

Stalls = 0. Errors = 0. Every requested row is retained.

## |Ash − Dusk| gap (paired, same seeds)

Signed: point estimate **≤ 20 pp**. Second clause dropped at sign-off.

| Vow | Ash − Dusk | Paired 95% | −1 / 0 / +1 | Gate |
|---|---:|---|---:|---|
| 0 | **−0.50 pp** | [−5.41, +4.41] | 13 / 175 / 12 | **PASS** |
| 5 | **+9.00 pp** | [+0.64, +17.36] | 28 / 126 / 46 | **PASS** |

## Boss turns (kind = boss)

Signed: mean ∈ **[5.5, 10.5]** for every act × aspect × gated vow. Share in
6–10 is reported, not gated.

| Vow | Aspect | Act 1 | Act 2 | Act 3 |
|---|---|---:|---:|---:|
| 0 | Duskblade | 6.685 | 6.600 | 9.594 |
| 0 | Ashwarden | 5.829 | 5.812 | 7.717 |
| 5 | Duskblade | 7.442 | 7.302 | 10.187 |
| 5 | Ashwarden | 6.538 | 6.556 | 8.510 |

All twelve means sit in [5.5, 10.5]. Closest to the floor: Vow 0 Ash act 2
**5.812**. Closest to the ceiling: Vow 5 Dusk act 3 **10.187**. Lowest
share-in-6–10: Vow 5 Dusk act 3 **60.4%** (84 / 139).

## Ablation (Vow 0, seeds 5000–5199, n = 200 per aspect)

Signed: point-estimate ≤ **12 pp** non-boss / ≤ **15 pp** boss relic.
Control: Dusk 188 / 200 = 94.0%, Ash 187 / 200 = 93.5%.

| Item | Dusk Δ; paired 95% | Ash Δ; paired 95% | Cap | Gate |
|---|---:|---:|---|---|
| hollowCrown (boss) | **−6.50 pp; [−10.91, −2.09]** | +2.00 pp; [−0.76, +4.76] | 15 pp | **PASS** |
| venomStrike | 0.00 pp; [−1.39, +1.39] | **−4.00 pp; [−7.63, −0.37]** | 12 pp | **PASS** |
| eclipseSlash | −2.50 pp; [−7.40, +2.40] | 0.00 pp | 12 pp | **PASS** |
| emberLantern | −2.00 pp; [−4.76, +0.76] | −0.50 pp; [−2.70, +1.70] | 12 pp | **PASS** |
| catalyst | 0.00 pp | −1.50 pp; [−4.44, +1.44] | 12 pp | **PASS** |
| virulence | −1.00 pp; [−2.38, +0.38] | +1.00 pp; [−1.40, +3.40] | 12 pp | **PASS** |
| duskmirror | −0.50 pp; [−1.48, +0.48] | −0.50 pp; [−2.20, +1.20] | 12 pp | **PASS** |
| warCry | +1.00 pp; [−2.40, +4.40] | 0.00 pp | 12 pp | **PASS** |

Peak boss relic: hollowCrown Dusk **−6.50 pp**. Peak non-boss: venomStrike Ash
**−4.00 pp**. Neither approaches its cap.

## Zero-tolerance trio (this block)

| Leg | Operationalisation here | Result |
|---|---|---|
| No unwinnable seed / softlock | stalls = 0 and errors = 0 on 800 diagnosis-holdout runs + 1,600 banned runs | **holds on this sample** |
| No strictly dominant aspect | band 2, \|Ash − Dusk\| ≤ 20 pp | **−0.50 / +9.00 pp** |
| No trivialize at a gated vow | band 4 ablation ceilings + Vow 5 p8-default cells inside 55–85% | **holds for this pilot** |

Amendment 1 still applies: a heuristic pilot cannot evidence "no strategy
trivializes a gated vow". The #213 C1–C4 landscape (last measured FAILING
C3/C4 and the Vow-5 ceiling on 2026-08-14, older SHA) was **not** re-run;
that is a 1.5 h instrument and a separate detector. #205 (human feel) stays
open.

## Content scalars changed

**None.** `content/full-content.json` and `content/mob-overrides.json` are
byte-identical to `af2984e`. The five vow penalties were left for #211.

## Replay

```bash
godot --headless -s res://tools/balance_sim.gd -- \
  --vow=0 --runs=200 --seed0=5000 --aspect=all \
  --out=docs/balance/data/2026-08-18-holdout-vow0.json
godot --headless -s res://tools/balance_sim.gd -- \
  --vow=5 --runs=200 --seed0=5000 --aspect=all \
  --out=docs/balance/data/2026-08-18-holdout-vow5.json
# eight --ban= IDs, same seeds, Vow 0
python3 tools/balance_score.py --csv-dir docs/balance/data \
  --csv-prefix 2026-08-18-holdout \
  --ablation hollowCrown=docs/balance/data/2026-08-18-holdout-ablation-n200-hollowCrown.json \
  # …same for duskmirror catalyst emberLantern venomStrike virulence warCry eclipseSlash
  docs/balance/data/2026-08-18-holdout-vow0.json \
  docs/balance/data/2026-08-18-holdout-vow5.json
```

Raw JSON and CSV slices live under `docs/balance/data/2026-08-18-holdout-*`,
same convention as the p8 diagnosis files. `.gdignore` keeps them out of the
Godot resource index.
