# UI/UX direction — fonts, controls, flows

Decision record for wayfinder ticket
[#163](https://github.com/fol2/glassvow/issues/163) (map
[#156](https://github.com/fol2/glassvow/issues/156)), resolved with James on
2026-08-14. The mocks here are **direction**, not production: execution
re-derives geometry and regenerates art at production quality, but the look
decided here is binding until James re-decides it.

## The four decisions

### 1. zh-Hant typography — Noto Serif TC

Latin stays as shipped (Cinzel display, Alegreya reading). Every zh-Hant
glyph moves from Noto Sans TC (geometric sans, tonally wrong beside the gold
epic serif pair) to **Noto Serif TC** — specimen at `font-specimen.png`,
chosen over Chiron Sung HK and LXGW WenKai TC.

Hard numbers measured against the full locale corpus (1,157 unique chars,
1,059 CJK):

- Coverage 1,163/1,165 wanted chars. The two missing — `✦` and `⬤` — are
  **also missing from the bundled NotoSansTC today**, so they already render
  through system fallback; not a regression, but execution should give them a
  themed treatment.
- Subset per weight ≈ 1.0 MB OTF / 0.73 MB woff2 (Regular and Black both
  measured). Three weights ≈ 2.2 MB woff2, replacing the 11.9 MB full
  NotoSansTC. The locale corpus is a closed set, so the subset regenerates
  whenever `locale/*.json` changes, with a CI gate asserting every locale
  char is in the bundled font.

### 2. Control theme — systematize, not redesign

The glass+gold language in `RunStyle`/`GlassStyle` is the commercial look;
the gap is that each screen hand-assembles it and some widgets
(scrollbar, dropdown, popup) still fall through to engine defaults. Decision:
one canonical Theme resource generated from the existing tokens, covering
every Control type, with the per-panel opaque `focus` styleboxes deleted in
favour of the shared lantern focus ring (the adoption prerequisite documented
in `GlassStyle.focus_ring`).

### 3. Title menu — variant B, "Ceremonial"

`title-b.png` / `title-b.html`. Three tiers: one gold primary (Continue
Climb) on a waystone-facet plate with a lantern bloom rising beneath it, one
plain-panel secondary (Begin the Climb), and the five utilities stripped of
their boxes into one row of unboxed words at 64 px tap height — which is what
kills the "How to Play" two-line wrap. A single gold hairline with a glass
lozenge separates actions from utilities. Variant A ("quiet hierarchy", same
skeleton in neutral dress) was presented and not chosen.

Implementation notes carried from the mock: a scrim cannot hide the current
buttons (at 0.96 opacity their borders still ghost through on this dark a
scene — measured); the mock uses backdrop blur instead, but the real screen
simply won't draw the old menu. A "resume context" sub-label under Continue
Climb (act · floor) needs a locale key that does not exist yet.

### 4. Shop — concept C1, "The Night Stall"

`shop-c1.png` / `shop-c1.html`, concept art master at `stall-scene.png`
(regenerate at production quality during execution). The screen is the
painting: a gothic-arch stall at night, merchant behind the counter, and
**no UI surface at all** — no panel, heading, section label, or button box.
The scene's furniture is the layout:

- phials hang from real canopy hooks; relics stand on the counter; cards sit
  in a foreground rack (CardView faces untouched)
- every ware carries a thread-tied tag: name (Cinzel), one effect line
  (Alegreya), price chip — gold when payable, danger red when not
- SOLD = the physical gap (bare hook, empty rack pocket) with a struck name;
  unaffordable = the ware still present, only the number red — a hole versus
  a red number, distinguishable with no reading
- the quest offer sits under a cold blue-glass bell jar on its own ledge, the
  only cold light in a warm room
- leaving is walking up the staircase (`← LEAVE THE SHOP` on the treads)

Two earlier variants (panel-with-item-faces layouts, `mock-shop-a/b` in the
session scratchpad) were rejected by James: *"Both are not good. Too busy …
you are still keeping the original elements. Think wider, think wilder."*
Concepts C2 (backlit stained-glass reliquary cabinet; sold = shattered dark
pane) and C3 (Hades-class merchant close-up over a sparse counter) were
presented alongside C1 and not chosen — C2's light-as-state grammar and C3's
card-stack-opens-on-tap are worth stealing if execution needs them.

## Locale keys the direction needs but the corpus lacks

- `ui.shop.sold` — "SOLD" / 售罄
- `ui.shop.removalSpent` — "SPENT" / 已用 (card removal after use)
- a purse label if the shop shows one ("YOUR PURSE"; nearest existing is
  `ui.reward.goldAmount`)
- optional title resume sub-label (act · floor) under Continue Climb

## Found along the way

Two dev-console defects filed during the survey:
[#235](https://github.com/fol2/glassvow/issues/235) (id-only `--scenario=`
silently constructs defaults instead of the catalogue recipe) and
[#236](https://github.com/fol2/glassvow/issues/236) (`ScenarioReference.locale`
validated but never applied — no zh-Hant review states).
