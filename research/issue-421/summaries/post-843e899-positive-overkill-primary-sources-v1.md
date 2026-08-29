# Post-843e899 positive-overkill excess: primary-source class audit

## Scope and authority

This is the zero-row source audit of the second and final direction in the
`terminal-hit precision/excess` class fixed by issue #421 owner comment
`5460811702`. The exact-lethal direction is now immutable closed evidence:
its direct identity preflight passed, but its separately preregistered complete
capacity rectangle produced zero exact-inactive policies and therefore applied
decision boundary 2. This audit does not lower that gate, select a posterior
subset or reopen exact lethal. It advances to positive overkill because the owner
ordered that direction before any support was read.

The source is current-main commit
`c4130163c7fb8edd865c0adc95732aae03e1bad2`. The controlling task capsule is
`task-capsule-5460811702-v20.json`, SHA-256
`673d0ee27b3337fe69b21a6964097cf49ee2e173ed4f8dd56fd4ba6fbba31385`.
The exact-lethal capacity protocol and summary have SHA-256
`b5e967510eb91a8ab75490c8fdf3711d5a5b94496b26cb1c32a94f3e9e97f1f9`
and `6f826f609bf677a63ae5161d08a99e82e6b4a44b6d57149d293ae6f73d032d1c`.
No positive-overkill support, frequency, cached observation, simulator row,
ledger row, protected seed or outcome was inspected to select this design.

## Exact source boundary

Current source provides one complete, deterministic terminal-excess boundary:

1. `hit_enemy` applies Strength, Weak, Vulnerable, multiplier and block before
   computing realised HP loss and `next_hp` (`domain/rules/combat.gd:545-566`).
   Positive overkill is therefore not printed damage: it is the canonical
   post-status, post-block value `max(0, -e.hp)`.
2. The emitted `HIT_ENEMY` event directly records `amount`, `blocked`, `hpAfter`,
   `killingBlow` and `overkill` (`domain/rules/combat.gd:568-577`). The sole
   positive-overkill cell is `killingBlow == true && overkill > 0`. Exact lethal,
   non-lethal damage and Finale hand-off are disjoint cells.
3. During authored card resolution, every blood-drawing Attack records its
   per-target intrinsic Facet entitlement in the existing `pending_chips` map
   before death is handled (`domain/rules/combat.gd:578-589`).
4. At the same card's deferred settlement, living targets receive
   `1 + authored chip + Beacon`, while dead-target records are skipped and the
   complete accumulator is cleared (`domain/rules/combat.gd:803-827`). A
   positive-overkill Attack therefore has both a directly measured excess and an
   otherwise-discarded base intrinsic Facet entitlement at an existing consumer
   boundary.
5. `apply_chips` deliberately rejects dead targets and is Dusk-only. Applying the
   chip to the corpse or transferring it to another enemy is not current source
   behaviour. The smallest existing Dusk-local resource operation is the bounded
   one-unit `gain_embers`; scaling by overkill magnitude would introduce an
   unsupported scalar family.
6. The current policy values `preview.lethal` but does not inspect or prefer
   overkill magnitude (`tools/balance_pilot.gd:110-166`). Existing-policy-first
   is therefore mandatory. A policy control cannot be introduced before a
   separate capacity result proves a repertoire bottleneck.

## Finite alternatives

The source and immutable closures leave the following finite alternatives:

| ID | Positive-overkill grammar | Disposition |
|---|---|---|
| `E1` | Mark the otherwise-lost base intrinsic Facet entitlement only when the canonical authored Dusk Attack hit has `overkill > 0`; aggregate one or more marks to one Ember at the same card's deferred settlement | Complete and eligible |
| `E2` | Grant one Ember directly at `HIT_ENEMY` or `DIE` | No independent mediator and overlays the closed generic any-kill branch |
| `E3` | Grant Embers proportional to overkill amount or add thresholds | Opens an unsupported scalar sweep and posterior magnitude subsets |
| `E4` | Convert overkill to Energy, draw, Ward or healing | Reopens closed action-economy, Reaper, Ward or recovery routes and lacks an excess-to-operation mediator |
| `E5` | Apply or transfer the dead target's chip | Reopens closed dead-target, cross-enemy and target-transfer routes |
| `E6` | Hold an excess mark to the next `PLAY`, turn or intent | Reopens closed next-PLAY grammar or belongs to later serial lifecycle classes |

`E1` dominates the other legal-looking forms. It uses the strongest direct
observation already emitted by source, the shortest existing lifecycle, one
ephemeral key in an existing per-card accumulator, no selector, no RNG and one
fixed resource unit. Storing or fitting the numeric overkill magnitude has no
decision value because the admissible payoff is fixed and card-capped; the
amount remains telemetry, not a factor level.

## Immutable alias boundary

- Exact lethal remains closed. `overkill == 0` is an explicit null here; it is
  not merged, thresholded or rescued.
- Generic any-kill and the existing death Ember remain unchanged. The selected
  consumer is the later originating-card Facet settlement and requires the
  otherwise-lost intrinsic entitlement plus `overkill > 0`.
- Reaper's Bell, immediate-next-PLAY, complete post-kill topology, target
  transfer, living Facet/Shatter, draw, duplicate, Scoreline and Afterimage
  remain immutable closed families.
- Positive overkill amount, card identity, hit count and target count are direct
  telemetry only. They cannot become candidate levels or posterior subsets.
- Multiple eligible targets on one card still request one Ember at most. Authored
  chip, Beacon and explicit chip effects do not increase the request.

## Complete twelve-field contract

1. **Producer:** during an originating authored Attack `PLAY`, a canonical
   `hit_enemy` call deals positive HP loss without Finale hand-off and emits
   `killingBlow=true && overkill>0` while the card's pending-chip accumulator is
   active.
2. **Mediator state:** that target's existing pending record gains one ephemeral
   `positiveOverkillIntrinsicFacet=true` Boolean. The emitted numeric overkill is
   recorded for attribution but is not stored as a scalar level and cannot scale
   the payoff.
3. **Consumer:** after every authored effect, the existing deferred pending-chip
   settlement order-independently asks whether any dead-target record has the
   mark, after leaving living-target settlement in its current insertion order.
4. **Payoff operation:** if combat continues, request
   `gain_embers(run, cb, 1)` exactly once per played card. Record requested one
   and the existing cap/quest law's realised delta separately.
5. **Expiry:** consume or expire with the originating card's existing
   pending-chip clear. Combat-over, absent consumer and every null producer clear
   without an excess payoff. No later `PLAY`, turn or combat can observe it.
6. **Natural cost:** the current policy must draw, pay and sequence an authored
   Attack whose post-status, post-block realised damage exceeds remaining HP,
   while at least one enemy remains after the card for the consumer to run.
7. **Dusk boundary:** only aspect zero is eligible. Ash, non-Attack damage,
   poison, direct hits outside a `PLAY` and Finale hand-off are exact nulls.
8. **Terminal-hit factor:** one binary factor named `terminalHitExcess` with
   levels `off` and `positive-overkill-facet-salvage-one-ember`. Magnitude,
   threshold, card and target are fixed observations, not levels.
9. **Fixed factors:** Scoreline and Afterimage remain separate closed factors
   fixed off. Acquisition, Ward setup, content, policy and RNG identities remain
   current-main within every comparison.
10. **Alias structure:** exact lethal, any-kill, Reaper, next-PLAY, transfer,
    Shatter tempo, draw, duplicate and proportional-overkill grammars are
    excluded. The generic death Ember and living-target Facet/Shatter effects are
    unchanged controls.
11. **Null path and policy exposure:** omitted and explicit off reproduce
    current-main; factor-on Ash and every excluded producer are exact null. Use
    frozen existing policies first. No policy control is admitted now.
12. **Direct telemetry:** record originating card, target, realised amount,
    blocked, HP-after, killing blow, numeric overkill, mark/exclusion, matching
    death, card-level mark count, living settlement, consume/expiry and requested
    versus realised precision Ember. No inferred endpoint substitutes for a
    directly observed stage.

## Zero-row conclusion

`E1`, canonically named `positive-overkill-facet-salvage-one-ember`, is the sole
complete source-compatible contract. Selection does not use the 512 exact-lethal
rows to infer positive-overkill support; it uses only the owner-fixed serial
direction, current source and immutable closure dispositions. The next lawful
step is one separately preregistered source/interface/null and A/B/AB preflight
with numeric ceilings. A failed preflight closes positive overkill without
repair. A passing preflight may advance only to a fresh existing-policy capacity
check. No ML, RL, optimiser, policy control or protected seed is authorised.
