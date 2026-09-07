# Act III Step 3 delivery report

Runtime candidate: `494090808c56932651ad6e0e340880b08310fdf5`.

The complete precinct composition is retained. This extension completes native
route reading and aligns the actual Act III combat ground. Final core validation
and independent review are running; this report will record their results before delivery.

| Workstream | Implementation | Decisive evidence |
|---|---:|---|
| Precinct, relief, courts, stairs and passages | 100% | Prior precinct-v2 report and approved runtime 0315abe |
| Selected approach and exact-branch Travel | 100% | Nine native runs; 15 actual next-node selections |
| Whole-network planning | 100% | All 76/74/74 edges retained for seeds 717/4/2026 |
| Ground support and game-truth preservation | 100% | 112,656 surface samples; source unchanged in every run |
| Shared obsidian finish and actual combat ground | 100% | Three native proportions; 98,304 alpha samples, zero changes |
| Native presentation and interaction recording | 100% | Wide/tablet/phone proportions; 638-frame uninterrupted movie |
| Final regression and independent review | Pending | Full core running; exact-candidate review follows |

## Behaviour and scope

Select an available next event to reveal its approach across the existing paving.
Travel follows current-to-selected, not the selected event's subsequent edge.
Selecting the current event clears that preview. Whole act reveals the full
network; grouped markers open through zoom. The inspection never advances a save.
This remains the Step 3 native study: Step 4 campaign-map integration is later.

`common/route_guidance.gd` is opt-in and read-only. It uses the existing precise
walking-surface audit and caches supported ribbons. `ObsidianFinish` owns the
Act III stone recipe; map world material and actual combat canvas material use
perspective-appropriate implementations. Only the Act III combat ledge opts in.
Act I/II composition and ground selection remain unchanged. Act IV is not started.

## Native evidence

The matrix covers seeds 717, 4 and 2026 at 1458×820, 1180×820 and 844×390.
Seed 2026 has one available next event; the other seeds have two. Three stale
second-choice copies were rejected and the capture tool now checks actual choice
count and freshness. See `receipt.json` for component provenance and media hashes.

The actual combat scene is frozen for each before/after pair. Final images are
`combat-final-*-before.png` and `combat-final-*-after.png`. Earlier `combat-*`
files are superseded evidence of a rejected edge-banding candidate. Final shading
blends smoothly into the original platform edge and preserves its alpha exactly.
All three final proportions were visually inspected.

The native movie records real control inputs, both complete selected approaches
and the overview, at 30 fps, 21.266 seconds. Encoding changes only the container
and codec; it contains no cuts, compositing or generated frames.

## Performance and limits

Actual guidance, 1180×820 native viewport on the host Mac, 120 frames per mode:

| Mode | Frame interval P95 | Render CPU P95 | Draw calls | Renderer allocation |
|---|---:|---:|---:|---:|
| Selected approach | 16.655 ms | 0.212 ms | 53 | 131.44 MiB |
| Whole network | 9.425 ms | 0.546 ms | 675 | 137.19 MiB |

Frame interval includes synchronisation; these are host measurements, not physical
phone/tablet certification. Overview antialiased polylines increase draw calls;
retain this counter for Step 4 device qualification. The engine reports no GPU
timestamps here; zero values are unavailable measurements, not zero GPU cost.

## AI-SDLC and four rules

One owned branch and bounded extension; shared opt-in modules; deterministic
selection and native evidence before final independent review. No Goal recreation.
Two earlier core attempts were superseded after actual interface/shader findings;
they are not passing receipts. The final coherent candidate owns the core result.
Native capture found and removed edge banding and stale capture aliases before
owner delivery. No acceptance tolerance was weakened. Running extra unrelated
suites is not a substitute for visual inspection.

Final delivery time, core verdict, independent review and measured token deltas
will be added when those gates finish. Raw token totals include cached context;
they are not the account's Pro quota or a monetary bill.
