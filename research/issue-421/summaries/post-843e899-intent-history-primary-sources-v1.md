# Post-843e899 intent-history primary-source audit (v1)

## Boundary

This is a zero-row source audit under issue #421 and owner comment `5460811702`.
It reads current-main source and immutable dispositions only. It does not read a
support trace, cache, outcome, policy result or protected seed, and it does not
make a capacity, causal, balance, product, acceptance or P9 claim.

Archive head `843e899ca053b42b9c8b92486687a43eb1193eb9`, every earlier archive and every
valid closed-family disposition remain immutable. The completed cross-turn direct
observations remain valid for their tested contexts, while the post-result
coverage audit closes that exact representation before capacity.

## Frozen source identity

All source is current main `c4130163c7fb8edd865c0adc95732aae03e1bad2`.

| Surface | SHA-256 | Relevant exact fact |
|---|---|---|
| `domain/state/enemy_combatant.gd` | `f689c34f580b70f798c2337feecf8a666eb69a378b2bd213161ba919e09776b7` | Each enemy already owns `last_moves`, current `move_key` and an unprojected `flags` dictionary. |
| `domain/rules/enemy_ai.gd` | `30a20a1f60b0c53ce7d68405ab5bde551e42820928a2a3d4925c52148e59c417` | `decide` receives exact one-back and two-back move keys. Deterministic authored branches provide direct repeat and return witnesses without changing RNG. |
| `domain/rules/combat.gd` | `3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8` | `_compute_intents` reads `last`/`prev`, calls AI once, stores `move_key` and emits `INTENT`; enemy action or Stagger then appends the telegraphed key before the next computation. |
| `domain/events/event_types.gd` | `445a68f3887baa87b2d666ab4c9d380fba6d9d56fffb1bef13e6016dbc83903a` | Canonical `INTENT`, `PLAY`, `ENERGY`, terminal and card-settlement events already define the comparator and ordering anchors. |
| `tools/balance_pilot.gd` | `4ff5934fc03af84e9d0c8fb285a91c6b7d5dfcab180b88825b1e75bb47ea6c47` | Current policy already plays legal Attacks and selects exact targets. It reads current incoming damage but not `last_moves`; no policy control is required before natural capacity is measured. |
| `tools/balance_policy.gd` | `8eeeb1d3289bbab7fb033e6f175b9d2adcbb2944292c097ad09f79419e162026` | Existing sampled policy identities remain sufficient for a first capacity screen; no research score is present. |
| `content/full-content.json` | `a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1` | The complete authored enemy and Attack catalogue remains unchanged. |

## Exact lifecycle facts

1. At combat start, `last_moves` is empty. The first intent therefore has no
   eligible history comparator.
2. During each enemy phase, both an ordinary action and a Staggered skip append
   the exact current `move_key` to that enemy's `last_moves`.
3. `_compute_intents` then reads one-back and two-back keys, calls `EnemyAi.decide`
   once with the live RNG, stores the new key and emits the canonical `INTENT`.
4. The next player turn exposes the same enemy object, exact index, current key
   and history while ordinary legal card and target selection runs.
5. `play_card` emits canonical `PLAY` and `ENERGY` before authored effects; card
   settlement occurs after effects. A deferred one-Ember payoff can therefore be
   kept outside the consumer card's own Ember-dependent effects.
6. `_on_enemy_death`, `_win_combat`, `lose_combat` and the next
   `_compute_intents` are the complete source-reachable expiry surfaces for a
   marker stored on a living enemy during one telegraph window.

The deterministic direct repeat witness is `ashAcolyte`: after its first
`ritual`, later authored decisions return `scorch`. The deterministic exact
two-back return witness is `gravewarden`: its authored sequence includes
`crush`, `bulwark`, `crush`. These are interface witnesses only; their frequency
or outcome is not read and no enemy subset is selected.

## Immutable alias boundaries

| Closed evidence | Boundary preserved here |
|---|---|
| One-bit producer-to-next-Attack action grammar, `4eeda4d0…` | No player-card producer, named-card sequence or generic next-Attack bit is relabelled. The producer is a new exact relation between one enemy's authored intent history and its current telegraph. |
| Dusk same-turn cadence, `563ea29e…` | No Attack/Skill cadence, length or orientation is varied. |
| Target-switch topology, `309f9266…` | No first-pair switch, target direction, death exclusion or target subset is reused. Target identity only binds the response to the enemy that owns the mediator. |
| Damaging-intent Shatter suppression, `9a56bf08…` | No Stagger, damage-class intent or suppressed action is the trigger. Stagger remains ordinary interference because it still appends history. |
| Current-main `EventTypes` and combat source | Canonical `INTENT` emission is only the ordering anchor. The new primitive is an explicit producer/mediator/consumer/expiry lifecycle, not an event-only payoff. The failed `a26063c3…` audit is not used as authority. |
| Fight-local frontier audit, `2e21b108…` | It left `new-intent-history-lifecycle` unresolved because no complete contract existed. This audit supplies a finite contract without reopening an existing intent or enemy subset. |
| Cross-turn coverage audit, `dbfccbae…` | The new direct matrix must cover every source-reachable expiry caller before capacity. No repair or result from the closed hold source is reused. |

## Finite legal grammar

The family has two source-exact history comparators and two smallest bounded
Dusk payoffs. All four use the same exact-target legal authored Attack consumer,
one telegraph-window duration, existing enemy `flags` as an unprojected mediator
carrier, current policy first, no new state field, no save surface and no RNG.

| ID | History producer | Deferred payoff | Additional direct burden |
|---|---|---|---|
| `I1-repeat-one-back-attack-same-target-ember-one` | New `move_key` exactly equals non-empty one-back key. | Request one Ember after the responding card fully settles if combat continues. | Exact two-string comparator and canonical Ember delta. |
| `I2-repeat-one-back-attack-same-target-facet-one` | Same as I1. | Apply one Facet after card settlement. | May Shatter, alter Facet state and fan out existing Shatter effects. |
| `I3-return-two-back-attack-same-target-ember-one` | New key equals two-back and differs from one-back. | Same as I1. | Three exact history fields rather than two. |
| `I4-return-two-back-attack-same-target-facet-one` | Same as I3. | Same as I2. | Both extra comparator and Facet/Shatter surfaces. |

Exact consecutive repeat has stronger direct attribution than a two-back return
because it needs only current and one-back identities. Within that comparator,
deferred Ember has fewer player-visible and source side effects than Facet. The
owner's lexicographic objective therefore selects I1 without reading support.

## Complete selected contract

1. **Producer:** after canonical `INTENT`, Dusk only, for each living enemy whose
   new exact key equals its non-empty one-back key.
2. **Mediator:** one ephemeral record in that enemy's existing `flags` containing
   `{move, createdTurn}`. It is erased before the next AI call, so AI never sees
   the research key.
3. **Consumer:** the first legal authored Attack targeting that exact enemy on
   `createdTurn`, after canonical `PLAY` and `ENERGY` but before authored effects.
4. **Payoff:** after the entire card and its ordinary settlement, request one
   Ember once if combat still continues; record requested and realised.
5. **Duration:** one current telegraph/player-response window only.
6. **Natural cost:** spend and pay a normal Attack and choose that target before
   the enemy acts; a Skill, Art, Potion, Attack on another enemy or ending the
   turn does not consume the opportunity.
7. **Aspect:** exact Dusk-only; Ash is null.
8. **Scoreline:** fixed off and closed.
9. **Afterimage:** fixed off and closed.
10. **Interference:** current target policy, enemy AI, RNG, Stagger history,
    terminal paths, card effects, card settlement and Ember cap remain live.
11. **Nulls:** absent, omitted, explicit off, B-only, first intent, changed
    intent, two-back-only return, Skill, wrong target, dead target, expired,
    missing or malformed record are fail-closed.
12. **Telemetry:** exact producer, mediator-set, consumer, mediator-consume,
    payoff and expiry stages carry enemy index, move, turn and reason.

Expiry is source-complete: unanswered-window before the next AI decision,
target death, victory, defeat, combat-over-after-consume, stale/missing/malformed
and explicit consumer-disabled A-only. Independent records on multiple enemies
are allowed, but each exact enemy/telegraph window requests at most one Ember.

## Required direct matrix before any capacity row

The direct preflight must include current-main, omitted, explicit off, A, B and
AB controls with identical seeds and source identities. Positive anchors cover
deterministic repeat, multiple enemies and Ember cap. Negative and expiry anchors
cover first intent, changed intent, exact two-back return, Ash, Skill, wrong
target, same move on another enemy, unanswered next AI computation, Staggered
history, target death by another route, victory, defeat, combat-over after a
responding final Attack, stale, missing and malformed records. It must prove the
unknown `flags` key is absent before every `EnemyAi.decide`, and exact RNG and
canonical path identity at omitted/off/B.

No support, capacity, policy control, ML, RL or optimiser is authorised until
that complete source/interface/null and direct A/B/AB gate passes.
