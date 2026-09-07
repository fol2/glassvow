# Capped low-bank consumer: startup versus peak, not a blanket buff

Exploration only. The complete512-row fuel screen did not establish a positive whole-run producer-demand win interaction. Higher production increased actual Nova use; demand3 reduced it. No P9 candidate was selected.

## New consumer, same engine implementation

Keep both tested production levels and all other content, pools, costs, states and policy code. Change only the consumer recipe to n0,reserve2,floor_per8(base)/9(up),consumeEmbers2. Thus native pre-debit stock q gives8*min(q,2), upgrade9*min(q,2), and pays min(q,2) before the hit. The existing optional fields already implement this law; there is no new runtime effect, resource or source of RNG.

Base raw damage at q0/1/2/4/8/9/12 is0/8/16/16/16/16/16, versus0/2/4/8/32/38/56 under the preceding demand3 stock law. This improves startup and reduces the high-bank ceiling. For stock-dependent damage, total raw payoff is at most8(base)/9(up) times actual fuel spent; actual future gains include all native sources. Ordinary Fervor/status/omen effects are not falsely included in this bound.

Two new content hashes: production1_capped ca7ceca7b8de004be549e8dc1ce8311e34e0faef4577afe35d864c271dc4f1ce; production2_capped fecf879236b36d781ba350f4e9002fd953bf8f4013d4ebeda996e400e9fe350d. Costs/pools and every other card are unchanged relative to the matching production*_demand3 arm. No always-take instruction or forced acquisition is added.

## Cheap native gate and reuse

728 native assertions passed across both aspects,base/up and stocks0..12: independently specified8/9-times-spent raw damage,preview,actual debit,energy and stats. Tests execute outside the frozen gameplay project; engine and observer source hashes match the completed fuel experiment.

To avoid paying for the same deterministic controls twice, reuse the completed production1/2_demand3 controls from fuel_screen, seeds25010000..25010015, with frozen receipt/output/source hashes. Reuse is explicit: these are256 previously observed control rows, NOT new independent confirmation. The new design is informed by those outcomes, so all subsequent comparisons are adaptive exploration and receive no confirmatory significance claim.

Preflight16 new conditions x one exposed seed25000100. Then two new recipes x vows0/5 x three planned Ash controllers plus balancedRandomBuild x16 same exposed indices25010000..25010015=256 NEW run-condition evaluations. The shared cohort supports a cheap paired diagnostic; it does not create new independent seeds. Four workers,unchanged2 determinizations/12 continuations,per-cell watchdog1200s. Source/recipe/assignment fixed before new rows; invalid capture stops further dispatch.

Report every old/new arm,win flips,actual Nova use,health-source fractions,acquisition,and adverse outcomes. Better raw Nova damage or higher overall quality does not prove causal distinctness. A useful result may justify separately frozen fresh confirmation or intervention,not a P9 PASS. Full Dusk impact,all-six-package validity,detector,unrestricted retention,guardrails,lifecycle and exact reviewed integration remain open.
