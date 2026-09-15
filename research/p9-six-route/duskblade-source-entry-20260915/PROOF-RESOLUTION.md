# #542 fixed-slate proof resolution: N3 is excluded by the standing closure

Author decision under [prepared batch 5687730761](https://github.com/fol2/glassvow/issues/542#issuecomment-5687730761).
Continuation base: `4b612c3fe19f27016582934960ad3ca656ba5759`.
Scientific source S: `07b5aa9dec8436132a524511d5438c510e322070`.
Archived baseline H: `c4130163c7fb8edd865c0adc95732aae03e1bad2`.
Archive A: `c802be36510273481b6d0f865b92fac43abf6aff`.

**Decision: NO_SOURCE_QUALIFIED_TRIPLE_WITHIN_THIS_SLATE, now substantiated by
N3's source/authority exclusion, rather than by unfinished Q labels.**
This closes the finite nomination question, not issue #542 or the P9 programme.
N1/N2 are not rejected by this argument. No replacement lead is selected.

The decisive distinction is between an excluded search family and an empirically
impossible payoff. N3 uses the already-closed native same-instance-growth/repeat
law, restricted to legally returned, affordable, causally useful occurrences.
Those restrictions add evidence obligations, not a new source law. The standing
no-reopening instruction excludes this nomination. The old capacity experiment
**did not estimate the causal value of native bonus**, and this decision does not
pretend that it did. No native payoff, support or Vow-0 failure is newly measured.

## 1. Exactly which contracts are compared

### C3: the fixed N3 role, not a newly invented card

`4b612c3f:research/p9-six-route/duskblade-source-entry-20260915/SOURCE-ENTRY.md`,
blob `77e7b894eff1e126b3e8185ee43093472727dc0e`, section 2, N3, is the candidate
contract. `NOMINATION.json` at that head, blob
`99b3e52d235ee2dfd26f598c394b59b150ffd8d7`, was its unresolved disposition.
The fixed lead is native Honing play -> bonus on that combat instance -> ordinary
zone return -> later affordable play of the same instance. Honing costs 1 and has
base damage/growth 6/4 or upgraded 8/6, with no on-card draw. Deflect is optional,
not an indispensable component. There is no added repeat factor, policy remap,
new payoff instruction, new required draw carrier or content change.

Its producer is an earlier execution of the native momentum arm. Its consumer
is a later execution of that same arm on the same combat instance. Its intended
payoff is the consequence attributable to the retained prior bonus under full
native resolution, not damage alone treated as proof of causal attribution.
The exact bounded empirical payoff reader remains unqualified; **every allowed
choice of that reader still observes the same unchanged law**. No choice of
reader is needed to establish the exclusion below.

### F: the archived family and E: the experiment on it are not interchangeable

At A, `research/issue-421/protocols/post-v38-momentum-preference-capacity-v1.json`,
blob `90d325492205d83e23e275541218973df75881d8`, defines experiment E:

- Action-role observation: at least two Momentum play events with equal fight
  and CardInst UID; offers/acquisitions and policy-route overlap are also counted.
- Factor levels 0/1 change only the existing Honing policy-score mapping.
- `honingEdgeRepeatPayoff` is fixed at 0 and not implemented. This is a proposed
  **additional** repeat payoff, not a switch deleting baseline `inst.bonus`.
- The finite estimands are capacity, inactivity, reachability and policy-set
  separation in the specified 64-policy/four-seed Dusk V5 cohort. The protocol's
  `estimands.notEstimated` excludes payoff, win-rate and product-balance effects.
- Its `decisionRules.futilityAuthority` closes the remap **and Honing repeat
  family**, without implementing the additional payoff.

At A, `.../summaries/progress-post-directive-momentum-preference-capacity-v1.md`,
blob `74f9c0cb821fb1abf5985128a3a239b5e613a7bb`, records that closure. It reports
14 active versus 16 required, and 7 Honing-only versus 8 required in the remap.
These are retained historical reports, not recalculated evidence in this batch.

At A, `.../summaries/post-v38-native-dusk-grammar-coverage-v1.json`, blob
`bf04dec673867770131642ee7953713984991057`, identifies F as
`same-instance-growth-repeat`, with source members Honing Edge,
`special.momentum`, same CardInst UID repeat and the identity-safe remap.
The index is not used as a transducer or an impossibility theorem. Its
classification agrees with E's actual baseline, observed repeat predicate,
terminal and explicit family closure. **The named native momentum law is part
of this registered family, not an unrelated behaviour found somewhere in its
enclosing game.**

We compare C3 to that native-law member of F, not to a fictional enabled
`honingEdgeRepeatPayoff`, and not to two undifferentiated copies of Glassvow.
E's coarse observed predicate is separately compared in T2. Thus this proof
does not assert that C3's full causal observation equals E's capacity statistic.

## 2. Source identity and the exact abstraction

`PROOF-SOURCE-READBACK.json` records live GitHub Git-object resolution from both
S and H through their content/domain/rules/state trees. Against the retained
`SOURCE-INPUTS.json`, complete file objects match:

| Object | Git blob | Bytes |
|---|---|---:|
| `content/full-content.json` | `1fdf17c5b5acda33159b4cc5badac9d166c3bf8e` | 135282 |
| `domain/rules/combat.gd` | `58c9b8c8f162e77d802fac6c10e5b884b53c8b15` | 49036 |
| `domain/state/card_inst.gd` | `bfb25f0417f3d34e7b5670bfdb97bfea86da2c57` | 740 |

This verifies complete object identity, not merely matching function names or
selected lines. It is GitHub-object verification, **not a local checkout or a
local recomputation of the complete combat/content SHA256**. The complete
retained SOURCE-INPUTS bytes and bundled CardInst bytes are locally rehashed by
the checker. The source object record contains exact GET URLs for reproduction.

Do not infer whole-product equivalence. `quests.gd` and `run_state.gd` differ
between S and H; the old protocol also pins instrumented combat SHA256
`76bb23be...`, distinct from the shipping combat SHA256 `3adb0e06...`.
No old experimental hooks, starting profiles, policies, outcome traces, RNG
assignments or acquisition frequencies are certified equal or reused here.

### State, alphabet, observations and footprint

For the nominated subsystem retain `(f, u, grade, b, zone, target, B)`: combat
identity f; owned-copy identity u; grade; bonus b; hand/draw/discard/exhaust
membership and reference order; chosen target; and common context B. In B retain
energy/effective cost, all other card instances, HP, Block, Strength and all
statuses, enemy flags/facets/chips, counters, pending chips, combat-over/finale
state, RNG, relevant relic/omen/vow/quest state, run stats and event queue.
Acquisition and ordinary progression remain boundary inputs, not free grants.

The controlled alphabet is ordinary native card plays, targets, legal turn/zone
operations, and new-combat construction. Mark one Honing play P and a later
same-instance Honing play C for analysis; those marks add no game transition.
Read-only role masks address the prior growth contribution and later use in
that same law. They do not create an executable new payoff factor or erase
other Strength/Shatter/Honing mechanisms from the comparator.

The observation retains legal/denied decisions, paid effective costs, target and
copy equality, ordered native events, damage/Block/HP separately, growth, zone
movement and reset. Raw identifiers may be renamed bijectively; equality and
order cannot be erased. This is the formal analyst relation, not permission to
feed internal UID or hidden draw order to a factual policy or classifier.
Public visibility remains an additional admission obligation and is not assumed
proved by the internal state representation.

Source edges are explicit:

| Edge | Native correspondence; state that cannot be omitted |
|---|---|
| Resolve/enable/pay | `card_data`, `eff_cost`, `can_play`, `play_card`: correct hand UID, live target, nonterminal combat and sufficient energy; native discounts and payment; remove from hand and update counters/hooks. |
| Produce/use bonus | `_apply_special` momentum: call `hit_enemy(..., n + inst.bonus, true, damage_mult)` **then** `inst.bonus += grow`. No successful-HP prerequisite is added to the growth write. |
| Shared hit continuation | `hit_enemy` and callbacks keep Strength, sequential floors, Block, death/finale, Thorns, stats/events and pending-chip effects. A terminal hit may still be followed by the bonus write. |
| Finish action | `play_card`: pending chips settle after effects if permitted, full coupled Shatter/Stun and collateral, then native lifecycle. A dead/terminal target cannot be invented for a later consumer. |
| Return | Non-exhaust lifecycle retains the same instance in discard. `draw_cards` moves references, uses native shuffle, respects hand cap and empty piles, and puts a real existing instance in hand. End-turn draw and Deflect use this same operator. |
| Reset | `start_combat` uses `combat_copy`; `CardInst.new(uid,id,up)` initializes bonus to zero. UID equality across combats is not retained growth. |
| Acquire | Ordinary content/rewards/progression supply owned instances and context. An optional draw card, a new observation, or a different legitimate profile changes access or evidence, not momentum's source law. |

## 3. Decisive relation and proof

### T1 — register/history representation of the very same native law

Fix one combat copy u. Let `g_1,...,g_k` be the native resolved growth operands
from its previous executions in that combat. Immediately before its next
execution, its native bonus is the left fold of native addition over those
operands starting at zero. This is an operator identity, not an assumption of
unbounded mathematical integer arithmetic.

Base: `combat_copy` initializes zero, matching the empty fold.
Inductive play step: the source first reads the old register for the hit, then
appends exactly the resolved growth by native addition. That equals appending
the operand to the fold. It also holds when the hit ends the fight: source still
performs the growth write, but no later legal consumer follows from that fact.
Zone step: moving or permuting references preserves the register and the history
of that object. A different copy has a different history even with identical
printed card data. Reset creates a new combat copy, so a reused UID begins a new
history. The induction covers the nominated play/ordinary-zone/new-combat
alphabet, not an injected edit to bonus. A different bonus-writing operation
is not silently absorbed into the frame or certified by this fold. Other
context changes are handled as specified in T3.

Thus C3's retained-bonus consumer call has exactly F's native same-instance
consumer argument `n + fold(prior growths)`, with the same target, current B,
mitigation and lifecycle. The growth and consumer maps both address the
**registered Honing role** in F. No new storage, read, write, trigger, guard,
resource conversion or reset law appears in C3. This is stronger than
`two plays occurred`, and does not require proving an equivalence to an
unimplemented additional payoff.

The vulnerable bookkeeping is executable in `check_n3_relation.py`:
`register_view` constructs the incrementally stored-bonus call terms;
`family_view` independently reconstructs them from earlier equal `(fight,uid)`
events. Append equations and interleavings agree; growth-before-hit,
copy-collapsing and fight-erasure mutants disagree. The induction, not the
number of tests, establishes the arbitrary-prefix statement.

### T2 — trace inclusion is one-way, not a causal equivalence assertion

Let L3 contain every legal native trace eligible for C3's proposed complete-chain
claim. By C3's definition each member has a growth-producing Honing play p and a
later consumer c with the same combat copy. Erase only the analyst's P/C marks
and derived measurement fields. Keep every native command, context change,
resource debit, target/copy relation and event. Then p and c still are two
Momentum plays with equal `(fight,uid)`. Consequently

`L3 subset {legal native traces satisfying E.exactRepeatRow}`.

T1 identifies the source law underlying this necessary event relation. T2 alone
would not identify a family: a hypothetical new independent payoff could share
the repeat predicate. That escape is unavailable here because T1 and the fixed
C3 contract identify unchanged native growth as the whole nominated law.

The converse is not used. The repeat predicate alone neither specifies a valid
causal contrast nor guarantees positive HP payoff. In the source-local
arithmetic countermodel, two base Honing hit inputs 6 and 10 are fully absorbed
by one Block stock 100, leaving 84, with zero HP loss. An optional Deflect between
plays may supply the ordinary return; its cost/Block/draw are not deleted. This
is an arithmetic/source-local countermodel, **not a generated legal full-run
witness or proof that every possible bounded payoff is absent**. The checker
labels it only as a refutation of the positive-HP converse. General legality,
causal attribution and population support still require their native evidence.

### T3 — shared-background congruence, without falsely commuting effects

Couple C3 and F's native-law presentation to the **same current** context B and
same native continuation for each corresponding action. Their bonus register
and fold relation give equal hit arguments by T1; every contextual callback is
therefore supplied the same inputs. Carry its entire returned context/event
sequence to both sides. This preserves mitigation, death, Thorns, Shatter/Stun,
quest/finale handling, counters and future enabling. No callback is moved across
a hit or declared to commute with bonus growth. No independent old experimental
callback is substituted for the current one.

Common actions may interact with the mediator's availability: a draw changes
zones/RNG, a turn changes energy/statuses, a kill ends future play. They are
**synchronised edges**, not discarded state. Truly unused frame variables can
be omitted only when not read/written by that edge or its callbacks. Anything
with a possible interaction remains inside B. This open-context argument does
not claim equal old/new acquisition distributions or old profile provenance.

In particular, Deflect need not be proven redundant as a whole paid command:
its Block, cost and timing can matter. The claim is narrower and sufficient:
F's repeat family places no requirement on *which ordinary enabler* returns
Honing. Keeping Deflect's complete native command in both traces adds no law
outside F. Removing its role label does not remove its game effects. Ordinary
turn return is handled similarly. No arbitrary sequence of native
micro-instructions is newly declared an authorised closed-package composition;
only F's expressly named native Honing growth/repeat member is used.

This establishes native-law containment for the fixed C3 nomination under the
retained common background. It does **not** establish equality between C3's
richer observation and E's coarse statistic, all masked outcomes, all policies,
all whole products, or all alternative possible package decompositions.

### T4 — standing authority supplies the exclusion; conjunction supplies no-go

The archived terminal explicitly closes the Honing same-instance repeat family.
The current #542 constraints preserve closed-family dispositions and prohibit
historical-family reopening. Prepared batch 5687730761 specifically requires
exclusion when N3 is contained in that family without an independent source law,
and says an optional Deflect, observer or stricter successful-use label does not
supply the missing distinction. T1-T3 establish exactly those premises.

Therefore the fixed C3 is **excluded under the standing source/authority rule**.
This is not an extrapolation of E's finite policy counts into a universal
impossibility theorem. No statistical bound is transferred to a new profile,
policy or Vow 0. Even perfect future visibility or stronger play would not, by
itself, authorise reopening this same law in the present assignment.

There is no conflict with the planner's earlier instruction to examine this
lead: a lead was not an admission, and the continuation explicitly permits this
exclusion endpoint. `EXACT-CLOSURE-SCOPE.json` blob `a3889fad...` left the modified
growth-plus-on-card-draw candidate's behavioural relation unresolved; that does
not exempt the present unchanged, no-on-card-draw native repeat role. The bound
D547-PC1 supplement supplies prospective acceptance rules, not a repeal of the
standing no-reopening boundary. Its files and binding remain untouched.

The fixed nomination requires eligible N1 **and** N2 **and** N3 on one product at
both vows. One mandatory slot's source exclusion makes that conjunction false,
regardless of the remaining comparisons. This proves the slate no-go without
claiming that N1/N2 are impossible or that no other future authorised slate can
exist. No refilling a slot, new effect, policy remap or new budget follows.

## 4. Decision-relevant completion and skipped work

| Obligation | Final treatment for this slate decision |
|---|---|
| Q3: relationship to closed native growth/repeat | RESOLVED_SOURCE_AUTHORITY_EXCLUSION, T1-T4. |
| Q3: additional independent-consumer/visibility qualification | NOT_REQUIRED_FOR_THIS_SLATE_NO_GO; not certified or claimed impossible. |
| Q1: remaining Facet closed-family/causal comparison | NOT_REQUIRED_FOR_THIS_SLATE_NO_GO; prior source facts retained, not PASS. |
| Q2: remaining Fervor canonical/decomposition comparison | NOT_REQUIRED_FOR_THIS_SLATE_NO_GO; shipping three-hit tuple retained, not PASS. |
| QP: N1/N2, N1/N3 and N2/N3 full peer comparisons | NOT_REQUIRED_FOR_THIS_SLATE_NO_GO; none is reported completed. |
| Native source/transition eligibility, policies, profiles, measurement and confirmation | Not activated; this slate cannot advance. |

This changes the meaning of the former no-triple label from a safe incomplete
state to a proved **author source/authority no-go**. `NOMINATION.json` and the
ordinary capsule carry this operative disposition. SOURCE-ENTRY, the original
69-check packet and CAUSAL-PREFLIGHT remain recoverable prior analytical work;
their unfinished Q labels are superseded for this decision by the table above.

R3 remains COMMAND_CONTRACT_FAIL. The earlier source report's sentence that its
whole-command control "must also be met" is not an instruction to turn that
unchanged failed experiment into PASS. No component arithmetic rescues it here;
N1's dependence on the refuted proposition was not needed for this no-go and is
not asserted resolved. R14's exact stock sampler stays closed. R11/R12 remain
claim-scoped missing-evidence restrictions, not reasons for this exclusion.

## 5. Actual checking, preservation and downstream boundary

Run `python3 check_n3_relation.py > PROOF-CHECKS.json` from this directory.
The checker uses the existing, byte-verified SOURCE-INPUTS and new live Git-object
readback. It checks symbolic call-argument correspondence, the induction's
append bookkeeping, event-pair inclusion, context/optional-action retention and
contrary mutations. It is not another game simulator, native exporter, general
proof framework, authenticity service or package-admission oracle.

The recorded output is actual author execution. Its source-footprint premises
and closure interpretation are the written proof's inspectable arguments, not
claims that Python understands natural-language authority. No natural native
trace is produced. A separate execution receipt records commands/exits and
negative invocations; publication readback binds the resulting files.

All changes stay in the existing source-entry directory and ordinary capsule.
No bound #547 file, kernel, allocation, SESSION-STATE or product file changes.
No new issue, PR, CI invocation, candidate/confirmation freeze, extractor receipt,
policy fit, native call, game outcome or empirical debit. Certificates stay 0/3
Duskblade. The completed **new decision** is ready for the required subsequent
independent review; this author has not self-approved it or invoked a nested
reviewer. That review does not reopen unchanged #547 or rerun an old cohort.
