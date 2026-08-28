# Issue #421 progress — independent held-out confirmation v1

Date: 2026-08-28

This is a remote-review evidence snapshot, not product authority. It continues
issue #421 under the current task SSOT and current-main AI-SDLC. It does not
restart the programme, create a successor, admit a detector, promote product
content or spend protected acceptance/reserve seeds.

## Frozen question and execution

The mechanism-blocked CRN first look froze exactly one candidate without an
outcome-based tie-break:

- cell `S-low__A-low__Q-2__R-uncommon__W-0`;
- content SHA-256
  `765d9efd639fe3507d92ea2f7515b3ed92afd15166925a6db2f8934e3a777f07`;
- research settings acquisition priority 2 and Ward setup priority 0.

Before the first new row, held-out protocol
`d8496263dbaab0534cf44702e9ea1078c952b87c145b5c04b3492085d6f15be0`
froze one candidate and one live baseline, policy root 546 indices 0-127,
policy seeds 345900-345903, RandomBuild seeds 345700-345827, 3,072 maximum
rows, 3,600 seconds, 5,000 bootstrap resamples with seed 421, zero model
context during execution and zero protected seeds. Its zero-row self-check
passed before execution.

The deterministic runner executed the protocol once:

- 1,536 live rows and 1,536 candidate rows;
- 3,072 total simulator observation rows;
- 128.90891004202422 seconds;
- zero acceptance or reserve rows;
- decision `confirm-one-frozen-candidate`;
- analysis SHA-256
  `aa4ac97242d701bd3ff187ebcf8ee6bd804e7277845aba0474f435267b03dcb3`.

## Independent policy identity

All 128 held-out policy identities had one exact policy snapshot across
candidate/live, both aspects and every simulation seed. The snapshots were
all unique and had zero overlap with the 64 root-545 first-look snapshots.

## Whole-run package evidence

Counts are held-out policy identities out of 128. Active requires the final
deck to contain both registered cards and at least one of four simulations to
record both the registered applied and consumed events.

| Package | Active | Inactive | Final pair reached | Consumer reached with pair |
|---|---:|---:|---:|---:|
| Ash Bloodfire-Leech | 36 | 92 | 58 | 36 |
| Ash Poison-Catalyst | 70 | 58 | 82 | 70 |
| Dusk Afterimage-Guard | 94 | 34 | 101 | 94 |
| Dusk Scoreline | 81 | 47 | 96 | 81 |

Within-aspect exclusive policy witnesses were 12 Bloodfire-only, 46
Poison-only, 30 Afterimage-only and 17 Scoreline-only. Every preregistered
activation, sensitivity, reachability and functional-separation threshold
passed.

## Guardrails

- policy Vow-5 win rate: Ashwarden 0.099609375, Duskblade 0.041015625;
- duration candidate-minus-live upper 95% bounds: Ashwarden
  0.09043022029845174 turns, Duskblade 0.09961368720297727 turns;
- RandomBuild candidate win rates: Ashwarden V0 0.203125, V5 0.046875;
  Duskblade V0 0.2890625, V5 0.0625;
- maximum absolute RandomBuild point movement: 0.046875;
- candidate faults and candidate-added faults: zero.

## Scientific boundary and next action

This stage confirms independent whole-run activation, policy sensitivity,
functional separation, live reward-path reachability and guardrails for the
one frozen candidate. It does not estimate local producer-consumer
complementarity and therefore does not yet satisfy the complete package or
detector acceptance boundary.

Existing exact-content local discovery and validation rectangles will first be
audited as immutable evidence. Only the cheapest preregistered, equal-cohort
held-out causal panel needed to resolve remaining package endpoints may add
rows. Alternative scalar cells, adaptive support, ML, RL, product promotion
and protected seeds remain unauthorised.

## Ledger freeze

After the held-out audit, the append-only ledger is 2,514,243,584 bytes with
460,941 records, sequence 1 through 460,941, SQLite integrity `ok`, and SHA-256
`aacdb478eda35704bf4a49128fca804bbffcccad7f2fe2d62a153b0aabde285a`.
The database itself remains local; the exact plans, outputs, analyses and
content objects are in the compressed raw archive.

## Remote heads at preparation

- `origin/main`: `c4130163c7fb8edd865c0adc95732aae03e1bad2`
- `research/issue-421-p9-recovery-evidence`:
  `0b901fc0387b5ec023a08df2e2c1af1b9aa96620`
- `research/issue-524-causal-slate-evidence`:
  `f305b95d9e1d173e5d8150289afab9688c0ea7f0`
- `research/issue-525-mechanism-package-synthesis-evidence`:
  `7132e5e0d6e6e6dc196dda3ed90ad2be292608d6`
- `work/421-h34`: `4a94d155400162289a84f416336ff407f55b3cf6`
- `work/421-landscape-retune`:
  `ad4b99b1538d7200e9b228051a029e554e9b9912`
- `work/421-s009-exam`: `b30b290813d88109c5b9bc34354babefdc406f8d`

Research continues inside issue #421. No successor ticket or product pull
request exists at this snapshot.
