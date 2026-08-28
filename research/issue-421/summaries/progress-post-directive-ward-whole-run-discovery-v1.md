# Issue #421 exact Ward whole-run admission

## Decision

Reject the exact immutable #525 `ward-mirror-edge` packet at decision boundary
2 and close that tested level-2 direction without retuning. Do not spend its
reserved held-out cohort. Continue with the next evidence-backed structural
Duskblade mechanism inside #421.

This is a bounded scientific negative, not a detector decision, product
promotion, protected-seed result or request for human direction.

## Frozen causal question

The only varied causal factor was the exact content packet:

- baseline: current-main content SHA-256
  `a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1`;
- candidate: immutable #525 candidate
  `4f02c9b78c4fa0d211f44f87257f2d4ca493559160619eeb2d785f8a7e8cc52c`,
  content SHA-256
  `0acbe2176743b1b705ef18876119f7e94734096f4a87ea4fb433020863ee0bbb`.

Scoreline payoff remained at its exact current-main value and was a shared
interference anchor. Afterimage payoff was separate, fixed at current main and
outside every endpoint. Acquisition priority, Ward setup priority,
`packageOrder`, `policyPackageOrder` and `policyPackageCommitment` were exact
nulls, not factors. This was therefore one binary exact-packet experiment, not
the old four-factor design and not a new five-factor factorial.

The packet was byte-copied from immutable #525 evidence. No candidate was
generated, fitted, ranked or tuned. The seven packet edits were aliased by
design, so the result supports no field-level or Mirror Edge-only attribution.

## Design and preregistered cap

Both content arms received every identical cell:

- root 551 policies 0-63 on Duskblade Vow 5 and Ashwarden Vow 5;
- policy simulation seeds 346596-346599;
- RandomBuild seeds 346532-346595 on both aspects at Vow 0 and Vow 5;
- 768 rows per content arm, 1,536 rows maximum;
- 900 seconds maximum wall time, 5,000 fixed bootstrap resamples and zero
  model-context tokens during execution and decision;
- zero acceptance or reserve seeds.

The complete matrix used common random numbers throughout. There were no
optional cells, promising-cell cohorts or adaptive expansions. The Scoreline
anchor was the only justified cross-package interference contrast. A movement
beyond its frozen threshold could reject the packet but could not authorise
extra cells or tuning.

The success gates required at least 16 active and 16 inactive policies per
package, eight reachable policies, eight reachable policies for each Ward
edge, four exclusive policies in each package direction, absolute Scoreline
and RandomBuild movements no greater than 0.10, RandomBuild win rate below
0.50, Vow-5 policy win rate no greater than 0.90, duration upper bound no
greater than 0.25 turns and zero reliability regression.

## Exact result

The deterministic runner completed all 1,536 rows in 64.53 seconds and chose
boundary 2.

| Whole-run support on 64 Dusk policies | Active | Inactive | Reachable | Consumer reached |
|---|---:|---:|---:|---:|
| Scoreline | 0 | 64 | 55 | 0 |
| Ward union | 14 | 50 | 20 | 14 |
| Brace edge | 6 | - | 11 | 6 |
| Mirror Edge edge | 13 | - | 19 | 13 |

Functional separation was 0 Scoreline-only, 14 Ward-only and 0 cross-active
policies. Mirror Edge was offered to all 64 policy identities, so its missing
support was not an offer-availability artefact. Ward activation rose from 2 to
14 policies against baseline, paired point estimate 0.1875 with interval
[0.09375, 0.296875], but still missed the fixed 16-policy sensitivity gate.
Scoreline remained inactive in both arms, so the interference movement was
exactly zero while its own support and consumer-reach gates failed.

The decisive global-power failures were independent of those support failures:

| RandomBuild grid | Baseline wins | Candidate wins | Candidate rate | Movement interval |
|---|---:|---:|---:|---:|
| Duskblade Vow 0 | 17/64 | 32/64 | 0.5000 | [0.0625, 0.40625] |
| Ashwarden Vow 0 | 15/64 | 27/64 | 0.421875 | [0.03125, 0.34375] |
| Duskblade Vow 5 | 9/64 | 8/64 | 0.1250 | [-0.125, 0.078125] |
| Ashwarden Vow 5 | 2/64 | 5/64 | 0.078125 | [-0.03125, 0.125] |

Duskblade Vow 0 hit the forbidden 0.50 ceiling and both Vow-0 movement
intervals lay wholly above the 0.10 limit. Policy identity, Vow-5, duration and
reliability controls passed: 64 distinct identities were exact across arms,
aspects and seeds; overlap with 320 excluded snapshots was zero; candidate
faults and added faults were zero.

## Independent read-only audit

`post_v38_ward_whole_run_discovery_audit.py` independently read the two exact
plan/output objects from the append-only ledger and reconstructed policy
identity, package and edge support, functional separation, exact RandomBuild
win counts and all eight hard-failure witnesses. It added zero simulator or
ledger rows and returned `PASS`.

The ledger remained byte-identical around that audit at 479,669 records,
sequence 1-479,669, SHA-256
`d96ee5162d5c7878f1e4b394791632e4cd514153c1510f4e8d055cbc4cb9834e`,
SQLite integrity `ok` and zero protected-seed rows.

## Scientific boundary and next action

Immutable #525 local probe/panel promotion did not establish current-main
whole-run admission. The exact packet now has multiple independent hard
failures: insufficient Ward sensitivity, a failed Brace edge, no current-main
Scoreline consumer expression or functional separation, and broad Vow-0
RandomBuild movement in both aspects. A numeric retune, packet splice or
held-out rescue would violate the frozen decision rule.

The next cheapest step is a zero-new-row inventory of the immutable #524
retained local edge-aspect interactions against current-main whole-run source
and archived traces. It will identify a materially different Duskblade
mechanism with an expressible mediator before any implementation or simulator
row. It will not reconstruct #524's historical plan, repeat #525's exhausted
Kindle/Branch paths, reopen Afterimage, or add ML/RL without measured decision
value.

## Exact artefacts

- protocol SHA-256: `bfc892c8c1c931294b38309319524cbeed455fd56eecf4a479b5642b565798aa`
- execution manifest SHA-256: `bfb08db7af22863edad7d186941c8732256e5a1473c30c3ead55dd4f7d431b16`
- runner SHA-256: `0d7dca792d968d1bfcfc28d1428f4071c0822a2e64372a67043773c2991547a0`
- result SHA-256: `62fbd2b3bb903bf41ffa4ed6f151884b0807376293eddf249c676ed05b8105e8`
- analysis cache SHA-256: `63b6d9ba4c79fa86eeeb0a8e54287463df4864deac27f0128d3a07ed9d77526c`
- independent audit runner SHA-256: `c28afa712e3eab5587aba75cf922b0cc039dc5c69205ad123c814061b379a5a1`
- independent audit SHA-256: `45add46363f5a11baaf84e8cc79092a3c162b92597b6424e1af5b3f376e8338b`
- raw cache archive SHA-256: `5a95a5564b64a8839b1152e3665b2a1f57d294dbfb8ab9060d165268f7bd01aa`

## Remote heads at publication preparation

- `origin/main`: `c4130163c7fb8edd865c0adc95732aae03e1bad2`
- `research/issue-421-p9-recovery-evidence`: `b7227e5b6b947f87a258899f5fb24bb1fdda7c0f`
- `research/issue-524-causal-slate-evidence`: `f305b95d9e1d173e5d8150289afab9688c0ea7f0`
- `research/issue-525-mechanism-package-synthesis-evidence`: `7132e5e0d6e6e6dc196dda3ed90ad2be292608d6`
- `work/421-h34`: `4a94d155400162289a84f416336ff407f55b3cf6`
- `work/421-landscape-retune`: `ad4b99b1538d7200e9b228051a029e554e9b9912`
- `work/421-s009-exam`: `b30b290813d88109c5b9bc34354babefdc406f8d`
