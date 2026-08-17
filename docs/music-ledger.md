# Music ledger — stained-glass-v1-act4

Port-scoped inventory of the music pack Glassvow ships. The full generation
ledger (prompts, motif law, render pipeline) lives at
`../roguecardv2-benchmark/docs/music-ledger.md` (roguecardv2@6e06911).

Dispatch for new tracks: `.claude/skills/glassvow-suno/SKILL.md`.
**Suno has no public API key.** v1 was the Suno Pro website; Act IV is
the same — Custom + Instrumental, paste the owed brief, download mp3s.
AceDataCloud is an optional third-party wrapper with its *own* token
(`ACEDATACLOUD_API_TOKEN`), not a Suno secret. Cookie scrapers stay out.

## What

The immutable **stained-glass-v1** pack: 22 looped tracks, plus the
**stained-glass-v1-act4** addendum: 2 Act IV loops. Files live at
`assets/audio/music/`. Direction: classical gothic stained-glass chamber
music — dark panes, cold stone, a lantern kept lit. `pack_id` is
`stained-glass-v1-act4`. v1 bytes are untouched.

## Provenance

Composed with **Suno** (Suno Pro workspace, July 2026); track selection
happened upstream in the reference repo. This port carries the **v1**
renders verbatim, as first rendered — variable bit rate, untrimmed run
lengths (`title.mp3` runs 159 s). The reference's later v2 master pass
(flat-rate re-encode, tighter loop cuts) is not what ships here. Do not
re-encode or re-title the shipping files without a pack bump.

Act IV tracks were composed in the same Pro workspace (`fol2hk`) on
2026-08-17 — Custom + Instrumental, untrimmed as Suno delivered them.

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

Both audio files are byte-identical to v1. Those two cues stay on the v1
renders; the pack_id bump is the Act IV addendum, not a retitle.

## Shipped — Act IV (#221)

James picked 2026-08-17. Shipping copies sit at `assets/audio/music/`;
every candidate stays in
`docs/design/2026-08-17-act4-audio/candidates/`. `MusicBus.FILES` maps
`act4Combat` → `act4-combat` and `act4Boss` → `act4-boss`. Credits titles
are display copy.

Direction inherited from v1: classical gothic stained-glass chamber
music — dark panes, cold stone, a lantern kept lit. Act IV overlay from
`docs/story/03-acts.md` and `07-scenes.md` §6: **inverted hearth-light**
— warmth arrives from ahead, the near field is colder; cinders rise.

| cue | file | pick | Suno id | duration | title |
|---|---|---|---|---|---|
| `act4Combat` | `act4-combat.mp3` | **C** (`act4-combat-c.mp3`) | `ef55956e-5c4d-4848-9457-690663c41fc1` | 103 s | **Hearthlight Runs Back** |
| `act4Boss` | `act4-boss.mp3` | **A** (`act4-boss-a.mp3`) | `5c3b0b31-aa55-4721-b28d-c4d003cba803` | 99 s | **The Seat That Would Not Leave** |

Prompt that rendered (Custom style field, Instrumental on):

- `act4Combat`: Loop. The Mirrored Road, not a new biome: the Act I–III chamber palette heard *backwards* — phrases inverted, cadence arriving before the step. Low strings and glass harmonics; a far amber pedal that brightens as the phrase repeats. No choir, no vocals, no climb, no brass fanfare.
- `act4Boss`: Loop. The Eternal Keeper's fight: the hearth theme at original speed (node 5 is "home"), but the harmony sits one degree colder than `vigil` / the opening hearth. Stillness is the threat — long held tones, a slow cracked-glass ostinato, no chase. No choir, no vocals, no sovereign-court brass.

Held candidates (kept in the repo, not wired): combat **A** 104 s (`a7613abf-f0f6-47a5-9e7b-830bb421b3c2`), **B** 153 s (`83a2af85-b971-4771-b644-18ac345a2e42`), **D** 98 s (`e5e1d8fa-509d-4900-b64d-6916edcf77df`); boss **B** 153 s (`6ed76c50-5e2b-4034-9cbd-ae27ff7c9f89`).

## Pointer

For prompts, motif law and the render pipeline, see
`../roguecardv2-benchmark/docs/music-ledger.md` (roguecardv2@6e06911).
This file is the port-facing contract only.
