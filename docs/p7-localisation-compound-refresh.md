# P7 compound refresh report

- Run mode: **non-interactive**
- Scope: `live-language-switching-is-one-main-owned-transaction.md`
- Production correction point checked: `092d577d51ee7e62303aff42b983295f7caa3cb7`
- Closure documentation point checked: final PR head, recorded by the PR's
  exact-head receipt
- Learning point checked: `d719c053125f723b05ebac8a3f3daf6758b35efd`

## Compound Refresh Summary

Scanned: **1 learning**

| Classification | Count |
|---|---:|
| Kept | 1 |
| Updated | 0 |
| Consolidated | 0 |
| Replaced | 0 |
| Deleted | 0 |
| Skipped | 0 |
| Marked stale | 0 |

`CONCEPTS.md`: scanned. The three qualifying in-scope terms — **Language
transaction**, **Active language** and **Pending language** — distinguish
immediate selection persistence from deferred player-facing activation, and
cover replacement and cancellation semantics without implementation details.
No entry was added, refined, reconciled or scrubbed by this refresh.

## Reviewed without edits

### `docs/solutions/architecture-patterns/live-language-switching-is-one-main-owned-transaction.md` — Keep

Evidence:

- `SettingsPanel` emits language intent without mutating Preferences or Locale;
  Main owns persist → activate → hydrate → exact-route reconstruction → Settings
  reopen (`presentation/run/settings_panel.gd` (`_language_row`),
  `application/main.gd` (`_show_settings`) and
  `application/main.gd` (`_on_language_changed`)).
- Content hydration restores the previous projection first, makes English the
  baked zero-write restore, restricts writes to existing display strings, and
  leaves IDs as keys (`application/locale.gd` (`hydrate_content`),
  `application/locale.gd` (`restore_content`),
  `application/locale.gd` (`overlay_content`) and
  `application/locale.gd` (`_write`)).
- Exact-route reconstruction stores a `Callable`; the route-contract test covers
  every routed constructor, including bound arguments and the unresolved Rest
  case (`application/main.gd` (`_remember_route`),
  `application/main.gd` (`_rebuild_active_route`) and
  `tests/test_live_locale_switch.gd` (`_source_contract`)).
- Combat defers activation, hydration and reconstruction together. Every request
  replaces the pending target; selecting the active language cancels it
  (`application/main.gd` (`_on_language_changed`) and
  `tests/test_locale_hydration_main.gd` (`_combat_latest_request_wins`)).
- Title, the general router, direct Map and direct Run End drain the pending pair
  before constructing consumers (`application/main.gd` (`_show_title`),
  `application/main.gd` (`_route_run`), `application/main.gd` (`_show_map`) and
  `application/main.gd` (`_show_run_end`)).
- Runtime tests fingerprint the run save, map projection, RNG cursor, catalogue
  IDs and exact English restore; combat coverage exercises a real newly drawn
  CardView (`tests/test_live_locale_switch.gd` (`_map_round_trip`),
  `tests/test_live_locale_switch.gd` (`_assert_state_unchanged`) and
  `tests/test_locale_hydration_main.gd` (`_combat_defer_and_card_consumer`)).
- The bundled frontmatter and mechanical-claims validators passed. Every
  referenced repository path and relative documentation link resolved, and the
  repository anchor checker accepted all code citations as symbol anchors.
- Active-language keyword-term matching sits beneath `Locale.active` and does
  not change Main's ownership or transaction order. `RulesText` maps each
  rendered locale surface back to a stable semantic key; `CombatScreen` then
  resolves the hydrated status or shared glossary body
  (`application/locale.gd` (`keyword_terms`),
  `presentation/combat/rules_text.gd` (`keyword_key`),
  `presentation/combat/rules_text.gd` (`keyword_status`) and
  `presentation/combat/combat_screen.gd` (`_keyword_tip`)).
- `tests/test_i2_combat_chrome_locale.gd` covers a real English → Traditional
  Chinese switch, dotted translated terms, cache invalidation, ASCII word
  boundaries and semantic tooltip resolution. Independent probes keep all 118
  English live-card token streams exact and account for 18 unique Traditional
  Chinese surfaces, 13 live surfaces, 90 fields and 130 raw occurrences.
- The learning remains distinct from its two adjacent links: whole-run headed
  verification concerns evidence technique, while sparse mob overrides concern
  authored-content composition. Neither duplicates the Main-owned language
  transaction.

### Post-correction classification — Keep

The translated-keyword correction adds presentation coverage below the active
catalogue. It does not change immediate selection persistence, deferred combat
activation, reversible hydration, exact-route reconstruction, replacement or
cancellation. The Main-owned transaction learning therefore remains **Keep**;
the correction receives separate runtime and visual evidence rather than
reclassifying this architectural learning.

Action: **no edit**. The guidance, examples, category, references and vocabulary
remain accurate at the production and closure points checked above.

## Applied

No refresh write was required.

## Recommended

None. No stale, overlapping, superseded, misfiled or contradictory learning was
found in scope. No relocation, split or category-shape recommendation applies.

## Discoverability

Pass. `AGENTS.md` and `CLAUDE.md` identify `docs/solutions/`, its category and
frontmatter structure and when it is relevant; both also identify `CONCEPTS.md`
as the shared domain vocabulary. No instruction-file edit is required.
