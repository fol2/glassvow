# Post-3a234bae Ward-spend v3 primary-source note

**Issue:** #421

**Controlling authority:** owner comment `5466728774`

**Current main:** `5f53020f588145ec5fbf803de32d82c7d29c06d2`

**Frozen protocol SHA-256:** `7b0773f92ceae02f3303b07ba9aaca54439e2aa443466a69068c874cdc704d1f`

This note records only primary-source facts used to freeze the cache-correct
v3 direct experiment. It does not read, recode or use the 82 quarantined v1
observations or the zero-decision-row v2 result.

## Engine and generated-cache authority

- Current-main `AGENTS.md` and
  `.claude/skills/glassvow-godot/SKILL.md` set the supported engine range to
  stable Godot 4.7.2 or later.
- The explicitly invoked
  `/Applications/Godot.app/Contents/MacOS/Godot` reports
  `4.7.2.stable.official.ed1daf0bf`; its SHA-256 is
  `c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf`.
- Owner comment `5466728774` authorises exactly one separately versioned
  correction in which fresh detached current-main worktrees generate their
  Godot project cache before candidate, probe, protocol and research identities
  are frozen.
- Both fresh worktrees produced
  `.godot/global_script_class_cache.cfg` at SHA-256
  `4937b0a7e7f4a10f3821d39ffd2e1c759ed79204ce37b8ddb53cce7af09ee8cd`.
  The v3 runner freezes both identities before execution, checks them again
  afterwards and contains no import or cache-repair step.

## Ward source and mediator law

- Current-main `content/full-content.json` defines `brace` as a one-energy
  common Skill gaining 8 Ward, and `bulwark` as a two-energy uncommon Skill
  gaining 13 Ward. Bulwark remains conditional and is not a direct v3 level.
- Current-main `domain/rules/combat.gd::gain_block_player` returns realised
  Ward after Dexterity, Frail and omen modification. The producer hook therefore
  records that return value rather than authored card text.
- Current-main `heavyAir` applies `wardMult = 1.25`. The one explicit Heavy
  Air source control consequently expects realised brace Ward 10; every other
  row explicitly assigns no omen.
- The candidate runtime diff is the unchanged v2 mechanical artefact at
  SHA-256 `27c753fbdebbf787be9a280e24529d1701218f048f4408f4f4a2b14f5c2f5291`.
  No threshold, producer, spend, payoff, aspect, expiry or policy semantic was
  changed for v3.

## Separate payoff and truthful preview

- Current-main `hit_enemy` records Attack blood only when `is_attack` is
  true. The Ward payoff therefore invokes one separate
  `hit_enemy(..., false)` operation.
- Current-main `preview_play` normally aggregates Attack hits before deciding
  Facet-chip entitlement. The research preview keeps ordinary Attack hits
  unchanged, represents the non-Attack payoff in a separate
  `research421WardPayoff` field, and derives chip entitlement only from
  ordinary Attack blood loss.
- `tools/balance_pilot.gd` consumes preview `loss`, `lethal`, `block`,
  `chips` and `willShatter`; including the separate payoff in total loss
  while excluding it from Attack chips preserves the policy-facing causal
  distinction.

## RNG and null identity

- Current-main `RunState.new_run` rolls an omen only when the profile reveals
  omens. The v3 probe uses a reveal-empty profile, then assigns the frozen null
  or Heavy Air value before combat, so no random omen draw enters a contrast.
- All 18 direct identities are deterministically derived from owner comment
  `5466728774` and scenario ID. The frozen construction found 18 unique
  identities, zero predecessor-protocol hits, zero append-only-ledger hits and
  zero values in protected range 3000–5399.
- Every causal contrast uses the same scenario seed, baseline, candidate,
  content projections, first-look budget, estimator and stopping rule.

## Claim boundary

These sources justify only the frozen pre-row environment provenance, exact
engine and class-cache identities, source, null, direct A/B/AB, separate preview
and expiry estimands. They do not establish capacity, causal whole-run value,
package admission, balance, product scope, #421 acceptance or #108 P9.

## Natural-capacity preregistration

The separately frozen capacity protocol has SHA-256
`04d113b2670bb163adf692736a853a2cedb472a7b6fd1c7c429fc7b278bc9708`.

- Both arms use one identical content projection at SHA-256
  `908a4cfb2c002b1f6dc17414e570c77e5da451c40cf84b6bf19be36f502038f8`.
  It adds the research card to the common pool in both arms; only producer
  observation changes.
- The consumer effect is fixed off. Capacity therefore derives payable Ward
  for spend 4 and 8 from the same opportunity telemetry without spending Ward,
  applying damage or duplicating aliased simulator rows.
- The shared off and brace arms use policy root `252206084`, indices 0–63 and
  four fixed simulation seeds. Bulwark adds only one observation arm against
  those same off rows, and only after valid brace capacity futility.
- The five cohort identities are absent from predecessor protocols, the
  append-only ledger and protected range 3000–5399.
- Capacity success may authorise only a separately frozen CRN causal panel.
  It cannot establish payoff value, package admission, product scope or P9.
