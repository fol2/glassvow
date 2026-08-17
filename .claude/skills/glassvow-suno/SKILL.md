---
name: glassvow-suno
description: Generate Glassvow music with Suno (AceDataCloud MCP or Suno Pro). Use when adding or replacing stained-glass pack tracks, act4Combat, act4Boss, BGM loops, or wiring Suno MCP. Always read and update docs/music-ledger.md before shipping a file.
---

# Glassvow Suno music

Ledger is law: `docs/music-ledger.md`. Cue ids, filenames, titles, and pack bumps live there. This skill is the dispatch path, not a second brief.

Direction: classical gothic stained-glass chamber music — dark panes, cold stone, a lantern kept lit. Instrumental only. No choir, no vocals, no climb, no brass fanfare unless the ledger row names one.

v1 was composed in the **Suno Pro workspace** (July 2026) and ships untrimmed. There is no first-party Suno MCP. Cloud Agents use the AceDataCloud HTTP gateway in `.cursor/mcp.json`. Cookie scrapers and unofficial reverse-engineered clients stay out.

## 1. Read the owed row

Open `docs/music-ledger.md`. Copy the cue, file, and brief verbatim into the style/prompt. If the row is missing, write it first.

`MusicBus.FILES` maps cue → kebab-case stem (`act4Combat` → `act4-combat`). `assets/audio/music/manifest.json` is the credits title source. A `title` is display copy, not a pack bump.

## 2. Generate

Write candidates under `docs/design/<date>-<cue>/candidates/`, not straight into `assets/audio/music/`.

Prefer MCP when this session actually has Suno tools (`suno_generate_custom_music` / `suno_generate_music`). Otherwise stop unless `ACEDATACLOUD_API_TOKEN` is set and the HTTP MCP can be registered — do not invent a scrape client.

Instrumental: empty or `[Instrumental]` lyrics; put the ledger brief in the style field. Make at least two candidates per cue. Act IV must not be a re-encode or retitle of an Act III file.

### Cloud Agent MCP

Remote server: `https://suno.mcp.acedata.cloud/mcp` with `Authorization: Bearer ${ACEDATACLOUD_API_TOKEN}`. Project `.cursor/mcp.json` reaches the IDE; Cloud Agents need the same server in the cursor.com/agents MCP dropdown. Poll `suno_get_task` until the mp3 URL is ready, then download the bytes into the candidates folder.

## 3. Ship

James picks. Then in **one commit**: chosen mp3 → `assets/audio/music/<stem>.mp3`, `MusicBus.FILES` points at the new stem (drop any Act III alias), `assets/audio/music/manifest.json` gains the cue with James's title, pack bump (`stained-glass-v2` or a dated Act IV addendum — do not re-encode v1), ledger row moved from Owed to shipped with the prompt that actually rendered. Run `godot --headless --import` so Godot mints `.import`; do not copy a sidecar.

Godot sets `AudioStreamMP3.loop = true` at play. Do not pre-loop or re-encode the render to flatten bitrate.
