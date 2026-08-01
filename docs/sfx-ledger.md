# SFX ledger — ashglass-v1

Port-scoped inventory of the sound pack Glassvow ships. The full generation
ledger (prompt set, category law, render pipeline) lives in the reference
repo at `docs/sfx-ledger.md`.

## What

The immutable **ashglass-v1** pack: 36 one-shot sounds at
`assets/audio/sfx/`. Theme: Ashglass Vigil — glass, ash, lantern, and the
small metallic ticks of a climb.

## Provenance

Synthesised with **ElevenLabs** (official sound-generation API) upstream in
the reference repo. Selection, trimming and loudness normalisation happened
there; this port carries the v1 one-shots verbatim. Do not re-encode or
rename shipping files without a pack bump.

## Contract

- Cue ids resolve through `SfxBus` in `presentation/audio/sfx_bus.gd`.
- `assets/audio/sfx/manifest.json` is the inventory the credits screen
  reads for the sound count and theme line.
- Playback is one-shot; looping and music beds belong to `MusicBus`.

## Pointer

For the generation bible and category law, see the reference repo's
`docs/sfx-ledger.md`. This file is the port-facing contract only.
