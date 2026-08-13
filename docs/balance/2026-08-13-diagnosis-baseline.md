# Balance diagnosis baseline — 2026-08-13

Issue: [fol2/glassvow#203](https://github.com/fol2/glassvow/issues/203).
Method: [fol2/glassvow#160](https://github.com/fol2/glassvow/issues/160).
Status: **DRAFT — PENDING JAMES SIGN-OFF** on the four bands. Step 2 (device validation) is HITL and is not this artifact.

Pilot `p7-d0-v1` on profile `mature-three-act-no-side-state-v1`. Content SHA-256
`633408231840d4ba47e0680d1969982cdf1ded1a61213a51bfd2bdab00f35155`. Godot
`4.7.1-stable (official)`. Manifest commit at sim time
`7fcfc5bd7154e86af42a86c0d817e024dd6c8f63`.

## Headline

| Cell | Wins / runs | Win rate | Wilson 95% |
|---|---:|---:|---|
| Vow 0 Ashwarden | 152 / 200 | **76.0%** | [69.627%, 81.393%] |
| Vow 0 Duskblade | 134 / 200 | **67.0%** | [60.217%, 73.143%] |
| Vow 5 Ashwarden | 80 / 200 | **40.0%** | [33.461%, 46.916%] |
| Vow 5 Duskblade | 72 / 200 | **36.0%** | [29.669%, 42.859%] |

- **Aspect gap (paired, same seeds):** Vow 0 Ash − Dusk = **+9.00 pp**, 95% [+0.08, +17.92]; Vow 5 = **+4.00 pp**, 95% [−5.30, +13.30].
- **Boss-turn window (means):** all twelve vow × aspect × act means sit in **6–10 turns**. Shortest mean 6.082 (Vow 0 Ash act 2); longest 9.590 (Vow 0 Dusk act 3).
- **Top-3 interventional ablation shifts** (Vow 0, seeds 4000–4199, 200 runs/aspect, matched control): **hollowCrown −9.50 pp** combined (−12.50 Dusk, −6.50 Ash); **duskmirror −4.75 pp**; **emberLantern −4.50 pp** combined. `catalyst` is −6.50 pp Ash and −2.25 pp combined.
- **Saturation:** **did not occur.** Vow 0 max is 76%, not ~100%. The four cells separate (Vow 0 vs Vow 5 CIs disjoint). Lookahead escalation is **not** triggered.

## Seeds and counts

Diagnosis seeds are **4000–4199 inclusive** (200 contiguous integers). Both aspects and both vows share that list so the aspect gap is paired. Exact list = `{4000, 4001, …, 4199}`.

| Reserved elsewhere | Range | Do not reuse |
|---|---|---|
| P6 B0 diagnosis | 1000–1199 | historical |
| P6 B7 holdout | 2200–2999 | historical |
| **This diagnosis** | **4000–4199** | **this baseline** |
| Ablation matched sample | 4000–4199 | same seeds as this diagnosis |
| Future holdout (suggested) | **5000+** | disjoint from all of the above |

Exact run counts:

- Diagnosis: **800** whole runs (4 cells × 200).
- Ablation: **3,200** additional banned whole runs (8 bans × 2 aspects × 200), each paired with the diagnosis control on the same seeds. A fresh 400-run control rerun reproduced the retained control exactly apart from its manifest commit.
- Stalls = 0 and simulator errors = 0 in every cell and every ablation file.

Raw files: `docs/balance/data/2026-08-13-vow0.json`, `…-vow5.json`,
`…-ablation-n200-<id>.json`, plus CSV slices `…-cells.csv`, `…-boss-turns.csv`,
`…-economy.csv`, `…-ablation-n200.csv`, `…-runs.csv`. The original n = 80
`…-ablation-<id>.json` and `…-ablation.csv` files remain as prior evidence.

## What the pilot change was

`p6-b0-v1` scored cards by rarity, skipped Ashwarden's Smother except as lethal Ward, bought one shop item in category order, and over-weighted Eclipse with a flat +1000. `p7-d0-v1` keeps the same RNG contract (incoming forecast clones the stream; no future-draw peek) and changes three heuristics:

1. **Valuation.** Effect-kind scores plus triangular Smolder expectation, Vulnerable/Shatter weights, and named specials (`catalyst`, `shatterEcho`, …). Aspect bonuses on the Eclipse/Shatter line (Dusk) and the Smolder line (Ash).
2. **Combat.** Preview loss/block/lethal/shatter is the primary score. Eclipse is played as a Vulnerable setup when another attack is in hand. Catalyst targets the highest Smolder. Non-lethal Ward is played when unblocked intent remains. Smother is no longer skipped.
3. **Shop.** Greedy value/gold, multiple buys, one remove of a tripled weak starter when the ratio beats the next buy. Routing prefers a shop when gold ≥ 140.

Determinism pin: `tests/test_balance_sim.gd` seed 1000 digest
`b38410ee207c477b1f0048dec350d1488a100937750150b2a4fd04d69eae6710`.

## Four cells

Vow 0 vs Vow 5 is the discrimination the sample was sized for. 200 runs/cell gives Wilson half-widths of ~6 pp at these rates; the vow gap is ~30–36 pp, so the cells do not overlap. The aspect gap inside a vow is smaller than the interval: Vow 0's paired interval just clears zero; Vow 5's contains zero.

Relative to P6's final holdout (seeds 2200–2999, weak pilot): Vow 0 rose from 62.9/67.5% (Dusk/Ash) to 67.0/76.0%; Vow 5 rose from 20.9/20.5% to 36.0/40.0%. A stronger pilot winning more is the expected direction. It is still far from the human saturation that made P6 undiagnosable.

## Boss turns

Means (all fights that are `kind=boss`):

| Vow | Aspect | Act 1 | Act 2 | Act 3 |
|---|---|---:|---:|---:|
| 0 | Ashwarden | 6.170 | 6.082 | 8.478 |
| 0 | Duskblade | 6.685 | 6.739 | 9.590 |
| 5 | Ashwarden | 6.758 | 6.507 | 8.500 |
| 5 | Duskblade | 7.422 | 7.165 | 9.283 |

Share of those fights whose length is 6–10 turns is 72–91% except Vow 5 Dusk act 3 (**54.3%**, many 11–15). Hallway `turnsPerFight` in the summary (~2.7–3.6) is not the boss window; it averages trash with bosses.

Ash Smolder kills/fight exceed Dusk in every act at both vows. Dusk shatters/fight exceed Ash in every act at both vows. The two signatures are firing.

## Economy and runs-to-endgame

Gold earned on wins is ~935–974; on losses ~499–630. Winning decks finish around 43 cards; losses die earlier around 30–33. Gold at the act-1 boss is ~200–214; act-2 ~276–301; act-3 end-gold ~213–275. Vow 5 spends more HP to get there (act-1 boss HP ~34–38 vs ~46–50 at Vow 0).

**Runs to a 3-act win** (geometric 1/p, this profile):

| Cell | E[runs] |
|---|---:|
| Vow 0 Ashwarden | 1.32 |
| Vow 0 Duskblade | 1.49 |
| Vow 5 Ashwarden | 2.50 |
| Vow 5 Duskblade | 2.78 |

**Six Shards / Act IV is not modeled.** The sim profile is `mature-three-act-no-side-state-v1` (`quests: {}`, `shards: []`). The 1/p figures above are **three-act clears, not vigil progression**, so they do not answer #160's "runs-to-endgame per vow" — that diagnostic is deferred to a later profile, not substituted here.

## Ablation

Observational "has item → higher win rate" is survivorship (a boss relic is only held if a boss died) and is **not** the gate. The table below is interventional: same seeds 4000–4199, item banned from start deck, relics, rewards and shop, compared to the unbanned control on those seeds (Dusk 134/200 = 67.00%, Ash 152/200 = 76.00%). Each cell reports point delta; paired McNemar 95% interval; achieved half-width.

| Item | Dusk Δ; paired 95%; ±half-width | Ash Δ; paired 95%; ±half-width | Combined Δ; paired 95%; ±half-width |
|---|---:|---:|---:|
| hollowCrown | **−12.50 pp; [−19.30, −5.70]; ±6.80** | −6.50 pp; [−12.41, −0.59]; ±5.91 | **−9.50 pp; [−14.01, −4.99]; ±4.51** |
| duskmirror | −5.00 pp; [−8.33, −1.67]; ±3.33 | −4.50 pp; [−7.70, −1.30]; ±3.20 | **−4.75 pp; [−7.06, −2.44]; ±2.31** |
| catalyst | +2.00 pp; [−0.76, +4.76]; ±2.76 | **−6.50 pp; [−11.12, −1.88]; ±4.62** | −2.25 pp; [−4.97, +0.47]; ±2.72 |
| emberLantern | −5.00 pp; [−9.96, −0.04]; ±4.96 | −4.00 pp; [−7.36, −0.64]; ±3.36 | **−4.50 pp; [−7.49, −1.51]; ±2.99** |
| venomStrike | +1.50 pp; [−0.69, +3.69]; ±2.19 | +1.00 pp; [−5.81, +7.81]; ±6.81 | +1.25 pp; [−2.32, +4.82]; ±3.57 |
| virulence | +0.50 pp; [−4.21, +5.21]; ±4.71 | +1.50 pp; [−3.79, +6.79]; ±5.29 | +1.00 pp; [−2.54, +4.54]; ±3.54 |
| warCry | +0.50 pp; [−5.94, +6.94]; ±6.44 | +2.00 pp; [−1.67, +5.67]; ±3.67 | +1.25 pp; [−2.45, +4.95]; ±3.70 |
| eclipseSlash | **+6.00 pp; [−3.07, +15.07]; ±9.07** | 0.00 pp; [0.00, 0.00]; ±0.00 | +3.00 pp; [−1.54, +7.54]; ±4.54 |

`eclipseSlash` stripped from the Dusk start deck *raised* win rate by 6.00 pp. That is thinning a 10-card starter, not a proof that Eclipse is weak in play — do not read it as a nerf recommendation. `hollowCrown` is the concentration peak and is a boss relic (+energy, −max HP). `catalyst` at −6.50 pp Ash is the Ash combo peak among pool cards.

n = 200 per aspect and 400 combined. The intervals use the document's existing paired-difference arithmetic: the sample variance of matched Bernoulli differences with n − 1 in the denominator and z = 1.9599639845. The combined figure pairs 400 comparisons, not 200.

## Saturation check

P6's failure mode was a weak pilot at 63–68% while humans sat at ~100%, destroying contrast. `p7-d0-v1` at Vow 0 is 67–76% with a 9 pp aspect gap and a 30+ pp vow gap. **Not saturated. Do not escalate to lookahead in this slice.**

Caveat for HITL: a competent human will still beat this heuristic. If James's device runs are near 100% at Vow 0, the *bands* can still use this pilot as the instrument, but Vow 0's player-facing challenge is then a separate question (#205, and the "Vow 0 must itself always be challenging" decision in #160).

---

## Four bands — DRAFT, PENDING JAMES SIGN-OFF

Instrument: headless `p7-d0-v1` on `mature-three-act-no-side-state-v1`, diagnosis seeds held out from any later proof. Gated vows are 0 (primary) and 5 (sanity). Vows 1–4 ungated.

> **Read "Limits of this instrument" below before signing.** An adversarial methodology review by a non-authoring model raised five findings that survived independent verification; two of them change what bands 2 and 4 can honestly claim, and one bounds what all four bands can claim together.

### 1. Win-rate band per gated vow × aspect

**Draft:** Vow 0 each aspect **60–80%**; Vow 5 each aspect **25–50%**.

Vow 0 must be challenging rather than a tutorial, and this pilot is already a fair bit stronger than `p6-b0-v1`, so a floor at 60% keeps the cell above a coin-flip without licensing saturation, while an 80% ceiling leaves room under the 100% human cap that wrecked P6. Vow 5 is the sanity check with wide bands: the observed 36–40% sits in the middle of 25–50%, which is meant to stay winnable and clearly harder than Vow 0 without pretending we have a precise ladder yet. Point estimates from this baseline (67/76% and 36/40%) sit inside; the next tuning pass should stay inside after a holdout on disjoint seeds.

### 2. |Ashwarden − Duskblade| gap

**Draft:** paired |Ash − Dusk| **≤ 15 pp** at both gated vows; the paired 95% interval must not lie entirely outside [−15, +15] pp.

#160 forbids one aspect strictly dominating the other. This sample's Vow 0 gap is +9 pp Ash with a paired interval that only just clears zero; Vow 5 is +4 pp with zero inside the interval. Fifteen points is wide enough that this baseline passes, tight enough that a 25 pp P6-style split would fail, and it is signed as an absolute gap so either aspect leading is the same offence. Do not revive P6's "Ash leads 10–25 pp" calibration — that hypothesis is already false on current content.

### 3. Boss 6–10 turn window

**Draft:** **mean** boss length in **[6, 10]** for every act × aspect × gated vow (twelve cells). Share-in-window is reported, not gated.

P6 already owned this window as the time for boss mechanics to show. All twelve means here are inside it (6.08–9.59). Gating the mean rather than every fight keeps a long Sovereign tail (Vow 5 Dusk act 3 only 54% inside 6–10, max 15) from failing a cell whose mean is 9.28. If James wants the tail gated too, a secondary "≥60% of boss fights in 6–10" is the obvious add — it would currently fail only that one cell.

### 4. Ablation concentration

**Draft:** on a matched ≥80-run Vow 0 sample, no single **non-boss** card or relic whose removal shifts a per-aspect win rate by more than **12 pp**; no **boss relic** more than **15 pp**.

The point of the gate is "one toy deletes the run." `hollowCrown` at −12.50 pp Dusk and −6.50 pp Ash is a boss energy relic; both point estimates sit under 15 pp. `catalyst` at −6.50 pp Ash is the largest negative pool-card shift and sits under 12 pp. `duskmirror` reaches −5.00 pp Dusk. The matched sample is now n = 200 per aspect; the band remains about the point-estimate peak, not the smaller rows. Observational lifts are evidence of survivorship, never of this gate.

---

## Limits of this instrument — read before signing

Added 2026-08-13 by the reviewing session after an adversarial methodology review by a non-authoring model. Each finding below was independently re-verified before being recorded; the review's two headline "blockers" did **not** survive that check and are recorded here with the reason, because a rejected finding is still evidence about how these bands read.

1. **The four bands cannot evidence the unwaivable trio.** This is the finding that most constrains the artifact. A hand-written heuristic pilot can only explore strategies it was programmed to try, so a passing win-rate band is *no evidence at all* that no degenerate strategy trivializes a gated vow. Likewise, zero stalls in 200 seeds per cell is consistent with an unwinnable-seed rate near 0.5%. #160's trio (no trivializing strategy, no strict aspect dominance, no unwinnable seed) is **not discharged by these bands**; it needs HITL (#205) and, for the trivialize leg, something these bands do not contain. Sign the bands as a pilot-adequacy checkpoint, not as a balance guarantee.

2. **Ablation results are biased toward the pilot's coded synergies.** `card_score` grants a flat +8 to two hand-authored card-id lists (Dusk's Eclipse line, Ash's Smolder line) on top of hand-authored `RELIC_SCORE`, `_status_value` and `_special_value` tables. A pilot told to like card X builds around X and therefore suffers more when X is ablated. Band 4 measures **sensitivity of this pilot**, not tightness of the game. Cards outside those lists are not shown to be balanced — only that this instrument does not lean on them.

3. **Band 4's n = 80 sample limit has been removed; interval margin is now measured at n = 200.** `hollowCrown` is −9.50 pp combined with paired McNemar 95% **[−14.01, −4.99]** and ±4.51 pp half-width. Its combined interval now clears the −15 pp boss-relic line. Per aspect it is −12.50 pp Dusk, **[−19.30, −5.70]**, ±6.80 pp, and −6.50 pp Ash, **[−12.41, −0.59]**, ±5.91 pp. Thus both per-aspect point estimates pass the drafted 15 pp line, while the Dusk interval still reaches past it. The drafted band remains a point-estimate gate; the table above records every interval and half-width rather than treating the combined interval as per-aspect evidence. *(The earlier review's [−20.74, −1.76] still does not reproduce; at n = 200 the combined figure pairs 400 comparisons.)*

4. **Band 2's second clause is close to vacuous as drafted; measured candidate outcomes are now explicit.** "The paired 95% interval must not lie entirely outside [−15, +15] pp" is satisfied by an interval of [+14.9, +40]. Recomputing from the retained 800-run raw JSON with the same paired-difference arithmetic gives Vow 0 **+9.00 pp, [+0.08, +17.92]** and Vow 5 **+4.00 pp, [−5.30, +13.30]**. The table does not select a replacement:

| Candidate second-clause treatment | Vow 0 today | Vow 5 today | Measured rule |
|---|---:|---:|---|
| (a) Drop it; gate only \|point gap\| ≤ 15 pp | **PASS** | **PASS** | 9.00 and 4.00 pp are within 15 pp. |
| (b) Paired 95% interval entirely inside [−15, +15] pp | **FAIL** | **PASS** | Vow 0 reaches +17.92 pp; Vow 5 stays inside. |
| (c) Upper bound of the \|gap\| interval ≤ 15 pp | **FAIL** | **PASS** | Absolute upper bounds are 17.92 and 13.30 pp. |
| (c) Upper bound of the \|gap\| interval ≤ 20 pp | **PASS** | **PASS** | Both absolute upper bounds are within 20 pp. |
| (c) Upper bound of the \|gap\| interval ≤ 25 pp | **PASS** | **PASS** | Both absolute upper bounds are within 25 pp. |
| (d) Paired 95% interval must contain zero | **FAIL** | **PASS** | Vow 0's lower bound is +0.08 pp; Vow 5 contains zero. |

Candidate (d) is non-vacuous when retained alongside the 15 pp point clause: it rejects a statistically resolved direction, while the point clause continues to cap magnitude. It does not itself bound magnitude. **Choosing (b) at sign-off fails the current baseline on the day it is signed**, because Vow 0 reaches +17.92 pp. The clause as drafted passes both cells but gates almost nothing; James must choose among the measured options rather than having this artifact choose for him.

5. **No multiple-comparisons correction.** The diagnosis reports 18 intervals (4 cells, 2 aspect gaps and 12 boss-turn cells) from the same 800-run sample. Ablation adds 16 per-aspect intervals and eight derived combined intervals from 3,200 banned runs paired against the retained Vow 0 control. The bands were chosen post-hoc to fit the baseline. Future validation should treat the four bands as one joint hypothesis, not four independent gates; the marginal Vow 0 aspect gap is the interval most exposed to a correction.

Limits 3 and 4 now record the additional measurements requested before sign-off; none of the five changes a drafted band definition. All five change what the numbers may be claimed to prove.

## Lookahead

Not implemented. Not indicated. Revisit only if HITL shows this pilot still saturates or disagrees with James's device runs (#203 step 2). Any lookahead must evaluate hidden information by expectation and must not read the run RNG's future draws.
