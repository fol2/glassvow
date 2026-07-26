# Attic

Art that was made for a decision that went the other way, kept because the
decision might not be final.

`.gdignore` at this level takes the whole directory out of Godot's importer, so
nothing here has a `res://` path, an `.import` sidecar, or any way to reach the
parse gate. Restoring a file means moving it back under `assets/art/` and
running `godot --headless --import`, which regenerates its sidecar.

## hud-2026-07-26

Six images generated during the combat-HUD session, landed in `1fe27ca` and
never loaded by anything. Its commit message says "hud_bar.gd is the consumer
and does not exist" — that was true when the message was written and false by
the time it was committed; `hud_bar.gd` had shipped in `4bc58a5` some hours
earlier, wearing different art.

- `candle-full`, `candle-two`, `candle-one`, `candle-out` — one candle at four
  burn levels. This is a **different energy read** from the one that shipped:
  a single candle whose remaining height is the turn's budget, rather than the
  benchmark's row of candles each either lit or spent. The HUD uses
  `assets/art/ui/candle-{lit,spent}.png` and one candle per point of max energy.
- `phial-frame` — a hexagonal lantern vessel. Not interchangeable with
  `assets/art/ui/hp-vial-frame.png`, which is a wide 512x179 bezel stretched
  over the plate's rail; this one is a 512x512 upright object.
- `rail-stone` — a 1024x256 stone rail strip, with no rule in the benchmark's
  stylesheet that corresponds to it.

They were part of the HUD redesigns, and the redesigns were declined: *"None of
your work is better than original one… UI simplicity is important, UI is never
the main character."* Parked rather than deleted because the standing decision
is a preference, not a proof — see `docs/visual-direction.md`.
