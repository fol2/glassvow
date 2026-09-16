extends RefCounted
## DD1-NATIVE-1 Native Proof catalogue: overlay cards must be displayable.
## CardLab reads port_fixtures/content/card-catalog.json, not ContentDB.


static func run(fails: Array[String]) -> void:
	var text: String = FileAccess.get_file_as_string(
		"res://port_fixtures/content/card-catalog.json")
	if text.is_empty():
		fails.append("dd1-catalog: card-catalog.json unreadable")
		return
	var raw: Variant = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		fails.append("dd1-catalog: card-catalog.json is not an object")
		return
	var doc: Dictionary = raw
	var cards_v: Variant = doc.get("cards")
	if typeof(cards_v) != TYPE_DICTIONARY:
		fails.append("dd1-catalog: cards object missing")
		return
	var cards: Dictionary = cards_v
	if not cards.has("setTheAngle"):
		fails.append("dd1-catalog: setTheAngle missing from Native Proof catalogue")
	if not cards.has("crosscut"):
		fails.append("dd1-catalog: crosscut missing from Native Proof catalogue")
	var content: ContentDB = ContentDB.load_full(false)
	var lab: Dictionary = CardLab.load_catalog(content)
	if not lab.has("setTheAngle") or not lab.has("crosscut"):
		fails.append("dd1-catalog: CardLab.load_catalog omits overlay cards")
	if int(float(str(doc.get("count", 0)))) != cards.size():
		fails.append("dd1-catalog: count %s != %d cards" % [str(doc.get("count", 0)), cards.size()])
