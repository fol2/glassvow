# The per-actor 3D stage, measured

`docs/actor-animation-checklist.md` §5.4 flagged the per-actor `SubViewport` as
unmeasured against `docs/commercial-game-delivery.md` §5. This is the
measurement. It exists because the checklist's PORT items are almost all
*additional per-frame work* layered on this floor — building them against an
unmeasured budget risks approving a list the frame cannot hold.

Tool: `tools/bench_actor_stage.gd`. Rerun with

```bash
godot --path . -s res://tools/bench_actor_stage.gd -- --actors=1,4,6,29
```

Measured 2026-07-26 on an **Apple M1 Max**, Metal 4.0, Forward Mobile
(`rendering_method="mobile"` is already the project setting). Tree at `1fe27ca`
plus the Enemy lane's uncommitted chip integration — which does not touch stage
construction, so it does not move these figures.

## What each column is worth

**`vram MB` and `draw calls` are backend-independent** and are the trustworthy
numbers on any machine.

**`GPU ms` reads 0 on every row.** Godot's Metal backend does not implement GPU
timestamp queries. The column is *unmeasured*, not free.

**`wall ms` is quantised by presentation.** Rows landing on exactly 5.56 or 8.33
ms are sitting on 1/180 and 1/120 — they mean "below the floor", not "this is the
cost". Only rows above ~9 ms carry information. A first pass reported the whole
ladder as 5.56 ms and would have been read as "everything is free"; the ladder
was extended to 60 actors precisely to get above that floor.

## As authored — MSAA 4x, `oversample` 2.5

| actors | stage Mpx | wall ms | draw | **vram MB** |
|---:|---:|---:|---:|---:|
| 1 | 0.2 | *floored* | 5 | 71.5 |
| 3 | 2.8 | *floored* | 15 | 249.4 |
| 4 | 3.6 | *floored* | 20 | 310.2 |
| 6 | 6.6 | *floored* | 30 | 509.5 |
| 12 | 16.9 | *floored* | 56 | 1168.4 |
| 29 | 47.8 | 9.52 | 134 | 3062.5 |
| 60 | 109.2 | 24.68 | 261 | 6723.5 |

## Proposed memory budget for `commercial-game-delivery.md` §5

§5 currently reads *"Memory: run state + UI ≤X MB (device-specific; clarify at
gate)"*. X was never filled in, so nothing here can be called a pass or a fail.
Proposed replacement, derived from the target devices §5 already names — **not**
derived from the measurements above, so that the budget is a standard rather
than a description of the status quo:

> **Memory (floor device — a 4 GB phone, 2021):** total process ≤**1.0 GB**.
> Of that, video memory ≤**550 MB**, split ≤**200 MB** actor stages and
> ≤**350 MB** textures. Steam Deck's default UMA frame buffer is 1 GB, so the
> video figure is the binding one on both targets.

Where each number comes from:

- **1.0 GB process.** iOS jetsam terminates a foreground app on a 4 GB device
  well before 2 GB; Android's low-memory killer gets aggressive above ~1 GB RSS
  for a foreground app with others cached. The tighter of the two is the floor.
- **550 MB video.** Engine, scripts, audio, and game state take 250–350 MB of
  the process before any render resource.
- **200 / 350 split.** The stages are the render targets; the textures are the
  art. Roughly two-thirds to the art matches where the pixels actually are.

Measured against that proposal, on this desktop:

| item | measured | proposed | |
|---|---:|---:|---|
| actor stages, 4-actor fight | 310 MB | ≤200 MB | **over by 55%** |
| actor stages at MSAA 2x + `oversample` 1.5 | 175 MB | ≤200 MB | fits |
| all textures resident | 885 MB | ≤350 MB | **over by 153%** |
| textures at ASTC 4×4 (estimated) | ~220 MB | ≤350 MB | fits |

So the proposed budget is not decorative: **the project fails it today on both
lines, and passes both with changes that are already priced.** That is the point
of setting a number.

## Verdict: frame time is not the constraint. Memory is.

**Frame time passes, with room.** The two unfloored rows give 0.247 ms per stage
megapixel (9.52 ms at 47.8 Mpx → 24.68 ms at 109.2 Mpx). A real fight — hero plus
three foes, 3.6 Mpx — therefore costs about **0.9 ms of the 16 ms budget**. The
16 ms line is not reached until roughly 65 Mpx, near 38 actors. §5.4's concern,
*as a frame-time concern*, does not reproduce here.

**Memory does not pass, and it is linear.** Roughly **113 MB per actor** on top
of a ~140 MB baseline. Four actors cost **310 MB of video memory before any
texture, UI, audio or game state**. Twelve cost 1.2 GB. The lab's 29-actor
roster costs 3 GB — a tool-only figure, but one that would be killed outright on
any handheld.

**The memory budget is unset.** `commercial-game-delivery.md` §5 reads
"Memory: run state + UI ≤X MB (device-specific; clarify at gate)" — X was never
filled in. **A pass cannot be declared against an unset number.** Setting it is a
gate decision and is the blocking item here, not any code change.

## The levers, priced — and GATED

> **Do not apply any of these yet.** Ruled 2026-07-26: optimisation waits for a
> real battlefield that has been **visually approved**. Every lever below is a
> visual trade — how much aliasing on a glass edge, how much resampling detail in
> a painting, how much gradient loss in a compressed one. Judging those against a
> screen that does not exist yet is judging nothing, and a knob turned now would
> be defended later as if someone had approved it.
>
> **And these figures are a floor, not a ceiling.** `docs/assembly-integration-plan.md`
> S1–S3 add three parallax plates (48 MB, measured above), a depth-mist layer, a
> ledge glow band, a cast-shadow layer, a stage dim and two breath blobs. When
> the battlefield lands, **re-run the probe** — do not re-use the prices below.
>
> ```bash
> godot --path . -s res://tools/bench_actor_stage.gd -- --actors=1,4,6,29 --textures
> ```



Both measured at 4 actors. Neither required an edit to `enemy_view.gd`:
`oversample` is already a `static var`, and the bench overrides `msaa_3d` on the
built viewport rather than changing the file it is measuring.

**MSAA** — the largest single term, because it multiplies the colour and depth
attachments:

| MSAA | vram MB | saved |
|---|---:|---:|
| 4x (as authored) | 310.2 | — |
| 2x | 245.3 | −21% |
| off | 180.8 | −42% |

**`oversample`** — stage pixels go as its square:

| oversample | stage Mpx | vram MB | saved |
|---|---:|---:|---:|
| 2.5 (as authored) | 3.6 | 310.2 | — |
| 2.0 | 2.3 | 248.4 | −20% |
| 1.5 | 1.3 | 198.2 | −36% |
| 1.0 | 0.6 | 162.2 | −48% |

**Together (MSAA 2x + `oversample` 1.5)** — roughly halves the cost at every size:

| actors | vram MB | as authored | saved |
|---:|---:|---:|---:|
| 4 | 175.0 | 310.2 | −44% |
| 6 | 259.3 | 509.5 | −49% |
| 29 | 1501.4 | 3062.5 | −51% |

Both are **visual** decisions — how much aliasing on a glass edge is acceptable,
and how much resampling detail the paintings need. `docs/card-angular-budget.md`
already records that this project's materials read off narrow angular features,
so neither knob is free. **They belong to the Enemy / hero lane to judge, not to
the organiser to set.** This note only prices them.

## The other half: textures are the larger term

Measured with `--textures`, which loads each group and reads the meter:

| group | textures | resident |
|---|---:|---:|
| **cards** | 60 | **688.9 MB** |
| enemies | 27 | 100.0 MB |
| stage | 9 | 48.0 MB |
| ui | 27 | 25.1 MB |
| statuses | 17 | 22.8 MB |
| **all** | **140** | **884.8 MB** |

**Every texture in this project imports lossless.** 245 `.import` files carry
`compress/mode=0`; **not one carries `compress/mode=2` (VRAM compressed)**. So
each is resident as uncompressed RGBA8 at w×h×4 — a card at 2048×1374 costs
11.25 MB, and sixty of them cost 689 MB. The measurement matches the arithmetic
exactly, which is how you know it is residency and not a leak.

That single import setting is a larger memory item than every actor stage
combined, and unlike MSAA or `oversample` it is **not a layout or lighting
decision** — it is a compression-quality decision on the source art. ASTC 4×4
would take the card set from 689 MB to roughly 170 MB; ASTC 6×6 to roughly 86 MB.

Two things make this the card lane's call rather than a free win:

- The card work is built on materials that read off *narrow angular features*
  (`docs/card-angular-budget.md`). Block compression is lossy in exactly the
  gradients that a holo or pearlescent surface lives in. Note though that the
  **procedural surface layers are shaders, not textures** — only the underlying
  painting is at stake here, and photographic art is what ASTC handles best.
  Hard-edged UI and status icons suffer more than paintings do.
- **`mipmaps/generate=false` on cards and enemies** (statuses do generate them).
  A 2048×1374 card drawn at hand size is roughly a 10× downsample with no mip
  chain — which is both an aliasing question and a texture-cache one. Worth
  asking the card lane whether that is deliberate.

Residency is not all-or-nothing: a fight holds the enemies present, the UI, the
statuses, the current act's three plates, and whichever cards have been drawn or
inspected. Godot caches what it loads, so over a long run the resident card set
creeps toward the full 689 MB rather than away from it.

## Not measured

- **GPU time**, on this backend. A machine with a Vulkan adapter would fill the
  column in without changing the tool.
- **The target device.** §5 names "a phone from 2021 or newer" and "Steam Deck".
  Everything above is desktop, where an M1 Max has 32 GB of unified memory and
  no jetsam limit. **Read a desktop OVER as disqualifying; never read a desktop
  OK as a target-device OK.**
- **Sharing one `World3D` across actors.** Each stage currently sets
  `own_world_3d` with its own `Sky` feeding ambient *and* reflections
  (`enemy_view.gd:438-467` (`_ward_from`)), so N actors bake N radiance maps. Collapsing them is
  a larger refactor than either knob above and was not attempted here.
