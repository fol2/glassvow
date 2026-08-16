# Scene plates — the nine B-grade full-bleed plates (#310)

Production record for the plate bill in `docs/story/07-scenes.md` §8, settled by
James's Hybrid verdict on the staging bake-off
(`docs/design/2026-08-16-scene-staging-bakeoff/README.md`, 2026-08-16).

**All ten paths are filled. James picked on 2026-08-16** — the winners are in the
candidates table below and encoded in `install_plates.py`, which is what wrote
`assets/art/scenes/`. Candidates stay in `candidates/` as lossless decision
material; re-run the installer to reproduce the shipped bytes.

## Frame contract

Fixed by the engine, not by taste:

- `project.godot:45` is `window/stretch/aspect="keep"`, so every device sees the
  same **1180×820** frame (1.4390). A plate meets exactly one aspect ratio —
  there is no per-device safe band to solve, unlike `night-stall.png`.
- Render **1536×1024** (1.5), the bake-off mocks' size. Displayed as cover on
  1.4390 that crops **2% of width off each side**, so nothing load-bearing may
  sit in the outer 4% of width.
- The scene player draws a dialogue band over the bottom of the frame (the
  bake-off mocks bake one in at ~8% height). **Keep the bottom 12% free of
  load-bearing content**, and the plates themselves carry **no baked text and no
  baked letterbox bars** — the mocks' bars and captions were mock furniture.
- Payload: the mocks measure 2.0–2.4 MB each against an art payload already at
  135 MB. Nine plates at that weight is ~20 MB. Every accepted plate goes
  through a lossy-palette pass before it lands in `assets/`.

## Asset paths

Fixed by `content/scenes.json` (#309) — the prompts must write these names.

| Plate | Path | Source |
|---|---|---|
| 1 | `assets/art/scenes/opening-hearth.png` | new |
| 2 | `assets/art/scenes/unsealing-mirror-queue.png` | new |
| 3 | `assets/art/scenes/unsealing-monuments-push.png` | new |
| — | `assets/art/scenes/unsealing-door-open.png` | **crop of plate 3** (§8: 「推門 plate 的門開 crop」) |
| 4–8 | `assets/art/scenes/act4-node1.png` … `act4-node5.png` | new |
| — | `assets/art/scenes/act4-entry.png` | **see "The tenth path" below** |
| 9 | `assets/art/scenes/finale-swap.png` | new |

### The tenth path

`content/scenes.json` names `act4-entry.png`, which appears in **no** line of the
§8 bill. It is a real gap between the data and the bill, not a naming slip.

Resolved the cheap way and flagged for James: `act4-entry` points at
`act4-node1.png`. Node 1's motif pool *is* the entry image — 門檻'
(the threshold's own inner face), the window seen from the far side. The entry
beat runs `push-in` and node 1 runs `hold`, so the same plate reads as one
continuous camera move into the node rather than as a repeat. The alternative is
a tenth plate nobody billed.

## Shared style block

Verbatim in all nine prompts. It is the Route B cinematic treatment James
preferred "much much more" — environment depth, asymmetric composition, raking
light — welded to the material language of `style-bible.md`.

> Cinematic gothic fantasy key art, painterly and richly rendered, in the visual
> language of a stained-glass world: deep environment perspective with real
> recession into the distance, asymmetric composition with the subject well off
> centre, strong raking light cutting through the dark, heavy chiaroscuro with
> most of the frame in warm-black shadow, dust motes and drifting embers in the
> light shafts, matte painterly brushwork with no photographic sheen and no
> visible generation noise. Palette: warm amber, honey and gold against cold
> slate, deep teal, indigo and violet — a candlelit cathedral at night. Every
> figure is built from large flat panes of coloured glass separated by thick
> black lead came lines with thin worn gold edging: cathedral stained glass
> rendered as a character, only a few big panes, never lacework or many small
> pieces. Hooded figures have no face — the hood opening is a deep black void
> with no glowing eyes. Landscape 1536x1024, full-bleed to every edge. Keep every
> load-bearing element inside the central 92 percent of the width and out of the
> bottom 12 percent of the height. NO TEXT of any kind, no caption, no letterbox
> bars, no logo, no watermark, no UI, no border frame.

## The nine subjects

Canon anchors are cited so a re-render can be checked, not re-argued.

### 1 — `opening-hearth.png` · the hearth, wide

Carries opening beats ①③④ (`07-scenes.md` §2). Reference:
`../2026-08-16-scene-staging-bakeoff/route-b-opening.png` — the plate James
named when he set the bar.

> The great hall of a night vigil, seen wide and deep. On the RIGHT, a deep
> stone hearth set into a massive block wall, a live fire burning inside it in
> hot amber and gold, the only strong light in the frame. Sitting on the hearth
> step directly before the fire, in profile with its back half-turned to us, a
> single hooded figure built of large panes of blue, violet, teal and deep red
> glass with heavy black lead lines — completely still, hands folded, hood a
> black void. On the LEFT, far away down the hall, an open arched doorway giving
> onto a long stone road running east into the night, a cold blue distance of
> hills and a few tiny lit waystones along it. High on the left wall, a round
> six-lobe rose window of dark unlit glass, its six lobes all cold and black,
> catching only a little starlight. Wet flagstones carry the firelight in a long
> raking streak across the floor from right to left, toward the door. Warm right,
> cold left, deep recession between them.

Notes bound to this plate:

- **The six lobes are dark.** The opening plays on the first run, at zero
  shards; a lit lobe would contradict the state the plate is shown in.
- **The plate is an empty room. There is no figure in it** [SETTLED — James,
  2026-08-16]. The first pass baked the seated hooded figure into the plate, on
  the reasoning that it is the L0 plant (`00-truth.md` §5 L0) and would save beat
  ④ a second asset. But the #283 Keeper overlays on this plate for beat ②'s
  dialogue, so a baked figure means two bodies on screen at once. James ruled one.
  `-c` and `-d` re-render the hall deserted, with the hearth step left bare and
  composed as the natural focal point; `-c` shipped.

  **Consequence for the scene player, not for the plate**: 爐前仍坐着一個兜帽身影
  is now carried entirely by the #283 overlay, so that overlay has to persist
  through beat ④'s linger and through the every-departure ambient staging — it is
  no longer free. Belongs to #283/#309 wiring.

### 2 — `unsealing-mirror-queue.png` · one queue across the whole window

The binding taste call of the whole bill. 00 §2.6: 彩窗全亮的一刻變成鏡:
窗中站滿一排「你」,每人胸口一點光. James rejected per-pane crowd duplication as
creepy; `../2026-08-16-scene-staging-bakeoff/route-b-unsealing.png` is the
**negative** reference — do not repeat it.

> The interior of a vast dark cathedral, seen from low and to the right. Filling
> the upper left, an enormous round six-lobe rose window blazing at full
> brightness in molten amber and gold, so bright it has become a MIRROR. Across
> that window stands ONE SINGLE UNBROKEN HORIZONTAL ROW of identical hooded
> figures, shoulder to shoulder, standing side by side in one continuous line
> that runs straight across the entire width of the window from its far left
> edge to its far right edge. The row passes BEHIND the black stone tracery and
> the mullions and simply continues on the other side of them — the stone bars
> cross in front of the row like railings in front of a crowd. The row is never
> broken into separate groups, never restarted inside each lobe, never repeated
> or tiled: it is one queue, seen once. Each figure is a hooded silhouette in
> violet and indigo glass with a faceless black hood, and each one carries a
> single small point of warm light at its chest. Down on the flagstone floor,
> small and far off to the lower right, one lone hooded figure stands with its
> back to us, looking up at the window. Broad raking shafts of gold pour down
> from the window across the empty floor toward it. Everything except the window
> and the light shafts is in deep warm-black shadow.

### 3 — `unsealing-monuments-push.png` · the monuments stand and push the door

00 §2.6: 沿路所有的碑同時動了——歷代行者站直,列隊,推門。門不是你開的,
是他們一齊推開的. Motion in the scene data is `push-in`, so compose for a camera
that moves toward the door.

> A long stone road at night, seen from behind and slightly above a crowd, the
> road running away from us into the far distance toward an enormous sealed
> double door of black stone at the end. The door is carved edge to edge with
> deep relief: robed pilgrims in procession. It is grinding OPEN — a narrow
> vertical blade of blinding gold light escapes from the seam between its two
> leaves and cuts back down the whole length of the road toward us. Along the
> road, tall weathered standing monuments are STRAIGHTENING UP out of the ground
> and becoming walkers: at the far end they are still crooked stones half-sunk in
> the earth, nearer the door they have risen into upright hooded figures of grey
> and teal glass with heavy black lead lines, and closest to the door dozens of
> them press shoulder to shoulder with their hands flat against the stone,
> pushing it together. Their backs are to us. Every one of them is rimmed in the
> gold light coming through the seam. The land either side of the road is cold
> blue-black and almost featureless. Asymmetric: the door sits off centre to the
> right, the road sweeps in from the lower left.

The `unsealing-door-open.png` beat is cropped from this file, not rendered
separately — §8: 「推門 plate 的門開 crop」. Crop to the door and the seam, then
resample to 1536×1024.

### 4 — `act4-node1.png` · 門檻' — the threshold's inner face

Motif pool (`03-acts.md` Act IV table): 彩窗六格、封門浮雕. Act IV's two standing
rules apply to nodes 1–5 alike: **站立的碑列隊成路** (monuments queued into a
road) and **倒轉的爐光** — the hearth light arrives from the wrong direction,
from the far end of the road back toward the viewer, because 門後之地是鏡面空間,
盡頭就是爐邊 (00 §2.4). #259 fixes 彩窗與封門是同一道 threshold 的兩面.

> Standing on the FAR side of a great rose window, looking back at it from
> inside a mirrored world. The six-lobe window fills the frame off to the left,
> seen from behind: its six lobes glow amber but everything in them is REVERSED,
> the tracery reading backwards, the glass lit from the side we are not on. Set
> into the same wall to the right, the inner face of a huge sealed door, its
> relief carving of robed pilgrims standing proud of the surface. Running away
> from the wall into the distance, a road paved in pale stone, lined on both
> sides with tall upright monuments standing in two ranks like a guard of
> honour. The light is INVERTED: warm hearth-amber comes from far away at the
> vanishing point behind us and rakes forward along the road, so the monuments
> throw their long shadows toward the window rather than away from it. Cold
> violet-grey everywhere the amber does not reach. No figures.

### 5 — `act4-node2.png` · III' — the Obsidian Court mirrored

Motif pool: 斷環、星、黑曜. Material law (00 §8.6): 黑曜=凝而無光的玻璃(被放棄
的意志); 斷光環=放棄一刻熄掉的光.

> A vast hall of black obsidian under an open night sky, mirrored and wrong. Two
> ranks of tall upright monuments run away from us down the centre, forming a
> road between colonnades of polished black obsidian pillars that reflect but do
> not transmit any light. Hanging in the air high above the far end, a huge
> BROKEN RING of gold — a halo snapped clean through, its two ends not meeting,
> dark along the break. Cold hard stars burn in the black sky and are doubled in
> the obsidian floor, so the hall appears to have sky above and below. The light
> is INVERTED: warm hearth-amber pours from the far vanishing point toward us
> down the length of the hall, catching the near edges of the pillars and the
> shoulders of the monuments in thin gold rims, while their faces stay black.
> Asymmetric, the colonnade sweeping in from the right. No figures.

### 6 — `act4-node3.png` · II' — the Sunken City mirrored

Motif pool: 水、假光、圖書館. Material law (00 §8.6, #261 Q4): 水=不燒也不凝的
意志=「等」; 假光=似光而不透意志的模仿.

> A drowned library, mirrored so that the water is ABOVE. A still black surface
> of water hangs across the whole ceiling of the frame like an upside-down lake,
> its underside rippling, with drowned things suspended in it. Beneath it, ranks
> of enormous stone bookshelves recede into the distance, their shelves packed
> with swollen ruined books, the aisles between them forming a road. Tall
> upright monuments stand in that road at intervals like readers who never left.
> Sickly green-white lanterns hang along the shelves giving a FALSE light — cold,
> flat, illuminating nothing, casting no proper shadow. The one true light is
> INVERTED hearth-amber arriving from the far end of the aisle toward us,
> ordinary and warm against all that false green, throwing the monuments'
> shadows forward. Drifting motes rise instead of falling. Asymmetric, the aisle
> entering from the lower left.

### 7 — `act4-node4.png` · I' — the Ash Wood mirrored

Motif pool: 灰、根、雙燈. Material law: 灰=燒盡、無可凝者; 燈=攜帶意志的器皿.
Scene data runs this node `linger` on three lines, so it must hold the eye.

> A forest turned upside down. The canopy overhead is not branches but a dense
> ceiling of pale bare ROOTS reaching down, and the grey trunks descend from it.
> Fine grey ash drifts UPWARD through the whole frame instead of falling,
> settling on the underside of the roots. A road of packed ash winds away between
> the trunks, lined with tall upright monuments half-buried in drifts. Standing
> at the roadside, off centre to the right, TWO iron lanterns on tall poles side
> by side — one burning with a small clean amber flame, the other utterly dark
> and empty, its panes cold and dead. The light is INVERTED: warm hearth-amber
> comes from far down the road toward us through the trunks in long raking
> shafts, so the monuments and the two lantern poles cast their shadows toward
> the viewer. Everything else is ash-grey and cold blue.

### 8 — `act4-node5.png` · 爐邊' — the Gilded City gate is the hearth

Motif pool: 爐光、兜帽像、隊伍. The payload of the whole act: 盡頭=爐邊真貌,
金城=守夜之爐由鏡面另一面看的樣子,入城=歸家 (00 §8.1, #259 Q3). The gate
arch and the hearth mouth must be recognisably the same shape — this plate is
the reveal, so the rhyme with plate 1's hearth is the point.

> The gate of a golden city standing above a sea of cloud at sunset, seen from
> the road below. The gate is an enormous arch of dark stone with a great fire
> burning in the opening — and its shape is unmistakably the mouth of a
> fireplace, the same arch as a domestic hearth built at cathedral scale, its
> stone blocks and its ash-lip and its low step all magnified. Spires of gold and
> stained glass rise behind it out of the clouds. Leading up to the gate, a road
> lined with tall upright monuments, and walking up that road away from us, a
> single unbroken queue of identical hooded figures in violet and teal glass,
> one behind the other, each carrying a point of warm light at its chest, the
> nearest large and the furthest tiny as they pass into the fire. The light comes
> from inside the gate, straight down the road into the camera, so every figure
> in the queue is a rimlit silhouette. Asymmetric, the gate off centre to the
> left, the road entering from the lower right.

### 9 — `finale-swap.png` · the swap — you walk, it stays

00 §2.6: 終戰不是把 boss 打倒,而是換位:你走,它留。全遊戲第一次,由留下的
那個親身走完最後一段. The interactive beat composites over this plate, so leave
the centre readable.

> Two figures, one leaving and one staying, at the mouth of a great fiery arch.
> On the RIGHT, in the near foreground and large, a hooded figure of blue and
> violet glass SITS on a low stone step with its back to the arch, motionless,
> hands empty and open on its knees, hood a black void, held entirely in cold
> shadow with only a thin amber rim down one side — it is not going anywhere. On
> the LEFT, further away and much smaller, a second identical hooded figure
> WALKS away from us into the arch, seen from behind, mid-stride, one foot
> lifted, already half dissolved in the gold light pouring out of the opening.
> Between them a wide empty stretch of lit flagstone. The whole composition
> reads left-to-right as departure and right-to-left as remaining. Embers drift
> up through the light. Deep recession through the arch into brightness; the two
> figures are the only figures in the frame.

## Candidates

Review sheet: **`contact-sheet.png`** — every candidate in scene order, forks
side by side. Rebuild it with `python3 contact_sheet.py` after any new render.

First pass was one candidate per plate. Six landed clean; four missed against a
stated constraint and were re-rendered as **-b** forks. Nothing here has been
picked — the `-a`/`-b` reads below are the agent's, and **James's pick is the
only verdict that counts**.

| Plate | Candidates | Where they stand |
|---|---|---|
| 1 opening-hearth | a, b, **c ← James**, d | `b` won the first round on staging, then the figure ruling voided both: `a` and `b` bake a seated figure that would collide with the #283 overlay. `c` and `d` re-render the hall deserted in `b`'s staging. **`c`** — a long low bare hearth step with the most room for the overlay, and the clearest read of the east road. `d` is more ceremonial (stepped platform, candelabra) but tighter on the seat. All four windows are six-lobe. |
| 2 unsealing-mirror-queue | a, **b ← James** | **`b`, decisively.** `a` reproduces the treatment James rejected — the crowd restarts inside each lobe. `b` changes the window's architecture to six tall lancets under one arch, so a single row crosses all six at one height with the mullions passing in front of it. One queue, seen once — 「窗中站滿一排『你』」 literally. Six panes, correct count. |
| 3 unsealing-monuments-push | a | **Clean.** Monuments straightening into walkers along the road, hands on the stone, gold seam, all backs to us; half-sunk stones still crooked in the foreground. |
| — unsealing-door-open | a | **Derived, not rendered** — crop `(600, 0, 1536, 624)` of plate 3 resampled to 1536×1024, per §8. The door's relief of hooded figures pushing rhymes with the real queue beneath it. ~1.6× upsample, soft but sound under a dialogue band. |
| 4 act4-node1 | a, **b ← James** | **Fork.** `a` has the richer light but fills its six lobes with haloed saints — generic cathedral iconography, not the six shards. `b` fixes that (six abstract amber panes, correct count, hooded relief on the sealed door, monuments that read as grave markers) but its light reads as coming *from* the window, so the inversion — the whole grammar of Act IV — goes missing. |
| 5 act4-node2 | a, **b ← James** | **Fork, and the two trade different things.** `a` is canon-true on motif — broken gold ring, stars doubled in the floor — and sits properly in the indigo/violet palette, but it is **symmetric**, against the bar James set, and its monuments are indistinguishable from the architecture. `b` fixes both: camera off the left edge, a single colonnade sweeping right to an off-centre vanishing point, rough-hewn monuments legibly distinct from the smooth pillars, light from the vanishing point rimming near edges and throwing shadows forward. The cost is colour — `b` is nearly monochrome gold-on-black and reads as polished stone rather than glass. |
| 6 act4-node3 | a | **Clean.** Water as ceiling with books rising into it, drowned shelves, green false lanterns against the one true amber from the far end, shadows thrown forward. |
| 7 act4-node4 | a, **b ← James** | **Fork, and the sharpest one.** `a` is the prettier picture but it is just the Ash Wood — the canopy is ordinary branches and nothing is inverted. `b` lands it: a ceiling of hanging roots and clotted soil, trunks growing downward, ash rising. `b` is stranger and less classically pretty; it is the only one of the two that is Act IV. |
| 8 act4-node5 | a | **Clean, and the best plate of the nine.** The gate is unmistakably a fireplace mouth at cathedral scale — the reveal that 金城=爐邊真貌 is carried by the architecture itself. Queue with chest-lights, cloud sea, monuments. Deviation: the queue reads as walking toward camera rather than away, and the lights are held in hands rather than at the chest. |
| 9 finale-swap | a | **Clean.** The swap reads at a glance: sitting figure near/right/cold, walking figure far/left/dissolving into gold. Background window measures five lobes — the only one in the set that is not six, at a size where the tracery barely resolves. |

### Counting the lobes

**There is no six-lobe problem. An earlier revision of this file claimed one and
was wrong** — James caught it on 2026-08-16, and the counts below are measured
off 4× crops of the window region rather than read off the contact sheet, which
is how the error was made in the first place.

| Plate | Tracery | Count |
|---|---|---|
| `opening-hearth-a` | round, petals round a hub | **6** |
| `opening-hearth-b` | round, petals round a central ring | **6** |
| `act4-node1-b` | round, petals round a hub | **6** |
| `unsealing-mirror-queue-b` | six lancets under one arch | **6** |
| `finale-swap-a` | round, background element | 5 |

Five of the six windows in the set are correct. Only the finale's background
rose is five, at a size where the tracery is barely resolved; it needs no action
unless James wants one.

The lesson is not about the generator. A count asserted from a downscaled view
is an inference wearing the grammar of a measurement — the crops cost one
command and would have prevented three documents carrying the wrong number.

## Payload

Measured, not estimated. 256-colour median-cut with Floyd–Steinberg dither, then
`optimize=True`:

| Plate | RGB | 256-colour | Cut |
|---|---|---|---|
| `act4-node5-a` | 2.90 MB | 1.05 MB | 64% |
| `opening-hearth-a` | 2.44 MB | 1.24 MB | 49% |

Inspected at full size: the sunset gradient and the cloud sea in `act4-node5`
survive with no visible banding, which is the hardest case in the set. Nine
plates go from ~24 MB to ~10 MB on a 135 MB payload. **Quantize on the way into
`assets/art/scenes/`, not in `candidates/`** — the candidates stay lossless so a
re-crop or an edit pass never compounds.
