# Bespoke beats — evidence for James (#334)

One page. Each still is a production frame from `tools/shot.sh --scene=…`
on this branch; James signs visuals off pictures.

Staging is per-scene presentation. ScenePlayer still owns tap/skip and the
persistence handshake (`docs/story/07-scenes.md:25-26`). No new scene-script
grammar, no `unlocks` writes.

## One decision is open

**`e-reflection-routes.png` is the page to look at.** 窗中反影遲半拍
(`docs/story/00-truth.md:173-174`) has three defensible readings and the
mechanism ships able to render all of them; the losers get deleted once you
point at one. Recommendation and the case for it are at the bottom.

## Shots

| File | What | Spec, or the choice it illustrates |
|---|---|---|
| `a-opening-hearth-figure.png` | Opening beat ②: empty-hall plate + #283 cutout, re-seated on the hearth platform and graded to the hall | `docs/art-ledger.md:228-233` (overlay, not baked); `docs/art-ledger.md:268-269` (beat ②); `docs/story/07-scenes.md:122` (坐像疊演拍②) |
| `b-departure-linger-reflection.png` | L0 every-departure linger, staged as **route A**: one hall, one body, the reflection confined to the rose window and lagging half a beat | `docs/story/00-truth.md:173-174` (爐前仍坐着一個兜帽身影;窗中反影遲半拍); `docs/story/07-scenes.md:35-37` |
| `c-unsealing-beat1-pane-lighting.png` | Unsealing beat 1: Vigil rose, mural/masks/frame, sixth pane lit. No plate — `scenes.json` names none | `docs/story/07-scenes.md:123` (亮格 beat 用 mural + masks + frame 現有機件) |
| `d-unsealing-beat3-mirror-queue.png` | Unsealing beat 3: the shipped one-queue plate. One row crosses the whole window; mullions in front | `docs/story/07-scenes.md:113-115` (#263 Q13: never per-pane crowds); `docs/story/07-scenes.md:123` (鏡中一條隊) |
| `e-reflection-routes.png` | **The open decision.** All three routes: window detail at 2.2× on top, the frame it came from below | the fork itself — pick a column |
| `f-route-b-doorway.png` | Route B at full frame: the ghost moved to the arched doorway | alternate; see the case below |
| `g-route-c-rose-glow.png` | Route C at full frame: hearth light in the rose, no figure at all | alternate; see the case below |
| `h-hearth-grade.png` | The cutout's grading, before and after, at the same seat and the same frame | the review's "flat high-chroma sticker"; numbers are measured off these two frames |

## Capture

```
tools/shot.sh --scene=opening   --cursor=2               --shot=…/a-opening-hearth-figure.png
tools/shot.sh --scene=departure --reflect=a --settle=1.2 --shot=…/b-departure-linger-reflection.png
tools/shot.sh --scene=unsealing --cursor=0               --shot=…/c-unsealing-beat1-pane-lighting.png
tools/shot.sh --scene=unsealing --cursor=2               --shot=…/d-unsealing-beat3-mirror-queue.png
tools/shot.sh --scene=departure --reflect=b --settle=1.2 --shot=…/f-route-b-doorway.png
tools/shot.sh --scene=departure --reflect=c --settle=1.2 --shot=…/g-route-c-rose-glow.png
```

`e-` and `h-` are composed from those frames, not captured.

`--settle=1.2` outlasts `HEARTH_HOLD` (1.0 s), so the reflection is
photographed at its peak rather than mid-ramp. `--reflect=` and `--scene=` are
capture hooks, not player grammar. Opening/unsealing/departure remain
UNSUPPORTED catalogue identities (`pending_scene` is not an OVERRIDE_KEY —
#202). `unsealing-replay` is the expressible named Scenario: Vigil with six
panes, window-body tap replays this staging.

**A `--scene=` shot leaves `user://glassvow_run_v2.json` behind, and four test
files then diverge on it** (`test_opening_flow`, `test_resume_routes`,
`test_scenario_catalogue`, `test_scene_wiring` — 26 failures, none real).
Delete that file before running the suite after a capture session.

## The fork — 窗中反影遲半拍

The frame is engine-locked to 1180×820 and the plate covers it at 820/1024, so
the plate offers exactly two openings to reflect in, and their sizes are the
whole argument:

| | rose window | arched doorway |
|---|---|---|
| Size on screen | 121 × 126 px (1.6% of the frame) | 126 × 290 px (3.8%) |
| What is in it | dark unlit glass, six lobes, heavy stone tracery and a central boss | open air: a lit road, waystones, mountains, sky |
| Plate's own words | 「a round six-lobe rose window of dark unlit glass, its six lobes all cold and black」 (`docs/design/2026-08-16-scene-plates/README.md:97-98`) | 「an open arched doorway giving onto a long stone road running east into the night」 (`docs/design/2026-08-16-scene-plates/README.md:95-96`) |

**A — the figure's reflection in the rose window.** Spec-faithful: 窗 is the
rose, and a reflection is not a second body, so the one-body ruling
(`docs/art-ledger.md:228-233`) is untouched. What the picture shows is the
cost: at 121 px with a stone boss across its middle, the ghost reads as *something
in the glass* rather than as a hooded figure. That is arguably the right
register for a plant whose spec line is 「零文字確認」 — but it is a
suggestion, not an image.

**B — the same ghost in the doorway.** The premise does not survive the plate:
that arch is open air, not glass. The ghost is invisible against a lit sky
(look at the middle column), and every fix for that makes it worse — anything
bright enough to read there reads as *a person standing outside on the road*,
which is a second body in the worst possible place.

**C — no figure; only the hearth light lagging in the rose.** The most legible
of the three by a distance, and it carries zero one-body risk. It also breaks
the rule the plate was re-rendered to obey: 「The six lobes are dark. The
opening plays on the first run, at zero shards; a lit lobe would contradict the
state the plate is shown in」 (`docs/design/2026-08-16-scene-plates/README.md:105-106`).
Warm light spreading across all six lobes at zero shards reads as the window
beginning to light — which is the L3 unsealing beat, four levels early.

**Recommendation: A.** It is the only one of the three that says what the spec
line says without spending a rule to say it. B's window is not a window and C
buys legibility with the plate's shard-state, whereas A's cost is only that the
plant is faint — and faint is what an L0 画面級伏筆 is supposed to be.

If A is picked and the faintness bothers you, there is a known upgrade that is
deliberately not built yet: the ghost currently paints **over** the stone
tracery, which is why it reads as a smear rather than as something behind the
glass. Deriving the mask from the plate's own dark-glass luminance instead of
from a plain disc would put the reflection *inside* the lobes with the mullions
crossing in front. That is real work and it only pays off on route A, so it
waits for this decision.

## Spec note

Issue #334 said `scenes.json` gives unsealing beats 1 and 3 no `art`. Beat 1
(index 0) has none, by design. Beat 3 (index 2, `story.unsealing.b3`) already
names `unsealing-mirror-queue.png` — that *is* the one-queue mirror plate from
the §8 bill. Staging beat 3 means showing that plate as one queue, not minting
a second crowd per pane. Beat 2 (index 1, 窗全亮) also has no art and keeps
the rose fully lit until the plate takes over.
