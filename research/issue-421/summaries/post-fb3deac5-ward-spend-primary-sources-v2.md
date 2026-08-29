# Post-fb3deac5 Ward-spend v2 primary-source note

**Issue:** #421

**Controlling authority:** owner comment `5465170578`

**Current main:** `5f53020f588145ec5fbf803de32d82c7d29c06d2`

**Frozen protocol SHA-256:** `9be852f9da9367418039e235d56de3dd55038b6cf981083568f2cbd53d86162e`

This note records only primary-source facts used to freeze the engine-correct
v2 direct experiment. It does not read, recode or use the 82 quarantined v1
observations.

## Engine and active authority

- Current-main `AGENTS.md` and
  `.claude/skills/glassvow-godot/SKILL.md` set the supported engine range to
  stable Godot 4.7.2 or later.
- The explicitly invoked
  `/Applications/Godot.app/Contents/MacOS/Godot` reports
  `4.7.2.stable.official.ed1daf0bf`; its SHA-256 is
  `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf`.
- Owner comment `5465170578` separates that repository compatibility range
  from the exact binary and host identity frozen for this experiment.

## Ward source and mediator law

- Current-main `content/full-content.json` defines `brace` as a one-energy
  common Skill gaining 8 Ward, and `bulwark` as a two-energy uncommon Skill
  gaining 13 Ward. Bulwark remains conditional and is not a direct v2 level.
- Current-main `domain/rules/combat.gd::gain_block_player` returns realised
  Ward after Dexterity, Frail and omen modification. The producer hook therefore
  records that return value rather than authored card text.
- Current-main `heavyAir` applies `wardMult = 1.25`. The one explicit Heavy Air
  source control consequently expects realised brace Ward 10; every other row
  explicitly assigns no omen.

## Separate payoff and truthful preview

- Current-main `hit_enemy` records Attack blood only when `is_attack` is true.
  The Ward payoff therefore invokes one separate `hit_enemy(..., false)` call.
- Current-main `preview_play` normally aggregates Attack hits before deciding
  Facet-chip entitlement. The research preview keeps its ordinary Attack hits
  unchanged, represents the non-Attack payoff in a separate
  `research421WardPayoff` field, and derives chip entitlement only from ordinary
  Attack blood loss.
- `tools/balance_pilot.gd` consumes preview `loss`, `lethal`, `block`, `chips`
  and `willShatter`; including the separate payoff in total loss while excluding
  it from Attack chips preserves the policy-facing causal distinction.

## RNG and null identity

- Current-main `RunState.new_run` rolls an omen only when the profile reveals
  omens. The v2 probe uses a reveal-empty profile, then assigns the frozen null
  or Heavy Air value before combat, so no random omen draw enters any contrast.
- All 18 direct identities are deterministically derived from the controlling
  comment and scenario ID. The frozen preflight found 18 unique identities,
  zero predecessor-protocol hits, zero append-only-ledger hits and zero values
  in protected range 3000–5399.

## Claim boundary

These sources justify only the frozen source, null, direct A/B/AB, separate
preview and expiry estimands. They do not establish capacity, causal whole-run
value, package admission, balance, product scope, #421 acceptance or #108 P9.
