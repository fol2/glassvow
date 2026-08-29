# Issue 421 post-fanout method decision

Date: 2026-08-29
Source identity: `c4130163c7fb8edd865c0adc95732aae03e1bad2`
Authority: issue #421 body SHA-256 `32b565aa...8e17`; owner comment
`5459094066` SHA-256 `154095ca...adf9`

## Decision

Use deterministic exact enumeration and, only after identity and capacity pass,
a mechanism-blocked common-random-number experiment. Do not add ML, RL,
Bayesian optimisation or quality-diversity search now.

The smallest unresolved information gap is actual combat target identity. The
runtime `PLAY` event already emits `targetIdx`, while the identity-proved
research trace records the same play without that field. A separately
preregistered observation-only identity experiment therefore has measured
decision value for one target-switching question without creating a fitted
objective or a new simulator mechanism.

This selects telemetry only. It does not select, implement or admit a package.

## Primary-source method evidence

- NIST describes blocking as holding nuisance sources fixed while treatments
  vary, and explains that fractional designs trade rows for explicit aliasing.
  It also requires confirmation of a selected best setting. These properties
  favour a small blocked causal design over an unneeded Cartesian product:
  [blocking](https://www.itl.nist.gov/div898/handbook/pri/section3/pri332.htm),
  [full factorials](https://www.itl.nist.gov/div898/handbook/pri/section3/pri333.htm),
  [aliasing](https://www.itl.nist.gov/div898/handbook/pri/section3/pri3343.htm),
  [confirmation](https://www.itl.nist.gov/div898/handbook/pri/section4/pri46.htm).
- Common random numbers compare alternatives on matched random streams, but
  are not automatically variance-reducing. Seed/path identity and paired
  estimation remain hard gates: [Wright and Ramsay 1979](https://doi.org/10.1287/mnsc.25.7.649),
  [Glasserman and Yao 1992](https://doi.org/10.1287/mnsc.38.6.884).
- Bayesian optimisation is intended for expensive black-box optimisation with
  scarce evaluations. Seed-aware CRN modelling is specialised rather than an
  automatic property of generic BO: [Jones, Schonlau and Welch 1998](https://doi.org/10.1023/A:1008306431147),
  [Pearce, Poloczek and Branke](https://arxiv.org/abs/1910.09259).
- Adaptive reuse of observations can overfit the data used to choose later
  hypotheses, which is why a selected result still needs fresh confirmation:
  [Dwork et al. 2015](https://arxiv.org/abs/1506.02629).
- RL learns sequential policies through sampled environment interaction;
  training introduces new stochastic policy identities and implementation
  variance: [Sutton and Barto](https://mitpress.mit.edu/9780262039246/reinforcement-learning/),
  [PPO](https://arxiv.org/abs/1707.06347),
  [Henderson et al.](https://doi.org/10.1609/aaai.v32i1.11694).
- MAP-Elites targets diverse high-performing behaviours in user-selected
  descriptor dimensions, not causal factor estimates; its ordinary archive
  grows exponentially with descriptor dimensionality:
  [MAP-Elites](https://arxiv.org/abs/1504.04909),
  [CVT-MAP-Elites](https://arxiv.org/abs/1610.05729).

## Repository evidence

Observed facts at the frozen source identity:

1. `domain/rules/combat.gd:783` emits one `PLAY` event containing `uid`, `id`
   and `targetIdx` after legality succeeds.
2. `tools/balance_pilot.gd:195-223` chooses the normal-policy enemy target
   deterministically from live combat state: a Dusk Shatter opportunity first,
   otherwise the lowest-HP living enemy. The frozen trace cohort does not use
   `random_play`.
3. The identity-proved co-hand observation source records `fight`, `event`,
   `id` and `uid` for a play but omits the existing `targetIdx` event field.
   Adding that one copied field needs no domain-state, RNG, policy, save,
   content or product change.
4. The frozen fanout capacity audit read all 256 current-main trace rows and
   closed authored `enemy -> allEnemies` target-scope order at four robust
   active and two viable policies. That failure is dominated by all-enemy-card
   reachability and does not observe actual target switching between two
   single-target Attacks.
5. The closed multi-enemy Shatter family uses one card producing multiple
   Shatter events across targets. Actual target switching instead uses two
   policy-selected `PLAY` events and reads no Facet or Shatter event.

Inferences, not yet observations:

- A same-turn single-target Attack on enemy A followed by the next
  single-target Attack on a different living enemy B is a genuinely different
  event unit from fanout and single-card cross-target Shatter.
- Because the target field is currently missing from the trace, its robust
  active/inactive/viable policy capacity cannot be inferred from source or
  authored target scope. Observation can change the next decision and is not
  decorative telemetry.

## Method-value comparison

| Method | Measured value now | Disposition |
|---|---|---|
| Copy existing `targetIdx`, exact identity, then enumerate the one frozen target-switch predicate | Resolves the specific missing variable with a finite Boolean/count decision | Selected |
| Generic ML or Bayesian optimisation | No frozen legal candidate grammar or stable direct-activation objective; prior #421 policy-signal held-out R2 was negative | Not authorised |
| RL | Would create trained policy and training-seed identities before a mechanism has passed identity/capacity | Not authorised |
| MAP-Elites/QD | No validated behavioural descriptor for this candidate and no causal estimate; archive cost would precede identification | Not authorised |

## Smallest falsifiable next experiment

1. Freeze the target-switch mechanism contract, factor levels, exact aliases,
   source/probe identities, cohort, row/wall/context ceilings and decision
   trichotomy before a row.
2. Prove omitted and explicit-null candidate paths exactly reproduce the
   identity-proved trace path, RNG, policy, state and result. The enabled
   observation may add only integer-or-null `targetIdx` copied from the already
   emitted `PLAY` event.
3. Prove direct positive, null, Ash and malformed-interface controls. No payoff
   or product mechanism exists in this stage.
4. Only after identity success, enumerate the sole frozen same-turn
   different-target predicate over the complete matched cohort. Require robust
   active, exact inactive, viable, target/card breadth, same-target controls,
   reliability and separation from Scoreline and Afterimage.
5. Only after capacity success, implement one disabled-by-default direct
   mediator/payoff prototype and use matched CRN arms. Freeze at most one
   feasible candidate for independent held-out confirmation.

Automatic stops:

- Any identity, schema, path, RNG, policy, result or reliability mismatch:
  close the exact observation representation without repair or rerun.
- Any capacity or alias gate failure: close actual target switching without a
  same-target, adjacency, payoff, carrier, policy or cohort rescue.
- Missing output or wall-time cap: record inconclusive; do not replace the
  cohort or infer an unmeasured endpoint.

This route spends no optimisation budget and no causal row before the one
missing observation proves both identity safety and decision value.
