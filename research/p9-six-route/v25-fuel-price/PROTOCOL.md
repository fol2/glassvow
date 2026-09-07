# Fuel as the price: a capped, zero-energy consumer

EXPLORATION_NOT_P9. Same task and research branch. This independently specified question follows the completed historical capped-consumer negative, not any partial PMF or echo result. No main change, protected cohort, new ticket or acceptance relaxation.

## Question and four fixed content recipes

The prior capped Nova spends up to2 Embers for8/9 raw damage per unit, but also costs1 energy. Compare energy0 versus1 at each existing Pyreheart production level1/2 (up2/3). No increase in raw damage, no change in fuel price, pools,rarities,IDs,other cards,enemy rules,HP,starting energy or any runtime implementation. The cost-zero card still leaves hand for discard and does not draw or generate fuel. This is a real price reduction,not claimed power neutrality.

Hashes:production1_energy0 b211afa8dcf1d58af38419f930099d8166596ff105d1129576aae7e573fc7a16; production1_energy1 ca7ceca7b8de004be549e8dc1ce8311e34e0faef4577afe35d864c271dc4f1ce; production2_energy0 48a03cc213f8505c4133bf5c179eeaa8975d1bfb1655c4c864fd6c9312508246; production2_energy1 fecf879236b36d781ba350f4e9002fd953bf8f4013d4ebeda996e400e9fe350d. Paid controls exactly match the published capped recipe bytes,but no unavailable old raw cohort is reused or relabelled.

Stock-dependent raw damage remains8/9 times actual fuel spent. Fervor,status modifiers,venomous,other relic payoffs and Dusk Shatter refill are separate native contributions,not falsely covered by that bound. No-fuel Nova can still interact with separately earned Fervor. As a reusable zero-energy card with no draw/energy/HP generation,the new card reduces hand count on a surviving-enemy transition; death is handled by living-enemy count in the existing source-bounded card-phase rank. This does not prove a100-action limit,exclude all future card combinations or guarantee full-run reliability.

## Actually executed native checks

1700 assertions pass across both aspects,base/up,stocks0..12 and four recipes: same damage and real debit,declared energy price,preview equality,discard not free draw,no HP creation,local rank descent including zero stock. Exact finite native action enumeration on hand[Nova,Strike,Strike,Strike],3energy,no relic/status exceptions and a high-HP target: with0fuel best health removal18 under either price; with2fuel best28 at energy1 and34 at energy0. Both production catalogues give the same fixed-state result. The six-unit difference is actual opportunity cost,not a whole-run victory claim. Root planner returns a legal action without mutating state. Existing16 public-information checks pass.

## Execution

Reference native planner/greedy policy is unchanged,not the new PMF arm or echo adapter. Two public determinizations/twelve continuations,terminal extensionoff,original route priors. All normal acquisition remains optional; no forced producer or perfect deck.

Preflight64conditions at35000100. Only after complete valid preflight:4recipes x2aspects x2vows x(3named planned+balancedRandomBuild) x32fresh seeds35010000..35010031=2048evaluations. Four workers after preceding batches,900-second per-cell watchdog. Inputs frozen before rows,no source edits inside active project,retain every loss/stall/error,halt dispatch on invalid capture. No protected seeds or post-peek enlargement.

Report every factor/route/context,paired nominal seed-cluster effects,resource use,acquisition and cross-route movement. A broadly useful zero-energy attack may benefit RandomBuild or unrelated routes; that is measured,not presumed absent. Balanced controls do not substitute for signed arm2. Candidate promotion still requires selective causal packages,natural reachability,corrected confirmation,unrestricted retention,detector/guardrails,lifecycle,independent review and exact integration.
