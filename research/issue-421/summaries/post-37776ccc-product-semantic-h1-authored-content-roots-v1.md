# H1 authored-content semantic roots

## Status

`SUPPORTED_ROOTS`

All four authorised inputs matched their frozen SHA-256 values. The projection
declares the same pinned source head and content hash. This was a read-only
audit on 2026-08-30. It used no prohibited input or action.

Selectors below are unique paths within the pinned content JSON. Exact numbers
appear only where inseparable from the source phrase. No values, cards, IDs,
relics or candidates were selected.

## Roots

1. **Attack-driven facet pressure and shatter**
   - Sources: `$.aspects[0].blurb` — “Strikes, shatters, and turns broken
     facets into fuel”; the card text “Deal 4 damage. Chip 1 extra Facet.”
   - Projection: existing — `play_card -> pending_chips -> apply_chips ->
     _shatter_enemy`.
   - Possible roles: producer, mediator, consumer, bounded payoff, lifecycle.
   - Counterevidence: the ordinary attack chip is awarded only after unblocked
     loss; the authored text does not state that condition.

2. **Fracture setup followed by attack payoff**
   - Sources: the card texts “Deal 7 damage. Apply 1 Cracked.” and “Deal 8
     damage. Cracked enemies take 6 more.”; `$.statuses[?(@.name=="Cracked")].desc`.
   - Projection: existing — vulnerable application, attack multiplier and the
     conditional `execute` and `shatterEcho` operators.
   - Possible roles: producer, mediator, consumer, bounded payoff, lifecycle.
   - Counterevidence: the echo payoff also accepts staggered state, so fracture
     is not its sole projected trigger.

3. **Broken-facet conversion into Ember economy**
   - Sources: `$.aspects[0].blurb` — “turns broken facets into fuel”; the card
     texts “Gain 2 Embers. Draw 1 card.” and “Deal 3 damage for every Ember in
     your lantern.”
   - Projection: existing — `_shatter_enemy` grants Embers; `ember`,
     `emberNova` and `emberdance` consume or transform them.
   - Possible roles: producer, mediator, consumer, bounded payoff, natural
     cost, lifecycle.
   - Counterevidence: content expresses resource generation and consumption
     separately; the shatter-to-Ember connection is narrative in content and
     implemented by the projection.

4. **Repeated-use card-local growth**
   - Sources: the card text “Deal 6 damage. Each play, this card gains +4 damage
     this combat.”; `$.statuses[?(@.name=="Crescendo")].desc` — “Attack grows
     stronger with each use.”
   - Projection: existing — `momentum` reads and increments per-instance
     `bonus`.
   - Possible roles: mediator, consumer, bounded payoff, lifecycle.
   - Counterevidence: only one current player-facing text directly states the
     mechanic; the status description is generic.

5. **Hand construction feeding a hand-size payoff**
   - Sources: the card texts “Draw 2 cards. Kindle.” and “Deal 3 damage for each
     card in your hand.”
   - Projection: existing — `draw_cards` and `phantom`, which multiplies by
     current hand size.
   - Possible roles: producer, consumer, bounded payoff, lifecycle.
   - Counterevidence: there is one explicit hand-count consumer and projected
     hand size is capped.

6. **Sacrifice-and-redraw lifecycle**
   - Sources: the card text “Burn every other card in your hand — each feeds
     the lantern. Draw 3 cards. Kindle.”; `$.aspects[0].blurb` — “turns broken
     facets into fuel”.
   - Projection: existing — `pyreTithe` removes held cards, exhausts them and
     redraws.
   - Possible roles: producer, natural cost, lifecycle.
   - Counterevidence: the explicit hand-burning instruction occurs in one
     content entry, so recurrence is semantic rather than a demonstrated
     multi-entry package.

7. **Preserved defence rewarded by remaining untouched**
   - Sources: the card text “Gain 8 Ward. If your glass is untouched this
     combat, gain 8 more.”; `$.statuses[?(@.name=="Annealed")].desc` — “Ward no
     longer expires.”
   - Projection: existing — `flawless` observes `hp_lost`; Ward persistence is
     an existing status operator.
   - Possible roles: consumer, bounded payoff, natural cost, lifecycle.
   - Counterevidence: the untouched-condition payoff appears in one content
     entry; the other source supports defence persistence, not a second
     intactness payoff.

8. **Multi-enemy attack pressure through the facet system**
   - Sources: the card texts “Deal 4 damage to ALL enemies twice.” and “Deal 5
     damage to ALL enemies twice.”
   - Projection: existing — all-enemy damage resolution and per-target pending
     chip recording.
   - Possible roles: producer, mediator, bounded payoff.
   - Counterevidence: neither text mentions facets; relevance derives from the
     projected Dusk-only attack-chip rule, and blocked damage prevents it.

## Accounting and unknowns

The input set comprised four files or endpoints and remained within the 60,000
source-token and 5,000 output-token ceilings. Package viability, reward
reachability, policy sensitivity, detector admission and any C5 candidate or
numeric design choice were deliberately unassessed.
