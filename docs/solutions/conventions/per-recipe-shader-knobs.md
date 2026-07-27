---
title: Tune one card-surface recipe with a per-recipe uniform, never the shared model
date: 2026-07-26
category: conventions
module: presentation/combat/card_surface
problem_type: convention
component: development_workflow
severity: high
applies_when:
  - A request names ONE recipe or rarity tier but the code that produces the effect is shared by several
  - Adding a constant, term, or branch inside a shader helper that more than one FINISH entry calls
  - Verifying that a visual change left the other recipes alone
tags: [godot, shader, card-surface, visual-regression, uniforms, rmse, verification]
---

# Tune one card-surface recipe with a per-recipe uniform, never the shared model

## Context

`presentation/combat/card_surface.gd` is a four-layer catalogue — `MATERIAL`,
`TEXTURE`, `FINISH`, `STOCK` — and a `RECIPES` table that names one entry from
each. `BY_RARITY` then points each rarity at a recipe. The shipping tiers are a
handful of names; the catalogue behind them is much wider.

The trap is that a request always arrives named after a *recipe* ("make nebula's
cosmos deeper"), while the code that produces the effect lives in a *shared
helper*. `confetti()` in `card_surface.gdshader:220` is called by every finish
with `sparkle > 0` — five of the fourteen `FINISH` entries: `metallic`,
`pearlescent`, `prismatic`, `cosmos`, `cosmos-art`.

On 2026-07-25 five commits were reverted for walking into exactly that. Depth,
murk, glow, herding, a size-tearing term, and a room-vs-lamp radiance ratio were
all added as constants *inside* `confetti()`. They were meant for one recipe.
They reached all five — including `pearlescent`, which at that moment was the
finish in `opal` (`["glass", "linen", "pearlescent", "premium"]`), the shipping
**uncommon** tier.

`opal` has since been re-stacked to `["glass", "tooth", "gloss", "premium"]`
(commit `fbb8d5e`), so that exact blast path is now closed — `gloss` carries
`sparkle: 0.0` and never enters `confetti()`. Do not read that as the hazard
having passed. It is the same hazard restated: **which tiers a shared helper
reaches is a property of the `RECIPES` table on the day you edit it, not of the
helper.** The table moved without `confetti()` changing at all, and it will move
again. Re-check the reach before every shared-model edit; a blast radius
memorised from last week is not evidence.

The collateral was measured at 0.32%, then 1.3% RMSE, and reported as an
acceptable trade-off — twice. That framing was itself the error. The user's
words: *"i can see your settings are affecting all other cards already."*
Magnitude was never the question; scope was.

## Guidance

**A want that belongs to one recipe belongs in a `FINISH` key plus a shader
`uniform` whose default is algebraically the identity.**

Four rules, all load-bearing:

1. **The default must be the identity by algebra, not by smallness.** Write the
   term so that at the default value the expression *is* the old expression, not
   a close neighbour of it:

   ```glsl
   // depth 0.0 -> `par * (dep * 0.0)` is exactly `- 0.0`, the flat sheet
   float shape = smoothstep(edge, soft, length(cell - ci
       - hash22(ci) - par * (dep * deep)));
   ```

   `0.001` as a "harmless" default is not the identity. It is a regression you
   have decided not to look at.

2. **Add the key to every `FINISH` entry, not just the ones you are changing.**
   `params()` (`card_surface.gd:422` (`params`)) asserts the four layers own disjoint keys,
   and `apply()` reads `p[key]` with a strict index — a missing key is a hard
   crash at load, not a silent default. Both are guardrails; feed them.

3. **Set a non-zero value only on the recipes named in the request.** In
   `card_surface.gd` today, `flake_deep`/`flake_wake` are non-zero on exactly
   two entries — `cosmos` and `cosmos-art`. The other twelve read `0.0, 0.0`.
   That column is reviewable at a glance, which is the point.

4. **Prove the untouched recipes did not move.** Render each before and after
   and show **RMSE = 0**, not "small". See the floor below for what 0 actually
   means.

## Why This Matters

Shared-model edits fail in a way that is invisible at review time and loud in
the game. The diff looks small and local — a couple of constants inside one
function — and nothing in it names the recipes it will move. The blast radius is
only discoverable by knowing which `FINISH` entries reach that code path, which
is precisely the knowledge a reviewer does not have in their head.

Reporting the collateral as a percentage makes it worse, not better, because it
invites a judgement call about *how much* drift is tolerable on a tier nobody
asked to change. There is no correct answer to that question. The correct answer
is that the tier should not appear in the diff at all.

### The 1/255 floor — what "RMSE 0" can and cannot mean

**Adding a uniform to a shader moves every recipe by up to 1/255, including
recipes whose code path never executes.** This is not collateral; it is the
noise floor of editing the shader at all, and you have to know it or you will
chase a phantom.

The mechanism: a new uniform changes the shader program, so the driver's
optimizer reschedules the *rest* of it — float reassociation, FMA contraction.
One-ULP differences land as ±1 after 8-bit quantization.

It was established as a floor rather than assumed, in two steps:

- **The renderer itself is deterministic.** Three identical runs of the same
  build diffed at RMSE exactly 0. So the 1/255 is not sampling noise.
- **A control recipe that never enters the changed code showed the same
  1/255.** `holofoil` is `["silver-leaf", "cross-etch", "holo", "gilded"]`, and
  the `holo` finish has `sparkle: 0.0`, so the `if (sparkle > 0.0)` block at
  `card_surface.gdshader:360` (in `fragment`) never runs for it. It moved by 1/255 anyway.

So the acceptance bar is: **maxdiff ≤ 1/255 on untouched recipes.** Anything
above that is a real change and needs explaining. Anything at or below it is the
compiler, and chasing it is wasted time.

## When to Apply

- Any request that names a single recipe, finish, or rarity tier.
- Before adding a constant or term inside `confetti()` or any other helper in
  `card_surface.gdshader` reached by more than one `FINISH` entry.
- When a visual change is being signed off — the untouched-recipe proof is part
  of the change, not a follow-up.

## Examples

### Wrong — a constant inside the shared helper

```glsl
const float FLAKE_DEEP = 1.8;   // <- reaches all five sparkle finishes

vec3 confetti(vec2 p, float pitch, ...) {
    ...
    float dep = hash12(ci + 3.1);
    float shape = smoothstep(edge, soft, length(cell - ci
        - hash22(ci) - par * (dep * FLAKE_DEEP)));
```

Nothing in this diff mentions `opal`, and `opal` moves.

### Right — a uniform, defaulted to the identity, set per recipe

```glsl
uniform float flake_deep = 0.0;   // card_surface.gdshader:125 (`flake_deep`)

vec3 confetti(vec2 p, float pitch, float edge, float soft, float lobe,
        float tip, vec3 N, vec3 T, vec3 Bv, vec3 H, float g,
        vec2 par, float deep) {           // <- passed in, not baked in
```

```gdscript
# card_surface.gd — every FINISH entry carries the key
"gloss":      { ..., "flake_deep": 0.0, "flake_wake": 0.0, "mask": 0, },
"pearlescent":{ ..., "flake_deep": 0.0, "flake_wake": 0.0, "mask": 0, },
"cosmos":     { ..., "flake_deep": 3.0, "flake_wake": 1.0, "mask": 0, },
"cosmos-art": { ..., "flake_deep": 3.0, "flake_wake": 1.0, "mask": 2, },
```

```gdscript
# card_surface.gd — apply()'s key list is strict; a missing key crashes at load
for key: String in ["ink", "ink_tint", ..., "sparkle", "flake_px",
        "flake_big", "flake_hue", "flake_deep", "flake_wake", "mask"]:
    mat.set_shader_parameter(key, p[key])
```

### Proving the others did not move

`card_view.gd:941` exposes three environment hooks for held-pose renders:
`GLASSVOW_TILT="nx,ny"` holds a pose, `GLASSVOW_LAMP="x,y[,gain]"` stands the
lamp somewhere fixed, and `GLASSVOW_DUMP=<prefix>` writes
`<prefix>_inner_<uid>.png` and `<prefix>_stage_<uid>.png`.

```bash
GLASSVOW_TILT="0,0" GLASSVOW_LAMP="-0.35,-0.35,1" GLASSVOW_DUMP=after \
  tools/shot.sh --cards --shot=/tmp/cards.png
```

Two details in that line are load-bearing. `tools/shot.sh` is the repo's capture
entry point, and the env prefix survives it because the wrapper `exec`s godot in
the same environment (`tools/shot.sh:51`); run it from the repo root, since
`GLASSVOW_DUMP` writes relative filenames. The `--shot=` is what makes the run
quit — `--cards` alone leaves the lab open, and a scripted run that forgets it
leaves a process behind to be killed by hand.

Do not expect the wrapper to keep the window out of sight. It requests
`--position -4000,-4000` and macOS clamps that back on screen, so each of the
two runs takes the desktop for about a second. Here that is unavoidable rather
than merely tolerated, because the recipe genuinely needs two processes (below).

Do **not** reach for `tools/live.sh` here. The hooks are read once from the
process environment (`card_view.gd:946-963`), so a single host cannot change its
dump prefix between the before and after builds — this recipe genuinely needs
two processes. See
[Capture through a long-lived host](../tooling-decisions/long-lived-capture-host-not-process-per-shot.md)
for when a host does apply.

Render the same recipe from both builds under an identical pose and lamp, then
diff numerically — never by eye:

```bash
magick compare -metric RMSE before_inner_opal.png after_inner_opal.png null:
```

Do not pass `--headless` together with `--shot=` — that combination hangs.

## Related

- `presentation/combat/card_surface.gd` — the four-layer catalogue, `RECIPES`,
  `BY_RARITY`, `params()`, `apply()`
- `presentation/combat/card_surface.gdshader` — `confetti()` and the finish
  uniform block
- Commit `6373297` — the revert that ended the shared-model attempt
- Commit `006aaea` — the same feature re-landed as `flake_deep` / `flake_wake`
- [Godot Label placement guessed at font height](../ui-bugs/godot-label-placement-guessed-font-height.md)
  — the same discipline in a different corner of the presentation layer: a
  plausible visual hypothesis that measurement refuted
