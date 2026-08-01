# Music ledger — stained-glass-v1

Port-scoped inventory of the music pack Glassvow ships. The full generation
ledger (prompts, motif law, render pipeline) lives in the reference repo at
`docs/music-ledger.md`.

## What

The immutable **stained-glass-v1** pack: 22 looped tracks at
`assets/audio/music/`. Direction: classical gothic stained-glass chamber
music — dark panes, cold stone, a lantern kept lit.

## Provenance

Composed with **Suno** (Suno Pro workspace, July 2026). Track selection,
loop renders and loudness normalisation happened upstream in the reference
repo; this port carries the v1 renders verbatim. Do not re-encode or
re-title the shipping files without a pack bump.

## Contract

- Cue ids resolve through `MusicBus.FILES` in
  `presentation/audio/music_bus.gd`.
- `assets/audio/music/manifest.json` is the track-title source the credits
  screen reads.
- Titles render in manifest order (dramatic order, not alphabetical).

## Pointer

For prompts, motif law and the render pipeline, see the reference repo's
`docs/music-ledger.md`. This file is the port-facing contract only.
