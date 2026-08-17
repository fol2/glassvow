extends RefCounted
## Acts 1–3 must ship all three combat stage plates. Act 4's plates are #221;
## until that ticket lands none, this gate does not fail-open the first three
## acts and does not invent raster assets here.
##
## A missing plate is silent at runtime: `CombatScreen` push_warning()s and then
## draws an empty stage (`presentation/combat/combat_screen.gd:1261-1266`). A
## warning is not a gate, so the first person to learn is a player looking at a
## blank backdrop. This makes absence loud at check time instead.
##
## The act count comes from the same `content.acts` the game itself indexes
## (`application/main.gd:1956`), the three plate names from `PLATE_PERIODS`
## (`combat_screen.gd:56`), and the path from `STAGE_ART` (`combat_screen.gd:50`).
## If any Act IV plate exists, all three are required so #221 cannot ship a
## partial set.


static func run(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.load_full()
	var acts: int = db.acts.size()
	if acts <= 0:
		fails.append("test_stage_plates: content book defines no acts")
		return

	var screen: GDScript = load("res://presentation/combat/combat_screen.gd") as GDScript
	if screen == null:
		fails.append("test_stage_plates: combat_screen.gd failed to load")
		return
	var consts: Dictionary = screen.get_script_constant_map()

	var pattern: String = str(consts.get("STAGE_ART", ""))
	if pattern.is_empty():
		fails.append("test_stage_plates: STAGE_ART missing from combat_screen.gd")
		return

	var periods_v: Variant = consts.get("PLATE_PERIODS", null)
	if typeof(periods_v) != TYPE_DICTIONARY:
		fails.append("test_stage_plates: PLATE_PERIODS missing from combat_screen.gd")
		return
	var periods: Dictionary = periods_v
	var plates: Array = periods.keys()
	if plates.is_empty():
		fails.append("test_stage_plates: PLATE_PERIODS is empty")
		return

	# Acts are zero-indexed in the run state; the files are one-indexed.
	#
	# FileAccess, not ResourceLoader.exists(): the latter answers from the import
	# cache, so it returns true for a plate whose source .png has been deleted as
	# long as .godot/imported/ still holds the .ctex. Measured — the first draft
	# of this gate passed with act3-ledge.png removed from the tree, which is the
	# fail-open failure this test exists to prevent.
	var last_required: int = mini(acts, 3)
	for act: int in range(1, last_required + 1):
		_require_plates(pattern, plates, act, fails)
	if acts >= 4:
		var present: int = 0
		for plate_v: Variant in plates:
			if FileAccess.file_exists(pattern % [4, str(plate_v)]):
				present += 1
		if present > 0:
			_require_plates(pattern, plates, 4, fails)


static func _require_plates(
	pattern: String, plates: Array, act: int, fails: Array[String]
) -> void:
	for plate_v: Variant in plates:
		var path: String = pattern % [act, str(plate_v)]
		if not FileAccess.file_exists(path):
			fails.append("test_stage_plates: missing %s" % path)
		elif not ResourceLoader.exists(path):
			fails.append("test_stage_plates: unimported %s" % path)
