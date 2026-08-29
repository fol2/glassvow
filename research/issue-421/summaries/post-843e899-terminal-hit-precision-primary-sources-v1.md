# Post-843e899 terminal-hit precision: primary-source class audit

## Scope and authority

This is a zero-row, primary-source-only audit of the first serial class authorised
by GitHub issue `#421` owner comment `5460811702`. The comment preserves archive
commit `843e899ca053b42b9c8b92486687a43eb1193eb9` and every earlier closure,
orders `terminal-hit precision/excess` before the other three serial classes,
and chooses exact-lethal precision before positive overkill. It also supplies
the finite pre-support selection rule: apply its six criteria lexicographically,
without using observed support, frequency, outcomes, aesthetic preference or
implementation convenience.

The exact product source is current-main commit
`c4130163c7fb8edd865c0adc95732aae03e1bad2`. No simulator row, ledger or cache
write, protected seed, product edit, GitHub mutation, support count or frequency
was used. This report can select only a complete contract for source/interface
and null preflight. It cannot establish activation, capacity, causal benefit,
balance, acceptance or product truth.

The controlling immutable boundary artefacts used from `843e899…` are:

- `research/issue-421/task-capsule-5459094066-v19.json`, SHA-256
  `7752a841f318c14ba766a268f8aad63f5270d99bc6bd9e7c55a5358b19b43cc0`;
- `research/issue-421/protocols/post-v38-fight-local-frontier-audit-v3.json`,
  SHA-256 `1ed01e349db8c3601fa93ccc33ae5fb9bd55b0bbe17ae9f1ae3741c3106b95cb`,
  and its summary, SHA-256
  `2e21b108bc2e8233cdbd995877d5bf20b396d6e245966bc729ca13a48b6380f3`;
- `research/issue-421/protocols/post-v30-unused-discrete-transition-audit-v1.json`,
  SHA-256 `169fb241e556d9dd5729ae6bbbd5a6b541ab4ccb098cfa30435ed01ca0a1dc01`,
  and its summary, SHA-256
  `a26063c374b21063674f72e49aee06be208f2c43a3d1055b1b18d9bd6e26155d`;
- `research/issue-421/summaries/post-v38-kill-relay-attribution-v1.json`,
  SHA-256 `71a4a9117b6a43c5d88ea8172e69bdf32553faccbc89254108812d412c7818b3`,
  and `research/issue-421/summaries/post-v38-kill-consumer-topology-v1.json`,
  SHA-256 `49b3bf3f776480327558d0bbaa8d7c8568747de918954f0666d6b386a6888711`;
- `research/issue-421/summaries/post-v38-reapers-bell-capacity-v1.json`,
  SHA-256 `0c8ed919c183c0a8255bbec2c1c24d0c78818d39005d5d0b07224d69dfe3ff05`;
- `research/issue-421/summaries/post-v30-combat-state-zone-frontier-audit-v1.json`,
  SHA-256 `1415ee899fefc2087a1b3730dfb71610ff4a5c8ed8e93842007b4f28eee4d4ed`;
- `research/issue-421/summaries/post-v30-cross-enemy-facet-identity-v1.json`,
  SHA-256 `a3f9f81407dc5d943487de33a5474663dc11f2216e68507873c2251caedaa0ee`;
- `research/issue-421/summaries/post-v30-multihit-facet-capacity-v1.json`,
  SHA-256 `dbf144eaf0615808eea7d63721a5695c5a3fa0878e62f5b183b362cdbb64e5cb`;
- `research/issue-421/summaries/post-v30-skill-chip-capacity-v1.json`,
  SHA-256 `471317d70b827206b7ea0787ea91f53822e4a8bab0cbecf2082c85e8889e7eae`;
- `research/issue-421/summaries/post-v30-shatter-card-capacity-v1.json`,
  SHA-256 `d8ed3a2e09e0c21d89665eafaa65c8e8716c9bba0a6b82b8fe4b6a83f1639db5`;
- `research/issue-421/summaries/post-v38-reward-overchip-capacity-v1.json`,
  SHA-256 `71b616c8c0f1f0c18ee8b578d5fcc87561d9b1d9eb92772752ec5bc7bd379fc8`;
- `research/issue-421/summaries/post-v38-novaflare-nonreward-capacity-v1.json`,
  SHA-256 `53c2e858dbb59e6258eea0fdb11cabcc8e89b959df6455f41494fe63f1b57e23`.

## Exact-source observation

At `c4130163…`, one concrete terminal-hit carrier exists inside the current card
resolution rather than in a hypothetical new event grammar:

1. `domain/rules/combat.gd:764-849` emits exact card `uid`, `id` and
   `targetIdx`, then opens `cb.pending_chips_active` and an empty
   `cb.pending_chips` for the played card at lines 803-805.
2. A player hit emits target `idx`, realised damage, `hpAfter`,
   `killingBlow` and non-negative `overkill`
   (`domain/rules/combat.gd:537-577`). Exact lethal is therefore the canonical
   cell `killingBlow == true && overkill == 0`. Finale hand-off is explicitly
   not a killing blow. The poison path at lines 1045-1072 lacks these fields and
   is not eligible.
3. The same hit records per-target `{"hit": true, "extra": ...}` whenever an
   Attack draws unblocked blood while the card accumulator is active
   (`domain/rules/combat.gd:578-582`). This Boolean is the current intrinsic
   Facet entitlement; it is set before the death path.
4. The matching death emits `DIE` synchronously
   (`domain/rules/combat.gd:588-609`). A non-final death independently receives
   the unchanged generic one Ember at lines 621-630.
5. After all authored effects, `play_card` computes the living-target implicit
   chip as `1 + authored chip + Beacon`, iterates the per-target records, and
   skips a record when its enemy is dead or combat is over. It then clears the
   whole accumulator (`domain/rules/combat.gd:811-827`). Thus an Attack can set
   the intrinsic `hit` entitlement on an exact-lethal target, but current source
   deterministically discards it at the deferred settlement because that target
   died. Authored explicit-chip accumulation is separately visible at lines
   924-940.
6. Living-target `apply_chips` is Dusk-only and refuses a dead target
   (`domain/rules/combat.gd:663-682`). A real Shatter changes pane state, applies
   stagger and Cracked, and grants two Embers at lines 685-699. The discarded
   dead-target entitlement never enters enemy `chips`, never emits `CHIP` or
   `SHATTER`, and never reaches that payoff.

The current content supplies paid Attacks and multi-enemy fights without any
acquisition change (`content/full-content.json:8-57,82-125`). The current pilot
chooses legal cards and targets and values `preview.lethal`, but neither
`preview_play` nor the pilot distinguishes exact lethal from overkill
(`domain/rules/combat.gd:1329-1405`; `tools/balance_pilot.gd:110-223`). This
supports existing-policy-first execution; it does not justify a precision
control or optimiser.

The unused-transition audit's exact-lethal/positive-overkill partition is valid
source algebra, but its immutable run stopped inconclusive before selecting a
representation. It supplies no support claim. Comment `5460811702`, not that
audit, supplies the product-semantic preference for deliberate precision.

## Finite source-grounded alternatives

The minimal alternatives below exhaust the existing synchronous surfaces that
can turn the exact-lethal cell into a complete producer/mediator/consumer/payoff
chain without crossing into a later serial class. Positive overkill is not a
parallel candidate; it remains the next ordered subfamily only after a lawful
exact-lethal closure.

| ID | Exact-lethal grammar | Source relation | Alias/dominance disposition |
|---|---|---|---|
| `P1` | Mark only the intrinsic per-target Facet entitlement that an exact-lethal Attack earned; at the originating card's deferred pending-chip settlement, aggregate one or more such dead-target marks to exactly one Ember, then clear | Reuses the existing `pending_chips` producer-to-settlement lifecycle; adds one bounded meaning to the otherwise discarded mark | Eligible and retained |
| `P2` | Grant one Ember directly at canonical `HIT_ENEMY` or matching `DIE` | Uses explicit terminal events but has no independent mediator; it overlays the current any-non-final-death Ember branch with a producer subset | Dominated by `P1` on source-grounded causal attribution and closed-family alias risk |
| `P3` | Preserve the dead target's chip, apply it to that dead target, or transfer it to another living enemy | `apply_chips` deliberately rejects dead targets; transfer would require a new target | Invalid current source or a rescue of closed cross-enemy Facet/target-transfer routes |
| `P4` | Let each exact-lethal target in one Attack pay, or turn the marks into a Shatter | Uses pending-chip target multiplicity or pane state | Reopens closed multi-target/multi-hit/Shatter cardinality; the one-per-card cap dominates it |
| `P5` | Mark every Attack kill irrespective of exactness, then settle one Ember | Same pending lifecycle as `P1` but removes the exact algebra | Collapses to the closed any-kill family and is prohibited |
| `P6` | Hold the mark for the immediate next `PLAY` | Extends past the originating card | Producer-subset rescue of the closed complete post-kill consumer topology |
| `P7` | Hold the mark to `END_TURN`, the next turn, intent history, or a private tag/transform | Requires a longer-lived carrier | Belongs to serial classes two, three or four; not evaluated here |

Energy plus draw is not an alternative payoff: it is the closed Reaper Bell
economy. Damage requires a target and reopens kill/target relays. Ward, healing
and statuses reopen their closed routes. A card/tag/transform belongs to serial
class four. One Ember is the smallest positive existing Dusk resource operation,
and `gain_embers` already clamps, emits and returns the realised delta
(`domain/rules/combat.gd:421-430`).

## Immutable alias audit

`P1` is a new primitive authorised by the owner; it is not presented as an
uncovered shipped mechanic. The source-complete state audit explicitly says a
different consumer/payoff over current Facet/Ember state is a new primitive,
not unused existing grammar. Its boundaries against the closed families are:

- **Any-kill and generic death Ember:** current generic Ember is emitted inside
  `_on_enemy_death` for any non-final death. `P1` requires the canonical
  exact-lethal algebra, an active authored Attack, its intrinsic per-target
  pending entitlement, survival of combat through the whole card, and the card
  settlement consumer. The generic Ember remains byte-for-byte baseline and is
  separately labelled. An any-kill mark is explicitly excluded.
- **Kill relay and complete kill topology:** those closures consume the next
  `PLAY` after a kill. `P1` never survives its originating card and has no later
  `PLAY`, target, consumer card or direct-damage payoff. It is therefore not a
  producer-subset rescue of their consumer topology.
- **Reaper Bell:** Reaper Bell requires natural relic ownership and pays Energy
  plus draw immediately on any non-final death. `P1` has no acquisition, pays one
  Ember at card settlement, and requires Dusk exact-lethal Attack attribution.
- **Facet, Shatter and overchip:** `P1` neither adds a living-target chip nor
  changes `chips`, `facet_max`, overflow, Shatter count, stagger, Cracked,
  multi-hit or cross-target ownership. It consumes only the intrinsic one-chip
  entitlement that current source has already skipped for a dead target; authored
  extra chip and Beacon do not increase its payoff. Existing living-target
  pending settlement and every `CHIP`/`SHATTER` event remain unchanged. The
  cross-enemy, multi-hit, Skill-chip, multi-enemy Shatter and reward-overchip
  closures therefore remain disjoint controls, not candidate levels.
- **Ember-reserve families:** `P1` produces a bounded one Ember during combat.
  It does not select Novaflare, consume an Ember reserve for damage, retain
  terminal reserve, or alter Hearth/post-combat healing. Existing Shatter,
  death, exhaust and other Ember producers are fixed interference.
- **Scoreline and Afterimage:** both payoffs are separate closed causal factors
  fixed off. Neither enters the mark, settlement or payoff, and this is not the
  old four-factor design.

## Complete twelve-field contract

The research identity is not shipping copy. The rule selects this one complete
contract:

1. **Identity and scope:** `dusk-exact-lethal-pending-chip-salvage-ember-one`;
   fight-local, originating-card-local, existing-content only, with no
   acquisition or global selector.
2. **Producer:** while `play_card` has its pending-chip accumulator active, an
   authored `type=attack` damage hit sets the normal per-target `hit` entitlement
   and its canonical hit is `killingBlow=true && overkill==0`. Poison, Finale
   hand-off, Art, potion and non-Attack damage are excluded.
3. **Mediator:** add only an ephemeral `exact_lethal_intrinsic=true` mark to that
   target's existing per-card `pending_chips` record. It represents exactly the
   base implicit one chip, never authored `d.chip`, Beacon or an explicit chip
   effect. No new `CombatState`, `RunState` or save field exists.
4. **Consumer:** the existing deferred pending-chip settlement after all authored
   card effects, provided `cb.over == false`. It order-independently computes
   `any` eligible dead-target precision mark, leaves normal living-target
   settlement in current insertion order, then consumes the aggregate once.
5. **Bounded payoff:** after unchanged living-target chip/Shatter settlement and
   before the accumulator clears, request exactly one separate
   `gain_embers(run, cb, 1)` if the aggregate is true. Record requested and
   realised deltas. Multiple marks, hits or targets never increase the request.
6. **Expiry and cardinality:** the originating `PLAY` may pay at most once. Every
   mark clears with the existing accumulator at card end. A non-exact hit,
   positive overkill, missing death, Finale hand-off, combat ending during the
   card, absent consumer or card return clears with no precision payoff.
7. **Natural cost:** draw and pay for a current Attack and arrange post-Ward and
   status-adjusted realised damage to equal a target's remaining HP while at
   least one enemy remains alive after the entire card. No free grant exists.
8. **Dusk, Ash and null:** enable only for existing Dusk aspect `0`. Mechanism
   omitted/off and every Ash aspect, including factor-on Ash controls, are exact
   current-main paths: no mark, queue change, Ember, RNG movement or result
   change.
9. **Separate factors:** precision salvage is one binary factor. Scoreline payoff
   and Afterimage payoff are independent closed factors fixed off; acquisition,
   rarity and Ward setup priorities remain current-main and unvaried.
10. **Interference rule:** preserve generic death Ember, normal living-target
    pending chips, Shatter Ember, Reaper Bell, cards, statuses and acquisition.
    Direct controls must show that only the discarded intrinsic entitlement is
    consumed and that baseline events are unchanged. Any-kill, extra-chip,
    next-`PLAY`, transfer and reserve interpretations are prohibited.
11. **RNG, persistence and policy:** no RNG call/cursor change, internal ID,
    content entry, reward pool, UI or save migration. Use the frozen policy first.
    No optimiser or precision selector is authorised; at most one bounded
    research control becomes eligible only after direct evidence identifies a
    policy-repertoire bottleneck.
12. **Direct telemetry:** record producer `PLAY` identity, canonical hit target,
    amount, blocked, HP-after, killing-blow and overkill; pending-record mark or
    exclusion; matching `DIE`; card-level eligible-mark count; `cb.over`
    exclusion; living-target settlement invariants; consume/expiry reason; and
    precision Ember requested/realised delta separately from death and Shatter
    Embers. No inferred endpoint supports a causal claim.

## Lexicographic decision and zero-row gates

`P1` is uniquely selected before support is available:

1. It has the strongest existing direct causal attribution. Current source
   already connects an Attack hit to a per-target pending entitlement, proves
   the entitlement is skipped because that exact target died, and owns a single
   card-terminal settlement/clear boundary. `P2` would invent a relay token that
   merely copies the producer predicate and would overlay the existing death
   Ember at the closed any-kill branch.
2. Among materially distinct candidates, `P1` adds one player-visible rule —
   precisely earned intrinsic Facet that cannot land is salvaged — and expires
   at the earliest existing consumer boundary, the same played card.
3. It adds no state field, content, acquisition, selector or policy control: one
   key in an already ephemeral record and one settlement-local aggregate suffice.
4. The cheapest decisive preflight is direct and finite. Mechanically prove the
   exact source interface; omitted/false/Ash path, queue, RNG, policy and result
   identity; then exercise scripted non-lethal, positive-overkill, exact-final,
   exact-non-final, poison, Finale, authored-extra-chip/Beacon, multi-hit,
   multi-target and living-target-Shatter controls. The mechanistic `A=mark`,
   `B=settlement conversion`, and `AB` controls must show that only `AB` emits
   the separately labelled precision Ember and that all baseline effects are
   invariant.
5. Dominance and immutable alias exclusions leave one finite candidate.
6. Canonical candidate-SHA tie-breaking is not reached.

This selection authorises only a separately preregistered source/interface/null
preflight with numeric context, row and wall-time caps and automatic success,
futility and inconclusive rules. If any source assertion, off/Ash identity,
single-per-card bound, intended-mediator isolation or immutable alias fails, the
exact-lethal class closes at zero simulator rows; it must not be repaired,
retuned from support, widened to positive overkill or rescued with another
consumer. Only after a passing null gate may the owner-prescribed direct A/B/AB,
capacity, CRN and held-out ladder proceed under separately frozen cohorts,
estimators and stopping rules.

## Method decision value and conclusion

Exact deterministic enumeration has decision value only for constructing and
checking this now-finite one-candidate grammar; it does not justify a candidate
sweep. BO/SMBO still lacks a search domain with measured same-budget value. RL
still lacks a demonstrated policy-repertoire bottleneck. QD still lacks validated
descriptors and a causal archive objective. None is authorised at this boundary.

The exact-source pending-chip salvage contract is materially distinct from the
closed any-kill, Reaper Bell, immediate kill-consumer, living-Facet/Shatter and
Ember-reserve families. Its producer is Dusk exact-lethal Attack damage; its
mediator is the intrinsic per-target Facet entitlement that current source
records but discards because the target died; its consumer is the originating
card's existing deferred settlement; and its payoff is one card-capped Ember.
This is a new, owner-authorised terminal-precision primitive, not an assertion
that current source already implements it and not a renamed next-play or generic
death reward.
