# P7 remaining English key map (Wave 4 I0)

Status: **catalogue frozen for I1–I3**. `locale/en.json` is the value
source; the extraction lanes must consume these keys verbatim and must not edit
the English catalogue. A post-I0 audit added only the mechanically derived
display labels listed below; call-site lanes still do not own catalogue files.
This map records ownership, composition and timing seams without duplicating
the catalogue copy.

Legend: **E** existing, **N** new in I0, **U** existing value corrected in I0.
Function names, rather than line numbers, are used so the map survives source
movement.

## I1 — remaining run screens

| Surface | Source seam (`file:function`) | Keys | Notes |
|---|---|---|---|
| Credits shell | `presentation/run/credits_screen.gd:_init`, `_add_licence_fold`, `_add_font_licence_fold`, `_build_licence` | E `ui.credits.title`, `heading*`, `body*`, `close`, `engineLicences`, `fontLicences`, `components`, `licenceTexts`; N `ui.credits.footer` | Preserve section and focus order. Manifest pack IDs and titles are not catalogue copy. |
| Credits manifests | `presentation/run/credits_screen.gd:_add_music_attribution`, `_add_music_rows`, `_add_sfx_rows` | N `ui.credits.musicAttribution`, `musicAttributionCount`, `musicTracklistFallback`, `sfxAttribution`, `sfxAttributionCount`; E `themeLine` | `{count}` replaces only the number; manifest item order stays authoritative. |
| Emberglass Rose | `presentation/run/rose_window_view.gd:_pane_copy`, `_detail_copy`; `presentation/run/choice_screen.gd:_add_title_rose` | N `ui.rose.shardRecoveredStack`; U `ui.rose.openLabel`; E remaining `ui.rose.*` | Preserve the newline in the recovered stack and pane ordering. |
| Dawn chrome | `presentation/run/dawn_screen.gd:_build` | N `ui.dawn.inputHint`; E `ui.dawn.*`, `ui.end.*` actions/stats | Preserve the double spaces around the middle dot and the reveal/skip timing. |
| Dawn fallback memories | `application/main.gd:_on_terminal_commit` | N `ui.dawn.memoryTitle`, `memoryBody` | `{count}` is the shard count; do not reorder the queued event. |
| Dawn unlock copy | `application/main.gd:_unlock_dawn_copy` | N `ui.dawn.unlock.{lamplighter,phials,omens,pool,emberglass,act4}` | All three pool-wave IDs compose the one `pool` value. |
| Dawn shard grant | `application/main.gd:_on_terminal_commit` | E `ui.dawn.shardGrantCopy` | Replace only the literal body; quest completion and event order stay authoritative. |
| Run-end bequest choices | `application/main.gd:_bequest_choices` | E `ui.end.bequestNote.{relic,card,gold,goldCache}` | `{n}` is the offered gold amount. Relic/card ranking and choice order stay code-owned. |
| Monument choice | `application/main.gd:_show_monument` | N `ui.end.monument.{body,bodyWithBequest,title,claim,leave}` | Select one complete body; do not assemble or retime the choice route. |
| Map captions | `presentation/map/world_map_screen.gd:_node_caption`, `_act_line` | N `ui.map.node.{act4,monument}`; U `ui.pilgrimage.awaits`; E `ui.pilgrimage.*` | `{region}` precedes `{boss}`; the narrow-layout region-only fallback remains code-owned. |
| Run HUD | `presentation/run/run_hud.gd:refresh`, `_rebuild_right`, `_location_text` | N `ui.hud.{hpFraction,location}`; E `viewDeck`, `menu`, `emptyPhial` | `{act}`, `{n}`, `{boss}` retain their source order. Diagnostic unknown-content fallbacks stay literal. |
| Run-deck overlay | `application/main.gd:_show_run_deck` | N `ui.hud.{deckOverlayTitle,deckOverlayCount}`; E `ui.menu.close` | `{count}` is the live deck size; preserve card and close-action order. |
| Non-combat phial choice | `application/main.gd:_show_potion_menu` | N `ui.common.use`; E `ui.hud.tossPotion`, `ui.menu.close` | Choice order is use, toss, close. |
| Lamplighter | `presentation/run/lamplighter_screen.gd:_build` | E `ui.lamp.{title,sub,boonLabel,artLabel,artHint}`, `ui.menu.chooseBoon`, `ui.menu.lightTheWay` | Compose `artLabel` + `artHint`; no redundant combined heading key. |

## I2 — combat and adjacent choices

| Surface | Source seam (`file:function`) | Keys | Notes |
|---|---|---|---|
| Combat HUD/inspector | `presentation/combat/hud_bar.gd:_build_lantern`; `presentation/combat/combat_screen.gd:_show_deck`, `_show_inspector` | N `ui.combat.{lanternAria,deckInspectorTitle,inspectorCardCountOne,inspectorCardCountMany,inspectorEmpty}` | Choose the one/many key in code; do not pass an English plural suffix. |
| Combat HUD raw controls | `presentation/combat/hud_bar.gd:set_values`, `_build_top_bar`, `_build_pile`, `_build_end_turn` | E `ui.combat.{draw,discard,ashes,drawPileAria,discardPileAria,ashesPileAria,end}`, `ui.hud.{deckAria,menuAria,emptyPhial}`; N `ui.hud.hpFraction` | Preserve widget order, accessibility labels and end-turn state timing. The plate's compact numeric fraction is code-owned. |
| Combat pile overlays | `presentation/combat/combat_screen.gd:_show_pile`, `_build_inspector` | E `ui.combat.{drawPileTitle,discardPileTitle,ashes}`, `ui.menu.close` | Close remains the final action; pile order comes from combat state. |
| Combat phial choice | `application/main.gd:_show_combat_potion_menu` | N `ui.hud.usePotionOn`, `ui.common.use`; E `ui.hud.tossPotion`, `ui.menu.close` | `{name}` is the live enemy display name; target order and use/toss/close order stay unchanged. |
| Combat drain/header | `presentation/combat/combat_screen.gd:_handle_event`, `_push_hud`; `application/main.gd:_resume_pending_combat` | N `ui.combat.{adamant,turn,encounterHeader}`, `ui.combat.encounterKind.{monster,elite,boss}` | Preserve `encounterHeader`'s double space and event/drain order. Resolve relic proc names through hydrated content; mechanics IDs and route kinds are not display copy. |
| Intent tooltip | `presentation/combat/combat_screen.gd:_intent_tip` | N `ui.combat.intent.{attackFor,gainWard,healSelf,afflictYou,empower,act,summary}` | Keep bit order: attack, Ward, heal, player affliction, self empowerment. `{amount}` retains BBCode and `{intent}` receives the joined phrase. |
| Rest upgrade | `application/main.gd:_on_rest_choice`; `presentation/run/rest_screen.gd:_build` | N `ui.rest.{temperCardTitle,temperCardBody}`; E `smithBtn`, `smithSub` | Compose the Smith line from existing keys; no combined key. |
| Event card choice | `application/main.gd:_show_event_pick` | N `ui.event.chooseCardBody`; E `ui.event.chooseCardTitle` | The content-card list and its ordering remain live data. |
| Shop removal | `application/main.gd:_on_shop_choice` | N `ui.shop.cardRemoval.confirmBody`; E `ui.shop.cardRemoval.*` | The chosen deck order is unchanged. |
| Live reward shell | `presentation/reward/reward_screen.gd:_init`, `_build_rows`, `_deepen`, `_on_continue`, `_title_text` | E `ui.reward.{victory,eliteSlain,bossVanquished,continue,skip,leaveIt,walkOn,takeOneLight,takeOneFromLight,onePiece,addCard,offeredTakeOne,goldAmount,chooseCardTitle,chooseCardBody,leaveConfirmTitle,leaveConfirmBody,leaveConfirmYes,leaveConfirmNo}`; U `ui.reward.goldRow` | Keep reward row, offer and confirmation order; `{tone}`/`{n}` retain Godot BBCode. Bench-only `_open_choice_modal` stays excluded. |
| Reward phial rack | `application/main.gd:_show_potion_replace` | N `ui.reward.{replacePotion,discardNewPhial,phialRackFullTitle,phialRackFullBody}` | `{name}` is the held phial; replacement slots stay in rack order, discard stays last. |
| Boss crown | `application/main.gd:_show_boss_relic` | N `ui.reward.{bossTakeNone,bossCrownTitle,bossCrownBody}` | Relic offer order stays deterministic; take-none remains last. |
| Adjacent Rest/Shop/Event | `presentation/run/rest_screen.gd:_build`; `presentation/run/shop_screen.gd:_build`; `presentation/run/event_screen.gd:_build` | E `ui.rest.*`, `ui.shop.*`, `ui.event.*`; N choice keys listed above | Content names/descriptions remain hydrated data; route action order stays unchanged. |
| Adjacent Treasure/Hollow | `presentation/run/treasure_screen.gd:_build`, `_reward_copy`; `presentation/run/hollow_screen.gd:_build`, `set_paid`, `show_error` | E `ui.treasure.*`, `ui.hollow.*`; U `ui.treasure.coinsOnly` | `{tone}`/`{gold}` retain BBCode; Hollow route state and answer timing stay unchanged. |
| Main combat choices | `application/main.gd:_show_combat_potion_menu`, `_show_potion_replace`, `_show_boss_relic`, `_show_event_pick`, `_on_shop_choice`, `_on_rest_choice` | N choice keys above; E their screen prefixes and `ui.common.*` actions | Only string sourcing changes; deterministic offer, target and choice ordering remain code-owned. |

## I3 — remaining prose and persistence

| Surface | Source seam (`file:function`) | Keys | Notes |
|---|---|---|---|
| Hollow rule messages | `domain/rules/quests.gd:pay_lamplighter`, `pay_hollow_price` | N `ui.hollow.message.{inactive,emberDebt,needGold,vesselTooFragile,needBoon,paneLit,noPriceWaiting}` | Seven exact result messages. Preserve domain purity and rule/progress order; persisted v2 English `answer` values remain backward-compatible, and I3 must never write translated copy into saves. |
| Begin-anew dialog | `application/main.gd:_on_embark_begin` | U `ui.menu.beginAnewBody`; E `ui.menu.beginAnew`, `stayOnRoad` | Uppercase `beginAnew` for the title only; preserve action and cancel order. |
| Leave-Road dialog | `application/main.gd:_show_run_menu` | N `ui.menu.{leaveRoadTitle,leaveRoadBody}`, `ui.common.stay`; E `ui.common.leave` | This owns only the quit confirmation opened by the already-extracted run menu; preserve action and cancel order. |
| Abandon dialog | `application/main.gd:_confirm_abandon` | U `ui.menu.abandonConfirmBody`; E `ui.menu.{abandonConfirmTitle,abandonRun,stayOnRoad}` | Preserve overlay routing, action order and the existing title case conversion. |
| Save-error shell | `application/main.gd:_show_save_error` | N `ui.persistence.{lightWouldNotHoldTitle,noProgressDiscarded}`, `ui.common.title`; E `ui.common.retry` | I3 owns the entire function. Keep the newline between detail and the no-progress sentence. |
| Save-error detail | every `_show_save_error` caller in `application/main.gd` | N all 35 `ui.persistence.detail.*` leaves | Exact duplicate messages share one key. Retry routing and save timing remain unchanged. |
| Already-wired prose proof | `presentation/run/help_screen.gd:_sections`, `_init`; `presentation/run/vigil_screen.gd:_whisper_lines`; `presentation/run/event_screen.gd:_build` | E `ui.help.*`, `content.whispers.*`, hydrated `content.events.*` | No call-site extraction is due. I3 still captures Help, one stable-index whisper and one event at both required shapes. |

## Post-I0 derived display labels

The raw-literal inventory could not see mechanics IDs transformed at runtime.
An independent I2 review found these labels before #103 translation began, so
their exact current English is frozen here in a separate catalogue-owner change:

| Surface | Source seam (`file:function`) | Keys/read path | Notes |
|---|---|---|---|
| Encounter kind | `application/main.gd:_resume_pending_combat` | N `ui.combat.encounterKind.{monster,elite,boss}` | Localise only the display parameter; `pending_combat`, music and rules retain the stable route ID. |
| Card type rubric | `presentation/combat/card_view.gd:_build` | N `ui.card.type.{attack,skill,power,status,curse}` | Values match the existing lower-case mechanics labels; the view keeps its visual uppercase transform. |
| Relic rarity tooltip | `presentation/run/run_hud.gd:_tip` | N `ui.rarity.{starter,common,uncommon,rare,special,boss}` | Translate only non-empty known values; unknown-content diagnostics stay literal. |
| Combat phial/relic names | `presentation/combat/hud_bar.gd:set_potions`; `presentation/combat/combat_screen.gd:_handle_event` | hydrated `content.potions.*.name`, `content.relics.*.name` | These are authored content names, not new UI synonyms. Preserve slot identity and floater timing. |

## Catalogue corrections included in I0

Nine pre-existing leaves changed to match current Godot output: `ui.menu.beginAnewBody`,
`ui.menu.abandonConfirmBody`, `ui.rose.openLabel`, `ui.reward.goldRow`,
`ui.treasure.coinsOnly`, `ui.pilgrimage.awaits`, `ui.combat.facetsBody`,
`ui.combat.lanternBody`, and `ui.combat.staggeredBody`. The last three replace
mojibake with a true em dash; all other wording and tags remain unchanged.

## Explicit exclusions

- `ContentDB` hydration owns authored `content.*` display fields; I1–I3 do not
  create per-call-site synonyms for hydrated names, rules text or event prose.
- Help and all 24 whispers are already catalogue-backed; authored event and
  quest content remains under `content.*`. They are verification targets, not
  new English keys in these lanes.
- `presentation/lab/**`, benches, diagnostics, unknown-ID/content fallbacks and
  developer-only strings remain outside the player catalogue.
- Manifest-provided music/SFX titles, pack IDs and licence text are data, not UI
  literals. Only their fixed attribution shells are catalogued here.
- Fixture/save/plugin/asset files and `locale/zh-Hant.json` are outside I0 and
  all I1–I3 English catalogue work.

After this I0 commit, I1, I2 and I3 must treat `locale/en.json` as read-only.
I4/#127 alone may add its already-decided shade-pattern and `nameBare` fields; it
must not alter this UI inventory. Any newly discovered player-facing English
requires a separate catalogue-owner change, with a fresh verbatim/marker proof,
before call-site extraction.
