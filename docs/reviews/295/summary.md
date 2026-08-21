# #295 iOS map-budget closeout

Measured tree `3d5bc33bb0886d1d18673e9d1310d1c17a37fe75` is byte-for-byte
identical to canonical merge `a28e02588a40e82b55cea93205a0641bb6f61b22`.
Godot was `4.7.2.stable.official.ed1daf0bf`; Xcode was 26.6 (17F113).

## Verdict

| Lane | Result | Guardrail | Verdict |
|---|---:|---:|---|
| Source GLB, all acts | 0.831 MiB | 7.31 MiB | pass |
| Source GLB, largest active act | 0.427 MiB | 2.25 MiB | pass |
| Conservative RGBA8+mips texture plan, all acts | 2.667 MiB | 11.31 MiB | pass |
| Conservative RGBA8+mips texture plan, active act | 0.667 MiB | 2.83 MiB | pass |
| Attributed `.godot/imported` cache | 2.149 MiB | reported separately | measured |
| Signed App Store IPA delta | 1.024 MiB | target <=16 MiB; reopen >18.7 MiB | pass |
| Attributed active renderer allocation | 0.609-0.922 MiB | 2.83 MiB active texture ceiling | pass |
| Prior-act strong references after 32 device samples | 0 | only one act | pass |
| iPad 8 pan workload, `en` / `zh-Hant` | 12 refresh-floor, 0 MISS each | #158 / #233 | pass |

The signed A/B exports used the same tree, Store preset, Xcode, bundle identity,
distribution certificate class and App Store profile. The baseline removed only
the 12 GLBs, four PNGs and their import sidecars under `assets/art/map/`.

The iPhone SE 2 physical footprint ranged 156.830-177.439 MiB; the iPad 8
ranged 223.392-233.361 MiB during four complete act cycles. These are Apple
Activity Monitor `phys_footprint` readings, not renderer allocation. An
assetless SE 2 twin ranged 164.205-175.048 MiB, so the overlapping distributions
do not show a process-footprint regression attributable to the map payload.

On iPad 8 the completed pan matrix ran five repeats of 180 measured frames for
each of 12 configurations in both locales. P50/P90/P95/P99/max rounded to
16.667 ms, missed deadlines were 0%, and every row was correctly classified as
a 60 Hz presentation floor. A separate Game Performance trace covered cold
entry, 16 actual-asset act switches and the ensuing static freeze: no interval
exceeded 25 ms and Instruments reported no potential hang.

The four units remain separate throughout. No map-specific optimisation ticket
is required, and the completed asset library does not invalidate #233.
