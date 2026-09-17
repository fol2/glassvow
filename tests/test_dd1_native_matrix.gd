extends RefCounted
## Current orchestration. Unchanged collateral fixture bodies are retained at
## their exact historical bytes; NEVER call Archive.run or its old N0 positive.
## Acquisition is a separate explicit entry, never a regression side effect.
const Archive: GDScript = preload("res://research/p9-six-route/dusk-design-1-20260916/native-qualification/source-repair/history/test_dd1_native_matrix_at_4f7.gd")
const Repair: GDScript = preload("res://tests/test_dd1_source_repair.gd")
const MainRoute: GDScript = preload("res://tests/support/dd1_native_main_route.gd")
static var native_starts: int = 0


static func run(fails: Array[String]) -> void:
	Archive.native_starts = 0
	var default_run: Variant = MainRoute.file_text(Archive.DEFAULT_RUN_PATH)
	var default_vigil: Variant = MainRoute.file_text(Archive.DEFAULT_VIGIL_PATH)
	Archive._k1_paid_chain(fails)
	Archive._k1_joint_and_upgrades(fails)
	Archive._adamant_hold(fails)
	Archive._prism_and_smolder(fails)
	Archive._reaper_draw_energy(fails)
	Archive._return_thorns(fails)
	Archive._abandon_clears_mark(fails)
	Archive._launch_receipt_controls(fails)
	Repair.run(fails)
	Archive._shipped_pending_capture(fails)
	Archive._unmodified_m_pending_resume(fails)
	# This archived serializer fixture proves preservation of supplied fields,
	# NOT their native origin. The connected Python verifier rejects such rows.
	Archive._pv_trace_producer_retains_bytes(fails)
	_constructed_profile_is_not_earned(fails)
	_canonical_structure_is_not_provenance(fails)
	native_starts = Archive.native_starts + Repair.native_starts
	if MainRoute.file_text(Archive.DEFAULT_RUN_PATH) != default_run \
			or MainRoute.file_text(Archive.DEFAULT_VIGIL_PATH) != default_vigil:
		fails.append("dd1-matrix: tests touched the default save")
	for path: String in [Archive.PV_VIGIL_PATH, Archive.PV_RUN_PATH,
			Archive.ABANDON_RUN_PATH, Archive.ABANDON_VIGIL_PATH, Archive.M_LOAD_PATH]:
		SaveService.clear(path)
	print("  DD1-NATIVE-1-matrix native_starts=%d" % native_starts)


static func _constructed_profile_is_not_earned(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var paths: Array[String] = ["user://dd1_structure_p0_run.json", "user://dd1_structure_p0_vigil.json",
		"user://dd1_structure_p5_run.json", "user://dd1_structure_p5_vigil.json"]
	for path: String in paths:
		if FileAccess.file_exists(path):
			fails.append("dd1-matrix: existing isolated structural fixture retained")
			return
	for i: int in [0, 1]:
		var run: RunState = RunState.new_run(content, 5421600 + i, "SYNTHETIC-profile-%d" % i,
			{"aspect": 0, "vow": 4 if i == 1 else 0})
		var vigil: VigilState = VigilState.blank()
		vigil.runs_played = 6 if i == 1 else 1
		vigil.deeds["shatters"] = 40 if i == 1 else 15
		vigil.vow_unlocked = 5 if i == 1 else 0
		vigil.unlocks.append("card:resonantLance")
		if not SaveService.store(run, paths[2 * i]) or not SaveService.store_vigil(vigil, paths[2 * i + 1]):
			fails.append("dd1-matrix: synthetic structural save failed")
			return
		if SaveService.load_run(content, paths[2 * i]) == null or SaveService.load_vigil(paths[2 * i + 1]) == null:
			fails.append("dd1-matrix: synthetic structural load failed")
	var supplied: Dictionary = MainRoute.evaluate_n0_witness(paths[0], paths[1], paths[2], paths[3], content)
	if str(supplied.get("result", "")) not in ["REJECT", "BLOCKED"]:
		fails.append("dd1-matrix: loadable constructed fields must not be an earned N0 witness")
	for path: String in paths:
		SaveService.clear(path)


static func _canonical_structure_is_not_provenance(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var paths: Array[String] = [Archive.QUAL_PV_P0_BYTES, Archive.QUAL_PV_P0_VIGIL,
		Archive.QUAL_PV_P5_BYTES, Archive.QUAL_PV_P5_VIGIL]
	var before: Array = []
	for path: String in paths:
		before.append(MainRoute.file_text(path))
	var result: Dictionary = MainRoute.evaluate_n0_witness(paths[0], paths[1], paths[2], paths[3], content)
	if str(result.get("result", "")) not in ["REJECT", "BLOCKED"]:
		fails.append("dd1-matrix: four saved files cannot authenticate ordinary provenance")
	for i: int in range(paths.size()):
		if MainRoute.file_text(paths[i]) != before[i]:
			fails.append("dd1-matrix: canonical evidence was changed")
