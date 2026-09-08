# Act IV Step 3 — delivery evidence

Status: **Act IV Step 3 engineering acceptance is complete (100%)**. Native
inspection, the full local core/specialist gates and the final independent review
pass. The chapter is delivered for owner art approval; that approval and Step 4
campaign-map integration remain outstanding, separate boundaries. Act I–III
already have owner Step 3 approval. This is not 100% of the eight-step renovation.

The review PR is scoped from the accepted Act III checkpoint, rather than folding
its accumulated historical study changes into this chapter's review. It remains
a draft for the chapter gate. Hosted CI has its live status in the PR; the exact
local commands and results are recorded below.

## Delivered chapter

The owner's later direction supersedes the old enclosed-court concept: only a
processional path remains in visually unbounded space. There is no ground plane,
perimeter wall, water sheet or horizon. The window is monumental, the hearth is
small, and the three intervening stops carry subordinate memories of earlier
chapters. Short resolved stair flights descend and rise along the way.

One slow canvas haze shader and 42 instanced drifting embers give the background
motion. There is no realtime sky cubemap, SSR, reflection buffer or CPU particle
simulation. Architecture has real thickness, recessed masonry, glass, footings
and restrained warm light. The shared `MirroredFinish` palette quietens the
actual Act IV combat ledge while retaining the original painted silhouette,
stelae, canvas modulation, actors, layout and encounter behaviour.

## Acceptance breakdown

| Package | Progress | Evidence |
| --- | ---: | --- |
| Fixed five-stop binding and baseline | 100% | Fresh seed 717/4/2026 exports; identical five-node/four-edge geometry |
| Complete spatial composition | 100% | Native close/whole frames at 1458×820, 1180×820 and 844×390 |
| Finished section and architectural kit | 100% | Thick rose-window, stone path/stairs, stelae, small hearth; inspected native close views |
| Full journey and chapter atmosphere | 100% | 28.77-second uncut recording, five stops, 661 travel frames, unchanged snapshot |
| Verification, independent review and delivery | 100% | Core 102, scripts 442, selected specialists and independent APPROVE; native review page delivered |

Weighted engineering completion is 100% (weights 10/20/20/25/25).
Owner art approval is not counted as an engineering pass.

## Native proof and limits

- Each reference shape passes 2,240 actual-triangle probes across seven usable
  corridor lanes, including stairs, with no missing floor or obstruction.
- Each assembly passes 189 lowest rendered asset-vertex contacts against the
  path, within 3 cm. This is a sampled foot-contact check, not physics simulation.
- Actual clicks exercise current selection, next-node selection and Travel;
  drag, zoom and overview pass. Route guidance samples 892 supported points.
- The complete journey is triggered by the actual Walk all button. It reaches
  the last node, keeps the traveller in the usable viewport and preserves the
  source snapshot. The film is silent and contains no cuts or compositing.
- The combat before/after pairs use one frozen actual scene per shape. Native
  transparent rendering checks inherited opacity 0.6 and plate opacity 0.37:
  maximum alpha error is **0**, with 24,768 colour-changed samples.
- The source guard rejects a changed boss type, missing stop, stale hero hash
  and rejected compiler sample. Rendered hero transforms come from the compiler.
- Browser UI inspection confirms playback through the final frame, image and
  comparison controls, nine loaded images, and no horizontal overflow at 390 px.
  Existing private Tailnet responses match the local page, film and tested media.

All game views are native Godot desktop captures. Phone/tablet dimensions are
reference proportions, not physical-device qualification. CPU timing is measured;
Godot's GPU timestamp query returned zero and is explicitly unavailable here.

## Performance — native desktop, 120 measured frames per view

| Viewport | View | Frame interval median / p95 | Render CPU median / p95 | Draw calls | Renderer allocation |
| --- | --- | --- | --- | ---: | ---: |
| 1458×820 | Journey | 8.323 / 9.034 ms | 0.178 / 0.506 ms | 57 | 152.16 MiB |
| 1458×820 | Overview | 8.319 / 9.921 ms | 0.235 / 0.723 ms | 124 | 152.53 MiB |
| 1180×820 | Journey | 8.344 / 8.976 ms | 0.178 / 0.619 ms | 52 | 138.88 MiB |
| 1180×820 | Overview | 8.338 / 9.401 ms | 0.239 / 0.609 ms | 115 | 139.25 MiB |
| 844×390 | Journey | 8.336 / 9.250 ms | 0.194 / 0.471 ms | 68 | 102.52 MiB |
| 844×390 | Overview | 8.343 / 9.481 ms | 0.250 / 0.703 ms | 140 | 102.89 MiB |

Mac M1 Max, Godot 4.7.2, Metal Forward Mobile. Frame intervals include display
synchronisation. Movie encoding was excluded from the performance measurements.
No claim of physical-phone performance or isolated GPU duration is made.

## AI-SDLC and four rules

One owner implemented one chapter, using the existing generator seam and shared
walking surfaces, stairs, camera/input, route guidance, Travel and profiling.
Native falsification preceded promotion: unsupported placement, sky artefacts,
missing glass faces, baked alpha and cropped films were rejected. Their causes
and corrections are retained under `rejected/`.

The final source candidate is `c0570e4ba664a7d531d19e52ce6216540d41cb87`.
The full script sweep passes 442 scripts. Imports and selected specialist checks
pass, including scope classification, repaired documentation anchors, reference
freeze, map-quality self-tests/current registry, performance replay, 20-seed asset
profile probing and the four selected UI containment checks. The complete core suite passes all 102 suites in 1,430.59 seconds on this
coherent candidate. Expected negative-case and headless shutdown diagnostics are
retained in the log. Independent review **APPROVE** at ac4a3d8dd4ad2a533cb472d87ddb85b78382338c,
with no blocking or non-blocking findings. The subsequent status/usage record
changes documentation only; implementation and media fingerprints are unchanged.

This follows the repository's AI-SDLC contract; it is not an external Anthropic
certification. Effectiveness comes from reusing proven geometry and measuring
native behaviour. Token/wall-time efficiency comes from one writer, bounded
experiments, batched captures and one coherent core gate, with no repeated green
suite or overlapping implementation agents. Goal remains off. A failed gate is
fixed or reported, never weakened to improve the completion percentage.

## Reproduction

From the repository root:

```sh
godot --path . -s res://tools/map_workshop/act4/study.gd -- --interactive --exercise --viewport=844x390 --output=/tmp/act4-phone
godot --headless --path . -s res://tools/map_workshop/act4/verify_source.gd
godot --path . -s res://tools/map_workshop/act4/verify_combat_material.gd
godot --path . --resolution 1180x820 --fixed-fps 30 --write-movie /tmp/act4-tour.avi -s res://tools/map_workshop/act4/tour.gd -- --interactive --viewport=1180x820 --output=/tmp/act4-film
```

The default sample is the committed seed 717 export. The MovieMaker viewport and
study viewport must both remain 1180×820 for this recording configuration.


## Time and token checkpoint

Implementation instruction received at 2026-09-07T09:42:20.427Z. Root counters below
are measured through 2026-09-07T10:57:53.597Z before the final hosted-CI wait. The final
PR delivery comment records the closing checkpoint without triggering a second
unchanged-code CI run. This avoids repeating the complete PR-diff gate merely
to record its own result.

| Root counter | Measured delta |
| --- | ---: |
| Input tokens | 19,985,080 |
| Cached input tokens | 19,626,368 |
| Uncached input tokens | 358,712 |
| Output tokens, including reasoning | 91,300 |
| Input cache hit | 98.205% |

Reviewer/provider usage is not separately observable in these root counters.
Reasoning is already included in output and is not added again. These counters
cannot attribute Pro allowance or billing to this task. Goal remains off.
The initial 4–6-hour forecast was conditional; native/local acceptance completed
within approximately 80 minutes. Final hosted review checks remain subject to
runner availability; use the PR's live gate state for the final publication time.
