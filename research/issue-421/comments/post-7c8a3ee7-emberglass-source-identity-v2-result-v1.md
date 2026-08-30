## Emberglass source/identity v2 result — inconclusive at final correction cap

The authorised absolute-path correction worked: both frozen Godot processes completed successfully, each wrote all 20 planned rows, and both probe outputs reported `PASS`. The v2 execution therefore completed 40 direct controlled executions in 1.592823 seconds.

The deterministic analysis did not complete. The v2 wrapper had globally replaced the inherited v1 `_load` function with the protocol-overlay validator. When the inherited analysis loaded the complete baseline and candidate probe-output JSON files, that validator rejected their keys before `_analyse` ran. The frozen summary therefore returned exit 2 with:

`analysis-exception:ValueError:v2 overlay keys differ from the frozen correction schema`

No identity gate or endpoint was evaluated. The owner agent did not read or fit the baseline or candidate endpoint content after the failure. Both raw outputs are preserved as immutable non-decision evidence; they are not source-identity success or scientific futility.

Evidence is published at commit [`e1ff9de6`](https://github.com/fol2/glassvow/commit/e1ff9de6b33b992157332159d048098a4eafa545) on ref `research/issue-421-post-c69b2752-persistent-contract-evidence`:

- preregistration comment: `5470131672`;
- protocol SHA-256: `28562ac99db14804cbe2c06748e2e22f511e74e36b951510d5cf2f792b573e82`;
- deterministic summary SHA-256: `eca403d6e1f1a45dc0ca01cabdebc97efca76103a7e4aa79f7052a9a7f0bb53b`;
- execution audit SHA-256: `38616144ebef7ffe649256048e108df9a584a77724331c2e9ac0e6dc162a1041`;
- baseline output SHA-256: `6b56900ab1cfdf6919d1a429bc9ab62e4cb0b905be6da022969493678aac5d91`;
- candidate output SHA-256: `cfece8e320ea104c03ff9d52e02457a2cc8baafb6cb4006ca7037b5a0818f052`;
- Godot processes `2`, direct controlled executions `40`, completed probe outputs `2`, evaluated analysis gates `0`;
- simulator rows, ledger reads/writes, protected-seed rows, product mutations and reruns: all `0`.

### Authority consequence

The inherited rule records `INCONCLUSIVE_AT_FINAL_CORRECTION_CAP` without rerun, repair or endpoint inference. Option A's one and final corrected version is exhausted; options B and C remain unchosen as instructed. Current authority therefore contains zero legal autonomous actions.

If #421 is to continue without B or C, a new explicit owner delta is required. The smallest possible delta would authorise exactly one analysis-only separately versioned correction over these two immutable v2 outputs: no new Godot process, row, seed identity or endpoint inspection before freeze; scope the overlay validator to the protocol only, then apply the unchanged inherited v1 analysis and decision rules. That delta is not inferred or executed here.

### Safe blocked state

Product `main` and the development worktree remain unchanged. #421 is open but not accepted; #108 P9 has no receipt. No product branch, PR, Actions run, protected seed, optimiser, candidate substitution or grammar widening exists. Keep #421 at `needs-info` until the owner either authorises that exact analysis-only delta or leaves the final inconclusive disposition in force.
