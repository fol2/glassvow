# SFX ledger — ashglass-v1-unsealing

Port-scoped inventory of the sound pack Glassvow ships. The full generation
ledger (prompt set, category law, render pipeline) lives at
`../roguecardv2-benchmark/docs/sfx-ledger.md` (roguecardv2@6e06911).

Dispatch for new samples: `.claude/skills/glassvow-elevenlabs/SKILL.md`.
MCP config (IDE): `.cursor/mcp.json` → `elevenlabs`. Cloud Agents do not
read that file; register the same stdio server in the cursor.com/agents
MCP dropdown and put `ELEVENLABS_API_KEY` on the environment. The hosted
ElevenLabs MCP at `https://api.elevenlabs.io/v1/mcp` is Agents/TTS — not
this pack. REST fallback is `POST /v1/sound-generation`.

## What

The immutable **ashglass-v1** pack: 36 one-shot sounds at
`assets/audio/sfx/`, plus the **ashglass-v1-unsealing** addendum
(`unsealingSting`). Theme: Ashglass Vigil — glass, ash, lantern, and the
small metallic ticks of a climb. `pack_id` is `ashglass-v1-unsealing`.
v1 bytes stay untouched.

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

## Shipped — unsealing sting (#377 leftover from #221)

Picked 2026-08-17, candidate **B**. Shipping copy sits at
`assets/audio/sfx/unsealingSting.mp3`; every candidate stays in
`docs/design/2026-08-17-unsealingSting/candidates/`. File stem is the
cue id. `pack_id` bumped to `ashglass-v1-unsealing`; the 36 v1 files are
byte-identical. `ScenePlayer` fires the cue once on unsealing beat 2
(窗成鏡). `SfxBus` still warns if the file is missing rather than
substituting `sealedDoor`, which stays the door/ceremony theme.

| cue | file | pick | duration | usage |
|---|---|---|---|---|
| `unsealingSting` | `unsealingSting.mp3` | **B** (`unsealingSting-b.mp3`) | 1.515 s | Unsealing beat 2 「窗成鏡」 unique sting |

Prompt that rendered (`eleven_text_to_sound_v2`, `duration_seconds` 1.5,
`prompt_influence` 0.65):

> One-shot glass sting: the six panes become a mirror. A short glass-chord inversion, warm amber bloom turning cold as the reflection takes. No choir, no vocals, no door grind, no footsteps, no long cinematic tail. Must not sound like a sealed door theme, a rose-window bed, or a tiny glass chip tick.

Do not steal a music-bus slot; this is a sting over the ceremony bed.
Beat 4’s low door-push is a separate cue.

## Pointer

For the generation bible and category law, see
`../roguecardv2-benchmark/docs/sfx-ledger.md` (roguecardv2@6e06911).
This file is the port-facing contract only.
