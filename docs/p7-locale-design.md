# P7.1 — Locale design: generator boundary and the literal inventory

Status: **design of record** for P7 (issue #7 / #98). Measured against `main`
at the P6 close (`5df7a2d`, 2026-08-03). No behaviour change in this commit.

> **VOCABULARY SUPERSEDED (2026-08-16, #232 → #303).** The vertical vocabulary
> is retired game-wide: Spire, climb, ascend, summit, above-as-a-place, upward
> and stair-as-the-road are banned in every player-facing string
> (`docs/story/06-glossary.md` carries the ban and the keep-list). Every
> `Climb` / `THE SUMMIT` below records the *old* copy, not a target — §5's
> "English source strings stay as shipped until a deliberate copy pass" is
> discharged: **#303 was that pass.** The extraction discipline the same
> section states — copy edits are their own commits, never folded into a
> mechanical extraction — still stands.

P7 lands full Traditional Chinese beside English in the game's 琉璃 register,
without touching a single content ID — save schema v2 stays frozen
(`docs/commercial-game-delivery.md` §2 Locale separation; SKILL.md §3).

---

## 1. The generator boundary

Two producers of player-facing card text sit side by side. Settling which one
zh-Hant translates decides whether card text is ~30 vocabulary keys or ~175
authored strings.

### What `RulesText` does

`presentation/combat/rules_text.gd` (`RulesText`) does **not** compose card
rules from templates. It takes an already-authored paragraph — typically
`content/full-content.json` → `cards.<id>.text` / `.up.text` — and:

1. Splits `@…@` / `#…#` markers into value runs (`RulesText.tokenize`).
2. Matches the active locale's twenty-one keyword-term surfaces and highlights
   them as keyword runs (`Locale.keyword_terms`, `RulesText.tokenize`).
3. Resolves each visible surface to a stable semantic key, then serves either
   the shared glossary body or, for six statuses, the hydrated status
   description (`RulesText.keyword_key`, `RulesText.keyword_text`,
   `RulesText.keyword_status`).

The twenty-one keywords (`Cracked`, `Dimmed`, `Brittle`, `Smolder`, `Fervor`,
`Poise`, `Kindle`, `Ward`, `Energy`, `Embers`, `Ember`, `Chip`, `Facets`,
`Facet`, `Shatters`, `Shatter`, `Staggered`, `Unplayable`, `Shard`, `Hex`,
`Cinder`) are **generator vocabulary**. Their active-language surface arrays
live under `ui.keywords.terms`; their fixed glossary bodies live beside them
under `ui.keywords.*`. This is UI chrome, already catalogued on the web as
`ui.keywords`
(`port_fixtures/content/locale-en.json` → `ui.keywords`, 11 entries; plurals
share descriptions). English aliases keep separate term leaves. Traditional
Chinese aliases may share one rendered surface, but every surface still maps
back to one semantic key before tooltip lookup.

Combat ceremony banners and tip bodies on `CombatScreen`
(`CombatScreen.SAY_YOUR_TURN`, `CombatScreen.TIP_FACETS_BODY`, …) are the same
kind of thing: UI copy that happens to live next to the drain, annotated today
as the future `tr('ui.combat.*')` surface.

### What content authors

Every card, relic, potion, boon, omen, affix, art, and status carries its own
display `name` / `text` / `desc` inside `content/full-content.json`
(`ContentDB.FULL_PATH`, loaded by `ContentDB.load_full`). Examples:

| ID | Authored English |
|---|---|
| `strike` | name `Edge` · text `Deal @6@ damage.` · up `Deal @9@ damage.` |
| `defend` | name `Ward` · text `Gain @5@ Ward.` |
| statuses.`poison` | name `Smolder` · desc *(burns each turn…)* |

`ContentDB.enemy_faults` already calls enemy `name` (and move names)
**locale-owned and read-only** under mob overrides — the port already treats
display strings as a separate layer from mechanics.

The web reference at `roguecardv2-benchmark@6e06911` draws the same line:
mechanics tables stay ID-keyed; `src/i18n/hydrate-content.js`
(`hydrateContent`) copies `name` / `text` / `textUp` / choice labels from the
locale content catalogue onto those tables. UI chrome lives in a sibling
`ui` catalogue (`src/i18n/en/ui.js`), looked up by `t('ui.…')`.

### Decision (binding for P7.3–P7.6)

| Layer | What it is | zh-Hant translates | Key home |
|---|---|---|---|
| **Authored copy** | Per-ID `name` / `text` / `desc` / event prose / quest inscriptions / whispers | The full string, markers preserved | `content.<domain>.<id>…` |
| **Generator vocabulary** | Locale-owned term surfaces + semantic/status-backed glossary + combat tip/banner constants | The tokens **and** their glossary lines, kept consistent with authored copy | `ui.keywords.terms.*`, `ui.keywords.*`, `ui.combat.*` |
| **UI chrome** | Buttons, titles, help, settings, map prompts | The chrome string | `ui.<screen>.*` |

**Do not** decompose card text into vocabulary templates. "Deal @6@ damage."
is one content string, not a `ui.verb.deal` + number + `ui.noun.damage`
assembly. A generator that rebuilt sentences would fight the register, drift
from the web catalogue, and make `@n@` / `#n#` ordering a second language.

**Do** keep keyword tokens and the words inside authored zh-Hant text in lockstep
(the glossary in P7.6). Matching follows the active locale: ASCII surfaces keep
whole-word boundaries, while Traditional Chinese surfaces match their authored
characters directly. If a card says 護甲 while the active term remains 護光, the
dotted rule never lights and its glossary tip is unreachable.

Interpolation stays two systems, never mixed:

- **Rules markers** `@n@` / `#n#` — in-content value styling; survive translation
  byte-for-byte as markers (digits inside may change with balance, not with
  locale).
- **Locale params** `{name}`, `{n}`, `{act}`, `{count}` — UI/catalogue
  substitution at lookup time, same contract as the web `t()` helper.

---

## 2. The inventory (measured)

Plan estimates were 17 screens / 7 help sections / 24 whispers. Measured:

### Screens (17)

| Path | Role |
|---|---|
| `application/main.gd` (title via `ChoiceScreen`) | Brand title + tagline + begin/continue |
| `presentation/run/embark_screen.gd` | Aspect / vow embark |
| `presentation/run/vigil_screen.gd` | Vigil ledger chrome (+ whisper bodies, see §2.3) |
| `presentation/run/settings_panel.gd` | Settings |
| `presentation/run/credits_screen.gd` | Credits / OFL folds |
| `presentation/run/threshold_screen.gd` | Sealed door |
| `presentation/run/run_end_screen.gd` | Fall / abandon monument |
| `presentation/run/dawn_screen.gd` | Dawn / ascent |
| `presentation/run/run_menu_panel.gd` | In-run menu |
| `presentation/run/run_hud.gd` | Out-of-combat run HUD |
| `presentation/run/lamplighter_screen.gd` | Lamplighter parting gift |
| `presentation/run/choice_screen.gd` | Shared choice shell |
| `presentation/map/world_map_screen.gd` | Pilgrimage map chrome |
| `presentation/combat/combat_screen.gd` | Combat stage + banners/tips |
| `presentation/reward/reward_screen.gd` | Post-fight reward shell |
| `presentation/run/help_screen.gd` | How to Play |
| *(combat-adjacent, wave 2)* shop / rest / event / treasure / hollow | See §4 |

Plus supporting chrome not titled `*_screen.gd`: `hud_bar.gd`, pile browsers,
`tooltip_layer.gd`, reward sub-views (`reward_reliquary.gd`, `reward_window.gd`,
`reward_embers.gd`, `reward_rose.gd`, `reward_lancet.gd`, `reward_spoils.gd`),
`stage/transition_layer.gd` omen banner.

### Help — 7 sections

`HelpScreen.SECTIONS`: Climb, Combat, The Glass, The Lantern, Ward & Statuses,
The Fires & The Merchant, The Vigil — plus title `How to Play` and close
`Fight On` → **16** UI strings (7×title + 7×body + 2 chrome). Bodies already use
`{count}` interpolation.

### Whispers — 24

Triplicated today, byte-identical:

1. `content/full-content.json` → `whispers` (string array)
2. `VigilScreen.WHISPERS` (const array)
3. `port_fixtures/content/locale-en.json` → `domains.whispers`

Wave 3 collapses to one locale-backed source; the vigil const goes away.

### Content display fields (`content/full-content.json`)

| Domain | Entries | Display strings | Breakdown |
|---|---:|---:|---|
| cards | 61 | 175 | name 61 · text 61 · up.text 53 |
| relics | 31 | 62 | name 31 · text 31 |
| enemies | 27 | 113 | name 27 · moves.name 86 |
| potions | 7 | 14 | name 7 · text 7 |
| boons | 8 | 16 | name 8 · text 8 |
| omens | 8 | 16 | name 8 · text 8 |
| affixes | 6 | 12 | name 6 · text 6 |
| vows | 5 | 10 | name 5 · desc 5 |
| deeds | 8 | 16 | name 8 · desc 8 |
| aspects | 2 | 2 | name 2 |
| statuses | 17 | 34 | name 17 · desc 17 |
| arts | 6 | 12 | name 6 · text 6 |
| events | 11 | 67 | name 11 · text 11 · choice.label 26 · choice.sub 17 · roll.text 2 |
| quests | 6 | 18 | name · inscription · (sparse hunt/progress) |
| variants | 7 | 10 | name 7 · dialogue 3 |
| themes / acts | 3+3 | 6 | act also carries `bossName` in-file |
| whispers | 24 | 24 | plain strings |
| **Content total** | | **~607** | |

### English catalogue already captured

`port_fixtures/content/locale-en.json` (immutable fixture, generated from the
web exporter — **not** hand-edited here) already holds:

| Bucket | Strings |
|---|---:|
| `ui.*` (23 sections) | **278** |
| `domains.*` (18 domains) | **666** |
| **Fixture grand** | **944** |

`domains` is a superset of the in-file content strings above: quest
`floorEchoes` / `resolved` lines, aspect blurbs, shade-kit move names, and
event branches the sparse `full-content.json` bake does not always surface as
separate fields. **Seed `locale/en.json` from this fixture**, then add
Glassvow-only keys (Pilgrimage map chrome) measured from presentation.

Notable fixture `ui` sections (for wave planning):

| Section | n | Section | n |
|---|---:|---|---:|
| combat | 35 | map | 31 |
| end | 27 | menu | 23 |
| reward | 17 | dawn | 16 |
| help | 15 | persistence | 14 |
| keywords | 11 | rest / hud / settings / … | ≤11 each |

### Glassvow-only chrome (not in the web UI catalogue)

The horizontal Pilgrimage (`docs/map-concept-brief.md`, `CONCEPTS.md` ›
Pilgrimage / Waystone) replaced the vertical climb. Map strings such as
`SCROLL OR DRAG TO SURVEY THE PILGRIMAGE`, `Unlit Way`, `THE SUMMIT`,
`THE ROAD ENDS HERE`, waystone travel prompts, and bounty-chip copy are
**Glassvow-authored**. They get new `ui.map.*` (or `ui.pilgrimage.*`) keys in
the English seed; they are not expected to exist in the fixture verbatim.

Help/embark still say "Climb" in places — extract **verbatim** in the waves
(copy edits are their own commits, never folded into extraction). The P7.6
glossary prefers CONCEPTS terms (Pilgrimage, Waystone, Vigil, …) when
coining 譯名; English source strings stay as shipped until a deliberate copy
pass.

### Labs and developer surfaces — out of inventory

`presentation/lab/**` (~344 heuristic literals) is developer tooling. Not
player-facing; not extracted. Same for `push_warning` / parse-fault strings,
audio cue ids, card-surface recipe names (`silver-leaf`, …), stage-shape ids
(`phone-portrait`, …), and tween property paths.

---

## 3. The key scheme

### File shape

```
locale/
  en.json          # P7.2 — English seed
  zh-Hant.json     # P7.6 — Traditional Chinese
```

Top-level (Godot runtime; seeded from the fixture with one rename):

```json
{
  "formatVersion": 1,
  "ui": { "brand": { "title": "GLASSVOW", "tagline": "…" }, "combat": { … }, … },
  "content": { "cards": { "strike": { "name": "Edge", "text": "Deal @6@ damage.", "textUp": "Deal @9@ damage." } }, … }
}
```

- Fixture key `domains` → runtime key `content` (matches the web module name and
  SKILL.md §3's `locale/en.json` wording). The transform is mechanical in P7.2;
  `port_fixtures/content/locale-en.json` itself stays untouched.
- Keys are dotted paths for UI: `ui.embark.title`, `ui.combat.end`,
  `ui.keywords.kindle`.
- Content is ID-keyed: `content.cards.strike.name`,
  `content.events.forgottenShrine.choices.0.label`,
  `content.whispers.0` (index, stable — whispers have no IDs).
- Long prose (help bodies, event text, whisper lines) is **one key per
  paragraph**, never split mid-sentence. Reordering paragraphs means new keys
  (or deliberate key renames with both languages updated together) — indices in
  help use the fixture's `climbTitle` / `climbBody` names, not array positions,
  so reordering the on-screen section list cannot renumber translations.

### API (P7.2 shape, preview)

`application/locale.gd` — `RefCounted`, `static var active` published by
`application/main.gd` (same pattern as `Preferences.active`). No autoload.

```
Locale.active.t("ui.embark.title")           → String
Locale.active.t("ui.hud.actFloor", {"act": 1, "floor": 3})
Locale.active.content("cards", "strike", "name")
# fallback: requested language → en → the key itself; never crash, never blank
```

Bare `Locale.new()` serves English without main (labs / tests).

### Content read path

Two cooperating mechanisms (both land before zh-Hant is playable):

1. **UI chrome** reads only through `Locale.active.t` — extraction waves replace
   literals with keys.
2. **Content display fields** hydrate at language select (and at boot): copy
   `content.*` strings onto the live `ContentDB` row fields the presentation
   already reads (`name`, `text`, `up.text`, choice `label`/`sub`, …), mirroring
   web `hydrateContent`. English baked into `full-content.json` remains the
   mechanics-catalogue fallback and the parity source; hydration overlays the
   active language. IDs never move.

Card rules text therefore stays one authored string per language; `RulesText`
styles it with the active locale's term map and retains the semantic key needed
by the tooltip. P7.4 wires the glossary consumers; P7.6 supplies the zh-Hant
terms so matching, dotted styling and tooltip meaning stay together.

### Live language transaction (P7.7)

`Main` is the sole owner of a language change. `SettingsPanel` reports the
requested catalogue; it does not mutate `Preferences`, `Locale` or `ContentDB`.
Outside combat, Main persists the request, swaps `Locale`, hydrates content and
rebuilds the exact current route before reopening Settings. Rebuilding rather
than refreshing replaces constructor-cached map captions and run chrome too.

During combat, Main persists the request but leaves both `Locale` and
`ContentDB` on the fight's existing language. Settings says that the request
takes effect on the next screen; the next route constructor activates and
hydrates it once. A later request supersedes an earlier pending one. Neither
path reloads the game or changes run state, map state, RNG, IDs or the v2 save
shape, and returning to English restores the baked content catalogue exactly.

---

## 4. Wave boundaries (P7.3–P7.5)

Drawn on the inventory above. If a later measurement moves a string across a
boundary, **the inventory wins** over the issue's prose list.

### P7.3 — Wave 1: run screens

Title (`main` / `ChoiceScreen` brand), Embark, Vigil **chrome** (headers,
deed/quest labels' chrome — not whisper bodies), Settings, Credits, Threshold,
Run-end / Dawn / monument, Run menu, Run HUD, Lamplighter, map chrome
(waystone labels, bounty chip, travel / survey prompts, summit / sealed-door
map copy).

Per-screen commits; before/after screenshots at pad-landscape + phone-portrait;
byte-identical English.

### P7.4 — Wave 2: combat chrome

HUD (`hud_bar`, lantern, end-turn, piles / pile browsers), ceremony banners and
floaters (`CombatScreen.SAY_*`), tooltips (`TIP_*`), intent/status chip chrome,
`RulesText` keyword-term matching, styling and semantic tooltip resolution →
`ui.keywords`, and combat-adjacent copy on shop / rest / event / treasure /
hollow / reward / choice confirmations.

Floater and banner strings ride the combat event queue — change source only,
never order or timing.

Content authored `text` is **not** re-authored here; this wave may wire the
hydrate/read path so presentation resolves names through Locale, but zh-Hant
strings arrive in P7.6.

### P7.5 — Wave 3: help, whispers, events, quests

Help (all 7 sections + chrome), all 24 whispers (dedupe the vigil const), event
and quest prose keys (ensure every `content.events.*` / `content.quests.*` field
the UI can show is keyed), and any dialog leftovers from waves 1–2.

Extract verbatim — no "while we're here" copy edits.

### After the waves

| Task | Delivers |
|---|---|
| P7.6 | `locale/zh-Hant.json` (authored, glossary-bound) + Cinzel/Alegreya → Noto Serif TC fallbacks + cmap glyph gate |
| P7.7 | Settings › DISPLAY › Language; `Preferences` persistence; live re-render policy |

Noto Serif TC is bundled as reproducible subsets: Regular for reading text,
SemiBold for names and headings, and Black for the act plate. Each falls back to
a three-glyph Noto Sans Symbols2 subset for the locale markers. `tools/check_locale_font_coverage.py`
checks every `locale/*.json` character against those bundled cmaps in CI.

---

## 5. What is never extracted

| Class | Why |
|---|---|
| Content IDs (`strike`, `poison`, `rootheart`, …) | Save shield — schema v2 frozen |
| Seeds, RNG cursors, save field names | Determinism / persistence |
| Debug / `push_warning` / parse-fault strings | Not player-facing |
| Lab copy (`presentation/lab/**`) | Developer tooling |
| Audio cue ids, VFX art ids, recipe/material/finish names | Internal catalogues |
| Stage-shape ids, layout scope names, tween property paths | Engine plumbing |
| File paths (`res://…`) | Not copy |

---

## 6. Glossary seed (for P7.6 — not translated here)

Fixed once from `CONCEPTS.md` and the keyword table; James signs a sample set
before #103 merges. Starter list (English → 譯名 to be authored in P7.6):

| English | Domain |
|---|---|
| Glassvow / 琉璃誓言 | Brand |
| Vigil | Meta ledger |
| Pilgrimage | Map journey ("Climb" and the rest of the vertical vocabulary are **banned**, #232) |
| Waystone | Map node; also the run counter (WAYSTONE n / 第 {n} 塊引路石) |
| The Obsidian Court | Act 3 region — it replaced the Spire, which is retired |
| Lantern / Lantern Art / Ember(s) | Resource |
| Kindle | Verb — burn a card for an Ember |
| Ward | Player-facing block |
| Facet / Shatter / Chip | Glass combat |
| Smolder / Cracked / Dimmed / Brittle / Fervor / Poise | Statuses |
| Vow / Deed / Omen / Affix / Boon / Aspect | Meta / modifiers |
| Lamplighter / Hollow Lamplighter | NPCs |
| Rose Window / Emberglass / Shard | Quest frame |
| Phial | Potion |

Interpolation markers and HTML-ish help tags (`<b>`, `<br>`) pass through
unchanged; CJK line length is verified on phone-portrait, not assumed.

---

## 7. Acceptance for this design commit

- This document answers the four questions in #98.
- `python3 tools/check_anchors.py` and `python3 tools/check_web_anchors.py` stay
  green (symbol citations only where code is named).
- Zero gameplay or presentation behaviour change.

P7.2 begins only after this merges: `application/locale.gd` + `locale/en.json`
seeded per §3.
