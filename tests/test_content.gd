extends RefCounted
## ContentDB loads the slice projection, exposes every manifest id, and confirms
## every slice enemy has an AI handler (validate). Cross-checks slice-content.json
## against slice-manifest.json so a divergence between the two fixtures is caught.


static func run(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.load_slice()
	if db.id != "slice-v1":
		fails.append("ContentDB: id expected slice-v1 got %s" % db.id)

	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://port_fixtures/content/slice-manifest.json")
	)
	if typeof(raw) != TYPE_DICTIONARY:
		fails.append("slice-manifest.json: parse failed")
		return
	var manifest: Dictionary = raw

	var man_cards: Array = manifest["cards"]
	for cv: Variant in man_cards:
		var cid: String = cv
		if db.card(StringName(cid)).is_empty():
			fails.append("ContentDB: manifest card %s missing from slice-content" % cid)

	var man_enemies: Dictionary = manifest["enemies"]
	var enemy_list: Array = []
	var normals: Array = man_enemies["normals"]
	var elite: Array = man_enemies["elite"]
	enemy_list.append_array(normals)
	enemy_list.append_array(elite)
	for ev: Variant in enemy_list:
		var eid: String = ev
		if db.enemy(StringName(eid)).is_empty():
			fails.append("ContentDB: manifest enemy %s missing from slice-content" % eid)

	var man_potions: Array = manifest["potions"]
	for pv: Variant in man_potions:
		var pid: String = pv
		if db.potion(StringName(pid)).is_empty():
			fails.append("ContentDB: manifest potion %s missing from slice-content" % pid)

	# Every enemy the content ships must have an AI handler.
	db.validate(fails)
