---
title: Live language switching is one Main-owned transaction
date: 2026-08-10
category: architecture-patterns
module: application/main
problem_type: architecture_pattern
component: service_object
severity: high
applies_when:
  - "A live locale change updates both lookup-based chrome and display strings copied into a mutable content catalogue"
  - "The current routed screen caches localised labels or content-derived display data during construction"
  - "A long-lived interaction such as combat cannot be reconstructed safely when the player changes language"
  - "Several language requests can arrive before a deferred route boundary, so the latest request must win"
  - "Language changes must preserve domain state, RNG, stable IDs and save shape while restoring the baked catalogue exactly"
related_components:
  - application/preferences
  - application/locale
  - content/content_db
  - presentation/run/settings_panel
  - presentation/routed-screens
tags: [live-localisation, atomic-transaction, composition-root, content-hydration, route-reconstruction, combat-deferral, latest-request-wins, state-preservation]
---

# Make live language switching a Main-owned atomic route transaction

## Context

Glassvow has two live representations of language. UI chrome is resolved from
`Locale.active.t(...)`, while translated content is copied into the existing
`ContentDB` rows that presentation code already reads. The locale design names
these as cooperating mechanisms, with IDs left in place
(`docs/p7-locale-design.md:262-273`); the runtime implements the second mechanism
by restoring any prior overlay and then writing only approved display fields
(`application/locale.gd` (`hydrate_content`),
`application/locale.gd` (`restore_content`),
`application/locale.gd` (`_overlay_node`) and
`application/locale.gd` (`_write`)). Changing only `Locale.active` or only the
hydrated rows can therefore produce a mixed-language screen.

The same risk exists in already-constructed UI. `SettingsPanel`, for example,
copies translated titles and labels into Nodes during construction
(`presentation/run/settings_panel.gd` (`_init`)). A refresh of one visible widget
does not update every constructor-cached caption, nor does it preserve an
unresolved route such as Rest: `_route_run()` falls through to Map when no
durable pending discriminator identifies another route
(`application/main.gd` (`_route_run`)). The integration test demonstrates that an
exact Rest reconstruction must remain a `RestScreen`, rather than being guessed
through the general run router (`tests/test_live_locale_switch.gd` (`_map_round_trip`)).

Earlier iterations split those responsibilities: Settings activated Locale
before Main could defer combat, pending state covered only ContentDB hydration,
Map was refreshed in place, and direct Run End initially bypassed the common
route drain (session history). Each shortcut left either two visible language
truths or one constructor outside the transaction. The current integration gates
exercise the real Settings request, a new combat draw, exact Rest reconstruction,
and direct Run End (`tests/test_live_locale_switch.gd` (`_map_round_trip`),
`tests/test_locale_hydration_main.gd` (`_combat_latest_request_wins`) and
`tests/test_locale_hydration_main.gd` (`_combat_defer_and_card_consumer`)).

The solution merged in PR #140 and closed issue #104. It treats language
selection as one Main-owned, presentation-atomic transaction. Outside combat,
Main persists the request, activates the catalogue, hydrates content, rebuilds
the exact routed screen, and then reopens Settings. During combat, it persists
the request but defers the activation, hydration, and reconstruction together
until a route boundary (`application/main.gd` (`_on_language_changed`)). The design of record
states the same ownership and state-safety contract
(`docs/p7-locale-design.md:279-292`).

## Guidance

### Keep intent reporting separate from state mutation

`SettingsPanel` should emit a requested language and do nothing else. Its
language button calculates the next supported code and emits
`language_changed`; it does not write Preferences, activate Locale, or hydrate
ContentDB (`presentation/run/settings_panel.gd` (`_language_row`)). Main connects
that signal and owns the transaction (`application/main.gd` (`_show_settings`)
and `application/main.gd` (`_on_language_changed`)). This keeps one composition
root responsible for ordering all four state changes.

At boot, use the same ownership boundary: Main loads the durable Preferences,
constructs `Locale.active` from the effective saved/OS language, and hydrates
the full content catalogue before constructing player routes
(`application/main.gd` (`_ready`)). `Preferences.set_language()` stores an explicit
choice (`application/preferences.gd` (`set_language`)), while
`effective_language()` gives an explicit `en` or `zh-Hant` priority over the OS
default and maps any `zh*` OS locale to Traditional Chinese
(`application/preferences.gd` (`effective_language`) and `application/preferences.gd` (`resolve_language`)).

### Order the non-combat transaction as persist, activate, hydrate, reconstruct

For a supported request, Main first persists it, overwrites the pending target,
and derives whether any activation is still required
(`application/main.gd` (`_on_language_changed`)). It then closes the old overlay, applies the
pending locale and content hydration, calls the remembered constructor, and
only then reopens Settings in the new language
(`application/main.gd` (`_on_language_changed`)). `_apply_pending_content_hydration()` activates
the pending catalogue before hydrating the live ContentDB; it clears the target
only after catalogue activation succeeds
(`application/main.gd` (`_apply_content_hydration`) and
`application/main.gd` (`_apply_pending_content_hydration`)).

This is presentation-atomic rather than a collection of unrelated refreshes:
no destination route is constructed between Locale activation and ContentDB
hydration. The map path clears the old route, constructs a new
`WorldMapScreen`, refreshes it from the unchanged run, and attaches a new HUD
only after the pending pair has been applied (`application/main.gd` (`_show_map`)).
The round-trip integration test verifies new Map and RunHud identities,
translated waystones/HUD/Settings, exact restoration of the English catalogue,
and unchanged run, map, RNG, and catalogue IDs
(`tests/test_live_locale_switch.gd` (`_map_round_trip`),
`tests/test_live_locale_switch.gd` (`_assert_state_unchanged`)).

### Remember the exact route constructor

Store a `Callable` whenever a routed screen is built, including bound arguments
when they affect reconstruction. Main retains that callable and invokes it on a
live switch, falling back to `_route_run()` or Title only when no exact
constructor is available (`application/main.gd` (`_route_rebuilder`),
`application/main.gd` (`_remember_route`) and
`application/main.gd` (`_rebuild_active_route`)). Current routes follow the
pattern, including Title, Map, Rest, Event, Shop, and a bound Vigil constructor
(`application/main.gd` (`_show_title`), `application/main.gd` (`_show_vigil`),
`application/main.gd` (`_show_map`), `application/main.gd` (`_show_rest`),
`application/main.gd` (`_show_event`), `application/main.gd` (`_show_shop`)).

Reconstruct; do not call a route-specific `refresh()` as a substitute. The
source-contract test enumerates every current routed constructor and requires
the correct `_remember_route(...)` call, including bound route arguments
(`tests/test_live_locale_switch.gd` (`_source_contract`)). The runtime test separately proves
that Map and its HUD are both replaced and that an unresolved Rest route stays
Rest (`tests/test_live_locale_switch.gd` (`_map_round_trip`)).

### Defer the whole visible transaction during combat

A fight owns one Locale/ContentDB pair. Main records the newest requested code
and persists it, but the `_screen != null` guard reopens Settings and returns
before activation, hydration, or route reconstruction
(`application/main.gd` (`_content_hydration_pending`),
`application/main.gd` (`_pending_language`) and
`application/main.gd` (`_on_language_changed`)). The reopened panel
uses Preferences for the target-language button while using the still-active
Locale for the rest of its chrome; when a switch is pending, it adds the
current-language defer note (`presentation/run/settings_panel.gd` (`_language_row`)).
This tells the player what they requested without changing the language of the
fight underneath them.

Apply the pending pair at the first constructor seam after combat, before that
screen reads Locale or ContentDB. The general run router applies it before
choosing a destination, while Title, direct Map, and Run End also protect their
direct construction paths (`application/main.gd` (`_show_title`),
`application/main.gd` (`_route_run`), `application/main.gd` (`_show_map`),
`application/main.gd` (`_show_run_end`)). The seam test explicitly requires hydration
before each of those consumers and rejects direct hydration inside the settings
handler (`tests/test_locale_hydration_main.gd` (`_main_source_seams`)).

### Make pending state latest-request-wins

Treat the pending language as a replaceable target, not a queue and not a
one-shot latch. Every request overwrites `_pending_language`; choosing the
currently active fight language makes `_content_hydration_pending` false and
clears the target (`application/main.gd` (`_on_language_changed`)). Thus an in-combat
English → requested zh-Hant → requested English sequence cancels the deferred
switch entirely.

The regression test drives that sequence through real Settings controls. It
checks that the first request persists without changing Locale, that the second
request cancels the pending hydration and defer copy, and that the next route
does not apply the stale first request
(`tests/test_locale_hydration_main.gd` (`_combat_latest_request_wins`)). This case was added explicitly
in PR #140 after a retain-the-first-request mutation showed that the earlier
suite did not protect latest-request-wins.

### Keep hydration display-only and reversible

`Locale.hydrate_content()` restores the previous overlay first and performs no
overlay for English, so switching back to English restores the baked catalogue
exactly (`application/locale.gd` (`hydrate_content`),
`application/locale.gd` (`restore_content`)). Its target map points at existing ContentDB
registries, its traversal skips unknown domains/rows, and its write helper only
replaces existing string slots while recording their previous values
(`application/locale.gd` (`_content_targets`),
`application/locale.gd` (`overlay_content`),
`application/locale.gd` (`_overlay_node`) and
`application/locale.gd` (`_write`)). IDs remain
keys rather than translated values (`application/locale.gd` (`overlay_content`)).

Do not reload or recreate `GlassvowGame` as part of a language switch. The
tests fingerprint the run save dictionary, map projection, RNG cursor,
catalogue IDs, and baked content before and after non-combat switching
(`tests/test_live_locale_switch.gd` (`_map_round_trip`),
`tests/test_live_locale_switch.gd` (`_assert_state_unchanged`)). The combat integration also proves
that existing and newly drawn CardViews remain English during the fight, that
the next screen consumes the hydrated zh-Hant catalogue, and that the v2 save
dictionary and IDs do not change (`tests/test_locale_hydration_main.gd` (`_combat_defer_and_card_consumer`)).

### Prevention and test gates

- Keep the ownership assertion that fails if `SettingsPanel` starts mutating
  Preferences or Locale, and the seam assertion that requires Main to retain a
  pending target (`tests/test_live_locale_switch.gd` (`_source_contract`)).
- Whenever a new routed constructor is added, call `_remember_route(...)` at
  its entry and extend the route table in the source-contract test
  (`tests/test_live_locale_switch.gd` (`_source_contract`)).
- Whenever a new direct combat-exit constructor is added, require
  `_apply_pending_content_hydration()` before its first Locale/ContentDB read,
  as the current Title, Map, general router, and Run End gates do
  (`tests/test_locale_hydration_main.gd` (`_main_source_seams`)).
- Preserve both integration directions: immediate en → zh-Hant → en with exact
  state/catalogue fingerprints (`tests/test_live_locale_switch.gd` (`_map_round_trip`)) and
  deferred combat switching with an actual new card draw
  (`tests/test_locale_hydration_main.gd` (`_combat_defer_and_card_consumer`)).
- Preserve the real-control cancellation test. A single-request defer test does
  not prove latest-request-wins (`tests/test_locale_hydration_main.gd` (`_combat_latest_request_wins`)).
- Run the repository gates after any change to this transaction: cache-cold
  asset import, script parsing, the full headless test suite,
  `tools/check_anchors.py`, and `tools/check_benchmark_freeze.py`.
  (`check_web_anchors.py` is deleted.) PR #140 merged only after those
  project gates and the live-switch
  integration evidence passed.

## Why This Matters

Dynamic chrome and hydrated content have different read paths but share one
player-visible language. If Locale changes during combat while ContentDB does
not, newly resolved banners can change language while card names and rules stay
old; if ContentDB changes early, a newly drawn card can change while existing
CardViews retain constructor-cached copy. The combat test exercises the actual
new-draw path and rejects either mixture
(`tests/test_locale_hydration_main.gd` (`_combat_defer_and_card_consumer`)). Deferring both halves preserves
one coherent fight.

Exact reconstruction is also a state-safety boundary. Rebuilding the stored
constructor updates constructor-cached captions without asking the general
router to infer transient presentation state. The Map/Rest integration proves
that this replaces the view and HUD while leaving the run save, map projection,
RNG cursor, and IDs unchanged
(`tests/test_live_locale_switch.gd` (`_map_round_trip`) and
`tests/test_live_locale_switch.gd` (`_assert_state_unchanged`)).

Finally, persistence and visible activation represent different truths during
combat: Preferences records what should happen next, while Locale and ContentDB
record what the current fight is allowed to render. The deferred Settings panel
makes that distinction explicit by showing the requested target and a defer
note without switching the active catalogue
(`application/main.gd` (`_show_settings`) and `application/main.gd` (`_on_language_changed`),
`presentation/run/settings_panel.gd` (`_language_row`)). Conflating those truths would
either lose the player's request or produce a mixed-language fight.

## When to Apply

- Any live setting that changes both lookup-driven chrome and data copied into
  mutable presentation catalogues, especially where screens cache strings at
  construction (`application/locale.gd` (`hydrate_content`),
  `presentation/run/settings_panel.gd` (`_init`)).
- Any route-based UI where a generic router cannot reconstruct the exact
  transient screen from durable state (`application/main.gd` (`_route_run`),
  `tests/test_live_locale_switch.gd` (`_map_round_trip`)).
- Any gameplay phase with asynchronous or incrementally-created views that must
  remain internally consistent until a safe boundary; combat creates new card
  consumers after the request and is therefore covered explicitly
  (`tests/test_locale_hydration_main.gd` (`_combat_defer_and_card_consumer`)).
- Any deferred preference where the player can change their mind before the
  boundary. The pending value must be replaceable, including cancellation back
  to the active value (`application/main.gd` (`_on_language_changed`),
  `tests/test_locale_hydration_main.gd` (`_combat_latest_request_wins`)).
- Any new direct exit from the deferred phase. It must apply the pending pair
  before constructing the destination, as direct Run End does
  (`application/main.gd` (`_show_run_end`)).

## Examples

### Bad: let the panel mutate pieces and refresh whichever screen is convenient

```gdscript
# SettingsPanel — wrong owner and wrong transaction boundary.
func _on_language_pressed(code: StringName) -> void:
	_preferences.set_language(String(code))
	Locale.active.set_language(code)
	Locale.active.hydrate_content(content)
	_map_screen.refresh(game.run)
```

This can activate language inside a fight, couples the panel to application
state, updates only one route type, and leaves constructor-cached Nodes alive.
The current contract instead limits the panel to emitting intent
(`presentation/run/settings_panel.gd` (`_language_row`)) and assigns sequencing to Main
(`application/main.gd` (`_on_language_changed`)).

### Good: Main owns an immediate-or-deferred transaction

```gdscript
func _on_language_changed(code: StringName) -> void:
	if code != Locale.CODE_EN and code != Locale.CODE_ZH_HANT:
		return
	Preferences.active.set_language(String(code))
	_pending_language = code                 # overwrite: latest request wins
	_content_hydration_pending = code != Locale.active.code
	if not _content_hydration_pending:
		_pending_language = &""                # cancelling back to active language
	_close_overlay()
	if _screen != null:
		_show_settings(true)                    # report defer; keep fight untouched
		return
	_apply_pending_content_hydration()        # activate, then hydrate
	_rebuild_active_route()                   # exact constructor, not a guess
	_show_settings(true)                      # rebuilt in the active language
```

This is the production ordering in `application/main.gd` (`_on_language_changed`). The pending
helper preserves the same activation-before-hydration order at a later route
boundary (`application/main.gd` (`_apply_pending_content_hydration`)).

### Bad: reconstruct through the general router

```gdscript
func _rebuild_after_language_change() -> void:
	_route_run() # unresolved Rest/Event/Shop can fall through to Map
```

The general router chooses from durable pending fields and otherwise shows Map
(`application/main.gd` (`_route_run`)); the Rest regression proves this loses the exact
current route (`tests/test_live_locale_switch.gd` (`_map_round_trip`)).

### Good: remember the constructor, including arguments

```gdscript
func _show_vigil(open_rose: bool = false) -> void:
	_remember_route(_show_vigil.bind(open_rose))
	# construct VigilScreen...

func _rebuild_active_route() -> void:
	var rebuild: Callable = _route_rebuilder
	if rebuild.is_valid():
		rebuild.call()
	elif game != null:
		_route_run()
	else:
		_show_title()
```

The bound-route pattern is used by Vigil (`application/main.gd` (`_show_vigil`)), and
the rebuild fallback order is centralised in Main
(`application/main.gd` (`_remember_route`) and `application/main.gd` (`_rebuild_active_route`)).

### Good: apply once at every route seam

```gdscript
func _show_run_end() -> void:
	_remember_route(_show_run_end)
	_apply_pending_content_hydration()
	var pending: Dictionary = game.run.pending_run_end
	# construct the destination only after Locale and ContentDB agree...
```

Run End is the direct combat-abandon seam and applies the pair before reading
content-derived statistics or constructing its screen
(`application/main.gd` (`_show_run_end`)). The corresponding test verifies translated
act/card/relic copy and an unchanged v2 save dictionary
(`tests/test_locale_hydration_main.gd` (`_combat_defer_and_card_consumer`)).


## Related

- [P7 locale design](../../p7-locale-design.md) — the phase design of record
- [Verify whole-run routes with headed input and throwaway application drivers](../workflow-issues/verify-whole-run-routes-with-headed-input-and-throwaway-drivers.md) — the complementary end-to-end proof pattern
- [Edit benchmark mobs as validated sparse overrides](../tooling-decisions/edit-benchmark-mobs-as-validated-sparse-overrides.md) — an adjacent atomic effective-content pattern
- [PR #140](https://github.com/fol2/glassvow/pull/140) — merged implementation and exact-head evidence
- [Issue #104](https://github.com/fol2/glassvow/issues/104) — acceptance and closure record
