# Music ledger — stained-glass-v1

Port-scoped inventory of the music pack Glassvow ships. The full generation
ledger (prompts, motif law, render pipeline) lives at
`../roguecardv2-benchmark/docs/music-ledger.md` (roguecardv2@6e06911).

Dispatch for new tracks: `.claude/skills/glassvow-suno/SKILL.md`.
**Suno has no public API key.** v1 was the Suno Pro website; Act IV is
the same — Custom + Instrumental, paste the owed brief, download mp3s.
AceDataCloud is an optional third-party wrapper with its *own* token
(`ACEDATACLOUD_API_TOKEN`), not a Suno secret. Cookie scrapers stay out.

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

## Owed — Act IV (#221)

No files yet. `MusicBus.FILES` still aliases `act4Combat` / `act4Boss` to
the Act III tracks; `tests/test_presentation.gd` asserts that alias until
these two land. Dispatch via `.claude/skills/glassvow-suno/SKILL.md`
(Suno Pro website, same as v1). A new file is a pack bump
(`stained-glass-v2` or a dated Act IV addendum) — do not re-encode v1
to make room.

Direction inherited from v1: classical gothic stained-glass chamber
music — dark panes, cold stone, a lantern kept lit. Act IV overlay from
`docs/story/03-acts.md` and `07-scenes.md` §6: **inverted hearth-light**
— warmth arrives from ahead, the near field is colder; cinders rise.

| cue | file | brief |
|---|---|---|
| `act4Combat` | `act4-combat.mp3` | Loop. The Mirrored Road, not a new biome: the Act I–III chamber palette heard *backwards* — phrases inverted, cadence arriving before the step. Low strings and glass harmonics; a far amber pedal that brightens as the phrase repeats. No choir, no vocals, no climb, no brass fanfare. Title (display copy, after James): **Hearthlight Runs Back**. |
| `act4Boss` | `act4-boss.mp3` | Loop. The Eternal Keeper's fight: the hearth theme at original speed (node 5 is "home"), but the harmony sits one degree colder than `vigil` / the opening hearth. Stillness is the threat — long held tones, a slow cracked-glass ostinato, no chase. No choir, no vocals, no sovereign-court brass. Title (display copy, after James): **The Seat That Would Not Leave**. |

Wire in `music_bus.gd` and `assets/audio/music/manifest.json` in the same
commit as the mp3s. Credits copy answers to the story bible like every
other `title`.

## Pointer

For prompts, motif law and the render pipeline, see
`../roguecardv2-benchmark/docs/music-ledger.md` (roguecardv2@6e06911).
This file is the port-facing contract only.
