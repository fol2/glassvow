extends RefCounted
## Locale catalogue: English seed resolves, fallback never blanks, params
## interpolate, and the default `active` stand-in needs no main.

const PERSISTENCE_DETAILS: Dictionary = {
	"ui.persistence.detail.currentPilgrimageClose": "The current pilgrimage could not be closed.",
	"ui.persistence.detail.currentPilgrimageClear": "The current pilgrimage could not be cleared.",
	"ui.persistence.detail.pilgrimageStart": "The pilgrimage could not be started.",
	"ui.persistence.detail.savedPilgrimageMapUnreadable": "The saved pilgrimage map is unreadable.",
	"ui.persistence.detail.abandonmentHold": "The abandonment could not be held.",
	"ui.persistence.detail.phialChoiceHold": "The phial choice could not be held.",
	"ui.persistence.detail.chosenWaystoneHold": "The chosen waystone could not be held.",
	"ui.persistence.detail.clearedWaystoneHold": "The cleared waystone could not be held.",
	"ui.persistence.detail.eventHold": "The event could not be held.",
	"ui.persistence.detail.eventChoiceHold": "The event choice could not be held.",
	"ui.persistence.detail.treasureHold": "The treasure could not be held.",
	"ui.persistence.detail.merchantStockHold": "The merchant's stock could not be held.",
	"ui.persistence.detail.emptyLanternPurchaseHold": "The empty lantern purchase could not be held.",
	"ui.persistence.detail.purchaseHold": "The purchase could not be held.",
	"ui.persistence.detail.removedCardHold": "The removed card could not be held.",
	"ui.persistence.detail.encounterFreeze": "The encounter could not be frozen.",
	"ui.persistence.detail.standingBequestClear": "The standing bequest could not be cleared.",
	"ui.persistence.detail.fallHold": "The fall could not be held.",
	"ui.persistence.detail.shadeVictoryHold": "The shade victory could not be held.",
	"ui.persistence.detail.finalVictoryHold": "The final victory could not be held.",
	"ui.persistence.detail.victoryRewardsHold": "The victory rewards could not be held.",
	"ui.persistence.detail.claimedRewardHold": "The claimed reward could not be held.",
	"ui.persistence.detail.crownRelicsHold": "The crown relics could not be held.",
	"ui.persistence.detail.nextActHold": "The next act could not be held.",
	"ui.persistence.detail.bequestHold": "The bequest could not be held.",
	"ui.persistence.detail.vigilRecord": "The Vigil could not record this pilgrimage.",
	"ui.persistence.detail.completedRunClose": "The completed run could not be closed.",
	"ui.persistence.detail.dawnHold": "Dawn could not be held.",
	"ui.persistence.detail.dawnCursorHold": "The Dawn cursor could not be held.",
	"ui.persistence.detail.sceneCursorHold": "The scene cursor could not be held.",
	"ui.persistence.detail.sceneHold": "The scene could not be held.",
	"ui.persistence.detail.shadeDuelHold": "The shade duel could not be held.",
	"ui.persistence.detail.hollowPriceHold": "The Hollow price could not be held.",
	"ui.persistence.detail.heldHollowDestinationUnreadable": "The held Hollow destination is unreadable.",
	"ui.persistence.detail.hollowDestinationHold": "The Hollow destination could not be held.",
	"ui.persistence.detail.lamplighterGiftsHold": "The Lamplighter's gifts could not be held.",
	"ui.persistence.detail.lamplighterGiftHold": "The Lamplighter's gift could not be held.",
}

## Deliberately identical player-facing values. Technical font and licence
## names are embedded in otherwise localised credit lines, so they do not need
## an exemption here.
const ZH_HANT_ENGLISH_ALLOWLIST: Array[String] = [
	# Language selectors display each language in its own script.
	"ui.language.en",
	"ui.language.zhHant",
	# This value contains only a decorative glyph and an interpolation marker;
	# there is no English lexical copy to translate.
	"ui.end.unlock.header",
]

## Every visible Latin-script remainder is deliberate: genre/credit proper
## names, the A key, or the status catalogue's literal N magnitude token.
const ZH_HANT_LATIN_PATH_ALLOWLIST: Array[String] = [
	"ui.brand.tagline", "ui.combat.lanternSub", "ui.help.lanternBody",
	"ui.lamp.artHint", "ui.credits.bodyBrand", "ui.credits.bodyGlass",
	"ui.credits.bodyCinzel", "ui.credits.bodyAlegreya", "ui.credits.bodyNoto",
	"ui.credits.bodyEngine", "ui.credits.fontLicences", "ui.credits.footer",
	"ui.credits.musicAttribution", "ui.credits.musicAttributionCount",
	"ui.credits.sfxAttribution", "ui.credits.sfxAttributionCount", "ui.language.en",
	"content.status.beacon.desc", "content.status.dex.desc",
	"content.status.emberflow.desc", "content.status.energized.desc",
	"content.status.metallicize.desc", "content.status.nightsight.desc",
	"content.status.poison.desc", "content.status.regen.desc",
	"content.status.ritual.desc", "content.status.str.desc",
	"content.status.thorns.desc", "content.status.venomous.desc",
]


## This allowlist exists for future 顯著 or 著作 senses of 著; 裡 has no legitimate use.
const ZH_HANT_BANNED_FORM_ALLOWLIST: Array[String] = []


## #232 Tier A — the retired vertical vocabulary, banned in every player-facing
## string. Matched as substrings against the lowercased value, so "climb" also
## catches climber/climbing and "spire" would catch "inspire": a false positive
## goes on the allowlist below, which is the point — the ban stays strict and
## every exception is named. 層 is deliberately absent (Tier B: the status-stack
## measure word). Keep in step with docs/story/06-glossary.md.
const TIER_A_EN: Array[String] = [
	"spire", "climb", "ascend", "summit", "above", "upward", "stair",
]
const TIER_A_ZH: Array[String] = [
	"尖塔", "爬", "攀", "登臨", "頂點", "之上", "向上", "階梯",
]

## Tier B keeps that the substring match trips anyway.
## ui.help.combatBody — "intent above their heads" is literal physical position
## inside a scene description, not "above" as a place. zh (頭頂) trips nothing.
const TIER_A_EN_ALLOWLIST: Array[String] = ["ui.help.combatBody"]
const TIER_A_ZH_ALLOWLIST: Array[String] = []


const ZH_HANT_GLOSSARY_SAMPLES: Dictionary = {
	"ui.brand.title": "琉璃誓言",
	"ui.vigil.title": "守夜",
	"ui.pilgrimage.survey": "滾動或拖曳以巡視朝聖之路",
	"ui.embark.noVows": "路如常。未立任何誓言。",
	"ui.combat.lanternTitle": "提燈",
	"ui.lamp.artLabel": "你的提燈術",
	"content.cards.firstSpark.text": "抽 1 張牌。燃燼。",
	"ui.combat.ashesSub": "焚去的牌——每張都曾餵提燈一點餘燼",
	"ui.rose.selectedPane": "已選的餘燼琉璃窗片",
	"ui.combat.facetsTitle": "璃面",
	"ui.keywords.chip": "琢擊可直傷琉璃本身：推進碎裂，無需見血。",
	"ui.combat.shatter": "碎裂",
	"ui.combat.affixTitle": "{name} — 菁英封號",
	"ui.persistence.detail.chosenWaystoneHold": "所選引路石未能保存。",
	"content.cards.defend.name": "護光",
	"content.status.poison.name": "陰燃",
	"content.status.dex.name": "沉穩",
	"content.status.vulnerable.name": "裂痕",
	"content.status.weak.name": "黯淡",
	"content.status.frail.name": "脆裂",
	"ui.embark.vowLevel": "誓言 {level}  / {max}",
	"ui.vigil.deeds": "功績",
	"ui.lamp.boonLabel": "路上的恩賜",
	"content.aspects.duskblade.name": "暮刃",
	"content.omens.eighthOmen.name": "第八凶兆",
	"ui.end.unlock.aspect": "面向已解鎖",
	"content.variants.ownShade1.name": "墜落之影",
	"ui.reward.phialRackFullTitle": "藥瓶架已滿",
	"ui.end.unlock.relic": "遺物已解鎖",
	"ui.pilgrimage.roseWindow": "彩窗",
	"ui.rose.shardRecoveredShort": "碎片已尋回",
	"ui.dawn.unlock.lamplighter": "空燈掌燈人踏上路途。",
	"content.quests.hollowLamplighter.name": "空燈掌燈人",
	"content.status.ritual.desc": "每回合開始時獲得 N 層熾心。",
	"ui.menu.abandonConfirmBody": "這段朝聖之路將告終；守夜會留下你所得的一切。",
	"ui.menu.beginAnewBody": "新的朝聖之路開始前，目前這段旅程會記作放棄。",
	"ui.map.unlitBody": "此處所藏仍是未知——但首次點亮會獲得金幣賞金。",
	"ui.omen.prefix": "凶兆——",
	"ui.event.chooseCardSub": "仍有一頁泛着微光。",
	"ui.help.vigilBody": "一切皆不白費。每段朝聖之路開始時，<b>掌燈人</b>贈予恩賜並讓你選擇提燈術。倒下時，將一事刻入石中——一座<b>紀念碑</b>，下一段旅程可在同一幕取回。每次碎裂、燃燼與擊殺皆累積畢生<b>功績</b>，解鎖新牌、遺物，與第二面向——<b>灰衛</b>。抵達破曉一次後，<b>誓言</b>開啟：一條可選的嚴酷難度之梯，留給願意踏上更殘酷朝聖之路的人。",
	"ui.help.glassBody": "每個生物皆是琉璃，生命條下有一列<b>璃面</b>。攻擊若未被護光擋下而見血，便會琢擊一格璃面（重型卡牌會琢擊更多格）。填滿量表，琉璃便會<b>碎裂</b>：它會失去下一次行動、陷入裂痕，並將<b>餘燼</b>灑入你的提燈。把握碎裂時機，擋下你無法承受的一擊。",
	"ui.help.lanternBody": "餘燼驅動你的<b>提燈術</b>——按 <b>A</b> 施展，每回合一次。將任意卡牌拖到提燈上即可<b>燃燼</b>：牌被焚去，提燈得 1 餘燼。每回合一次；詛咒拒火。",
	"ui.combat.facetsBody": "每個生物皆是琉璃。攻擊造成未被格擋的傷害時，會琢擊一格璃面；填滿量表，琉璃便會[b]碎裂[/b]——它會失去下一次行動、陷入裂痕，並將餘燼灑入你的提燈。",
	"content.quests.hollowLamplighter.meetings.0.ask": "你的提燈太吵。把它接下來收集的三點餘燼交給我。",
	"ui.pilgrimage.notNow": "暫時不要",
	"content.acts.0.bossName": "根脈之心",
	"content.acts.1.bossName": "利維坦之喉",
	"content.acts.2.bossName": "永恆君王",
	"content.enemies.rootheart.name": "根脈之心",
	"content.enemies.leviathan.name": "利維坦之喉",
	"content.enemies.sovereign.name": "永恆君王",
	"content.enemies.shade.name": "影",
	"ui.rose.openLabel": "打開餘燼琉璃彩窗",
	"content.cards.flurry.name": "碎屑風暴",
	"content.cards.shardstorm.name": "碎片風暴",
	"content.cards.leechBlade.name": "渴血碎片",
	"content.cards.twinFangs.name": "雙生碎片",
	"content.whispers.8": "枯瘦的掌燈人記得你未走的路。",
	"ui.combat.lanternArtTitle": "提燈術——{name}",
	"ui.combat.staggeredBody": "琉璃已碎——此生物在重新接合前失去下一次行動。",
	"ui.combat.encounterHeader": "{kind}  ·  第 {act} 幕",
	"ui.dawn.inputHint": "點擊或按空白鍵繼續  ·  長按跳過",
	"ui.combat.energyAria": "能量",
	"content.cards.burn.name": "燼屑",
	"content.cards.hex.name": "咒印",
	"ui.combat.staggered": "踉蹌",
	"ui.keywords.unplayable": "此牌無法打出。",
}

## Runtime keyword surfaces are catalogue data, but their semantic keys are
## stable. Keep every alias exact in both languages: a drift here can leave an
## authored card word unstyled or send its tooltip to the wrong glossary body.
const KEYWORD_TERM_SURFACES: Dictionary = {
	"vulnerable": {"en": ["Cracked"], "zh-Hant": ["裂痕"]},
	"weak": {"en": ["Dimmed"], "zh-Hant": ["黯淡"]},
	"frail": {"en": ["Brittle"], "zh-Hant": ["脆裂"]},
	"poison": {"en": ["Smolder"], "zh-Hant": ["陰燃"]},
	"str": {"en": ["Fervor"], "zh-Hant": ["熾心"]},
	"dex": {"en": ["Poise"], "zh-Hant": ["沉穩"]},
	"kindle": {"en": ["Kindle"], "zh-Hant": ["燃燼"]},
	"ward": {"en": ["Ward"], "zh-Hant": ["護光"]},
	"energy": {"en": ["Energy"], "zh-Hant": ["能量"]},
	"ember": {"en": ["Embers", "Ember"], "zh-Hant": ["餘燼", "餘燼"]},
	"chip": {"en": ["Chip"], "zh-Hant": ["琢擊"]},
	"facetDesc": {
		"en": ["Facets", "Facet", "Shatters", "Shatter"],
		"zh-Hant": ["璃面", "璃面", "碎裂", "碎裂"],
	},
	"staggered": {"en": ["Staggered"], "zh-Hant": ["踉蹌"]},
	"unplayable": {"en": ["Unplayable"], "zh-Hant": ["無法打出"]},
	"shard": {"en": ["Shard"], "zh-Hant": ["碎片"]},
	"hex": {"en": ["Hex"], "zh-Hant": ["咒印"]},
	"cinder": {"en": ["Cinder"], "zh-Hant": ["燼屑"]},
}


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("locale: %s" % what)


static func run(fails: Array[String]) -> void:
	_english_seed(fails)
	_derived_display_seed(fails)
	_fallback_chain(fails)
	_params(fails)
	_content_and_whisper(fails)
	_unknown_language_rejected(fails)
	_default_active(fails)
	_remaining_run_screen_call_sites(fails)
	_dialog_shells(fails)
	_persistence_calls_and_shell(fails)
	_zh_hant_catalogue_contract(fails)
	_retired_vertical_vocabulary(fails)
	_title_wordmark_locale(fails)


static func _english_seed(fails: Array[String]) -> void:
	var locale: Locale = Locale.new()
	if locale.code != Locale.CODE_EN:
		fails.append("locale: default language is not en")
	if locale.t("ui.brand.title") != "GLASSVOW":
		fails.append("locale: ui.brand.title missing from en seed")
	if locale.t("ui.embark.title") != "THE PILGRIMAGE BEGINS":
		fails.append("locale: ui.embark.title missing from en seed")
	if locale.t("ui.keywords.kindle") == "ui.keywords.kindle":
		fails.append("locale: ui.keywords.kindle missing from en seed")
	if locale.t("ui.pilgrimage.survey") != "SCROLL OR DRAG TO SURVEY THE PILGRIMAGE":
		fails.append("locale: Glassvow pilgrimage keys missing from en seed")
	if locale.t("ui.embark.vowLevel", {"level": "I", "max": "III"}) != "VOW I  / III":
		fails.append("locale: ui.embark.vowLevel missing or mistyped")
	if locale.t("ui.settings.ledger") != "The Ledger":
		fails.append("locale: ui.settings.ledger missing from en seed")
	if locale.t("ui.credits.bodyGlass") != "Parallel-ported from roguecardv2.":
		fails.append("locale: player credits expose benchmark build identity")
	if locale.content("cards", "strike", "name") != "Edge":
		fails.append("locale: content.cards.strike.name missing from en seed")
	if not locale.content("cards", "strike", "text").contains("@6@"):
		fails.append("locale: card text lost @n@ markers")


## Mechanics IDs that are rendered as labels need catalogue-owned display copy.
## The English values deliberately match the current transforms byte for byte;
## I2 and the residual presentation follow-up consume these leaves separately.
static func _derived_display_seed(fails: Array[String]) -> void:
	var locale: Locale = Locale.new()
	var expected: Dictionary = {
		"ui.combat.encounterKind.monster": "Monster",
		"ui.combat.encounterKind.elite": "Elite",
		"ui.combat.encounterKind.boss": "Boss",
		"ui.card.type.attack": "attack",
		"ui.card.type.skill": "skill",
		"ui.card.type.power": "power",
		"ui.card.type.status": "status",
		"ui.card.type.curse": "curse",
		"ui.rarity.starter": "starter",
		"ui.rarity.common": "common",
		"ui.rarity.uncommon": "uncommon",
		"ui.rarity.rare": "rare",
		"ui.rarity.special": "special",
		"ui.rarity.boss": "boss",
	}
	for key: String in expected:
		if locale.t(key) != expected[key]:
			fails.append("locale derived display: %s is missing or mistyped" % key)


static func _fallback_chain(fails: Array[String]) -> void:
	var locale: Locale = Locale.new()
	var missing: String = locale.t("ui.does.not.exist")
	if missing != "ui.does.not.exist":
		fails.append("locale: missing key did not fall back to the key itself")
	# A bare catalogue with no en file still must not blank.
	var empty: Locale = Locale.new(Locale.CODE_EN, "res://locale/__missing__.json")
	if empty.t("ui.brand.title") != "ui.brand.title":
		fails.append("locale: empty catalogue blanked instead of returning the key")
	if empty.t("ui.brand.title") == "":
		fails.append("locale: empty catalogue returned a blank string")


static func _params(fails: Array[String]) -> void:
	var locale: Locale = Locale.new()
	var line: String = locale.t("ui.hud.actFloor", {"act": 2, "floor": 7})
	if line != "Act 2 · Waystone 7":
		fails.append("locale: ui.hud.actFloor params failed (%s)" % line)


static func _content_and_whisper(fails: Array[String]) -> void:
	var locale: Locale = Locale.new()
	if locale.whisper(0) != "There is a colour the Spire refuses to name.":
		fails.append("locale: whisper 0 did not resolve")
	if locale.whisper(23) != "The climb continues.":
		fails.append("locale: whisper 23 did not resolve")
	if locale.whisper(99) != "content.whispers.99":
		fails.append("locale: out-of-range whisper did not fall back to the key")
	var status: String = locale.content("status", "poison", "name")
	if status != "Smolder":
		fails.append("locale: status.poison.name expected Smolder, got %s" % status)


static func _unknown_language_rejected(fails: Array[String]) -> void:
	var locale: Locale = Locale.new()
	if locale.set_language(&"xx-NOPE"):
		fails.append("locale: unknown language was accepted")
	if locale.code != Locale.CODE_EN:
		fails.append("locale: failed set_language drifted the code")
	if locale.t("ui.brand.title") != "GLASSVOW":
		fails.append("locale: failed set_language lost the en catalogue")


static func _default_active(fails: Array[String]) -> void:
	if Locale.active == null:
		fails.append("locale: static active is null")
	if Locale.active.t("ui.common.continue") != "Continue":
		fails.append("locale: static active does not serve English without main")


## Wave 4 I1 owns these exact presentation seams. Source assertions are
## deliberate here: an English runtime cannot distinguish a raw literal from
## the English catalogue value, while a changed locale must traverse every
## call site below.
static func _remaining_run_screen_call_sites(fails: Array[String]) -> void:
	var seams: Dictionary = {
		"res://presentation/run/credits_screen.gd": {
			"_init": ["ui.credits.title", "ui.credits.headingBrand",
				"ui.credits.bodyBrand", "ui.credits.headingGlass",
				"ui.credits.bodyGlass", "ui.credits.headingMusic",
				"ui.credits.headingSound", "ui.credits.headingType",
				"ui.credits.bodyCinzel", "ui.credits.bodyAlegreya",
				"ui.credits.bodyNoto", "ui.credits.headingEngine",
				"ui.credits.bodyEngine", "ui.credits.footer", "ui.credits.close"],
			"_add_music_attribution": ["ui.credits.musicAttribution",
				"ui.credits.musicAttributionCount"],
			"_add_music_rows": ["ui.credits.musicTracklistFallback"],
			"_add_sfx_rows": ["ui.credits.sfxAttribution",
				"ui.credits.sfxAttributionCount", "ui.credits.themeLine"],
			"_add_licence_fold": ["ui.credits.engineLicences"],
			"_add_font_licence_fold": ["ui.credits.fontLicences"],
			"_build_licence": ["ui.credits.components", "ui.credits.licenceTexts"],
		},
		"res://presentation/run/rose_window_view.gd": {
			"_pane_copy": ["ui.rose.shardRecoveredStack"],
			"_detail_copy": ["ui.rose.shardRecoveredStack", "ui.rose.paneDark"],
			"_pane_accessible_name": ["ui.rose.dormantPane", "ui.rose.unknownPane"],
			"_add_replay": ["ui.rose.replayUnsealing"],
		},
		"res://presentation/run/choice_screen.gd": {
			"_add_title_rose": ["ui.rose.openLabel"],
		},
		"res://presentation/run/dawn_screen.gd": {
			"_build": ["ui.dawn.inputHint"],
		},
		"res://presentation/run/lamplighter_screen.gd": {
			"_build": ["ui.lamp.title", "ui.lamp.sub", "ui.lamp.boonLabel",
				"ui.lamp.artLabel", "ui.lamp.artHint", "ui.menu.chooseBoon"],
			"_refresh": ["ui.menu.lightTheWay", "ui.menu.chooseBoon"],
		},
		"res://presentation/run/run_hud.gd": {
			"refresh": ["ui.hud.hpFraction"],
			"_rebuild_right": ["ui.hud.viewDeck", "ui.hud.menu"],
			"_potion_seat": ["ui.hud.emptyPhial"],
			"_location_text": ["ui.hud.location"],
		},
		"res://presentation/map/world_map_screen.gd": {
			"_act_line": ["ui.pilgrimage.awaits"],
		},
		"res://application/main.gd": {
			"_show_run_deck": ["ui.hud.deckOverlayTitle", "ui.hud.deckOverlayCount",
				"ui.menu.close"],
			"_show_potion_menu": ["ui.common.use", "ui.hud.tossPotion", "ui.menu.close"],
			"_bequest_choices": ["ui.end.bequestNote.relic", "ui.end.bequestNote.card",
				"ui.end.bequestNote.gold", "ui.end.bequestNote.goldCache"],
			"_on_terminal_commit": ["ui.dawn.shardGrantCopy", "ui.dawn.memoryTitle",
				"ui.dawn.memoryBody"],
			"_unlock_dawn_copy": ["ui.dawn.unlock.lamplighter", "ui.dawn.unlock.phials",
				"ui.dawn.unlock.omens", "ui.dawn.unlock.pool",
				"ui.dawn.unlock.emberglass", "ui.dawn.unlock.act4"],
			"_show_monument": ["ui.end.monument.body", "ui.end.monument.bodyWithBequest",
				"ui.end.monument.title", "ui.end.monument.claim", "ui.end.monument.leave"],
		},
	}
	for path_v: Variant in seams:
		var path: String = str(path_v)
		var source: String = FileAccess.get_file_as_string(path)
		var functions: Dictionary = seams[path_v]
		for function_v: Variant in functions:
			var function_name: String = str(function_v)
			var body: String = _function_body(source, function_name)
			for key_v: Variant in functions[function_v]:
				var key: String = str(key_v)
				if not body.contains('Locale.active.t("%s"' % key):
					fails.append("locale I1 call site: %s:%s misses %s" % [
						path, function_name, key])
	var map_source: String = FileAccess.get_file_as_string(
		"res://presentation/map/world_map_screen.gd")
	var node_caption: String = _function_body(map_source, "_node_caption")
	if not node_caption.contains('var node_key: String = "ui.map.node.%s"') \
			or not node_caption.contains("Locale.active.t(node_key)"):
		fails.append("locale I1 call site: map node captions bypass their dynamic locale key")


static func _function_body(source: String, name: String) -> String:
	var start: int = source.find("func %s(" % name)
	if start < 0:
		return ""
	var finish: int = source.find("\nfunc ", start + 1)
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)


static func _dialog_shells(fails: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string("res://application/main.gd")
	var expected_keys: Array[String] = [
		"ui.menu.beginAnew", "ui.menu.beginAnewBody", "ui.menu.keepClimbing",
		"ui.menu.leaveSpireTitle", "ui.menu.leaveSpireBody",
		"ui.common.leave", "ui.common.stay", "ui.menu.abandonConfirmTitle",
		"ui.menu.abandonConfirmBody", "ui.menu.abandonRun",
	]
	for key: String in expected_keys:
		_check(fails, source.contains('Locale.active.t("%s")' % key),
			"Main dialog seam does not consume %s" % key)

	var previous: Locale = Locale.active
	Locale.active = Locale.new(Locale.CODE_EN)
	var main: Main = Main.new()
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._transitions = TransitionLayer.new()
	main.add_child(main._transitions)
	main._confirm_abandon()
	var abandon: ChoiceScreen = main._modal as ChoiceScreen
	_check(fails, abandon != null, "abandon confirmation did not open as an overlay")
	if abandon != null:
		_check_dialog(fails, abandon, "ABANDON RUN?",
			"This pilgrimage will end. The Vigil will keep what was earned.",
			["Abandon Run", "Stay on the Road"], "no", "Abandon Run", "abandon")
	main._close_overlay()
	main._show_run_menu()
	var menu: RunMenuPanel = main._modal as RunMenuPanel
	_check(fails, menu != null, "run menu did not open")
	if menu != null:
		menu.quit_requested.emit()
	var leave: ChoiceScreen = main._choice_screen as ChoiceScreen
	_check(fails, leave != null, "Leave Spire confirmation did not open")
	if leave != null:
		_check_dialog(fails, leave, "LEAVE THE ROAD?", "The lantern keeps your place.",
			["Leave", "Stay"], "no", "Leave", "leave")
	Locale.active = previous


static func _check_dialog(fails: Array[String], screen: ChoiceScreen,
		title: String, body: String, actions: Array[String], cancel: String,
		first: String, label: String) -> void:
	var labels: Array[String] = []
	for node: Node in screen.find_children("", "Label", true, false):
		var text: String = str((node as Label).text)
		if not text.is_empty():
			labels.append(text)
	var buttons: Array[String] = []
	for node: Node in screen.find_children("", "Button", true, false):
		buttons.append(str((node as Button).text))
	_check(fails, labels.has(title), "%s title changed" % label)
	_check(fails, labels.has(body), "%s body changed" % label)
	_check(fails, buttons == actions, "%s action order changed: %s" % [label, buttons])
	_check(fails, screen._cancel_id == cancel, "%s cancel action changed" % label)
	_check(fails, screen._first_button != null and screen._first_button.text == first,
		"%s initial focus target changed" % label)


static func _persistence_calls_and_shell(fails: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string("res://application/main.gd")
	var call_keys: Array[String] = []
	var marker: String = '_show_save_error("'
	var at: int = source.find(marker)
	while at >= 0:
		var start: int = at + marker.length()
		var finish: int = source.find('")', start)
		if finish < 0:
			break
		call_keys.append(source.substr(start, finish - start))
		at = source.find(marker, finish + 2)
	_check(fails, call_keys.size() == 43,
		"expected 43 save-error call sites, found %d" % call_keys.size())
	var distinct: Array[String] = []
	var locale: Locale = Locale.new(Locale.CODE_EN)
	for key: String in call_keys:
		_check(fails, PERSISTENCE_DETAILS.has(key), "save-error call uses non-frozen key %s" % key)
		if PERSISTENCE_DETAILS.has(key):
			_check(fails, locale.t(key) == str(PERSISTENCE_DETAILS[key]),
				"save-error key %s does not preserve its English detail" % key)
		if not distinct.has(key):
			distinct.append(key)
	_check(fails, distinct.size() == 37,
		"expected 37 distinct save-error details, found %d" % distinct.size())
	for key: String in PERSISTENCE_DETAILS:
		_check(fails, distinct.has(key), "save-error details do not cover %s" % key)

	var previous: Locale = Locale.active
	Locale.active = Locale.new(Locale.CODE_EN)
	var main: Main = Main.new()
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._transitions = TransitionLayer.new()
	main.add_child(main._transitions)
	main._show_save_error("ui.persistence.detail.eventHold")
	var shell: ChoiceScreen = main._choice_screen as ChoiceScreen
	_check(fails, shell != null, "save-error shell did not open")
	if shell != null:
		_check_dialog(fails, shell, "THE LIGHT WOULD NOT HOLD",
			"The event could not be held.\nNo progress was discarded.",
			["Retry", "Title"], "", "Retry", "save error")
		_check(fails, not shell._has_cancel, "save-error shell gained a cancel action")
	Locale.active = previous


## P7.6's authored catalogue is a strict peer of English: the same keys, no
## accidental blanks, and no English seed copy left behind except the named
## language label. Markers are compared as multisets, not mere containment, so
## duplicate parameters and paired rich-text tags cannot disappear unnoticed.
##
## The closing scan holds the house orthography (#177): it bans only the
## non-house forms, because 著 stays legal in the 顯著 / 著作 senses, so the
## ban can never run in the opposite direction.
static func _zh_hant_catalogue_contract(fails: Array[String]) -> void:
	var en: Dictionary = _read_catalogue("res://locale/en.json", fails)
	var zh: Dictionary = _read_catalogue("res://locale/zh-Hant.json", fails)
	if en.is_empty() or zh.is_empty():
		return
	var en_leaves: Dictionary = {}
	var zh_leaves: Dictionary = {}
	_flatten_strings(en, "", en_leaves)
	_flatten_strings(zh, "", zh_leaves)
	var missing: Array[String] = []
	var extra: Array[String] = []
	var blank: Array[String] = []
	var untranslated: Array[String] = []
	var marker_drift: Array[String] = []
	for key_v: Variant in en_leaves:
		var key: String = str(key_v)
		if not zh_leaves.has(key):
			missing.append(key)
			continue
		var en_value: String = str(en_leaves[key])
		var zh_value: String = str(zh_leaves[key])
		if not en_value.is_empty() and zh_value.strip_edges().is_empty():
			blank.append(key)
		if en_value == zh_value and not en_value.is_empty() \
				and not ZH_HANT_ENGLISH_ALLOWLIST.has(key):
			untranslated.append(key)
		if _marker_multiset(en_value) != _marker_multiset(zh_value):
			marker_drift.append(key)
	for key_v: Variant in zh_leaves:
		var key: String = str(key_v)
		if not en_leaves.has(key):
			extra.append(key)
	missing.sort()
	extra.sort()
	blank.sort()
	untranslated.sort()
	marker_drift.sort()
	_check(fails, missing.is_empty(), "zh-Hant missing %d keys: %s" % [
		missing.size(), _first_paths(missing)])
	_check(fails, extra.is_empty(), "zh-Hant has %d extra keys: %s" % [
		extra.size(), _first_paths(extra)])
	_check(fails, blank.is_empty(), "zh-Hant has %d unexpected blanks: %s" % [
		blank.size(), _first_paths(blank)])
	_check(fails, untranslated.is_empty(), "zh-Hant leaves %d English values: %s" % [
		untranslated.size(), _first_paths(untranslated)])
	_check(fails, marker_drift.is_empty(), "zh-Hant marker drift in %d values: %s" % [
		marker_drift.size(), _first_paths(marker_drift)])
	for key_v: Variant in ZH_HANT_ENGLISH_ALLOWLIST:
		var key: String = str(key_v)
		_check(fails, en_leaves.has(key) and zh_leaves.has(key)
			and str(en_leaves[key]) == str(zh_leaves[key]),
			"zh-Hant English allowlist entry is stale: %s" % key)
	for key_v: Variant in ZH_HANT_GLOSSARY_SAMPLES:
		var key: String = str(key_v)
		_check(fails, str(zh_leaves.get(key, "")) == str(ZH_HANT_GLOSSARY_SAMPLES[key]),
			"zh-Hant glossary drift at %s" % key)
	_keyword_term_contract(fails, en, zh)
	var card_names: Dictionary = {}
	var cards: Dictionary = zh.get("content", {}).get("cards", {})
	for card_id_v: Variant in cards:
		var card_id: String = str(card_id_v)
		var card: Dictionary = cards[card_id]
		var card_name: String = str(card.get("name", ""))
		if card_names.has(card_name):
			fails.append("locale: zh-Hant card name collision: %s (%s, %s)" % [
				card_name, card_names[card_name], card_id])
		else:
			card_names[card_name] = card_id
	var latin_paths: Array[String] = []
	for key_v: Variant in zh_leaves:
		var key: String = str(key_v)
		if _visible_ascii(str(zh_leaves[key])):
			latin_paths.append(key)
	latin_paths.sort()
	var expected_latin: Array[String] = ZH_HANT_LATIN_PATH_ALLOWLIST.duplicate()
	expected_latin.sort()
	_check(fails, latin_paths == expected_latin,
		"zh-Hant visible Latin allowlist drift: %s" % _first_paths(latin_paths))
	var banned_form_paths: Array[String] = []
	for key_v: Variant in zh_leaves:
		var key: String = str(key_v)
		var value: String = str(zh_leaves[key])
		if value.contains("著") or value.contains("裡"):
			banned_form_paths.append(key)
	banned_form_paths.sort()
	var expected_banned_forms: Array[String] = ZH_HANT_BANNED_FORM_ALLOWLIST.duplicate()
	expected_banned_forms.sort()
	_check(fails, banned_form_paths == expected_banned_forms,
		"zh-Hant banned-form allowlist drift (replace 著 with 着 and 裡 with 裏): %s" % _first_paths(banned_form_paths))


## The Tier A ban from #232, made mechanical so the next copy edit cannot quietly
## re-authorise the tower. Scope is `ui.*` only: `content.*` still carries the
## retired vocabulary until #301's rewrite lands, and gating it now would fail on
## copy this ticket does not own. Tier B look-alikes that are correct to keep get
## an allowlist row rather than a weaker pattern — see docs/story/06-glossary.md.
static func _retired_vertical_vocabulary(fails: Array[String]) -> void:
	var en: Dictionary = _read_catalogue("res://locale/en.json", fails)
	var zh: Dictionary = _read_catalogue("res://locale/zh-Hant.json", fails)
	if en.is_empty() or zh.is_empty():
		return
	_tier_a_pass(fails, en, TIER_A_EN, TIER_A_EN_ALLOWLIST, "en")
	_tier_a_pass(fails, zh, TIER_A_ZH, TIER_A_ZH_ALLOWLIST, "zh-Hant")


static func _tier_a_pass(fails: Array[String], catalogue: Dictionary,
		banned: Array[String], allowlist: Array[String], language: String) -> void:
	var leaves: Dictionary = {}
	_flatten_strings(catalogue, "", leaves)
	var hits: Array[String] = []
	for key_v: Variant in leaves:
		var key: String = str(key_v)
		if not key.begins_with("ui."):
			continue
		var value: String = str(leaves[key]).to_lower()
		for term: String in banned:
			if value.contains(term):
				hits.append(key)
				break
	hits.sort()
	var expected: Array[String] = allowlist.duplicate()
	expected.sort()
	_check(fails, hits == expected,
		"%s ui.* carries retired vertical vocabulary (#232 Tier A): %s" % [
			language, _first_paths(hits)])


static func _keyword_term_contract(fails: Array[String], en: Dictionary,
		zh: Dictionary) -> void:
	var en_terms: Dictionary = en.get("ui", {}).get("keywords", {}).get("terms", {})
	var zh_terms: Dictionary = zh.get("ui", {}).get("keywords", {}).get("terms", {})
	_check(fails, en_terms.size() == KEYWORD_TERM_SURFACES.size(),
		"English keyword-term semantic set drifted")
	_check(fails, zh_terms.size() == KEYWORD_TERM_SURFACES.size(),
		"zh-Hant keyword-term semantic set drifted")
	for key_v: Variant in KEYWORD_TERM_SURFACES:
		var key: String = str(key_v)
		var expected: Dictionary = KEYWORD_TERM_SURFACES[key_v]
		var en_matches: bool = en_terms.get(key, []) == expected["en"]
		var zh_matches: bool = zh_terms.get(key, []) == expected["zh-Hant"]
		_check(fails, en_matches,
			"English keyword-term drift at %s" % key)
		_check(fails, zh_matches,
			"zh-Hant keyword-term drift at %s" % key)


static func _read_catalogue(path: String, fails: Array[String]) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		fails.append("locale: could not parse catalogue %s" % path)
		return {}
	return parsed


static func _flatten_strings(value: Variant, path: String, out: Dictionary) -> void:
	if typeof(value) == TYPE_STRING:
		out[path] = value
	elif typeof(value) == TYPE_DICTIONARY:
		var table: Dictionary = value
		for key_v: Variant in table:
			var key: String = str(key_v)
			_flatten_strings(table[key_v], key if path.is_empty() else "%s.%s" % [path, key], out)
	elif typeof(value) == TYPE_ARRAY:
		var rows: Array = value
		for index: int in range(rows.size()):
			_flatten_strings(rows[index], str(index) if path.is_empty()
				else "%s.%d" % [path, index], out)


static func _marker_multiset(value: String) -> Array[String]:
	var pattern: RegEx = RegEx.new()
	pattern.compile("(@[^@]+@|#[^#]+#|\\{[^{}]+\\}|<[^>]+>|\\[[^]\\n]+\\])")
	var markers: Array[String] = []
	for found: RegExMatch in pattern.search_all(value):
		markers.append(found.get_string())
	markers.sort()
	return markers


static func _visible_ascii(value: String) -> bool:
	var structural: RegEx = RegEx.new()
	structural.compile("(@[^@]+@|#[^#]+#|\\{[^{}]+\\}|<[^>]+>|\\[[^]\\n]+\\])")
	var words: RegEx = RegEx.new()
	words.compile("[A-Za-z]")
	return words.search(structural.sub(value, "", true)) != null


static func _first_paths(paths: Array[String]) -> String:
	var shown: Array[String] = []
	for index: int in range(mini(paths.size(), 8)):
		shown.append(paths[index])
	return ", ".join(shown)


static func _title_wordmark_locale(fails: Array[String]) -> void:
	var context: Dictionary = {"variant": "title"}
	var en: ChoiceScreen = ChoiceScreen.new("GLASSVOW", "", [], context)
	_check(fails, en._wordmark != null and en._wordmark.visible,
		"English title no longer uses the exact authored raster")
	_check(fails, en.get("_wordmark_label") == null,
		"English title gained a duplicate text wordmark")
	en.free()
	for shape: StringName in [&"pad-landscape", &"phone-portrait"]:
		var zh_context: Dictionary = {"variant": "title", "shape": shape}
		var zh: ChoiceScreen = ChoiceScreen.new("琉璃誓言", "", [], zh_context)
		zh.set_anchors_preset(Control.PRESET_TOP_LEFT)
		zh.size = Vector2(StageShape.REFERENCES[shape])
		zh._fit_title()
		# zh-Hant has its own authored raster, cut in the same stained glass
		# as the English wordmark (docs/art-ledger.md) — no text fallback.
		_check(fails, zh._wordmark != null and zh._wordmark.visible
			and zh._wordmark.texture == load(ChoiceScreen.TITLE_WORDMARK_ZH),
			"zh-Hant title does not paint its authored raster at %s" % shape)
		_check(fails, zh.get("_wordmark_label") == null,
			"zh-Hant title gained a duplicate text wordmark at %s" % shape)
		zh.free()
	# Any locale WITHOUT an authored raster still paints its catalogue title
	# through the display-face fallback chain.
	var other: ChoiceScreen = ChoiceScreen.new("GLASVOGT", "", [],
		{"variant": "title", "shape": &"pad-landscape"})
	other.set_anchors_preset(Control.PRESET_TOP_LEFT)
	other.size = Vector2(StageShape.REFERENCES[&"pad-landscape"])
	other._fit_title()
	var label_v: Variant = other.get("_wordmark_label")
	var label: Label = label_v if label_v is Label else null
	_check(fails, other._wordmark != null and not other._wordmark.visible,
		"rasterless locale title still paints the English raster")
	_check(fails, label != null and label.text == "GLASVOGT",
		"rasterless locale title does not paint its catalogue wordmark")
	if label != null:
		var font: Font = label.get_theme_font("font")
		_check(fails, font != null and font.has_char("誓".unicode_at(0)),
			"rasterless locale wordmark cannot shape representative glyph 誓")
	other.free()
