# P9 v16: broad support versus conditional payoff

Status: bounded exploration, NOT P9 certification. This continues the same owner's research; no local-agent handoff, new ticket, product merge or acceptance relaxation.

## Evidence motivating the design

The completed v15 test retained all 768 assigned native runs. Vow-0 RandomBuild won 21-26/32 under competent native planning. Ash Vow-5 Smolder won 29/32 while hand and Ember won 20/32 and 19/32. Thus tactical competence alone does not establish balanced plurality. Do not promote the current content.

The next question is whether broadly useful support is overwhelming build distinctions, and whether low-standalone/high-combination payoffs can preserve planned routes without paying random building equally. These are grouped design factors, not individual causal effects for each changed scalar.

## Four recipes fixed before screen rows

Reference is the exact v15 content, SHA256 de41f69c9cd28cbd09e16880450957b80675f21b53125cd68a42594e41fbf747.

Support-contraction factor: Night Sight returns from common to rare; Ashen Core starting Smolder goes from 3 to 1; Ashfall Smolder from 4 to 3. Other player HP/energy, enemy HP/facets, vows, map, and Shatter/Stun laws are unchanged. This is not a new route or a global-difficulty calibration label.

Conditional-payoff factor: Momentum becomes 0 initial damage, +14 growth, draw one at its unchanged one-energy cost (upgrade 1/+17/draw one). Flurry becomes zero base damage over five hits (upgrade one over five), preserving ordinary Fervor and once-per-card implicit-chip rules. Phantom and Nova use an eight-damage slope above four held units (upgrade nine). Phantom becomes common; Resonant Lance uncommon. No free repeatable cantrip or new action ceiling is introduced. Existing producer/consumer opportunities remain optional, not forced decks.

The four cells are reference, support contraction only, conditional payoff only, and both. Actual content hashes:

- available_reference: de41f69c9cd28cbd09e16880450957b80675f21b53125cd68a42594e41fbf747
- scarce_reference: 094773fa384f33be1f68d85fc469aede7cde9db67d01ef69d710fb70ac068441
- available_conditional: ff5cc8bf7694306e0730aabedc02e076dcdb5dfd575298571e99295a61872510
- scarce_conditional: 36eaac5102c093f947648033637a63eae612df83676c76152faea03a5e85c1f8

Display text is updated for changed effects where generated; these remain research configurations and have not passed production localization/progression validation. Historical failed content remains unchanged.

## Instrumentation and cheap gates

A read-only event fold separates nominal HIT_ENEMY amounts, actual health removed, poison health removed and enemy healing, and checks event-state conservation against native enemy HP. Thirty nominal overkill damage against seven HP records seven health removed. Poison overkill is also clipped by prior HP. Unknown targets and contradictory hpAfter transitions fail closed. All twelve native/accounting tests passed.

Eighteen native recipe assertions passed: zero standalone Flurry, Fervor multi-hit payoff, once-per-card Dusk chips and zero Ash chips, paid Momentum cantrip and repeated same-instance growth, Phantom/Nova thresholds, retained Embers, and unchanged Fervor behavior at zero base damage. Sixteen one-seed whole-run smoke conditions completed without error/stall. These are qualification of the exploratory implementation, not package admission.

## Fixed screen

Four recipes, two aspects, vows 0/5, three named planned controllers plus one balanced RandomBuild screen: 64 cells, sixteen assigned seeds 14040000..14040015, 1,024 run-condition evaluations. Native controller, public-information sampling and rollout limits remain the tested v15 procedure. The new observer adds only health-accounting telemetry. No edits during execution; all old and new observer identities remain separate.

Retain all losses/stalls/errors and actual acquired decks. Same seed indices do not imply identical downstream RNG after content/build choices. The balanced screen is not the signed acceptance arm and does not replace later route-matched controls. No protected acceptance cohort is opened.

## Interpretation and continuation

Compare factor effects on planned quality, random-build quality, real mechanism use, and actual health-removal profiles. Use the sampled top-minus-control gap and midpoint floor only as diagnostics; three names do not satisfy the old four-cell C1 bar. Report every recipe, not only the best. A numerical pass here cannot establish causal packages, detector validity, optimized ceilings or retention.

A promising recipe may proceed to fresh route-matched verification and mechanism interventions. A failure should identify which intended margin or enacted mechanism failed and guide a separately frozen change, not trigger another owner-quota request or a claim of universal impossibility. Final P9 still needs all package, detector, retention, hard-guardrail, lifecycle, review and exact-integration evidence.
