# DD1-NATIVE-1 N0 after 5706552165 (findings 1–4)

Same candidate. Attempt 1/1 not reset. D/C/H/ALLOCATION unchanged. Certificates **0/3**.

Coherent PASS pair at `92da314c066b84fc565c428cbbda03375ef03481` (evidence commit follows). Two identical `PASS (2 tests)` logs, blob `d722fd0d88f6f84f6a0a58cbde0e55d99fd41f6a`, `native_starts=201` + `45`.

## Four-finding map

1. **Bytes are the sole resolution root.** `DuskNativeExportReader.decoded_payload` parses `bytes`, checks digest, normalizes JSON keys, rejects companion divergence. Role lives in the payload. Controls: intact roundtrip; companion mutation fails; digest mismatch fails; malformed/wrong-role/wrong-path fail; restore succeeds. Published `reader-capture-bytes.json`.
2. **Per-invocation identities.** INV-1..3 / headed pin O combat `8110f15e` / test `baaeff7b`. INV-4..6 pin repair `ab74e33b` combat `8353b395` / test `3cc6bdbc`. INV-10/11 pin `92da314` combat `4288f589` / overlay test `1daa3f8f` / matrix `0f1c2dd0` / reader `6c08fc23`. E was not attached to earlier runs.
3. **P_v earned.** Ordinary `VigilState.blank` → legal campaigns → `commit_run`. First-valid P_0 seed `5421601` (paneBreaker / `card:resonantLance`, 31 shatters). P_5 seed `5421609`, `vowUnlocked=5`. See `pv-ledgers.json`. Not a constructed `_fight` hand.
4. **PROMOTION §3 rows mapped.** K1 paid chain vows {0,5}; joint shatter mask; upgrades; Adamant hold then shatter; Prism extra embers; Smolder jump + RNG cursor; Reaper DRAW/energy/hand; return-Thorns; Main abandon; unmodified M pending via SaveService (`m-pending-run-v2.json`, M emit head `07b5aa9d`). Catalog log abbreviation corrected to actual PASS-pair blob below.

## Account

Used **1277 / 8192**, remaining **6915**. Attempt 1/1. CPU/elapsed **UNKNOWN**; conservative bound 7200s under epoch 64h/48h. ALLOCATION `824ff18a` untouched.

## Residuals (downstream, not new N0 blockers)

- Live replace/expiry not restaged (unit + existing PNGs).
- Overlay card art absent (bare-pane catalog PNG).
- Extraction/guardrail receipts absent, not manufactured.
- N1/N2 / 2048-run D547-NATIVE-EXPORT-2 not opened.

**0/3 certificates.** Handoff is for isolated review of the **new** head, not author self-approval.
