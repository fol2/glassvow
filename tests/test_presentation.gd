extends RefCounted
## M5a smoke: the combat screen plays a real encounter headless through the
## instant sequencer (no suspension), exercising the same input paths the
## player uses — new_run, start_encounter sync, targeted play, end turn.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_presentation: %s" % what)


static func run(fails: Array[String]) -> void:
	# The bundled UI font must shape the title glyphs (琉璃誓言) — guards a
	# broken font import that headless runs would otherwise never notice.
	var ui_font: FontFile = load("res://assets/fonts/NotoSansTC.ttf") as FontFile
	_check(fails, ui_font != null, "NotoSansTC.ttf imports as a FontFile")
	if ui_font != null:
		for ch: String in ["琉", "璃", "誓", "言"]:
			_check(fails, ui_font.has_char(ch.unicode_at(0)), "font has glyph %s" % ch)
	var ui_theme: Theme = GlassStyle.theme()
	_check(fails, ui_theme.default_font == GlassStyle.face(GlassStyle.NOTO_SANS_TC),
		"runtime theme supplies NotoSansTC as the default UI font")
	if ui_theme.default_font != null:
		for ch: String in ["琉", "璃", "誓", "言"]:
			_check(fails, ui_theme.default_font.has_char(ch.unicode_at(0)),
				"runtime theme default has glyph %s" % ch)
	# Display faces must fall back to NotoSansTC so 繁中 never tofu.
	var cinzel: Font = GlassStyle.face(GlassStyle.CINZEL_500)
	var alegreya: Font = GlassStyle.face(GlassStyle.ALEGREYA_400)
	_check(fails, cinzel != null and alegreya != null, "display faces load through face()")
	if cinzel != null:
		for ch: String in ["琉", "璃"]:
			_check(fails, cinzel.has_char(ch.unicode_at(0)),
				"Cinzel+Noto fallback has glyph %s" % ch)
	if alegreya != null:
		for ch: String in ["誓", "言"]:
			_check(fails, alegreya.has_char(ch.unicode_at(0)),
				"Alegreya+Noto fallback has glyph %s" % ch)
	# zh-Hant catalogue resolves brand + a whisper.
	var zh: Locale = Locale.new(Locale.CODE_ZH_HANT)
	_check(fails, zh.set_language(Locale.CODE_ZH_HANT) or zh.code == Locale.CODE_ZH_HANT,
		"zh-Hant catalogue loads")
	_check(fails, zh.t("ui.brand.title") == "琉璃誓言", "zh-Hant brand title")
	_check(fails, zh.whisper(0).begins_with("有一種顏色"), "zh-Hant whisper 0")
	_check(fails, zh.content("cards", "strike", "name") == "刃鋒", "zh-Hant card name")
	_check(fails, zh.t("ui.credits.bodyGlass") == "平行移植自 roguecardv2。",
		"zh-Hant player credits omit benchmark build identity")
	# Markers survive translation.
	_check(fails, zh.content("cards", "strike", "text").contains("@6@"),
		"zh-Hant card text keeps @n@ markers")
	var credits: CreditsScreen = CreditsScreen.new()
	var player_credit_text: String = ""
	for node: Node in credits.find_children("*", "Label", true, false):
		if node is Label:
			player_credit_text += "\n" + node.text
	_check(fails, not player_credit_text.contains("6e06911")
		and not player_credit_text.contains("0.5.0+"),
		"player credits omit benchmark build identity")
	credits.free()

	# The title paints on frame 0, before its first process tick: measured with
	# the layout already resolved (size 1180x820) and `_focal` still at its 1.0
	# sentinel, so that frame drew at a garbage projection. `_ready` is what
	# initialises it. Guarded by `has_method` because `_ready` is a virtual —
	# calling it directly once the override is gone raises "nonexistent
	# function", which aborts the rest of this file instead of failing it.
	var title_world: TitleWorld = TitleWorld.new()
	title_world.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title_world.size = Vector2(1180.0, 820.0)
	var title_ready: bool = title_world.has_method("_ready")
	if title_ready:
		title_world._ready()
		title_ready = is_equal_approx(title_world._focal,
			(title_world.size.y * 0.5) / tan(deg_to_rad(TitleWorld.FOV_DEG * 0.5)))
	_check(fails, title_ready, "title projection is ready before its first paint")
	title_world.free()

	var content: ContentDB = ContentDB.load_slice()
	_derived_display_labels(fails, content)

	# ---- new_run builds a fresh core-only profile from content.player
	var rs: RunState = RunState.new_run(content, 12345)
	_check(fails, rs.player.deck.size() == 10, "new_run deck has 10 cards")
	_check(fails, rs.player.hp == 72 and rs.player.max_hp == 72, "new_run hp 72/72")
	_check(fails, rs.player.gold == 99, "new_run gold 99")
	_check(fails, rs.player.energy_max == 3, "new_run energy 3")
	_check(fails, rs.player.relics.size() == 1 and rs.player.relics[0] == "emberHeart", "new_run start relic")
	_check(fails, rs.player.potions.size() == 3, "new_run 3 empty potion slots")
	_check(fails, not rs.reveals_all and rs.reveals.is_empty(), "new_run fresh reveals []")
	_check(fails, rs.omens.size() == 1 and rs.omens[0] == null, "new_run act-0 omen null")
	_check(fails, rs.uid == 11, "new_run uid cursor after deck")

	# ---- screen drives a real fight headless (instant drain)
	var game: GlassvowGame = GlassvowGame.new(content, rs)
	var composition: Main = Main.new()
	_check(fails, composition.theme != null
		and composition.theme.default_font == GlassStyle.face(GlassStyle.NOTO_SANS_TC),
		"shipping Main owns the runtime default UI font")
	var inherited_label: Label = Label.new()
	composition.add_child(inherited_label)
	var inherited_font: Font = inherited_label.get_theme_default_font()
	_check(fails, inherited_font != null and inherited_font.has_char("琉".unicode_at(0)),
		"Main descendant resolves the runtime NotoSansTC default")
	composition.game = game
	rs.pending_quest_id = "paleOnes"
	_check(fails, composition._combat_music("normal") == &"paleOnes",
		"quest combat music overrides the act")
	rs.pending_quest_id = null
	rs.omens[0] = "eighthOmen"
	_check(fails, composition._combat_music("normal") == &"eighthOmen"
		and composition._combat_music("boss") == &"act1Boss",
		"Eighth Omen music excludes bosses")
	rs.omens[0] = null
	var phone_reward_padding: float = RewardScreen._deep_padding_for(366.0, 113.0, 8.0, 3)
	_check(fails, is_equal_approx(phone_reward_padding, 3.5)
		and RewardScreen._panel_body_width(366.0, phone_reward_padding) >= 355.0,
		"phone reward pane contains three benchmark-sized cards")
	composition.free()
	var screen: CombatScreen = CombatScreen.new(game)
	screen.seq.instant = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	_layout_identity(fails, screen)
	_chrome_identity(fails)

	screen.start_encounter(["sporeling", "sporeling"], "normal", "smoke")
	_check(fails, game.cb != null and game.cb.turn == 1, "combat started turn 1")
	_check(fails, screen._enemy_views.size() == 2, "two enemy views")
	_check(fails, screen._hand.uids().size() == 5, "hand renders 5 cards")
	var hero_before: EnemyView = screen._hero
	var foe_before: EnemyView = screen._enemy_views[0]
	var stage_before: SubViewport = hero_before._stage
	var card_before: CardView = screen._hand.card_view(game.cb.hand[0].uid)
	screen.set_shape(&"phone-portrait")
	_check(fails, screen._hero == hero_before and screen._enemy_views[0] == foe_before
			and screen._hero._stage == stage_before,
		"shape change preserves actors and their fracture stages")
	_check(fails, screen._hero.body_frame.is_equal_approx(Vector2(80.0, 130.0))
			and screen._hud.shape == &"phone-portrait",
		"phone shape re-frames the hero and combat HUD")
	_check(fails, screen._hand.card_view(game.cb.hand[0].uid) == card_before
			and is_equal_approx(card_before.base_scale,
				screen._card_metrics().x / CardView.CARD_W),
		"phone shape re-sizes existing hand cards")
	screen.set_shape(StageShape.IDENTITY)
	_check(fails, screen._hero == hero_before
			and screen._hero.body_frame.is_equal_approx(Vector2(190.0, 285.0))
			and screen._slots(2)[0].is_equal_approx(Vector2(820.0, 0.0)),
		"landscape return preserves and restores the hero")

	# `onCardClick` (combat.js:1667). A tap below the slop is a CLICK, and a click
	# is how the fight is played: a card that must choose between two living foes
	# arms and opens the arc; it does not play, and it does not open a panel.
	var enemy_uid: int = -1
	for c: CardInst in game.cb.hand:
		var v: CardView = screen._hand.card_view(c.uid)
		if v != null and v.target_kind == "enemy" and v.playable:
			enemy_uid = c.uid
			break
	_check(fails, enemy_uid >= 0, "hand holds a playable single-target card")
	var hand_view: HandView = screen._hand
	hand_view._on_card_pressed_at(enemy_uid, Vector2(100, 700))
	hand_view._on_card_released_at(enemy_uid, Vector2(104, 703))
	_check(fails, screen._targeting, "tap arms targeting when two foes live")
	_check(fails, game.cb.hand.size() == 5, "arming does not play the card")
	# Tapping the armed card again puts it back down.
	hand_view._on_card_pressed_at(enemy_uid, Vector2(100, 700))
	hand_view._on_card_released_at(enemy_uid, Vector2(104, 703))
	_check(fails, not screen._targeting, "tapping the armed card disarms it")
	_check(fails, game.cb.hand.size() == 5, "disarming does not play the card")
	var first_uid: int = game.cb.hand[0].uid

	# Drag past slop arms the drag machine; a dead-zone release snaps back.
	hand_view._on_card_pressed_at(first_uid, Vector2(100, 700))
	hand_view._on_card_moved_to(first_uid, Vector2(100, 660))
	_check(fails, hand_view._dragging, "40px drag passes the slop threshold")
	hand_view._on_card_released_at(first_uid, Vector2(100, 790))
	_check(fails, game.cb.hand.size() == 5, "release inside the hand zone cancels")

	# Play the first enemy-target card through the rules-gated play request.
	var target_uid: int = -1
	for c: CardInst in game.cb.hand:
		var d: Dictionary = game.rules.card_data(c)
		if str(d.get("target", "")) == "enemy" \
				and game.rules.can_play(game.run, game.cb, c, 0):
			target_uid = c.uid
			break
	_check(fails, target_uid >= 0, "an enemy-target card is in the opening hand")
	if target_uid >= 0:
		var hand_before: int = game.cb.hand.size()
		_check(fails, screen.request_play(target_uid, 0), "request_play accepts a valid target")
		_check(fails, not screen.seq.is_busy(), "instant drain completes synchronously")
		_check(fails, game.cb.hand.size() == hand_before - 1, "card left the hand")
		_check(fails, screen._hand.uids().size() == game.cb.hand.size(), "hand view tracks state")
		_check(fails, not screen.request_play(9999, 0), "unknown uid rejected")

	# End the turn: enemy phase runs, next turn draws back to 5.
	screen._on_end_turn_pressed()
	_check(fails, not screen.seq.is_busy(), "end-turn drain completes")
	if not game.cb.over:
		_check(fails, game.cb.turn == 2, "turn advanced to 2")
		_check(fails, game.cb.hand.size() == 5, "redrew to 5")
		_check(fails, screen._hand.uids().size() == 5, "hand view redrew to 5")

	tree.root.remove_child(screen)
	screen.free()


static func _derived_display_labels(fails: Array[String], content: ContentDB) -> void:
	var previous_locale: Locale = Locale.active
	var locale: Locale = Locale.new(Locale.CODE_EN)
	Locale.active = locale
	var strike: Dictionary = content.card(&"strike")
	var normal_card: CardView = CardView.new(CardInst.new(9001, &"strike"), strike, 1)
	_check(fails, _has_label(normal_card, "ATTACK"),
		"card type rubric keeps exact English uppercase")
	_free_card(normal_card)

	var relic: Dictionary = content.relic(&"emberHeart")
	var run: RunState = RunState.new_run(content, 9001)
	var normal_hud: RunHud = RunHud.new(run, content)
	var normal_tip: String = "%s\n%s\nstarter" % [relic["name"], relic["text"]]
	_check(fails, normal_hud._tip(relic, "missing") == normal_tip,
		"relic tooltip keeps hydrated English name, text and rarity")
	normal_hud.free()

	var requested: Dictionary = locale.get("_requested")
	var ui: Dictionary = requested["ui"]
	var card: Dictionary = ui["card"]
	var card_types: Dictionary = card["type"]
	card_types["attack"] = "blade-kind"
	var rarities: Dictionary = ui["rarity"]
	rarities["starter"] = "heirloom-tier"

	var translated_card: CardView = CardView.new(CardInst.new(9002, &"strike"), strike, 1)
	_check(fails, _has_label(translated_card, "BLADE-KIND"),
		"card type rubric resolves the active catalogue before uppercasing")
	_free_card(translated_card)
	var unknown_card_data: Dictionary = strike.duplicate(true)
	unknown_card_data["type"] = "diagnostic-type"
	var unknown_card: CardView = CardView.new(
		CardInst.new(9003, &"strike"), unknown_card_data, 1)
	_check(fails, _has_label(unknown_card, "DIAGNOSTIC-TYPE"),
		"unknown card type rubric stays literal instead of showing a key")
	_free_card(unknown_card)

	var translated_hud: RunHud = RunHud.new(run, content)
	var translated_tip: String = "%s\n%s\nheirloom-tier" % [relic["name"], relic["text"]]
	_check(fails, translated_hud._tip(relic, "missing") == translated_tip,
		"relic tooltip resolves a known rarity through the active catalogue")
	var relic_seat: Control = translated_hud._collection.get_child(0) as Control
	_check(fails, relic_seat != null and relic_seat.tooltip_text == translated_tip,
		"real relic seat carries the translated rarity tooltip")
	_check(fails, translated_hud._tip({"name": "Oddity", "text": "Kept",
		"rarity": "diagnostic-tier"}, "missing") == "Oddity\nKept\ndiagnostic-tier",
		"unknown relic rarity stays literal")
	_check(fails, translated_hud._tip({"name": "Plain", "text": "Kept",
		"rarity": ""}, "missing") == "Plain\nKept",
		"empty relic rarity stays omitted")
	translated_hud.free()
	Locale.active = previous_locale


static func _has_label(root: Node, text: String) -> bool:
	for node: Node in root.find_children("*", "Label", true, false):
		if node is Label and node.text == text:
			return true
	return false


static func _free_card(card: CardView) -> void:
	for surface: int in 3:
		card._slab.set_surface_override_material(surface, null)
	card.free()


## The layout identity gate.
##
## Every number this screen composes with now comes out of
## `assets/layout/combat-layout.json` instead of a constant. At the identity
## shape and act 0 the book must resolve to EXACTLY the literals that used to be
## written here, or the swap has quietly moved the composition — and with it
## every `file:line` this port carries, because all of them were measured at
## 1180x820 (`CONCEPTS.md:193`).
##
## The plate figures are the ones `docs/battlefield-parity.md:172-174` records as
## re-checked against `battlefield-layout.js`: `pad-landscape` act 0 is
## 640/280/drift 30, 1000/300/drift 10, 450/0/drift 0.
static func _layout_identity(fails: Array[String], screen: CombatScreen) -> void:
	_check(fails, screen.shape == StageShape.IDENTITY and screen.act == 0,
		"a default screen composes for pad-landscape act 0")
	_check(fails, is_equal_approx(screen._ground_y(), 232.0), "the ground line is 232")
	_check(fails, is_equal_approx(screen._hero_x(), 200.0), "the hero's centre is 200")

	var formations: Array[Array] = [
		[1, [Vector2(980.0, 0.0)]],
		[2, [Vector2(820.0, 0.0), Vector2(1035.0, 0.0)]],
		[3, [Vector2(698.0, 42.0), Vector2(850.0, -18.0), Vector2(996.0, 26.0)]],
	]
	for row: Array in formations:
		var count: int = row[0]
		var want: Array = row[1]
		var got: Array[Vector2] = screen._slots(count)
		_check(fails, got.size() == want.size(), "formation for %d foes has %d slots"
			% [count, want.size()])
		for i: int in mini(got.size(), want.size()):
			var seat: Vector2 = want[i]
			_check(fails, got[i].is_equal_approx(seat),
				"formation for %d, slot %d is %s (wanted %s)" % [count, i, got[i], seat])

	# h, y, x, zoom, opacity, posX, posY, drift — the eight the plate builder reads.
	var plates: Array[Array] = [
		["backdrop", [640.0, 280.0, 0.0, 1.0, 0.85, 50.0, 100.0, 30.0]],
		["mid", [1000.0, 300.0, 100.0, 0.4, 0.95, 100.0, 100.0, 10.0]],
		["ledge", [450.0, 0.0, 0.0, 1.0, 1.0, 100.0, 0.0, 0.0]],
	]
	var keys: PackedStringArray = ["h", "y", "x", "zoom", "opacity", "posX", "posY", "drift"]
	var layers: Dictionary = screen._layout().get("layers", {})
	for row: Array in plates:
		var name: String = row[0]
		var want: Array = row[1]
		var layer: Dictionary = layers.get(name, {})
		for i: int in keys.size():
			var got: float = LayoutBook.num(layer.get(keys[i]), NAN)
			var expect: float = want[i]
			_check(fails, is_equal_approx(got, expect),
				"%s plate %s is %s (wanted %s)" % [name, keys[i], got, expect])


## The same gate for the chrome. `UIC` gives every widget a distance from the
## corner it sits in, so `HudBar._place` needs no stage size — and the six boxes
## below are the arithmetic that used to be done by subtracting 1180x820 from an
## absolute coordinate. If any offset moves, the HUD has moved.
static func _chrome_identity(fails: Array[String]) -> void:
	var hud: HudBar = HudBar.new()
	_check(fails, is_equal_approx(hud.bar_height(), 56.0), "the top bar is 56 tall")

	# node, anchored-right?, offset_left, offset_top, offset_bottom
	var seats: Array[Array] = [
		["energy", hud._energy_orb, false, 0.0, -252.0, -162.0],
		["lantern", hud._lantern, false, 18.0, -372.0, -268.0],
		["endTurn", hud._end_turn, true, -120.0, -283.0, -163.0],
	]
	for row: Array in seats:
		var what: String = row[0]
		var node: Control = row[1]
		var right: bool = row[2]
		var want_left: float = row[3]
		var want_top: float = row[4]
		var want_bottom: float = row[5]
		if node == null:
			_check(fails, false, "%s exists" % what)
			continue
		_check(fails, is_equal_approx(node.anchor_left, 1.0 if right else 0.0),
			"%s hangs off the %s edge" % [what, "right" if right else "left"])
		_check(fails, is_equal_approx(node.anchor_bottom, 1.0), "%s hangs off the bottom" % what)
		_check(fails, is_equal_approx(node.offset_left, want_left),
			"%s offset_left is %s (wanted %s)" % [what, node.offset_left, want_left])
		_check(fails, is_equal_approx(node.offset_top, want_top),
			"%s offset_top is %s (wanted %s)" % [what, node.offset_top, want_top])
		_check(fails, is_equal_approx(node.offset_bottom, want_bottom),
			"%s offset_bottom is %s (wanted %s)" % [what, node.offset_bottom, want_bottom])

	# The three piles go through the same funnel; what is worth pinning is the
	# data they go through it with — `left 16 / right 132 / right 22`, all at
	# `bottom 14` and 96x148 (`src/ui-chrome-layout.js:21-23`).
	var piles: Array[Array] = [
		["draw", "left", 16.0], ["ashes", "right", 132.0], ["discard", "right", 22.0],
	]
	for row: Array in piles:
		var what: String = row[0]
		var edge: String = row[1]
		var gap: float = row[2]
		var seat: Dictionary = hud._chrome.get(what, {})
		_check(fails, seat.has(edge), "the %s pile pins to %s" % [what, edge])
		_check(fails, is_equal_approx(LayoutBook.num(seat.get(edge)), gap),
			"the %s pile is %s from that edge" % [what, gap])
		_check(fails, is_equal_approx(LayoutBook.num(seat.get("bottom")), 14.0)
				and is_equal_approx(LayoutBook.num(seat.get("w")), 96.0)
				and is_equal_approx(LayoutBook.num(seat.get("h")), 148.0),
			"the %s pile is 96x148, 14 up from the bottom" % what)
	hud.free()
