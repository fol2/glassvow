# unsealingSting candidates — 2026-08-17

ElevenLabs `eleven_text_to_sound_v2`, `duration_seconds` 1.5,
`prompt_influence` 0.65, `loop` false. Three REST renders; pick **B**.

Shipping copy is `assets/audio/sfx/unsealingSting.mp3` (byte-identical to
`candidates/unsealingSting-b.mp3`). v1 ashglass files were not re-encoded.

| cand | bytes | duration | mean / max | note |
|---|---:|---:|---|---|
| A | 24703 | 1.515 s | −39.9 / −26.7 dB | Two-hump, too quiet to land over the ceremony bed |
| **B** | 24703 | 1.515 s | −35.5 / −24.8 dB | Most tonal (lowest ZCR). Second-half brightness rise = amber → cold |
| C | 24703 | 1.515 s | −24.7 / −14.6 dB | Punchy impact; dies by ~550 ms — reads as a hit, not a chord inversion |

None can pass for `chip` (0.52 s, ZCR ~0.38 vs B ~0.012), `sealedDoor`
(179 s music bed), or `roseWindow` (149 s music bed).

Prompt that rendered:

> One-shot glass sting: the six panes become a mirror. A short glass-chord inversion, warm amber bloom turning cold as the reflection takes. No choir, no vocals, no door grind, no footsteps, no long cinematic tail. Must not sound like a sealed door theme, a rose-window bed, or a tiny glass chip tick.
