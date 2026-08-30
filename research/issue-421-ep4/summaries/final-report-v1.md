# Issue #421 EP4 final report

## Decision

**VETO. Stop EP4.** No P9 landscape is authorised and this is not a P9 claim.

The unique Phase A used all 4,000 registered runs and completed in 142.363
seconds. All three Godot jobs exited zero without timeout. One Dusk/Vow-0/arm-1
run, seed 4199, stalled against the Act 2 Leviathan at 30 turns. The registered
reliability maximum was zero, so this alone fixes the verdict at `VETO`.

Independently, Dusk `ward-mirror-edge` was reached in only 1/200 arm-1 runs at
Vow 0 and 0/200 at Vow 5, below the registered 5% floor in both cells. EP4 is
therefore also scientifically negative; removing the reliability veto would not
produce a GO.

## Gate matrix

| Gate | Result | Evidence |
|---|---:|---|
| Zero-row composition preflight | PASS | disjoint 12-pointer composition; reverse order byte-identical; 0 simulator rows |
| Phase A budget | PASS | 4,000/4,000 rows; one invocation; 142.363/2,700 s |
| Four arm-2 cells below 50% | PASS | Dusk 38%, 10%; Ash 29%, 10% |
| Planned above RandomBuild | PASS | 70.5%>38%; 28%>10%; 84%>29%; 52%>10% |
| Dusk destinations reachable and separated | FAIL | direct shatter 100%/100%; ward-mirror-edge 0.5%/0%; Jaccard 0.005/0 |
| Ash destinations reachable and separated | PASS | hand-size 13%/16.5%; poison-catalyst 75.5%/64.5%; Jaccard 0.113/0.165 |
| Vow-5 ceiling | PASS | Dusk 31.5%; Ash 44% |
| Ash lead 0–20 pp | PASS | 12 pp at Vow 0; 12.5 pp at Vow 5 |
| H10 | PASS | zero Ash shatters |
| Reliability | **VETO** | one Dusk/Vow-0/arm-1 stall, seed 4199, Act 2 Leviathan, turn 30 |
| Frozen H11 readout | FAIL | 2,419 positive Dusk enemy Smolder status events |
| Frozen Godot version comparison | FAIL | CLI and manifest used two display forms for the same frozen binary |

## Representation audit

The exact deterministic analyser output remains unchanged. Two hard reasons need
care when interpreting the product:

- H11 names *player-origin* enemy Smolder, but its frozen observer counted every
  positive enemy Smolder status event. Current-main has non-player-origin enemy
  Smolder, including Ashfall omen start status, which can later emit a jump. The
  count is preserved but does not isolate a player-origin identity breach.
- The protocol stored Godot's CLI string
  `4.7.2.stable.official.ed1daf0bf`; simulator manifests stored
  `4.7.2-stable (official)`. Logs print the registered CLI version and the frozen
  binary SHA-256 is unchanged. This was a literal representation mismatch, not
  an observed binary change.

Neither caveat changes the result: the real stall independently requires VETO,
and the two Dusk reachability cells independently fail the scientific gate. No
analysis correction or rerun was performed.

## Disposition

Stop with no parameter rescue, second composite, second Phase A, landscape, new
family, successor issue, product-main mutation, pull request or merge. Emberglass
and all previously closed families remain closed. P9 and issue #421 remain
unchanged and unaccepted.
