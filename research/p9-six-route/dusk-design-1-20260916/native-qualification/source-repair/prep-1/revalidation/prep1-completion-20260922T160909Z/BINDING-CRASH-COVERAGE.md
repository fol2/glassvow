# PREP-1 binding/crash coverage — new byte and predicate verification

Authority #542/5779715600. Verification run `prep1-completion-20260922T160909Z`; actual execution remains `prep1-revalidation-20260921T211017Z`. Implementation I=`d4e91e4fc70d57c81922cc1883b339877d835a53`. This is readback verification, not reexecution, independent approval, native evidence or recovery of the missing original run.

## Actual complete inputs and decoding

At E=`e3ad0548747865af914c8c8b4a5fb48c6e3274db`, sibling `../prep1-revalidation-20260921T211017Z/pre-release-bindings.json` has Git blob `4604797212f5b134607f598ed4fec0b56994252a`, 10,674 bytes. Its strict base64 decoded to 7,056 XZ bytes, SHA256 `07077407974f7c28eeb5174ad75ee8bad2c77934772387f429434d4a91b809e0`; decompression yielded 164,503 bytes, SHA256 `fe6904f5c51a79dcf8b497bddcc05901777df538737dd0bf105d1c401f7d74b6`.

Sibling `crash-exclusivity.json` has Git blob `731dc7a0ef3fa6b49e2b535d3f856156367fe2b0`, 10,062 bytes. Its strict base64 decoded to 6,776 XZ bytes, SHA256 `14ca459e003250bd145316ad68530ce0f51c92f5cbce4c2eff716771258dcf27`; decompression yielded 47,378 bytes, SHA256 `becdc773845c122eb08f7b8170c598f9c313b8d218eb135124a6ce5d4af09c95`.

Both complete wrappers were materialized from actual retrieved lines and independently matched their Git blob identities, not only declared hashes. The reader checked compressed/decoded lengths and hashes, bounded XZ end-of-stream with no unused bytes, duplicate JSON keys, relative record paths, run identity, descriptor decoding and every restored original record length/SHA256. No archive member or decoded code was executed. Restored JSON uses sorted keys, compact separators, allow_nan=false and a final LF, exactly as the transport declares.

Verification executed 2026-09-22T16:16:20.318774+00:00 to 16:16:20.351567+00:00, exit 0. Reader SHA256 `eb5260206266d6d940b3a37fea57e55e44f43fcebe8af1bd38da309a0dd53978`. Measured reader-only wall 0.034739255 s, user CPU 0.021578 s, system CPU 0.011426 s. Retrieval/materialization/analysis are outside those narrow measurements; no ledger credit. Exact reader and structured results are retained for the consolidated verifier unit.

## Coverage of actual raw records

Each locator is `records/<case>` in the named decoded bundle. Each binding/concurrent record retains the full argv, unit/demand, source/runtime/helper manifests, input receipt, before-account bytes, after account, exit/stdout/stderr and empty captured-file inventory.

| Case | Restored bytes | Restored SHA256 | Reached guard / outcome |
|---|---:|---|---|
| binding-asset-sha | 13887 | 3c1a47e0490ca06dbe84a3a128b0b91ba4b03d7635c31a9bda2f5ec7bf04d723 | seed asset identity |
| binding-engine | 13886 | b6122ee97c7a57121e35e517f04bf17e12108e5236b039b9942518eacbcd9fc3 | preparation engine lineage |
| binding-execution-map | 13945 | f281370687f8df223e8f9038061c8e9f95c4b4b6a460a8440d9634173c06b3cc | wrong bound preparation execution view |
| binding-execution-view | 13960 | 3182651ee9b36a12b40a6aeb9b1d37ed5ee0068e7cf6766ed56c1f69f72e09e8 | wrong original/derived/runtime view binding |
| binding-producer | 13902 | ea13edd18eee602187d56dfe4111218ccd2cde7d47588fb15d018ca9ec4d4efe | wrong producer/recipe binding |
| binding-recipe-head | 13911 | 311e20a12801d0bd6111973926a3958afdb8f5e70b835bbe663c6a733502e110 | preparation source lineage |
| binding-seed-blob | 13919 | d502cca86b29a8f14990e11e5dadded5746b34bb29e48036584878e0cc8a1f73 | wrong tracked sidecar seed identity |
| binding-seed-path | 13917 | f2cbf9812ed32f771b352ed9f5048cbbdeee2908d9904cb89a52f316fb51d26e | not a generated import/UID/cache slot |
| binding-seed-sha | 13914 | ad64fbc194d94924ae94317fd293396c4df7f65e1beefaa422101acead306914 | wrong tracked sidecar seed identity |
| binding-traversal | 13885 | b17bec317e19a8b9a4ab1a92c880c4c54a5f2f303924ea6f3d5f300f4e4b3908 | invalid generated path |
| binding-undeclared-dependency | 14009 | cb804496c5ccb308db76e7c74af4faf3a64d1a98a3743af93e85a669359cce16 | sidecar dependency outside declared generated inventory |
| binding-unpriced-copies | 13966 | 9adbd40256655458912c4efbb6449a03b0335e71e09b1c990cb757082d73e975 | raw cannot fit immutable inputs and workload |
| concurrent-controller | 16067 | ca35ff3fa987528e23ec014f956211bb0660af98a88012577b16c88b19a4c5a0 | one executor already holds account |
| concurrent-supervisor | 16067 | 63883e2a229032845eff7a6f93694138ce52139954fcab34dae0e54d4dbfbfc9 | one executor already holds account |
| kill-controller | 2844 | e83e22f30eea0b209dafd0ebc46e04ccb88fcb944a23334f26735fb8ea77144d | killed controller; full reservation retained |
| kill-supervisor | 13211 | 59dac4e0005a18a7167fddc73a4a0a0d2c4c0aedec0aac59304aa6f89ec2f29f | supervisor killed; FAILED, no seal, cleanup |

All fourteen pre-release records have exit 2, exact expected ReservationError, parsed stdout equal to result, empty stderr/files, byte-identical before/after synthetic account and no new reservation. Existing input receipts are not native launch receipts. Source `tools/dd1_linux/prep_controls.py` at I, blob `056bc1c7608bbca4b0268643066997c8d1363ed7`, lines 218–241 generates the twelve binding mutations; lines 293–321 waits for the actual blocked producer point, attempts concurrent entry, kills and checks cleanup. Matrix.run at lines 145–175 establishes account/guard capture semantics. Source pins were read, not executed here.

## Kill lineage and scope

Original execution boot is `d0864e9f-3592-4f03-9800-01af9ddfb74b`. Kill-controller identities are controller 825/start145334, supervisor 826/start145342 and workload 827/start145342. Controller exit is -9; supervisor/workload were adopted with status 9. Before-kill and after account bytes encode identically; state remains RESERVED. Kill-supervisor identities are controller830/start145355, supervisor831/start145368 and workload832/start145368. Its final row is FAILED with success=false, cleanup_confirmed=true and sealed_preparation=null. Both original records report remaining_pids=[].

Both retain one start, 16,000,000,000 CPU ns and 12,582,912 raw bytes. These are synthetic reserved envelopes, not measured cost or live-account spend. No killed-controller final result is invented; post-matrix supporting observations remain to be linked in consolidated coverage. No present /proc test was used to reinterpret another boot's cleanup. No execution is missing merely because a deliberately killed controller cannot emit a terminal record.

This is a completed 16-case coverage checkpoint, not the whole batch endpoint. Positive/seal/runtime, semantic/mutation and same-run source/build/post-capture coverage follow separately. N0 BLOCKED; certificates 0/3; source and both real accounts unchanged.
