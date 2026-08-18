# Landscape only — portrait is not a shipping orientation

Decision record, James, 2026-08-18. Map
[#156](https://github.com/fol2/glassvow/issues/156). Executing ticket
[#399](https://github.com/fol2/glassvow/issues/399).

**Glassvow does not support portrait.** Phone, pad, and desktop ship in
landscape. There is no portrait Stage shape, no portrait layout, no portrait
sign-off surface, and no portrait store screenshot. A player who rotates a
phone to portrait sees the OS rotation lock, not a second composition.

This file is the authority. Where an older brief, rubric sentence, test, or
comment still names `phone-portrait` or `pad-portrait` as a live window, it
is stale against this decision — except **historical evidence packets**, which
stay frozen (see § Historical).

Character art that happens to be framed taller-than-wide is unrelated. Those
are portraits of people, not a screen orientation.

## Why now

The identity composition has always been landscape: `pad-landscape` 1180×820,
pinned in `project.godot`, load-bearing for every measured layout number
(`CONCEPTS.md`, Stage shape). Portrait was a second product: two extra
authored sizes, a second HUD grammar (#338, #382), a second map camera
(`docs/map-concept-brief.md`), a second Night Stall rack (#242), and a
50-row performance matrix that multiplied five shapes × two locales.

That second product is cancelled. Breadth work that exists only to make
portrait readable is waste. Landscape is the game.

## Shipping Stage shapes

Three remain. Names, sizes, and the identity invariant are unchanged.

| Shape | Size | Who gets it | Role |
|---|---|---|---|
| `pad-landscape` | 1180×820 | pad class; some desktop windows (MacBook, 3:2) | **Identity.** Every ported layout number was measured here. `stage_size` at this shape against this window must stay exactly 1180×820. |
| `phone-landscape` | 844×390 | phone class | The short-wide phone composition. Still shipping. Still hard. |
| `desktop-landscape` | 1458×820 | desktop class at ~16:9 and wider | Roomier landscape. Steam Deck stays here. |

Retired. Not shipping. Not a sign-off window. Not a performance row.

| Shape | Size | Was |
|---|---|---|
| `phone-portrait` | 390×844 | phone class, taller-than-wide |
| `pad-portrait` | 820×1180 | pad class, taller-than-wide |

Device class (phone / pad / desktop) is unchanged: platform name and physical
diagonal, `PAD_MIN_INCHES` 7, `DESKTOP_MIN_INCHES` 13. Class still decides
which **landscape** reference a window may be given. It no longer offers a
portrait candidate.

## What the player sees

### Handheld (iOS, Android)

The OS lock is landscape, both tilts: Godot
`display/window/handheld/orientation = sensor_landscape`, and the iOS /
Android export presets must agree (landscape-left and landscape-right;
portrait and reverse-portrait absent from `UISupportedInterfaceOrientations`
and from the Android `screenOrientation`).

A phone held upright does not enter a Glassvow portrait mode. It stays in
the OS landscape lock, or the system UI tells the player to turn the phone.
That is a platform behaviour, not a second layout.

Floor devices for the RC bar ([#158](https://github.com/fol2/glassvow/issues/158)
— iPhone SE 2nd gen, iPad 8th gen; later the Android pair) are evidenced
**in landscape**. Portrait evidence is not collected and cannot pass a
surface.

### Desktop (macOS, Windows, Linux, Steam Deck)

Orientation settings do not apply. The window is landscape by default
(1180×820 identity). If a player resizes the window taller than wide:

- `StageShape.pick` returns that class's **landscape** reference, never a
  retired portrait name.
- Flex may add height up to `FLEX_CAP` (still 0.12 until re-measured).
- Past the cap, `content_scale_aspect = keep` letterboxes. Themed fill, not
  bare black, in the bars — same rubric rule as today.
- The layout does not restack. No two-row shop rack, no hidden HUD title, no
  map-path-in-the-lower-third.

A portrait-shaped desktop window is a degenerate window, not a product.

### Forced `--shape=`

`--shape=` / `?shape=` remains the measurement override. After cutover it may
only name a **remaining** reference. A retired name is ignored the same way
an unknown name is ignored today (`StageShape.pick` already drops
`not-a-shape`). Lab screenshots of the old portrait compositions are not a
reason to keep the keys.

## Flex cap

`FLEX_CAP` 0.12 was sized so a 16:10 tablet **in portrait** could fill
`pad-portrait` (worst case 10.1%). That justification dies with portrait.

Do **not** retune the cap in the same change that drops the shapes. Keep
0.12. The remaining landscape worst cases already sit inside it (iPad 4:3
landscape against `pad-landscape`; 21:9 Android phone against
`phone-landscape` at 7.8%). A later ticket may shrink the cap if a new
measure says so. Ultrawide desktop monitors still pillarbox past the cap;
that answer is unchanged.

## Rubric, RC bar, sign-off

`docs/commercial-rubric.md` is live. Amendments in the same landing as this
file:

- Global safe-area criterion already said "in landscape". After this
  decision every supported device **is** landscape, so the phrase is
  redundant but true.
- The 4:3 / 20:9 fill criterion is landscape 4:3 (iPad held sideways) and
  landscape 20:9 (phone held sideways). "Tall phone" no longer names a
  portrait window.
- Credits Close "at every stage shape" means the three remaining shapes.
- Node-screen reachability on `phone-landscape` stays. That shape is still
  the tightest vertical budget.
- HUD location-line criterion on a phone-landscape stage stays.

Sign-off protocol is unchanged: real device, release export, both locales,
arm's length. The device is held in landscape.

The RC bar (`docs/rc-bar.md`) does not name portrait. No pillar is rewritten
here. P2 performance rows that still enumerate five shapes are cut to the
three remaining ones on the next evidence capture — not by editing a frozen
packet.

Store listings (App Store, Play, Steam): landscape screenshots only.
Portrait phone frames are not a listing requirement we will meet.

## Historical documents stay frozen

These records measured portrait on purpose. They are not instructions, and
they are not rewritten:

- `docs/p8-full-run-qa.md` — journeys R2 / R4 at 390×844.
- `docs/commercial-game-delivery.md` §5 — Issue #105's 50-row matrix
  (five authored shapes × locales × processes). The signed P8.1 Mac gate
  numbers stay. Future captures use three shapes.
- `docs/battlefield-parity.md`, `docs/p7-locale-design.md`,
  `docs/p7-localisation-milestone.md` — portrait is part of the history
  they report.
- `docs/solutions/**` that diagnosed a portrait bug — the diagnosis stays;
  the bug's surface is gone.
- Frozen `file:line` citations into the detached web reference (607, no
  608th).

`docs/map-concept-brief.md`'s **Phone-portrait** camera paragraph
(path in the lower third, ~2–3 nodes) is superseded. The pilgrimage is a
horizontal landscape journey. Pad-landscape and phone-landscape camera
notes in that brief still apply.

## In-flight tickets

| Ticket | After this decision |
|---|---|
| #242 Night Stall | Landscape C1 only. No two-row portrait rack. No portrait shipping window in `tests/test_stall_layout.gd`. Identity 1180×820, phone-landscape short stage, 4:3 iPad landscape. |
| #338 pad-portrait HUD | Already on `main`. Those branches become dead and come out in the presentation slice. |
| #382 phone-landscape HUD wrap | Stays. `phone-landscape` is still shipping. Compact chrome that pad-portrait *shared* with phone-landscape is now phone-landscape's own. |
| #204 holdout | Unrelated. Already on `main`. |
| #211 vow bake-off | Unrelated. |

## Implementation slices

One change that deleted every portrait branch, book key, test, and tool row
would blow the >400-line stop. Split:

**Slice 0 — this document.** Glossary, rubric wording, map. No runtime
change. Lands first so every other lane cites one file.

**Slice 1 — picker + OS lock.** `StageShape.CANDIDATES` drops the two
portrait names. A taller-than-wide window picks that class's landscape
shape. `tests/test_stage_shape.gd` matrix rows that currently expect
`phone-portrait` / `pad-portrait` expect the landscape pick and letterbox
past the cap. `project.godot` + iOS/Android export presets take
`sensor_landscape`. Forced `--shape=` of a retired name is ignored.

**Slice 2 — presentation branches.** Delete `shape == &"phone-portrait"` /
`&"pad-portrait"` arms in HUD, combat, map, story player, node screens,
shop, embark, vigil, dawn, credits, run-end, layout book resolver defaults.
`phone-landscape` and `pad-landscape` arms stay. Visual shots of the three
remaining shapes before review.

**Slice 3 — layout book keys.** Remove `phone-portrait` and `pad-portrait`
objects from `assets/layout/combat-layout.json` (and any sibling book).
Schema/validator must reject a new portrait key.

**Slice 4 — tools and gates.** `tools/run_performance_budget.py`,
`tools/probe_layout.gd`, `presentation/lab/layout_lab.gd`, shot harness
defaults, `tests/measure_hud_location.gd`, containment harnesses that still
boot a portrait window as if it were shipping.

**Slice 5 — leftover live docs.** `docs/map-concept-brief.md` phone-portrait
paragraph struck with a pointer here. No historical packet is edited.

Domain, saves, content IDs, locale strings, and the identity size do not
move. This is a presentation + export + evidence-matrix change.

## Out of scope

- Retuning combat, rewards, vows, or shop prices.
- Redesigning the identity 1180×820 composition.
- Dropping `phone-landscape` (it is landscape).
- A desktop window-aspect lock (we letterbox; we do not fight the WM).
- Regenerating character portrait art.
- Re-running the #105 / P8.1 performance packet (next capture, not this
  decision).
- IAP, store presence copy, or #243 listing screenshots beyond the rule
  "landscape only".

## Done when

Observable, not vibes:

1. This file is on `main`.
2. Slice 1: a phone-class 1179×2556 window picks `phone-landscape`; an
   iPad-class 1640×2360 window picks `pad-landscape`; a handheld export
   refuses portrait rotation; `godot --headless -s res://tests/run_all.gd`
   is PASS.
3. Slice 2–4: `rg phone-portrait pad-portrait` in `presentation/`,
   `application/`, `tests/`, `tools/`, `assets/layout/` returns only
   comments that say the name is retired, or zero hits.
4. Rubric sign-off and RC evidence name three shapes, never five.
5. #242's stall acceptance windows are landscape-only.

## Inventory (live code, 2026-08-18, `99b66e5`)

Not an implementation plan — the search an implementer starts from. Counts
are `rg` hits on this commit and will move.

**Picker / identity**

- `presentation/stage/stage_shape.gd` — `REFERENCES` (five), `CANDIDATES`
  (phone and pad still offer portrait), `FLEX_CAP` comment names tablet
  portrait as the worst case.
- `tests/test_stage_shape.gd` — shipping matrix still expects portrait picks
  (iPhone 17 / Pixel 9 / Galaxy S24U portrait; iPad Air / 4:3 / Tab S9
  portrait; "desktop window, portrait").
- `application/main.gd` — `--shape=` examples name `phone-portrait` /
  `pad-portrait`.
- `project.godot` — viewport 1180×820, no `handheld/orientation` yet.
- `export_presets.cfg` — no orientation key yet (defaults allow portrait).

**Presentation branches** (file has at least one `phone-portrait` or
`pad-portrait` arm)

`presentation/run/run_hud.gd`, `run_end_screen.gd`, `credits_screen.gd`,
`embark_screen.gd`, `shop_screen.gd`, `help_screen.gd`, `threshold_screen.gd`,
`rose_window_view.gd`, `dawn_screen.gd`, `vigil_screen.gd`,
`lamplighter_screen.gd`, `hollow_screen.gd`, `rest_screen.gd`,
`event_screen.gd`, `treasure_screen.gd`, `choice_screen.gd`,
`presentation/story/scene_player.gd`, `presentation/map/map_band.gd`,
`presentation/map/glass_waystone.gd`, `presentation/combat/enemy_view.gd`,
`presentation/combat/combat_screen.gd`, `presentation/combat/sky_field.gd`,
`presentation/stage/layout_book.gd`, `presentation/lab/layout_lab.gd`.

**Layout book:** `assets/layout/combat-layout.json` — nine
`phone-portrait` / `pad-portrait` objects.

**Tests / harnesses:** `tests/test_run_hud.gd`, `test_presentation.gd`,
`test_locale.gd`, `test_map.gd`, `test_layout_book.gd`,
`test_stall_layout.gd`, `measure_hud_location.gd`,
`choice_scroll_reachability.gd`, `dawn_phone_containment.gd`,
`boss_relic_choice_containment.gd`.

**Tools:** `tools/run_performance_budget.py`, `tools/probe_layout.gd`,
`tools/dev.py` (defaults already `pad-landscape`).

**Live docs to amend (not freeze):** this file, `CONCEPTS.md` (Stage shape),
`docs/commercial-rubric.md` (two criteria), `docs/map-concept-brief.md`
(slice 5).
