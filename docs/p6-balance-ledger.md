# P6 balance ledger

Status: **PASS** on the untouched replacement holdout at game commit
`e32962086124a407233eb5281fd89cdd5b4cd469`.

This is the one-page reading copy for James before the human playtest. It lists
every gameplay number changed by P6, in the order a player meets it. Stored HP
pairs are shown exactly as they appear in content.

## What changed

| Player order | Balance value | Before P6 | Final | Why |
|---|---|---:|---:|---|
| Across the run | Emberheart post-combat heal | 6 HP | 3 HP | Remove the Duskblade's excess sustain without weakening Ashwarden. The relic text also says 3 HP. |
| Act 1 boss | Rootheart HP | `[150, 150]` | `[240, 240]` | Move the first boss into the intended 6–10-turn window. |
| Act 2 boss | Leviathan HP | `[260, 260]` | `[310, 310]` | Lift the second boss into the 6–10-turn window without adding damage, status pressure or another rule. |
| Act 3 elite | Voidforged Colossus HP | `[155, 168]` | `[300, 320]` | Stop mature decks from deleting the late elite before its mechanics matter. |
| Act 3 elite | Herald of the End HP | `[128, 142]` | `[260, 280]` | Give the second late elite the same meaningful decision window. |
| Act 3 boss | Eternal Sovereign HP | `[330, 330]` | `[650, 650]` | Give the finale enough time for its mechanics and escalation to develop. |

The semantic content diff from pre-P6 `61935a3` to the validated game contains
no other gameplay scalar change. P6 deliberately left enemy damage, ramps,
statuses, affixes, act-transition mending, potion probability, other player
content, saves and generated fixtures alone. Simulator constants and test
digests are evidence, not player balance values, so they are not entries in this
ledger.

## What the player-facing result became

The B0 diagnosis used seeds 1000–1199 (200 runs per aspect). The final B7 proof
used untouched seeds 2200–2999 (800 runs per aspect after its single declared
top-up). They are deliberately independent samples, so the table reports exact
counts rather than pretending to be a paired before/after experiment.

| Difficulty | B0 Ashwarden | B0 Duskblade | B0 gap | Final Ashwarden | Final Duskblade | Final gap |
|---|---:|---:|---:|---:|---:|---:|
| Vow 0 | 162/200 = 81.0% | 187/200 = 93.5% | 12.5 pp | 540/800 = 67.500% | 503/800 = 62.875% | 4.625 pp |
| Vow 5 | 83/200 = 41.5% | 130/200 = 65.0% | 23.5 pp | 164/800 = 20.500% | 167/800 = 20.875% | 0.375 pp |

At vow 0, boss length moved into the same intended window for both aspects:

| Boss act | B0 Ash / Dusk turns | Final Ash / Dusk turns |
|---:|---:|---:|
| 1 | 4.680 / 4.583 | 6.206 / 6.500 |
| 2 | 5.568 / 5.687 | 6.072 / 6.315 |
| 3 | 5.600 / 5.852 | 8.205 / 8.956 |

## Final holdout gate

- The primary vow-0 gap was 4.25 pp, so the single declared top-up ran; no
  further sample was taken.
- Vow-0 paired Ash-minus-Dusk result: +4.625 pp, 95% interval
  `[−0.086, +9.336]`; `−1 / 0 / +1` counts `167 / 429 / 204`.
- Vow-5 paired result: −0.375 pp, 95% interval `[−4.290, +3.540]`;
  `−1 / 0 / +1` counts `129 / 545 / 126`.
- All twelve vow/aspect/act boss means are 6–10 turns. The largest per-act
  death share is 48.85%, below the 60% ceiling.
- Duskblade shatters/fight in acts 2/3 are `1.282 / 1.773` at vow 0 and
  `1.336 / 1.811` at vow 5. Ashwarden's Smolder kills/fight exceed
  Duskblade's in every act at both vows.
- Every one of the 3,200 requested raw run rows is retained. Stalls and
  simulator errors are zero.

Reproducibility: final content SHA-256
`85b44aa5effc46c7db80601302aa38cb3512d8de0ad9e04de7a0c8d66652b819`;
combined vow-0 report SHA-256
`3260add43c0aa9292596b5f1aedfeb1805001314fec8ca13cfee04b840da57e6`;
combined vow-5 report SHA-256
`98d0e1c733dd2a288aec463af153018d1ba93c50ff547ffe262fb107bca3c8ef`.
