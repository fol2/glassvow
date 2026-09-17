extends SceneTree
## Replay the first-valid P_0 seed from the retained predecessor vigil.


const MainRoute: GDScript = preload("res://tests/support/dd1_native_main_route.gd")
const SEED: int = 5421603
const VIGIL_IN: String = "user://dd1_pv_vigil_5421602_v2.json"
const RUN_OUT: String = "user://dd1_pv_run_5421603_v2.json"
const VIGIL_OUT: String = "user://dd1_pv_vigil_5421603_replay_v2.json"


func _initialize() -> void:
	if not MainRoute.launch_permitted():
		print("DD1_REPLAY_FAIL launch receipt invalid")
		quit(1)
		return
	var content: ContentDB = ContentDB.load_full(false)
	var vigil: VigilState = SaveService.load_vigil(VIGIL_IN)
	MainRoute.bind_unmodified_pilot()
	var vow: int = mini(vigil.vow_unlocked, 4)
	var row: Dictionary = MainRoute.drive_ordinary(
		content, vigil, SEED, vow, RUN_OUT, VIGIL_OUT)
	var pre: String = str(row.get("pre_terminal_run", ""))
	if not pre.is_empty():
		var wf: FileAccess = FileAccess.open(RUN_OUT, FileAccess.WRITE)
		if wf != null:
			wf.store_string(pre)
			wf.close()
	print("DD1_REPLAY_DONE status=%s starts=%s shatters=%s p0=%s run_sha=%s vigil_sha=%s pre_len=%d" % [
		str(row.get("status", "")), str(row.get("starts", 0)), str(row.get("shatters", 0)),
		str(MainRoute.ledger_satisfies_p0(SaveService.load_vigil(VIGIL_OUT))),
		str(row.get("run_sha", "")), str(row.get("vigil_sha", "")),
		pre.length(),
	])
	quit(0)
