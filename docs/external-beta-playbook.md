# External Beta Playbook

> **Status: skipped for glassvow** (James, 2026-08-13). Glassvow runs an
> internal TestFlight round instead — 4 testers, designed in
> [#166](https://github.com/fol2/glassvow/issues/166) — because the team has no
> recruitment resources for an external cohort. The design below was judged
> good and is kept so a future project can start from it instead of from zero.

## What one external round is for

One round cannot falsify everything. Split the goals:

- **Hard gates** — real-device stability (crashes, save integrity, thermal/
  battery) and first-run comprehension (onboarding, card text legibility).
- **Signal, not gated** — fun / worth-paying answers; collected, reviewed,
  never a numeric pass bar.
- **Out of scope** — balance tuning. Balance observations route to the balance
  workstream; mixing them into pass criteria muddies both.

## Distribution — TestFlight external

- External group, up to 10,000 testers; the **first build sent to an external
  group goes through Beta App Review automatically** — treat that as a free
  dry-run of App Store review (privacy policy URL, beta description, metadata
  all get exercised early).
- Builds expire after 90 days; testers may use up to 30 devices.
- Internal track (≤100, no review) is not a substitute: every internal tester
  must be an App Store Connect team user, which makes recruiting outsiders
  harder, not easier.

## Cohort

- **Recruit 30–40**, expecting roughly half to never open the app.
- **Validity floor: ≥15 testers actually play ≥20 minutes.** Below that the
  round didn't happen — extend or re-recruit; it is not a fail.
- Composition:
  - ≥8 active testers per locale (en and zh-Hant).
  - ~70% genre-familiar (Slay the Spire / Monster Train players), ~30% fresh —
    comprehension evidence must come from the fresh cohort.
  - ≥2 devices at or near the performance floor (iPhone SE 2 / iPad 8 class).

## Recruitment channels

- Friends and colleagues as the guaranteed-response baseline.
- HK/TW board-game and card-game communities for the zh-Hant cohort.
- r/slaythespire and roguelike-deckbuilder Discords with a public TestFlight
  link for the en cohort.

## Round shape

- **14 days, one build.** Respin only for a blocker that stops testing;
  a respin does not reset the clock.
- The build is **RC-shape**: dev tooling absent, crash reporting on — beta must
  test the thing that will be submitted, not a cousin of it.

## Feedback capture

- TestFlight built-in feedback (screenshot + comment + crash log) for
  in-the-moment reports.
- One bilingual end-of-round survey.
- Crash telemetry (Sentry) in the build — crash-free rates are unmeasurable
  without it. No additional analytics; stay privacy-minimal.

## Pass criteria — three tiers

1. **Validity floor** — the participation minimums above. Not met → extend,
   never fail.
2. **Must-fix gate** — objective and hard: crash-free sessions ≥99%, zero
   save-loss/corruption events, zero unresolved P0/P1 defects at round end.
3. **Signal review** — survey scores carry no numeric threshold at this sample
   size; the owner judges what enters the defect ledger.

## Evidence to keep

Consolidated survey results, crash-telemetry summary for the window, defect
ledger entries opened during the round with resolution status, a validity-floor
statement (who / playtime / locales / devices), and the exact build identifier.
