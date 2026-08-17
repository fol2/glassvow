# #228 read-pass prep — finder dossier

HITL ticket. This document is the mechanical half: a census, a finder
shortlist, and a surface map so James can read **on the page**. It does not
close #228, does not rewrite prose, and does not declare the rubric bar met.

Method: #177 resolution (James reads zh-Hant; Eugenia and Nelson read en;
Fable finds, never decides). Edit-site: #228's third restatement (#317/#323)
— English `content.*` display lives in `content/full-content.json`; whispers
and all `ui.*` / `story.*` live in the locale catalogues; a fix only in
`locale/en.json` `content.*` still changes nothing on screen.

Re-run the finder:

```bash
python3 tools/audit_copy_leaves.py --json docs/reviews/228/audit-findings.json
```

Machine dump: `docs/reviews/228/audit-findings.json`.

## Census vs the ticket's 1,197

Measured on this branch (`docs/228-read-pass-prep`), flattening both locale
catalogues the same way `tests/test_locale.gd` does:

| | Ticket (P7, #177) | Measured now |
|---|---|---|
| Paired string leaves | 1,197 | **1,400** |
| Delta | — | **+203** |
| en words (paired) | ~6,540 | **8,819** |

Both catalogues are the same shape: `en=1400`, `zh=1400`, `missing=0`,
`extra=0`. The 1,197 figure is not wrong — it is the P7 catalogue before
story batches and later content. Reconciliation:

| Family | P7 (ticket split) | Now | What landed |
|---|---|---|---|
| `ui.*` | 527 | 543 | #303 road-vocabulary chrome, rarity, persistence |
| `content.*` (hydrated display) | ~478 names/rules | 711 | Act IV selves, quests, events, variants |
| `content.whispers.*` | inside the 192 narrative | 24 | still the original 24; **Batch 1 rewrite not applied** |
| `story.*` | 0 | 122 | Batches 2–4 (opening, Lamplighter, dawn, unsealing, Act IV, finale, 5 event scripts) |
| **Total** | **1,197** | **1,400** | |

Nine event-choice `sub` leaves are byte-empty in both locales (Leave /
Walk-away rows). They count in the 1,400; they are not blanks in the #177
sense (zh empty while en is not).

Companion corpus, **not** in the 1,400: `content/line-table.json` — **178
rows** (hearth 60, waystone 60, loss 50, plus 8 quest death/closer rows).
Those render through `LineTable.text`, not `Locale.t`.

English ContentDB display is 711 hydrated leaves in `content/full-content.json`.
Bake vs `locale/en.json` `content.*` overlay shape: **0 drift** (whispers are
locale-only, as designed).

## Mechanical audit (green)

| Check | Result |
|---|---|
| Key parity | 0 missing / 0 extra |
| One-sided empty | 0 |
| Placeholder tokens (TODO, lorem, …) | 0 |
| Interpolation / rich-text marker mismatch | 0 |
| en copy-through into zh-Hant | 0 (allowlist: language labels + unlock glyph) |
| Visible Latin in zh-Hant off allowlist | 0 |
| 著 / 裡 orthography | 0 |
| Cantonese 口語 (嘅／唔／喺／嗰／攞／乜／…) | 0 |
| Trailing whitespace | 0 after excluding two joiners (`ui.brand.secrets`, `ui.omen.prefix`) |
| `ui.*` Tier A gate (`tests/test_locale.gd`) | already holding; this finder scanned **all** families |

No mechanical defect was in scope to patch. Prose stays for the sitting.

## Retired vocabulary (the real finder)

`ui.*` was cleaned by #303. What remains is **`content.*` and a handful of
line-table rows** — 27 locale keys, 4 line-table ids. The `[REWRITE:climb]`
ledger section is marked closed because Batch 1 **reviewed** those lines.
They have not **landed**. The batch file still says landing is gated on
#307/#305; both of those are now closed, and the runtime files still show
the pre-rewrite text.

Shipped (stale) vs James-approved (Batch 1), one example:

| | Shipped now | Approved, not landed |
|---|---|---|
| `content.whispers.0` | 有一種顏色，**尖塔**拒絕為它命名。 / There is a colour the **Spire** refuses to name. | 有一種顏色,長路拒絕為它命名。 / There is a colour the **road** refuses to name. |
| `content.whispers.17` | 他們在**向上**指。 / pointing **upward**. | 他們在指向**東方**。 / pointing **east**. |
| `content.whispers.20` | **王冠之上**有一扇封印之門。 / **above** the crown. | **王冠之後**… / **beyond** the crown. |

The same stale Own Shade death line is stored in three homes:
`content.quests.ownShade.fragments.*`, `content.variants.ownShade*.deathDialogue`,
and `line-table` `death.ownShade*`. Landing has to touch all three, plus
`content/full-content.json` for English quest/variant display.

27 locale keys with a remaining Tier A / tower-floor hit:

- Whispers (0-index): `.0 .3 .6 .17 .18 .19 .20 .23`
- Quests: Own Shade fragments/final; Usurper inscription/bought/death;
  Unreadable Page pages 1, 2, 4; Hollow Lamplighter meetings 1–2; Eighth Omen
  waystone echo 2
- Also: `content.variants.ownShade{2,3}.deathDialogue`,
  `content.aspects.duskblade.blurb` (climber / 攀越),
  `content.omens.longNight.text`, `content.omens.eighthOmen.text` (floor),
  `content.vows.3.desc`

Physical-position keeps, not listed: `ui.help.combatBody` ("intent above
their heads"), `story.event-forgottenShrine.coda` (苔蘚…祭品之上),
`pool.loss.e37` ("lamp still burns above the water").

**Index warning.** Ledger / Batch 1 whisper numbers are **1-indexed**.
Catalogue keys `content.whispers.N` are **0-indexed**. Ledger "whisper 14"
is `content.whispers.13`. #177's calque list uses catalogue keys.

## Per-surface map (where a leaf shows)

Hosts are the runtime screen, not the JSON file.

| Prefix | Leaves | Host |
|---|---|---|
| `ui.brand` / `ui.menu` / `ui.common` | 4+29+8 | Title / pause / ChoiceScreen |
| `ui.combat` / `ui.hud` / `ui.lamp` / `ui.card` / `ui.keywords` | 58+18+5+5+32 | CombatScreen, HUD, lantern, card chrome, RulesText |
| `ui.map` / `ui.pilgrimage` | 37+8 | World map, sealed-door threshold |
| `ui.vigil` / `ui.rose` / `ui.dawn` | 8+13+37 | VigilScreen, Rose Window, dawn chrome |
| `ui.hollow` | 15 | HollowScreen (Lamplighter meetings) |
| `ui.event` / `ui.shop` / `ui.rest` / `ui.reward` / `ui.treasure` | 11+10+15+35+8 | Node screens |
| `ui.end` / `ui.embark` | 36+7 | Run-end, vow select |
| `ui.help` / `ui.hint` | 15+7 | How-to-play, first-run hints |
| `ui.settings` / `ui.language` / `ui.credits` | 26+4+25 | Settings, credits |
| `ui.persistence` | 53 | Save-error dialog |
| `ui.scene` | 6 | ScenePlayer speaker labels |
| `ui.rarity` / `ui.omen` | 6+1 | Card rarity; act-transition plate |
| `ui.smoke` | 1 | **No host** — leftover `Hello, {name}` |
| `content.cards` / `content.status` / `content.relics` / `content.potions` | 175+34+62+14 | Card faces, tooltips, relics, phials. **en from the bake** |
| `content.enemies` / `content.variants` / `content.affixes` | 176+13+12 | Nameplates, death lines, elite titles |
| `content.events` | 76 | EventScreen body (plus `story.event-*` result/coda) |
| `content.quests` | 57 | Vigil / Rose Window quest copy |
| `content.whispers` | 24 | `Locale.whisper` — dawn + Rose Window log |
| `content.acts` / `content.vows` / `content.omens` / `content.boons` / `content.arts` / `content.aspects` / `content.deeds` / `content.shadeKits` | 8+10+16+16+12+6+16+8 | Embark, map titles, Keeper boon, lantern arts |
| `story.opening` | 8 | ScenePlayer — opening |
| `story.lamplighter-*` | 27 | ScenePlayer — five meetings |
| `story.dawn` | 25 | Vigil dawn-ceremony passages |
| `story.unsealing*` | 14 | ScenePlayer — sixth-shard |
| `story.act4-*` | 18 | ScenePlayer — Act IV nodes |
| `story.finale*` | 12 | ScenePlayer — finale / win / loss |
| `story.event-*` | 18 | EventScreen result / coda |
| line-table `hearth` | 60 | DepartureStaging (run 2+ Keeper) |
| line-table `waystone` | 60 | Map interstitial |
| line-table `loss` | 50 | Vigil defeat epitaph |
| line-table death/closer | 8 | Quest combat / closer (duplicates locale fragments) |

Suggested sitting order: **chrome (help + HUD) → whispers → quests →
opening/Lamplighter → dawn → unsealing/Act IV/finale → event scripts →
hearth/waystone/loss pools**. Skip card rules text as an A8 surface (#177);
the finder already holds tokens and orthography there.

## James shortlist (12 items, not 1,400)

Finder only. Every verdict is James's. The rest of the catalogue is for the
full sitting; these are the lines that would waste the sitting if they were
discovered halfway through.

### 1. Do not re-read Batch 1 as if it were the approved text — landing gap

James already signed Batch 1 (quests + 24 whispers) on 2026-08-16. The
runtime files still serve the pre-rewrite climb copy. Reading them "on the
page" today is a re-read of **stale** lines, not a quality pass on the
approved ones.

**Call:** land Batch 1 (all three homes + the English bake) **before** the
zh sitting, or sit knowing those 24 + six quest lines are the old text.
This prep pass does not land them.

### 2. #177 calque four, still live (catalogue keys)

| Key | zh now | Why it is on the list |
|---|---|---|
| `content.whispers.14` | 三次死亡會教你的影直言。 | Named in #177; Batch 1 kept it |
| `content.whispers.15` | 守夜有一扇窗，雖無牆承載它。 | Named in #177; Batch 1 kept it |
| `content.whispers.17` | 他們在向上指。 | Calque **and** banned 向上; Batch 1 rewrote to 指向東方 |
| `content.whispers.21` | 它的銘文等候得比守夜更久。 | Named in #177; Batch 1 kept it |

`.17` is the one that still fails the climb ban. The other three are
register/calque judgement, not token defects.

### 3. `ui.help.vigilBody` — wrong giver of the boon

en: "the **Lamplighter** offers a boon". zh: "**掌燈人**贈予恩賜".
Settled hearth NPC is **守爐人 / the Keeper** (`docs/story/02-cast.md`,
#261 Q11). The Lamplighter is the road character. This is How-to-Play, so
every new player learns the wrong name.

### 4. 彩窗 vs 玫瑰窗 — glossary split, leftover in unlanded copy

`docs/story/06-glossary.md` locks **彩窗**. `docs/zh-hant-glossary.md` 1.1
still lists **玫瑰窗**. UI chrome and Batch 4 dawn copy use 彩窗.
Unlanded whisper 22 / Unreadable Page 5 still say 玫瑰窗. One sitting
decision should pick the term; the other file then follows.

### 5. Half-width commas in `story.*` — one style call, not 100 rewrites

**100 / 122** story leaves use ASCII `,` in zh-Hant (every Batch 2–4 line
that has a comma). UI `content.*` mostly already uses `，`. This is a
house-style decision (convert vs keep), not 100 separate prose defects.

### 6. Act IV 【未*者】 names — eight placeholders, already ledgered

`content.enemies.un{carved,crossed,lit,obsidian,opened,sunk,walked,wooded}Self.name`
ship with 【brackets】 on purpose (#220). Confirm they stay bracketed for
this pass rather than getting ad-hoc names on the page.

### 7. `content.aspects.duskblade.blurb` — "versatile climber" / 「皆能攀越」

Aspect-select flavour, not quest lore. Still a Tier A hit. Easy to miss
because it is not in the Batch 1 table.

### 8. Omen + Vow leftover climb/floor

- `content.omens.longNight.text` — "The climb stretches on"
- `content.omens.eighthOmen.text` — "follow every floor"
- `content.vows.3.desc` — "You climb already cursed"

Chrome-adjacent content, outside the story batches. Short, high-traffic.

### 9. Opening beat ① — thinnest Keeper line

`story.opening.b1.l1` 「你醒了。」 / "You're awake." Voice sheet: warm,
tired, never rushes, never first-person of the road. The follow-up
「慢慢來。路不會走掉。」 does the job; the opener is the one that might
read as placeholder. Beat ④ "The vigil begins." / 「守夜開始了。」 — en
does not capitalise Vigil.

### 10. Triple-stored Own Shade death lines (voice + canon)

`fragments.1` / `ownShade2.deathDialogue` / line-table `death.ownShade2`:
「尖塔已學會披上我們的模樣。」 Batch 1 v2 (ledger row 4, 待審 at review,
then signed in the batch file): 「你留下過一道形影。這條路，已學會留住我們。」
If the sitting starts from the page, it will judge the stale voice (「每位朝聖者」
vs Shade's second-person). Same for `fragments.2` (王冠之上 vs 君王之後).

### 11. Pronouns — do not expand to 37 rows

The finder reports 37 `它/他們/它們` hits in story/content/whispers (#177
had 21; story batches added the rest). Most are inanimate 它 (door, shrine,
omen) or 他們 = the Queue, which is correct. Only re-judge:

- `content.whispers.17` 他們 (Pale Ones — calque subject)
- `content.whispers.0` / `.15` / `.21` 它 (already in item 2)
- `story.opening.b2.l3` 「他們說」 (legend "they say" — whose they?)
- `story.unsealing.b4.l1–l2` 他們 = monuments/Queue (should pass dual-read)

### 12. Finale Keeper, first person — twist-safety, not diction

`story.act4-node5.b1.l2` 「我一句都沒有說錯。我只是從來沒有說過,出去的那個是誰。」
First person is allowed (speech, not walking). This is the L4 tell. Confirm
it still passes fair-play 3 (literally true, never a lie) on the page next
to the swap.

## Out of the shortlist on purpose

- Card / relic / status rules text — mechanical surface, already gated.
- Hearth / waystone / loss pools (170 lines) — Batch 3, already
  James-reviewed per batch; finder shows no 口語 and almost no climb
  (one physical "above the water", allowlisted). Read them in the full
  sitting; they do not need a second finder pile.
- Length-ratio flags (en much longer than zh on story lines) — expected
  for zh-first + English rewrite, not a defect by itself. Eugenia/Nelson
  can use the ratio list in the JSON if a line *reads* padded.

## Eugenia / Nelson (en) — parallel finder, not James's pile

Story copy is zh-first; the calque risk sits in English. Besides the
unlanded Batch 1 en lines (climber, Spire, pointing upward, above the
crown, "The climb continues."), the native-en pass should watch:

- `content.aspects.duskblade.blurb` "versatile climber"
- `content.vows.3.desc` "You climb already cursed"
- `content.omens.longNight.text` "The climb stretches on"
- Help body `ui.help.vigilBody` (Lamplighter vs Keeper, same as item 3)
- Opening "You're awake." / "The vigil begins." (register, not calque)

## Edit-site reminder for whatever the sitting marks

| Kind | File that renders |
|---|---|
| English card/quest/enemy/omen/vow display | `content/full-content.json` |
| English whispers | `locale/en.json` |
| zh-Hant anything in `content.*` / `ui.*` / `story.*` | `locale/zh-Hant.json` |
| Hearth / waystone / loss / quest death rows | `content/line-table.json` (`zh` / `en` columns) |
| `locale/en.json` `content.*` except whispers | key template only; value drift is a docs bug, not a display bug |

The PR that lands marked lines is the record. Deferred defects go in
`docs/rc-bar.md`. No copy ledger.
