# Conditional poison reallocation: source-derived design and finite native test

Exploration, not P9. Same research branch and owner, no product merge or administrative quota stop. This tests a specific alternative to broadly weakening Ashfall, whose completed shortcut screen harmed hand/Ember more than Smolder.

## Mechanistic construction

The inspected VenomStrike applies poison4 (upgrade5) and physical4 (upgrade6). Catalyst multiplies current poison by2 (upgrade3). For an isolated surviving enemy without reapplication, total decaying poison is T(p)=p(p+1)/2. Change only VenomStrike poison4/5 to2/3 and Catalyst multiplier2/3 to4/5. Cost, physical damage, targeting, rarity, pool order and Exhaust are preserved.

Standalone base potential falls14 to7 and upgraded21 to12. Same-tier pairs preserve exactly8 poison stacks (base) and15 (both upgraded), hence total potential40 and126 respectively. This is not a claim of identical gameplay: damage timing differs; mixed upgrades differ; other poison producers can benefit from stronger Catalyst; acquisition and survival are uncertain. Test all four factorial arms, not just the combined recipe. Native test executed24 controlled arms with92 assertions and zero failures, checking actual ticks and the preserved same-tier combinations.

Content SHA256: control35a0e20202b6a6031773d6252eddd3daa0709bd04e9aa47bea8f8c77e880d922; producer_only e5f8345beea39dc63215e7d004697d0a00154a94bd98362f5de157f18d23cee8; consumer_only b3f1b49468fa1bde1ef71125259b2e3028166af26901a317082de5788b34157c; combined7d0dcea446dd17f98cdcbf2596617b669f4ca59b8b9fb73d672ddc46320f5f25. Actual files and config hashes are frozen before execution.

## Correctness-only observer repair, separate from the active terminal-extension experiment

A native witness exposed terminal health mismatch: killing a9HP enemy from10HP with Devour produces combatHP10/persistentHP14, whereas Leech produces combatHP14/persistentHP10. CombatRules copies combat health into run state on victory before these subsequent heals. The old terminal evaluator preferred Leech by reading combatHP; the repaired evaluator uses native persistent runHP and chooses Devour. It also correctly values Hearth post-fight healing and clamps. No product healing law is changed.

The isolated corrected project passed16 terminal-health assertions and16 public-information assertions. An earlier fixture wrongly assumed native preview recognises Devour as lethal; that failed source/log is preserved, and the recognized Bellstrike/Hearth leaf is tested separately. No preview-completeness claim. Correction policy SHA256 ef294f057d0ab23a13c2af57d9ced9a27c74d622c308550e4be932617c8d7261. Current unfinished terminal-extension off/on study is untouched; this observer is not selected from its partial outcomes. The new study sets leaf_terminal=false for every cell.

## Frozen execution and automatic branch

Ash only; three planned route contracts plus balanced RandomBuild screen, vows0/5, four recipes=32cells. Smoke one seed18000010 percell. Only after valid smoke, sixteen seeds18010000..18010015 percell=512 exploratory rows. Two public determinizations/twelve continuation actions, exact same observer for all recipes, four workers after the earlier batch finishes. Retain all assigned losses/stalls/errors, exact identities and native diagnostics. No protected cohorts. Same numeric seed is a paired index, not identical downstream RNG. No Dusk exact-null or signed C2 claim.

Prespecified diagnostic selection: for each recipe/vow compute top planned rate, balanced random rate, midpoint floor=(top+random)/2. Proxy margins are0.5-random,top-random-0.35,each named planned rate-floor, and0.9-top atV5. Recipe score is the minimum margin across vows. Rank score descending, mean planned descending, then name. A non-control earns a fresh comparative follow-up only if its score is at least-0.10 and strictly above control; choose the first eligible ranked recipe. Otherwise no optional follow-up.

If triggered, run control plus the selected recipe on64 new seeds18020000..18020063, same eight cells perrecipe=1024 rows. These diagnostics are selection rules, NOT rewritten P9 thresholds or corrected final confirmation. Report all initial arms and the entire follow-up; no further extension of this cohort after peeking. A winner still needs route-matched signed controls, mechanism specificity, uncertainty-controlled confirmation, detector validation, unrestricted retention, lifecycle and exact reviewed integration.
