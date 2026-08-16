# Bespoke beats — evidence for James (#334)

One page. Each still is a production frame from `tools/shot.sh --scene=…`
on this branch; James signs visuals off pictures.

Staging is per-scene presentation. ScenePlayer still owns tap/skip and the
persistence handshake (`docs/story/07-scenes.md:25-26`). No new scene-script
grammar, no `unlocks` writes.

## Shots

| File | What | Spec |
|---|---|---|
| `a-opening-hearth-figure.png` | Opening beat ②: empty-hall plate + #283 cutout on the hearth step | `docs/art-ledger.md:228-233` (overlay, not baked); `docs/art-ledger.md:268-269` (beat ②); `docs/story/07-scenes.md:122` (坐像疊演拍②) |
| `b-departure-linger-reflection.png` | L0 every-departure linger: figure seated, window copy flipped and lagged | `docs/story/00-truth.md:173-175` (爐前仍坐着一個兜帽身影; 窗中反影遲半拍); `docs/story/07-scenes.md:35-37` |
| `c-unsealing-beat1-pane-lighting.png` | Unsealing beat 1: Vigil rose, mural/masks/frame, sixth pane lit. No plate — `scenes.json` names none | `docs/story/07-scenes.md:123` (亮格 beat 用 mural + masks + frame 現有機件) |
| `d-unsealing-beat3-mirror-queue.png` | Unsealing beat 3: the shipped one-queue plate. One row crosses the whole window; mullions in front | `docs/story/07-scenes.md:113-115` (#263 Q13: never per-pane crowds); `docs/story/07-scenes.md:123` (鏡中一條隊) |

## Capture

```
tools/shot.sh --scene=opening --cursor=2 --shot=…/a-opening-hearth-figure.png
tools/shot.sh --scene=departure --settle=0.7 --shot=…/b-departure-linger-reflection.png
tools/shot.sh --scene=unsealing --cursor=0 --shot=…/c-unsealing-beat1-pane-lighting.png
tools/shot.sh --scene=unsealing --cursor=2 --shot=…/d-unsealing-beat3-mirror-queue.png
```

`--scene=` is a capture hook, not player grammar. Opening/unsealing/departure
remain UNSUPPORTED catalogue identities (`pending_scene` is not an OVERRIDE_KEY
— #202). `unsealing-replay` is the expressible named Scenario: Vigil with six
panes, window-body tap replays this staging.

## Spec note

Issue #334 said `scenes.json` gives unsealing beats 1 and 3 no `art`. Beat 1
(index 0) has none, by design. Beat 3 (index 2, `story.unsealing.b3`) already
names `unsealing-mirror-queue.png` — that *is* the one-queue mirror plate from
the §8 bill. Staging beat 3 means showing that plate as one queue, not minting
a second crowd per pane. Beat 2 (index 1, 窗全亮) also has no art and keeps
the rose fully lit until the plate takes over.
