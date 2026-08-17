extends RefCounted
## Every act the layout book knows has all three combat stage plates on disk.
##
## A missing plate is silent at runtime: `CombatScreen` push_warning()s and then
## draws an empty stage (`presentation/combat/combat_screen.gd:1261-1266`). A
## warning is not a gate, so the first person to learn is a player looking at a
## blank backdrop. This makes absence loud at check time instead.
##
## Act count is `LayoutBook.ACTS`, not `content.acts.size()`. The three plate
## names come from `PLATE_PERIODS` (`combat_screen.gd:56`), the path from
## `STAGE_ART` (`combat_screen.gd:50`).


static func run(fails: Array[String]) -> void:
	var acts: int = LayoutBook.ACTS
	if acts <= 0:
		fails.append("test_stage_plates: LayoutBook.ACTS is not positive")
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
	for act: int in range(1, acts + 1):
		_require_plates(pattern, plates, act, fails)


static func _require_plates(
	pattern: String, plates: Array, act: int, fails: Array[String]
) -> void:
	for plate_v: Variant in plates:
		var path: String = pattern % [act, str(plate_v)]
		if not FileAccess.file_exists(path):
			fails.append("test_stage_plates: missing %s" % path)
		elif not ResourceLoader.exists(path):
			fails.append("test_stage_plates: unimported %s" % path)
