# Post-843e899 private counter/tag/transform primary-source audit (v1)

## Boundary

This is the final zero-row family audit ordered by issue #421 owner comment
`5460811702`. It reads exact current-main source and immutable dispositions only.
It does not read a trace, cache, support metric, policy outcome or protected seed,
and it makes no capacity, causal, balance, product, acceptance or P9 claim.

Archive head `843e899ca053b42b9c8b92486687a43eb1193eb9`, every earlier archive and every
valid closed-family disposition remain immutable. The three preceding ordered
classes have reached their automatic dispositions: terminal-hit precision and
excess are closed at natural capacity; the exact cross-turn representation is
closed by its post-result source-coverage audit; and intent history is closed at
natural capacity.

## Frozen source identity

All source is current main `c4130163c7fb8edd865c0adc95732aae03e1bad2`.

| Surface | SHA-256 | Exact relevant fact |
|---|---|---|
| `domain/state/combat_state.gd` | `605605900a816908278465a08c58de94cc5c395befead0cba169f28915db35ae` | The aggregate fight-local truth consists of turn/result, zones, Ember, Art/Kindle state, pending chips, played/Attack counters, first-play, HP-loss and terminal hand-off state. |
| `domain/state/player_combatant.gd` | `f30653fcb20b776cd4efb51d22d83a2c6c1006b6bbc32ef4468f627c74fc46d3` | The player's only private combat carrier is the integer `statuses` map beside HP, Ward and Energy. |
| `domain/state/enemy_combatant.gd` | `f689c34f580b70f798c2337feecf8a666eb69a378b2bd213161ba919e09776b7` | An enemy owns statuses, Facet, intent history and a private `flags` dictionary. |
| `domain/state/card_inst.gd` | `e624df08e953accce132e5438a83e7018b6896098cd88504753e400c96a16f4d` | A card instance owns only `uid`, content `id`, upgrade state and the combat-scoped `bonus` transform. `combat_copy` deliberately resets the transform. |
| `domain/rules/combat.gd` | `3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8` | The rules layer owns all current producers, effects, zone moves, settlement, status mutation, targeting, intent and terminal paths. |
| `domain/events/event_types.gd` | `445a68f3887baa87b2d666ab4c9d380fba6d9d56fffb1bef13e6016dbc83903a` | The complete canonical combat-event vocabulary exposes the current ordering anchors; events report truth but do not own gameplay state. |
| `tools/balance_pilot.gd` | `4ff5934fc03af84e9d0c8fb285a91c6b7d5dfcab180b88825b1e75bb47ea6c47` | The existing policy can choose cards and enemy targets. It has no hand-card target, private-tag, transform or new-counter decision grammar. |

## Exhaustive carrier partition

A causal mediator must survive from producer to consumer. Under the owner's
fight-local, no-persistent-run, no-relic, no-acquisition, no-RNG and no-global-
selector constraints, its gameplay ownership has only four possibilities:

1. aggregate combat or player ownership;
2. one enemy's ownership;
3. one card instance's ownership; or
4. a mutation/replacement of one card instance.

A field on `CombatRules`, or a side table keyed by the current fight, is
semantically the first case: moving the same bit outside `CombatState` does not
change its producer, consumer, payoff or lifecycle. A local variable cannot
span producer and consumer. The event queue is presentation output and cannot
own gameplay truth. Persistent `RunState`, relic and acquisition carriers are
explicitly outside this family. Therefore storage location does not supply a
seventh causal representation.

Within card ownership, a player-selected transform and a self/automatic
transform have different policy contracts and are separated below. This gives
the complete six-representation grammar for the authorised class.

## Finite representation audit

| ID | Minimal representation | Exact source route | Blocking scientific fact |
|---|---|---|---|
| `S1-combat-private-counter-existing-event-threshold` | One Dusk-only aggregate integer/bit, incremented by an existing event and consumed at a threshold. | `CombatState` already has play/Attack counters, turn, Energy, Ember, Ward/HP-loss and first-play state. | The complete current-state/zone and one-bit action grammars are closed. Choosing another event, threshold, consumer or payoff has no source/evidence selector and would be arbitrary semantic tuning. No complete producer-consumer-payoff contract exists. |
| `S2-player-private-tag-existing-action-consume` | One private player tag/status set by an action and cleared by a later action. | `PlayerCombatant.statuses` and the shared signed status accumulator are the minimum carrier/hook. | Harmful private status liability is closed at capacity; positive player-marker/Ward and current buff routes are closed. A new producer/consumer card pair would be unsupported named sequencing. |
| `S3-enemy-private-tag-existing-action-consume` | One private enemy flag/status set on a target and cleared by a later response. | `EnemyCombatant.flags` or `statuses` is the minimum carrier; existing policy can target enemies. | Enemy-marker Scoreline, status/Facet/Shatter, target transfer and intent-response topologies are closed. Changing the key or payoff does not create a materially different causal family. |
| `S4-card-instance-private-tag-zone-replay` | One combat-only tag on a `CardInst`, consumed on a later zone or play event. | A new field beside `bonus`, or an equivalent UID side table, would identify the card. | Draw thread, duplicate copy, co-hand, hand/discard/exhaust, Kindle, reshuffle-next-play, exact cross-turn hold and same-instance repeat are closed. The existing policy has no tag-aware decision; changing storage from field to UID map is an alias. |
| `S5-card-instance-private-transform-replay` | Deterministically mutate the same card after an action and consume the transform on a later play. | Reuse `bonus`, change `id`, or generate a replacement instance. | `bonus` is the closed Honing/Momentum same-instance family. Replacement/generation is the closed private generated-card liability and card-zone grammar. A new content ID adds product/internal-ID semantics without choosing a new causal topology. |
| `S6-explicit-card-transform-action-selector` | A new action explicitly selects another hand card to tag or transform. | This needs a new hand-card target contract in rules, presentation and policy, or an automatic target rule. | Current policy selects actions and enemies only. An explicit hand-card target is the prohibited global selector and exceeds existing-policy-first; an automatic target criterion is an unsupported semantic guess. It cannot satisfy the authority gate even though it is representation-distinct. |

No representation has a complete twelve-field contract. For S1-S5, filling the
missing fields necessarily chooses a member of a closed producer/consumer
topology or invents a product-semantic event, threshold, named pair or payoff.
For S6, filling them necessarily introduces the prohibited selector (or hides
that selector in an arbitrary automatic rule). Payoff substitution cannot cure
the producer/consumer alias because the owner's gate requires the complete
mechanism to be materially distinct.

## Immutable alias map

| Evidence | Decision preserved | Representations constrained |
|---|---|---|
| `post-v30-combat-state-zone-frontier-audit-v1` | `close-existing-combat-state-zone-grammar` | S1 and every storage-only relocation. |
| `post-v38-action-grammar-inventory-v1` | `close-one-bit-setup-action-grammar` | S1, S2 and S3 action-to-later-action bits. |
| `post-v30-status-liability-capacity-v1` | `close-status-liability-at-capacity` | S2 harmful private status. |
| `post-v38-scoreline-component-crn-v1` | `close-scoreline-commitment-after-component-crn` | S3 enemy-marker commitment. |
| `post-v38-afterimage-order-capacity-v1` | `close-afterimage-order-at-capacity` | S2 positive player marker/order. |
| `post-v30-private-debt-identity-v2` | `close-private-debt-design-at-identity` | S5 generated/replacement card liability. |
| `post-v38-honing-repeat-capacity-v1` | `close-honing-repeat-without-implementation` | S4/S5 same-instance tag or transform replay. |
| `post-843e899-cross-turn-hold-coverage-audit-v1` | `close-cross-turn-hold-representation-and-advance-to-intent-history` | S4 exact-UID hold/replay rescue. |
| `post-843e899-intent-history-capacity-v1` | `close-intent-history-and-advance-to-private-counter-tag-transform` | S3 intent-trigger relabelling and serial-entry identity. |

These decisions are used as immutable evidence, not reconstructed historical
plans. Valid direct observations remain valid only for their tested contexts;
their automatic family dispositions remain controlling.

## Twelve-field completeness result

The required fields are producer, mediator state, consumer, payoff operation,
lifecycle/expiry, natural cost, Dusk boundary, separate Scoreline factor,
separate Afterimage factor, interference rule, null path and policy exposure.

Every representation can describe a *carrier*, Dusk guard and exact null. None
can source-select all of producer, consumer, bounded payoff, natural cost and
expiry while also remaining materially distinct and existing-policy-first.
Carrier feasibility is therefore not mechanism feasibility. Completing any
candidate by aesthetic preference, implementation convenience, support mining
or an optimiser would be the prohibited guess.

## Method decision value

- Exact enumeration has enumerated the finite representation grammar. There is
  no legal candidate domain to expand into event/threshold/payoff combinations.
- Deterministic QMC cannot choose missing product semantics.
- BO/TPE/SMBO has no frozen legal search space, direct activation objective or
  held-out recommendation test. It would encode the missing semantic choice.
- RL has no surviving measured policy-repertoire bottleneck and would add policy
  and training identities before a mechanism exists.
- Quality diversity has no validated descriptor or causal fitness objective.

No additional method or simulator row has measured decision value at this
boundary.

## Automatic disposition and authority boundary

The final class ends in valid zero-row futility: close exact private
counter/tag/transform grammar without implementation, support inspection,
simulator spend, rescue loop or protected seed.

All four serial classes in comment `5460811702` are now validly exhausted. That
comment therefore permits one new human-authority package. The evidence cannot
scientifically rank the remaining product-semantic alternatives. The smallest
safe authority delta is a new finite family-selection rule that supplies a
mechanistically meaningful producer/consumer direction; the owner agent can
then freeze the remaining twelve-field contract. Alternatively, the owner may
explicitly relax one named immutable closure or one of the save/internal-ID/
selector constraints, or amend #421 acceptance. Until such a delta exists,
preserve #421 as the single task in a safe `needs-info` state. Do not create a
successor, mutate product truth, run Actions, open a research/product PR or
claim #421 acceptance or the #108 P9 receipt.

## Audit accounting

This audit reads seven exact source files and ten immutable decision summaries.
Its executable decision check reads zero observations, zero support metrics and
zero protected seeds, starts zero Godot processes and appends zero ledger rows.
