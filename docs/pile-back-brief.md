# Pile back — brief for the card line

Written 2026-07-26 by the combat-HUD line, for whoever picks up the card line.
The decision behind it is recorded in `docs/visual-direction.md`.

## The ask

The three piles in the combat HUD should wear a **real card back built through
the card surface system** rather than three flat authored paintings. They are
all the same play cards, and this project has a material system the web build
never had.

## The finding that changes the ask

**There is no card back anywhere.** Not in this repo, not in the frozen
benchmark. `assets/art/piles/{draw,discard,ashes}.png` — 512×512 each, imported
in `0162b6d` — are the only backs that exist, and they are flat paintings. The
benchmark loads them with `assetUrl('piles', pileMasterId(pile))` and does
nothing further to them.

The card system renders **faces**: `CardSurface.stack_of()` folds a Recipe of
four layers and `CardView` runs it through an offscreen stage.

So this is not *use the existing back*. It is **author a back through the Recipe
system, with those three paintings as the artwork baseline**.

## What the HUD needs back

**One `Texture2D` per pile, obtained once and cached.** That is the whole
interface, and it is not negotiable in the way the rest of this brief is.

`hud_bar.gd`'s `Fan` draws every visible face of a pile in a single `_draw()` —
up to 16 faces, three piles, 48 draws of one texture. Collapsing that was
deliberate and is written up in
`docs/solutions/design-patterns/dom-node-per-layer-in-godot.md` (48 Control
nodes → 3). **A Node per face, or a live `ShaderMaterial` per face, puts all 48
back and undoes that work.**

So the back has to be baked. `CardView` already owns the whole pipeline —
`_inner` `SubViewport` (the 2D face) → `_stage` `SubViewport` (glass prism,
lamp, long lens) → a texture. A back is that same stage with back artwork in
the inner viewport. For a bake rather than a live card:

- `render_target_update_mode = UPDATE_ONCE` instead of `UPDATE_ALWAYS`
- await one frame, then `get_texture().get_image()` into an `ImageTexture`
- free the viewports; nothing should stay resident per pile

A shape that would suit the HUD, named however the card line prefers:

```gdscript
static func pile_back(which: StringName) -> Texture2D   # &"draw" | &"discard" | &"ashes"
```

Two conditions on it:

- **No game dependency.** It must be callable with a pile id and nothing else.
  `HudBar.set_values()` takes plain ints and no run, combat or content, and that
  stays true.
- **No await inside my `_init`.** If the bake needs a frame, give me a pre-warm
  entry point to call before the HUD is constructed, or a signal to connect —
  not a coroutine in the constructor.

## Geometry — agree it, don't assume it

Each face is currently drawn as a **square**: side = the pile box width = 96px,
inside a 96×148 box, turned about a pivot at (50%, 92%) of the square. That
square exists because the art is 512×512.

A real card slab is not square. If the baked back comes back at card aspect, my
fan's pivot and box both change. That is a fine change to make — but it is mine
to make, so **state the aspect before baking**, not after.

The fan's own rules are not in scope here and stay as they are: one visible face
per card capped at 16, 5° between faces, the whole span averaged down once it
would pass 30° (the benchmark's `pile-chrome.js`).

## What must survive

- **The three piles stay tellable apart at 96px** — draw is the blue vault,
  discard the warm parchment, ashes the charred one. Whatever the Recipe adds,
  that read is the point of having three.
- **`.pile-exhaust { opacity: 0.9 }`** — the ash pile sits a shade back. HudBar
  applies that itself; do not bake it into the texture.
- An empty pile hides its faces and keeps its count and its name. HudBar's
  business, listed so it is not re-solved on the other side.

## Ownership and gate

- The card line owns `card_surface.gd`, `card_view.gd`, the shaders,
  `card_lab.gd`, `card_studio.gd`.
- The HUD line owns `presentation/combat/hud_bar.gd` and
  `presentation/lab/hud_lab.gd`. The texture gets wired in there by the HUD
  line — please do not edit those two files.
- **Shared tree, five concurrent sessions: commit with explicit paths only,
  never `git add -A`.**
- Godot 4.7.2 stable or later stable; the per-file parse gate is warnings-as-errors. A lab file
  that fails to parse takes down *every* lab entry point, not only its own —
  `enemy_lab.gd` did this to all five sessions once.
- Judge it at real size: `godot --path . -- --hud` and press `6`. That state
  poses 99 cards in every pile, which is the only one that exercises both fan
  caps at once.

## Open question, worth settling before building

Should a pile's Recipe be **fixed per pile**, or should the top face carry the
Recipe of the card actually sitting on top?

The second is more honest and costs a bake per card id — 61 cards. The first is
three bakes, forever. The benchmark answers neither, because it could not ask
the question. Flag the choice before building the expensive one.

Unused but available if it helps: the benchmark's `pileTier(count)` grades a
pile 0–5 by depth, and the DOM carries it as `data-tier`. Nothing in this port
reads it yet.
