extends RefCounted
## Locale catalogue: English seed resolves, fallback never blanks, params
## interpolate, and the default `active` stand-in needs no main.


static func run(fails: Array[String]) -> void:
	_english_seed(fails)
	_fallback_chain(fails)
	_params(fails)
	_content_and_whisper(fails)
	_unknown_language_rejected(fails)
	_default_active(fails)


static func _english_seed(fails: Array[String]) -> void:
	var locale: Locale = Locale.new()
	if locale.code != Locale.CODE_EN:
		fails.append("locale: default language is not en")
	if locale.t("ui.brand.title") != "GLASSVOW":
		fails.append("locale: ui.brand.title missing from en seed")
	if locale.t("ui.embark.title") != "THE CLIMB BEGINS":
		fails.append("locale: ui.embark.title missing from en seed")
	if locale.t("ui.keywords.kindle") == "ui.keywords.kindle":
		fails.append("locale: ui.keywords.kindle missing from en seed")
	if locale.t("ui.pilgrimage.survey") != "SCROLL OR DRAG TO SURVEY THE PILGRIMAGE":
		fails.append("locale: Glassvow pilgrimage keys missing from en seed")
	if locale.content("cards", "strike", "name") != "Edge":
		fails.append("locale: content.cards.strike.name missing from en seed")
	if not locale.content("cards", "strike", "text").contains("@6@"):
		fails.append("locale: card text lost @n@ markers")


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
	if line != "Act 2 · Floor 7":
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
