# Actor animation checklist

The standing list of which animations an **Actor** — a foe or the player's hero —
should and should not have, and where this port currently stands against each.

Written 2026-07-26 to close the open item recorded in
[`visual-direction.md`](visual-direction.md) § Enemies: *"list which animations
should and should not exist, then work the checklist"*, whose scope was extended
to cover heroes.

## Sources

- **Benchmark** — `roguecardv2` at **`6e069118`**, the approved pre-pixi visual.
  Not `main`, which is a regression. Every benchmark claim below carries a
  `file:line` citation read from that commit.
- **This port** — `presentation/combat/enemy_view.gd`,
  `presentation/combat/combat_screen.gd`, `assets/art/enemies/char-meta.json`.

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

### 1.1 Entrance — **PORT**

Benchmark: `heroIn` / `enemyIn`, 0.55s `cubic-bezier(.2,.75,.3,1)`. The hero
enters from the left (`translateX(-70px)` → 0), foes from the right
(`translateX(90px)` → 0), each foe delayed `160 + i×130ms`
(`styles.css:724-730`, `ui/combat.js:280`, `ui/combat.js:345-351`).

Here: actors appear instantly at encounter start.

The staggered arrival is what tells the player how many foes there are before
reading any chrome, and the opposing directions establish which side each actor
fights for. Both are design.

### 1.2 Idle — **FIX**

Benchmark runs idle at two levels:

- A per-character vertex deformation — sway, breathe, bob, head, cloth — from the
  `mesh` block in the character table. `duskblade` is
  `sway .5, bob 0, breathe 1.6, head 1.35, cloth .75, pin .5`; `ashwarden` is
  `sway 0, bob 0, breathe 1.3, head 0, cloth 0` (`char-meta.js:31-35`,
  `mesh.js:824-844`). Frequencies 0.7–2.5 rad/s, displacement × 0.45
  (`mesh.js:140-161`).
- A per-**kind** CSS idle on foes only: `idleFloat` (wisp 3.1s/16px, eye
  3.4s/18px, siren and shade 3.6s/12px, plant 3.8s/9px), `idleSlime` 4.2s,
  `idleSway` 3.5s, `idleBreathe` 3.6s (`ui/combat.js:1840-1849`,
  `styles.css:1611-1624`).

Here: one idle for every actor — a shared scale-breathe, z-sway and y-bob on the
vessel transform, with only a per-actor phase offset
(`enemy_view.gd:664-686`). The `mesh` blocks sitting in
`char-meta.json` are **never read** — dead data.

A wisp, a slime and an armoured knight currently breathe identically. That is the
gap: the benchmark's idle is character, not decoration.

*The vertex deformation itself is a browser material simulation; a Godot actor can
carry the same intent as a transform or a light vertex shader. Port the intent and
the per-character numbers, not the mesh machinery.*

### 1.3 Attack lunge — **PORT**

Benchmark: `choreoAttack` — wind back `-8×dir px` with `scale(.97,1.02)`, then
lunge `34×dir px` with `scale(1.02,.99)`; 330ms normal, 380ms floaty, 420ms heavy,
`cubic-bezier(.34,1.56,.64,1)`. Floaty hops instead (`6→10×dir px`,
`-5→-2px`); heavy squashes in place to `scale(1.08,.86)`. Fires for the hero on a
card's first non-Art hit, and for a foe on an attack intent
(`ui/combat.js:1953-1977`, `ui/drain.js:494-505`, `ui/drain.js:898-925`).

Here: nothing. A foe acts and only a text label floats up
(`combat_screen.gd:564-570`).

Note the three weight classes — this is not one lunge with a duration knob.

### 1.4 Hit recoil — **BUILT** (`5ff8204`), strength undecided

Benchmark: `choreoHit` — `translateX(9×dir px) scale(.97,1.03)` with
`brightness(1.9)`, 300ms `cubic-bezier(.22,1,.36,1)`, plus a 160ms material flash.
Applies to a foe on `hitEnemy` and to the hero on an ordinary `hitPlayer`.
Poison, burn, self-damage and thorns deliberately do **not** recoil the body
(`ui/combat.js:1979-1989`, `mesh.js:1027-1033`, `ui/drain.js:511-512`,
`ui/drain.js:593-596`).

Here: nothing. The body does not move when struck.

This is the single largest missing beat. The exclusion list matters as much as the
animation: a recoil on every tick of poison would read as being punched by nothing.

### 1.5 Hurt flash — **BUILT** (`5ff8204`), strength undecided

Benchmark: `hurtFlash`, foes only, 0.3s — at 30% `brightness(2.6) saturate(.4)`
with an 18px white glow and `X +7px`, at 60% `X -5px`. Fires on **every**
`hitEnemy` including poison, and on a facet shatter
(`styles.css:788-789`, `ui/drain.js:291-307`, `ui/drain.js:543-548`).

Here: nothing.

Distinct from 1.4 and stacked with it: recoil is the body being moved, the flash is
the glass being lit. Poison gets the flash without the recoil.

Built as `take_hit(direct)` — one call, both beats, split by source. `flare_gain`
is left at 1.0 and is **not** a decision: a 300ms beat cannot be judged from a
still, so the bench drives it (`H` strikes, `J` poisons, a `struck flash` slider,
`time scale` down to 0.05x). Three literal ports of the CSS filter were rejected
along the way and are recorded in the shader — the short version is that
`brightness`, a dilated-alpha halo and `saturate` all mean something different
inside a lit shader than they do over a composited sprite.

Still open in this pair: whether the benchmark's 9px shove is enough. It is kept as
absolute pixels, so a sporeling is knocked 8% of its width sideways and a leviathan
barely twitches — a CSS convenience that happens to read as mass. Judge in motion,
across the size ladder, before changing it.

### 1.6 Stagger — **PORT**, and rewire

Benchmark: `choreoStagger` — foe art only, 360ms
`cubic-bezier(.22,1,.36,1)`, `fill: forwards`: `translateY(+5px)`,
`rotate(-2.5deg)`, brightness → `.6`. It fires on **`die`**, immediately before
ignition (`ui/combat.js:1991-2000`, `ui/drain.js:551-570`).

Here: nothing, and the wiring is wrong in an instructive way — this port floats the
word "staggered" on the `STAGGERED` event (`combat_screen.gd:511-516`) and runs
straight from `mark_dead()` into the ignite ramp with no slump.

The slump is the beat that makes the death rite land: the vessel gives before it
breaks. It belongs to dying, not to the stagger status.

### 1.7 Boss doom — **PORT** (bosses only)

Benchmark: on a boss `die`, 820ms before the stagger — `doomTremble` .09s linear
jitter through `(+1.6,-1)`, `(-1.4,+1.2)`, `(+1,+1.4)px`; the whole screen
transitions over .22s to `saturate(.07) brightness(.85)`; a 110ms hit-stop; crack
paths go white (`styles.css:95-110`, `ui/drain.js:551-566`).

Here: nothing — a boss dies exactly like a sporeling.

The screen desaturation is not an actor animation but it is what the actor's death
commands, so it is listed here.

### 1.8 The death rite — **KEEP the physics, RETIME**

Benchmark: ignition 200ms normal / 320ms boss; then hand-rolled JS ballistics at
`G = 2400 px/s²` with up to two damped bounces (`vy × −.34`, then `× −.22`);
shards hold full opacity 650ms, fade over 380ms; the corpse class switches at 830ms
(`ui/combat.js:2011-2037`, `vfx.js:283-345`, `ui/drain.js:566-584`).

Here: 0.45s ignite, then real `RigidBody3D` shards with engine gravity, per-shard
cool and dissolve tweens, burst flash, embers, fire flash and camera shake
(`enemy_view.gd:875-1061`).

`V.shatter` is flagged in the source review as a **physics substitute** — the whole
reason this port is in Godot. Keep ours. But the *timing* is design and ours is
slower: 0.45s of ignition against the benchmark's 0.2s. A rite that dawdles reads
as a cutscene.

### 1.9 Low-HP body slump — **DECLINE**

Benchmark has the rules — `.9s ease`, foe `rotate 2.4deg / Y +4px / scale .985`,
hero `rotate -2deg / Y +4px` — but the selector only ever reaches the SVG aim-ring
and crack overlay. The live painted body is an `img.raster-art` the rule never
matches, and the crack overlay is separately reset to `transform:none`
(`ui/combat.js:729-774`, `ui/assets.js:5-8`, `styles.css:969-970`,
`styles.css:1605-1608`).

Dead at the visual standard. Do not build it.

### 1.10 Cracks from ordinary damage — **DECLINE**

`COMBAT_CRACKS = false`. Landed hits call `addCrack`, which returns immediately.
Only death forces cracks (`ui/combat.js:2001-2019`, `ui/drain.js:543-546`).

Confirms `CONCEPTS.md` › **Crack**: the glass vocabulary is spent on death, not on
attrition. Here, `crack()` is already only called from the lab — correct as is.

---

## 2. Cast shadow — **KEEP**

Benchmark: `syncCastShadow`, a squashed sprite copy resynchronised every frame.
Explicitly flagged a workaround — a shadow surrogate, because CSS cannot project.
At full lift `t=1`: scaleX ×`.74`, scaleY ×`.5`, opacity ×`.45`, blur `+2.8px`,
skew reduced 35%, from a base of `scale(1,.24)`, opacity `.62`, blur `1.5px`
(`char-meta.js:8`, `ui/combat.js:1771-1819`, `styles.css:767-782`).

Here: derived by projecting the silhouette along the key light, done in `0c8ed59`
and documented. Correct, and it does something the source could not — swing the key
and the shadow swings.

One thing worth checking rather than assuming: our lift response
(`f*0.5` on scale, `1-f*1.2` on opacity, `1+f*4` on softness —
`enemy_view.gd:613-634`) was authored, not matched. The benchmark's full-lift
figures above are the only numbers in this area that describe taste rather than
geometry, so they are worth diffing against.

---

## 3. Chrome hanging off the actor

### 3.1 HP vial — **PORT**

Benchmark: the fill transitions over .35s `cubic-bezier(.3,1,.4,1)`, and a second
**ghost** bar trails it over .9s ease with a .25s delay
(`ui/combat.js:721-726`, `ui/combat.js:764-774`, `styles.css:833-835`).

Here: the value is assigned outright (`enemy_view.gd:1380-1387`). No drain, no ghost.

The ghost is the whole point — it shows how much was just taken, not merely how
much is left.

### 3.2 Ward — **PORT** the pulse; the shell is a **DECISION**

Benchmark has two separate things:

- `blockPulse` on the chip: .4s ease-out, scale peak 1.3, 22px glow
  (`ui/drain.js:618-633`, `styles.css:857-859`).
- A ward **shell** around the body: an oversized (`pad 1.46`), opacity .4,
  32-site refractive glass envelope, growing and fading over 560ms; a re-gain
  shrinks the sites to .12 over 45% of the tween then regrows
  (`mesh.js:920-967`, `ward-params.js:3-21`).

Here: the ward chip appears and disappears instantly (`enemy_view.gd:1389-1392`).

The pulse is a straight port. The shell is genuinely open: the *implementation* is a
WebGL material simulation, but "temporary protection reads as a glass envelope
around the body" is a design idea, and this project's whole vocabulary is glass.
See § Open decisions.

### 3.3 Facet gauge — **PORT** `chipPop`, **DECLINE** `pvPulse`

Benchmark: `chipPop` .4s ease-out, peak scale 1.35, added on the `chip` event
(`ui/drain.js:279-289`, `styles.css:955-960`).

`pvPulse` (.9s infinite opacity to .4, the target-preview hint) is explicitly
`animation:none` for the real raster facet pips — the rule survives only on the
HP-preview bar (`styles.css:987-1063`).

Here: `set_pips()` re-draws instantly (`facet_pips.gd:32-39`).

### 3.4 Status row — **KEEP** the stillness, **FIX** the widget

Benchmark: no entry or exit animation. The row is rebuilt synchronously
(`ui/combat.js:660-674`, `ui/drain.js:635-645`). `.schip.pop` exists in CSS but
nothing ever adds the class (`styles.css:890-891`) — dead.

So: no animation is the correct answer, and this port already matches. But the
actor still renders statuses as a plain `" · "`-joined `Label`
(`enemy_view.gd:1404-1410`) while a finished `StatusChip` widget exists,
benchmark-matched and signed off in its own lane. Integration debt, not animation.

### 3.5 Intent telegraph — **PORT** `teleFlash`, **FIX** the widget

Benchmark: `teleFlash` .5s `ease-in-out` × 2 iterations — midpoint scale 1.22,
brightness 1.8, 10px current-colour glow — fired on every `enemyAct`, with a 300ms
lead **before** the body lunge (`ui/drain.js:898-925`, `styles.css:893-908`).
`.intent.pop` is dead CSS (`styles.css:938`).

Here: the text swaps instantly, and the actor builds its own inline chip
(`enemy_view.gd:1247-1249`) with a comment noting the standalone `IntentChip`
should be swapped in. Same integration debt as 3.4.

The 300ms lead is the read: the telegraph fires, *then* the body moves. Simultaneous
would be unreadable.

### 3.6 Targeting — **FIX**

Benchmark has **two** states: `targetGlow`, a 1s `ease-in-out infinite` pulse from
6px to 18px red on every targetable foe; and `.target-hover`, which *kills* the
pulse and goes to a solid 22px glow with `brightness(1.25)`
(`ui/combat.js:1199-1257`, `styles.css:1237-1251`).

Here: one state, and it snaps. `set_targetable(on)` flips a shader uniform between
0 and 1 with no transition (`enemy_view.gd:1222-1228`), and
`combat_screen.gd:354-361` lights only the hovered foe — so there is no
"these are the legal targets" pulse at all.

Two defects: the missing pulse state, and the instant on/off.

---

## 4. Actor-centred effects that live on the screen, not the actor

Listed because they are triggered by an actor and aimed at one; ownership noted in
§ Ownership.

### 4.1 Floating text — **PORT**

Benchmark: 1100ms normal / 1250ms crit, `cubic-bezier(.2,.7,.3,1)`; scale
`.6→1.15→.95`, rise `-50%` → `-230%`, random ±20px drift. Poison **descends** to
`+80%` instead. A crit peaks at 1.45, holds, then rises and fades
(`vfx.js:175-210`).

Here: `_float_text` rises 46px linearly over 0.6s and fades
(`combat_screen.gd:437-451`). No crit form, no descending poison, no overshoot.

### 4.2 Impact particles — **PORT** (its own phase)

Benchmark dispatches by damage archetype — slash, pierce, blunt, fire, poison,
void, ward — into arcs, sparks, rings, bursts, droplets and motes, each with its own
life (`ring` .45s, `slashArc` .14s sweep / .3s life, motes .9–1.4s, droplets
.6–.9s, shard spray .5–.8s, trail .5–.9s) under per-frame velocity, gravity and drag
(`vfx.js:51-149`, `vfx.js:362-431`).

Here: nothing.

Large enough that it should not be bundled with anything else.

### 4.3 Screen shake, hit-stop, flash — **FIX**

Benchmark: shake at initial power 4–22 decaying `power × 0.001^dt`, applied to
**all** battlefield actors through one `#shake` wrapper; hit-stop 70ms on a big
hit, 90/130ms on a kill, 90ms on a facet shatter, 110ms on a boss death — during
which the particle loop freezes; colour flashes at .09/.24/.28/.3s
(`vfx.js:52-57`, `vfx.js:127-149`, `ui/drain.js:291-306`).

Here: a camera shake exists but it lives **inside each actor's own SubViewport**
(`enemy_view.gd:664-669`) — so it shakes one creature's private stage while the
rest of the battlefield holds still. There is no hit-stop at all.

Wrong level. The shake belongs to the battlefield.

### 4.4 Ember flight — **PORT**

Benchmark: `flyTo`, 460ms or 520ms, motes staggered `i×46ms`,
`cubic-bezier(.32,.05,.35,1)`, scale `.5→1.05→.55`, lofted waypoint. Used for
ember gain and `smolderJump` (`ui/combat.js:1420-1478`, `ui/drain.js:351-380`).

Here: nothing — `EMBER` updates a label, `SMOLDER_JUMP` just waits
(`combat_screen.gd:523-526`, `combat_screen.gd:571-572`).

---

## 5. Structural, not animation

### 5.1 The hero is not an actor here — **PORT**

Benchmark: the hero is a raster-painted battlefield combatant created by
`heroArt(S.run.aspect)`, resolving `duskblade` / `ashwarden`, carrying the same cast
shadow, idle deformation, ward shell and hit recoil as a foe. It explicitly
**cannot** crack or shatter (`ui/combat.js:215-237`, `ui/assets.js:43-48`,
`ui/combat.js:1820-1903`).

Here: the hero is a `PanelContainer` with a "The Duskblade" text label
(`combat_screen.gd:135-182`). The paintings exist, `char-meta.json` gives them
`tier: hero` at 285px, and `enemy_lab`'s bench stands them up — but the fight has
no hero body.

Note the chrome does **not** mirror a foe's foot plate: `hud_bar.gd` already carries
the hero's HP and ward, by its own lane's design.

### 5.2 `footX` / `footY` — **KEEP**, but they are judged against a floor we do not draw

Settled against the source, and the answer inverts the first reading.

**The port is faithful.** In the benchmark, positive `footY` moves an actor up and
negative moves it down (`battlefield-layout.js:8`, `ui/combat.js:397`), so
`duskblade`'s `footY: -30` sinks it ~30px below the ground line *there too*. Our
lab roster reproduces the benchmark, it does not deviate from it.

**Hero and foes share one ground line**, confirmed arithmetically: both `bottom`
values are relative to `.battlefield`'s bottom edge, which sits `groundY = 232`
above a stage bottom of `H = 820`; with `footY = 0` a hero and a normal-tier foe
both land at stage y 588 (`battlefield.js:86`, `battlefield.js:144`,
`battlefield-layout.js:30`, `stage.js:23`).

**`footY` is not canvas slack.** The numbers do not correlate with the paintings:

| Painting | Size | Empty canvas below body | Scaled into its box | Authored `footY` |
|---|---|---|---|---|
| `duskblade.png` | 825×1024 | 9px | ~2.5px of 285 | **−30** |
| `ashwarden.png` | 682×1024 | 23px | ~6.4px of 285 | 0 |
| `duskfang.png` | 1024×1024 | 62px | ~11px of 327 | 0 |
| `sporeling.png` | 1024×1024 | 62px | ~7px of 115 | 0 |

The source's only stated semantic is "corrects art where feet aren't at the
sprite's bottom edge" (`battlefield-layout.js:8`), and no comment claims a
deliberate body position. So it is an eyeballed nudge — **taste, not geometry**,
which by the derive-vs-transcribe rule means it is design and gets ported as-is.
Do not derive it.

**`footY` is also not how floating works.** All four suspected floaters carry
`footY: 0`. Hovering is expressed by the per-kind CSS idle bob — `voidWisp` 16px,
`watcherEye` 18px, `shade` 12px, all via `idleFloat` — plus `mesh.float` when the
mesh is on; `voltEel` sways instead and overrides `mesh.float: 1.1`.
`shadow.dy` moves only the shadow, never the body
(`char-meta.js:44-55`, `styles.css:1612-1621`, `ui/combat.js:1807`,
`mesh.js:1143`). The conflation this checklist worried about does not exist in the
source: floating and `footY` are two separate mechanisms, and floating is part of
§1.2, not of placement.

**What actually breaks, then.** The benchmark stands its actors on a *painted*
ground — `sl-ledge`, described in its own CSS as a "ground/ledge PNG" placed
"under feet" (`ui/combat.js:216`, `styles.css:662`). An eyeballed −30 that
correlates with nothing measurable is very likely someone landing Duskblade on the
painted ledge rather than on the abstract line.

This port draws no ledge. `combat_screen.gd:56-88` builds the battlefield from a
night gradient, an ember glow and a vignette; `enemy_lab` draws a 1px rule. So a
value authored against painted ground is being judged against nothing, and reads as
sunk.

The stage art is already here and already imported —
`assets/art/stage/act{1,2,3}-{backdrop,mid,ledge}.png` — and the reward lane
already uses all three layers (`reward_reliquary.gd:118-122`). The combat screen
uses none of them.

**Therefore this is not a `footY` task.** See § Open decisions 4.

### 5.3 Dead data in `char-meta.json` — **FIX or DELETE**

The `mesh` blocks (§1.2) and the nine `shadow` knobs (already vestigial per the
solutions doc) are carried but unread. Either wire `mesh` up as part of §1.2 or
delete it; data that looks like tuning but changes nothing costs the next reader an
hour.

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
defined, `styles.css` closes them out:

```css
/* act-themed ground glow off — stage-ledge + stage-breath both tint --ledge (act1 = green) */
.stage-ledge, .stage-breath { opacity: 0; animation: none; }
```

So the 120px ledge glow band with its 1.5px lit lip (S1 step 3) and the two
breathing blobs (S1 step 4) **do not appear** at the visual standard — and the
comment gives the reason rather than leaving it a mystery: both tint `--ledge`,
and act 1's `--ledge` resolves green. This is a decision that was made and
recorded, not a leftover.

**Landed anyway.** `933ab46 feat(stage): the fight gets a ground to stand on`
builds both: `combat_screen.gd` `_breath()` ×2 with the 7s `.06 → .16` pulse, and
the `.stage-ledge` band plus its lip. Worth raising with that lane — either the
green is wanted here (a deliberate departure, which is allowed) or two layers are
paying for themselves in nothing.

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
its own comment says the cast shadow replaced it (`styles.css:1602-1604`).

### The plates drift — the ledge does not

`sl-drift`, `ease-in-out infinite alternate`, horizontal `translateX(-50% ∓ --amp)`
(`styles.css:670-677`): backdrop **26s**, mid **18s**, ledge **12s**. `--amp` is
the per-act drift value, and at act 0 that is backdrop 30, mid 10, **ledge 0** — so
the ledge carries an animation with zero amplitude. Reduced motion sets
`.sl { animation: none }`.

S1 defers the drift as a later pass, which is fine; worth knowing the ledge never
needs it.

### `groundY` is not always 232

Act 2 (index 1) overrides `groundY: 220`, putting its ground line at y **600**
rather than 588 (`battlefield-layout.js:147-168`). Act 0 and act 2 (index 2) use
232. The plan's resolved table lists only 232.

### Placement is inline style, and the ledge uses a different formula

`ui/combat.js:377-390` — height, left, bottom, opacity, scale and object-position
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
`min-width:100%`, `bottom:0` before the inline override (`styles.css:665-672`).
A missing asset creates no element and has no fallback (`art.js:16-23`).

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
composition — stage plates included — which is further confirmation that a shake
living inside one actor's `SubViewport` is at the wrong level.

Act selection is theme insertion order — `act1`, `act2`, `act3` — indexed by
`run.act` (`registry.js:571-575`). There are no act-specific CSS selectors,
filters or layer counts: the difference is the art plus the runtime geometry above.

## Ownership

`enemy_view.gd`, `glass_gem.gd`, `facet_pips.gd`, `enemy_lab.gd` and
`char-meta.json` are this lane's. `combat_screen.gd` was this lane's from
2026-07-26 for the hero placement in §5.1; §4's items live there too and should be
confirmed rather than assumed. `IntentChip` and `StatusChip` are finished work from
the chip lane — §3.4 and §3.5 consume them, they are not to be re-designed here.

## Open decisions

1. **The ward shell (§3.2)** — build a glass envelope around a warded actor, or
   keep ward as chrome only? The implementation was a browser workaround; the idea
   may be design.
2. ~~**`footY`**~~ — settled: keep as authored. See §5.2.
3. **The battlefield has no floor (§5.2)** — the ledge, mid and backdrop art is in
   the repo and unused by combat. Placement cannot be judged until the actors have
   ground to stand on, so this now blocks §5.1 rather than the other way round.
   Does the combat screen get its three stage layers, and is that this lane's work
   or the screen's?
4. **Order of work** — this list is long. It is not a sprint.
