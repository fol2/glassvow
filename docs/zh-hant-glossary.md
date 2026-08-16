# Traditional Chinese canonical glossary

**Version:** 1.1

**Locale:** `zh-Hant`
**Scope:** player-facing Glassvow copy

This glossary fixes the vocabulary used by `locale/zh-Hant.json`. It preserves
Glassvow's language of vows, lanterns, glass and embers; new copy must use these
terms rather than introducing synonyms. English catalogue keys and content IDs
remain unchanged.

| English source term | Canonical Traditional Chinese | Usage note |
|---|---|---|
| Glassvow | 琉璃誓言 | Brand title. |
| Vigil | 守夜 | The cross-run ledger and its ceremony. |
| Pilgrimage | 朝聖之路 | The horizontal journey. “Climb” and the rest of the vertical vocabulary are **banned** — full table and keep-list in `docs/story/06-glossary.md` › 垂直語彙. |
| Waystone | 引路石 | One stopping place on the Pilgrimage; the run counter is 第 {n} 塊引路石 / WAYSTONE n. |
| The Obsidian Court | 黑曜王庭 | Act III's region (it replaced the Spire, which is banned). |
| Lantern | 提燈 | The vessel that carries Embers. |
| Lantern Art | 提燈術 | The once-per-turn power. |
| Energy | 能量 | The resource spent to play cards. |
| Kindle | 燃燼 | Burn a card away to feed the Lantern. |
| Ember / Embers | 餘燼 | No plural suffix in Chinese. |
| Cinder | 燼屑 | The unplayable status card. |
| Emberglass | 餘燼琉璃 | The six panes and their Shards. |
| Facet | 璃面 | One unit of structural integrity. |
| Pane | 窗片 | One narrative Rose Window or Emberglass pane; never a combat Facet. Card metaphors may simply say 牌. |
| Chip | 琢擊 | Damage a Facet directly. |
| Shatter | 碎裂 | Break a full Facet gauge. |
| Staggered | 踉蹌 | The state caused by Shatter. |
| Ward | 護光 | Temporary protection; “Held Light” may remain 持光 as a proper item name. |
| Smolder | 陰燃 | The transferable burning status. |
| Fervor | 熾心 | Stacked inner fire that increases attack damage. |
| Poise | 沉穩 | The glassworking status that strengthens Ward cards. |
| Cracked / Dimmed / Brittle | 裂痕 / 黯淡 / 脆裂 | Glass and light states; keep the three mechanically distinct. |
| Vow | 誓言 | The optional difficulty ladder. |
| Deed | 功績 | A lifetime accomplishment recorded by the Vigil. |
| Boon | 恩賜 | The Lamplighter's starting gift. |
| Omen | 凶兆 | An act-wide modifier. |
| Hex | 咒印 | The curse card that costs health when drawn. |
| Affix | 封號 | An elite enemy's title. |
| Aspect | 面向 | A playable form. |
| Shade | 影 / `{aspect}之影` | Use 影 in prose and the composed form for generated names. |
| Phial | 藥瓶 | The consumable item class. |
| Relic | 遺物 | Persistent run equipment. |
| Mythic (card rarity) | 秘藏 | The tier above Rare. Chase content: Vow 3 only, never in shop, events or normal offer weights. |
| Treasure (map node) | 寶箱 | The no-fight chest node and its screen; renamed from 寶藏 so 藏 reads as the rarity term. |
| Rose Window | 玫瑰窗 | The Vigil's six-pane memorial and map. |
| Shard | 碎片 | A completed Emberglass quest token. |
| Unplayable | 無法打出 | A card that cannot be played from hand. |
| Lamplighter | 掌燈人 | The keeper who offers gifts. |
| Hollow Lamplighter | 空燈掌燈人 | The quest character on the Unlit Way. |

## Register standard

- House standard is Hong Kong 書面語.
- Avoid the 口語 vs 書面 gap rather than treating it as regional variation; do not use Cantonese colloquial forms (嘅／唔／係咁／攞／乜嘢).
- Proper nouns and fixed expressions are exempt.
- Draft story copy in zh-Hant first, then translate it to English for review by native English readers.
- This standard follows issue #177.

## Orthographic variants

- Use 着, not 著, for aspect and verb-complement uses; 著 remains legitimate in 顯著、著作 and 著名.
- Use 裏, not 裡, for 心裏 and 裏面.
- `tests/test_locale.gd` mechanically enforces these forms; document exceptions on `ZH_HANT_BANNED_FORM_ALLOWLIST` with a comment.
- A character scan cannot see 用語, measure words or rhythm; a green gate settles only the cheapest slice.

## Retained technical and proper names

`Alegreya`, `Cinzel`, `Noto Sans TC`, `Google`, `OFL`, `Suno`, `ElevenLabs`,
`Godot`, `roguecardv2`, `fol2`, the `Roguelite` genre label, and the `A` key
label remain in Latin script. The status descriptions also retain their literal
`N` magnitude token. Their surrounding player-facing sentences are still
translated. The language selector deliberately keeps `ui.language.en` as
`English` and `ui.language.zhHant` as `繁體中文`, so each language names itself.
`ui.end.unlock.header` is also byte-identical because it contains only a
decorative glyph and `{kind}`, with no lexical copy. `tests/test_locale.gd`
holds both exhaustive allowlists so a new identical value or Latin-script
remainder must be reviewed explicitly.

## Mechanical invariants

- Preserve the exact multiset of `@n@`, `#n#`, `{param}`, BBCode and HTML tags.
- Never add English plural suffixes to Chinese terms (`餘燼s`, `璃面s`).
- Keep every runtime keyword-term leaf paired across English and Traditional
  Chinese; aliases resolve to stable semantic keys rather than English
  fallback.
- Keep stable keys, content IDs, save fields and fixture data unchanged.
