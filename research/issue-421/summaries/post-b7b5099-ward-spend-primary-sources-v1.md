# Post-b7b5099 Ward-spend family: primary-source note

## Scope

This note supports only the preregistration of the finite family authorised by owner comment `5464228499`. It does not reconstruct #524 or #525, reopen a closed family, select a shipping card, or claim support, complementarity, detector admission, product acceptance or P9 completion.

## Live authorities and immutable evidence

- The live #421 body is the task SSOT; its UTF-8 body SHA-256 is `32b565aac287d12ed98b858746158a5cc5136fbcdbe684485e43232172d58e17`.
- Owner comment `5464228499`, updated `2026-08-29T19:00:30Z`, selects deliberate Ward investment followed by a same-player-turn Ward-spend finisher. Its exact UTF-8 body SHA-256 is `367cb6da57c092f487ff39ce023bd86607a475abf0e12dbf02ad03d5082b768f`.
- Current main is `c4130163c7fb8edd865c0adc95732aae03e1bad2`. Archive head `b7b509939ff0bd8f75ba2218309e09cb94808878` and every earlier valid closed-family disposition remain immutable.
- The #525 level-two freeze is used only for the fact that a common one-energy Attack named `mirrorEdge` was a reachable research card surface. The file SHA-256 is `a8a966663f260b9128376d332c173ae0944bd5f006099f96589f8fefa85ba351`. Its changed `brace`, `bulwark`, `mirrorEdge` numbers and its Ward-grant interaction are not reused.

## Current-main source facts

From `content/full-content.json` at current main:

- `brace` is common, costs 1, and has one Ward effect: 8 base or 11 upgraded.
- `bulwark` is uncommon, costs 2, and has one Ward effect: 13 base or 18 upgraded.
- `guardedStrike` supplies the nearest current common one-energy Attack basis: 5 base damage or 7 upgraded damage, plus authored Ward that this research surface deliberately omits.
- `mirrorEdge` is absent from both the current card catalogue and common pool.

From `domain/rules/combat.gd` at current main:

- `play_card` is the single `GlassvowGame` card-resolution call and applies a card's effects in authored order.
- `gain_block_player` returns the realised Ward gain and emits the canonical `blockGain` event.
- `hit_enemy(..., is_attack=false)` is a separate deterministic damage operation: it can be absorbed by enemy Ward but does not use Fervor, Dimmed, Cracked or Attack facet entitlement.
- `preview_play` is the policy-facing pure arithmetic mirror and therefore must mirror any admitted research effect while leaving policy identity unchanged.

From `tools/balance_pilot.gd` and `tools/balance_policy.gd` at current main:

- The frozen policy scores a common one-energy 5-damage Attack with one unknown special above the current card-decline threshold, without any new priority weight.
- Unknown specials use the already-installed fallback special score. This permits an existing-policy capacity test without changing the policy repertoire.

## Mechanistic derivation

The consumer is a research-only common one-energy Dusk Attack with fixed base damage 5 (7 upgraded) and one special operation. It never grants Ward. An exact producer play records only its realised Ward gain in combat-local, non-stacking state. The later consumer must have both producer credit and current Ward at least equal to its frozen spend level; it then spends exactly that level and requests one separate damage operation.

The finite grid is derived before support:

| Spend | Basis | Payoff ratio | Separate damage |
|---:|---|---:|---:|
| 4 | half of base `brace` Ward | 0.5 | 2 |
| 4 | half of base `brace` Ward | 1.0 | 4 |
| 8 | all base `brace` Ward | 0.5 | 4 |
| 8 | all base `brace` Ward | 1.0 | 8 |

The ratios cap conversion at one raw damage per Ward spent. The duplicate four-damage cells remain distinct because one spends twice the defence; that is a mechanistically relevant trade-off, not an alias.

## Method decision

Exact deterministic enumeration of the frozen finite grid and policy identities is sufficient. No ML, RL or optimiser is justified before a valid capacity and CRN result identifies a remaining policy-repertoire bottleneck and a matched-budget preregistration can measure decision value.
