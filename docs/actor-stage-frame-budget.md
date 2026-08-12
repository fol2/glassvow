# Actor-stage performance evidence

## Current exported-combat matrix — issue #105

The release evidence is the real exported `Main -> CombatScreen` route, not the
component probe below. The immutable evidence is commit
[`1ce1ce8915b33ae1914714a6b2c40af89fb6ac22`](https://github.com/fol2/glassvow/blob/1ce1ce8915b33ae1914714a6b2c40af89fb6ac22/manifest.md),
with every row in its
[`binding/summary.json`](https://github.com/fol2/glassvow/blob/1ce1ce8915b33ae1914714a6b2c40af89fb6ac22/binding/summary.json).
It binds measurement source `cf1b3d51af2992e1db8a419a49ff6254d6147581`
and verifier `5fb7d95a0bfa75953d184e172c3cd4a7d91d7786`.

**Named target:** Mac mini `Mac16,10`, Apple M4, 16 GiB unified memory;
macOS 26.6.1 (25G76); official Godot 4.7.1, native `arm64`; Forward Mobile.

**Recorded workload:** act-1 Leviathan boss, seed 717, settled full HUD, hand and
intents, with exactly 96 non-weather VFX particles sustained through each
sample. The matrix is five authored shapes × `en`/`zh-Hant` × five fresh
processes: 50 rows.

| Metric | Proposed P8.1 gate | Maximum observed | Matrix result |
|---|---:|---:|---|
| renderer allocation peak | ≤1228.8 MiB | **543.640625 MiB** | clears proposal |
| macOS process physical-footprint peak | ≤1536 MiB | **1056.204544 MiB** | clears proposal |
| observed whole-frame p95 | ≤16.00 ms in every row | **9.578 ms** | clears proposal |

These thresholds are submitted for James's owner decision on PR #143. They
become the P8.1 gate only if and when he approves that exact final PR head; a
verifier `pass` shows only that the evidence clears the proposed numbers. PR
#143 is the decision of record.

Metric boundaries are binding:

- Renderer allocation is Godot's `Performance.RENDER_VIDEO_MEM_USED`, not total
  physical VRAM. On Apple unified memory it must not be added to process
  footprint.
- Physical footprint is macOS `footprint`'s
  `auxiliary.phys_footprint_peak`, not RSS.
- Observed-frame p95 is an unsynchronised whole-frame interval, not a Metal GPU
  timer. GPU time was unavailable on Metal; Godot's zero does not mean free GPU
  work.
- #105 did not measure the standing cold save-load ≤2-second target. #108
  remeasures it at the release-candidate gate.
- The result clears only the named Mac proposal. It is not phone or Steam Deck
  evidence.

## Current actor-stage component diagnostic

The immutable tree also retains five serial exact-verifier-head component runs:

```sh
godot --path . -s res://tools/bench_actor_stage.gd -- --actors=1,4,6,29
```

| actors | renderer allocation, approximate | cadence evidence |
|---:|---:|---|
| 1 | 86.8 MiB | mostly pinned to 8.33 ms presentation floor |
| 4 | 227.8 MiB | mostly pinned to 8.33 ms presentation floor |
| 6 | 380.1 MiB | mostly pinned to 8.33 ms presentation floor |
| 29 | 2532.3 MiB | p95 11.67–14.29 ms across five runs |

One `--textures` run measured all 140 source textures resident as an additional
885.0 MiB: cards 702.1, enemies 87.0, stage 48.0, UI 25.1 and statuses
22.8 MiB. This ladder isolates scaling and texture residency; it is a component
diagnostic, not release clearance. Its raw logs retain the old `vram MB` label,
but the value is renderer-reported allocation under the definition above.

## Historical component appendix — M1 Max probe and tuning rationale

The remainder records the 2026-07-26 Apple M1 Max probe and the visual decisions
it informed. Its old 2.5× numbers are not the current exported matrix, are not a
target-device gate, and carry no pass/fail status. The component tool's
`wall ms` was quantised by presentation: exact 5.56 or 8.33 ms rows sat on a
presentation floor, while GPU timing was unavailable on Metal.

### Historical as-authored ladder — MSAA 4×, `oversample` 2.5

| actors | stage Mpx | wall ms | draw | renderer allocation |
|---:|---:|---:|---:|---:|
| 1 | 0.2 | *floored* | 5 | 71.5 MiB |
| 3 | 2.8 | *floored* | 15 | 249.4 MiB |
| 4 | 3.6 | *floored* | 20 | 310.2 MiB |
| 6 | 6.6 | *floored* | 30 | 509.5 MiB |
| 12 | 16.9 | *floored* | 56 | 1168.4 MiB |
| 29 | 47.8 | 9.52 | 134 | 3062.5 MiB |
| 60 | 109.2 | 24.68 | 261 | 6723.5 MiB |

The old probe suggested approximately 0.247 ms per stage megapixel above its
floor and roughly linear renderer allocation. Those extrapolations were useful
for choosing what to inspect, but they are not substitutes for the current
whole-frame matrix.

### Historical tuning prices

These were visual choices, not backend-independent laws. The project waited for
a real battlefield before judging aliasing and resampling detail.

**MSAA, four actors at the old 2.5× profile:**

| MSAA | renderer allocation | change |
|---|---:|---:|
| 4× | 310.2 MiB | — |
| 2× | 245.3 MiB | −21% |
| off | 180.8 MiB | −42% |

**Oversample, four actors with MSAA 4×:**

| oversample | stage Mpx | renderer allocation | change |
|---|---:|---:|---:|
| 2.5 | 3.6 | 310.2 MiB | — |
| 2.0 | 2.3 | 248.4 MiB | −20% |
| 1.5 | 1.3 | 198.2 MiB | −36% |
| 1.0 | 0.6 | 162.2 MiB | −48% |

The lab decision was `oversample` 2.0 with MSAA 4×. MSAA 2× broke the continuous
lit edge into a dim line; `oversample` 1.5 softened paintings, leaded seams and
teeth. Keeping MSAA retained the sub-pixel glass highlight while the smaller
oversample accepted coarser, still-lit edges.

### Historical texture rationale

The old `--textures` pass measured 140 lossless imports at 884.8 MiB of renderer
allocation: cards 688.9, enemies 100.0, stage 48.0, UI 25.1 and statuses
22.8 MiB. That made texture compression worth investigating, but not a free
change: narrow gradients carry the holo and pearlescent surfaces, and cards and
enemies had no mip chain. Residency also grows over a run as Godot caches art.
The current exact-head component receipt above supersedes the old totals.

### Reward-room component note

The 2026-08-01 component probe measured one reward stage at 127.4 MiB of
renderer allocation. It was a full logical-canvas viewport at `oversample` 1.5,
not a per-actor art box. If reward ever stands over live combat, combat
viewports must be freed or set to `UPDATE_DISABLED`. This remains useful
lifetime guidance, but the isolated old reading is not an independent release
threshold and was not the #105 exported-combat workload.

### Unmeasured component questions

Sharing one `World3D` across actors was not attempted. Each stage owns a `Sky`
feeding ambient light and reflections, so collapsing those worlds is a refactor,
not a tuning knob. GPU time also remains unavailable on the measured Metal path.
