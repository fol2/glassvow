# SFX ledger — ashglass-v1

Port-scoped inventory of the sound pack Glassvow ships. The full generation
ledger (prompt set, category law, render pipeline) lives at
`../roguecardv2-benchmark/docs/sfx-ledger.md` (roguecardv2@6e06911).

## What

The immutable **ashglass-v1** pack: 36 one-shot sounds at
`assets/audio/sfx/`. Theme: Ashglass Vigil — glass, ash, lantern, and the
small metallic ticks of a climb.

## Provenance

Synthesised with **ElevenLabs** (official sound-generation API) upstream in
the reference repo, where the pack was selected. This port carries the
**v1** one-shots verbatim, untrimmed as the API rendered them (`chip.mp3`
runs 0.52 s — the API's minimum). The reference's later v2 pass (tail
trims) is not what ships here. Do not re-encode or rename shipping files
without a pack bump.

## Contract

- Cue ids resolve through `SfxBus` in `presentation/audio/sfx_bus.gd`.
- `assets/audio/sfx/manifest.json` is the inventory the credits screen
  reads for the sound count and theme line.
- Playback is one-shot; looping and music beds belong to `MusicBus`.

## Pointer

For the generation bible and category law, see
`../roguecardv2-benchmark/docs/sfx-ledger.md` (roguecardv2@6e06911).
This file is the port-facing contract only.
