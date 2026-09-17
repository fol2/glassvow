# DD1-N0-RECOVERY-1 after 5718464731 (binding 5718448223)

Same candidate. Attempt 1/1 not reset. D/C/H/ALLOCATION unchanged. Certificates **0/3**.
N0 result: **BLOCKED / not accepted**. P_0 vigil+pre-terminal run archived; P_5 not earned in the fixed 16-root sequence. This is not author self-approval.

Starting G `84cd143f44923294e614def62de74e720598648a`. Binding [5718448223](https://github.com/fol2/glassvow/issues/421#issuecomment-5718448223). Task [5718464731](https://github.com/fol2/glassvow/issues/542#issuecomment-5718464731). Protocol [5717964158](https://github.com/fol2/glassvow/issues/421#issuecomment-5717964158) SHA-256 `92b78c7a93ddf5f46cc4ff1fe77f42729223a9814fc59241f8cccddade06b7df`.

## Nine-bullet response map (5712464645)

### Reader (four cases)

1. **Required digest.** `decoded_payload` still rejects missing/non-string/empty/mismatching digest before parse. `_as_float` replaces `float(Variant)` so the reader compiles under warnings-as-errors. Retained capture `reader-capture-bytes.json` is mutate/restore input; tests do not rewrite it.
2. **Non-dictionary event.** `_normalize_payload` rejects the whole capture. Control: insert a non-object, recompute digest, require null, restore.
3. **Integer fields.** `exact_int` accepts int or finite float exactly equal to that integer. `1.9` is not `1`.
4. **play_observations.** Returns `null` on malformed capture, successful empty Array when a well-formed capture has no plays. Dual PASS pair: overlay `native_starts=45`.

### P_v / procedure (three cases)

5. **F summaries are not earned proof.** `pv-ledgers.json` remains `admission=UNSUPPORTED_SUMMARIES_NOT_DURABLE_PROVENANCE`. First-valid P_0 is seed **5421603** death (`unlocks` includes `card:resonantLance`; vigil deeds.shatters=41 cumulative). Sequence vigil `recovery/acquire2/dd1_pv_vigil_5421603_v2.json` SHA-256 `25d4da7617c91edbfa1d35163e43248f894ec4a9a768a983e9c5887006f08c7f` (`runId=run-0052ba23-1a0b0a3c9df`). Pre-terminal run bytes were cleared by `_on_terminal_commit`; charged same-seed replay from predecessor 5421602 recovered `p0-first-valid-run-v2.json` SHA-256 `54aaaa92a419e30c80ea4278eddc58be0d15470e8b3095e395daa8c3a21e62f5` (9961 bytes, `runId=run-0052ba23-1a0b0a5881f`) and matching replay vigil `p0-first-valid-vigil-v2.json` SHA-256 `7f5608a257046d66b6f678c7d8d47daa4aced97bd6a51cf502a72551a9195e27`. Unlock sets match. P_5 was not earned: after the 5421600 win (`vow_unlocked=1`) every remaining exposed root died at vow 1. Named absence: no `p5-first-valid-*.json`. Gate: missing P_5 is BLOCKED, not PASS.
6. **Missing P_5 is BLOCKED.** N0 acceptance path `evaluate_n0_witness` ACCEPTS a genuine supplied witness and BLOCKED/REJECTs absence. Ordinary regression no longer asserts that canonical files must remain absent.
7. **Campaign helper.** `dd1_native_driver_main.gd` skips WorldMapScreen/CombatScreen presentation only. Map `enter` precedes `_on_node_chosen`. Each completed combat dispatches `Main._on_combat_over` once. Turn/step cap is INCOMPLETE. Launch is receipt-validated (bodies/operation/identities/reservations/expiry); file existence and env vars are not permission.

### Pending compatibility (two cases)

8. **F `m-pending-run-v2.json` remains constructed history.**
9. **Ordinary-route pending.** Unchanged M seed **5420099**: 63 map nodes, `pendingCombat=monster`, three sporelings, 8316 bytes, SHA-256 `5b778ab57008761c14bf9ec52bc790df6135cee9b40b5e1b4eef36fc5450c6f7`. Overlay `Main._continue_run` resume PASS (matrix `native_starts=15` including that resume). Marker absent pre- and post-resume.

## Account (dual)

Historical **1277 / 8192 remaining 6915** listed-event arithmetic — **not spendable**. Attempt 1/1. CPU/elapsed **UNKNOWN**. ALLOCATION `824ff18a` untouched.

Recovery DD1-N0-RECOVERY-1: first engine launch **2026-09-17T17:54:40Z**, deadline **2026-09-24T17:54:40Z**. Starts **1786 / 2048** remaining **262**. Process-tree CPU **380532833995 ns** (~0.1057 h of 4 h). Raw **882381** bytes of 1 GiB. One executor. Failures remain charged. No 6915 spend, no top-up. Identities: `recovery/ACCOUNT.json`, `recovery/LAUNCH-RECEIPT.json`, `recovery/BYTE-IDENTITIES.json`.

## Residuals

- P_5 not earned in 5421600–5421615; N0 stays BLOCKED.
- Live replace/expiry, overlay card art, Crosscut clipping, extraction/guardrail receipts unchanged downstream.
- N1/N2 / 2048-run D547-NATIVE-EXPORT-2 not opened.
- Certificates **0/3**. Isolated N0 review is not commissioned by this author batch.
