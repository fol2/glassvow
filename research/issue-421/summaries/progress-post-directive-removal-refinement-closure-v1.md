# Issue #421 progress — removal-refinement capacity closure

## Status

The preregistered zero-row removal-refinement capacity screen reached decision
boundary 2: `close-removal-refinement-trigger-family`. The substrate had useful
activity, route breadth and Scoreline separation, but it did not preserve enough
exact inactivity and was not sufficiently independent of Afterimage. No trigger,
payoff, carrier or content was implemented, and the cohort will not be retuned or
rerun.

This remains research inside issue #421. No successor issue, product branch,
pull request, protected-seed run, detector claim, acceptance claim or #108 P9
receipt exists.

## Preregistered question and design

Current main already records a `removalEconomy` diagnostic package with three
permanent-card-removal routes:

- shop: `shopVisited` to `shopRemovalBought`;
- Forgotten Shrine: `forgottenShrineSeen` to `shrineRemovalChosen`;
- Mirror: `mirrorSeen` to `mirrorRemovalChosen`.

The exact issue #490 response-contract source was frozen at SHA-256
`6ffa7f313561f8309de3256b6a78a29feb4a696fdbc31489eaa59db283d2c5c6`.
The policy source independently samples `removalAppetite` over 4 through 28 and
`removalMinCopies` over 1, 2 and 3. These existing surfaces justified a
necessary-capacity test without defining a payoff.

The design was one immutable observational cell, not a factorial. It compared
the same 64 root-551 Duskblade Vow-5 policies and seeds 346596–346599 against
the exact cached current-main baseline. Scoreline payoff and Afterimage payoff
were separate fixed factors with separate shared anchors. Removal payoff was
fixed absent and deliberately undefined.

The frozen ceilings were 512 cached rows read, zero new simulator observations,
zero new ledger rows, zero model-context tokens during execution and decision,
zero protected seeds and 30 seconds. Success required at least 16 robust
opportunity, 16 robust active, 16 exact inactive and eight viable-active
policies; at least two robust trigger routes; and separate two-sided Scoreline
and Afterimage support with Jaccard at most 0.75.

Artefact identities:

- protocol SHA-256: `49945d91274a326d858deafa963e5eec70ce7b86291906fea7c9ea8726d99ecd`;
- runner SHA-256: `99aabde5dc66f3c3947f14da56429fd6ea5314fe504f8ad9a64825712406442e`;
- summary SHA-256: `ea92533f960e22d06cd00f20867038f8dbe12c12cae1c05d86857e6889e14db0`.

## Result

All 256 explicit-current trace rows reproduced the frozen baseline policy, path,
RNG and result exactly before any removal count was read. The screen found:

- 64 robust-opportunity policies and 32 robust-active policies;
- 14 viable robust-active policies;
- 24 ambiguous policies and only eight exact-inactive policies;
- 97 active rows and 233 opportunity rows;
- two robust trigger routes: shop and Forgotten Shrine;
- one immutable baseline fault.

Scoreline separation passed: 15 removal-only policies, 14 Scoreline-only
policies and Jaccard 0.369565. Afterimage separation failed: only four
removal-only policies against the fixed minimum of eight, despite 26
Afterimage-only policies and Jaccard 0.482759.

The exact-inactive gate also failed at eight against 16. Every other frozen
gate passed. Runtime was 9.19 seconds.

## Bounded interpretation and stop

Permanent removal is observable and not merely the Scoreline route, but it is
too broad on this policy repertoire and overlaps the broad Afterimage anchor.
Whole-run aggregate events do not identify the removed card, timing, later draw
frequency or a causal benefit. The result therefore cannot justify a new
Duskblade payoff or carrier.

Close the complete removal-refinement trigger family. Do not subset routes,
weaken inactivity or separation gates, tune the removal policy, invent a payoff,
add a carrier or rerun the cohort. Continue inside #421 with the next materially
different source- and evidence-backed structural mechanism.

## Ledger and remote heads

The append-only ledger is byte-identical before and after: 480,372 records,
SHA-256 `4563f536f6a57e97ac7a5b51129f3967806e5bd445088547f0c874b1cd77b2e0`,
SQLite integrity `ok`, protected-seed rows 0.

Remote heads refreshed immediately before publication preparation:

- `origin/main`: `c4130163c7fb8edd865c0adc95732aae03e1bad2`;
- `research/issue-421-p9-recovery-evidence`: `1b97c300dd83a2fb5ac21be742fcfd1685fc0ff8`;
- `research/issue-524-causal-slate-evidence`: `f305b95d9e1d173e5d8150289afab9688c0ea7f0`;
- `research/issue-525-mechanism-package-synthesis-evidence`: `7132e5e0d6e6e6dc196dda3ed90ad2be292608d6`;
- `work/421-h34`: `4a94d155400162289a84f416336ff407f55b3cf6`;
- `work/421-landscape-retune`: `ad4b99b1538d7200e9b228051a029e554e9b9912`;
- `work/421-s009-exam`: `b30b290813d88109c5b9bc34354babefdc406f8d`.

#524 and #525 remain immutable scientific evidence only. No historical plan was
reconstructed and no exhausted path from either issue was repeated.
