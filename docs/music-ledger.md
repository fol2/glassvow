# Music ledger — stained-glass-v1

Port-scoped inventory of the music pack Glassvow ships. The full generation
ledger (prompts, motif law, render pipeline) lives at
`../roguecardv2-benchmark/docs/music-ledger.md` (roguecardv2@6e06911).

## What

The immutable **stained-glass-v1** pack: 22 looped tracks at
`assets/audio/music/`. Direction: classical gothic stained-glass chamber
music — dark panes, cold stone, a lantern kept lit.

## Provenance

Composed with **Suno** (Suno Pro workspace, July 2026); track selection
happened upstream in the reference repo. This port carries the **v1**
renders verbatim, as first rendered — variable bit rate, untrimmed run
lengths (`title.mp3` runs 159 s). The reference's later v2 master pass
(flat-rate re-encode, tighter loop cuts) is not what ships here. Do not
re-encode or re-title the shipping files without a pack bump.

## Contract

- Cue ids resolve through `MusicBus.FILES` in
  `presentation/audio/music_bus.gd`.
- `assets/audio/music/manifest.json` is the track-title source the credits
  screen reads.
- Titles render in manifest order (dramatic order, not alphabetical).

## Pointer

For prompts, motif law and the render pipeline, see
`../roguecardv2-benchmark/docs/music-ledger.md` (roguecardv2@6e06911).
This file is the port-facing contract only.
