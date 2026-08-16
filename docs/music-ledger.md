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
- **A `title` is display copy, not provenance.** The renders, the file names
  and the cue ids are frozen at v1 and a change to any of them needs a pack
  bump; a `title` string is rendered verbatim into the credits by
  `presentation/run/credits_screen.gd`, so it is player-facing copy and answers
  to the story bible like every other line. Retitling does **not** bump the
  pack — the audio has not changed and claiming it has would be false — but it
  does have to be recorded below.

## Title changes since v1

| cue | v1 title | now | authority |
|---|---|---|---|
| `map` | Lanterns on the Face of the Spire | **Lanterns Along the Road** | [#232](https://github.com/fol2/glassvow/issues/232) Tier A ban, landed by [#303](https://github.com/fol2/glassvow/issues/303) |
| `sealedDoor` | The Climb Continues | **The Pilgrimage Continues** | foreshadow-ledger row 82 — 「朝聖仍在繼續。」/ "The pilgrimage continues." is one sentence at three sites (whisper 24, `ui.map.sealedDoor.inscription`, this title); signed in story batch 1 ([#301](https://github.com/fol2/glassvow/issues/301)), landed by [#303](https://github.com/fol2/glassvow/issues/303) |

Both audio files are byte-identical to v1. `pack_id` stays `stained-glass-v1`.

## Pointer

For prompts, motif law and the render pipeline, see
`../roguecardv2-benchmark/docs/music-ledger.md` (roguecardv2@6e06911).
This file is the port-facing contract only.
