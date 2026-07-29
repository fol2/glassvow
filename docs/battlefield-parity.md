# Battlefield parity ledger

What the benchmark's combat screen does, and what this port does about it.
Sources are `roguecardv2@6e069118` — `src/ui/drain.js`, `src/vfx.js`,
`src/ui/combat-choreo.js`, `src/ui/combat-presentation.js`, `src/styles.css` —
plus figures read off the running build at `localhost:5190`, which is the only
way to get the ones the stylesheet's fallbacks lie about.

Scope is the **battlefield only**: the fight, its actors, its chrome and its
effects. Reward, map and the run around it are other lanes.

---

## 1. The drain, event by event

`drain.js` answers thirty-seven event types. Our domain emits twenty-eight of
them; the other nine have no source in the slice and nothing to play back.

| Event | Benchmark | Port | Notes |
|---|---|---|---|
| `turn` | banner from turn 2, 500ms | ✅ | turn 1 opens with 120ms and no plate |
| `endTurn` | banner, 480ms | ✅ | also spends the hero's owed swing |
| `intent` | resync | ✅ | |
| `energy` | `chipPop` on the orb | ✅ | |
| `draw` | wave, `drawBatchSchedule` | ✅ | flights overlap; pile bumps on the last |
| `reshuffle` | card backs, discard → draw, 600ms | ✅ | flown by `HudBar`, which owns the faces |
| `play` | targeted card streaks into the foe at 22% | ✅ | untargeted just leaves the fan |
| `hitEnemy` | swing, impact, ward chip, numeral, shake, kill ceremony | ✅ | see §2 |
| `hitPlayer` | source-split, red flash, numeral | ✅ | |
| `die` | stagger → ignite → shatter → burst | ✅ | boss beat 320ms, common 200 |
| `chip` | spark burst, `chipPop` on the gauge | ✅ | |
| `shatter` | hitstop, ring, burst, float, shake, crack | ✅ | |
| `staggered` | float, `reseaming` 720ms | ⚠️ | float + sting; no reseam shimmer |
| `blockGain` | float with shield, `blockPulse` | ✅ | |
| `status` | float, motes on a buff | ✅ | debuff resolved from the catalogue |
| `heal` | motes, float | ✅ | |
| `ember` | mote flight to the lantern, `chipPop` | ✅ | source is `emberFrom` |
| `kindle` | records `emberFrom`, burst at the seat | ✅ | card flies to the ashes here |
| `art` | flash, ring at the lantern, motes, float | ⚠️ | `artCast` sprite not built |
| `toDiscard` / `exhaust` | flight to the pile, bump | ✅ | |
| `powerConsumed` | motes to the hero, ring | ✅ | was wrongly flying the card to ash |
| `discardHand` | all seats fly to the discard | ✅ | |
| `enemyAct` | telegraph, name, 300ms, swing | ✅ | |
| `smolderJump` | motes between foes | ✅ | |
| `relicProc` | chip `proc` | ⚠️ | no relic row in the chrome yet (D5) |
| `potion` | sfx only | ✅ | |
| `victory` | gold flash, PERFECT plate | ✅ | |
| `defeat` | dark flash, lantern snuff | ⚠️ | flash only; the snuff is `.stage-dim` |
| `bossIntro`, `variantDialogue`, `questReveal`, `questProgress`, `questComplete`, `questUnlock`, `monumentGift`, `hollowTithe`, `adamantHold`, `addCard`, `maxHp` | banners and floats | — | the domain emits none of these |

**Sound is wired.** All thirty-four `sfx.*` calls in `drain.js` are answered
from `presentation/audio/sfx_bus.gd`, off the benchmark's own `ashglass-v1`
bank (36 ElevenLabs samples, carried across with their provenance manifest).
The WebAudio oscillator fallback in `audio.js` is deliberately NOT ported: it
guards against a sample that has not finished downloading, and a Godot project
has its bank on disk before the window opens.

Music is a separate subsystem and is not ported. `MUSIC_CATALOG` names 22
tracks across title, map, act combat, bosses and run end; none of them belong
to the battlefield alone, so they are out of this lane's scope.

## 2. The blow

`hitEnemy` is the branch the fight is built around, so it is spelled out:

- the hero swings once per **card**, not per hit (`choreoDone`)
- `archetypeHit` at the body, powered by `min(1, amount / 24)`
- `choreoHit` — recoil and hurt flash; poison gets the flash without the shove
- ward chipping off: shield float, nine-spark burst, GUARD SHATTERED at zero
- the numeral in one of four tiers, tinted by archetype, laid in three columns
  so a multi-hit card does not stack its numbers
- `shake(min(4 + amount/2, 15))`, hitstop at 16+
- a killing blow: heavier hitstop, white ring, warm ring, gold wash; overkill 8+
  adds a white flash and two more bursts

## 3. Motion

| Piece | State |
|---|---|
| `heroIn` / `enemyIn` / `chromeIn` | ✅ built |
| `choreoAttack` — heavy / floaty / default | ✅ built |
| `choreoHit` | ✅ built |
| `choreoStagger` | ✅ built |
| `teleFlash` on the intent chip | ✅ built |
| `pileBump`, `chipPop`, `blockPulse` | ✅ built |
| `sl-drift` plate parallax | ✅ built — 30/10/0, read off the DOM |
| HP `.ghost` trail | ✅ built |
| Per-character idle (`mesh` blocks in `char-meta.json`) | ✅ `breathe` / `sway` / `bob` read; `head`, `cloth`, `pin` have no rig to drive |
| `pvPulse` — HP preview segment | ✅ built |
| Aim outline (`meshAim` / `charAim`) | ✅ built — per-creature tint and width read |
| `candleFlick` | ❌ |
| ward pulse / gemstone shell (`syncWardMesh`) | ❌ |
| `.cast-shadow-layer` | ❌ — each actor casts its own |
| `.stage-dim` lantern tracking | ❌ — verified `--la: 0` in normal play |

## 4. The effect layer

`vfx.js` is ported in `presentation/combat/vfx_layer.gd`: particles (spark,
ring, slash, dot), flashes, the shake spring, hitstop, all seven archetype hits
and the ash weather. Two deliberate departures:

- **Blending.** A canvas flips `globalCompositeOperation` per particle; a
  CanvasItem cannot. The list is painted twice, additive and not, with the
  flash on a third pass — the same paint order `tick()` uses.
- **A cap.** 400 live particles, about four simultaneous deaths. The benchmark
  has none; a browser canvas can afford one more draw call than we can.

`shatterCells` (the Voronoi glass break) is **not** ported and does not need to
be: `EnemyView.shatter` already breaks the body into cells along its own crack
sites and hands them to the physics engine, which is a better version of the
same idea.

## 5. The sky

The act's plate art has a transparent sky and `#bg3d` is what shows through it —
a three.js scene with a lit sky, fog, and two bloomed mote fields.
`sky_field.gd` is a **declared mock** of the part the battlefield shows: the sky
and fog colours, `ptsMain` in the theme's `particles` colour and `ptsAccent` in
its `glow` at 0.55 of the rise. The spire, beacon and cloud sea are below the
treeline at this camera and the plates cover them. If the 3D scene is ever
ported, this comes out.

## 6. Input, and what it decides

`drain.js` is only half the fight. The other half is `combat.js` +
`pointer.js`, which decide what the player can DO — and three whole surfaces of
it were missing rather than approximate.

| Surface | Benchmark | Port |
|---|---|---|
| Tooltips | `_tip` on ten node kinds, mouse-follow, 380ms long-press on touch | ✅ built — see below |
| Hover preview (`updatePreviews`) | aim rim, rail segment, ghost facets, death-mark | ✅ built |
| Keyboard (`handleCombatKey`) | Esc / E / A / ←→ / ↑↓ / Enter / Space | ✅ built |
| Drag arm | 26px UPWARD; 12px click slop | ✅ both, and both were wrong before |
| `kindleOnly` free drag | an unaffordable card still drags, but only the lantern takes it | ❌ — this port kindles by a toggle (D4), so there is no lantern to drop on |
| Enemy `targetGlow` idle pulse | a targetable foe breathes a red drop-shadow | ❌ |

**The tooltip walk is inverted.** The benchmark hangs `_tip` on a DOM node and
walks UP from the event target until it finds one. That walk cannot exist here:
a keyword inside a card is a run of glyphs the paragraph drew, not a node. So
the screen answers one question — `tip_at(global_pos)` — front to back, and
the widgets it asks report a ZONE rather than a sentence. Every sentence is
assembled at the screen, because a widget in `presentation/` does not read
content and all of this is catalogue copy.

**The preview rules are the whole of it**, and they are not "the foes it could
hit": `allEnemies` reaches every living foe while a card is being READ or
carried loose but never while aimed; a single-target card reaches the lone
survivor, or once aiming only the foe under the pointer; and a foe that is a
legal target but not the aimed one is DIMMED — it keeps its rail preview and
loses the death-mark and the shatter ring, so a three-foe lineup cannot claim
three kills at once.

## 7. Known differences, deliberate or open

- **The hero renders warmer** than the benchmark's, which is a dark-blue-robed
  sprite. Same `duskblade.png` (verified by hash); the difference is our 3D
  lighting rig against a DOM image. Open.
- **A big elite's intent chip rides over the top strip.** The chip hangs off the
  actor's box and an elite's box reaches y≈30. The benchmark positions it the
  same way off the same box, so this is parity, not drift — but it looks wrong
  in both.
- **Card faces are ours**, and better; that is an enhancement, not a gap.
- **Actor plates are ours**: the numeral sits inside the rail rather than to its
  right, and the width is the WIDE variant. Recorded as an open A/B in
  `hud_bar.gd`.
- **Viewport support exists, and its data is the benchmark's own.** This
  paragraph used to record the opposite, and named `aspect="expand"` as what it
  would take. That turned out not to be the mechanism: `project.godot` still
  reads `canvas_items` + `aspect=keep`, unchanged, and the flex is expressed
  instead as a computed `content_scale_size` (`presentation/stage/stage_shape.gd`).
  When the flexed size matches the window's aspect, `keep` has nothing to
  letterbox and produces no bars; past a ±12% cap the size stops moving and
  `keep` bars the remainder. One mechanism, and the cap comes free.

  Both authored tables — `BF` and `UIC` — are transliterated verbatim into
  `assets/layout/combat-layout.json` and resolved by
  `presentation/stage/layout_book.gd`, which ports the benchmark's three-level
  merge once for both scopes rather than twice. `CombatScreen` and `HudBar` are
  both shape-aware; the plate figures this port used were re-checked against
  `battlefield-layout.js` before the swap and are exactly `pad-landscape` → act
  0 (640/280/drift 30, 1000/300/drift 10, 450/0/drift 0), which is why the swap
  changed nothing on screen at that shape. `tests/test_presentation.gd` pins
  that identity, so it cannot drift back unnoticed.

  The hazard the old paragraph named still stands: `desktop-landscape` is a
  different table entirely, so reading `--amp` off a wide browser window reads
  THAT one. `?shape=` on the benchmark and `--shape=` here are the guard.

- **Card, hand, chrome and HUD sizing now follow the shape; the reward and map
  screens still do not.** This paragraph used to say the whole regime was
  unported, and for combat it no longer is. The numbers upstream keeps in 331
  lines of `@container stage` rules rather than in `BF`/`UIC` — `--cw`,
  `.hand-zone`'s height, `.hand-zone .card`'s inset, the energy orb's box, and
  fourteen declarations of HUD-rail sizing — were measured off the running
  benchmark at each `?shape=` and authored into the book as `card/w`,
  `card/inset`, `hand/h`, `energy/w`, `energy/h`, `actor/scale` and the rail's
  `hud/scale`, `hud/title` and `hud/stat`. `tests/test_layout_book.gd` pins the
  table for all five shapes.

  What made this invisible for so long is worth stating plainly: a
  `@container stage` regime has no editor, no schema and no data file upstream,
  so nothing was ever going to notice the port had none of it. The two authored
  tables were complete and the screen was still wrong.

  Still one shape: the reward rack and the map. `CARD_SCALE` is a `const`
  derived from `CardView.CARD_W` in four files — `reward_screen.gd:142`,
  `reward_embers.gd:109`, `reward_reliquary.gd:56`, `reward_window.gd:69` — so
  a phone-portrait reward draws three 178px cards across a 390px stage and cuts
  the outer two in half. Upstream authors `.choice-cards .card`'s `--cw` per
  regime and it resolves to **178 / 178 / 150 / 113 / 135** across
  pad-landscape, desktop-landscape, pad-portrait, phone-portrait and
  phone-landscape (the last two are `29cqw` and `16cqw` against the stage
  container, which is the reference width). Those five numbers plus a `reward`
  entry in `LayoutBook.SCOPES` are the whole data side; the work left is the
  four `const`s and the spoils row above the rack, which the Reward lane owns.
- **The stage plates drift by moving their PAINT, not their box.**
  `gui/common/snap_controls_to_pixels` defaults to true, so writing an offset
  rounds a Control's rect before it draws, and a 30px sweep over 26 seconds
  ticks rather than glides. Draw commands are not snapped. This also happens to
  be what `sl-drift` does — a `transform` moves the painted image and leaves
  layout alone.
