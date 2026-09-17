# DD1-NATIVE-1 after 5715191434 (review 5712464645)

Same candidate. Attempt 1/1 not reset. D/C/H/ALLOCATION unchanged. Certificates **0/3**.
N0 result: **BLOCKED / not complete**. This is not author self-approval.

Parent F `3993b3f0a98ef436ed144ba800e7e031583baa0a`. This file is the nine-bullet response map for the sole-local-author correction. Native/engine/capture/profile processes were **not** launched: original 8-seed P_5 fail is unratified as 16-seed proof; cpu/elapsed UNKNOWN.

## Nine-bullet response map

### Reader (four cases) — repaired source; runtime unverified (Godot blocked)

1. **Required digest.** `decoded_payload` rejects missing, non-string, empty, or mismatching digest **before** parse/observations. Self-hash is integrity, not issuer authentication. Retained capture `reader-capture-bytes.json` blob `93326afd7b993d70d6977d66b9f4b7cd6134d497` (inner SHA-256 `c9a8cd7d…`) is the mutate/restore input. Tests no longer rewrite that file.
2. **Non-dictionary event.** `_normalize_payload` rejects the whole capture when any events entry is not a dictionary. No drop/reindex. Control: insert a non-object before the retained hit at ordinal 2, recompute digest, require null, restore.
3. **Integer fields.** `exact_int` accepts an int or a finite float exactly equal to that integer. `1.9` is not `1`; booleans and numeric strings reject. Only object-index **keys** get string-to-index normalization (`"0"`). Key collisions reject rather than merge. Opaque non-integer fields stay opaque. `_same` compares numbers without truncation.
4. **play_observations.** Returns `null` on a malformed capture (not `[]`). A well-formed capture with no play events returns a successful empty Array. Callers must not treat invalid as zero events. Missing-HP still rejects; amount/overkill/physical-HP distinction stays.

### P_v / procedure (three cases) — source repaired; acquisition BLOCKED

5. **F summaries are not earned proof.** `pv-ledgers.json` p0/p5/traces are retained charged history. `admission=UNSUPPORTED_SUMMARIES_NOT_DURABLE_PROVENANCE`. Durable first-valid P_0/P_5 run/Vigil bytes, ordered commands, and commit receipts are absent and were not invented.
6. **Missing P_5 is BLOCKED, not print-then-PASS.** `n0_result=BLOCKED` with `blocked_prerequisite` naming the original 8-seed cap fail, unratified 16-seed extension, and UNKNOWN cpu/elapsed. Routine matrix no longer prints then PASSes. The 8-to-16 seed loop is removed from ordinary regression.
7. **Campaign helper replaced.** `_legal_campaign` (act==2 win, 30-turn abort labelled death, direct `commit_run`) is gone. `tests/support/dd1_native_main_route.gd` drives Main `_new_run` / `_on_node_chosen` / `_prepare_encounter` / `_on_combat_over` / `_on_terminal_commit`. A turn cap is INCOMPLETE, not death. Acquisition runs only when `DD1_NATIVE_ACQUIRE=1` **and** `LAUNCH-PERMITTED.json` exists. Routine regression is read-only and does not write `pv-ledgers.json`.

### Pending compatibility (two cases) — constructed history kept; ordinary-route BLOCKED

8. **F `m-pending-run-v2.json` is constructed history**, not an ordinary-route witness (empty map, injected sporelings, `runId=m-pending-5420099`). Bytes retained. Overlay `_r3_overkill_and_m_fixture` remains the structural injected-fixture check.
9. **Application resume path.** Constructed bytes copy unmodified through SaveService then `Main._continue_run` → `_resume_pending_combat` (not a lone `startCombat`). A real unchanged-M map-route pending (`m-pending-ordinary-run-v2.json`) is absent; capture is BLOCKED by the same native-launch prerequisite. K1 paid-chain / joint mask / upgrades / Adamant / Prism / Smolder / Reaper / return-Thorns remain source-present.

## Account

Used **1277 / 8192**, remaining **6915** listed-event arithmetic — **not independently spendable**. Attempt 1/1. CPU/elapsed **UNKNOWN**. This author batch launched **0** native processes. ALLOCATION `824ff18a` untouched.

## Residuals (unchanged downstream)

- Live replace/expiry not restaged.
- Overlay card art absent; Crosscut body still clips.
- Extraction/guardrail receipts absent, not manufactured.
- N1/N2 / 2048-run D547-NATIVE-EXPORT-2 not opened.
- INV-9 `native-overlay-only.log` still missing.

**0/3 certificates.** Isolated review of a later head is not commissioned while P_v/account/procedure remain BLOCKED.
