# Delay-aware poison reallocation: an affine live-stock consumer

Exploration only, not P9 certification. Existing branches/evidence remain immutable. This prototype is independent of the running Banked Light study and does not combine partially observed winners.

## Mathematical distinction

Let a producer apply P poison and the old consumer multiply the positive current stock by M. Lowering the producer to P' < P and only changing the multiplier cannot preserve both immediate and one-tick-delayed stocks: P'M'=PM and (P'-1)M'=(P-1)M imply M'=M and then P'=P. Immediate-only compensation therefore fails under delayed draw/order even before whole-run randomness is considered.

With a two-unit producer reduction, use F(q)=Mq+2M when q>0, and F(0)=0. Keep the old multiplier2/3 and add bonus4/6 instead of multiplying by4/5. For every base/upgrade pairing and every delay d for which P-2-d>0, M(P-2-d)+2M=M(P-d). Postconsumer stock is preserved; prior ticks still lose2d damage. Expired stock remains zero: preserving an expired producer would require additional state or making the consumer independently create poison, neither is claimed or implemented here.

The isolated total poison potential T(q)=q(q+1)/2 assumes a surviving enemy without reapplication. Base immediate total including unchanged physical4 remains40. At one-tick delay, old total29 becomes27 with the affine law, versus16 with the earlier multiplicative reallocation. High-stock amplification is lower than multiplier4 when q>2; this is not a guarantee against all other producer/consumer interactions or a global win-rate prediction.

## Three explicit recipes

Control SHA25635a0e20202b6a6031773d6252eddd3daa0709bd04e9aa47bea8f8c77e880d922. Earlier multiplicative combined recipe7d0dcea446dd17f98cdcbf2596617b669f4ca59b8b9fb73d672ddc46320f5f25. New affine recipee1cda65c7351578c56381e88197c59da238afa6faf8bfe261e0d8a64b34fcf73: VenomStrike poison2/3, unchanged physical4/6/cost, Catalyst multiplier2/3 plus4/6 only on a target with positive poison. All other content, rarity, pools, deterministic RNG, Exhaust, aspects and resources are unchanged.

Native code reads optional bonus with default0 inside the existing positive-poison guard. Absent bonus preserves the old law. Existing Dusk player-poison prohibition is unchanged. Greedy continuation translates the affine consumer to its actual current status delta; draft adds a bounded bonus-times-existing-producer proxy. This is a disclosed heuristic, not optimality or future-state access. Root native rollout remains two public determinizations/twelve continuation actions, persistent terminal health corrected, optional terminal extension off.

## Actual cheap evidence

48 native controlled arms across3recipes, both producer/consumer upgrade choices and delays0/1/2/3 passed218 assertions. Checks cover actual end-turn ticks, all-tier live-stock preservation, exactly2d prior damage loss, expiration, consumer-alone zero, Dusk null, and exact greedy current-delta translation. All16 existing public-information/rollout assertions passed. These constructed states do not establish natural acquisition, whole-run causal specificity, viability or P9.

## Frozen full-run exploration

Three recipes x Ash three planned route contracts plus balanced RandomBuild x vows0/5 =24cells. Preflight one exposed seed18000010 percell. The16 no-bonus control/old-multiplicative rows must reproduce poison_smoke control/combined parsed rows; this is parity, not fresh scientific evidence. Only after valid preflight,16 new exploratory seeds20010000..20010015 percell=384run-condition evaluations. No protected cohorts, no source edits while running, four native workers only after the preceding batch finishes.

Report all assigned outcomes, paired nominal contrasts, acquisition/enactment and actual HP-removal profiles. No completed comparison is promoted by its label, no signed-C2 replacement and no automatic post-peek sample extension. This finite experiment answers whether preserving delayed stock improves practical selectivity relative to the earlier design; final P9 still needs six admitted packages on one content, detector validation, corrected confirmation, unrestricted retention, signed guardrails, lifecycle and exact reviewed integration.
