# Tier 1 grammar — Slice A — 2026-08-13

Issue: [fol2/glassvow#215](https://github.com/fol2/glassvow/issues/215).
Pilot `p7-d2-v1` on profile `mature-three-act-no-side-state-v1`. Content SHA-256
`633408231840d4ba47e0680d1969982cdf1ded1a61213a51bfd2bdab00f35155` (unchanged).
Godot `4.7.1-stable (official)`. Defaults preserve the merged p7-d2-v1 instrument;
the four #203 bands in `docs/balance/2026-08-13-diagnosis-baseline.md` are not
re-fitted here.

Slice A opens the two missing actions — decline a card reward, and remove below
the old `copies >= 3 and wscore <= 6.5` gate — as sampled knobs whose defaults
reproduce today's pilot exactly. Slice B (not this artifact) puts a sampled
vector through the same dict.

## Flags go after `--`

`tools/balance_sim.gd:8` (`in _initialize`) reads `OS.get_cmdline_user_args()`,
so every sim flag must come **after a bare `--`**:

```
godot --headless -s res://tools/balance_sim.gd -- --vow=0 --runs=200 --seed0=4000 --out=...
```

Without the separator Godot swallows the flags, the sim silently runs its
defaults (seeds **1000–1199**, `--aspect=all --vow=0 --runs=200`), and it prints
a complete, valid-looking report for a different question. That cost the hub a
wasted verification run. The JSON `manifest.seeds` is the check: a 4000–4199
request that records `first: 1000` was not the run you asked for.

## What T1a changed

T1a is decline. `_claim_rewards` used to append `Pilot.choose_card`'s pick
unconditionally. It now scores that pick and keeps it only when
`accepts_card_reward` says so:

- Gate: `tools/balance_sim.gd:132-133` (`in _claim_rewards`)
- Predicate: `tools/balance_pilot.gd:52` (`accepts_card_reward`) —
  `score >= card_decline_threshold`
- Default: `CARD_DECLINE_DEFAULT = -1e9` at `tools/balance_pilot.gd:10`
  (`CARD_DECLINE_DEFAULT`). Finite so CLI/JSON round-trip; no catalogue score is
  this low, so the default still takes every offered card.

The declined card is the *best of the offer*, not a second-choice swap. That
matters for the sample range (see `cardDecline=6` below).

## What T1b changed

T1b is removal. The old shop gate was the conjunction
`copies >= 3 and wscore <= 6.5`, and event `pickRemove` was the intercept
`8.5 - wscore`. Those are now one policy with three numbers; `remove_value`
stays the unified intercept.

- Shop eligibility: `tools/balance_pilot.gd:56-57` (`wants_shop_remove`) —
  `copies >= removal_min_copies and wscore <= removal_appetite - REMOVAL_SHOP_MARGIN`
- Shop numerator and event score: `tools/balance_pilot.gd:54-55` (`remove_value`)
  — `removal_appetite - wscore`. Event path:
  `tools/balance_sim.gd:241` (`in _event_op_score`). Shop call:
  `tools/balance_pilot.gd:449-450` (`in choose_shop`).
- Defaults: `removalAppetite = 8.5`, `removalMinCopies = 3`,
  `REMOVAL_SHOP_MARGIN = 2.0` (not sampled). So the default shop gate is still
  `copies >= 3 and wscore <= 6.5`, and default `pickRemove` is still `8.5 - wscore`.

`removalMinCopies` is the third parameter of that same decision, not a second
removal path. Default **3** preserves today's behaviour exactly. Opening it is
what lets a policy cut a singleton — the way a player builds a thin deck.
`copies >= 3` as a hard constant made that impossible.

## Knob table

One dict. `apply_policy` / `policy_snapshot` at
`tools/balance_pilot.gd:28` (`apply_policy`) and
`tools/balance_pilot.gd:34` (`policy_snapshot`). CLI keys in
`tools/balance_sim.gd:464-466` (`_policy`). `simulate(..., policy)` applies the
dict at the start of every run. Slice B records the resolved vector on every
run row (`policy`) as the replay key; the seed-1000 digest moves with that
field. See `docs/balance/2026-08-14-policy-vector.md`.

| name | default | drives | Slice B |
|---|---|---|---|
| `cardDecline` | `-1e9` | T1a: keep a reward iff its `card_score` ≥ this | sample **~10–16**, not 0–6 (see below) |
| `removalAppetite` | `8.5` | T1b intercept: `pickRemove = appetite − wscore`; shop ceiling `wscore <= appetite − 2.0`; shop ratio `(appetite − wscore) / removeCost` | one number, both sides |
| `removalMinCopies` | `3` | T1b shop eligibility: `copies >= this` | sample 1 / 2 / 3 so a thin policy can cut singletons |

`REMOVAL_SHOP_MARGIN = 2.0` is structural, not a sampled knob. Slice B's
`BalancePolicy.default()` is the rest of that dict — `card_score` constants,
`_status_value`, `_special_value`, relic scores, `_combat_score` bonuses, the
route table, rest and potion thresholds, `SHOP_MIN_RATIO`. `apply_policy({...})`
deep-merges onto it. CLI still exposes only the three T1 keys.

## Neutrality proof

Defaults must reproduce the merged p7-d2-v1 instrument. Re-confirmed **after**
`removalMinCopies` landed (default 3):

1. **Seed-1000 digest.** Slice A pin was
   `b38410ee207c477b1f0048dec350d1488a100937750150b2a4fd04d69eae6710`.
   Slice B records `policy` on the run row; the pin is now
   `648562f245b41b131c36945c3c0627b465ec99b0f2e44c4a3aae28008f132aee`
   (`tests/test_balance_sim.gd` (`EXPECTED`)). Library / forgottenShrine scores
   unchanged: `library[0]=28.345 [1]=9.8`, `forgottenShrine[0]=6.0 [1]=5.4`.
2. **Vow 0, seeds 4000–4199 inclusive, 200 runs/aspect, defaults.**
   Duskblade **129 / 200** (64.5%). Ashwarden **149 / 200** (74.5%). Stalls = 0,
   errors = 0. Matches `docs/balance/2026-08-13-diagnosis-baseline.md`.
3. **`removalMinCopies=3` is the default.** Same seeds, same outcomes as the
   default row (deck, wins, and per-run `(aspect, seed, outcome, deck)` all
   equal).

## Spot-check

Vow **0**. Seeds **4000–4199 inclusive** (200 contiguous integers; exact list =
`{4000, 4001, …, 4199}`). 200 runs per aspect per setting. Stalls = 0 and
simulator errors = 0 in every row. Start deck is 10.
`add/fight = (final_deck − 10) / n_fights` — same formula as the #215 diagnosis
comment. Default winner / loser add/fight (pooled) = **1.296 / 1.204**, against
the diagnosis 1.295 / 1.208.

| Setting | Dusk deck | Dusk add/fight | Dusk wins | Ash deck | Ash add/fight | Ash wins | Pooled deck | Pooled wins |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **default** (`cardDecline=-1e9`, `appetite=8.5`, `copies=3`) | 39.05 | 1.269 | 129 | 39.99 | 1.267 | 149 | 39.52 | 278 |
| T1a `cardDecline=6` | 39.05 | 1.269 | 129 | 39.99 | 1.267 | 149 | 39.52 | 278 |
| T1a `cardDecline=10` | 38.37 | 1.248 | 129 | 39.75 | 1.262 | 147 | 39.06 | 276 |
| T1a `cardDecline=16` | 32.66 | 1.020 | 112 | 33.33 | 1.008 | 135 | 32.99 | 247 |
| T1b `removalAppetite=4` | 40.22 | 1.354 | 124 | 41.76 | 1.349 | 145 | 40.99 | 269 |
| T1b `removalAppetite=16` | 38.79 | 1.262 | 128 | 39.94 | 1.262 | 153 | 39.36 | 281 |
| T1b `removalAppetite=28` | 38.63 | 1.243 | 136 | 39.16 | 1.233 | 150 | 38.90 | 286 |
| T1b `removalMinCopies=1` | 38.78 | 1.258 | 129 | 39.74 | 1.259 | 149 | 39.26 | 278 |
| T1b `removalMinCopies=2` | 38.95 | 1.264 | 131 | 39.87 | 1.263 | 149 | 39.41 | 280 |
| T1b `removalMinCopies=3` | 39.05 | 1.269 | 129 | 39.99 | 1.267 | 149 | 39.52 | 278 |

**`cardDecline=6` is a no-op.** Identical to default on every column. T1a
declines the best of a 3-of-1 offer, and that max is nearly always ≥ 6, so the
threshold never fires. `=10` is the first visible move; `=16` is the first
material one (mean deck ~39.5 → ~33.0, add/fight ~1.27 → ~1.02). Slice B should
sample roughly **10–16**, not 0–6. Sampling the no-op band wastes a sweep.

**`removalMinCopies` at default appetite barely thins.** copies=1 vs 3 is
−0.26 mean cards, same 278 wins. The score ceiling still binds unique cards;
opening copies alone does not open the thin column. copies=3 reproduces default
exactly, which is the point of the default.

**But the two removal knobs interact, and the table above cannot see it.** Every
row varies one knob at a time, which is blind by construction to a lever that
only exists when both move. Hub check, same seeds 4000–4199, both aspects,
paired against the default run:

| `removalAppetite` | `removalMinCopies` | mean deck | pooled wins |
|---:|---:|---:|---:|
| 8.5 (default) | 3 (default) | 39.52 | 278 |
| 28 | 3 | 38.90 | 286 |
| 8.5 | 1 | 39.26 | 278 |
| **28** | **1** | **36.80** | **288** |

Paired against default: deck **−2.73 cards**, 95% **[−3.40, −2.05]** — interval
excludes zero. That is roughly four times the sum of the two singles (−0.62 and
−0.26). **The removal leg is not inert; one-factor-at-a-time simply could not
reach it.** Slice B must sample the removal pair jointly, and any later
sensitivity check on these knobs has to vary them together or it will conclude
the same wrong thing.

## Measured, not tuned: the two ways to thin a deck are not the same

**On the T1a axis, more cards won more.** 39.52 mean cards → **278 / 400 wins**
(default, take everything) against 32.99 mean cards → **247 / 400 wins**
(`cardDecline=16`). Refusing offered cards costs this pilot 31 wins.

**On the removal axis it does not.** `removalAppetite=28` with
`removalMinCopies=1` thins to 36.80 mean cards for **288 / 400 wins** — paired
against default that is **+2.50 pp, 95% [−2.64, +7.64]**, an interval that
contains zero. Cutting your worst cards costs nothing measurable; refusing good
ones costs real wins. A competent human would say the same, which is mild
evidence the grammar now reaches something real.

So the earlier reading of this table — "take-everything is optimal inside this
pilot's grammar" — **holds only on the T1a axis and is withdrawn as a general
claim.**

That matters for #215's gate rather than for Slice A. The risk worth carrying
forward is narrower than it first looked: a thin column reached by *declining*
sits well below the top cell, but a thin column reached by *removal* does not,
so the 9-cell grid's thin cells are not obviously doomed below the viability
floor. Whether they clear it is for the sweep to measure. Slice B samples the
grammar; it does not retune the pilot to make thin look good, and it should not
read either result as a statement about the game until the landscape is drawn.
