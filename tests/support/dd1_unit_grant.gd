extends RefCounted
## Process-wide consumption inside a complete unit already reserved by the host.
## This file cannot issue authority. Native admission belongs to the host.

static var _grant: Dictionary = {}
static var _read: bool = false
static var _used: int = 0
static var _root_index: int = 0
static var _verified_sources: Dictionary = {}
static var error: String = ""


## The protected host grant retains its actual engineering mode. Only the
## reviewed two-combat fixture can consume it; root acquisition remains gated
## on fixed_ordinary below. This is a consumer check, never launch authority.
static func _valid_mode(grant: Dictionary) -> bool:
	var mode: String = str(grant.get("mode", ""))
	if mode in ["fixed_ordinary", "focused_fixture"]:
		return true
	if mode != "engineering" or grant.get("stage") != "fixture":
		return false
	var profile_v: Variant = grant.get("compatibility")
	if typeof(profile_v) != TYPE_DICTIONARY:
		return false
	var profile: Dictionary = profile_v
	return profile.get("id") == "DD1-B1-COMPAT-2-CAPABILITIES-1" \
		and profile.get("operation") == "DD1-LINUX-ENTRY-1" \
		and profile.get("stage") == "fixture" \
		and profile.get("source_head") == grant.get("overlay_head") \
		and profile.get("attribution") == "CAPABILITY_CLASS_ONLY" \
		and grant.get("engine_starts") == 1 and grant.get("contained_starts") == 2


static func remaining() -> int:
	if not _read:
		_read = true
		var path: String = OS.get_environment("DD1_RESERVED_UNIT_PATH")
		if path.is_empty() or not FileAccess.file_exists(path):
			error = "missing_enclosing_reservation"
			return 0
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			error = "invalid_enclosing_reservation"
			return 0
		_grant = parsed
		if _grant.get("schema") != "DD1-RESERVED-UNIT-2" \
				or _grant.get("operation") != "DD1-N0-RECOVERY-1" \
				or _grant.get("scientific_m") != "07b5aa9dec8436132a524511d5438c510e322070" \
				or not _valid_mode(_grant):
			error = "wrong_enclosing_operation"
			return 0
		var files: Variant = _grant.get("source_files")
		if typeof(files) != TYPE_DICTIONARY or files.is_empty():
			error = "missing_enclosing_sources"
			return 0
		# PREP-1 keeps original identities and the actual sealed runtime view
		# distinct. This consumer cannot authenticate/issue the host grant.
		# Only the engineering fixture may consume this projection; existing
		# .uid, code, content, assets and restored project bytes cannot change.
		if _grant.has("execution_files"):
			var execution_v: Variant = _grant.get("execution_files")
			if _grant.get("mode") != "engineering" or _grant.get("stage") != "fixture" \
					or typeof(_grant.get("sealed_input")) != TYPE_DICTIONARY \
					or typeof(execution_v) != TYPE_DICTIONARY or execution_v.is_empty():
				error = "unbound_execution_projection"
				return 0
			var execution: Dictionary = execution_v
			for original_v: Variant in files:
				var original_path: String = str(original_v)
				if not execution.has(original_path) or (execution[original_path] != files[original_v] \
						and not original_path.ends_with(".import")):
					error = "changed_original_execution_input"
					return 0
			for generated_v: Variant in execution:
				var generated_path: String = str(generated_v)
				if not files.has(generated_path) and not generated_path.begins_with("res://.godot/") \
						and not generated_path.ends_with(".uid") and not generated_path.ends_with(".import"):
					error = "undeclared_execution_source_kind"
					return 0
			files = execution
		for path_v: Variant in files:
			var source_path: String = str(path_v)
			if not source_path.begins_with("res://") or source_path.contains("..") \
					or FileAccess.get_sha256(source_path) != files[path_v]:
				error = "enclosing_source_mismatch"
				return 0
		for required: String in ["res://tests/support/dd1_unit_grant.gd",
				"res://tests/support/dd1_native_driver_main.gd", "res://tests/support/dd1_ordinary_capture.gd",
				"res://tests/support/dd1_route_journal.gd", "res://tests/support/dd1_native_main_route.gd",
				"res://tools/balance_pilot.gd", "res://tools/balance_policy.gd",
				"res://application/main.gd", "res://application/save_service.gd", "res://domain/game.gd",
				"res://domain/state/run_state.gd", "res://domain/state/vigil_state.gd",
				"res://domain/state/combat_state.gd", "res://domain/rules/combat.gd",
				"res://domain/rules/rewards.gd", "res://domain/rules/quests.gd", "res://tools/vow_incentives.gd"]:
			if not files.has(required):
				error = "unbound_execution_source"
				return 0
		_verified_sources = files.duplicate(true)
	var value: Variant = _grant.get("contained_starts")
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) \
			or float(value) != floorf(float(value)) or float(value) < 1 or float(value) > 2047:
		error = "unsafe_enclosing_start_limit"
		return 0
	var deadline: Variant = _grant.get("deadline_unix")
	if typeof(deadline) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(deadline)) \
			or float(deadline) != 1790272480.0 or Time.get_unix_time_from_system() >= float(deadline):
		error = "enclosing_reservation_expired_or_reset"
	var raw: Variant = _grant.get("child_raw_bytes")
	if typeof(raw) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(raw)) \
			or float(raw) != floorf(float(raw)) or float(raw) <= 0 or float(raw) > 1073741824:
		error = "unsafe_enclosing_raw_limit"
	return maxi(0, int(value) - _used) if error.is_empty() else 0


static func consume() -> bool:
	if remaining() <= 0:
		return false
	_used += 1
	return true


static func source_manifest() -> Dictionary:
	return _verified_sources.duplicate(true) if remaining() > 0 else {}


static func journal_limit() -> int:
	return mini(67108864, int(_grant.get("child_raw_bytes", 0))) if remaining() > 0 else 0


static func claim_root(seed: int) -> bool:
	if remaining() <= 0 or _root_index >= 16 or seed != 5421600 + _root_index:
		return false
	if _grant.get("mode") != "fixed_ordinary":
		return false
	_root_index += 1
	return true


static func output_root() -> String:
	if remaining() <= 0 or _grant.get("mode") != "fixed_ordinary":
		return ""
	var root: String = str(_grant.get("artifact_root", ""))
	return root if root.is_absolute_path() and not root.begins_with("res://") \
		and not root.begins_with("user://") and not root.contains("..") else ""


static func root_limit() -> int:
	var value: Variant = _grant.get("max_roots", 16)
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) \
			or float(value) != floorf(float(value)) or float(value) < 1 or float(value) > 16:
		return 0
	return int(value)
