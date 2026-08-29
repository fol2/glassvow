# Post-843e899 cross-turn hold primary-source audit (v1)

Date: 2026-08-29  
Issue: `#421`  
Exact source: `c4130163c7fb8edd865c0adc95732aae03e1bad2`  
Task capsule: `task-capsule-5460811702-v20.json`, SHA-256
`673d0ee27b3337fe69b21a6964097cf49ee2e173ed4f8dd56fd4ba6fbba31385`  
Controlling authority: owner comment `5460811702`, body SHA-256
`58d71b9af60d811f40b489da19499b3dd113fd77fcb06bdf12fa6692fb5686f6`

## Decision boundary

The positive-overkill natural-capacity look validly closed the complete ordered
terminal-hit precision/excess class. The next owner-ordered class is cross-turn
hold lifecycle. This audit reads exact source and immutable decisions only. It
does not inspect a cached support row, run Godot, append the ledger or infer a
candidate from frequency.

Exactly one smallest complete contract is source-compatible under the owner
objective: retain one existing authored Attack left in the Duskblade hand at
end of turn, count it against the next normal draw, and grant one Ember only
when that exact card instance is played on that next turn. Its research identity
is `dusk-one-turn-held-attack-play-ember-one`.

This is not a product or support decision. It selects one finite representation
for the source/interface/null and direct A/B/AB preflight. A failed mechanical
preflight closes this representation without repair. A passed preflight can
authorise only the cheapest separately preregistered natural-capacity screen.

## Exact source facts

- `domain/state/combat_state.gd:7-34` owns all fight-local zones and counters.
  None is saved in `RunState`; one research-only hold record can therefore be
  fight-local without changing a save or internal content identity.
- `domain/rules/combat.gd:335-372` emits the exact next `TURN`, resets Energy and
  draws the normal hand. Subtracting one draw only while the exact one-turn hold
  record and card are both present makes the retained card replace, rather than
  supplement, one normal draw.
- `domain/rules/combat.gd:764-849` resolves a legal `PLAY` by exact card `uid` and
  emits that `uid`, authored `id` and target before effects. This is the strongest
  direct consumer identity available without a new selector or inferred label.
- `domain/rules/combat.gd:1014-1040` emits `END_TURN`, applies hand penalties,
  then moves the complete hand to discard with exact UIDs. The producer can be
  inserted at this single existing lifecycle boundary and leave every unselected
  card on the current discard path.
- `domain/rules/combat.gd:1154-1187` can Kindle an exact hand UID before end turn.
  Kindle remains an interference/expiry route; it is not a producer, consumer or
  alternative payoff.
- `tools/balance_pilot.gd:88-152` exhausts its existing legal card choices, may
  Kindle one remaining card, then ends the turn. The first capacity screen must
  use that frozen policy. No hold control is authorised by this design.
- `domain/events/event_types.gd:6-34` already exposes `TURN`, `DRAW`, `PLAY`,
  `EMBER`, `DISCARD_HAND`, `END_TURN`, `KINDLE`, `VICTORY` and `DEFEAT`. New
  telemetry need label only the research chain and its exact expiry reason.

## Immutable alias boundary

- Immediate exact-UID draw thread is closed. The selected producer is not a
  `DRAW` effect and the consumer is not its immediate next `PLAY`: the card was
  deliberately left in the prior turn's hand, survives an enemy phase, counts
  against the following draw and is consumed only by the same UID on that next
  turn.
- First reshuffle to immediate next `PLAY` is closed. The hold makes no shuffle
  or RNG call and does not use `RESHUFFLE` as a producer or consumer.
- Afterimage and the one-bit setup/action grammar are closed. No named pair,
  Ward setup, Attack/Skill cadence or second card creates the mediator.
- Turn-state action economy is closed. Energy, unused Energy, first-card state,
  Art use and Kindle count are contexts only; none creates or pays the hold.
- Duplicate-copy, Momentum, Kindle/exhaust, target transfer, kill topology,
  terminal-hit, Facet/Shatter relay, Scoreline and Afterimage remain unchanged
  controls. Same card ID is insufficient; only the exact retained UID consumes.

## Finite legal grammar

The source permits only these pre-support choices without inventing an arbitrary
named pair or persistent system:

1. eligibility: one authored Attack versus any card, Skill or named card;
2. cardinality: first eligible card in existing hand order versus all cards;
3. persistence: exactly one enemy phase versus multiple turns;
4. hand economy: replace one next-turn draw versus grant an extra hand card;
5. consumer: exact retained UID on the immediately following turn versus turn
   start, any card or a later turn;
6. bounded payoff: one Ember versus one Facet, Energy, Ward or targeted damage.

`dusk-one-turn-held-attack-play-ember-one` is lexicographically smallest. It
uses the exact end-turn hand and same-UID play surfaces, has one visible hold
rule and the shortest genuine cross-turn lifecycle, adds one ephemeral record
and no policy control, and needs no target, status, draw, reshuffle or global
selector. One Ember uses the existing capped Dusk resource law and direct event.
Facet needs an additional successful-hit/target settlement surface; Energy is a
closed action-economy payoff; Ward and damage need timing or target semantics.

The alternatives fail or lose before support:

- retaining without replacing a draw gives a free additional hand card and
  fails the natural-cost gate;
- retaining every eligible card is not bounded and adds variable state;
- any-card or Skill holds are not Dusk-mechanistic and overlap the closed action
  grammar;
- named-card holds select semantics by catalogue identity rather than source;
- discard/top-deck return overlays the closed draw/reshuffle surface and changes
  more zones;
- multi-turn persistence adds lifecycle and state with no earlier contract
  deficit;
- a player/policy selector violates existing-policy-first and the no-selector
  boundary; it cannot be added unless later direct evidence proves that sole
  missing decision dimension under the owner rule.

## Complete twelve-field contract

1. **Producer:** after hand penalties at `END_TURN`, if Dusk aspect zero and no
   live hold exists, scan the current hand once in existing order and select the
   first authored `type=attack` card. Status, curse, Skill and Power cards are
   exact non-producers. Multiple eligible cards still create one producer.
2. **Mediator state:** retain that exact `uid` in `cb.hand` while every other
   hand card follows the existing discard path. Store only one ephemeral
   fight-local record `{uid, cardId, createdTurn}` in `CombatState` and emit one
   mediator-set event. Do not change `CardInst`, content, `RunState` or save data.
3. **Consumer:** a successful legal `PLAY` of the same UID at
   `turn == createdTurn + 1`, after the normal `PLAY` and Energy events and before
   authored effects. Same ID/different UID, any other card and any later turn do
   not consume.
4. **Payoff operation:** on the sole consumer request exactly one
   `gain_embers(run, cb, 1)`. Record requested one and realised capped/tithed
   delta separately. The payoff never scales by card cost, damage, targets,
   Facets, turns held or number of eligible cards.
5. **Lifecycle:** the card crosses exactly one enemy phase. At the following
   turn start it reduces the normal draw count by one. Consume on the exact play;
   otherwise expire on Kindle/removal, next `END_TURN`, combat victory/defeat,
   missing card, stale turn or disabled consumer. An expired UID cannot be
   immediately selected again at the same end-turn boundary.
6. **Natural cost:** the player forgoes the card's prior-turn play or Kindle,
   receives one fewer normal draw next turn, then must pay and legally play the
   exact retained Attack before expiry. No card, Energy, draw or Ember is free.
7. **Dusk boundary:** only current aspect zero is eligible. Factor-on Ashwarden
   is exact current-main: no retained card, record, draw change, event, Ember,
   RNG movement or result change.
8. **Scoreline factor:** separate closed factor, fixed off. No Oath, Faultline,
   Cracked requirement, assignment or Scoreline payoff enters the hold.
9. **Afterimage factor:** separate closed factor, fixed off. No Ward setup,
   Warden's Edge, order intervention or Afterimage payoff enters the hold.
10. **Interference rule:** preserve existing hand penalties, selected-card
    identity, unselected discard order, start-turn effects, hand cap, Kindle,
    authored card effects, Ember cap/tithe, Art, Momentum bonus, Facet/Shatter,
    death, relics and RNG. Exact-UID hold telemetry must separate each stage.
11. **Null path:** omitted or explicit off reproduces current-main exactly.
    B-only consumer with no producer, no eligible Attack, same-ID/different-UID,
    stale turn, Ash and malformed/missing mediator are exact nulls and fail
    closed. No global/static residue may cross a combat or probe case.
12. **Policy exposure:** use frozen existing policy identities first with no new
    acquisition, reward, hold, scoring or target control. At most one bounded
    research-only hold decision control becomes eligible only if direct evidence
    proves it is the sole repertoire bottleneck; this contract does not authorise
    it. Direct telemetry records producer, mediator-set, carry/draw replacement,
    consumer, mediator-consume, payoff requested/realised and every expiry by
    exact UID, card ID and turn.

## Next lawful gate

Freeze a deterministic zero-row design protocol that canonically enumerates the
finite choices above and selects at most this one contract. If it passes, freeze
one direct source/interface/null and A/B/AB protocol with numeric row, process,
wall-time and context ceilings. No whole-run row, support metric, policy control,
protected seed, ML, RL or optimiser is authorised before those gates pass.
