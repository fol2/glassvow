# Issue #421 co-hand and Energy-observation closure

## Status

This is an active, archive-only progress snapshot. Issue #421 remains open.
No detector, product candidate, protected-seed acceptance, RC, merge or issue
#108 P9 receipt is claimed.

The campaign is progressing and is not blocked. It has separated simultaneous
hand opportunity from later play, then failed closed when the next observation
surface violated its preregistered completeness rule.

## Exact co-hand reconstruction

A zero-row source census selected only existing deterministic `TURN` and
`KINDLE` events in the same `BalanceSim._harvest_fight` loop. Current content
has no `addCard`-to-hand effect, so `TURN`, `DRAW`, `PLAY` and `KINDLE` form a
complete fixed-scalar reconstruction for the two target cards. Whole-hand and
Pilot snapshots and variable-length discard arrays were rejected.

The separately preregistered 256-row identity preflight used the same 64
root-551 policies and seeds 346596-346599 as the frozen draw trace. Removing
only `turns` and `kindles` reproduced all anchor rows exactly:

- path/result mismatches: 0/256;
- RNG mismatches: 0/256;
- policy mismatches: 0/256; and
- trace-schema faults: 0.

The subsequent zero-row decomposition found:

| Necessary boundary | Robust policies | Gate | Result |
| --- | ---: | ---: | --- |
| Same-fight Ward and Warden's-Edge draws | 20 | 16 | pass |
| Simultaneous co-hand opportunity | 17 | 16 | pass |
| Same-fight co-play in either order | 13 | 16 | fail |
| Ward played before Warden's Edge | 10 | 16 | fail |

Four robust co-hand policies did not robustly co-play. No co-play policy lacked
co-hand opportunity. The first failed necessary condition is therefore
`legality-or-play-selection-unresolved`, not temporal hand availability and not
a proved policy-repertoire bottleneck.

## Legal-opportunity observation

A second zero-row source census found five combat-path current-Energy mutation
sites and five exact `ENERGY(n)` event appends. Ward and Warden's Edge are both
fixed cost-one cards. The only eligible minimal surface was therefore one
`energies(fight,event,n)` container in the existing harvest loop. Static-cost
inference and a new Pilot legal-action hook were rejected.

The one permitted 256-row identity preflight was path-, RNG- and policy-exact
after removing only `energies`:

- path/result mismatches: 0/256;
- RNG mismatches: 0/256; and
- policy mismatches: 0/256.

It nevertheless failed its frozen trace-completeness gate in 87 rows. In each
reported case, a terminal player-Smolder tick occurred after the `TURN` event
and returned on defeat before Energy was assigned or emitted. The protocol had
required every `TURN` to have a later Energy event. This source path invalidates
that preregistered assumption, so decision boundary 2 applies.

The preflight was not repaired or rerun, and its rows were not used for a legal
opportunity count. Energy telemetry and the natural Ward/Warden's-Edge route are
closed. The result does not authorise ML, RL, an optimiser or a policy knob.

## Scientific and authority constraints

- Scoreline payoff and Afterimage payoff remain separate, fixed and absent.
- Acquisition priority, Faultline rarity and Ward setup priority remain exact
  current-main levels; no non-null research knob exists.
- No factorial or Cartesian expansion ran.
- No ML, RL, optimiser, fitted model or adaptive candidate sequence ran.
- No acceptance or reserve seed ran.
- The append-only ledger remains 480,372 rows at SHA-256
  `4563f536f6a57e97ac7a5b51129f3967806e5bd445088547f0c874b1cd77b2e0`.
- New simulator observations since the preceding V26 snapshot total 512: 256
  co-hand identity rows and 256 failed Energy identity rows. Every other new
  decision was zero-row.
- The cumulative clean current-main observation count is 1,792. None entered
  the append-only research ledger or used a protected seed.

## Next bounded action

Freeze one zero-row competing-options audit over materially different
current-main Duskblade structural mechanisms that are not among the closed Ward,
Kindle, carrier, trigger or action-grammar families. Select at most one smallest
mechanistically complete option only when source-complete evidence and measured
decision value distinguish it. No simulator row, candidate, payoff, policy
knob, ML, RL, optimiser or protected seed is authorised before that decision.

## Remote heads at snapshot preparation

| Ref | SHA |
| --- | --- |
| `origin/main` | `c4130163c7fb8edd865c0adc95732aae03e1bad2` |
| `research/issue-421-p9-recovery-evidence` | `c528cb08c4bc1d833eeeb513a32a22435333c01f` |
| `research/issue-524-causal-slate-evidence` | `f305b95d9e1d173e5d8150289afab9688c0ea7f0` |
| `research/issue-525-mechanism-package-synthesis-evidence` | `7132e5e0d6e6e6dc196dda3ed90ad2be292608d6` |
| `work/421-h34` | `4a94d155400162289a84f416336ff407f55b3cf6` |
| `work/421-landscape-retune` | `ad4b99b1538d7200e9b228051a029e554e9b9912` |
| `work/421-s009-exam` | `b30b290813d88109c5b9bc34354babefdc406f8d` |

The issue #421 body remains at SHA-256
`3a0b39ceca35c54610dcf5e7e67710e3bd501a4bd76399075511ef8734a390b4`.
