# Policy vector — Slice B — 2026-08-14

Issue: [fol2/glassvow#215](https://github.com/fol2/glassvow/issues/215).
`BalancePolicy.default()` at `tools/balance_policy.gd:5` (`default`) is exactly
today's `p7-d2-v1` constants. `Pilot.apply_policy` deep-merges an override onto
that dict. Unspecified keys reset to default (same contract as Slice A).

## What is sampled

One vector. Groups: T1 knobs (`cardDecline`, `removalAppetite`,
`removalMinCopies`), economy thresholds (`shopMinRatio`, `restHpPct`,
`potionHealMissing`, shop gold cuts, potion shop values), `card`, `status`,
`special`, `combat`, `route`, `relics` / `relicRarity`. Removal appetite is
still one knob: shop ceiling and event `pickRemove` both read
`removal_appetite`. `REMOVAL_SHOP_MARGIN = 2.0` stays structural. Favourite-card
and relic-aspect *id lists* stay structural; only the bonus magnitudes are in
the vector.

CLI after `--` still exposes only the three T1 keys. The full vector is the
`policy` dict on `apply_policy` / `simulate`. Slice C samples it; this slice
does not.

## Replay key

Every run row records the resolved vector as `policy`. `manifest.policy` is the
same resolved dict. Adding the field bumps the seed-1000 digest from
`b38410ee…` to
`648562f245b41b131c36945c3c0627b465ec99b0f2e44c4a3aae28008f132aee`.

## Neutrality

Default vector must reproduce the merged instrument. Library still chooses
`[0]` (`28.345` vs `9.8`), forgottenShrine still chooses `[0]` (`6.0` vs
`5.4`). Empty override and `Policy.default()` produce the same run once
`policy` is stripped from the row.

Paired batch, vow 0, seeds 1000–1019, both aspects (40 runs). Stripped-row
SHA-256 `46ce7bb554c8de44927728574fff5caef937fcf6404023c8b07ccebfdfb1ab99`
before and after. Zero field mismatches. Dusk 15/20, Ash 14/20, stalls 0.
