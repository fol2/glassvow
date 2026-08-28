# Issue #421 Hearth source, capacity and acquisition-priority identity

## Status

This is an active, archive-only progress snapshot. Issue #421 remains open.
No detector, product candidate, protected-seed acceptance, RC, merge or issue
#108 P9 receipt is claimed.

The campaign is progressing and is not blocked. A source-complete zero-row
audit found one unclosed direct Ember consumer, a zero-row capacity audit
isolated acquisition choice as its first failed necessary condition, and the
one permitted binary acquisition-priority preflight passed exact identity. No
causal treatment row ran.

## Source-complete Ember-state audit

The audit mechanically enumerated every executable current-main
`CombatRules` function that reads or writes `cb.embers`, `ember_cap` or
`gain_embers`. All 14 functions were accounted for. Exactly one direct consumer
was not closed by prior issue #421 evidence:

- `crownOfTheHearth` converts terminal unspent Embers to post-combat healing at
  three HP per Ember;
- it is a shipped boss-pool relic, not a proposed carrier; and
- it is mechanistically distinct from Novaflare reserve damage, Emberdance
  reserve Ward, automatic Art spending, in-combat weak-mend, voluntary-loss
  recovery and fight-quality triggers.

The only prior Crown of the Hearth mention in the issue #421 archive was as an
unselected boss-pool comparator. The audit read no cached observation, added no
simulator or ledger row and used no model context.

## Natural capacity

The capacity audit read the frozen exact current-main trace for the same 64
root-551 policy identities and seeds 346596-346599. Scoreline and Afterimage
remained separate fixed anchors throughout.

| Necessary condition | Potential active | Exact inactive | Viable | Result |
| --- | ---: | ---: | ---: | --- |
| Crown offered | 19 | 24 | 9 | eligible |
| Crown naturally selected | 2 | 54 | 1 | insufficient |
| Later Dusk Shatter opportunity after selection | 2 | 55 | 1 | insufficient |

The eligible offer cohort had 13 candidate-only identities against each
separate anchor. Exact source rows included 62 Crown offers, 13 natural
selections and 12 later Dusk-opportunity rows. The first failed necessary
condition was therefore candidate-specific acquisition choice. Post-acquisition
Shatter remained only an upper bound on terminal Ember and healing. The result
does not establish a general policy-repertoire bottleneck and grants no ML, RL
or optimiser authority.

## Acquisition-priority identity preflight

The research knob was the smallest possible binary intervention: when Crown of
the Hearth was already in a legal offered list, prefer it. It did not alter
offers, rarity, content, payoff, policy identities or the original random draw.
`RandomBuild` still consumed the same RNG choice before the legal override.

Fifteen direct controls passed:

- omitted and explicit false were exact on every surface;
- enabled changed exactly the two eligible deterministic and random choices;
- enabled changed no offered list and no RNG cursor;
- Crown absent, banned or already selected remained unchanged; and
- no other choice ID or mediator changed.

Only after those controls passed did the preflight run the two complete 256-row
null arms against the frozen current-main anchor:

| Identity gate | Mismatches |
| --- | ---: |
| Omitted versus anchor | 0 / 256 |
| Explicit false versus anchor | 0 / 256 |
| Omitted versus explicit false | 0 / 256 |
| RNG | 0 / 512 |
| Policy | 0 / 512 |
| Ordered trajectory | 0 / 512 |

Decision boundary 1 freezes only this exact acquisition-priority knob as
identity-safe for a separately preregistered mechanism block. No enabled
whole-run, causal contrast or candidate ran.

## Scientific and authority constraints

- Scoreline payoff and Afterimage payoff remained separate, fixed and absent.
- Current-main Hearth payoff remained separate and fixed; it was not varied or
  estimated.
- This was a source audit, capacity audit and one-factor identity preflight,
  not the old four-factor design or a joint factorial.
- No ML, RL, optimiser, fitted model, adaptive candidate sequence or human label
  entered execution or decision.
- Acceptance seeds 3000-5199 and reserve seeds 5200-5399 remain unused.
- The append-only ledger remains 480,372 rows at SHA-256
  `4563f536f6a57e97ac7a5b51129f3967806e5bd445088547f0c874b1cd77b2e0`.
- This snapshot adds 512 whole-run null identity replays and 15 direct controls,
  but zero scientific causal rows and zero ledger rows.
- The cumulative clean current-main whole-run observation count is 2,816. None
  entered the append-only research ledger or used a protected seed.

## Next bounded action

Run one zero-row exact-source observability and payoff-control audit for Crown
of the Hearth. It may select only the smallest existing event or fixed harvest
hook that identifies Crown opportunity and terminal Ember, and may freeze only
an explicit current-main-payoff null versus disabled-payoff factor without
changing acquisition priority.

Before any causal row, separately prove that omitted and current payoff
reproduce the frozen path, RNG, policy and result, that disabled payoff affects
only Crown healing, and that any telemetry is observation-only. No enabled
whole-run, factorial, ML, RL, optimiser or protected seed is authorised before
that identity boundary.

## Remote heads at snapshot preparation

| Ref | SHA |
| --- | --- |
| `origin/main` | `c4130163c7fb8edd865c0adc95732aae03e1bad2` |
| `research/issue-421-p9-recovery-evidence` | `83b420a2b2fafa8df67d9e5324270e5fdd57ed0a` |
| `research/issue-524-causal-slate-evidence` | `f305b95d9e1d173e5d8150289afab9688c0ea7f0` |
| `research/issue-525-mechanism-package-synthesis-evidence` | `7132e5e0d6e6e6dc196dda3ed90ad2be292608d6` |
| `work/421-h34` | `4a94d155400162289a84f416336ff407f55b3cf6` |
| `work/421-landscape-retune` | `ad4b99b1538d7200e9b228051a029e554e9b9912` |
| `work/421-s009-exam` | `b30b290813d88109c5b9bc34354babefdc406f8d` |

The issue #421 body remains at SHA-256
`3a0b39ceca35c54610dcf5e7e67710e3bd501a4bd76399075511ef8734a390b4`.
