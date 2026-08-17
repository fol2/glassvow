# SFX ledger — ashglass-v1

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
`assets/audio/sfx/`. Theme: Ashglass Vigil — glass, ash, lantern, and the
small metallic ticks of a climb. An additive unsealing sting is owed as
`ashglass-v1-unsealing`; v1 bytes stay untouched.

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

## Owed — unsealing sting (#377 leftover from #221)

No sample yet. James on #263 Q10 / the #221 comment: **one more cue is
owed**. `sealedDoor` plays on every threshold-overlay open
(`application/main.gd` switches music when the ceremony opens), so it
cannot satisfy the rubric's heard-nowhere-else requirement. It stays the
door/ceremony theme.

The **engine hook is in**: `ScenePlayer` fires `unsealingSting` once on
unsealing beat 2 (窗成鏡). `SfxBus` warns if the file is missing rather
than substituting `sealedDoor`. Dispatch via
`.claude/skills/glassvow-elevenlabs/SKILL.md` (official sound-generation
API as v1). A new file is a pack bump (`ashglass-v1-unsealing`); do not
re-encode v1. Wire the sample into `assets/audio/sfx/manifest.json` in
the same commit as the mp3.

| cue | file | brief |
|---|---|---|
| `unsealingSting` | `unsealingSting.mp3` | One-shot, ~1.2–1.8 s. File stem is the cue id (`SfxBus` loads `DIR % id`). Lands on unsealing beat 2 「窗成鏡」 (`docs/story/07-scenes.md` §6, Batch 4). The six panes become a mirror: a short glass-chord inversion, warm amber bloom turning cold as the reflection takes, no choir, no vocals, no door grind (that grind is a separate low push on beat 4). Must be unique in the pack — if it could pass for `sealedDoor`, `roseWindow`, or `chip`, it is wrong. |

Wire through `SfxBus` and `assets/audio/sfx/manifest.json` in the same
commit as the mp3. Do not steal a music-bus slot; this is a sting over
the ceremony bed.

## Pointer

For the generation bible and category law, see
`../roguecardv2-benchmark/docs/sfx-ledger.md` (roguecardv2@6e06911).
This file is the port-facing contract only.
