# Bespoke beats — evidence for James (#334)

Staging is per-scene presentation. ScenePlayer still owns tap/skip and the
persistence handshake (`docs/story/07-scenes.md:25-26`). No new scene-script
grammar, no `unlocks` writes.

## Settled — 窗中反影 is route A

James signed **A** on 2026-08-16: the figure's reflection in the rose window,
lagging half a beat. B (doorway ghost) and C (rose glow, no figure) are
deleted. The signed comparison is `e-reflection-routes.png`. Opening hearth
cutout, unsealing beat 1 pane-lighting, and unsealing beat 3 one-queue mirror
were signed the same turn; placeholder copy is #355 / #228, not a staging
reject.

A reflection is not a second body, so the one-body ruling
(`docs/art-ledger.md:228-233`) holds. The cost is faintness at 121 px behind
tracery — the right register for an L0 「零文字確認」 plant
(`docs/story/00-truth.md:177-178`). B's arch is open air, not glass. C lights
the six dark lobes at zero shards, which is the L3 unsealing beat four levels
early (`docs/design/2026-08-16-scene-plates/README.md:105-106`).

Unbuilt, not blocking: the ghost currently paints over the stone tracery.
Deriving the mask from the plate's own dark-glass luminance would put it
inside the lobes with the mullions in front. Real work; not this ticket.

## Shots

| File | What | Spec |
|---|---|---|
| `a-opening-hearth-figure.png` | Opening beat ②: empty-hall plate + #283 cutout, seated on the hearth platform and graded to the hall | `docs/art-ledger.md:228-233`, `docs/art-ledger.md:268-269`; `docs/story/07-scenes.md:122` |
| `b-departure-linger-reflection.png` | L0 every-departure linger: one hall, one body, reflection in the rose, lagging half a beat | `docs/story/00-truth.md:177-178`; `docs/story/07-scenes.md:35-37` |
| `c-unsealing-beat1-pane-lighting.png` | Unsealing beat 1: Vigil rose, mural/masks/frame, sixth pane lit. No plate | `docs/story/07-scenes.md:123` |
| `d-unsealing-beat3-mirror-queue.png` | Unsealing beat 3: the shipped one-queue plate. One row crosses the whole window | `docs/story/07-scenes.md:113-115`; `docs/story/07-scenes.md:123` |
| `e-reflection-routes.png` | Signed A/B/C comparison; A shipped | #334 |
| `h-hearth-grade.png` | Cutout grading, before and after | the review's "flat high-chroma sticker" |

## Capture

```
tools/shot.sh --scene=opening   --cursor=2 --shot=…/a-opening-hearth-figure.png
tools/shot.sh --scene=departure --settle=1.2 --shot=…/b-departure-linger-reflection.png
tools/shot.sh --scene=unsealing --cursor=0 --shot=…/c-unsealing-beat1-pane-lighting.png
tools/shot.sh --scene=unsealing --cursor=2 --shot=…/d-unsealing-beat3-mirror-queue.png
```

`e-` and `h-` are composed from those frames, not captured.

`--settle=1.2` outlasts `HEARTH_HOLD` (1.0 s), so the reflection is
photographed at its peak rather than mid-ramp. `--scene=` is a capture hook,
not player grammar. Opening/unsealing/departure remain UNSUPPORTED catalogue
identities (`pending_scene` is not an OVERRIDE_KEY — #202). `unsealing-replay`
is the expressible named Scenario: Vigil with six panes, window-body tap
replays this staging.

**A `--scene=` shot leaves `user://glassvow_run_v2.json` behind, and four test
files then diverge on it** (`test_opening_flow`, `test_resume_routes`,
`test_scenario_catalogue`, `test_scene_wiring` — 26 failures, none real).
Delete that file before running the suite after a capture session.

## Spec note

Issue #334 said `scenes.json` gives unsealing beats 1 and 3 no `art`. Beat 1
(index 0) has none, by design. Beat 3 (index 2, `story.unsealing.b3`) already
names `unsealing-mirror-queue.png` — that *is* the one-queue mirror plate from
the §8 bill. Staging beat 3 means showing that plate as one queue, not minting
a second crowd per pane. Beat 2 (index 1, 窗全亮) also has no art and keeps
the rose fully lit until the plate takes over.
