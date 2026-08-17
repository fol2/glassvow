---
name: glassvow-elevenlabs
description: Generate Glassvow SFX with ElevenLabs sound-generation (MCP or official REST). Use when adding or replacing ashglass pack samples, unsealingSting, UI/combat one-shots, or wiring ElevenLabs MCP. Always read and update docs/sfx-ledger.md before shipping a file.
---

# Glassvow ElevenLabs SFX

Ledger is law: `docs/sfx-ledger.md`. Cue ids, filenames, prompts, durations, and pack bumps live there. This skill is the dispatch path, not a second brief.

SFX is **sound-generation**, never TTS. Do not use `https://api.elevenlabs.io/v1/mcp` (ElevenAgents / speech). Do not steal a music-bus slot.

## 1. Read the owed row

Open `docs/sfx-ledger.md`. Copy the cue, file stem, duration, and brief verbatim into the prompt. If the row is missing, write it first.

`SfxBus` loads `res://assets/audio/sfx/%s.mp3` with `%s` = the cue id. The file stem **is** the cue (`unsealingSting.mp3`, not kebab-case).

## 2. Generate

Prefer MCP when this session actually has ElevenLabs tools. Otherwise official REST. Stop if `ELEVENLABS_API_KEY` is unset.

Write candidates under `docs/design/<date>-<cue>/candidates/`, not straight into `assets/audio/sfx/`. Set `ELEVENLABS_MCP_BASE_PATH` to the workspace (`.cursor/mcp.json` already does). Default MCP output is `~/Desktop` and that path is wrong here.

v1 pack used `prompt_influence` around 0.5–0.75 and requested durations of 0.5–1.4 s. Match the ledger row. `loop` stays false — playback is one-shot.

### MCP

Official stdio server: `uvx elevenlabs-mcp` (see `.cursor/mcp.json`). Call the sound-generation tool with the ledger prompt, duration, and influence. Discard TTS / voice / agent tools.

### REST (Cloud Agent fallback)

```bash
test -n "$ELEVENLABS_API_KEY"
curl -fsS -X POST "https://api.elevenlabs.io/v1/sound-generation" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text":"<ledger brief>","duration_seconds":1.5,"prompt_influence":0.65,"model_id":"eleven_text_to_sound_v2"}' \
  --output docs/design/<date>-<cue>/candidates/<cue>-a.mp3
```

Make at least three candidates (`a`/`b`/`c`). A sting that could pass for `sealedDoor`, `roseWindow`, or `chip` is wrong — regenerate.

## 3. Ship

James picks. Then in **one commit**: chosen mp3 → `assets/audio/sfx/<cue>.mp3`, new row in `assets/audio/sfx/manifest.json` (prompt, duration, influence, usage), pack bump on `pack_id` (do not re-encode ashglass-v1), ledger row moved from Owed to shipped with the prompt that actually rendered. Run `godot --headless --import` so Godot mints `.import`; do not copy a sidecar.

Missing sample: `SfxBus` warns. Do not substitute another cue.
