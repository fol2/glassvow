# #457 F0 evaluator — paired controls, mini-landscape, tidy response

Issue: [fol2/glassvow#457](https://github.com/fol2/glassvow/issues/457).
Part of [#454](https://github.com/fol2/glassvow/issues/454). Hosts from [#456](https://github.com/fol2/glassvow/issues/456).
Engine: **4.7.2.stable.official.ed1daf0bf**. Worker count: **8** (M1 Max QUALIFIED).
This is a screening experiment. It is not an acceptance exam and does not emit C1–C4 PASS/FAIL.

## Protocol

Common random numbers across all 32 balanced Tier-0 candidates from
`tools/balance_content_doe.py --count 32 --seed 421`. Development seeds and
policy root 454 come from `docs/balance/421-content-search-seeds-v1.json`.
Mini-landscapes use the frozen #215 axes (thinMax 25, midMax 35, aspect
shatter/smolder medians, shatter-then-smolder-then-attrition tie order). No
per-candidate re-fit. No CEM. No seeds ≥5000. Audit 8000–8199 stays sealed.

| Arm | What | Seeds | n per cell |
|---|---|---|---|
| Controls 1–4 (sweep CLI) | planned/random × competent/random | 6000–6031 | 32 |
| Ranking / Pareto | **arms 1 and 2 only** | 6000–6031 | 32 |
| Mini-landscape | 128 policies, root **454** | 6100–6107 | 8 |

The existing `balance_sweep.gd --mode=controls` path always emits four arms.
Ranking, paired bootstrap and the Pareto set use arm 2 (and landscape cells).
Arms 3–4 remain in the immutable raw rows as unused diagnostics.

Driver: `python3 -B tools/balance_f0.py --jobs 8 --boot 1000 --out DIR`.
Raw shards and `observations.jsonl` stay in the output directory (replayable,
not committed). Tidy product: [`data/457/summary.json`](data/457/summary.json).
Candidate identities: [`data/457/doe-manifest.json`](data/457/doe-manifest.json).

## Completeness

Host fingerprint `27a837c0…` matches the #456 M1 Max packet. Live
`content/full-content.json` SHA `a0d608a5…` did not move. Search-space SHA
`524f2773…` and driver SHA `619bc0e7…` match the #456 qualification packet.

| | Count | Simulator rows |
|---|---:|---:|
| Candidates requested | 32 | — |
| Complete F0 (controls + landscape) | **31** | 512 + 4,096 each |
| Fail-closed early-stop | **1** (`c027`) | controls only (512) |
| Control rows (all candidates) | — | 16,384 |
| Landscape rows | — | 126,976 |
| Total | — | **143,360** |

All 32 have either a complete observation set or an explicit early-stop
record. Observed seeds span **6000–6107** only.

Early-stop counts **arms 1 and 2 only** (the protocol arms). A first pass
also counted arms 3–4 from the four-arm sweep CLI and wrongly stopped eight
candidates on a single arm-3/4 stall; those eight were resumed and completed.
The remaining early-stop is `c027`: one **arm-1** Dusk V0 stall on seed 6015
versus `c000`’s zero. Errors were zero everywhere. Identity collapse was not
observed.

Replay: re-running `c000` into a second output directory reproduced
**byte-identical** `observations.jsonl` (SHA `cef6c8db…`). Manifests match
after stripping wall-clock / path metadata.

## Uncertainty-aware comparison with `c000`

Paired seed-block bootstrap, B = 1,000, seed 454. Control blocks are the 32
seeds 6000–6031; landscape blocks are the 8 seeds 6100–6107. The same
resampled seed IDs are applied to the candidate and to `c000`.

Display order below is **summed normalised gate deficit** (C1a / C1b / C2-arm
/ C2-gap, each scaled to 0–1 per grid then summed). It is **not a score** and
must not be used as a weighted ranking.

`p(lower deficit)` is the paired probability that the candidate’s deficit sum
is below `c000`’s on the same bootstrap draw.

| id | deficit sum | p(lower deficit) | Dusk V0 arm 2 | Dusk V0 top | within-10 (D0,D5,A0,A5) | viable | note |
|---|---:|---:|---:|---|---:|---:|---|
| c000 | 4.917 | — | 9/32 (28.1%) | shatter:fat 84.6% | 1,1,1,1 | 2,1,2,2 | H39 baseline |
| **c015** | **3.167** | **0.983** | 10/32 (31.2%) | **smolder:fat 100%** | 2,1,2,2 | 4,2,2,2 | Pareto; Dusk identity watch |
| **c029** | **3.167** | **0.994** | 9/32 (28.1%) | shatter:fat 86.0% | 2,1,2,2 | 4,2,2,2 | Pareto; identity holds |
| c002 | 3.500 | 0.921 | 4/32 (12.5%) | shatter:fat 78.8% | 1,1,2,2 | 3,3,2,2 | identity holds |
| c019 | 3.750 | 0.950 | 8/32 (25.0%) | **smolder:fat 100%** | 1,1,2,2 | 4,1,2,2 | Dusk V0 identity watch |

c029 bootstrap, Dusk V0 (intervals are 2.5 / 50 / 97.5 percentiles):

| Proxy | p025 | p50 | p975 |
|---|---:|---:|---:|
| top cell rate | 0.750 | 0.862 | 0.937 |
| third cell rate | 0.652 | 0.750 | 0.819 |
| fourth cell rate | 0.153 | 0.710 | 0.750 |
| arm-2 rate | 0.125 | 0.281 | 0.438 |
| top − arm-2 margin | 0.400 | 0.578 | 0.748 |
| within-10pp count | 1 | 2 | 4 |
| viable count | 3 | 4 | 4 |

c029 versus `c000` on the paired deficit-sum delta: p025 **0.335**, p50 1.417,
p975 2.514. The interval sits above zero — at this fidelity `c029` is below
`c000`’s deficit on essentially every bootstrap draw (`p = 0.994`). That is
still a screening interval, not an exam PASS.

C2 proxies are already slack at this fidelity: arm 2 < 50% on every complete
candidate, and top−arm-2 ≥ 35 pp on almost every grid (`c2arm` deficit 0;
`c2gap` deficit 0 except c022 / c025 / c028). The binding F0 deficits are
**C1a (within-10pp count)** and **C1b (viable-cell count)**. That is a
screening result, not a gate verdict.

## Pareto frontier

Eligible set: status `complete` and no early-stop. Minimise the four
normalised deficit coordinates `(c1a, c1b, c2arm, c2gap)`.

**Frontier: `{c015, c029}`.** Both sit at `(1.667, 1.500, 0, 0)`. Neither
dominates the other. `c002` at `(2.000, 1.500, 0, 0)` is next on display
order and is dominated on C1a.

| Feature | c000 | c015 (Pareto) | c029 (Pareto) | c002 |
|---|---:|---:|---:|---:|
| duskMaxHp | 64 | **60** | **60** | 62 |
| flareDamage | 9 | **11** | **11** | 7 |
| ashfallSmolder | 6 | 5 | 6 | 4 |
| ashfallWard | 5 | 4 | 6 | 7 |
| regrowthHeal | 2 | **4** | **4** | 2 |
| ironSkinWard | 3 | 2 | 2 | 5 |
| guardedStrikeWard | 4 | 6 | 4 | 3 |
| venomStrikeSmolder | 4 | 4 | 2 | 5 |

Identity: `c029` and `c002` keep Dusk shatter:fat / Ash smolder:fat. `c015`
(and also `c013`, `c019`) put Dusk V0 on **smolder:fat** — not the reversal
early-stop (Ash does not flip to shatter), but a reason not to race `c015`
as if it were identity-preserving. F1 should treat `{c029, c002}` as the
identity-clean shortlist and keep `c015` only as a C1-looking contrast.

## Features and interactions for F1

Main-effect ranges are deficit-sum means among the **31 complete**
candidates. Ranked-arm (1–2) stalls are almost absent: only `c027` (one arm-1
stall). A first-pass stall table that included arms 3–4 was discarded; it is
not a protocol signal.

| Feature | Complete-set range | Pareto / identity note | F1 |
|---|---:|---|---|
| **regrowthHeal** | 0.95 (level 4 best: 3.72 vs 4.67 at 1) | Both Pareto points are level **4** | **Keep 4** in the racing set. Do not drop it on the old four-arm stall scare. |
| **duskMaxHp** | 0.90 (**60** best 3.85; **64 / c000 worst 4.75**) | Both Pareto points are 60; c002 is 62 | **Narrow around 60–62.** H39’s 64 looks locally expensive. |
| **flareDamage** | 0.76 (11 best 3.94; 9 / c000 4.69) | Both Pareto points are **11** | Keep the high-Flare neighbour; 9 is a poor local. |
| ashfallWard | 0.44 (7 4.08; 3 4.52) | mixed on the frontier (4 vs 6) | Secondary. |
| ironSkinWard | 0.43 | Pareto sits at **2**, c002 at 5 | Do not collapse to “higher Ward”; keep both sides for F1. |
| ashfallSmolder | 0.40 | 5 vs 6 on the frontier | Low priority. |
| guardedStrikeWard | 0.28 | | Low priority. |
| venomStrikeSmolder | 0.17 | 4 vs 2 on the frontier | Weak main effect. |

The pairing **duskMaxHp=60 × flareDamage=11 × regrowthHeal=4** appears on
both Pareto points. That is the interaction worth keeping. It is also the
region where Dusk V0 can flip to smolder:fat (`c015`). F1 should race the
identity-clean copy (`c029`) against the identity-clean neighbour (`c002`)
before expanding that corner.

Nine-cell shape, 31 complete landscapes: Dusk V5 is shatter:fat on 30/31;
Dusk V0 shatter:fat on 28/31 (smolder:fat on `c013`, `c015`, `c019`); Ash V0
smolder:fat on 30/31. Tier-0 knobs move rates and can pick up a second
within-10pp cell. They still do not open the thin/mid interior. If F1 racing
on `{c029, c002}` plus a second 16-candidate batch cannot get within-10pp
count ≥ 3 on Dusk, that is evidence to **expand into Tier 1** (starter
packages / deck-thickness / economy), not to grind more of the same eight
leaves.

Do not spend F1 budget on C2. Arm-2 absolute rate and top−arm-2 margin already
sit on the slack side of the proxy at n=32 / 128 policies. Racing should
increase seed count on C1a/C1b for `{c029, c002}` and should not promote
`c015` / `c019` until the Dusk V0 smolder-fat top is understood.

## What this does not claim

- No candidate PASSes C1–C4. F0 does not sit the frozen exam.
- No single weighted score selected a winner. Display order is labelled.
- Surrogate fitting is #458. This packet is the tidy table #458 is allowed to
  read.
- One stall in 512 is a severe early-stop; relaxing it is an F1 protocol
  decision, not a silent change here.

## Replay

```bash
python3 -B tools/balance_f0.py --self-test
python3 -B tools/balance_content_doe.py --count 32 --seed 421 --out DIR/doe
python3 -B tools/balance_f0.py --jobs 8 --boot 1000 --out DIR --candidates DIR/doe
# one-candidate identity check (second directory):
python3 -B tools/balance_f0.py --only=c000 --jobs 8 --out DIR-replay --candidates DIR/doe
```

Godot must be `4.7.2.stable`. The host must match a QUALIFIED #456 packet
(M1 Max 64GB or M4 Mac mini 16GB). Cloud remains NOT QUALIFIED.
