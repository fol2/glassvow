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

### 1.1 Entrance — **BUILT** (was two concurrent foe paths)

Benchmark: `heroIn` / `enemyIn`, 0.55s `cubic-bezier(.2,.75,.3,1)`. The hero
enters from the left (`translateX(-70px)` → 0), foes from the right
(`translateX(90px)` → 0), each foe delayed `160 + i×130ms`
(`src/styles.css:725-729`, `src/ui/combat.js:280`). The animation is on `.enemy`
and `.player-zone` — the boxes that carry the name plate, the HP vial and the
intent — and `animation-fill-mode: backwards` holds the `from` frame through the
delay. The hero has no delay.

**Resolved 2026-07-27.** Both paths were partly right, which is why neither
looked broken: `EnemyView.enter` had the stagger and moved the vessel inside its
3D stage, so the chrome stood at the destination waiting for the painting to
arrive; `CombatScreen._enter` moved the Control with the exact `Motion.ENTER`
curve, the hero's −70px and the `_stand` re-anchor, and had no stagger. The
Control is the correct element and the stagger is the correct behaviour, so they
are one function: `EnemyView.enter(delay, done)` owns the motion and the fill,
`_play_entrance` owns the seat delay and the re-anchor (`enemy_view.gd:2800` (`enter`),
`combat_screen.gd:1134` (`_play_entrance`)). The `view.enter(...)` call in `_build_battlefield`,
which fired a frame earlier and set foe alpha to zero under the other path's
nose, is gone.

Measured on the `--enter` strip: the actor's bright centroid travels 79.6 canvas
px with an ease-out profile, and the plate and rail travel with it.

### 1.2 Idle — **BUILT** (was the missing CSS kind layer)

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

Here: the **mesh layer matches**. `IDLE_PROFILES` matches the benchmark
`PROFILE` table, `_read_idle` overlays the character's `mesh` block, and the six
terms run in `BODY_SHADER` (`enemy_view.gd:517-537` (`IDLE_PROFILES`),
`enemy_view.gd:2607-2611` (`_read_idle`), `enemy_view.gd:834-1159` (`BODY_SHADER`)).

**The kind layer is built (2026-07-27).** All four shapes, at the source's own
amplitudes and periods, composed onto the vessel beside the recoil rather than
tweened onto it (`enemy_view.gd:564` (`KIND_IDLE`); applied at
`enemy_view.gd:2156` (in `_process`)):

| Shape | Kinds | Values |
| --- | --- | --- |
| `idleFloat` | wisp, eye, siren, shade, plant | 16 / 18 / 12 / 12 / 9 px over 3.1 / 3.4 / 3.6 / 3.6 / 3.8 s |
| `idleSlime` | slime | `translateY 0 / −4 / +2` with `scaleX 1 / 1.04 / .97` at 0/33/66%, 4.2s |
| `idleSway` | serpent | `translateX 5px` with `rotate 1.8deg`, 3.5s |
| `idleBreathe` | beast, rogue, cultist, knight, zombie, crawler | `scaleY 1.025`, 3.6s |

Two things the port did not previously distinguish. **CSS eases every keyframe
interval**, not once across the iteration the way a WAAPI list does, so
`idleSlime`'s three stops are three eased segments — `Motion.css_keyframe` is
that contract and `Motion.keyframe` is the other one (`motion.gd:75` (`css_keyframe`)). And
**`idleSlime` does leave the ground**, briefly, and also sinks below it; the
shadow reads `max(0, y)` exactly as `spriteLiftPx` does, so the dip is its own
beat rather than a shadow underground.

`idleFloat` came first as part of §2 — a shadow that answers the body's height
has nothing to answer while the floaters move `1.35 × 12 × .45 = 7.29px` on a
5.46s sine against the benchmark's 16px on 3.1s.

**The motes are built too** — `IdleMotes` (`idle_motes.gd:1` (`IdleMotes`)), two drifting
spores on wisps and plants only, in the creature's own hue, hung on the actor's
Control between the painting and the plate the way `.idle-motes` sits at
`z-index: 2` inside `.enemy-sprite`. Deliberately not seed-desynced:
`animation-delay` does not inherit, so two wisps drift in lockstep over there
too.

**Two lab defects surfaced on the way.** The sheet never called `set_profile`, so
every creature on the one surface built to judge the actors idled as a humanoid —
an idle no fight ever runs (`enemy_lab.gd:414` (in `_actor`)). And there was no way to look at
the kind layer at all, which is the likelier reason nobody noticed: `--idle` is
now a strip mode (`enemy_lab.gd:1303` (in `_ready`)). It runs in REAL time, unlike every other
strip here, because the idle clock is `Time.get_ticks_msec` and `Engine.time_scale`
cannot reach it.

### 1.3 Attack lunge — **FIX** the curve

Benchmark: `choreoAttack` — wind back `-8×dir px` with `scale(.97,1.02)`, then
lunge `34×dir px` with `scale(1.02,.99)`; 330ms normal, 380ms floaty, 420ms heavy,
`cubic-bezier(.34,1.56,.64,1)`. Floaty hops instead (`6→10×dir px`,
`-5→-2px`); heavy squashes in place to `scale(1.08,.86)`. Fires for the hero on a
card's first non-Art hit, and for a foe on an attack intent
(`src/ui/combat.js:1953-1977`, `src/ui/drain.js:494-505`, `src/ui/drain.js:898-925`).

Here: built as `EnemyView.lunge` with the same three kind sets and keyframe
numbers (`enemy_view.gd:258-293` (`HEAVY_KINDS`), `enemy_view.gd:2754-2777` (`lunge`)). The hero swings once
per non-Art card (`combat_screen.gd:1785`, `combat_screen.gd:2086-2091`); a foe
telegraphs, waits 300ms, then lunges (`combat_screen.gd:2281-2287`). Durations
and keyframes match; the
remaining difference is `TRANS_BACK/EASE_OUT` versus the benchmark's
`cubic-bezier(.34,1.56,.64,1)` (`enemy_view.gd:2572-2577` (in `lunge`)).

### 1.4 Hit recoil — **FIX** the recoil curve and indirect white beat

Benchmark: `choreoHit` — `translateX(9×dir px) scale(.97,1.03)` with
`brightness(1.9)`, 300ms `cubic-bezier(.22,1,.36,1)`, plus a 160ms material flash.
Applies to a foe on `hitEnemy` and to the hero on an ordinary `hitPlayer`.
Poison, burn, self-damage and thorns deliberately do **not** recoil the body
(`src/ui/combat.js:1979-1989`, `src/mesh.js:1027-1033`, `src/ui/drain.js:511-512`,
`src/ui/drain.js:593-596`).

Here: direct hits now give foes and the hero the same ±9px displacement, 3%
squash, 300ms duration and 160ms square-wave white material beat
(`enemy_view.gd:2511-2565`, `combat_screen.gd:2100`,
`combat_screen.gd:2195`). The recoil still differs: the benchmark reaches its
peak at 25% (75ms) with `cubic-bezier(.22,1,.36,1)`, while Godot starts at the
peak at 0ms and decays with `TRANS_QUINT/EASE_OUT`.

The white beat is also wired too broadly. `_white_beat()` runs before the
`direct` branch, so poison, facet shatter and indirect hero damage receive it;
the benchmark only calls `meshFlash` through `choreoHit`, which excludes those
indirect paths (`enemy_view.gd:2954-2963` (`_white_beat`),
`combat_screen.gd:1833`, `combat_screen.gd:2163`,
`combat_screen.gd:2195`).

### 1.5 Hurt flash — **FIX** the extra hero nudge

Benchmark: `hurtFlash`, foes only, 0.3s — at 30% `brightness(2.6) saturate(.4)`
with an 18px white glow and `X +7px`, at 60% `X -5px`. Fires on **every**
`hitEnemy` including poison, and on a facet shatter
(`src/styles.css:788-789`, `src/ui/drain.js:291-307`, `src/ui/drain.js:543-548`).

Here: the foe beat is live. It peaks after 90ms, lasts 300ms and follows the
benchmark's +7/−5px nudge; poison gets it without recoil
(`enemy_view.gd:2570-2601`, `combat_screen.gd:2160-2163`). The material is an
intentional shader translation rather than a numeric CSS match: benchmark
brightness 2.6, saturation .4 and an 18px halo become `flare_gain = 1`, up to
1.8× albedo with 10% desaturation, a ×4 light term and a small rim emission
(`enemy_view.gd:1010-1044`).

The wiring still differs: every indirect hero hit calls `take_hit(false)`, which
adds the +7/−5px nudge even though `hurtFlash` is foe-only in the benchmark
(`combat_screen.gd:2173-2195`). Remove that extra hero motion; do not add the
foe-only material flare to the hero.

### 1.6 Stagger — **FIX** the curve

Benchmark: `choreoStagger` — foe art only, 360ms
`cubic-bezier(.22,1,.36,1)`, `fill: forwards`: `translateY(+5px)`,
`rotate(-2.5deg)`, brightness → `.6`. It fires on **`die`**, immediately before
ignition (`src/ui/combat.js:1991-2000`, `src/ui/drain.js:551-570`).

Here: built and wired to dying. `EnemyView.stagger` is the same 5px / −2.5° /
0.6 modulate / 0.36s (`enemy_view.gd:2889-2900` (`stagger`)). `_die` awaits it before
`mark_dead` (`combat_screen.gd:2272-2275` (in `_die`)). The `STAGGERED` status still floats
its label and runs `reseam` (`combat_screen.gd:1865-1876` (in `_handle_event`)) — that is the facet
reseam, not this death slump, and matches the benchmark's split. The remaining
difference is `TRANS_CUBIC/EASE_OUT` versus
`cubic-bezier(.22,1,.36,1)` (`enemy_view.gd:2698` (in `stagger`)).

### 1.7 Boss doom — **FIX** the live crack blaze

Benchmark: on a boss `die`, 820ms before the stagger — `doomTremble` .09s linear
jitter through `(+1.6,-1)`, `(-1.4,+1.2)`, `(+1,+1.4)px`; the whole screen
transitions over .22s to `saturate(.07) brightness(.85)`; a 110ms hit-stop; crack
paths go white (`src/styles.css:95-110`, `src/ui/drain.js:551-566`).

Here: boss-only timing, 820ms world-stop, 110ms hit-stop, .22s transition,
.07 saturation, .85 brightness and .09s tremble are built and wired
(`combat_screen.gd:152-157` (`WORLDSTOP_SAT`), `combat_screen.gd:2229-2246` (in `_hit_player`),
`enemy_view.gd:236-239`, `enemy_view.gd:2032-2038`). The actor pixels
desaturate too, unlike the benchmark's separate mesh canvas; that is a documented
structural departure (`combat_screen.gd:142-151` (in `WORLDSTOP_SAT`)).

The visible crack blaze is absent. `set_doomed()` writes only the legacy
`_glass_mat`, while the default `CrackField` route lives in `BODY_SHADER`;
legacy discs are off (`enemy_view.gd:4683-4691` (`set_doomed`),
`enemy_view.gd:834-1159` (`BODY_SHADER`)). The current fracture seams therefore never receive
the benchmark's white-doom state.

### 1.8 The death rite — **KEEP**

Benchmark: ignition 200ms normal / 320ms boss; then hand-rolled JS ballistics at
`G = 2400 px/s²` with up to two damped bounces (`vy × −.34`, then `× −.22`);
shards hold full opacity 650ms, fade over 380ms; the corpse class switches at 830ms
(`src/ui/combat.js:2011-2037`, `src/vfx.js:283-345`, `src/ui/drain.js:566-584`).

Here: `mark_dead(beat)` ignites over the caller's beat — combat passes 0.2s /
0.32s boss (`combat_screen.gd:2244-2247`, `enemy_view.gd:3497-3528` (`mark_dead`)) — then real
`RigidBody3D` shards with engine gravity, per-shard cool and dissolve, burst
flash, embers and camera shake. Ignition timing matches; physics is the Godot
substitute and stays. Its numbers deliberately differ: Godot uses `gravity_scale = 2.4`,
restitution .35 and random 0.90–1.40s shard life, versus the benchmark's
`G = 2400`, fixed −.34/−.22 bounces and 650ms + 380ms opacity life
(`enemy_view.gd:3574-3603` (in `shatter`)).

### 1.9 Low-HP body slump — **DECLINE**

Benchmark has the rules — `.9s ease`, foe `rotate 2.4deg / Y +4px / scale .985`,
hero `rotate -2deg / Y +4px` — but the selector only ever reaches the SVG aim-ring
and crack overlay. The live painted body is an `img.raster-art` the rule never
matches, and the crack overlay is separately reset to `transform:none`
(`src/ui/combat.js:729-774`, `src/ui/assets.js:5-8`, `src/styles.css:969-970`,
`src/styles.css:1605-1608`).

Dead at the visual standard. Do not build it.

### 1.10 Cracks from ordinary damage — **KEEP** the owner-approved departure

Benchmark: `COMBAT_CRACKS = false`. Landed hits call `addCrack`, which returns
immediately. Only death forces cracks (`src/ui/combat.js:2001-2019`,
`src/ui/drain.js:543-546`). That was the reading when this entry first said
**DECLINE**.

The former DECLINE is void. `CONCEPTS.md` › **Crack** was rewritten at the owner's
direction: cracks **are** driven by damage. What was built is the whole of
`docs/fracture-model.md` — a propagated fracture model, a groove in
`BODY_SHADER`, a carve so the death rite breaks along carried cracks, and
damage→fracture energy through calibrated `bite`. Combat scores cracks on landed
hits (`combat_screen.gd:2139`). Cap is **eight impacts**, matching the
reference's drawn-crack cap (`enemy_view.gd:104` (`MAX_SITES`)).

This intentionally differs from the non-rendering benchmark behaviour; it is not
open parity work.

---

## 2. Cast shadow — **DERIVE** (built)

Benchmark: `syncCastShadow`, a squashed sprite copy resynchronised every frame.
Explicitly flagged a workaround — a shadow surrogate, because CSS cannot project.
At full lift `t=1`: scaleX ×`.74`, scaleY ×`.5`, opacity ×`.45`, blur `+2.8px`,
skew reduced 35%, from a base of `scale(1,.24)`, opacity `.62`, blur `1.5px`
(`src/char-meta.js:8`, `src/ui/combat.js:1771-1819`, `src/styles.css:767-782`).

Here: derived by projecting the silhouette along the key light
(`enemy_view.gd:2211` (`_update_shadow`)). **Built out 2026-07-27** — the grade
above was the shape; the lift response was neither matched nor alive.

Two defects, both fixed. **It never ran.** `_update_shadow` was called at build,
at reset, and from two lab-bench setters no fight reaches — nothing else — while
the benchmark resynchronises against the
body's live transform on every frame of the rig loop
(`src/ui/combat.js:1930-1932`). **And its one variable was the wrong quantity:**
`_lift` was the transparent margin below the painting's lowest opaque row, which
is a uniform export border, not height — bottom matches top to a tenth of a
percent on 13 of the 27 and to within a percentage point on 18 (10.0/10.0,
5.2/5.2, 13.0/13.0, 20.7/20.6), the largest
belongs to `shellback` (a crab, flat on the floor) at 20.7%, and `voidWisp` has
4.3%. The response was therefore inverted as well as frozen.

Height now comes from the body's own transform, floored at zero exactly as
`spriteLiftPx` is, and the benchmark's response is ported by ratio: width
`×(1-.26t)`, length `×(1-.5t)`, opacity `×(1-.55t)`, softening `×2.87` at full
lift. `t` is normalised against `floatKinds` (`SHADOW_MAX`), plus the creature's
resting hover so the four whose `dy` already meets their kind's span are not
pinned at full fade. The skew relax is deliberately not ported — there the lean
is a hand-set fake being walked back, here it is the projection.

The projection also does the thing nine authored knobs could not: the contact
point **moves**. A rising creature slides its shadow along the light's ground
track (`hover * l.x * run`) and leaves it behind. Measured on `watcherEye` over
eight frames of its own hover: shadow mass swings 22.3k → 28.3k, centroid travels
11.4px.

Per-creature `shadow` knobs in `char-meta.json` are unread except `dy` — §5.3.

---

## 3. Chrome hanging off the actor

### 3.1 HP vial — **FIX** (ghost **KEEP**; fill still snaps)

Benchmark: the fill transitions over .35s `cubic-bezier(.3,1,.4,1)`, and a second
**ghost** bar trails it over .9s ease with a .25s delay
(`src/ui/combat.js:721-726`, `src/ui/combat.js:764-774`, `src/styles.css:833-835`).

Here: ghost is built — hold 0.25s, fall 0.9s (`GHOST_HOLD` / `GHOST_FALL`,
`enemy_view.gd:45-46` (`GHOST_HOLD`), `enemy_view.gd:4022-4035` (in `_build_chrome`)). The live fill is still assigned
outright (`enemy_view.gd:4006-4014` (in `_build_chrome`)). The ghost timings match, but its
`TRANS_SINE/EASE_IN_OUT` curve differs from the benchmark's CSS `ease`. The
fill's 0ms versus 350ms transition is the larger remaining gap.

### 3.2 Ward — **FIX** the chip curve and shell re-gain; shell design **KEEP**

Benchmark has two separate things:

- `blockPulse` on the chip: .4s ease-out, scale peak 1.3, 22px glow — on player
  **and** foe chips (`src/ui/drain.js:618-633`, `src/styles.css:857-859`).
- A ward **shell** around the body: an oversized (`pad 1.46`), opacity .4,
  32-site refractive glass envelope, growing and fading over 560ms; a re-gain
  shrinks the sites to .12 over 45% of the tween then regrows
  (`src/mesh.js:920-967`, `src/ward-params.js:3-21`).

Here: the shell was decided and built against "an envelope around the body". It
is a cut gem held in front of the mob (`WARD_*` block, `enemy_view.gd:200-234` (`WARD_OPACITY`),
`set_ward_shell` at `enemy_view.gd:2500-2537` (`set_ward_shell`)) — ordered facets, no hash, breaks on
its own cuts. Initial grow (560ms), opacity (.4) and colour match. Re-gain does
not: the benchmark shrinks for 252ms then regrows for 308ms; Godot shrinks for
308ms and snaps straight back to full (`enemy_view.gd:208-209` (`WARD_PULSE`),
`enemy_view.gd:2539-2600` (`_step_ward`)). Full design reasoning is in
`docs/fracture-model.md` §9.

The actor chip now pulses on first and subsequent gains: a first hidden→visible
gain waits one layout frame before starting, then every gain runs 0.4s to a
1.3-scale / 22px-glow peak and home (`enemy_view.gd:4038-4079`). Those numbers
match. Its `TRANS_CUBIC/EASE_OUT` curve is only an approximation of CSS
`ease-out`, the same curve difference as §3.3.

### 3.3 Facet gauge — **FIX** the `chipPop` curve; **DECLINE** `pvPulse` on pips

Benchmark: `chipPop` .4s ease-out, peak scale 1.35, added on the `chip` event
(`src/ui/drain.js:279-289`, `src/styles.css:955-960` / facet-row at `:1058`).

`pvPulse` (.9s infinite opacity to .4) is explicitly `animation:none` for the
real raster facet pips — the rule survives only on the HP-preview bar
(`src/styles.css:987-1063`).

Here: `FacetPips.pop` is the 1.35 peak over 0.4s (`facet_pips.gd:68-75` (`pop`)), driven
from `set_facets(..., pop)` (`enemy_view.gd:4549-4556` (`set_facets`)). HP-preview `pvPulse` is
ported on the rail (`PREVIEW_PULSE` 0.9 / dip 0.4, `enemy_view.gd:41-43`,
`enemy_view.gd:2113-2114` (in `_process`)) — that is the live rule, not a pip animation. The
duration and 1.35 peak match; `TRANS_CUBIC/EASE_OUT` is not the benchmark's CSS
`ease-out`.

### 3.4 Status row — **KEEP**

Benchmark: no entry or exit animation. The row is rebuilt synchronously
(`src/ui/combat.js:660-674`, `src/ui/drain.js:635-645`). `.schip.pop` exists in CSS
but nothing ever adds the class (`src/styles.css:890-891`) — dead.

Here: `StatusRow` / `StatusChip` are integrated (`enemy_view.gd:3684-3688`,
`enemy_view.gd:4126-4127`). No enter/exit animation — correct. The old
`" · "`-joined `Label` is gone.

### 3.5 Intent telegraph — **FIX** the curve and transient glow

Benchmark: `teleFlash` .5s `ease-in-out` × 2 iterations — midpoint scale 1.22,
brightness 1.8, 10px current-colour glow — fired on every `enemyAct`, with a 300ms
lead **before** the body lunge (`src/ui/drain.js:898-925`, `src/styles.css:893-908`).
`.intent.pop` is dead CSS (`src/styles.css:938`).

Here: `IntentChip` is the actor's telegraph (`enemy_view.gd:3912` (in `_build_chrome`)).
`telegraph()` is two 0.5s loops peaking at scale 1.22 / modulate 1.8
(`intent_chip.gd:166-176` (`telegraph`)). Drain order: telegraph → float name → wait 0.3s →
lunge (`combat_screen.gd:2281-2287`). The numeric beats match, but Godot uses
`TRANS_SINE/EASE_IN_OUT` rather than CSS `ease-in-out`, and it brightens the
chip's existing 8px halo instead of adding the benchmark's event-only 10px glow
(`intent_chip.gd:51-55` (`GLOW_OUT_DEFAULT`), `intent_chip.gd:170-176` (in `telegraph`)).

### 3.6 Targeting — **FIX**

Benchmark has **two** states: `targetGlow`, a 1s `ease-in-out infinite` pulse from
6px to 18px red on every targetable foe; and `.target-hover`, which *kills* the
pulse and goes to a solid 22px glow with `brightness(1.25)`
(`src/ui/combat.js:1199-1257`, `src/styles.css:1237-1251`).

Here: `set_targetable` has one binary, instant state
(`enemy_view.gd:4068-4076` (`set_targetable`)). All-target cards light every living foe, but an
armed single-target card lights only the hovered foe (or the sole survivor), not
every legal target (`combat_screen.gd:2781-2784`). There is no 1s 6→18px legal
target pulse and no separate 22px / 1.25-bright hover state.

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
poison descends, crit blaze (`floaters.gd:43-45` (`FLOAT_EASE`), `floaters.gd:145-197` (`float_text`)). Driven
from `combat_screen._float` (`combat_screen.gd:1725-1730` (`_float`)). The benchmark's crit
branch has no caller, so its presence in both trees is not a visible parity gap.

### 4.2 Impact particles — **KEEP** (and honour the dead kinds)

Benchmark dispatches by damage archetype — slash, pierce, blunt, fire, poison,
void, ward — into arcs, sparks, rings, bursts, droplets and motes
(`src/vfx.js:51-149`, `src/vfx.js:362-431`).

**Measured:** `ring` and `slashArc` never reach the screen at `6e06911`. They push
particles with no `vx`/`vy`; the draw loop does `p.x += p.vx * dt` and coordinates
go NaN before paint. Pixel counts on the running page: burst/motes draw; ring and
slashArc draw 0 (`vfx_layer.gd:43-59` (in `DEAD_KINDS_RENDER`)).

Here: `VfxLayer.archetype_hit` and the drain call sites are built
(`vfx_layer.gd:591` (`archetype_hit`), `combat_screen.gd:2098` (`_hit_enemy`)). `DEAD_KINDS_RENDER = false` drops
`ring` / `slash` at `_push` so the typed `Vector2.ZERO` default does not
accidentally repair them into visible hoops (`vfx_layer.gd:71-73` (`DEAD_KINDS_RENDER`),
`vfx_layer.gd:405-410` (`_push`)). Call sites stay as the record of what the source asks
for; turning the flag on would render intent the benchmark has never shown.

### 4.3 Screen shake, hit-stop, flash — **KEEP**

Benchmark: shake at initial power 4–22 decaying `power × 0.001^dt`, applied to
**all** battlefield actors through one `#shake` wrapper; hit-stop 70ms on a big
hit, 90/130ms on a kill, 90ms on a facet shatter, 110ms on a boss death — during
which the particle loop freezes; colour flashes at .09/.24/.28/.3s
(`src/vfx.js:52-57`, `src/vfx.js:127-149`, `src/ui/drain.js:291-306`).

Here: shake moves `_shake_host` wrapping stage, battlefield and HUD
(`combat_screen.gd:415` (`_shake_host`), `vfx_layer.gd:433-434` (`shake`), `vfx_layer.gd:344-357` (in `_step_shake`)).
`hitstop` freezes the particle sim (`vfx_layer.gd:437-438` (`hitstop`),
`vfx_layer.gd:245-248` (in `_process`)) and is wired for big hits, kills, shatter and world-stop
(`combat_screen.gd:1852` (in `_handle_event`), `2172`, `2176`, `2266`). Flashes go through
`VfxLayer.flash`. Per-actor SubViewport camera shake is no longer the battlefield
shake.

### 4.4 Ember flight — **KEEP**

Benchmark: `flyTo`, motes staggered `i×46ms`,
`cubic-bezier(.32,.05,.35,1)`, scale `.5→1.05→.55`, lofted waypoint. Ember gain
and `smolderJump` both use 460ms; the separate `hollowTithe` uses 520ms
(`src/ui/combat.js:1420-1478`, `src/ui/drain.js:351-380`,
`src/ui/drain.js:429-433`).

Here: `VfxLayer.fly_to` with the same ease and 46ms stagger (`vfx_layer.gd:541-585`).
Ember gain and smolder jump both pass 0.46s (`combat_screen.gd:1854-1866`,
`combat_screen.gd:2034-2040`).

---

## 5. Structural, not animation

### 5.1 The hero is an actor here — **FIX** aspect selection and actor box

Benchmark: the hero is a raster-painted battlefield combatant created by
`heroArt(S.run.aspect)`, resolving `duskblade` / `ashwarden`, carrying the same cast
shadow, idle deformation, ward shell and hit recoil as a foe. It explicitly
**cannot** crack or shatter (`src/ui/combat.js:215-237`, `src/ui/assets.js:43-48`,
`src/ui/combat.js:1820-1903`).

Here: the hero is an `EnemyView` with `tier: hero` (`combat_screen.gd:1024-1033`).
Same idle, shadow, ward gem and recoil. `mark_dead` and `shatter` refuse a hero,
and player damage never calls `crack` (`enemy_view.gd:3076-3085`,
`enemy_view.gd:3497-3528` (`mark_dead`), `combat_screen.gd:2193-2195`). Chrome matches the
benchmark DOM: no intent, no facet row, no name line on the hero plate
(`enemy_view.gd:3911-3929` (in `_build_chrome`), `enemy_view.gd:4082` (in `_build_chrome`)). `hud_bar.gd` still
carries run chrome (energy, lantern, piles); the hero plate owns HP and ward on
the body.

The remaining structural differences are visible: the benchmark selects
`duskblade` or `ashwarden` from `S.run.aspect` and lays the hero out at 190×285px
in pad landscape (`src/ui/assets.js:43-48`,
`src/battlefield-layout.js:30-32`, `src/battlefield-layout.js:139-142`).
Godot hard-codes `duskblade` and gives every painted actor a square 285×285px box
(`combat_screen.gd:38-39` (`HERO_ART`), `enemy_view.gd:1544-1556`).

### 5.2 `footX` / `footY` — **KEEP** the offsets; stage data differ

Settled against the source, and the answer inverts the first reading.

**The port is faithful.** In the benchmark, positive `footY` moves an actor up and
negative moves it down (`src/battlefield-layout.js:8`, `src/ui/combat.js:397`), so
`duskblade`'s `footY: -30` sinks it ~30px below the ground line *there too*. Our
sign convention reproduces the benchmark.

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
| `duskfang.png` | 1024×1024 | 62px | ~20px of current 327; ~11px of benchmark 176 | 0 |
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
(`combat_screen.gd:731-750`, `combat_screen.gd:766+`). Placement can be judged
against painted ground again. See appendix for layer visibility and drift.

The offset mechanism is live: metadata `footX` / `footY` are read and `_stand`
applies both against the battlefield ground edge (`enemy_view.gd:1544-1556`,
`combat_screen.gd:1175-1196`). It is not full stage-data parity. Godot currently
freezes act-1 art and `GROUND_Y = 232`, while the benchmark uses 220 in act 2;
current `duskfang.scale` is 1.77 versus the benchmark's .95
(`combat_screen.gd:14-27`, `assets/art/enemies/char-meta.json:72-78`,
`src/char-meta.js:35-36`). Those are separate stage/content departures, not a
reason to derive the authored foot offsets.

### 5.3 Shadow metadata in `char-meta.json` — **PARTLY READ** (`dy` is not derivable)

The benchmark reads nine per-character knobs and transforms a darkened copy of
the painted silhouette; only its missing-art fallback is a blob
(`src/char-meta.js:8`, `src/char-meta.js:94-99`,
`src/ui/combat.js:1795-1818`, `src/styles.css:769-778`).

Godot derives eight of the nine from the painting alpha, the ground plane and the
key light (`enemy_view.gd:2029` (`_read_contact`),
`enemy_view.gd:2211` (`_update_shadow`)). **The ninth, `dy`, is now read** (2026-07-27,
`enemy_view.gd:2635` (`_read_hover`)) — this entry previously called the whole
block vestigial and that was wrong about one knob.

Contact point, lean, length and softening are all in the image or in the light.
Resting height is in neither: `dy` says *this painting is of something already off
the ground*, which no scan can recover, and exactly five creatures carry it —
`watcherEye` 24, `shade` 16, `voltEel` 13, `sporeling` 10, `voidWisp` 9, which are
exactly the floaters. It is read as a height and fed through the same projection
the live hover uses, so it buys an offset, smaller, fainter, softer shadow rather
than the straight-down shove CSS could manage. `dx` stays unread — it is a lateral
nudge the projection now supplies.

The remaining eight are still reference data, and the solution record has been
corrected accordingly.

### 5.4 Every actor renders a live 3D stage — **MEASURED** at 1×; live scale not yet measured

`_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS`, one stage per
actor. `oversample = 2.0` and MSAA 4× remain the chosen baseline, but the stage
now multiplies that size by the live canvas scale, rounds to 64px and caps at
2048² on window-size changes (`enemy_view.gd:1577-1641`). Measured by the organiser in
`docs/actor-stage-frame-budget.md` (tool: `tools/bench_actor_stage.gd`):

- **1× canvas baseline:** four actors at `oversample = 2.0`, MSAA 4× occupy
  2.3 Mpx / **248.4 MB** in the desktop measurement
  (`actor-stage-frame-budget.md:134-140`). The former 3.6 Mpx / 310 MB and
  inferred 0.9ms / roughly 38 actors belong to the old 2.5× profile, not the
  chosen baseline (`actor-stage-frame-budget.md:34-44`,
  `actor-stage-frame-budget.md:82-94`). Neither wall time nor memory has been
  remeasured for the new live-scale path, so 248.4 MB is no longer a general
  current-window figure.
- **Memory still has no budget to pass against.**
  `commercial-game-delivery.md` §5 still reads "≤X MB"; setting it remains a
  gate decision.

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

Retained because these source measurements settle §5.2 and explain the stage
now built in `combat_screen.gd`. They are reference facts, not a second queue.

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
232. Current combat hard-codes act-1 plates and `GROUND_Y = 232`
(`combat_screen.gd:14-27`), so act-2 placement is not yet represented.

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

1. **Memory budget (§5.4)** — the 1× 2.0× / MSAA 4× baseline is measured; the
   live-scale path is not, and the commercial gate still has no limit to pass or
   fail.
2. **Hurt-flash strength (§1.5)** — the shader translation is source-audited;
   whether it visually matches the composited CSS flash still requires an
   in-motion lab judgement.

Everything headed **FIX** above is a source-proven implementation difference,
not an unresolved design choice. `footY`, the cut-gem ward design and the
reference-dead ring/slash particles are settled.
