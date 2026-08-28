# Issue #421 progress — route and fight-quality closures

## Status

Two preregistered zero-row screens reached decision boundary 2:

- `close-elite-victory-trigger-family`;
- `close-exact-equality-fight-quality-family`.

No trigger, payoff, carrier or content was implemented. No threshold, encounter
kind, route weight, conjunction, policy subset or cohort was changed after the
first looks. Together with the preceding removal-refinement closure, these
results measure a repeated policy-repertoire bottleneck rather than authorising
another hand-picked candidate.

This remains research inside issue #421. No successor issue, product branch,
pull request, protected-seed run, detector claim, acceptance claim or #108 P9
receipt exists.

## Elite-victory capacity

The exact current-main source defines elite nodes from map row 5, maps them to
elite combat, assigns the existing elite reward schedule and gives healthy and
low-HP elite routes separate root-551 policy weights. The immutable trace
already retained entered node types and fight kind/result, so no new telemetry
or simulator row was needed.

Scoreline payoff, Afterimage payoff, the existing elite reward and the absent
new elite-victory payoff were separate fixed factors. One observational cell
used the same 64 policies and four seeds for every count and both package
anchors. The aliases were explicit: realised elite entry does not prove what
other nodes were reachable or that an elite weight caused the choice; victory
also depends on map RNG, HP and combat strength.

The screen found:

- 63 robust-opportunity and 63 robust-active policies;
- zero exact-inactive and one ambiguous policy;
- 22 viable robust-active policies;
- 206 elite-victory rows across acts 1, 2 and 3;
- all 31 Scoreline policies inside the elite-victory set;
- 53 of 54 Afterimage policies inside the elite-victory set.

The inactivity gate failed at 0 against 16. Scoreline two-sided separation
failed with zero Scoreline-only policies. Afterimage separation failed with one
Afterimage-only policy and Jaccard 0.828125. Elite victory is near-universal
progression, not a strategy discriminator.

Artefact identities:

- protocol SHA-256: `2eec98bd7d41d7ff60540a56f1c35aea35109a80de5a37cb2dc9ddd416c009a4`;
- runner SHA-256: `eddf087a2112e9f150af0d68029e72e04303da6eea50a96050aba11ebfb353ab`;
- summary SHA-256: `609dcb2d5595ff4f2505755b005c56d098ef50ee1b2c3743aa2a9d4ccf28f2da`.

Do not replace victory with entry, subset by act or encounter, tune route
weights, alter the existing reward, invent a payoff or rerun the cohort.

## Complete exact-equality fight-quality grammar

To avoid adaptive candidate-by-candidate iteration, the next protocol froze the
complete unclosed exact-equality grammar exposed by the current fight summary:

- won fight with `hpLost == 0`;
- won fight with `turns == 1`.

Both candidates were evaluated together once in a source-state simplicity
order. Boss, elite, normal and named-encounter subsets, HP-loss thresholds above
zero, turn thresholds above one, conjunctions and package-conditioned variants
were forbidden before execution. At most the first complete pass could receive
identity-preflight authority.

No-HP-loss victory was again near-universal:

- 63 robust-active, zero exact-inactive and 22 viable policies;
- 182 active rows across normal, elite and boss fights;
- only one Scoreline-only and one Afterimage-only policy;
- Afterimage Jaccard 0.828125.

One-turn victory was too sparse:

- four robust-active, 34 exact-inactive and zero viable policies;
- 34 active rows, all in normal fights;
- two candidate-only identities against Scoreline and one against Afterimage.

The first candidate failed inactivity and both two-sided separation gates; the
second failed active, viability and both separation gates. The complete family
is closed without a kind subset, relaxed threshold or conjunction.

Artefact identities:

- protocol SHA-256: `dbf01b88b3a13ebf92469ec551be59f45742812d23703231afb12cb3dd271c7a`;
- runner SHA-256: `c017b9db746c22ddd5fa004274f6e16f7741962a8754433841db42ceacf7d8c2`;
- summary SHA-256: `4332f3ad1cf49d44cb25860626ffc6d5b978b12644482a0108d310fdc8178746`.

## Measured narrowing result

The recent run-state screens now identify the same missing property from three
independent source surfaces:

- removal refinement: 32 robust-active but only eight exact-inactive, with four
  removal-only identities against Afterimage;
- elite victory: 63 robust-active and zero exact-inactive;
- no-HP-loss victory: 63 robust-active and zero exact-inactive;
- one-turn victory: only four robust-active and zero viable.

The remaining bottleneck is not observability of those surfaces. It is a
selective policy repertoire with enough active, inactive, viable and
package-independent identities at the same time. This does not itself justify
ML, RL, an optimiser or a payoff. Before another candidate, the remaining
current-main state grammar and missing telemetry surfaces must be frozen as one
bounded audit, with a numeric decision-value rule for whether any additional
method is warranted.

## Ledger and remote heads

Both screens reproduced all 256 trace rows exactly against their frozen
current-main policy, path, RNG and result before reading their estimands. Each
used zero new simulator observations, zero new ledger rows, zero model-context
tokens during execution and decision, and zero protected seeds.

The append-only ledger remains 480,372 records, SHA-256
`4563f536f6a57e97ac7a5b51129f3967806e5bd445088547f0c874b1cd77b2e0`,
SQLite integrity `ok`, protected-seed rows 0.

Remote heads at publication preparation:

- `origin/main`: `c4130163c7fb8edd865c0adc95732aae03e1bad2`;
- `research/issue-421-p9-recovery-evidence`: `1846fe0a5a55d4b5a5722dc0b56133eb08dcaa0c`;
- `research/issue-524-causal-slate-evidence`: `f305b95d9e1d173e5d8150289afab9688c0ea7f0`;
- `research/issue-525-mechanism-package-synthesis-evidence`: `7132e5e0d6e6e6dc196dda3ed90ad2be292608d6`;
- `work/421-h34`: `4a94d155400162289a84f416336ff407f55b3cf6`;
- `work/421-landscape-retune`: `ad4b99b1538d7200e9b228051a029e554e9b9912`;
- `work/421-s009-exam`: `b30b290813d88109c5b9bc34354babefdc406f8d`.

#524 and #525 remain immutable scientific evidence only. No historical plan was
reconstructed and no exhausted path from either issue was repeated.
