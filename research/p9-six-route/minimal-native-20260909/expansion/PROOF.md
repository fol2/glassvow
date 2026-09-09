# Exact native-role decomposition: what is and is not proved

Input is unmodified main `2ed6cdb0302ba3aab5845a18d862841165e8aaf7`.
This is not a third bulk candidate, an extra scalar, a replacement for the frozen
negative screens, or a claim that new labels make new topologies.

## Observable semantics and the rewriting relation

A state includes the complete RunState, CombatState, CardInst aliases, RNG
cursor, event queue and last command return. The observable result is the
complete new state plus emitted events, not HP alone. Card payment, hand removal,
all card/relic hooks, pending-chip settlement, Power consumption and
Exhaust/discard are the *single native play envelope*. They are not erased.

For a live legal Splinterstorm (`flurry`) command, the original `dmg` effect
contains a loop of three iterations. An iteration reads current player Strength,
then performs the native hit operation with current target state. That operation
already owns floors, Weak, Vulnerable, Block, thorns, death, finale handoff,
post-hit and pending-chip effects. Replace the loop by three calls to that same
native effect with `times=1`, checking `cb.over` before every call. Each call has
exactly the original iteration's arguments and side effects. Induction on the
remaining iterations gives identical whole state and emitted event sequence;
it also handles early terminal states and a dead target. The enclosing card
executes once in both programs. Thus no additional payment, played-card count,
chip settlement, discard or RNG operation is introduced. This is NOT three
separately played Attacks and is NOT a one-hit `3*(base+Strength)` replacement.

For a legal Bellows (`catalyst`) command, let q be the current target's poison
value and m its exact authored multiplier (2 or 3). The original special body
performs no operation if q<=0; otherwise it calls native `add_status_enemy`
once with `q*(m-1)`. A normal target-status effect with those same arguments
calls that very method once. Target validity holds at the command boundary;
the replacement delegates the original outside the live-target entry domain.
The multiplication and signed arithmetic are copied, not approximated.
Consequently the body has identical state/event semantics. In particular,
Dusk's poison suppression still happens in `add_status_enemy`, and no
instantaneous HP damage appears. The unchanged outer Skill then Exhausts and
feeds native Ember/Branch hooks in the same order. Poison's later tick/decay,
transfer, death and the next combat reset remain native, not a new simulator.

These arguments cover the exact source-level transformations parametrically;
the 208 source-bound native comparisons corroborate wiring and alias/event
preservation across the declared contexts. The fixed 208 stock references
are taken from the already retained 1040-case raw, never rerun as new evidence.
This is not independent runtime/translation qualification or a proof of
arbitrary future source versions. Mutation or source-hash drift invalidates it.

## Minimal role contracts and actual historical comparisons

Fervor is a player-owned additive inventory read on successive hits and actions.
Smolder is a target-owned inventory amplified by a distinct Skill and paid out
at the native enemy phase. Both are currently expressible without changing
product content, costs, starter kits, Core/Art values or any aspect invariant.
The checked plain factorial payoff is 4/6 additional actual consumer HP for
base/upgraded Fervor and 4/10 additional target stock followed by delayed HP
for base/upgraded Smolder. Those formulas are not global HP identities under
clipping, different target choice, mortality, Block or rounded debuffs.

The exact historical `post-v38-action-grammar-inventory-v1` asks whether an
additional non-stacking bit, set by Power/Energy/draw producers and consumed
by the next Attack for one extra Chip, has enough support. That is not an
experiment removing Empower Strength or its repeated-hit contribution.
However the old full system shares the native combat background. Comparing
only its extra bit with Strength and declaring formal novelty would also be
invalid: the background already contains this native Fervor behaviour.

The corrected `post-v38-hand-size-inventory-v2` inherits the v1 package
`ash-poison-catalyst`: producer `toxicMist`, consumer `catalyst`, observed
`mistboundConsumedByCatalyst`, in a particular structural-null content arm.
Our named producer is `venomStrike`, an Attack with hit-before-poison and one
live target. Shared Catalyst does not make the complete named action equal;
conversely, adding an ordinary hit is not proof of a formally new mechanism.
The old inventory and later Ash admission remain exactly scoped; neither the
old Poison support failure nor Hand/Bloodfire support is relabelled here.

**Disposition:** the two *native role laws* are fully specified and decomposed
as existing operations within their true play envelopes. They are not new
primitives. These facts settle source feasibility and the meaning of component
contrasts, not the complete closed/admitted-family quotient, live policy support,
held-out complementarity, three strategies per aspect, or P9 admission.
No new numerical content candidate is selected by this witness.
