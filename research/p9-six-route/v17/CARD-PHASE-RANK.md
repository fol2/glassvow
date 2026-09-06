# Source-bounded finite card-phase argument

Research evidence, not global game termination or P9 certification. Content is shortcut control SHA256 35a0e20202b6a6031773d6252eddd3daa0709bd04e9aa47bea8f8c77e880d922, native combat source from the v17 assembled project, official Godot4.7.2. A source/content change invalidates this argument until its assumptions are rechecked.

## Rank

For a nonterminal state within one player turn define the lexicographic natural-number tuple:

`(L, C, F, 10*(E + H + G) + h)`

L = living enemy count. C = cards in hand/draw/discard (not exhausted or consumed powers). F = one if no card has yet been played this turn, otherwise zero. E = energy, H = player HP, G = sum of living enemy HP, h = hand size.

For the inspected catalogue and source, a legal card either terminates combat or strictly decreases this tuple:

1. An enemy death decreases L. This covers overkill healing, death-triggered energy/draw and other death effects without assuming that displayed damage equals actual health loss.
2. Otherwise Exhaust, consumed powers and hand exhaustion decrease C. The inspected card catalogue has no card-creation effect; no enemy is spawned during such a card transition.
3. Otherwise the first card consumes F. All inspected cost discounts that can make an otherwise paid card free are limited to that first-card flag.
4. Otherwise a positive-cost reusable card spends at least one net weighted resource unit. The hand cap is ten, so the hand can increase by at most nine in a single completed card action. Leech health recovery, including Sun Blossom, is bounded by health removed from a surviving enemy. Devour heals on death and is handled above. Thus the final coordinate falls by at least one.
5. The only reusable zero-cost resource producer in this catalogue is Blood Rite: it loses three HP for at most three energy, ignoring Ward; consuming the played hand card makes the final coordinate fall by at least one. Unsupported free-draw, net-positive energy, healing or new special/card-creation effects require a new argument, not automatic carry-forward.

The lexicographic order on a finite tuple of nonnegative integers is well-founded. Consequently an infinite legal sequence of card plays is excluded under these assumptions. Art, Kindle and potion uses have finite per-turn supplies in the inspected source; they cannot insert infinitely many interruptions between finite card-play segments. EndTurn begins a different phase and is not covered by this rank.

## Actual checks

The content assumption scan evaluated118 base/upgrade definitions with zero unsupported entries. Adversarial content tests reject the original renewable Preparation upgrade, a net-positive free-energy mutation, card creation and an unknown special.

A native matrix covers118 definitions, two aspects, first-card flag on/off, enemy HP3/200 and four relic combinations. There are3776 constructed states:128 illegal plays skipped,3648 legal native transitions. Native legality plus nonterminal descent checks total7168 assertions. A further negative assertion restores the old zero-cost renewable Preparation in memory and verifies rank non-descent: [2,20,0,4248] -> [2,20,0,4249]. Total7169 assertions, zero failures.

These finite native checks test the implementation of the source argument; they are not exhaustive reachable-state enumeration or an independent formal proof assistant. The argument does not guarantee fewer than100 actions, exclude thirty-turn stalls, establish any win rate, prove acquisition or admit a strategy. Existing action/turn limits remain unchanged.
