# First-run hint stills — #321

Evidence for the six state-triggered hints in
`docs/design/2026-08-16-guided-first-run.md`. Captured through `tools/shot.sh`
`--onboard=` (production story flow; `--fight=` / `--map` stay hint-free).
James signs off the pictures.

| Still | Design | What to look for |
|---|---|---|
| `h1-map-select.png` | L45 H1; L60–61 survey retirement; L88 skip on the first hint | Glass callout on the first live waystone. Survey label (`ui.pilgrimage.survey`) is gone. Skip-guidance control is present. |
| `h2-drag-play.png` | L46 H2; L52–54 gesture ghost | Callout on a playable enemy-target card. Gold ghost traces from the card onto the foe. |
| `h3-targeting.png` | L47 H3; L52–59 state-triggered, not step-ordered | Two living foes. Callout on a grabbed enemy-target card. H2 is already recorded so it cannot steal the still. |
| `h4-end-turn.png` | L48 H4 | Energy exhausted. Callout on End Turn. |
| `h5-intent.png` | L49 H5 | Second player turn. Callout on the enemy intent mark. |
| `h6-reward.png` | L50 H6 | First reward screen. Callout on the offering pane. |

## Machine vs design

The signed design (L93–95) stored onboarding flags in Vigil `unlocks` and gated
on `opening_played`. The machine (#321 comment, measured on main, #320) wins:

- Gate: `_vigil.scenes_seen.has("opening")` — there is no `opening_played`.
- Skip-all: `VigilState.guidance_skipped`.
- Hint records: adjacent Vigil `hints_seen` (`hintsSeen`). Never `unlocks`
  (title secrets count / Dawn reveal cards).
- Dismissal flushes Vigil at dismissal (#332 persist-before-advance). A failed
  write re-holds on Retry; the named action does not go through.

`--onboard=` is the review/photo path. Scenario kernel can write `scenes_seen`
but `_dev_claimed` still suppresses hints, matching #320.

## Capture

```bash
tools/shot.sh --onboard=map-select --seed=32101 --settle=1 \
  --shot=docs/design/2026-08-16-first-run-hints/h1-map-select.png
tools/shot.sh --onboard=drag-play --seed=32101 --settle=1 \
  --shot=docs/design/2026-08-16-first-run-hints/h2-drag-play.png
tools/shot.sh --onboard=targeting --seed=32101 --settle=1 \
  --shot=docs/design/2026-08-16-first-run-hints/h3-targeting.png
tools/shot.sh --onboard=end-turn --seed=32101 --settle=1 \
  --shot=docs/design/2026-08-16-first-run-hints/h4-end-turn.png
tools/shot.sh --onboard=intent --seed=32101 --settle=1 \
  --shot=docs/design/2026-08-16-first-run-hints/h5-intent.png
tools/shot.sh --onboard=reward --seed=32101 --settle=1 \
  --shot=docs/design/2026-08-16-first-run-hints/h6-reward.png
```
