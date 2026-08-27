---
name: glassvow-suno
description: Generate Glassvow music with Suno. Use only when adding or replacing stained-glass pack tracks, Act IV combat/boss cues, or BGM loops. Read and update docs/music-ledger.md before shipping a file.
---

# Glassvow Suno Music

The ledger is law: `docs/music-ledger.md`. Cue IDs, filenames, titles, briefs, and pack bumps live there. This skill is the dispatch path, not a second brief.

Direction: classical gothic stained-glass chamber music—dark panes, cold stone, a lantern kept lit. Instrumental only. No choir, vocals, climb vocabulary, or brass fanfare unless the ledger row names one.

The official generation path is the Suno Pro website. Do not invent an unofficial scraper. A third-party gateway is optional only when James explicitly accepts its quality and terms.

## 1. Read the owed row

Open only the matching row in `docs/music-ledger.md`. Copy the cue, file, and brief verbatim into the generation prompt. If the row is missing, write it first.

`MusicBus.FILES` maps cue to kebab-case stem (`act4Combat` → `act4-combat`). `assets/audio/music/manifest.json` is the credits-title source. A title is display copy, not a pack bump.

## 2. Discovery loop

Use Suno Pro → Create → Custom, enable Instrumental, and leave lyrics empty or `[Instrumental]`. Generate at least two candidates for the cue. Act IV must not be a re-encode or retitle of an Act III file.

Download audio, not video, into `docs/design/<date>-<cue>/candidates/`. Do not write candidates directly into `assets/audio/music/`.

Candidate generation and comparison are one bounded research batch. Do not create an issue, branch, PR, CI run, or full repository context for every render. Record the prompt and decision once; only the selected candidate crosses into delivery.

## 3. Optional third-party gateway

Use an unattended third-party gateway only when James requests it. Its credential belongs to that provider, not Suno. Keep it in the agent environment, never in the repository, prompts, logs, or output. Do not build a scraping client.

## 4. Delivery

James selects the candidate. Then make one coherent delivery change: chosen audio to `assets/audio/music/<stem>.mp3`; update `MusicBus.FILES`; add the manifest row and selected title; make the required pack bump without re-encoding the existing pack; and move the ledger row from Owed to shipped with the prompt that actually rendered.

Run import and the affected playback or manifest checks locally. The PR's actual diff then activates the relevant scopes through `tools/ci_scope.py`; do not manually attach map, balance, locale, or evidence suites that cannot observe the audio change.

Godot creates the import sidecar; do not copy one. `AudioStreamMP3.loop = true` is applied at playback, so do not pre-loop or re-encode the render merely to flatten bitrate.
