# Inherited Ash package causal/value contract

Task: #421; target remains three viable, reachable, genuinely distinct strategies
per aspect. Main `2ed6cdb0302ba3aab5845a18d862841165e8aaf7`, research input
`5d5375b3f2a36494ec575926b0450f585aad2cf0`. No closed study or product rule is
reopened. Author self-review is not independent evidence.

## Correction that changes the causal design

BloodRite is **lose 3 HP, gain 2 Energy (3 upgraded), then gain one Bloodfire on
Ash**, not a draw/HP exchange. Current-main `full-content.json` lines 910-941,
and minimum `build.py` require those original effects unchanged. Historical
closure prose saying draw/HP is wrong; preserve its numeric results and immutable
raw, correct the current contract instead. Preparation/Surge are the Hand draw
producers. Their distinct Energy and Exhaust/Ember channels must not be combined
with draw or with Bloodfire's incremental status payoff.

## Exact candidate, canonical scope and boundaries

This is the existing minimum Bloodfire candidate, not a third retune or a third
acquisition/planner composition. Candidate content SHA256
`4107c7c0bbed5d9acf8c2bdf97023552426920242ea958c8ebdec793b712afd9`; combat SHA256
`3ccb89f69f50e41d5a46eadd8f48c0a907fd0e382cd492b2c34dd5f93e091ad0`.
Hand uses unchanged Preparation/Surge/Phantom. Bloodfire uses the explicitly
permitted inherited BloodRite/Leech family. No six-globally-new-primitives rule
is added. Inheritance permission does not carry whole-run results across changed
content, controller, policy distribution or runtime. A failed controller-value
conjunction remains failed; it is not reclassified as admitted here.

## Causal variables and estimands (specified before new observations)

For a fixed complete initial native state X and externally fixed command sequence
Q, let Y(e,m,c; X,Q) be the complete native trajectory. `e` retains/suppresses
only the source's Energy effect. `m` retains/suppresses the source's Bloodfire
creation (BloodRite) or explicit draw (Preparation/Surge). `c` retains/suppresses
only the mediator read by Leech or Phantom, never the command payment or generic
attack effects. HP loss, Exhaust, Ember, all relic/death hooks, target/instance
identity, card and dictionary order, shuffle and RNG remain native. Zero Energy
intervention on Preparation is an exact placebo. Generic Hand mechanics are not
made Ash-exclusive: only Bloodfire's added pathway has an other-aspect exact null.

The controlled mediator/consumer interaction, conditional on each Energy arm, is
`I_MC(e) = Y(e,1,1)-Y(e,1,0)-Y(e,0,1)+Y(e,0,0)` for each declared numeric outcome
separately. The outcome vector includes actual capped target HP removed, healing
events and player HP delta; event hit amounts are not substituted for actual HP.
Report the eight trajectories, not merely a positive scalar. Report initial and
post-source mediator differences and initial/current Energy. Compare full all-on
trajectories against a separate instance of the unchanged minimum CombatRules.

If any prescribed action is unavailable in an arm, that payoff contrast is
**undefined for the fixed sequence**, not zero. The unavailable action is itself
an observed eligibility consequence. Never replenish Energy, insert missing
cards, undo deaths, reset enemy Block or branch-selected RNG to force agreement.
A separate adaptive-policy experiment must define the legal fallback policy in
advance; this fixed-command proof cannot supply that estimand.

Source-card utility is not incremental Bloodfire utility. Suppressing only
Bloodfire must retain BloodRite's identical HP/Energy effects. A positive Leech
payoff with no Bloodfire does not disprove the added mechanism, and all of
BloodRite's HP loss cannot be booked as its incremental cost. Similarly, playing
Preparation then dealing Phantom damage is only necessary-pattern evidence:
when no card can be drawn, the entire sequence can be unchanged under draw
suppression. That counterexample must remain visible.

## One missing proof, not a repeated preflight

The new executable proof crosses source Energy, source mediator and consumer
read in all eight arms. Previous preflight/consumer clones did not separately
identify the original Energy channel. Sources {BloodRite, Preparation, Surge},
aspects {Dusk,Ash}, vows {0,5}, upgrades {base,upgraded}, and eight explicit contexts
produce 192 fixtures, eight factorial arms plus an uninstrumented reference:
1,728 two-command records. All are constructed—not natural acquisitions,
independent confirmation or a replay of old panels. The context set is frozen in
PROTOCOL.json, including unavailable Energy, draw exhaustion, hand cap, reshuffle,
Block saturation, lethal target and fatal source. No outcome-dependent extension.

A failure in native-reference equality, scope, full assignment, source-law checks
or nulls means this observation method is not qualified; retain all output.
Positive non-saturated source/mediator/consumer witnesses are required, but they
alone admit no package. Source-bound deterministic checker/mutation tests precede
native observation. No model, controller, product scalar or protected cohort is fit.

## Complete admission obligations and dependency decisions

1. **Canonical identity/inheritance:** bind the exact allowed historical package,
   all current dependencies and limits. Only those allowed inheritance claims
   carry. Existing source identity records support this dependency—not a current
   complete certificate.
2. **Source and complete-chain causality:** this factorial qualifies separation
   of pre-existing source utility, source-produced mediator and consumer response.
   Proper subsets must fail to reproduce the *complete intended effect*, not all
   ordinary damage. Direct mediator removal and lifecycle/repeated-use evidence
   retain the existing qualified minimal-preflight scope; no universal proof is
   claimed from a finite matrix. Adaptive whole-run producer/consumer removal is
   still missing.
3. **Trace descriptor:** an authored label, co-ownership, source/consumer plays,
   or nonzero Phantom damage is not a causal descriptor. Required fields include
   producer uid and effect, produced/drawn identity, intervening expenditure,
   consumer target/uid, actual read value, eligibility, payoff vector and reset.
   Fixed commands and source-null counterexamples qualify meaning only. Assignment
   stability, held-out prediction, intervention stability and peer separation
   remain missing. The earlier six-route frozen validation model is NOT refit.
4. **Competent policy and quality:** bind a specified policy and legal adaptation
   for every intervention, using full gameplay-visible information only. Existing
   one-sample value/cost and joint support are scoped evidence, not admissions.
   Do not require a new policy to be universally best, and do not claim a failed
   acquisition-value contrast is now passed. Viability and the unchanged C2 gap
   still require the exact signed control contract.
5. **Real-economy reachability and separation:** normal starters, actual rewards,
   shops and events, no injections/bans; source/consumer offer is not affordability.
   Preserve existing necessary support32/32/16/8 with its exact scope and show
   viable route-sensitive and peer policies under the correct complete descriptor.
6. **Independent confirmation:** freeze candidate/policy/descriptor, unused seed
   and configuration assignments, all tests/sample sizes, error correction,
   stopping rules and adaptive interventions before any confirmatory outcome.
   Existing four-CRN policy panels are not seed-independent confirmation. No
   new confirmatory cohort is authorized by this local instrument test alone.
7. **Guardrails and deliverable:** all unchanged P9 C1-C4, C2 signed separation,
   V5 ceiling, aspect identity, determinism, zero added faults, duration and content
   validity; then detector admission and unrestricted endpoint retention. Registry/
   lifecycle and exact-product/#108 receipt follow actual admitted interfaces,
   not this task-local contract. All these claims remain incomplete.

## Local execution/preservation boundary

The current connector exposes reads only; direct GitHub network access from the
container fails DNS. Source/data are committed locally; no remote publication or
verified recovery claim is made. Local deterministic observation is authorized by
owner's explicit instruction to continue in the environment and commit/push when
available. Freeze locally before observations, preserve full raw and failures,
produce a self-contained patch/bundle. This is not a new provider or runtime tier.
A later publisher must read back the entire committed packet before admission.
