---
name: glassvow-elevenlabs
description: Generate Glassvow SFX with ElevenLabs sound generation. Use only when adding or replacing ashglass pack samples, UI/combat one-shots, or related sound-generation wiring. Read and update docs/sfx-ledger.md before shipping.
---

# Glassvow ElevenLabs SFX

The ledger is law: `docs/sfx-ledger.md`. Cue IDs, filenames, prompts, durations, and pack bumps live there. This skill is the dispatch path, not a second brief.

SFX uses sound generation, never TTS. Do not take a music-bus slot.

## 1. Read the owed row

Open only the matching row in `docs/sfx-ledger.md`. Copy the cue, file stem, duration, and brief verbatim into the prompt. If the row is missing, write it first.

`SfxBus` loads `res://assets/audio/sfx/%s.mp3`, where `%s` is the cue ID. The file stem is the cue (`unsealingSting.mp3`, not kebab-case).

## 2. Discovery loop

Prefer the connected ElevenLabs sound-generation tool when available; otherwise use the official sound-generation REST endpoint. Stop when the required environment credential is absent. Never put credentials in the repository, prompts, logs, or generated evidence.

Write candidates under `docs/design/<date>-<cue>/candidates/`, not directly into `assets/audio/sfx/`. Match the prompt influence and duration governed by the ledger row. Playback remains one-shot.

Generate at least three distinct candidates. A sting that could pass for another governed cue is not a valid candidate.

Candidate generation and comparison are one bounded research batch. Do not create an issue, branch, PR, CI run, or full repository context for every render. Record the actual generation parameters and decision once; only the selected candidate crosses into delivery.

## 3. Delivery

James selects the candidate. Then make one coherent delivery change: chosen audio to `assets/audio/sfx/<cue>.mp3`; add the manifest row with the actual prompt, duration, influence, and usage; make the required pack bump without re-encoding the existing pack; and move the ledger row from Owed to shipped.

Run import and the affected playback or manifest checks locally. The PR's actual diff then activates the relevant scopes through `tools/ci_scope.py`; do not manually attach map, balance, locale, or evidence suites that cannot observe the SFX change.

Godot creates the import sidecar; do not copy one. A missing sample must remain an explicit warning; never silently substitute another cue.
