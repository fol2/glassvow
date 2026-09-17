# DD1-NATIVE-1 remaining account — established before new native calls

Recorded 2026-09-17 by the sole local author batch for #542/5706552165.
No Godot/live/shot/profile process launched while writing this file.

## Pins (unchanged)

- M `07b5aa9dec8436132a524511d5438c510e322070`
- E start `94a5297376325f12f2f1e6264ec7cfed2e8c5a12` tree `4074da7ab5c4b1180a2df01eb5ec4fead80dac71`
- D `746388323b8e886967e0e13fe109490a70206a66` PROMOTION `ba9fc8004f385958b064598b6fa54dc9634cf577`
- C `cf27285a3103d8867a179f700c5ebf32661453d5` NATIVE-HANDOFF `df007ee4a1032e57f3bcd90de98a6c0c1dca8fe2`
- H `5b6b3a718b8c6200d12d5c06c85702ea9a0f35c6` ALLOCATION `824ff18acbca2f776533beed83a43b21d9a50f2c`
- O `d8f4dde0905db7156008a53173e3851768448b8d`
- M RunState `95b6bbb10c5fd8ab2c6fdc79c61440f9959998eb` (identical on E)
- Engine present: `4.7.2.stable.official.ed1daf0bf`
- Attempt 1/1 consumed (not reset)
- Certificates 0/3

## Listed-event start arithmetic (unchanged unless this batch charges)

`90 + 1 headed + 132 (44×3) + 3 prior shots + 2 catalog + 1 catalog shot + 1 constructed + 1 live = 231 used / 8192 / 7961 remainder`

H epoch ceilings from CANDIDATE_PREFLIGHT (bound H SPEC): cpu 64h = 230400s; active elapsed 48h = 172800s; raw 64 GiB; executors 2; per-invocation CPU 300s.

## Per-invocation identities (do not attach E to earlier runs)

| id | contemporaneous commit | combat.gd | test_dd1_native_overlay.gd | reader | content | starts |
|---|---|---|---|---|---|---|
| INV-1..3, HEADED-1 | O `d8f4dde0` | `8110f15e` | `baaeff7b` | `799af6eb` | `81aa6473` | 30+30+30+1 |
| INV-4..6 | repair `ab74e33b` (not E) | `8353b395` | `3cc6bdbc` | `3b276cc6` | `81aa6473` | 44+44+44 |
| CAT-1/2, SHOT-4/5, LIVE-1 | catalog `6d440683` / evidence `452d080d` | `8353b395` | `3cc6bdbc` | `3b276cc6` | `81aa6473` | 1+1+1+1+1 |

Catalog test blob at catalog commit: `f8e598f5`. E readback `94a52973` did not change those runtime blobs.

CANDIDATE_PREFLIGHT `exact_pre_next_invocation` still pins O. That freeze is **stale for any post-O debit** and will be replaced with a coherent pre-invocation manifest **immediately before** the next launch, bound to the then-current commit/tree or base+dirty blobs.

## CPU / elapsed / raw

- CPU seconds: **UNKNOWN** (no process accounting on historical events).
- Conservative upper bound on historical CPU: 16 charged invocations × H per-invocation ceiling 300s = **4800s**. Remaining CPU ≥ 230400 − 4800 = **225600s**. This is a contractual ceiling bound, not a measurement.
- Active elapsed: **UNKNOWN**. Same conservative 4800s << 172800s.
- Raw: measured published qualification logs/png/json/md/txt = **8912856 bytes** (~8.5 MiB). Additional unretained stderr/import: **UNKNOWN**. Conservative extra 64 MiB still << 64 GiB.

Historical UNKNOWN is retained, not credited as zero.

## Remaining authority for this batch

Listed-event remainder **6915** (EVENT_LEDGER used 1277 / cap 8192) is **not independently spendable authority**. The **7961** figure above is a pre-batch snapshot and is stale. cpu_seconds and active_elapsed_seconds remain **UNKNOWN**. The 7200s conservative bound is 24 listed events × H’s 300s ceiling, not measured containment.

Author batch **5715191434** launched **0** native/engine/capture/profile processes. Original 8-seed selection failed P_5; the 8-to-16 extension is charged history, not a ratified first-valid proof or a new cohort. No top-up, refund, or #548 borrow.

Executors observed historically: 1.

## Stop

If a named invocation cannot bind commit/tree, test/reader/content, engine, command, and input/seed, do not launch it. Do not launch while cpu/elapsed remain UNKNOWN and the original selection/stop cannot be established.
