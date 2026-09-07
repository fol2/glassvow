# Same-forecast payoff integration sensitivity

EXPLORATION_NOT_P9. Continues #421 on the existing research branch. Product reference 2ed6cdb0302ba3aab5845a18d862841165e8aaf7; recovered published source 25a9bcbf907a315499f01d8cbaaf648b4628df0c. All 795 exported files matched their Git blob identities. Official Godot 4.7.2 binary SHA256 8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e. Old unavailable raw rows are neither replayed as confirmation nor presumed recovered.

## Question and assumption

The recovered draft chain evaluates resource payoff at a forecast mean. For nonlinear stock payoffs this is not generally the expectation of the payoff. An exact equal-mean counterexample reverses the ranking of threshold and capped raw payoffs. That mathematical fact does not identify the actual future stock distribution or prove a better controller.

Compare unchanged mean-first draft against payoff-first integration on one explicitly assumed bounded marginal PMF: Binomial(capacity, existing_forecast_mean/capacity). This PMF is a sensitivity model, NOT a calibrated model of game occupancy, not a claim of independent resource arrivals, and not the exact transition distribution. Ember capacity is native 9/12; post-Phantom hand stock support is 0..9. Its mean exactly matches the existing deck-conditioned forecast. No live RNG, hidden draw order or future outcome is read, and no random source is added to gameplay.

Only the aggregation rule for Phantom/Nova/Banked Light draft value changes. The mean arm returns the existing draft value exactly. Current known-state action raw payoff, native effects, policy priors and native rollout procedure are unchanged. Draft is also used by upgrades/removal/Kindle decisions, so the whole-run contrast includes those controller responses; it is not falsely labelled a direct acquisition-only effect. Banked Light preserves the legacy plug-in integer-Ward quantisation in the reference. Native root uses two public determinizations and twelve greedy continuations, terminal extension off.

## Fixed content and inexpensive checks

One catalogue only: production2_demand3, SHA256 3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa. There is no new card/scalar/content selection in this comparison. Local recovery passed 16 public-information checks, 4582 stock-law checks and 207 RandomBuild-shop checks. A new 1287-assertion native test passes: PMF normalisation/mean, convex/concave signs, the equal-mean ranking witness, exact disabled-arm draft equivalence for every card and all seven route labels, native adapter arithmetic and no game/content/RNG mutation. These are instrument checks, not P9 admission.

## Frozen paired exploration

Six named routes x vows 0/5 x Planned/route-matched RandomBuild x mean/expectation =48 cells. Smoke: one fresh seed33000100 per cell. After complete valid smoke:32 assigned exploratory seeds33010000..33010031 per cell,1536 evaluations. One earlier engine-throughput row33000000 is not reused for quality. No protected cohort, selective loss exclusion, source edits during batches, or post-peek enlargement. Four workers,900-second per-cell watchdog. Invalid capture halts new dispatch. All raw outcomes and configurations remain. Full raw reconciliation is separate from the driver.

Report all paired cells, mechanism acquisition/enactment, health attribution and cost; uncertainty is clustered by the32 shared assigned seed indices. Seed pairing does not imply equal downstream RNG. This is exploratory, not corrected confirmation, and these route-matched controls do not replace signed legacy arms. A null result is informative and does not authorise claims that the PMF is correct or the method globally useless. A promising result requires calibration/sensitivity checks before promotion.

The six-route content, causal packages, detector, unrestricted optimisation/retention, all hard guardrails, lifecycle and exact reviewed integration remain unestablished. No main modification or #108 receipt. Historical stops remain immutable. Checkpoints persist code and evidence, not just progress prose.
