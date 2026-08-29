# Post-d486 private-state causal-topology correction and primary-source audit

## Boundary

This is a zero-row correction under issue #421 owner comment `5460811702`.
Archive heads `843e899ca053b42b9c8b92486687a43eb1193eb9` and
`d48628913409375437a20a52e290d098cc20062e`, including every valid closed-family
disposition, remain immutable. No simulator observation, cache support metric,
policy outcome, protected seed or product file is used to select this design.

The post-843e899 private-state v1 evidence remains truthful about the six carrier
records it checked. Its family-exhaustion inference is not sufficient: its runner
read gate booleans already frozen in the protocol and did not enumerate causal
producer-to-consumer topologies. A storage partition is not a causal-mechanism
partition. The resulting human-authority claim and `needs-info` transition are
therefore not controlling evidence.

## Exact inputs

All product source is current main
`c4130163c7fb8edd865c0adc95732aae03e1bad2`.

| Surface | SHA-256 | Exact fact used |
|---|---|---|
| `domain/rules/combat.gd` | `3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8` | `gain_embers` computes a clamped next value and returns only the realised delta. A positive requested gain above `ember_cap` is discarded and is not current gameplay state. |
| `domain/state/combat_state.gd` | `605605900a816908278465a08c58de94cc5c395befead0cba169f28915db35ae` | Combat state has the Ember reserve and cap but no overflow residual or equivalent private mark. |
| `content/full-content.json` | `a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1` | The normal reward pool contains exactly three non-starter, single-target Attacks with one ordinary damage effect and no chip, special, status or exhaust: `twinFangs`, `heavyBlow`, `flurry`. |
| `tools/balance_pilot.gd` | `4ff5934fc03af84e9d0c8fb285a91c6b7d5dfcab180b88825b1e75bb47ea6c47` | Existing policy chooses a card and enemy target using the exact previewed loss. It needs no private-card selector to express the proposed consumer. |
| `domain/events/event_types.gd` | `445a68f3887baa87b2d666ab4c9d380fba6d9d56fffb1bef13e6016dbc83903a` | Existing Ember, play and hit events give deterministic producer, consumer and payoff ordering anchors. |

## Correct finite producer domain

The final family authorises the smallest new private counter, tag or transform,
not merely a new storage location. To avoid inventing an arbitrary event, the
producer grammar is limited to exact current-main bounded transitions that lose
an attempted value and do not preserve that residual in gameplay state.

| Residual | Source boundary | Disposition |
|---|---|---|
| Positive enemy overkill | `hit_enemy` HP floor | Closed terminal-hit precision/excess. |
| Positive player overkill | `damage_player` terminal loss | Terminal failure context, not a viable Dusk package. |
| Missed draw at hand/deck bound | `draw_cards` early stop | Closed draw-thread/card-zone family. |
| Overheal above maximum HP | `heal_player` clamp | Generic healing and prior recovery families; not Dusk-only. |
| Enemy overheal | enemy action `mini(max_hp, ...)` | Enemy-intent context; not Dusk-only. |
| Positive Ember overflow | `gain_embers` clamp to `ember_cap` | Unrepresented, deterministic and Dusk-specific; retain exactly one lost Ember as the sole legal producer. |

Energy is not capped, Ward is not capped, Facet-chip overflow carries forward,
and status changes are accumulated rather than discarded. Start-of-combat Ember
clamping is fixed context and would be a free grant, so it is excluded.

This producer is materially different from every preserved Ember decision. The
closed families consume the represented Ember reserve through an Art, damage,
Ward or post-combat heal payoff, or vary existing Ember production. This design
observes a value that current state discards; it does not retune, subset or rescue
any represented-reserve family.

## Correct finite consumer domain

The consumer grammar retains only normal-pool reward cards that:

1. are not in either aspect's starter deck;
2. are a single-target Attack;
3. have exactly one ordinary damage effect;
4. have no chip, special, status or exhaust effect; and
5. are already selectable and targetable by the frozen policy.

Exact current content yields:

| Card | Rarity | Cost | Hit structure | Attribution rank |
|---|---:|---:|---:|---|
| `heavyBlow` | common | 2 | one hit of 12 | 0 — one producer, one consumer and one payoff event |
| `twinFangs` | common | 1 | two hits of 4 | 1 — payoff attribution must choose one hit or split across hits |
| `flurry` | uncommon | 1 | three hits of 2 | 1 — same ambiguity with greater call cardinality |

The owner's first lexicographic criterion is strongest direct observability and
causal attribution. `heavyBlow` is therefore uniquely selected before any
support, frequency, outcome, implementation convenience or SHA tie-break is
available.

## Frozen twelve-field hypothesis

1. **Producer:** while the research factor is on for Duskblade, one positive
   `gain_embers` request whose realised delta is smaller than the request.
2. **Mediator:** one non-stacking player-private `emberOverflow` mark carrying
   exactly one lost Ember, regardless of larger loss.
3. **Consumer:** a later exact `heavyBlow` play in the same player turn.
4. **Payoff:** consume the mark and add exactly 3 damage to Heavy Blow's one
   ordinary hit. Three is the exact current Flare rate, 9 damage divided by 3
   Embers, applied once to one target.
5. **Lifecycle:** current player turn only; expire unused at end turn, loss,
   victory or combat disposal. It never crosses a turn.
6. **Natural cost:** reach the Ember cap, forfeit at least one positive Ember
   gain, acquire/draw/pay for Heavy Blow and order it after the overflow.
7. **Dusk boundary:** Duskblade only. Ashwarden is exact current-main null.
8. **Scoreline factor:** fixed absent/off; its closed enemy-marker package is not
   reopened or pooled with this payoff.
9. **Afterimage factor:** fixed absent/off; its closed Ward-order package is not
   reopened or pooled with this payoff.
10. **Interference rule:** current Ember reserve, Art use, Kindle, Shatter, kills,
    card effects, rarities and costs remain unchanged. Only lost positive overflow
    can set the private mark. No joint cell is authorised at the identity or
    capacity gates.
11. **Null path:** omitted/off, non-positive gain, uncapped gain, absent mark,
    non-Heavy-Blow card and Ashwarden must reproduce current path, RNG, events and
    result exactly after removing research-only trace fields.
12. **Policy exposure:** frozen policy identity, card choice, target choice and
    previewed loss first. No new control is authorised unless direct capacity
    evidence proves one exact timing dimension is the bottleneck.

## Scientific distinction

- It is not Scoreline: no enemy mark, Chisel or Executioner is used.
- It is not Afterimage or Ward: no block producer, carried Ward value or mirrored
  Ward payoff is used.
- It is not the one-bit setup grammar: its producer is a discarded clamp residual,
  not a Power, Energy or draw setup action, and its consumer is exact Heavy Blow,
  not the next Attack.
- It is not existing Ember reserve damage, Ward, Art or healing: represented
  Embers and every authored consumer remain unchanged.
- It is not draw, duplicate, generated-card, reshuffle, same-instance repeat,
  cross-turn hold, intent history, kill relay, target transfer or terminal-hit
  precision/excess.
- It needs no run field, relic, acquisition UI, RNG, save change, internal-ID
  change, global selector or hand-card target.

## Next evidence boundary

The zero-row runner may select this contract only if exact source identities,
immutable closure decisions, the residual enumeration, the three-card consumer
enumeration and the lexicographic result all match. Selection authorises only a
separately preregistered research prototype, exact-null proof and direct causal
controls. It does not authorise a simulator capacity row, package claim, product
mutation, protected seed, ML/RL/optimiser, #421 acceptance or #108 P9 receipt.
