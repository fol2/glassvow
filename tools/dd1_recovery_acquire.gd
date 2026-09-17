extends SceneTree
## First-valid ordinary Dusk P_0/P_5 on exposed roots 5421600–5421615.
## Launch must already be receipt-permitted by the process wrapper.


const MainRoute: GDScript = preload("res://tests/support/dd1_native_main_route.gd")
const QUAL: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification"
const P0_RUN: String = QUAL + "/p0-first-valid-run-v2.json"
const P0_VIGIL: String = QUAL + "/p0-first-valid-vigil-v2.json"
const P5_RUN: String = QUAL + "/p5-first-valid-run-v2.json"
const P5_VIGIL: String = QUAL + "/p5-first-valid-vigil-v2.json"
const TRACE_PATH: String = QUAL + "/recovery/PV-TRACES.json"


func _initialize() -> void:
	if not MainRoute.launch_permitted():
		print("DD1_ACQUIRE_FAIL launch receipt invalid")
		quit(1)
		return
	var default_run: Variant = MainRoute.file_text("user://glassvow_run_v2.json")
	var default_vigil: Variant = MainRoute.file_text("user://glassvow_vigil_v2.json")
	var content: ContentDB = ContentDB.load_full(false)
	var vigil: VigilState = VigilState.blank()
	var freeze: Dictionary = MainRoute.bind_unmodified_pilot()
	var p0_archived: bool = false
	var p5_archived: bool = false
	var traces: Array = []
	var starts: int = 0
	for seed: int in range(5421600, 5421616):
		var vow: int = mini(vigil.vow_unlocked, 4)
		var run_path: String = "user://dd1_pv_run_%d_v2.json" % seed
		var vigil_path: String = "user://dd1_pv_vigil_%d_v2.json" % seed
		SaveService.store_vigil(vigil, vigil_path)
		var row: Dictionary = MainRoute.drive_ordinary(
			content, vigil, seed, vow, run_path, vigil_path)
		starts += int(float(str(row.get("starts", 0))))
		var loaded: VigilState = SaveService.load_vigil(vigil_path)
		if loaded != null:
			vigil = loaded
		var status: String = str(row.get("status", "INCOMPLETE"))
		traces.append(MainRoute.durable_trace_row(seed, vow, row, vigil))
		var commands_v: Variant = row.get("commands", [])
		var command_n: int = commands_v.size() if typeof(commands_v) == TYPE_ARRAY else 0
		print("DD1_ACQUIRE_ROW seed=%d vow=%d status=%s starts=%d shatters=%s p0=%s p5=%s vow_unlocked=%d commands=%d pre_len=%d" % [
			seed, vow, status, int(float(str(row.get("starts", 0)))), str(row.get("shatters", 0)),
			str(MainRoute.ledger_satisfies_p0(vigil)), str(MainRoute.ledger_satisfies_p5(vigil)),
			vigil.vow_unlocked, command_n, str(row.get("pre_terminal_run", "")).length(),
		])
		if status == "INCOMPLETE":
			continue
		if not p0_archived and MainRoute.ledger_satisfies_p0(vigil):
			if MainRoute.archive_profile_run(row, P0_RUN):
				MainRoute.archive_bytes(vigil_path, P0_VIGIL)
				p0_archived = true
				print("DD1_ACQUIRE_P0 seed=%d" % seed)
			else:
				print("DD1_ACQUIRE_P0_SKIP seed=%d empty pre_terminal_run" % seed)
		if p0_archived and not p5_archived and MainRoute.ledger_satisfies_p5(vigil):
			if MainRoute.archive_profile_run(row, P5_RUN):
				MainRoute.archive_bytes(vigil_path, P5_VIGIL)
				p5_archived = true
				print("DD1_ACQUIRE_P5 seed=%d" % seed)
				break
			print("DD1_ACQUIRE_P5_SKIP seed=%d empty pre_terminal_run" % seed)
	var gate: Dictionary = MainRoute.evaluate_n0_witness(P0_RUN, P0_VIGIL, P5_RUN, P5_VIGIL, content)
	var payload: Dictionary = {
		"pilot": freeze,
		"starts": starts,
		"p0_archived": p0_archived,
		"p5_archived": p5_archived,
		"gate": gate,
		"traces": traces,
	}
	if not MainRoute.write_pv_traces(TRACE_PATH, payload):
		print("DD1_ACQUIRE_FAIL could not write PV-TRACES")
		quit(1)
		return
	if MainRoute.file_text("user://glassvow_run_v2.json") != default_run \
			or MainRoute.file_text("user://glassvow_vigil_v2.json") != default_vigil:
		print("DD1_ACQUIRE_FAIL default owner saves were touched")
		quit(1)
		return
	print("DD1_ACQUIRE_DONE starts=%d p0=%s p5=%s gate=%s" % [
		starts, str(p0_archived), str(p5_archived), str(gate.get("result", "")),
	])
	quit(0 if str(gate.get("result", "")) == "ACCEPT" else 2)
