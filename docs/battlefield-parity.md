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
| `staggered` | float, `reseaming` 720ms | ⚠️ | float only; no reseam shimmer |
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

**No sound at all.** `sfx.*` fires on nearly every branch above and this port
has no audio layer. That is the largest single unmatched surface, and it is not
an animation gap — it is a missing subsystem.

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
| Per-character idle (`mesh` blocks in `char-meta.json`) | ❌ still dead data |
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

## 6. Known differences, deliberate or open

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
- **Viewport support does not exist.** `project.godot` is `canvas_items` +
  `aspect=keep` at 1180×820, so the composition scales and letterboxes and
  nothing reflows. Real support needs `aspect="expand"` plus the benchmark's
  five authored shape tables (`BF` / `UIC`) and a shape-aware `HudBar`.
