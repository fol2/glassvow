# Floor-device profile protocol — wayfinder #172 / RC bar P2

Authority for running the iOS performance floor on the named devices. The
gates themselves live in the
[Performance floor](https://github.com/fol2/glassvow/issues/158) resolution
and `docs/rc-bar.md` P2; this file is the executable route, not a restatement
of the numbers.

**This Cloud / Linux checkout cannot produce the packet.** Evidence is a
release iOS binary on the Mac mini, tethered to the iPhone SE 2 (`iPhone12,8`)
and iPad 8 (`iPad11,6`) inventoried on
[Buy or borrow the physical performance-floor device matrix](https://github.com/fol2/glassvow/issues/171).

Android stays deferred with the Android phase.

## What is measured

One **route** process per device × locale (`en`, `zh-Hant`), then one **save**
process on the same save:

| Leg | Flag | Workload |
|---|---|---|
| Route | `--floor-profile --locale=…` | Live `WorldMapScreen` pan (worst visible map motion, including the act plate) then act-1 Leviathan with 96 VFX, soaked `--soak-seconds` (default 1800). |
| Save | `--floor-profile --leg=save --locale=…` plus `--resume` | Cold `--resume` to interactive. The P2 Continue-tap ≤2 s row is the same save, timed by stopwatch on the title Continue control — `--resume` is the scripted proxy, not a substitute for that HITL tap. |

Default seed 717, act 1, fight `leviathan`. Do not pass `--shape=` or `--vp=`
on device: the live window is the evidence, and iPad 8 flexes to 1180×885.

Report the two devices separately. iPad 8 native fill is ~3.75× the SE 2;
an SE 2 pass is not an iPad 8 pass ([comment on #172](https://github.com/fol2/glassvow/issues/172#issuecomment-5288343569)).

## Build

Release engine slice, development-signed twin (container access). Not
`--export-debug`, not the App Store `method = app-store-connect` IPA. Recipe:
`docs/release-signing.md` › “iOS build on a tethered device”. After Godot
export, set Info.plist `godot_cmdline` (the exporter overwrites it every
time) and rebuild:

```
["--log-file","user://bench.log","--","--floor-profile","--locale=en","--perf-commit=<40-char sha>"]
```

Save leg: add `--leg=save`. Pull `Documents/floor_profile.json` and
`Documents/floor_profile.txt` with `devicectl device copy from` (`user://`
maps to `Documents/`). `print()` does not reach `--console`.

Conditions, both devices, both legs: unplugged, 50% brightness, controlled
room temperature, Reduce Motion off, a release build, landscape
(`sensor_landscape`). Cold route first; heat-soaked 30-minute route second.
Repeat the route once more for retained-growth. Charging runs are invalid.

## In-engine gates (the JSON)

`pacing_ok` / `sustained.ok` / `save_ok` are scored against the #158
numbers. `sustained_scored` is false unless combat ran ≥10 minutes (first
and last five). Renderer allocation is reported; it is not the jetsam
figure.

## Instruments (HITL — not in the JSON)

iOS Game Performance + Power Profiler on the 30-minute route:

1. Thermal state must never reach `serious` or `critical`. Keep the trace.
2. Battery: ≤10 percentage points; start/end levels; health ≥80% where
   Settings exposes it (SE 2). iPad 8 does not expose health; say so.
3. Memory: `phys_footprint` peak and post-route; no jetsam; no monotonic
   retained growth across the two consecutive route runs.

GPU timer reads 0 on A12 Metal; whole-frame interval is the pacing
instrument. iOS does not honour `VSYNC_DISABLED` (#233).

## Pass / fail

A miss on one named floor device does not weaken the floor. It files
measured optimisation work. A renderer, fidelity, frame-rate, or supported-
device change returns to map #156 as a new decision.

Short Mac rehearsals (`--soak-seconds=30 --map-seconds=5`) are plumbing, not
evidence.
