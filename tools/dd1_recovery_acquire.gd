extends SceneTree
## Explicit source-bound ordinary capture, not an N0 certificate producer.
## Native entry is currently disabled: this script grants no launch or credit.
const Route: GDScript = preload("res://tests/support/dd1_native_main_route.gd")
const Unit: GDScript = preload("res://tests/support/dd1_unit_grant.gd")


func _initialize() -> void:
	if not Route.launch_permitted():
		print("DD1_ACQUIRE_BLOCKED missing launch receipt or enclosing reservation")
		quit(1)
		return
	var root: String = Unit.output_root()
	var limit: int = Unit.root_limit()
	if root.is_empty() or limit <= 0 or DirAccess.dir_exists_absolute(root) \
			or DirAccess.make_dir_recursive_absolute(root) != OK:
		print("DD1_ACQUIRE_BLOCKED output must be new and reserved")
		quit(1)
		return
	var default_run: Variant = Route.file_text("user://glassvow_run_v2.json")
	var default_vigil: Variant = Route.file_text("user://glassvow_vigil_v2.json")
	var content: ContentDB = ContentDB.load_full(false)
	var vigil: VigilState = VigilState.blank()
	var traces: Array = []
	var profiles: Dictionary = {}
	var starts: int = 0
	var reason: String = ""
	for seed: int in range(5421600, 5421600 + limit):
		var run_path: String = root.path_join("run-%d.json" % seed)
		var vigil_path: String = root.path_join("vigil-%d.json" % seed)
		if Unit.remaining() <= 0:
			reason = "enclosing_contained_start_limit"
			break
		# Copy the last actual native commit (blank only for the first root).
		# Exact bytes are read by drive_ordinary before anything can clear them.
		if FileAccess.file_exists(run_path) or FileAccess.file_exists(vigil_path) \
				or not SaveService.store_vigil(vigil, vigil_path) \
				or Route.file_text(vigil_path) != JSON.stringify(vigil.to_dict()):
			reason = "initial_vigil_persistence_failure"
			break
		var vow: int = mini(vigil.vow_unlocked, 4)
		var row: Dictionary = Route.drive_ordinary(content, vigil, seed, vow, run_path, vigil_path)
		starts += int(row.get("starts", 0))
		traces.append(row)
		if not Route.write_pv_traces(root.path_join("row-%d.json" % seed), row):
			reason = "row_persistence_failure"
			break
		print("DD1_CAPTURE_ROW seed=%d status=%s starts=%d" % [seed, str(row.get("status", "INCOMPLETE")), int(row.get("starts", 0))])
		if str(row.get("status", "INCOMPLETE")) not in ["win", "death"]:
			reason = "incomplete_route:" + str(row.get("incomplete_reason", "unknown"))
			break  # Never clear failed evidence or continue into an unrelated chain.
		var loaded: VigilState = SaveService.load_vigil(vigil_path)
		if loaded == null or Route.file_text(vigil_path) != row.get("commit_vigil"):
			reason = "committed_vigil_readback_failure"
			break
		vigil = loaded
		for name: String in ["p0", "p5"]:
			var eligible: bool = Route.ledger_satisfies_p0(vigil) if name == "p0" else Route.ledger_satisfies_p5(vigil)
			if profiles.has(name) or not eligible:
				continue
			if not Route.archive_profile_run(row, root.path_join(name + "-run.json")) \
					or Route.archive_bytes(vigil_path, root.path_join(name + "-vigil.json")).is_empty():
				reason = "profile_persistence_failure:" + name
				break
			profiles[name] = {"root": seed, "run_bytes": row["pre_terminal_run"], "vigil_bytes": row["commit_vigil"]}
		if not reason.is_empty() or profiles.has("p5"):
			break
	if Route.file_text("user://glassvow_run_v2.json") != default_run \
			or Route.file_text("user://glassvow_vigil_v2.json") != default_vigil:
		reason = "default_profile_changed"
	var payload: Dictionary = {"operation": "DD1-N0-RECOVERY-1", "traces": traces,
		"profiles": profiles, "starts": starts, "incomplete_reason": reason,
		"result": "CAPTURED_PREFIX_UNVERIFIED" if reason.is_empty() else "INCOMPLETE",
		"n0_accepted": false}
	if not Route.write_pv_traces(root.path_join("linked-capture.json"), payload):
		print("DD1_ACQUIRE_FAIL final evidence persistence failure; retained partial files")
		quit(1)
		return
	print("DD1_CAPTURE_DONE starts=%d roots=%d profiles=%s result=%s" % [starts, traces.size(), str(profiles.keys()), payload["result"]])
	quit(0 if reason.is_empty() else 2)
