# Actor animation checklist

The standing list of which animations an **Actor** — a foe or the player's hero —
should and should not have, and where this port currently stands against each.

Written 2026-07-26 to close the open item recorded in
[`visual-direction.md`](visual-direction.md) § Enemies: *"list which animations
should and should not exist, then work the checklist"*, whose scope was extended
to cover heroes. Re-verified 2026-07-27 against the Godot tree and the
benchmark at `6e06911`.

## Sources

- **Benchmark** — `roguecardv2-benchmark` at **`6e06911`**, the approved pre-pixi
  visual. Not `~/Coding/roguecardv2` / `main`, which is post-Pixi and a
  regression for parity. Every benchmark claim below carries a `file:line`
  citation read from that commit. A function existing in source is not evidence
  it renders — measure on the running page.
- **This port** — chiefly `presentation/combat/enemy_view.gd`,
  `presentation/combat/combat_screen.gd`, `presentation/combat/vfx_layer.gd`,
  `presentation/combat/floaters.gd`, `presentation/lab/enemy_lab.gd`, and
  `assets/art/enemies/char-meta.json`.

Per `CONCEPTS.md` › **Benchmark**, the web build is authority for *what* the game
does, never for *how* it had to achieve it. Beats it only performs because a
browser could not do better are marked and not ported.

## Verdicts

| | Meaning |
|---|---|
| **PORT** | The benchmark has it, we do not, and it is a design decision. Build it. |
| **KEEP** | We have it and it matches the intent. Leave alone. |
| **FIX** | We have something, but it is wrong, incomplete, or wired to the wrong thing. |
| **DERIVE** | The benchmark's value is a compensation for a browser limit. Compute it instead — see [derive-authored-compensations-when-porting.md](solutions/design-patterns/derive-authored-compensations-when-porting.md). |
| **DECLINE** | The benchmark appears to have it, but it is dead, disabled, or a pure workaround. Do not build it. |

---

## 1. Whole body

### 1.1 Entrance — **KEEP**

Benchmark: `heroIn` / `enemyIn`, 0.55s `cubic-bezier(.2,.75,.3,1)`. The hero
enters from the left (`translateX(-70px)` → 0), foes from the right
(`translateX(90px)` → 0), each foe delayed `160 + i×130ms`
(`src/styles.css:725-729`, `src/ui/combat.js:280`, `src/ui/combat.js:345-351`).

Here: built. `EnemyView.enter` carries the same 0.55s / −70px hero / +90px foe /
`ENTER_LEAD` 0.16 + `ENTER_STEP` 0.13 stagger
(`enemy_view.gd:251-257`, `enemy_view.gd:2222-2237`). Combat seats foes with that
delay (`combat_screen.gd:1061-1066`) and `_play_entrance` slides the hero and
each foe from the matching side over 0.55s (`combat_screen.gd:1095-1119`).

Foes currently also run the vessel-local `enter` and the screen-level `_enter`;
both land. Worth consolidating later — not a missing beat.

### 1.2 Idle — **KEEP**

Benchmark runs idle at two levels:

- A per-character vertex deformation — sway, breathe, bob, head, cloth — from the
  `mesh` block in the character table. `duskblade` is
  `sway .5, bob 0, breathe 1.6, head 1.35, cloth .75, pin .5`; `ashwarden` is
  `sway 0, bob 0, breathe 1.3, head 0, cloth 0` (`src/char-meta.js:31-35`,
  `src/mesh.js:824-844`). Frequencies 0.7–2.5 rad/s, displacement × 0.45
  (`src/mesh.js:20`, `src/mesh.js:140-161`).
- A per-**kind** CSS idle on foes only: `idleFloat` (wisp 3.1s/16px, eye
  3.4s/18px, siren and shade 3.6s/12px, plant 3.8s/9px), `idleSlime` 4.2s,
  `idleSway` 3.5s, `idleBreathe` 3.6s (`src/ui/combat.js:1840-1849`,
  `src/styles.css:1611-1624`). Mesh `float` is separate: `float * 12 * 0.45`
  (`src/mesh.js:872`).

Here: both intents are live. `IDLE_PROFILES` matches the benchmark `PROFILE`
table kind-for-kind (`enemy_view.gd:447-468` ↔ `src/mesh.js:140-161`).
`set_profile` / `_read_idle` lay the character's own `mesh` block over the kind
(`enemy_view.gd:2096-2138`). The deform lives in `BODY_SHADER`'s vertex stage,
weighted by height so the feet stay planted (`enemy_view.gd:630-682`), with
`IDLE_INTENSITY = 0.45` (`enemy_view.gd:439`). Whole-body float is the mesh
`float` knob as stage px (`FLOAT_PX` 12, `enemy_view.gd:471-473`,
`enemy_view.gd:1858-1864`) — the CSS px table is not transcribed as a second
layer; kind differentiation is carried by the profile.

A wisp, a slime and an armoured knight no longer breathe identically.

### 1.3 Attack lunge — **KEEP**

Benchmark: `choreoAttack` — wind back `-8×dir px` with `scale(.97,1.02)`, then
lunge `34×dir px` with `scale(1.02,.99)`; 330ms normal, 380ms floaty, 420ms heavy,
`cubic-bezier(.34,1.56,.64,1)`. Floaty hops instead (`6→10×dir px`,
`-5→-2px`); heavy squashes in place to `scale(1.08,.86)`. Fires for the hero on a
card's first non-Art hit, and for a foe on an attack intent
(`src/ui/combat.js:1953-1977`, `src/ui/drain.js:494-505`, `src/ui/drain.js:898-925`).

Here: built as `EnemyView.lunge` with the same three kind sets and keyframe
numbers (`enemy_view.gd:227-261`, `enemy_view.gd:2188-2267`). The hero swings once
per card (`combat_screen.gd:2071-2076`); a foe telegraphs, waits 300ms, then
lunges (`combat_screen.gd:2266-2272`).

### 1.4 Hit recoil — **KEEP**, strength still open

Benchmark: `choreoHit` — `translateX(9×dir px) scale(.97,1.03)` with
`brightness(1.9)`, 300ms `cubic-bezier(.22,1,.36,1)`, plus a 160ms material flash.
Applies to a foe on `hitEnemy` and to the hero on an ordinary `hitPlayer`.
Poison, burn, self-damage and thorns deliberately do **not** recoil the body
(`src/ui/combat.js:1979-1989`, `src/mesh.js:1027-1033`, `src/ui/drain.js:511-512`,
`src/ui/drain.js:593-596`).

Here: built. `take_hit(direct)` shoves on direct hits and only nudges on
incidental ones (`enemy_view.gd:2352-2365`, `enemy_view.gd:2375-2402`). Kick is
the benchmark's 9px (`KICK_PX`, `enemy_view.gd:113-121`). Wired from the drain
(`combat_screen.gd:2085`, `combat_screen.gd:2180`).

Still open: whether absolute 9px reads as mass across the size ladder. Kept as
absolute pixels on purpose — judge in motion before changing it. `flare_gain`
(shared with §1.5) is a lab knob, default 1.0 (`enemy_view.gd:265`).

### 1.5 Hurt flash — **KEEP**, strength still open

Benchmark: `hurtFlash`, foes only, 0.3s — at 30% `brightness(2.6) saturate(.4)`
with an 18px white glow and `X +7px`, at 60% `X -5px`. Fires on **every**
`hitEnemy` including poison, and on a facet shatter
(`src/styles.css:788-789`, `src/ui/drain.js:291-307`, `src/ui/drain.js:543-548`).

Here: built inside `take_hit` — foes flare; heroes shove without flashing
(`enemy_view.gd:2360-2361`, `_flare` at `enemy_view.gd:2410+`). Incidental hits
get the smaller two-phase nudge instead of the full shove. Three literal ports of
the CSS filter were rejected and are recorded in the shader
(`enemy_view.gd:907-937`).

Same open as §1.4: judge `flare_gain` in motion; a 300ms beat cannot be judged
from a still.

### 1.6 Stagger — **KEEP**

Benchmark: `choreoStagger` — foe art only, 360ms
`cubic-bezier(.22,1,.36,1)`, `fill: forwards`: `translateY(+5px)`,
`rotate(-2.5deg)`, brightness → `.6`. It fires on **`die`**, immediately before
ignition (`src/ui/combat.js:1991-2000`, `src/ui/drain.js:551-570`).

Here: built and wired to dying. `EnemyView.stagger` is the same 5px / −2.5° /
0.6 modulate / 0.36s (`enemy_view.gd:2312-2321`). `_die` awaits it before
`mark_dead` (`combat_screen.gd:2227-2231`). The `STAGGERED` status still floats
its label and runs `reseam` (`combat_screen.gd:1823-1831`) — that is the facet
reseam, not this death slump, and matches the benchmark's split.

### 1.7 Boss doom — **KEEP**

Benchmark: on a boss `die`, 820ms before the stagger — `doomTremble` .09s linear
jitter through `(+1.6,-1)`, `(-1.4,+1.2)`, `(+1,+1.4)px`; the whole screen
transitions over .22s to `saturate(.07) brightness(.85)`; a 110ms hit-stop; crack
paths go white (`src/styles.css:95-110`, `src/ui/drain.js:551-566`).

Here: built. `_die` runs world-stop, `set_doomed`, hit-stop 110ms, hold 0.82s,
then clears before stagger (`combat_screen.gd:2214-2228`,
`WORLDSTOP_*` at `combat_screen.gd:129-144`). The body rattles via
`_doom_tremble` with the same keyframe px (`enemy_view.gd:210-213`,
`enemy_view.gd:1873-1879`). Seams whiten under the `doomed` uniform
(`enemy_view.gd:3999-4005`).

Noted departure: the drain greys `#screen` beside `#mesh`, so warped bodies stay
lit there; here actors share the tree and drain with the world
(`combat_screen.gd:133-138`). White doomed seams still read.

### 1.8 The death rite — **KEEP**

Benchmark: ignition 200ms normal / 320ms boss; then hand-rolled JS ballistics at
`G = 2400 px/s²` with up to two damped bounces (`vy × −.34`, then `× −.22`);
shards hold full opacity 650ms, fade over 380ms; the corpse class switches at 830ms
(`src/ui/combat.js:2011-2037`, `src/vfx.js:283-345`, `src/ui/drain.js:566-584`).

Here: `mark_dead(beat)` ignites over the caller's beat — combat passes 0.2s /
0.32s boss (`combat_screen.gd:2229-2231`, `enemy_view.gd:2893-2922`) — then real
`RigidBody3D` shards with engine gravity, per-shard cool and dissolve, burst
flash, embers and camera shake (`enemy_view.gd:3104+`). Timing matches; physics
is the Godot substitute and stays.

### 1.9 Low-HP body slump — **DECLINE**

Benchmark has the rules — `.9s ease`, foe `rotate 2.4deg / Y +4px / scale .985`,
hero `rotate -2deg / Y +4px` — but the selector only ever reaches the SVG aim-ring
and crack overlay. The live painted body is an `img.raster-art` the rule never
matches, and the crack overlay is separately reset to `transform:none`
(`src/ui/combat.js:729-774`, `src/ui/assets.js:5-8`, `src/styles.css:969-970`,
`src/styles.css:1605-1608`).

Dead at the visual standard. Do not build it.

### 1.10 Cracks from ordinary damage — **OVERRULED** (owner, 2026-07-26)

Benchmark: `COMBAT_CRACKS = false`. Landed hits call `addCrack`, which returns
immediately. Only death forces cracks (`src/ui/combat.js:2001-2019`,
`src/ui/drain.js:543-546`). That was the reading when this entry first said
**DECLINE**.

The DECLINE is void. `CONCEPTS.md` › **Crack** was rewritten at the owner's
direction: cracks **are** driven by damage. What was built is the whole of
`docs/fracture-model.md` — a propagated fracture model, a groove in
`BODY_SHADER`, a carve so the death rite breaks along carried cracks, and
damage→fracture energy through calibrated `bite`. Combat scores cracks on landed
hits (`combat_screen.gd:2124`). Cap is **eight impacts**, matching the
reference's drawn-crack cap (`enemy_view.gd:79-86`).

The historical DECLINE text is left only as the record of the reverse; do not
treat it as current policy.

---

## 2. Cast shadow — **KEEP** / **DERIVE**

Benchmark: `syncCastShadow`, a squashed sprite copy resynchronised every frame.
Explicitly flagged a workaround — a shadow surrogate, because CSS cannot project.
At full lift `t=1`: scaleX ×`.74`, scaleY ×`.5`, opacity ×`.45`, blur `+2.8px`,
skew reduced 35%, from a base of `scale(1,.24)`, opacity `.62`, blur `1.5px`
(`src/char-meta.js:8`, `src/ui/combat.js:1771-1819`, `src/styles.css:767-782`).

Here: derived by projecting the silhouette along the key light
(`enemy_view.gd:1760-1785`). Lift response remains authored, not matched:
`s = 1 - f*0.5`, opacity `× (1 - f*1.2)`, softness `1 + f*4`
(`enemy_view.gd:1774-1785`). Correct as a derive; the benchmark full-lift figures
above remain the only taste numbers worth diffing if the shadow ever looks wrong
at float.

Per-creature `shadow` knobs in `char-meta.json` are unread — see §5.3.

---

## 3. Chrome hanging off the actor

### 3.1 HP vial — **FIX** (ghost **KEEP**; fill still snaps)

Benchmark: the fill transitions over .35s `cubic-bezier(.3,1,.4,1)`, and a second
**ghost** bar trails it over .9s ease with a .25s delay
(`src/ui/combat.js:721-726`, `src/ui/combat.js:764-774`, `src/styles.css:833-835`).

Here: ghost is built — hold 0.25s, fall 0.9s (`GHOST_HOLD` / `GHOST_FALL`,
`enemy_view.gd:45-46`, `enemy_view.gd:3833-3846`). The live fill is still assigned
outright (`enemy_view.gd:3821-3823`). The ghost carries the "how much was just
taken" read; the fill's 0.35s ease is the remaining gap.

### 3.2 Ward — **FIX** the chip pulse; shell **KEEP** (owner rewrite)

Benchmark has two separate things:

- `blockPulse` on the chip: .4s ease-out, scale peak 1.3, 22px glow — on player
  **and** foe chips (`src/ui/drain.js:618-633`, `src/styles.css:857-859`).
- A ward **shell** around the body: an oversized (`pad 1.46`), opacity .4,
  32-site refractive glass envelope, growing and fading over 560ms; a re-gain
  shrinks the sites to .12 over 45% of the tween then regrows
  (`src/mesh.js:920-967`, `src/ward-params.js:3-21`).

Here: the shell was decided and built against "an envelope around the body". It
is a cut gem held in front of the mob (`WARD_*` block, `enemy_view.gd:128-208`,
`set_ward_shell` at `enemy_view.gd:1989+`) — ordered facets, no hash, breaks on
its own cuts. Timing/colour knobs kept from `ward-params.js`. Full reasoning in
`docs/fracture-model.md` §9.

The chip pulse is only on the HUD ward (`hud_bar.gd:807-816`, fired for the
player at `combat_screen.gd:1869`). An enemy `blockGain` shows the chip and grows
the gem (`combat_screen.gd:1871-1875`) but never pulses the chip
(`set_ward` at `enemy_view.gd:3849-3858`). That is the remaining FIX.

### 3.3 Facet gauge — **KEEP** `chipPop`, **DECLINE** `pvPulse` on pips

Benchmark: `chipPop` .4s ease-out, peak scale 1.35, added on the `chip` event
(`src/ui/drain.js:279-289`, `src/styles.css:955-960` / facet-row at `:1058`).

`pvPulse` (.9s infinite opacity to .4) is explicitly `animation:none` for the
real raster facet pips — the rule survives only on the HP-preview bar
(`src/styles.css:987-1063`).

Here: `FacetPips.pop` is the 1.35 peak over 0.4s (`facet_pips.gd:68-75`), driven
from `set_facets(..., pop)` (`enemy_view.gd:3865-3870`). HP-preview `pvPulse` is
ported on the rail (`PREVIEW_PULSE` 0.9 / dip 0.4, `enemy_view.gd:41-43`,
`enemy_view.gd:1819-1822`) — that is the live rule, not a pip animation.

### 3.4 Status row — **KEEP**

Benchmark: no entry or exit animation. The row is rebuilt synchronously
(`src/ui/combat.js:660-674`, `src/ui/drain.js:635-645`). `.schip.pop` exists in CSS
but nothing ever adds the class (`src/styles.css:890-891`) — dead.

Here: `StatusRow` / `StatusChip` are integrated (`enemy_view.gd:3503-3504`,
`enemy_view.gd:3905-3906`). No enter/exit animation — correct. The old
`" · "`-joined `Label` is gone.

### 3.5 Intent telegraph — **KEEP**

Benchmark: `teleFlash` .5s `ease-in-out` × 2 iterations — midpoint scale 1.22,
brightness 1.8, 10px current-colour glow — fired on every `enemyAct`, with a 300ms
lead **before** the body lunge (`src/ui/drain.js:898-925`, `src/styles.css:893-908`).
`.intent.pop` is dead CSS (`src/styles.css:938`).

Here: `IntentChip` is the actor's telegraph (`enemy_view.gd:3499-3501`).
`telegraph()` is two 0.5s loops peaking at scale 1.22 / modulate 1.8
(`intent_chip.gd:166-176`). Drain order: telegraph → float name → wait 0.3s →
lunge (`combat_screen.gd:2266-2272`).

### 3.6 Targeting — **FIX**

Benchmark has **two** states: `targetGlow`, a 1s `ease-in-out infinite` pulse from
6px to 18px red on every targetable foe; and `.target-hover`, which *kills* the
pulse and goes to a solid 22px glow with `brightness(1.25)`
(`src/ui/combat.js:1199-1257`, `src/styles.css:1237-1251`).

Here: legal targets do light — `aim_all` / `aim_one` drive `set_targetable`
(`combat_screen.gd:2767-2769`) — but `set_targetable` still snaps the
`target_lit` uniform between 0 and 1 with no pulse and no hover-solid variant
(`enemy_view.gd:3460-3466`). Two defects remain: the missing pulse, and the
instant on/off.

---

## 4. Actor-centred effects that live on the screen, not the actor

Listed because they are triggered by an actor and aimed at one; ownership noted in
§ Ownership.

### 4.1 Floating text — **KEEP**

Benchmark: 1100ms normal / 1250ms crit, `cubic-bezier(.2,.7,.3,1)`; scale
`.6→1.15→.95`, rise `-50%` → `-230%`, random ±20px drift. Poison **descends** to
`+80%` instead. A crit peaks at 1.45, holds, then rises and fades
(`src/vfx.js:175-210`).

Here: `Floaters.float_text` — 1.1s / 1.25s crit, matching ease and keyframes,
poison descends, crit blaze (`floaters.gd:43-45`, `floaters.gd:145-197`). Driven
from `combat_screen._float` (`combat_screen.gd:1681-1684`).

### 4.2 Impact particles — **KEEP** (and honour the dead kinds)

Benchmark dispatches by damage archetype — slash, pierce, blunt, fire, poison,
void, ward — into arcs, sparks, rings, bursts, droplets and motes
(`src/vfx.js:51-149`, `src/vfx.js:362-431`).

**Measured:** `ring` and `slashArc` never reach the screen at `6e06911`. They push
particles with no `vx`/`vy`; the draw loop does `p.x += p.vx * dt` and coordinates
go NaN before paint. Pixel counts on the running page: burst/motes draw; ring and
slashArc draw 0 (`vfx_layer.gd:43-59`).

Here: `VfxLayer.archetype_hit` and the drain call sites are built
(`vfx_layer.gd:591+`, `combat_screen.gd:2083`). `DEAD_KINDS_RENDER = false` drops
`ring` / `slash` at `_push` so the typed `Vector2.ZERO` default does not
accidentally repair them into visible hoops (`vfx_layer.gd:71-73`,
`vfx_layer.gd:405-410`). Call sites stay as the record of what the source asks
for; turning the flag on would render intent the benchmark has never shown.

### 4.3 Screen shake, hit-stop, flash — **KEEP**

Benchmark: shake at initial power 4–22 decaying `power × 0.001^dt`, applied to
**all** battlefield actors through one `#shake` wrapper; hit-stop 70ms on a big
hit, 90/130ms on a kill, 90ms on a facet shatter, 110ms on a boss death — during
which the particle loop freezes; colour flashes at .09/.24/.28/.3s
(`src/vfx.js:52-57`, `src/vfx.js:127-149`, `src/ui/drain.js:291-306`).

Here: shake moves `_shake_host` wrapping stage, battlefield and HUD
(`combat_screen.gd:439-446`, `vfx_layer.gd:433-434`, `vfx_layer.gd:344-357`).
`hitstop` freezes the particle sim (`vfx_layer.gd:437-438`,
`vfx_layer.gd:245-248`) and is wired for big hits, kills, shatter and world-stop
(`combat_screen.gd:1808`, `2128`, `2132`, `2222`). Flashes go through
`VfxLayer.flash`. Per-actor SubViewport camera shake is no longer the battlefield
shake.

### 4.4 Ember flight — **KEEP**

Benchmark: `flyTo`, 460ms or 520ms, motes staggered `i×46ms`,
`cubic-bezier(.32,.05,.35,1)`, scale `.5→1.05→.55`, lofted waypoint. Used for
ember gain and `smolderJump` (`src/ui/combat.js:1420-1478`, `src/ui/drain.js:351-380`).

Here: `VfxLayer.fly_to` with the same ease and 46ms stagger (`vfx_layer.gd:541-569`).
Ember gain and smolder jump call it (`combat_screen.gd:1844-1846`,
`combat_screen.gd:2023`).

---

## 5. Structural, not animation

### 5.1 The hero is an actor here — **KEEP**

Benchmark: the hero is a raster-painted battlefield combatant created by
`heroArt(S.run.aspect)`, resolving `duskblade` / `ashwarden`, carrying the same cast
shadow, idle deformation, ward shell and hit recoil as a foe. It explicitly
**cannot** crack or shatter (`src/ui/combat.js:215-237`, `src/ui/assets.js:43-48`,
`src/ui/combat.js:1820-1903`).

Here: the hero is an `EnemyView` with `tier: hero` (`combat_screen.gd:1011-1018`).
Same idle, shadow, ward gem, recoil; `mark_dead` / `shatter` / crack refuse a hero
(`enemy_view.gd:2896-2902`, `enemy_view.gd:3107-3108`). Chrome matches the
benchmark DOM: no intent, no facet row, no name line on the hero plate
(`enemy_view.gd:3471-3501`). `hud_bar.gd` still carries run chrome (energy,
lantern, piles); the hero plate owns HP and ward on the body.

### 5.2 `footX` / `footY` — **KEEP**

Settled against the source, and the answer inverts the first reading.

**The port is faithful.** In the benchmark, positive `footY` moves an actor up and
negative moves it down (`src/battlefield-layout.js:8`, `src/ui/combat.js:397`), so
`duskblade`'s `footY: -30` sinks it ~30px below the ground line *there too*. Our
lab roster reproduces the benchmark, it does not deviate from it.

**Hero and foes share one ground line**, confirmed arithmetically: both `bottom`
values are relative to `.battlefield`'s bottom edge, which sits `groundY = 232`
above a stage bottom of `H = 820`; with `footY = 0` a hero and a normal-tier foe
both land at stage y 588 (`src/battlefield.js:86`, `src/battlefield.js:144`,
`src/battlefield-layout.js:30`, `src/stage.js:23`).

**`footY` is not canvas slack.** The numbers do not correlate with the paintings:

| Painting | Size | Empty canvas below body | Scaled into its box | Authored `footY` |
|---|---|---|---|---|
| `duskblade.png` | 825×1024 | 9px | ~2.5px of 285 | **−30** |
| `ashwarden.png` | 682×1024 | 23px | ~6.4px of 285 | 0 |
| `duskfang.png` | 1024×1024 | 62px | ~11px of 327 | 0 |
| `sporeling.png` | 1024×1024 | 62px | ~7px of 115 | 0 |

The source's only stated semantic is "corrects art where feet aren't at the
sprite's bottom edge" (`src/battlefield-layout.js:8`), and no comment claims a
deliberate body position. So it is an eyeballed nudge — **taste, not geometry**,
which by the derive-vs-transcribe rule means it is design and gets ported as-is.
Do not derive it.

**`footY` is also not how floating works.** All four suspected floaters carry
`footY: 0`. Hovering is expressed by the per-kind CSS idle bob — `voidWisp` 16px,
`watcherEye` 18px, `shade` 12px, all via `idleFloat` — plus `mesh.float` when the
mesh is on; `voltEel` sways instead and overrides `mesh.float: 1.1`.
`shadow.dy` moves only the shadow, never the body
(`src/char-meta.js:44-55`, `src/styles.css:1612-1621`, `src/ui/combat.js:1807`,
`src/mesh.js:1143`). Floating and `footY` are two separate mechanisms; floating is
§1.2.

**Floor.** The combat screen now stands actors on the imported stage plates —
backdrop, mid, ledge — with mist between mid and ledge
(`combat_screen.gd:734-737`, `combat_screen.gd:760+`). Placement can be judged
against painted ground again. See appendix for layer visibility and drift.

### 5.3 Shadow metadata in `char-meta.json` — **MISSING FEATURE**

The reference (web benchmark, commit `6e06911`) reads the nine `shadow` knobs from `char-meta.json` (`char-meta.js:94–97`, `ui/combat.js:1798`) and uses them to position and scale cast shadows via CSS transforms (`styles.css:769–773`). These shadows render as dark ellipses under creatures, scaled and positioned per metadata (`ox`, `oy`, `sy`, `skew`, `dy`).

This port carries the metadata but does not read or render it. Cast shadows here are derived from the key light angle and ground tilt, not authored per-creature, and the `shadow` blocks remain unread. This is a design choice in the port (see `docs/solutions/design-patterns/derive-authored-compensations-when-porting.md` § Cast shadow) that trades per-asset tuning for derived behaviour. Verified: `presentation/combat/enemy_view.gd` reads `mesh` and `aim` from metadata (§1.2, §2) but does not access `shadow`.

The metadata is retained as reference data. If ground shadows are restored, the `shadow` blocks are the source of truth.

### 5.4 Every actor renders a live 3D stage — **MEASURED, and one knob moved**

`_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS`, one stage per
actor, sized up to 2048². Measured by the organiser in
`docs/actor-stage-frame-budget.md` (tool: `tools/bench_actor_stage.gd`):

- **Frame time passes with room.** A real fight — hero plus three foes, 3.6 Mpx —
  costs about **0.9 ms of the 16 ms budget**. The 16 ms line is not reached until
  roughly 38 actors. This checklist's PORT items are not blocked.
- **Memory has no budget to pass against.** Roughly **113 MB per actor**, 310 MB
  for four, before any texture, UI or audio. `commercial-game-delivery.md` §5
  reads "≤X MB" and X was never filled in. Setting it is a gate decision.

Two knobs were priced there and left to this lane to judge. Judged 2026-07-26 in
the lab at 1:1, and the naive reading of that price table is **wrong**:

| | memory saved (4 actors) | what it costs |
|---|---|---|
| `oversample` 2.5 → 2.0 | −20% | the lit lip on a shard edge gets **coarser** |
| MSAA 4x → 2x | −21% | the lit lip **stops being lit** |

The two save the same memory for very different prices. MSAA resolves the
sub-pixel coverage of the shard's side band, which is a sliver — so its specular
highlight lives or dies there. At 2x the continuous bright edge breaks into a dim,
broken line and the piece stops reading as glass, which is precisely the failure
[procedural-glass-reads-off-its-edges.md](solutions/design-patterns/procedural-glass-reads-off-its-edges.md)
describes. The aggregate difference is small — RMSE 0.005 on the body frame —
because the affected area is a few hundred pixels. They are the load-bearing ones.

**Decision: `oversample` 2.5 → 2.0, MSAA stays 4x.** −20% of the per-actor cost
for a coarser but still-lit edge. `oversample` 1.5 was rejected: visibly soft
paintings (RMSE 0.010, mushy leaded seams and teeth at 1:1).

Both are now `static var`s on `EnemyView`, and the lab takes
`--msaa=off|2|4|8` and `--oversample=N` so any future re-judgement is one command
per setting rather than an edit to the file being judged.

**Method note for anyone re-running this.** Judge from `--rite`, not `--states`:
the states sheet fit-scales (53% for six cells), and a downscale is itself an
antialiasing pass that hides exactly what is being tested. `--rite` renders one
actor at `content_scale_factor = 1.0` and crops at native pixels. And trust only
the **frame 0** difference — later frames carry `CPUParticles3D` embers and the
burst flash, which differ run to run, so their RMSE measures particles rather than
aliasing (a first pass read 0.215 there and it meant nothing).

Still not measured, and larger than either knob: each stage sets `own_world_3d`
with its own `Sky` feeding ambient *and* reflections, so N actors bake N radiance
maps. Collapsing that is a refactor, not a knob.

---

## Appendix — the benchmark's stage, measured from source

Not this lane's to build (`combat_screen.gd` stage work is Assembly's S1, see
`docs/assembly-integration-plan.md`). Recorded here because it came out of this
lane's source queries while settling §5.2, and because **three of its findings
contradict that plan**. For the organiser to route.

### Two of S1's four layers are switched off in the benchmark, on purpose

Read directly from the benchmark worktree, not relayed. After both rules are
defined, `src/styles.css` closes them out:

```css
/* act-themed ground glow off — stage-ledge + stage-breath both tint --ledge (act1 = green) */
.stage-ledge, .stage-breath { opacity: 0; animation: none; }
```

So the 120px ledge glow band with its 1.5px lit lip (S1 step 3) and the two
breathing blobs (S1 step 4) **do not appear** at the visual standard — and the
comment gives the reason rather than leaving it a mystery: both tint `--ledge`,
and act 1's `--ledge` resolves green. This is a decision that was made and
recorded, not a leftover.

**Not built here either.** They were briefly ported, produced a green band across
the floor, and were removed once that stylesheet line was read. Combat builds
backdrop, mid, mist and ledge only (`combat_screen.gd:734-749`). Putting the glow
band or breath blobs back would be a deliberate departure, not a fix.

What is actually visible, back to front:

| z | Layer | Visible? |
|---|---|---|
| 0 | `img.sl-backdrop` | yes |
| 0 | `.stage-breath` ×2 | **no** — forced `opacity:0` |
| 1 | `img.sl-mid` | yes |
| 2 | `.combat-screen::after` — 300px bottom mist | yes |
| 3 | `img.sl-ledge` | yes |
| 3 | `.stage-ledge` glow band + lip | **no** — forced `opacity:0` |
| 4 | `.stage-dim` — radial, HP-driven | yes |
| 5 | `.cast-shadow-layer` | yes |
| 6 | `#mesh` | the actor warp canvas |
| 7 | `.battlefield` | the actors |

No stage plate draws in front of a creature. The ledge PNG is the only contact
plate. A dedicated floor-darkening overlay, a horizon glow and a light pool were
all looked for and **not found** — the old `.lightpool` rule is `display:none` and
its own comment says the cast shadow replaced it (`src/styles.css:1602-1604`).

### The plates drift — the ledge does not

`sl-drift`, `ease-in-out infinite alternate`, horizontal `translateX(-50% ∓ --amp)`
(`src/styles.css:670-677`): backdrop **26s**, mid **18s**, ledge **12s**. `--amp` is
the per-act drift value, and at act 0 that is backdrop 30, mid 10, **ledge 0** — so
the ledge carries an animation with zero amplitude. Reduced motion sets
`.sl { animation: none }`.

Combat ports those amplitudes and periods on the three plates
(`combat_screen.gd:734-737`).

### `groundY` is not always 232

Act 2 (index 1) overrides `groundY: 220`, putting its ground line at y **600**
rather than 588 (`src/battlefield-layout.js:147-168`). Act 0 and act 2 (index 2) use
232. The plan's resolved table lists only 232.

### Placement is inline style, and the ledge uses a different formula

`src/ui/combat.js:377-390` — height, left, bottom, opacity, scale and object-position
are written as inline styles per layer, and the ledge's `bottom` is not the others':

```js
img.style.bottom = name === 'ledge'
  ? `${Math.max(0, L.groundY + L.ledgeLip - p.h + p.y)}px`
  : `${p.y}px`;
```

Resolved for our 1180×820 `pad-landscape` stage:

| Act | backdrop | mid | ledge | ground |
|---|---|---|---|---|
| 0 (act1) | h640 bottom280 x0 zoom1 pos 50%/100% op .85 drift30 | h1000 bottom300 x+100 zoom.4 pos 100%/100% op .95 drift10 | h450 bottom0 zoom1 pos 100%/0% op1 drift0 | 588 |
| 1 (act2) | h800 bottom280 x−50 zoom.9 pos 50%/100% op .85 drift30 | h1000 bottom300 x+100 zoom.5 pos 100%/100% op .95 drift10 | h350 bottom0 zoom1 pos 100%/0% op .7 drift0 | **600** |
| 2 (act3) | h800 bottom300 x0 zoom1 pos 50%/100% op .85 drift30 | h1000 bottom200 x−300 zoom.5 pos 100%/100% op .95 drift10 | h320 bottom0 zoom1 pos 100%/0% op .9 drift0 | 588 |

All three plates are `object-fit: cover`, `left:50%`, `translateX(-50%)`,
`min-width:100%`, `bottom:0` before the inline override (`src/styles.css:665-672`).
A missing asset creates no element and has no fallback (`src/art.js:16-23`).

Three details in that CSS that a port can get wrong, each with the source's own
reason attached:

- **`.sl { transform-origin: 0 100% }`** — its comment: *"the scale property then
  multiplies the translateX(-50%) too, so zoom keeps the plate horizontally
  centered and bottom-anchored"*. A plate with `zoom` and a default origin will
  drift sideways as it scales.
- **The ledge's drift is 0 on purpose** — *"the ground plate defaults to 0 so the
  floor never slides under the combatants"*. The `--amp` values in CSS (6/3/0px)
  are fallbacks only; the real per-layer amplitude comes from
  `battlefield-layout.js` `layers.*.drift`, which is 30/10/0 at act 0.
- **The mist sits under the ground plate** — z 2 against the ledge PNG's z 3,
  *"so the ledge plate stays visible"*.

And one that lands on §4.3 of this checklist: *"Screen shake already ripples the
diorama because `#screen` lives inside `#shake`."* The benchmark shakes the whole
composition — stage plates included — which is what `_shake_host` now does.

Act selection is theme insertion order — `act1`, `act2`, `act3` — indexed by
`run.act` (`src/registry.js:571-575`). There are no act-specific CSS selectors,
filters or layer counts: the difference is the art plus the runtime geometry above.

## Ownership

`enemy_view.gd`, `glass_gem.gd`, `facet_pips.gd`, `enemy_lab.gd` and
`char-meta.json` are this lane's. `combat_screen.gd` owns hero placement (§5.1)
and §4's screen-level effects. `IntentChip` and `StatusChip` are finished work from
the chip lane — §3.4 and §3.5 consume them.

## Open decisions

1. ~~**The ward shell (§3.2)**~~ — settled 2026-07-27: a **cut gem held in front
   of** the actor, not an envelope. See §3.2.
2. ~~**`footY`**~~ — settled: keep as authored. See §5.2.
3. ~~**The battlefield has no floor (§5.2)**~~ — settled: combat draws backdrop,
   mid, mist and ledge. Stage-ledge glow and stage-breath stay off, matching the
   benchmark.
4. **Order of work** — the remaining FIX items are short; see the open-work list
   below rather than treating this file as a sprint backlog.
5. **`flare_gain` / 9px kick (§1.4–1.5)** — built; strength still judged in the lab.
6. **`DEAD_KINDS_RENDER` (§4.2)** — off, matching measured benchmark. On would show
   rings/arcs the reference has never drawn.
