---
name: glassvow-suno
description: Generate Glassvow music with Suno. Use when adding or replacing stained-glass pack tracks, act4Combat, act4Boss, BGM loops. Official path is the Suno Pro website — Suno has no public API key. Always read and update docs/music-ledger.md before shipping a file.
---

# Glassvow Suno music

Ledger is law: `docs/music-ledger.md`. Cue ids, filenames, titles, and pack bumps live there. This skill is the dispatch path, not a second brief.

Direction: classical gothic stained-glass chamber music — dark panes, cold stone, a lantern kept lit. Instrumental only. No choir, no vocals, no climb, no brass fanfare unless the ledger row names one.

**Suno has no self-serve API key.** v1 was composed in the Suno Pro website (July 2026) and ships untrimmed. That is still the official path. Cookie scrapers stay out. AceDataCloud is a third-party wrapper with its *own* token, not a Suno key — optional, below.

## 1. Read the owed row

Open `docs/music-ledger.md`. Copy the cue, file, and brief verbatim into the style/prompt. If the row is missing, write it first.

`MusicBus.FILES` maps cue → kebab-case stem (`act4Combat` → `act4-combat`). `assets/audio/music/manifest.json` is the credits title source. A `title` is display copy, not a pack bump.

## 2. Generate — Suno Pro website (official)

1. Open [suno.com](https://suno.com), signed into the same **Pro** workspace that made v1.
2. Create → **Custom**. Turn **Instrumental** on. Lyrics empty or `[Instrumental]`.
3. Paste the ledger brief into the style field. Title can wait — credits titles are display copy in the manifest.
4. Generate at least two candidates per cue. Act IV must not be a re-encode or retitle of an Act III file.
5. Download the mp3 (audio, not the video). Drop them in `docs/design/<date>-<cue>/candidates/` or hand them to the agent. Do not write straight into `assets/audio/music/` until James picks.

## 3. Optional — AceDataCloud gateway (not Suno)

Only if James wants an unattended Cloud Agent to generate. Sign up at [platform.acedata.cloud](https://platform.acedata.cloud), open the Suno Audios service, **Credentials → Create**, and put *that* token on the Cloud Agent environment as `ACEDATACLOUD_API_TOKEN`. Register `https://suno.mcp.acedata.cloud/mcp` in the cursor.com/agents MCP dropdown. Their own docs say Suno does not officially provide an API; this wrapper simulates it. Quality and ToS are James's call. Do not invent a scrape client.

## 4. Ship

James picks. Then in **one commit**: chosen mp3 → `assets/audio/music/<stem>.mp3`, `MusicBus.FILES` points at the new stem (drop any Act III alias), `assets/audio/music/manifest.json` gains the cue with James's title, pack bump (`stained-glass-v2` or a dated Act IV addendum — do not re-encode v1), ledger row moved from Owed to shipped with the prompt that actually rendered. Run `godot --headless --import` so Godot mints `.import`; do not copy a sidecar.

Godot sets `AudioStreamMP3.loop = true` at play. Do not pre-loop or re-encode the render to flatten bitrate.
