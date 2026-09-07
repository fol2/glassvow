# Interpretation correction: stock-eight anchor is not the native cap

Source review after the v19 batch started confirmed native CombatState.ember_cap defaults to9; crownOfCinders sets12. The predeclared equal-payoff stock8 is therefore an anchor, not the actual full-bank maximum. The recipes, actual code, assigned seeds and sample count are unchanged. This is not a retrospective recipe correction, sample extension or outcome reclassification.

At E9, hard/smooth base Nova damage is40/38 and base Ward17/16. At E12, Nova64/56 and Ward26/22. Upgraded Nova45/43 at9 and72/64 at12; upgraded Ward23/21 at9 and35/27 at12. Smooth arms redistribute value toward startup and reduce upper-stock returns; they do not preserve native maximum output. No global-power-neutrality claim is made.

The original formulas and protocol remain historical records. An external native fixture, without editing the running observer, passed50 assertions covering actual default/Crown cap setup and upper-stock base/up preview, execution and retained bank. Source hashing confirmed OBSERVER_UNCHANGED=true against the running freeze.

Interpret all subsequent results under the exact declared intervention. No policy, product or P9-acceptance change is authorised merely to correct this terminology error. Source path: domain/state/combat_state.gd and crownOfCinders handling in domain/rules/combat.gd at the bound product reference.
