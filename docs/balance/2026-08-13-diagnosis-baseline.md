# Balance diagnosis baseline — 2026-08-13

Issue: [fol2/glassvow#203](https://github.com/fol2/glassvow/issues/203).
Method: [fol2/glassvow#160](https://github.com/fol2/glassvow/issues/160).
Status: **SIGNED — James, 2026-08-16** on the **p8-d0-v1** bands (addendum 2026-08-14), as a **pilot-adequacy checkpoint, not a balance guarantee**, with the four adversarial amendments attached. Band 2's second clause was dropped at sign-off (point-only gate — candidate (a)); band 3 signed as mean ∈ [5.5, 10.5]; band 4 as a point-estimate gate at n = 200. Step 2 (device validation) was folded into [#205](https://github.com/fol2/glassvow/issues/205). The p7-d2-v1 bands were never signed and are superseded. See the sign-off record at the end.

**Holdout 2026-08-18:** the four signed bands **PASS** on seeds 5000–5199, n = 200, no content retune. Record: `docs/balance/2026-08-18-holdout-bands.md` (#204).

**The bands also await a re-measure, not only a signature.** #203 is wired blocked-by [Strategy landscape layer 1](https://github.com/fol2/glassvow/issues/215): Tier 1 opens the pilot's grammar so a policy can *decline* a card reward, and the measured winning deck of ~43 cards is not a build any competent human plays. A new grammar is a new instrument, so these four cells will move again and every number below is provisional against that. Signing before then would fence the game to a superseded ruler. *(Re-measured 2026-08-14 — see the addendum at the end: the numbers did not move, and that is not the same as the ruler surviving.)*

**What the two instrument defects actually cost: nothing this sample can detect.** Repairing them (`deck[0]` duplication and first-affordable event choice) moved every cell by less than its own noise — all four paired cell intervals and both gap-movement intervals contain zero at n = 200, where the half-widths run ±5 to ±6 pp. #213 and #215 both record the defects as depressing the four cells "by an unmeasured amount"; measured here, the depression is **not detectable**, and effects smaller than roughly 5 pp remain un-excluded. The repairs were still correct — a choice decided by array order is not a strategy — but they are not the explanation for anything.

Pilot `p7-d2-v1` on profile `mature-three-act-no-side-state-v1`. Content SHA-256
`633408231840d4ba47e0680d1969982cdf1ded1a61213a51bfd2bdab00f35155` (unchanged).
Godot `4.7.1-stable (official)`. Manifest commit at sim time
`a0b8e2f6e6aaf51b6542fe04f7a3bc3b3b0cc576` (pre-fix control commit; the instrument
fixes below were uncommitted in the worktree when these runs were taken).

Pre-fix control is `p7-d0-v1` on the same seeds, retained as the paired baseline.
`p7-d1-v1` raw JSON is deleted — that pilot was never valid (see valuation errors
below). The small `…-p7d1-…` CSVs stay as the record of what those errors cost.

## Headline

| Cell | Wins / runs | Win rate | Wilson 95% |
|---|---:|---:|---|
| Vow 0 Ashwarden | 149 / 200 | **74.5%** | [68.037%, 80.040%] |
| Vow 0 Duskblade | 129 / 200 | **64.5%** | [57.652%, 70.801%] |
| Vow 5 Ashwarden | 84 / 200 | **42.0%** | [35.374%, 48.928%] |
| Vow 5 Duskblade | 64 / 200 | **32.0%** | [25.927%, 38.752%] |

- **Aspect gap (paired, same seeds):** Vow 0 Ash − Dusk = **+10.00 pp**, 95% [+1.10, +18.90]; Vow 5 = **+10.00 pp**, 95% [+0.68, +19.32].
- **Boss-turn window (means):** all twelve vow × aspect × act means sit in **6–10 turns**. Shortest mean 6.071 (Vow 0 Ash act 2); longest 9.379 (Vow 0 Dusk act 3).
- **Top-3 interventional ablation shifts** (Vow 0, seeds 4000–4199, 200 runs/aspect, matched post-fix control): **hollowCrown −8.75 pp** combined (−17.00 Dusk, −0.50 Ash); **catalyst −5.25 pp** combined (−11.00 Ash); **duskmirror −4.00 pp** combined.
- **Saturation:** **did not occur.** Vow 0 max is 74.5%, not ~100%. Vow 0 vs Vow 5 CIs remain disjoint per aspect. Lookahead escalation is **not** triggered.

**Number 1 — Vow 0 Ashwarden vs the 80% ceiling.** Pre-fix was 76.0%. Post-fix is **74.5%**. The point estimate does **not** breach 80%. Wilson upper is 80.040%, which kisses the drafted ceiling; the band as drafted is still a point-estimate gate, so this cell passes. The ceiling was not moved.

**Number 2 — Ash − Dusk gap.** Hypothesis: copying `strike` (6 dmg) vs `ashBite` (5 dmg + 2 Smolder) cost Duskblade more, so a strongest-card duplicate should shrink the Ash lead by lifting Dusk. Measured paired movement, same seeds:

| Vow | Pre-fix Ash − Dusk | Post-fix Ash − Dusk | Paired movement (post − pre) |
|---|---|---|---|
| 0 | **+9.00 pp**, [+0.08, +17.92] | **+10.00 pp**, [+1.10, +18.90] | **+1.00 pp**, [−6.22, +8.22] |
| 5 | **+4.00 pp**, [−5.30, +13.30] | **+10.00 pp**, [+0.68, +19.32] | **+6.00 pp**, [−2.29, +14.29] |

Vow 0 still has Ash leading; the point gap *widened* 1.00 pp because Dusk dropped 2.50 pp while Ash dropped 1.50 pp. Both movement intervals contain zero, so this sample does **not** confirm that the duplicate defect cost Dusk more. Direction at both vows remains Ash-positive; both post-fix gap intervals now exclude zero.

## Paired before/after (same seeds 4000–4199)

| Cell | Pre-fix (`p7-d0-v1`) | Post-fix (`p7-d2-v1`) | Δ | Paired 95% |
|---|---:|---:|---:|---|
| Vow 0 Duskblade | 134 / 200 = 67.0% | 129 / 200 = 64.5% | **−2.50 pp** | [−7.78, +2.78] |
| Vow 0 Ashwarden | 152 / 200 = 76.0% | 149 / 200 = 74.5% | **−1.50 pp** | [−6.41, +3.41] |
| Vow 5 Duskblade | 72 / 200 = 36.0% | 64 / 200 = 32.0% | **−4.00 pp** | [−9.53, +1.53] |
| Vow 5 Ashwarden | 80 / 200 = 40.0% | 84 / 200 = 42.0% | **+2.00 pp** | [−4.05, +8.05] |
| Vow 0 Ash − Dusk | +9.00 pp | +10.00 pp | **+1.00 pp** | [−6.22, +8.22] |
| Vow 5 Ash − Dusk | +4.00 pp | +10.00 pp | **+6.00 pp** | [−2.29, +14.29] |

Intervals use the document's paired-difference arithmetic (sample variance of matched Bernoulli differences, n − 1 in the denominator, z = 1.9599639845). Every before/after interval contains zero.

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

- Diagnosis: **800** whole runs (4 cells × 200) under `p7-d2-v1`, plus the retained **800** `p7-d0-v1` control runs on the same seeds.
- Ablation: **3,200** additional banned whole runs (8 bans × 2 aspects × 200) under `p7-d2-v1`, each paired with the post-fix Vow 0 control. The pre-fix `…-ablation-n200-<id>.json` files remain as the paired instrument control.
- Stalls = 0 and simulator errors = 0 in every post-fix cell and every post-fix ablation file.

Raw files: post-fix `docs/balance/data/2026-08-13-p7d2-vow0.json`, `…-p7d2-vow5.json`,
`…-p7d2-ablation-n200-<id>.json`, plus CSV slices `…-p7d2-cells.csv`,
`…-p7d2-boss-turns.csv`, `…-p7d2-economy.csv`, `…-p7d2-ablation-n200.csv`,
`…-p7d2-runs.csv`. Every pre-fix `2026-08-13-vow0.json` / `…-vow5.json` /
`…-ablation-n200-<id>.json` / CSV file is kept. The `…-p7d1-….csv` slices remain
as the record of the invalid first correction; the `…-p7d1-….json` dumps were
deleted. The original n = 80 `…-ablation-<id>.json` files remain as prior evidence.

## What the instrument fix was

Two original layout-order defects in `tools/balance_sim.gd` (`p7-d0-v1`):

1. **Duplicate.** `deck[0]` was always `strike` (Dusk) or `ashBite` (Ash) because
   `RunState.new_run` appends `startDeck` in authoring order. Post-fix uses
   `Pilot.best_card()` / `card_score`. Do not touch this; it is correct.
2. **Event choice.** The first affordable authored row always won.

The first correction (`p7-d1-v1`) repaired both, then scored affordable rows from
existing valuations — and introduced three valuation errors:

1. **`pickCard` scored 0.** A placeholder, not a judgement. `library` would then
   lose to `{heal: 0.2}` (9.8 on a Dusk start). Binding acceptance: `library`
   must choose `[0] {pickCard: 5}`.
2. **`maxHp` scored 0.** No existing per-point valuation was wired. The only
   authored use is `fleshTrader[0]` `{maxHp: -8}`.
3. **`pickRemove` = `shop.removeCost * SHOP_MIN_RATIO` = 4.5.** `SHOP_MIN_RATIO`
   (0.06) is a *threshold* — the minimum value-per-gold the pilot will accept —
   not a conversion rate. Using it as one values a removal at the worst price
   the pilot would tolerate, which systematically under-values it. That
   specification is withdrawn.

`p7-d2-v1` keeps combat, shop and `card_score` heuristics unchanged (Limit 2)
and values each event op from an existing instrument quantity. No new scoring
table.

| Op | Score | Derivation |
|---|---|---|
| `gold n` | `n * SHOP_MIN_RATIO` | existing shop threshold, applied to gold |
| `hp n` | `card_score` of `heal` / `loseHp` \|n\| | existing heal / loseHp weights (0.7 / 0.4) |
| `heal f` | `card_score` of `heal` `round(maxHp * f)` | same weights |
| `maxHp n` | `card_score` of `loseHp` \|n\| | loseHp weights only; under-values permanence of a max-HP change |
| `addCard id` | `card_score(id)` | existing |
| `addRelic id` | `relic_score(id)`; `random` uses pool × 0.5 / 0.35 / 0.15 | existing `_random_relic` weights |
| `potion` | `mean(shop.potionPrice) * SHOP_MIN_RATIO` = 3.3 | (48 + 62) / 2 × 0.06 |
| `pickRemove` | `8.5 - card_score(worst)` | shop-remove numerator at `tools/balance_pilot.gd:450` (in `choose_shop`); worst card via `Pilot.worst_card` |
| `pickCard n` | E[max of n] from `card_pool` weighted common×2, uncommon×2, rare×1 | no RNG; read the pools |
| `pickUpgrade` | best `card_score(up) − card_score(base)` in deck | existing rest-site upgrade delta |
| `pickDuplicate` | `card_score(best_card)` | same `best_card` as the duplicate fix |
| `roll` | Σ p × nested choice score | expectation over authored branches |

Acceptance, measured on a Dusk start deck (seed 7):

- **`library` (binding):** `[0] {pickCard: 5}` = **28.345** beats `[1] {heal: 0.2}` = **9.8**. Must choose `[0]`.
- **`forgottenShrine` (reported, not gated):** `[0] {pickRemove}` = **6.0** (`8.5 − 2.5` on `defend`) vs `[1] {gold: 90, addCard: hex}` = **5.4**. The winner legitimately depends on how bad the deck's worst card is; a valuation that always returns the same answer regardless of deck state would be the defect. `forgottenShrine[1]` is *over*-valued because `hex` scores ~0 (`card_score` does not read `endTurnLoseHp`) — that is the standing Limit 2, out of scope here, and it biases this particular comparison toward the gold option.

Determinism pin: `tests/test_balance_sim.gd` seed 1000 digest
`b38410ee207c477b1f0048dec350d1488a100937750150b2a4fd04d69eae6710` (`p7-d0-v1`) →
`9ea56ecf0201ea89325b30aa7d403b4da4e3c684df461853b11f7053c6ac260a` (`p7-d1-v1`, invalid) →
`b38410ee207c477b1f0048dec350d1488a100937750150b2a4fd04d69eae6710` (`p7-d2-v1`).
The p7-d2 pin coincides with p7-d0: seed 1000 does not take a path where the
corrected valuations diverge. The 4000–4199 sample does.

`p6-b0-v1` scored cards by rarity, skipped Ashwarden's Smother except as lethal Ward, bought one shop item in category order, and over-weighted Eclipse with a flat +1000. `p7-d0-v1` keeps the same RNG contract (incoming forecast clones the stream; no future-draw peek) and changes three heuristics:

1. **Valuation.** Effect-kind scores plus triangular Smolder expectation, Vulnerable/Shatter weights, and named specials (`catalyst`, `shatterEcho`, …). Aspect bonuses on the Eclipse/Shatter line (Dusk) and the Smolder line (Ash).
2. **Combat.** Preview loss/block/lethal/shatter is the primary score. Eclipse is played as a Vulnerable setup when another attack is in hand. Catalyst targets the highest Smolder. Non-lethal Ward is played when unblocked intent remains. Smother is no longer skipped.
3. **Shop.** Greedy value/gold, multiple buys, one remove of a tripled weak starter when the ratio beats the next buy. Routing prefers a shop when gold ≥ 140.

## Four cells

Vow 0 vs Vow 5 is the discrimination the sample was sized for. 200 runs/cell gives Wilson half-widths of ~6 pp at these rates. Vow 0 vs Vow 5 CIs remain disjoint per aspect (Dusk 57.7–70.8% vs 25.9–38.8%; Ash 68.0–80.0% vs 35.4–48.9%). Both aspect-gap intervals now exclude zero.

Relative to P6's final holdout (seeds 2200–2999, weak pilot): Vow 0 is 64.5/74.5% (Dusk/Ash) against P6's 62.9/67.5%; Vow 5 is 32.0/42.0% against P6's 20.9/20.5%. A stronger pilot winning more at Vow 0 is the expected direction. Vow 5 Dusk at 32.0% sits 7 pp above the drafted 25% floor.

## Boss turns

Means (all fights that are `kind=boss`):

| Vow | Aspect | Act 1 | Act 2 | Act 3 |
|---|---|---:|---:|---:|
| 0 | Ashwarden | 6.190 | 6.071 | 8.219 |
| 0 | Duskblade | 6.675 | 6.640 | 9.379 |
| 5 | Ashwarden | 6.753 | 6.465 | 8.475 |
| 5 | Duskblade | 7.377 | 7.320 | 9.176 |

Share of those fights whose length is 6–10 turns is 71–90% except Vow 0 Ash act 2 (**71.4%**, 130 / 182) and Vow 5 Dusk act 3 (**65.9%**, 56 / 85, min 3 max 17). Hallway `turnsPerFight` in the summary (~2.7–3.5) is not the boss window; it averages trash with bosses.

Ash Smolder kills/fight exceed Dusk in every act at both vows. Dusk shatters/fight exceed Ash in every act at both vows. The two signatures are firing.

## Economy and runs-to-endgame

Gold earned on wins is ~939–983; on losses ~502–606. Winning decks finish around 43 cards; losses die earlier around 30–32. Gold at the act-1 boss is ~202–214; act-2 ~278–304; act-3 end-gold ~232–281. Vow 5 spends more HP to get there (act-1 boss HP ~35–38 vs ~47–50 at Vow 0).

**Runs to a 3-act win** (geometric 1/p, this profile):

| Cell | E[runs] |
|---|---:|
| Vow 0 Ashwarden | 1.34 |
| Vow 0 Duskblade | 1.55 |
| Vow 5 Ashwarden | 2.38 |
| Vow 5 Duskblade | 3.13 |

**Six Shards / Act IV is not modeled.** The sim profile is `mature-three-act-no-side-state-v1` (`quests: {}`, `shards: []`). The 1/p figures above are **three-act clears, not vigil progression**, so they do not answer #160's "runs-to-endgame per vow" — that diagnostic is deferred to a later profile, not substituted here.

## Ablation

Observational "has item → higher win rate" is survivorship (a boss relic is only held if a boss died) and is **not** the gate. The table below is interventional: same seeds 4000–4199, item banned from start deck, relics, rewards and shop, compared to the unbanned **post-fix** control on those seeds (Dusk 129/200 = 64.50%, Ash 149/200 = 74.50%). Each cell reports point delta; paired McNemar 95% interval; achieved half-width.

| Item | Dusk Δ; paired 95%; ±half-width | Ash Δ; paired 95%; ±half-width | Combined Δ; paired 95%; ±half-width |
|---|---:|---:|---:|
| hollowCrown | **−17.00 pp; [−24.99, −9.01]; ±7.99** | −0.50 pp; [−5.79, +4.79]; ±5.29 | **−8.75 pp; [−13.61, −3.89]; ±4.86** |
| duskmirror | −3.00 pp; [−5.37, −0.63]; ±2.37 | −5.00 pp; [−8.33, −1.67]; ±3.33 | **−4.00 pp; [−6.04, −1.96]; ±2.04** |
| catalyst | +0.50 pp; [−3.04, +4.04]; ±3.54 | **−11.00 pp; [−16.52, −5.48]; ±5.52** | −5.25 pp; [−8.57, −1.93]; ±3.32 |
| emberLantern | −3.50 pp; [−8.58, +1.58]; ±5.08 | −3.00 pp; [−6.65, +0.65]; ±3.65 | −3.25 pp; [−6.38, −0.12]; ±3.13 |
| venomStrike | 0.00 pp; [−2.78, +2.78]; ±2.78 | +2.00 pp; [−4.21, +8.21]; ±6.21 | +1.00 pp; [−2.40, +4.40]; ±3.40 |
| virulence | +1.00 pp; [−3.61, +5.61]; ±4.61 | +4.00 pp; [−0.98, +8.98]; ±4.98 | +2.50 pp; [−0.89, +5.89]; ±3.39 |
| warCry | +2.50 pp; [−4.23, +9.23]; ±6.73 | +2.50 pp; [−1.03, +6.03]; ±3.53 | +2.50 pp; [−1.29, +6.29]; ±3.79 |
| eclipseSlash | +0.50 pp; [−8.45, +9.45]; ±8.95 | 0.00 pp; [0.00, 0.00]; ±0.00 | +0.25 pp; [−4.22, +4.72]; ±4.47 |

`hollowCrown` at **−17.00 pp Dusk** is a boss energy relic and **fails** the drafted 15 pp boss-relic point line. The threshold was not raised to accommodate it. `catalyst` at −11.00 pp Ash is the largest negative pool-card shift and sits under 12 pp. `venomStrike` banned no longer raises Ash (p7-d1's +7.00 pp was an artifact of the invalid scorer). `eclipseSlash` stripped from the Dusk start deck is +0.50 pp; do not read it as a nerf recommendation.

n = 200 per aspect and 400 combined. The intervals use the document's existing paired-difference arithmetic: the sample variance of matched Bernoulli differences with n − 1 in the denominator and z = 1.9599639845. The combined figure pairs 400 comparisons, not 200.

## Saturation check

P6's failure mode was a weak pilot at 63–68% while humans sat at ~100%, destroying contrast. `p7-d2-v1` at Vow 0 is 64.5–74.5% with a 10.0 pp aspect gap whose interval excludes zero, and a 30+ pp vow gap. **Not saturated. Do not escalate to lookahead in this slice.**

Caveat for HITL: a competent human will still beat this heuristic. If James's device runs are near 100% at Vow 0, the *bands* can still use this pilot as the instrument, but Vow 0's player-facing challenge is then a separate question (#205, and the "Vow 0 must itself always be challenging" decision in #160).

---

## Four bands — p7 draft, never signed (superseded by the signed p8 bands in the addendum)

Instrument: headless `p7-d2-v1` on `mature-three-act-no-side-state-v1`, diagnosis seeds held out from any later proof. Gated vows are 0 (primary) and 5 (sanity). Vows 1–4 ungated. Thresholds below are the same numbers drafted against `p7-d0-v1`; commentary is recomputed on the post-fix sample. Where a post-fix point now fails a drafted line, the line is **not** moved.

> **Read "Limits of this instrument" below before signing.** An adversarial methodology review by a non-authoring model raised five findings that survived independent verification; two of them change what bands 2 and 4 can honestly claim, and one bounds what all four bands can claim together.

### 1. Win-rate band per gated vow × aspect

**Draft:** Vow 0 each aspect **60–80%**; Vow 5 each aspect **25–50%**.

Vow 0 must be challenging rather than a tutorial, and this pilot is already a fair bit stronger than `p6-b0-v1`, so a floor at 60% keeps the cell above a coin-flip without licensing saturation, while an 80% ceiling leaves room under the 100% human cap that wrecked P6. Point estimates (64.5 / 74.5% and 32.0 / 42.0%) sit inside. Vow 0 Ash's Wilson upper (80.040%) kisses the ceiling; the point does not breach it. Vow 0 Dusk at 64.5% sits 4.5 pp above the 60% floor. Vow 5 Dusk at 32.0% sits 7 pp above the 25% floor. The next tuning pass should stay inside after a holdout on disjoint seeds.

### 2. |Ashwarden − Duskblade| gap

**Draft:** paired |Ash − Dusk| **≤ 15 pp** at both gated vows; the paired 95% interval must not lie entirely outside [−15, +15] pp.

#160 forbids one aspect strictly dominating the other. This sample's Vow 0 gap is +10.00 pp Ash with zero *outside* the interval; Vow 5 is +10.00 pp with zero outside. Fifteen points still passes both *point* estimates. Do not revive P6's "Ash leads 10–25 pp" calibration.

### 3. Boss 6–10 turn window

**Draft:** **mean** boss length in **[6, 10]** for every act × aspect × gated vow (twelve cells). Share-in-window is reported, not gated.

P6 already owned this window as the time for boss mechanics to show. All twelve means here are inside it (6.071–9.379). Gating the mean rather than every fight keeps a long Sovereign tail (Vow 5 Dusk act 3 65.9% inside 6–10, max 17) from failing a cell whose mean is 9.176. If James wants the tail gated too, a secondary "≥60% of boss fights in 6–10" is the obvious add — it would currently pass all twelve cells.

### 4. Ablation concentration

**Draft:** on a matched ≥80-run Vow 0 sample, no single **non-boss** card or relic whose removal shifts a per-aspect win rate by more than **12 pp**; no **boss relic** more than **15 pp**.

The point of the gate is "one toy deletes the run." `hollowCrown` at **−17.00 pp Dusk** and −0.50 pp Ash is a boss energy relic. The Dusk point estimate **fails** the drafted 15 pp line. That line is not raised here. `catalyst` at −11.00 pp Ash is the largest negative pool-card shift and sits under 12 pp. `duskmirror` reaches −5.00 pp Ash. The matched sample is n = 200 per aspect; the band remains about the point-estimate peak, not the smaller rows. Observational lifts are evidence of survivorship, never of this gate.

---

## Limits of this instrument — read before signing

Added 2026-08-13 by the reviewing session after an adversarial methodology review by a non-authoring model. Each finding below was independently re-verified before being recorded; the review's two headline "blockers" did **not** survive that check and are recorded here with the reason, because a rejected finding is still evidence about how these bands read. Measured bases below are the `p7-d2-v1` re-run; the five limit *claims* are unchanged.

1. **The four bands cannot evidence the unwaivable trio.** This is the finding that most constrains the artifact. A hand-written heuristic pilot can only explore strategies it was programmed to try, so a passing win-rate band is *no evidence at all* that no degenerate strategy trivializes a gated vow. Likewise, zero stalls in 200 seeds per cell is consistent with an unwinnable-seed rate near 0.5%. #160's trio (no trivializing strategy, no strict aspect dominance, no unwinnable seed) is **not discharged by these bands**; it needs HITL (#205) and, for the trivialize leg, something these bands do not contain. Sign the bands as a pilot-adequacy checkpoint, not as a balance guarantee.

2. **Ablation results are biased toward the pilot's coded synergies.** `card_score` grants a flat +8 to two hand-authored card-id lists (Dusk's Eclipse line, Ash's Smolder line) on top of hand-authored `RELIC_SCORE`, `_status_value` and `_special_value` tables. A pilot told to like card X builds around X and therefore suffers more when X is ablated. Band 4 measures **sensitivity of this pilot**, not tightness of the game. Cards outside those lists are not shown to be balanced — only that this instrument does not lean on them. The two layout-order repairs do not change this limit: they stopped array order from impersonating strategy; they did not add strategy. `hex` scoring ~0 (`endTurnLoseHp` unread) is this same limit, and it over-values `forgottenShrine[1]`.

3. **Band 4's n = 80 sample limit has been removed; interval margin is now measured at n = 200.** `hollowCrown` is −8.75 pp combined with paired McNemar 95% **[−13.61, −3.89]** and ±4.86 pp half-width. Per aspect it is **−17.00 pp Dusk**, **[−24.99, −9.01]**, ±7.99 pp, and −0.50 pp Ash, **[−5.79, +4.79]**, ±5.29 pp. The Dusk *point* estimate fails the drafted 15 pp line; the Ash point passes. The drafted band remains a point-estimate gate; the table above records every interval and half-width rather than treating the combined interval as per-aspect evidence.

4. **Band 2's second clause is close to vacuous as drafted; measured candidate outcomes are now explicit.** "The paired 95% interval must not lie entirely outside [−15, +15] pp" is satisfied by an interval of [+14.9, +40]. Recomputing from the post-fix 800-run raw JSON with the same paired-difference arithmetic gives Vow 0 **+10.00 pp, [+1.10, +18.90]** and Vow 5 **+10.00 pp, [+0.68, +19.32]**. The table does not select a replacement:

| Candidate second-clause treatment | Vow 0 today | Vow 5 today | Measured rule |
|---|---:|---:|---|
| (a) Drop it; gate only \|point gap\| ≤ 15 pp | **PASS** | **PASS** | 10.00 and 10.00 pp are within 15 pp. |
| (b) Paired 95% interval entirely inside [−15, +15] pp | **FAIL** | **FAIL** | Vow 0 reaches +18.90 pp; Vow 5 reaches +19.32 pp. |
| (c) Upper bound of the \|gap\| interval ≤ 15 pp | **FAIL** | **FAIL** | Absolute upper bounds are 18.90 and 19.32 pp. |
| (c) Upper bound of the \|gap\| interval ≤ 20 pp | **PASS** | **PASS** | Both absolute upper bounds are within 20 pp. |
| (c) Upper bound of the \|gap\| interval ≤ 25 pp | **PASS** | **PASS** | Both absolute upper bounds are within 25 pp. |
| (d) Paired 95% interval must contain zero | **FAIL** | **FAIL** | Vow 0's lower bound is +1.10 pp; Vow 5's is +0.68 pp. |

Candidate (d) is non-vacuous when retained alongside the 15 pp point clause: it rejects a statistically resolved direction, while the point clause continues to cap magnitude. It does not itself bound magnitude. **Choosing (d) at sign-off fails both gated vows on the day they are signed.** Choosing (b) or (c) at 15 pp fails both cells. The clause as drafted still passes both cells but gates almost nothing; James must choose among the measured options rather than having this artifact choose for him.

5. **No multiple-comparisons correction.** The diagnosis reports 18 intervals (4 cells, 2 aspect gaps and 12 boss-turn cells) from the same 800-run sample. Ablation adds 16 per-aspect intervals and eight derived combined intervals from 3,200 banned runs paired against the retained Vow 0 control. The bands were chosen post-hoc to fit the `p7-d0-v1` baseline; this re-run did not retune them. Future validation should treat the four bands as one joint hypothesis, not four independent gates. The intervals most exposed to a correction are now both aspect gaps (zero outside at both vows) and `hollowCrown`'s Dusk ablation.

Limits 3 and 4 record the post-fix measurements; none of the five changes a drafted band *definition*. Band 4's Dusk `hollowCrown` point and band 2's two gap intervals are the measured bases that moved.

## Lookahead

Not implemented. Not indicated. Revisit only if HITL shows this pilot still saturates or disagrees with James's device runs (#203 step 2). Any lookahead must evaluate hidden information by expectation and must not read the run RNG's future draws.

## Addendum — 2026-08-14 re-measure on the Tier 1 grammar

Re-run on main `bf1ecdb` (post-#230 Tier 1 grammar, post-#218 shard-derived
final act, post-#224/#216), same pilot `p7-d2-v1`, same seeds 4000–4199, same
content SHA `6334082318…` (unchanged).

**Every re-measured number is bit-identical to this document.** All four
diagnosis cells (129/200, 149/200, 64/200, 84/200 — 64.5% / 74.5% / 32.0% /
42.0%), their Wilson intervals, and a spot-checked ablation cell
(`hollowCrown`: Dusk 95/200, Ash 148/200) reproduce exactly. This is by
construction, not coincidence: Tier 1 ships with every grammar knob at its
pre-grammar behaviour (`CARD_DECLINE_DEFAULT = -1.0e9` — the default pilot
never declines), #218's boss-relic gate resolves identically in a three-act
run, and the sim is seed-deterministic. The default instrument's readings
stand; the deterministic replay key of this document remains valid on main.
Raw re-run files: `/private/tmp/glassvow-203-remeasure/` (vow0.json,
vow5.json, ablation-hollowCrown.json).

**Reproducing is not the same as surviving.** #215's control arms measured the
thing this pilot cannot see about itself: at Vow 0, **arm 2 — random build,
competent play — beats this pilot's planned build** (Dusk 80.5% vs 64.5%, Ash
87.5% vs 74.5%). A build policy that loses to uniform-random picking is not a
"substantially stronger heuristic" in the sense step 1 of #203 requires; it is
the non-discrimination failure #160 warned about, now with a measured
direction. Step 1's "upgrade the pilot until the statistics discriminate"
clause is therefore **re-triggered**, and the four drafted bands must not be
signed against `p7-d2-v1`: they would anchor the game's difficulty to an
instrument measurably worse at building than chance.

**What the next instrument is anchored on is a decision, not a derivation.**
The policy vector (#215 slice B) makes the pilot parameterisable; the open
choice is which policy the diagnosis pins as "competent":

1. **Top-decile-informed default** — set the default vector from the sweep's
   top-decile audit profile (high draw/energy and regen valuation, low decline
   threshold). Anchors bands to *measured competent play inside the grammar*.
   Recommended.
2. **CEM optimum** — the layer-2 argmax. Wrong anchor for bands: it is the
   ceiling (Vow 5 91–94%), not a competent human.
3. **Keep `p7-d2-v1`** — rejected above; loses to random build at Vow 0.

Option 1 needs its own adequacy check before any band is drafted against it:
it must beat arm 2 at Vow 0 on paired seeds, and the four cells must still
separate. That validation, the re-drafted bands, and James's signature are
what remain of #203.

---

## Addendum — 2026-08-14 p8-d0-v1 (top-decile default)

James delegated the #203 anchor to option 1 (planner session 2026-08-14).
Pilot `p8-d0-v1` is that instrument. The p7-d2-v1 bands above are **not** the
signature target.

Godot `4.7.1-stable (official)`. Content SHA-256
`633408231840d4ba47e0680d1969982cdf1ded1a61213a51bfd2bdab00f35155` (unchanged).
Profile `mature-three-act-no-side-state-v1`. Seeds **4000–4199** (diagnosis
block; holdout 5000+ untouched). Manifest `commit` at sim time is worktree HEAD
`104d818b9ae121b82e127183bd59f967735c5587`; the p8 default was uncommitted in
this worktree, same pattern as the p7-d2 control.

Every headline number below recomputes from
`docs/balance/data/2026-08-14-p8d0-*.json` with this document's arithmetic
(Wilson / paired difference, z = 1.9599639845, n − 1 in the paired variance).
CSV slices: `…-p8d0-cells.csv`, `…-p8d0-boss-turns.csv`, `…-p8d0-economy.csv`,
`…-p8d0-runs.csv`, `…-p8d0-ablation-n200.csv`.

### Vector derivation + provenance

`BalancePolicy.default()` is the **componentwise median of the four #215
top-deciles** (Dusk/Ash × Vow 0/5, 200 policies each = 800 observations). A
policy in more than one top-decile is counted once per grid. Integer knobs
(`removalMinCopies`, `restHpPct`, `potionHealMissing`, `routeLowHpPct`,
`shopGoldLow`, `shopGoldHigh`) are rounded to nearest int after the median.
Construction and per-grid checks:
`docs/balance/data/2026-08-14-p8-default-derivation.json`.

The four-grid auditor in `docs/balance/2026-08-14-strategy-landscape.md` (and
`/private/tmp/glassvow-215-slice-c/sweep/analysis.json`) is the source, not a
paraphrase. Recomputed top-200 medians match that audit bit-for-bit on the
published fingerprint paths:

| Grid (cutoff) | `card.drawEnergy` top median | `status.regen` | `cardDecline` |
|---|---:|---:|---:|
| Dusk V0 (75.0%) | 10.05878415317795 | 10.4527410380887 | 13.974294066429149 |
| Dusk V5 (40.0%) | 10.4412650565421 | 12.357756913535251 | 13.9244389627129 |
| Ash V0 (82.5%) | 8.889488865874636 | 10.5010444153098 | 15.82626729737965 |
| Ash V5 (50.0%) | 10.2766173984526 | 12.4427187507917 | 13.68352461606265 |

Pooled-800 p8 defaults vs frozen p7 origin:

| Knob | p7-d2-v1 | p8-d0-v1 |
|---|---:|---:|
| `card.drawEnergy` | 4.5 | **10.03605729808525** |
| `status.regen` | 6.0 | **11.76985144414705** |
| `cardDecline` | −1e9 (never decline) | **14.0958831273019** |
| `restHpPct` | 70 | **67** |
| `removalAppetite` | 8.5 | **16.4400114826858** |
| `removalMinCopies` | 3 | **2** |
| `shopMinRatio` | 0.06 | **0.06475653649074956** |
| `relics.hollowCrown` | 90 | **129.500764113312** |

The rest of the vector is the same construction (full median, not a
fingerprint-only patch). `Pilot.VERSION = p8-d0-v1`. CLI T1 knobs
(`CARD_DECLINE_DEFAULT`, `REMOVAL_APPETITE_DEFAULT`,
`REMOVAL_MIN_COPIES_DEFAULT`) match those medians so
`godot --headless -s res://tools/balance_sim.gd -- --vow=0 --runs=200 --seed0=4000`
applies p8, not a T1 override back to p7.

`BalancePolicy.sample_origin()` freezes the p7-d2-v1 constants.
`sample_range` and CEM encode against that origin so #215 / #216 replay stays
bit-identical. Live `resolve({})` / empty `apply_policy` uses p8 `default()`.

Seed-1000 digest `eaeacd084dd9793a1a924ea2b5850c99453e38227c55bb09bb38dc0da45fdcb0`.
Event scores on a Dusk start (seed 7): library `[0]=27.202 [1]=11.870`;
forgottenShrine `[0]=13.201 [1]=5.828` — still chooses `[0]` on both.

### Adequacy check — PASS

Paired seeds 4000–4199, Vow 0, both aspects, vs #215 arm 2 (random build,
competent play: Dusk 161/200 = 80.5%, Ash 175/200 = 87.5%).

| Cell | p8 | arm 2 | Paired Δ; 95% |
|---|---:|---:|---|
| Vow 0 Duskblade | **178 / 200 = 89.0%** | 161 / 200 = 80.5% | **+8.50 pp; [+1.31, +15.69]** |
| Vow 0 Ashwarden | **185 / 200 = 92.5%** | 175 / 200 = 87.5% | **+5.00 pp; [−0.51, +10.51]** |

Both **point estimates beat arm 2**. Dusk's paired interval excludes zero. Ash's
interval includes zero — the +5.00 pp lift is not resolved at n = 200. The
binding was point-estimate "beat"; both cells pass. Stalls = 0, errors = 0.

Four diagnosis cells, Wilson 95%, Vow 0 vs Vow 5 disjoint per aspect:

| Cell | Wins / runs | Win rate | Wilson 95% |
|---|---:|---:|---|
| Vow 0 Ashwarden | 185 / 200 | **92.5%** | [87.996%, 95.403%] |
| Vow 0 Duskblade | 178 / 200 | **89.0%** | [83.907%, 92.623%] |
| Vow 5 Ashwarden | 162 / 200 | **81.0%** | [74.999%, 85.833%] |
| Vow 5 Duskblade | 128 / 200 | **64.0%** | [57.142%, 70.331%] |

- Dusk V0 [83.907, 92.623] vs V5 [57.142, 70.331]: **disjoint**.
- Ash V0 [87.996, 95.403] vs V5 [74.999, 85.833]: **disjoint**.

Adequacy does **not** fail. Diagnosis + ablation proceeded.

### Four cells (p8)

Aspect gap (paired, same seeds): Vow 0 Ash − Dusk = **+3.50 pp**, 95%
[−2.46, +9.46]; Vow 5 = **+17.00 pp**, 95% [+8.89, +25.11].

**Runs to a 3-act win** (geometric 1/p; still not vigil progression):

| Cell | E[runs] |
|---|---:|
| Vow 0 Ashwarden | 1.08 |
| Vow 0 Duskblade | 1.12 |
| Vow 5 Ashwarden | 1.23 |
| Vow 5 Duskblade | 1.56 |

Winning decks finish around 42–44 cards (Dusk V0 win 42.48; Ash V5 win 44.06).
cardDecline 14.1 does **not** collapse the diagnosis decks to thin — the
top-decile fingerprint was fat.

Saturation: Vow 0 max is 92.5%, Wilson upper 95.403%, not ~100%. Lookahead
escalation is **not** triggered. A competent human can still beat this
heuristic; HITL (#203 step 2) remains.

### Boss turns (p8)

Means (`kind=boss`):

| Vow | Aspect | Act 1 | Act 2 | Act 3 |
|---|---|---:|---:|---:|
| 0 | Ashwarden | 5.914 | 5.949 | 7.947 |
| 0 | Duskblade | 6.725 | 6.568 | 9.598 |
| 5 | Ashwarden | 6.588 | 6.451 | 8.485 |
| 5 | Duskblade | 7.505 | 7.250 | 10.157 |

Shortest mean **5.914** (Vow 0 Ash act 1). Longest **10.157** (Vow 5 Dusk act 3).
Share-in-window 6–10 is 60.0–92.5%; lowest is Vow 5 Dusk act 3 (**60.0%**,
84 / 140). Three means sit outside the p7 [6, 10] gate: Vow 0 Ash act 1 and 2
below 6, Vow 5 Dusk act 3 above 10. A stronger pilot shortens early Ash bosses.

### Ablation (p8)

Interventional `--ban=`, Vow 0, seeds 4000–4199, n = 200 per aspect, matched to
the p8 unbanned control (Dusk 178/200 = 89.00%, Ash 185/200 = 92.50%). Same
eight IDs as the p7 table.

**Amendment 3 sample choice:** keep **n = 200** per aspect. The ±5 pp half-width
target needs ~131; 200 already meets it on the largest shift (hollowCrown Dusk
±4.59 pp). Did not drop to 131 (would widen). Did not raise further (not
needed). Existing p7 sample size, not a new budget.

| Item | Dusk Δ; paired 95%; ±half-width | Ash Δ; paired 95%; ±half-width | Combined Δ; paired 95%; ±half-width |
|---|---:|---:|---|
| hollowCrown | **−7.50 pp; [−12.09, −2.91]; ±4.59** | +3.00 pp; [−0.08, +6.08]; ±3.08 | −2.25 pp; [−5.06, +0.56]; ±2.81 |
| emberLantern | −2.00 pp; [−4.39, +0.39]; ±2.39 | +0.50 pp; [−1.70, +2.70]; ±2.20 | −0.75 pp; [−2.38, +0.88]; ±1.63 |
| duskmirror | 0.00 pp; [−1.39, +1.39]; ±1.39 | −1.00 pp; [−2.38, +0.38]; ±1.38 | −0.50 pp; [−1.48, +0.48]; ±0.98 |
| eclipseSlash | −0.50 pp; [−6.79, +5.79]; ±6.29 | 0.00 pp; [0.00, 0.00]; ±0.00 | −0.25 pp; [−3.39, +2.89]; ±3.14 |
| catalyst | 0.00 pp; [0.00, 0.00]; ±0.00 | −0.50 pp; [−2.70, +1.70]; ±2.20 | −0.25 pp; [−1.35, +0.85]; ±1.10 |
| virulence | −0.50 pp; [−2.70, +1.70]; ±2.20 | +2.50 pp; [−0.08, +5.08]; ±2.58 | +1.00 pp; [−0.70, +2.70]; ±1.70 |
| warCry | +2.00 pp; [−2.16, +6.16]; ±4.16 | 0.00 pp; [0.00, 0.00]; ±0.00 | +1.00 pp; [−1.08, +3.08]; ±2.08 |
| venomStrike | +1.50 pp; [−0.69, +3.69]; ±2.19 | +0.50 pp; [−3.55, +4.55]; ±4.05 | +1.00 pp; [−1.30, +3.30]; ±2.30 |

No row fails a 12 pp non-boss or 15 pp boss-relic **point** line. hollowCrown
Dusk −7.50 pp is the largest negative shift (p7 was −17.00 pp on this relic).
catalyst Ash is −0.50 pp (p7 was −11.00 pp). Ceiling effects at 89–92% Vow 0
compress ablation deltas; band 4 still measures **sensitivity of this pilot**.

### Wall-clock

| Sweep | UTC start | UTC end | wall |
|---|---|---|---:|
| Vow 0 diagnosis (400 runs) | 2026-08-14T21:58:19Z | 21:58:50Z | **31 s** |
| Vow 5 diagnosis (400 runs) | 2026-08-14T21:58:20Z | 21:58:50Z | **30 s** |
| ablation hollowCrown | 22:01:30Z | 22:02:09Z | **39 s** |
| ablation duskmirror | 22:01:33Z | 22:02:15Z | **42 s** |
| ablation catalyst | 22:01:36Z | 22:02:20Z | **44 s** |
| ablation emberLantern | 22:01:39Z | 22:02:23Z | **44 s** |
| ablation venomStrike | 22:01:41Z | 22:02:26Z | **45 s** |
| ablation virulence | 22:01:44Z | 22:02:27Z | **43 s** |
| ablation warCry | 22:01:47Z | 22:02:29Z | **42 s** |
| ablation eclipseSlash | 22:01:47Z | 22:02:29Z | **42 s** |

Diagnosis pair ran in parallel; the eight ablations ran as eight Godot
processes. Per-run cost ~75–110 ms once Godot is up.

### Four bands — SIGNED against p8-d0-v1 (James, 2026-08-16)

Re-fitted to this instrument. The p7 60–80 / 25–50 / 15 pp / [6, 10] lines do
not contain these points. The four adversarial-review amendments follow
**verbatim** as caveats; they are not weakened by the re-fit.

#### 1. Win-rate band per gated vow × aspect

**Signed:** Vow 0 each aspect **80–97%**; Vow 5 each aspect **55–85%**.

p7's 60–80 / 25–50 sat around 64.5–74.5 and 32–42. p8 sits at 89.0 / 92.5 and
64.0 / 81.0. The floor stays above arm 2's Vow 0 Dusk 80.5% so the instrument
cannot regress to "loses to random build." The 97% ceiling leaves room under
100%. Point estimates sit inside. Vow 0 Ash's Wilson upper (95.403%) is under
the ceiling. Vow 5 Dusk at 64.0% sits 9 pp above the 55% floor. Vow 5 Ash at
81.0% sits 4 pp under 85%.

#### 2. |Ashwarden − Duskblade| gap

**Signed:** paired |Ash − Dusk| point estimate **≤ 20 pp** at both gated vows.
The drafted second clause ("the paired 95% interval must not lie entirely
outside [−20, +20] pp") was **dropped at sign-off** — candidate (a) below —
per amendment 2: that clause shape is vacuous at any cap.

p7's 15 pp line **fails** Vow 5's **+17.00 pp** point. Twenty points is the
same kind of round cap with ~3 pp margin on the measured 17.00 that fifteen
had on p7's 10.00. Vow 0 is +3.50 pp with zero inside the interval. Measured
second-clause candidates (amendment 2 still applies):

| Candidate second-clause treatment | Vow 0 today | Vow 5 today |
|---|---|---|
| (a) Drop it; gate only \|point gap\| ≤ 20 pp | **PASS** (3.50) | **PASS** (17.00) |
| (a′) \|point gap\| ≤ 15 pp | **PASS** | **FAIL** (17.00) |
| (b) Paired 95% interval entirely inside [−20, +20] pp | **PASS** | **FAIL** (reaches +25.11) |
| (c) Upper bound of the \|gap\| interval ≤ 20 pp | **PASS** (9.46) | **FAIL** (25.11) |
| (c) Upper bound of the \|gap\| interval ≤ 26 pp | **PASS** | **PASS** |
| (d) Paired 95% interval must contain zero | **PASS** | **FAIL** (lower +8.89) |

Choosing (a′) or (d) at sign-off fails Vow 5 on the day they are signed.

#### 3. Boss 6–10 turn window

**Signed:** **mean** boss length in **[5.5, 10.5]** for every act × aspect ×
gated vow (twelve cells). Share-in-window is reported, not gated.

p7's [6, 10] fails three p8 means: Vow 0 Ash act 1 **5.914**, act 2 **5.949**,
Vow 5 Dusk act 3 **10.157**. All twelve sit in [5.5, 10.5]. Share ≥ 60% in 6–10
would currently pass all twelve (lowest 60.0%). If James wants the original
[6, 10] mean gate kept as design intent, it fails those three cells today.

#### 4. Ablation concentration

**Signed:** on a matched ≥80-run Vow 0 sample, no single **non-boss** card or
relic whose removal shifts a per-aspect win rate by more than **12 pp**; no
**boss relic** more than **15 pp**. Point-estimate gate (amendment 3).

n = 200 per aspect. hollowCrown −7.50 pp Dusk is the peak and sits under 15 pp.
Largest non-boss negative is emberLantern −2.00 pp Dusk, under 12 pp. The p7
hollowCrown −17.00 / catalyst −11.00 failures do not reproduce under p8.

### Amendments — attached verbatim, not weakened

These are the four amendments the adversarial review earned, copied from
https://github.com/fol2/glassvow/issues/203 (comment "Before you sign"). They
constrain what a signature on the p8 bands can claim. Full adjudication remains
on https://github.com/fol2/glassvow/pull/208#issuecomment-5281077468.

1. **State that the four bands do not discharge the unwaivable trio.** A heuristic pilot only explores strategies it was programmed to try, so no win-rate band evidences "no strategy trivializes a gated vow". That leg needs #205 plus something these bands do not contain. This is the finding that most constrains what the baseline can claim.
2. **Tighten or drop band 2's second clause.** "The paired 95% interval must not lie entirely outside [−15, +15] pp" is satisfied by an interval of [+14.9, +40].
3. **Sign band 4 explicitly as a point-estimate gate, or raise the ablation sample.** At n = 80, `hollowCrown`'s −10.62 pp has a paired interval of [−17.01, −4.24] — the point estimate passes the 15 pp line but the interval reaches past it. A ±5 pp half-width needs roughly 131 seeds per aspect.
4. **Note that the bands were fitted post-hoc** to ~34 uncorrected intervals from one sample; future validation should treat them as one joint hypothesis.

On (2): resolved at sign-off by dropping the second clause — candidate (a),
point-only ≤ 20 pp. The candidate table above records the measured
alternatives that were on the table.
On (3): band 4 is signed as a **point-estimate** gate; the sample is n = 200
(already above 131), and every interval/half-width is in the table.
On (4): these four bands were fitted post-hoc to the p8 sample. Treat them as
one joint hypothesis on a future holdout (seeds 5000+).

RNG: `_incoming` still clones `run.rng_state()`; `domain/rng/rng.gd` was not
touched. Ablation bans still live in `choose_card` / `choose_relic` /
`choose_shop` (next-best, not forfeit).

### Sign-off record — 2026-08-16

Signed by James (wayfinder session on
[#203](https://github.com/fol2/glassvow/issues/203)), all four bands against
`p8-d0-v1`:

- The signature certifies the **instrument's envelope** — a pilot-adequacy
  checkpoint. Per amendment 1 it is no evidence for #160's unwaivable trio,
  which rests on the strategy-landscape line (#213's decision) and the human
  feel pass (#205).
- Band 2's second clause **dropped** (candidate (a): point-only ≤ 20 pp).
  Band 3's mean gate is **[5.5, 10.5]**, a deliberate widening of the p7
  [6, 10] intent — boss length is pilot-strength-sensitive, and half a turn
  sits inside instrument noise; share-in-window stays reported, not gated.
  Band 4 signed as a point-estimate gate at n = 200.
- Step 2 (real-device direction runs) **folded into #205's protocol** rather
  than gating this signature: the pilot is confirmed non-saturating, so a
  human ~100% Vow 0 result would not move these bands — it would only feed
  #205's "is Vow 0 challenging for a human" question, which was already
  #205's to answer.
- Post-hoc caveat (amendment 4) stays binding: future validation treats the
  four bands as **one joint hypothesis** on a holdout (seeds 5000+).
- #204 tunes against these bands as the ruler.
