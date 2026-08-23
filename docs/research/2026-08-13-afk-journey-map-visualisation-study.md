# AFK Journey visualisation study — the map surface

**Scope:** decision input for [#207](https://github.com/fol2/glassvow/issues/207)
("Map visual direction — the AFK Journey bar applied to the map surface"), not
the direction decision itself. Commissioned 2026-08-13 from the #85 re-grill.

**Evidence rule.** Every claim below carries one of five labels and its
citation:

| Label | Meaning |
|---|---|
| **VERIFIED** | A fact-checker read the primary source and the quoted text matches. |
| **CORRECTED** | Verified, but the original research claim overreached; the correction is stated inline. |
| **REFUTED** | The fact-checker found the claim false. Kept visible, never silently dropped. |
| **UNVERIFIABLE** | Only non-independent aggregators repeat it; treat the number as unsourced. |
| **UNSOURCED** | No source found. Usually an assumption someone brought to the study. |
| *Estimate* | Arithmetic or engineering judgement by this study, not measured on hardware. |

Four research lenses fed this document — art anatomy, camera/depth technology,
map storytelling, the Godot 4.7 2D toolbox, the mobile envelope, and a local
inventory of the current map code. Every lens except the local inventory was
independently fact-checked; the corrections are folded in below rather than
appended.

---

## 1. Executive summary

1. AFK Journey's look is a **real-time 3D scene** under a near-orthographic
   long-lens top-down camera ([GameRes 905985](https://www.gameres.com/905985.html)),
   built by ~190 full-time staff ([GamesBeat](https://gamesbeat.com/how-afk-journey-aims-to-make-anime-into-a-global-art-style/))
   at a **30 fps mobile default** inside a <4 GB package ([GameRes 905985](https://www.gameres.com/905985.html)).
   None of that pipeline is available here, and copying it is not the proposal.
2. What transfers is the **perceptual recipe**, and it is measurable: region
   identity carried by hue rotation at held value and saturation; a bright
   desaturated stage inside a dark saturated surround (V=0.68/S=0.15 against
   V=0.35/S=0.38–0.52); aerial perspective by saturation loss and hue cooling at
   **constant value**. All three are palette-and-shader work costing zero payload.
3. Three ingredients commonly attributed to the look are **unsourced** and should
   not be bought: rim/bounce lighting (the store-screenshot rim is marketing
   compositing), tilt-shift/depth-of-field miniature, and parallax-scrolled 2D
   backdrop layers. No source supports any of the three.
4. The floor device is **iPad 8, not iPhone SE 2**: 3.50 Mpx on an A12 against
   1.00 Mpx on the faster A13. Alpha blending defeats hidden-surface removal on
   Apple's TBDR lineage, so N full-screen painted layers cost N× fragment work
   essentially unmitigated ([Imagination](https://docs.imgtec.com/starter-guides/powervr-architecture/html/topics/rules/do-not-use-alpha-blend-unnecessarily.html)).
5. *Estimate:* ≤4 screen-covering alpha-blended layers on iPad 8, backmost
   authored **opaque**, and zero per-layer full-screen post shaders.
6. The payload trap is **import mode, not resolution**: Godot's Lossy mode keeps
   RGBA8 in VRAM. VRAM Compressed (ASTC 4×4, 8 bpp) is mandatory, and 2048-wide
   cannot cover iPad 8's 2160 px landscape — 3072-wide is the honest minimum.
7. **Zero map art ships today.** `assets/art/map/` does not exist. `MapStrip`
   (`fetch` / `draw_tiled`, skyband and region kinds) retired with SkyBand and
   RegionBand in #234 slice 7b2 — PNG assets were not deleted (separate
   decision). Veil motes still draw via `SkyField.disc()`.
8. Three packages: **Colour Script** (0 MB, palette + one shader), **Painted
   Horizon** (~45–50 MiB *estimate*: sky, far silhouette, one singular landmark
   per act), **Painted World** (~150 MiB *estimate*, every plane painted, above
   the floor-device layer budget).
9. Recommendation: land **Colour Script** first as a revertible commit. It is
   free, it is falsifiable against the measured AFK numbers, and it is the only
   honest test of whether painted art is needed at all — then buy pixels where
   the grade demonstrably fails.
10. The calls that are not technical: the iOS download ceiling, whether the map
    is a *painting* or *stained glass*, and whether the map surface may run at
    30 fps while combat holds 60.

---

## 2. How AFK Journey does it

### 2.1 What the style is called — two names, not one

**VERIFIED.** The lead art designer calls it the **Canvas Art Style**: "We call
it the Canvas Art Style, as we want to evoke the feeling of looking at a
beautiful painting. We also wanted to balance the environmental art somewhere
between realistic and painterly" — Silver, Lead Art Designer
([GameRant](https://gamerant.com/afk-journey-art-interview/), 2024-06-01).

**VERIFIED.** The CPO calls it the **"Magical Storybook" style**: "We've been
trying to give it a name, and internally we often refer to it as the 'Magical
Storybook' style" — Xiaodong Tian, CPO of Lilith Games and Farlight Games
([GamesBeat](https://gamesbeat.com/how-afk-journey-aims-to-make-anime-into-a-global-art-style/),
2024-06-02). Chinese coverage renders it 魔法绘本风
([GameRes 910615](https://www.gameres.com/910615.html)).

**CORRECTED.** Neither is an "official" published style-guide term. Two internal
labels one day apart, and Tian's own phrasing ("we've been *trying* to give it a
name") says the team had not settled. *Inference for us:* there is no canonical
recipe to conform to. The bar is a *read*, not a spec — which is good news,
because it means partial adoption is legitimate rather than half-hearted.

### 2.2 The reference set — and why it matters here more than usual

**VERIFIED.** "Our art team drew inspiration from murals, stained glass,
illustrated books, and much more" — Jiangyuan He, Producer
([Google Play editorial](https://play.google.com/store/apps/editorial?id=mc_games_editorialmd_best_game_afk_journey_interview_fcp)).
The same page names specific techniques: gold filigree in murals and Chinese
paintings, foil stamping and lamination in books. *Caveat:* first-party promo
hosted by the storefront — primary, but not independent.

*Inference, and the most useful single finding in this study:* **stained glass
is already in AFK Journey's own reference set**, and it is glassvow's native
idiom (`presentation/combat/glass_style.gd`, the night-glass palette the map
brief builds on). Large flat colour areas divided by outlined leading is the
mechanism both share. The distance between the two looks is smaller than the
words "painterly" and "procedural glass" suggest.

### 2.3 Painterly texture treatment

**VERIFIED.** The art-side rule is colour-block drawing: 「以色块对结构进行区隔和
描绘，同时在必要的地方填充了丰富的纹理细节」— colour blocks separate and describe
structure, texture detail is filled in only where necessary
([17173](https://news.17173.com/content/08132024/101501449.shtml)).

**VERIFIED.** Cohesion is held by "soft brushstrokes and a clever palette"
([GameRes 910615](https://www.gameres.com/910615.html)).

**CORRECTED — the hybrid-rendering claim is narrower than it is usually quoted.**
The often-cited "hybrid of physically-based and stylized rendering" is stated of
**characters only**: 「游戏内角色采用基于物理渲染和风格化渲染相结合的方案」. The
famous framing 「原画设计都是静态的、平面的，但是游戏却是三维的」 is also in the
character section. Only the third clause — 「技术团队在2D绘本和三维空间的风格化中
寻找平衡点」 — is about scenes
([GameRes 905985](https://www.gameres.com/905985.html), an interview with the
**technical** team, not the art leads of §2.1–2.2). Do not cite "AFK Journey
renders its world with hybrid PBR" — the source does not say that.

### 2.4 Colour scripting per region — the transferable core

**VERIFIED (measurement on official store art).** Region backdrops rotate **hue**
while holding value and saturation nearly constant: grassland ≈220° S=0.11
V=0.74; tundra ≈101° S=0.08 V=0.77; desert ≈42° S=0.23 V=0.68 — ~180° of hue
rotation across regions at V 0.68–0.77, S 0.08–0.23
([Google Play screenshots](https://play.google.com/store/apps/details?id=com.farlightgames.igame.gp)).

**VERIFIED.** The engine side is a day-night system with 「内嵌24小时光照和环境
色带的环境系统配置，方便美术自由调整」 — an embedded 24-hour lighting and
*environment colour-band* configuration artists tune freely
([GameRes 905985](https://www.gameres.com/905985.html)).

**VERIFIED.** Contrast was deliberately lowered relative to AFK Arena's
高对比度的颜色, for 护眼 (eye-friendliness)
([17173](https://news.17173.com/content/08132024/101501449.shtml)).

*Caveat on all pixel measurements in this study:* they are sampled inside the
gameplay viewport of **official store screenshots**, which are marketing
composites. They are directionally strong and numerically approximate.

### 2.5 Saturation / value structure — the lit stage

**VERIFIED (measurement).** On the forest map shot: canopy V=0.35 S=0.38–0.52;
the lit clearing the party stands on V=0.68 S=0.15 — roughly **2× the value at
⅓ the saturation**, i.e. a bright *desaturated* stage cut into a dark
*saturated* surround
([App Store listing](https://apps.apple.com/us/app/afk-journey/id1628970855)).

*Inference:* this is a composition rule, not a lighting rule, and it is the one
that most directly buys "the eye knows where to look". It is free to implement:
it is a choice about where saturation goes.

### 2.6 Atmospheric perspective — carried by saturation, not value

**VERIFIED (measurement).** Far canopy S=0.38 hue 193°, near canopy S=0.52 hue
205°, **both at V=0.35** — distance is carried by saturation loss and hue
cooling with value held ([App Store listing](https://apps.apple.com/us/app/afk-journey/id1628970855)).

**VERIFIED (mechanism).** 「除了高度雾、距离雾外，还增加了根据不同区域变化的云投影，
为场景营造空间感」— height fog, distance fog, plus per-region-varying cloud
projection, explicitly to create 空间感
([GameRes 905985](https://www.gameres.com/905985.html)).

**CORRECTED.** 云投影 is literally "cloud projection"; "cloud *shadow*
projection" is a reasonable but unstated reading. And the source never says the
fog was added *because* the camera is near-orthographic — that causal tie is
adjacent-context inference.

*Inference for a 2D port:* the measured rule (saturation down, hue cools, value
held) is exactly what a per-band `COLOR.rgb` mix toward a fog tint does, and it
is the cheapest ingredient in this entire study.

### 2.7 Shape language

**VERIFIED (observation).** Conifers as flat wedge silhouettes, flower fields as
interlocking dab masses, cliffs as stacked slabs, no small silhouette noise.

**CORRECTED.** The tooling claim is authoring-time, not runtime: 「借助自动化工具
和自动化流程，团队让地图自动生成悬崖、海岸线、草地、植被、水流向及spline等元素」
— *automated authoring tools*, not procedural generation at play time
([GameRes 905985](https://www.gameres.com/905985.html)). "The world is
procedurally generated" would be a misreading.

**VERIFIED.** Local variety is narrative rather than formal: Rusty Anchor Port
uses patched paving and 偏灰偏暗 sea-weathered materials; Cedar Town uses
巨大的齿轮与铁铸的烟囱 and exploits 高低差 for layering
([GameRes 910615](https://www.gameres.com/910615.html)).

### 2.8 The camera — and why none of it ports

**VERIFIED.** 「视角效果接近正交的长焦相机」— a top-down long-focal-length
perspective camera whose *effect* approaches orthographic. **CORRECTED:** the
source says this made some 「基于视线方向的物理算法」 (physics algorithms)
「难以直接使用」 — "hard to use directly". It does not say "shading", and it does
not say "broke" ([GameRes 905985](https://www.gameres.com/905985.html)).

**VERIFIED.** Framing is portrait ~45° 2.5D with fully 3D assets: 「在竖屏45°2.5D
视角下，选择了将角色、环境全面3D动态化」
([GameRes 900338](https://www.gameres.com/900338.html)). **CORRECTED:** the
often-paired "moved off Cocos" half is **not** in that source — it comes from
Cocos's own material about AFK Arena, and should be cited there or dropped.

**VERIFIED quote, mechanism UNSOURCED.** "we incorporated a 'rolling log' effect
to maintain the distinct top-down perspective while providing a sense of
smoothness" — Tian
([VentureBeat](https://venturebeat.com/games/how-afk-journey-aims-to-make-anime-into-a-global-art-style/)).
No mechanism is described anywhere. Reading it as cylindrical world-bending is
**pure inference**, and the phrase is a translator's rendering of an unknown
Chinese term, not a term of art.

**VERIFIED.** Everything is authored for that camera: 「基于俯视角远距离去设计」,
which made close flat cinematography unusable and pushed story scenes onto a
separate cinematic camera
([4Gamers](https://www.4gamers.com.tw/news/detail/66318/afk-journey-interview)).

*Inference:* glassvow's map is a horizontally scrolled side-on parallax stage.
Nothing in §2.8 has an attach point. It is listed so the grilling can retire it
explicitly rather than leave it as unfinished business.

### 2.9 Engine and budget context

**VERIFIED, weakly.** Unity + IL2CPP with Lua for gameplay logic — from a single
anonymous reverse-engineering forum post
([Fearless Revolution](https://fearlessrevolution.com/viewtopic.php?t=28412),
2024-04-01). No Lilith/Farlight statement names the engine; Wikipedia lists none;
there is no second independent teardown. Render pipeline (URP vs custom SRP) is
**UNSOURCED**.

**VERIFIED.** Default **30 FPS** on mobile with per-device tiering from a
proprietary device database; map data under 500 MB; total mobile package under
4 GB; animation data compressed ~50%
([GameRes 905985](https://www.gameres.com/905985.html)).

**VERIFIED.** ~190 full-time staff on development and publishing
([GamesBeat](https://gamesbeat.com/how-afk-journey-aims-to-make-anime-into-a-global-art-style/)).

*This is the honest frame for the whole decision.* The anchor ships at half our
frame-rate floor, with an art budget three orders of magnitude past ours, on a
pipeline we do not have. The rubric anchor is a **quality read**, not a
production model.

### 2.10 What AFK Journey does NOT do (and we should therefore not buy)

- **Rim / bounce lighting as a named technique — UNSOURCED.** The only
  lighting-pipeline statements found are improved 面部阴影着色方案 (facial shadow
  shading) and cross-environment character-lighting consistency
  ([GameRes 905985](https://www.gameres.com/905985.html)). The bright
  yellow-green rim on hero cut-outs in store screenshots is **marketing
  compositing, not in-world lighting** — do not treat it as evidence.
- **Tilt-shift, depth of field, or a miniature-diorama post-process —
  UNSOURCED.** No dev interview, teardown, or settings documentation mentions
  any of them for the world map.
- **Parallax-scrolled 2D backdrop layers — NOT SUPPORTED by any source.** The
  map is a live 3D scene. *Inference with teeth:* the technique glassvow would
  actually be using is **not** the technique that produces the reference look.
  We are reproducing the *output*, and we should judge the result against
  screenshots rather than against a process description.

### 2.11 Map storytelling — what the surface carries (interlocks with #175)

**VERIFIED.** Reaching a specific exploration-progress milestone in an area
removes the **Miasma** shrouding it, and region-wide totals unlock extra rewards
([afk.guide 1.0.11 patch notes](https://afk.guide/afk-journey-v1-0-11-patch-notes/)).
The device is diegetic — clearing the map *is* healing the world — which makes
reveal earned rather than mechanical.

**VERIFIED.** Patch 1.0.11 **reset world exploration progress for everyone** —
rewards, monsters, puzzles, Miasma, Keith's Store — onto a new World map
(same source). Seasons run roughly every four months, each with a new storyline
and new areas
([MMORPG.com](https://www.mmorpg.com/reviews/afk-journey-review-heroes-guilds-and-gacha-should-you-invest-your-time-2000131159)).

**VERIFIED.** Purple way stones activate as permanent fast-travel anchors —
a visible ledger of ground covered
([PocketGamer review](https://www.pocketgamer.com/afk-journey/review/)).
Exploration surfaces guarded chests, boulder puzzles, caves, comedic townsfolk
([PocketGamer preview](https://www.pocketgamer.com/afk-journey/preview/)).

**CORRECTED.** "Story Quests follow Merlin across regions, split Main/Side" is
substantiated only by the **fan wiki and guide sites**, not by any developer
source — the originally cited game8 page says nothing of the kind. Do not
present it as a studio statement.

**CORRECTED.** The producer's line is "we struck a successful balance between
idle progression and open-world exploration"
([PocketGamer.biz](https://www.pocketgamer.biz/the-nuance-of-a-successful-sequel-balancing-familiarity-and-refreshing-experiences-in-afk-journey/))
— retrospective framing of why the game succeeded, not a stated design *pillar*,
and the source says nothing about AFK Stages and the map being separate tracks.

**REFUTED.** The commonly repeated region list is partly wrong. **"Lucent
Plains" does not exist** (there is a Lucent Tree inside the Dark Forest, and a
"Lucent's Lament" chapter); **"Holistone Peaks" does not exist** (Holistone is a
hub town; "Peaks" is bled over from Remnant Peaks). Attested regions: Golden
Wheatshire, Dark Forest, Remnant Peaks, Vaduso Mountains, a Desert Region, and
the Ashen Wastes
([AFK Journey wiki](https://afk-journey.fandom.com/wiki/Starter_Story/Exploration)).

**CORRECTED.** In the desert-region description, "seven endemic species" is a
counter's arithmetic, not a stated figure, and the **Warsong Festival belongs to
the Ashen Wastes' Mauler culture**, not the desert
([BlueStacks](https://www.bluestacks.com/blog/game-guides/afk-2-journey/afkj-desert-region-map-guide-en.html)
— an emulator-vendor marketing blog, not a primary source).

**UNSOURCED.** Landmark composition as "destination promise" (distant
silhouettes framed to pull the player forward), classic minimap fog-of-war, and
a zoomed-out continental chapter-framing screen. *Note:* the destination-promise
device is nonetheless already glassvow's design — the horizon Spire that grows
each act (`docs/map-concept-brief.md` §1). It is simply not something AFK
Journey is on record as doing.

**VERIFIED (the counter-evidence).** Reviewers report the open world's seams:
invisible barriers, getting stuck on obstacles, areas that cannot be entered
despite the open-world framing
([Hardcore iOS](https://hardcoreios.com/afk-journey-review/),
[PocketGamer preview](https://www.pocketgamer.com/afk-journey/preview/)).
*Inference:* the anchor is not flawless, and glassvow's constrained, authored,
non-walkable map is not automatically the poorer surface.

---

## 3. The ingredient table

Column meanings: **Attach point** cites the current code (`file` (`symbol`) form,
which does not rot) or says NO PATH EXISTS. **Floor cost** is against iPad 8, the
binding device. **Payload** is shipped bytes. All costs marked *estimate* are
arithmetic or judgement, not measured on hardware.

The device arithmetic behind every "floor cost" cell:

- iPhone SE 2 — 1334×750 = **1.00 Mpx**, A13
  ([Apple](https://support.apple.com/en-us/111882)); iPad 8 — 2160×1620 =
  **3.50 Mpx**, A12 ([Apple](https://support.apple.com/en-us/118451)).
  **CORRECTED:** A12 is ~15–25% slower than A13 (Apple claims A13 GPU +20%); the
  "30% slower" figure sometimes quoted is unsourced.
- At 60 fps one full-screen layer costs 60 Mpx/s on SE 2 and **210 Mpx/s on
  iPad 8**. iPad 8 is the binding target by a wide margin.
- Alpha blending defeats hidden-surface removal on PowerVR-lineage TBDR:
  "Disable alpha blending wherever possible… keep the number of transparent
  objects to a minimum"
  ([Imagination](https://docs.imgtec.com/starter-guides/powervr-architecture/html/topics/rules/do-not-use-alpha-blend-unnecessarily.html)).
  Godot concurs: "Transparent objects are also particularly bad for fill rate,
  because every item has to be drawn even if other transparent objects will be
  drawn on top later on"
  ([godot-docs](https://github.com/godotengine/godot-docs/blob/master/tutorials/performance/gpu_optimization.rst)).
- **UNVERIFIABLE:** the widely repeated "LPDDR4X-4266, 34.1 GB/s" for A12/A13
  traces only to non-independent spec aggregators. Safe framing: both are
  LPDDR4X on a 64-bit bus, roughly 30–35 GB/s class, and **iPad 8 is not
  bandwidth-advantaged despite its larger framebuffer**.
- *Estimate:* bandwidth is therefore **not** the wall — 5 blended ASTC layers +
  UI on iPad 8 is ~1.3 GB/s of texture reads against ~30–35 GB/s available, and
  blending resolves in on-chip tile memory. The wall is **fragment invocations
  and blend rate**.
- *Estimate (the budget line this study recommends):* **≤4 screen-covering
  alpha-blended layers on iPad 8, ≤6 on SE 2, backmost authored opaque, zero
  per-layer full-screen post shaders** — fold grain and grade into one final pass.

| # | Ingredient | AFK Journey mechanism | Godot 4.7.1 2D technique (exact API) | Attach point in the current map | Floor cost (iPad 8) | Payload | Risk |
|---|---|---|---|---|---|---|---|
| 1 | **Painterly colour-block texture** | 色块 structure, spot texture, soft brushstrokes ([17173](https://news.17173.com/content/08132024/101501449.shtml), [GameRes 910615](https://www.gameres.com/910615.html)) | Authored raster only. `Texture2D` via `MapStrip.fetch` → `MapStrip.draw_tiled` (`CanvasItem.draw_texture_rect`). Import **VRAM Compressed** (ASTC 4×4), never Lossy | **RETIRED** — `MapStrip.fetch` / `draw_tiled` and SkyBand/RegionBand `apply_region` strip loaders deleted in #234 slice 7b2. PNGs not deleted (separate decision); `assets/art/map/` still does not exist. 3D ground is `map_ground.gdshader` | 1 full-screen blend per painted band; sky band can be authored opaque → free of blend | 5.06 MiB/layer at 3072×1728 ASTC 4×4; +33% with mips (*estimate*) | Art-production risk, not engine risk. #87 records two generation rounds that produced synthesis, not art |
| 2 | **Per-region hue-rotation colour script** | 环境色带 (environment colour band) + 24 h lighting, artist-tunable ([GameRes 905985](https://www.gameres.com/905985.html)). Measured: hue rotates ~180°, V 0.68–0.77 and S 0.08–0.23 held ([Play](https://play.google.com/store/apps/details?id=com.farlightgames.igame.gp)) | Pure data. Extend the per-act palette table; no new API needed. Optionally `Color.from_hsv` at load | **EXISTS** — `presentation/map/world_map_screen.gd` (`_set_act_theme`) and (`set_act_scenery`), fed by `presentation/map/map_regions.gd` | Zero | Zero | Low. Only risk is the act palettes are currently value-differentiated, not hue-differentiated — this is a rework, not an addition |
| 3 | **Bright desaturated stage in dark saturated surround** | Measured V=0.68/S=0.15 clearing against V=0.35/S=0.38–0.52 canopy ([App Store](https://apps.apple.com/us/app/afk-journey/id1628970855)) | Composition rule expressed in the same palette table + the existing ground scrim `draw_rect` and marker glow | **PARTIAL** — PathBand `_draw_bed` / `_draw_ramp` retired in #234 slice 7b2 with the 2D road; live marker glow remains in `presentation/map/map_band.gd` (`_draw`). 3D ground is the cel shader | Zero | Zero | Low. Conflicts with the current "everything is dark night-glass" grade — this is the change that most alters the map's felt identity |
| 4 | **Aerial perspective by saturation loss + hue cooling at constant value** | Measured far S=0.38 h193° vs near S=0.52 h205°, both V=0.35 | `shader_type canvas_item; render_mode unshaded;` mix `COLOR.rgb` toward a fog tint by a per-band `uniform float depth`. Zero extra passes | **NO SHADER PATH YET** on the 2D overlay. `WorldMapScreen.depth_of` retired with 2D seating in #234 slice 7b2. Live: `presentation/map/map_band.gd` (`set_view`) still carries cam-x and drift for the veil. 3D grade is `map_ground.gdshader` / `map_prop.gdshader` | ~3–5 ALU per pixel per band, no new layers, no new blends | Zero | Low. Uniform plumbing through `set_view` is the whole job |
| 5 | **Height fog / distance fog / cloud projection** | Height fog + distance fog + per-region 云投影 「为场景营造空间感」 ([GameRes 905985](https://www.gameres.com/905985.html)) | Same shader as #4 with a vertical gradient term; cloud projection as one slow-scrolling multiply strip or a shader `sin`-warp on the region band | **PARTIAL** — sky-band fog disc retired with SkyBand in #234 slice 7b2. Live: `SkyField.disc()` in `presentation/map/map_band.gd` (`_draw`) (VeilBand motes / storm streaks). A cloud-projection `MapStrip` kind is moot: `MapStrip` retired in 7b2 | Fog term: free (same pass as #4). A separate cloud strip: +1 full-screen blend — counts against the ≤4 budget | Fog: zero. Cloud strip: 5.06 MiB/act (*estimate*) | Medium — a scrolling multiply strip is exactly the "visible repetition" defect measured on #87 round 1 (motif recurring every ~300 px on a 606 px draw) |
| 6 | **Day-night / time-of-day arc** | 昼夜系统 with 24 h ramp, artist-tunable ([GameRes 905985](https://www.gameres.com/905985.html)) | Would be a `Tween` or run-clock driving the same palette table + shader uniforms | **NO PATH EXISTS** — the act palette is applied once per act; nothing carries a continuous clock to the bands | Free if it drives existing uniforms | Zero | **Recommend DROP.** A ~20-minute run across three fixed acts has no room for a 24 h arc; the acts already are the arc |
| 7 | **Region-scripted weather** | Per-region weather shifting light colour, lowering light/shadow contrast, changing vegetation sway frequency and amplitude, 随机频闪+雷声 ([GameRes 905985](https://www.gameres.com/905985.html)) | Already the design. `CPUParticles2D`/`GPUParticles2D` would be the idiomatic upgrade; note `emit_particle()` is Forward+/Mobile only, and `amount_ratio` gives **no** perf benefit ([GPUParticles2D docs](https://github.com/godotengine/godot-docs/blob/master/doc/classes/GPUParticles2D.xml)) | **EXISTS** — `presentation/map/map_band.gd` (`_draw`) VeilBand draws 128 disc quads / storm streaks. Act-2 lightning (`set_flash`, `_step_lightning`, `MapRegions.LIGHTNING_*`) retired with the sky/region bands in #234 slice 7b2 — deliberate, no 3D successor in this slice | Veil is already the most expensive band (parallax 1.35, ungated, 128 quads). *Estimate:* fine on SE 2, needs measuring on iPad 8 | Zero | Low — this ingredient is the one glassvow already matches |
| 8 | **Shape language (flat wedges, stacked slabs, no small noise)** | Enforced by shared authoring tools ([GameRes 905985](https://www.gameres.com/905985.html)) | `draw_polygon` / `Polygon2D` / `MeshInstance2D` (faster than a `Sprite2D` with large transparent areas) | **RETIRED** — act-0 tree polygons and sunken shafts (`_draw_shafts`, RegionBand `_draw`) deleted with RegionBand in #234 slice 7b2. 3D placeholder modules (wedge / slab / dab) live on `MapScene` | Vertex work, negligible | Zero | Low. This is where the procedural map is already closest to the anchor |
| 9 | **Singular landmark composition** | Giant stone sword etc. as single high-value silhouettes against a saturated bed | An untiled, world-anchored `draw_texture_rect` — a `MapStrip.draw_single` sibling to `draw_tiled`, plus a placement contract | **NO PATH** — issue [#85](https://github.com/fol2/glassvow/issues/85). `_draw_spire` and `_draw_rose_window` retired in #234 slice 7b2 with SkyBand / the 2D path bed (#207/#232: Spire retired game-wide). `MapStrip` itself retired in 7b2 | 1 small blended quad; not full-screen | ~2.25 MiB/act at 1536×1536 ASTC (*estimate*) | Medium. `FAR_BLEED` overdraw retired with the far bands |
| 10 | **Avatar tiny inside a light hole** | Party ~4% of frame height in a lit clearing inside a dark field | Composition + the existing marker glow | **EXISTS** — waystone rings and glow in `presentation/map/glass_waystone.gd`; raster-on-`Control` is already proven there (a `TextureRect` over procedural `_draw` rings) | Zero | Zero | Low |
| 11 | **Progressive reveal (Miasma analogue)** | Exploration-% milestone dissolves the Miasma; diegetic ([afk.guide](https://afk.guide/afk-journey-v1-0-11-patch-notes/)) | Cheap version: one `uniform float cleared` into the #4 shader, driving saturation/haze per band. Expensive version: a second painted variant per band per state | **PARTIAL.** Per-node reveal exists (`presentation/map/glass_waystone.gd` (`kindle_reveal`), walked-edge recolour, depth alpha). **Scenery: NO PATH** — bands see progress only at act granularity; `map.at` and the cleared set never reach sky/region/veil | Shader version: free. Painted-variant version: **doubles** the strip payload | 0 MiB or +100% of the strip budget | Medium — the shader version is nearly free and should be the default answer |
| 12 | **Rim / bounce lighting** | **UNSOURCED as a technique.** Store-screenshot rim is marketing compositing | Would need `PointLight2D` + `CanvasTexture` normal maps, which require a `Light2D` present and raised light Height ([Godot 2D lights](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)) | **NO PATH EXISTS** — no `PointLight2D`/`CanvasModulate`/`LightOccluder2D` anywhere in the repo; bands are Control-space `_draw` with baked alpha, and real Light2D needs Node2D-space children plus `light_mask` | "Larger lights have a higher performance cost as they affect more pixels"; additive `Sprite2D` fakes render "much faster" than real 2D lights ([same](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)) | Normal maps would double every texture | **DROP.** Unsourced in the anchor, no path here, and the cheap fake is already what the map does |
| 13 | **Tilt-shift / DoF miniature** | **UNSOURCED.** No source mentions either for the world map | Would need `hint_screen_texture` + `BackBufferCopy` ([screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)) | **NO PATH EXISTS** | A backbuffer copy per region on a tiler; Godot's Mobile renderer sub-passes explicitly constrain glow and depth of field | Zero | **DROP** |
| 14 | **Near-ortho long-lens camera / "rolling log"** | Verbatim quote, mechanism undescribed ([VentureBeat](https://venturebeat.com/games/how-afk-journey-aims-to-make-anime-into-a-global-art-style/)) | `Node2D.skew` and `CanvasLayer.follow_viewport_scale` are the documented pseudo-3D knobs; `MeshInstance2D` for free-form warp | **NO PATH — and not applicable.** The map is a side-on horizontal parallax stage, not a top-down one. Bands are `Control`s, not `Node2D`s | n/a | n/a | **DROP explicitly**, so it stops resurfacing |

### 3.1 Two toolbox notes that change the answers above

**`Parallax2D` is not the right tool here.** `ParallaxBackground`/`ParallaxLayer`
are deprecated in favour of `Parallax2D`
([Godot docs](https://docs.godotengine.org/en/stable/classes/class_parallaxbackground.html)),
and `Parallax2D` is a `Node2D` with `scroll_scale`, `repeat_size`, `autoscroll`
and camera-rotation support. But glassvow's bands are full-rect `Control`s whose
parallax is already hand-rolled in `presentation/map/map_band.gd` (`set_view`),
with child order as paint order. `FAR_BLEED` overdraw retired with SkyBand /
RegionBand in #234 slice 7b2. Adopting `Parallax2D` is a rewrite of a working
system for no new capability. *Recommendation: keep the hand-rolled band parallax.*

**`SubViewport` baking is the escape hatch nobody has costed.** A `SubViewport`
with `render_target_update_mode = ONCE` renders an image once and reuses the
texture "without incurring the cost of rendering every frame"
([Using Viewports](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html)).
*Inference:* a procedurally composed band could be baked once per act into a
texture, converting per-frame `_draw` cost into a one-off. This is the cheapest
route to "more procedural detail than 60 fps would otherwise allow", and it
costs zero payload. It is not in any package below because it is an optimisation,
not a direction — but it is the first lever to pull if a package misses the
frame budget.

### 3.2 Payload arithmetic

**VERIFIED (the trap).** Godot's **Lossy** import mode stores lossy WebP *on disk
only* — VRAM is still RGBA8. A 4096×4096 texture with mipmaps costs **85.33 MiB
under Lossless, Lossy and VRAM Uncompressed alike, versus 21.33 MiB under VRAM
Compressed**
([importing_images.rst](https://github.com/godotengine/godot-docs/blob/master/tutorials/assets_pipeline/importing_images.rst)).
Lossy buys download size and buys **nothing** in memory.

**VERIFIED.** Godot 4 implements only **ASTC 4×4 and 8×8**; other block sizes
were judged "too complex to handle for the current Godot image compression code"
([PR #65376](https://github.com/godotengine/godot/pull/65376)). ASTC 4×4 is
exactly **8.00 bits/texel = 1 byte/px**
([ARM](https://chromium.googlesource.com/external/github.com/ARM-software/astc-encoder/+/HEAD/Docs/FormatOverview.md)).

**VERIFIED, with a counter-argument.** Godot warns VRAM compression "should be
avoided for 2D as it exhibits noticeable artifacts" — but the surrounding text
aims that at pixel art and hard-edged UI. For painterly content ARM's own
position is that ASTC "manages to beat nearly all legacy texture compression
formats… on image quality at equivalent bit rates" and its luminance modes
"capture smooth gradients very well" (same ARM source). *Residual risk:* wide,
near-flat gradients band. *Mitigation:* dither the source before encoding, and
verify per asset rather than assuming.

**VERIFIED.** App Store total uncompressed ceiling is 4 GB
([Apple](https://developer.apple.com/help/app-store-connect/reference/maximum-build-file-sizes/));
apps over 200 MB face a cellular-download restriction, user-overridable since
iOS 13 ([9to5Mac](https://9to5mac.com/2019/06/03/ios-13-removes-200-mb-file-size-limit-for-app-downloads-over-cellular/)).
*Inference:* at ~330 MB today the 200 MB cellular line is **already crossed**, so
it is not the marginal constraint. The 4 GB ceiling is far away. What the extra
megabytes actually cost is store-page conversion, not a gate.

**Sizing note that sets the authoring resolution.** iPad 8 landscape is 2160 px
wide, so a 2048-wide layer cannot cover it 1:1. **2048-wide is a phone-only
budget.** *Recommended middle:* **3072×1728 → 5.06 MiB ASTC per full-screen
layer**, ~1.07× vertical downscale on iPad 8, 1.42 screens of horizontal pan.

**Memory ceiling.** Apple documents jetsam per-process limits but publishes no
table ([Apple](https://developer.apple.com/documentation/xcode/identifying-high-memory-use-with-jetsam-event-reports)).
A single community measurement puts a 3 GB iPhone SE at ~900 MB before jetsam
([umurinan.com](https://umurinan.com/pages/posts/ios-memory-mcp-server.html)) —
single-source, approximate. *Estimate:* plan against **~900 MB**, not the ~50%-of-RAM
rule of thumb; engine + scene + audio + OS overhead ~250–400 MB, leaving all
textures ≤ ~400 MB and map parallax ≤ ~120 MB resident.

---

## 4. Direction packages

Each package states what it buys against the AFK Journey bar, the budget, the
engine work (and which existing tickets it activates), and what it deliberately
gives up. All budget figures are *estimates*.

### Package A — **Colour Script** (palette + one shader, zero art)

**What it buys.** Ingredients 2, 3, 4, 5 (fog term only), 8 and 11 (shader
version) — the entire *measurable* half of the AFK Journey read, applied to the
bands that already exist:

- act identity carried by **hue rotation at held value/saturation** rather than
  by brightness (§2.4);
- a **bright desaturated stage** where the path and the active waystone are, cut
  into a dark saturated surround (§2.5);
- **aerial perspective by saturation loss and hue cooling at constant value**,
  as a per-band shader uniform driven by the band's parallax factor (§2.6);
- **progressive reveal** as a `cleared` uniform that lifts saturation and drops
  haze on scenery behind you.

**Budget.** **0 MB payload. 0 MB VRAM.** Fragment cost: one extra
`shader_type canvas_item; render_mode unshaded;` material per band, ~3–5 ALU per
pixel, **no new layers and no new blends** — so the ≤4-layer floor budget is
untouched.

**Engine work.**
1. Push uniforms through `presentation/map/map_band.gd` (`set_view`), which today
   carries only cam-x and drift. `WorldMapScreen.depth_of` retired with 2D
   seating in #234 slice 7b2; 3D grade is the cel shaders.
2. Rework the per-act palette in `presentation/map/map_regions.gd` and
   `world_map_screen.gd` (`_set_act_theme`) from value-differentiated to
   hue-differentiated, with explicit V/S targets taken from §2.4–2.6.
3. One test in `tests/test_map.gd` asserting the per-act palette holds V and S
   inside band and rotates hue — the numbers are measurable, so the gate is real.

**Tickets activated.** None. It **answers** [#87](https://github.com/fol2/glassvow/issues/87)
in the in-band direction (no painted skyband strip, no baked noise — which is
what both failed generation rounds argue for) and leaves
[#85](https://github.com/fol2/glassvow/issues/85) on its POST-1.0 hold.

**What it deliberately gives up.** Painterly texture (ingredient 1) entirely.
Singular painted landmarks (9). The map stays recognisably drawn-by-code: it will
read as *well-graded vector art*, not as *a painting*. Against the rubric's AFK
Journey anchor, this closes the colour and depth gap and does not touch the
surface-quality gap.

**Why it is nonetheless the first commit in every package.** It is free,
revertible, and falsifiable. Landing it produces the only honest measurement of
how much of the gap is grading and how much is pixels — and the answer changes
what B and C are worth.

### Package B — **Painted Horizon** (hybrid painted + procedural) — recommended

**What it buys.** Everything in A, plus ingredients 1 and 9 on the two planes
where painterly texture does the most work per byte:

- **sky band** — a painted `act{N}-skyband.png` (cloud, haze, star field),
  authored **opaque** so it is the backmost layer and costs no blend;
- **region band** — a painted `act{N}-region.png` far skyline silhouette,
  transparent below its skyline, loop-safe;
- **one singular, world-anchored, untiled landmark per act** — the act terminus,
  and optionally a mid-act monument — via a new `MapStrip.draw_single`.

The play plane stays procedural: waystones, path, rose window, chips and veil
keep the night-glass idiom. *Rationale:* those are the surfaces that must stay
legible at phone distance and that already read best; painting them buys the
least and risks the most.

**Budget (estimate).** Height-fitted to the two band rects rather than to a
shared canvas (`MapStrip` ART CONTRACT, retired with the class in #234 slice
7b2: sky ≈ 37% of stage height, region ≈ 65% plus crown bleed):

| Asset | Size | ASTC 4×4 |
|---|---|---|
| `act{N}-skyband.png` | 3072×1152 | 3.38 MiB |
| `act{N}-region.png` | 3072×2048 | 6.00 MiB |
| `act{N}-terminus.png` | 1536×1536 | 2.25 MiB |
| **per act** | | **11.63 MiB** |
| ×3 acts | | 34.9 MiB |
| +33% mipmaps | | **~46 MiB shipped** |

Resident per act ~15.5 MiB — far inside the ~120 MiB map-parallax estimate.
Build ~330 MB → **~376 MB (+14%)**; art 135 MB → ~181 MB.

**Floor-device check.** Full-screen blended layers on iPad 8: region strip (1) +
veil (2). Sky strip is opaque, terminus is a small quad, path/chips are small.
**2 of the ≤4 estimated budget.** Comfortable.

**Engine work.**
1. Package A in full (it is the grade the painted art is authored against — do
   this first or the art will be authored to the wrong target).
2. **Activates [#85](https://github.com/fol2/glassvow/issues/85)** — the singular
   region-plane draw path. `MapStrip.draw_single` / `draw_tiled` and `FAR_BLEED`
   retired with MapStrip / the far bands in #234 slice 7b2; a successor would
   be a 3D landmark, not a 2D strip sibling.
3. **Activates [#87](https://github.com/fol2/glassvow/issues/87)** — decides
   *painted strip*, and thereby re-opens the art-production question that two
   generation rounds failed. #87's own evidence (numpy sine decomposition, visible
   ~300 px repeat, act-3 strip at 22.9% opaque) is the specification for what must
   not happen again.
4. Test gates: **nothing currently tests `draw_tiled`, `MAX_TILES`, or any
   painted strip.** At minimum, assert a strip wider than `MAX_TILES` tiles
   degrades to a gap rather than a draw-call storm, and assert the ART CONTRACT's
   two rect heights.

**What it deliberately gives up.** The mid-ground and play plane stay procedural
— so the map will not have AFK Journey's *uniform* painted surface, and a
screenshot comparison will show the seam between painted horizon and drawn
foreground. Also given up: runtime day-night (ingredient 6), weather-driven light
colour beyond the per-act fixed palette, and painted per-state variants of the
strips (progressive reveal stays the shader uniform from A).

### Package C — **Painted World** (full painted surface)

**What it buys.** The uniform painted surface. Every plane authored per act,
including the mid-ground, plus painted cleared/shrouded variants for a real
Miasma analogue (ingredient 11, expensive version). This is the only package that
can actually be mistaken for the anchor in a still.

**Budget (estimate).** 5 full-screen layers × 3072×1728 (5.06 MiB) × 3 acts ×
1.33 mips ≈ **101 MiB**; add painted cleared-state variants of the sky and region
strips and it lands **~150 MiB**. Build ~330 MB → **~480 MB (+45%)**; art 135 MB
→ ~285 MB, i.e. the art payload more than doubles.

**Floor-device check — this is where it fails.** 5 screen-covering layers is
**above** the ≤4 *estimate* for iPad 8, and only one of them can be opaque. The
mitigations are all product concessions: render the map below native resolution
on iPad, drop the map to 30 fps, or cut a layer on a device tier — which is
precisely what the anchor does (per-device tiering from a proprietary device
database, 30 fps default).

**Engine work.** Everything in B, plus a new `MapBand` subclass inserted in order
at `presentation/map/world_map_screen.gd` (`_init`) — the study cited
`_build_bands`, which retired with PathBand in #156 round 2 once the 3D road
took over drawing the graph — per-band strip
variants keyed on cleared state, a device-tier switch, and — the real line item —
an art pipeline producing and holding style across ~30 large paintings.

**What it deliberately gives up.** The procedural fallback's advantages: zero
payload, instant iteration, and an act-agnostic surface that already ships. It
also gives up schedule certainty, and it is the package most exposed to the
expansion question — if acts 4+ ever ship, C's per-act cost scales linearly at
~34 MiB per new act while A's is zero and B's is ~12 MiB.

### 4.1 Recommendation

**A, then measure, then B.** A is free and revertible and turns the whole
question into a measurement. B is the package whose floor-device and payload
numbers both hold with margin, and it is the one that activates #85 and #87 with
a clear brief rather than reopening them speculatively. C is costed here so the
grilling can reject it on numbers rather than on instinct — and so that, if James
wants it, he is choosing the 30 fps map along with it.

---

## 5. Open questions for the grilling — the calls only James can make

1. **What is the iOS download ceiling, and is "~330 MB" the download or the
   on-disk size?** The whole payload column depends on it. +46 MiB (B) is a 14%
   build growth; +150 MiB (C) is 45%. The 200 MB cellular line is already crossed,
   so this is a store-conversion judgement, not a technical gate — which makes it
   a product call, not an engineering one.

2. **Is the map a painting, or is it stained glass?** The rubric anchors AFK
   Journey, whose own reference set *includes* stained glass (§2.2) — but the
   game's established idiom is night-glass with hard leading and faceted forms,
   and ingredient 1 (soft painterly texture) is the one ingredient that pulls
   directly against it. "AFK Journey's compositional discipline applied to our
   glass idiom" and "AFK Journey's painterly softness" are different products.
   This question decides whether Package A is a stepping stone or the destination.

3. **May the map surface run at 30 fps while combat holds 60?** The anchor ships
   30 fps by default with per-device tiering. The map is a low-input, low-stakes
   surface. Answering yes roughly doubles the floor-device layer budget and makes
   Package C arguable; answering no fixes the ≤4-layer estimate as a hard wall.
   This is an #158-floor amendment, so it needs James, not a measurement.

4. **Progressive reveal — is there a Miasma analogue, and does it come from
   #175?** The shader version (a `cleared` uniform lifting saturation on ground
   already walked) is nearly free. The painted version doubles the strip payload.
   The choice is really "does the map need to *show* healing, or only to show
   distance covered?" — and that is a story question.

5. **Who paints it, and against what?** #87 has two failed rounds on record. If
   the answer is "generated again", the brief must change (the failures were
   synthesis, not generation) and the acceptance test must be the measured
   numbers in §2.4–2.6, not an eyeball. If the answer is "commissioned", that is
   a schedule and money decision that outranks everything else in this document.

6. **What must each act's map surface *tell*?** §2.11 shows the anchor puts
   story in the walkable world, not a menu — glassvow's map already has the
   horizon Spire growing per act as a destination promise. What #175's arc needs
   the surface to carry (a beat per act? residue after a defeat? a character who
   appears on the map?) changes whether ingredient 9's singular landmark is one
   asset per act or several.

7. **Desktop.** The standing constraint is desktop-aware, and 3072-wide is a
   phone/tablet budget. Do we author one set at 3072 and accept softness at
   2560+, or carry a second desktop set (which roughly doubles B's payload and
   is not downloadable-on-demand on iOS)?

8. **Expansion.** If acts 4+ ship as IAP, per-act art cost is the thing that
   scales. A costs nothing per act; B costs ~12 MiB and three paintings; C costs
   ~34 MiB and five. Does the direction need to be cheap to extend, or is the
   base game's three acts the whole surface?

---

## Sources

Art and direction: [GameRant — Silver interview](https://gamerant.com/afk-journey-art-interview/) ·
[GamesBeat — Tian interview](https://gamesbeat.com/how-afk-journey-aims-to-make-anime-into-a-global-art-style/) ·
[VentureBeat mirror](https://venturebeat.com/games/how-afk-journey-aims-to-make-anime-into-a-global-art-style/) ·
[Google Play editorial — He interview](https://play.google.com/store/apps/editorial?id=mc_games_editorialmd_best_game_afk_journey_interview_fcp) ·
[GameRes 905985 — technical team](https://www.gameres.com/905985.html) ·
[GameRes 910615](https://www.gameres.com/910615.html) ·
[GameRes 900338](https://www.gameres.com/900338.html) ·
[17173](https://news.17173.com/content/08132024/101501449.shtml) ·
[4Gamers](https://www.4gamers.com.tw/news/detail/66318/afk-journey-interview) ·
[Zhihu teardown (三渲二)](https://zhuanlan.zhihu.com/p/17994971449) ·
[Fearless Revolution (engine RE)](https://fearlessrevolution.com/viewtopic.php?t=28412)

Storytelling: [afk.guide 1.0.11 patch notes](https://afk.guide/afk-journey-v1-0-11-patch-notes/) ·
[MMORPG.com review](https://www.mmorpg.com/reviews/afk-journey-review-heroes-guilds-and-gacha-should-you-invest-your-time-2000131159) ·
[PocketGamer review](https://www.pocketgamer.com/afk-journey/review/) ·
[PocketGamer preview](https://www.pocketgamer.com/afk-journey/preview/) ·
[PocketGamer.biz](https://www.pocketgamer.biz/the-nuance-of-a-successful-sequel-balancing-familiarity-and-refreshing-experiences-in-afk-journey/) ·
[Hardcore iOS](https://hardcoreios.com/afk-journey-review/) ·
[AFK Journey wiki](https://afk-journey.fandom.com/wiki/Starter_Story/Exploration) ·
[BlueStacks desert guide](https://www.bluestacks.com/blog/game-guides/afk-2-journey/afkj-desert-region-map-guide-en.html)

Godot: [Parallax2D](https://docs.godotengine.org/en/stable/classes/class_parallax2d.html) ·
[ParallaxBackground (deprecated)](https://docs.godotengine.org/en/stable/classes/class_parallaxbackground.html) ·
[canvas_item shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html) ·
[screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html) ·
[2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html) ·
[CanvasGroup](https://docs.godotengine.org/en/stable/classes/class_canvasgroup.html) ·
[SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html) ·
[Using Viewports](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html) ·
[GPU optimization](https://github.com/godotengine/godot-docs/blob/master/tutorials/performance/gpu_optimization.rst) ·
[importing_images](https://github.com/godotengine/godot-docs/blob/master/tutorials/assets_pipeline/importing_images.rst) ·
[renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) ·
[ASTC PR #65376](https://github.com/godotengine/godot/pull/65376)

Hardware and store: [Apple — iPhone SE 2](https://support.apple.com/en-us/111882) ·
[Apple — iPad 8](https://support.apple.com/en-us/118451) ·
[Notebookcheck — A13 GPU](https://www.notebookcheck.net/Apple-A13-Bionic-GPU.434833.0.html) ·
[Imagination — alpha blend](https://docs.imgtec.com/starter-guides/powervr-architecture/html/topics/rules/do-not-use-alpha-blend-unnecessarily.html) ·
[ARM — ASTC format overview](https://chromium.googlesource.com/external/github.com/ARM-software/astc-encoder/+/HEAD/Docs/FormatOverview.md) ·
[Apple — jetsam](https://developer.apple.com/documentation/xcode/identifying-high-memory-use-with-jetsam-event-reports) ·
[Apple — max build sizes](https://developer.apple.com/help/app-store-connect/reference/maximum-build-file-sizes/) ·
[9to5Mac — cellular limit](https://9to5mac.com/2019/06/03/ios-13-removes-200-mb-file-size-limit-for-app-downloads-over-cellular/)
