extends RefCounted
## Process-wide consumption inside a complete unit already reserved by the host.
## This file cannot issue authority. The native Python entry remains blocked.

static var _grant: Dictionary = {}
static var _read: bool = false
static var _used: int = 0
static var _root_index: int = 0
static var error: String = ""


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
				or _grant.get("mode") not in ["fixed_ordinary", "focused_fixture"]:
			error = "wrong_enclosing_operation"
			return 0
		var files: Variant = _grant.get("source_files")
		if typeof(files) != TYPE_DICTIONARY or files.is_empty():
			error = "missing_enclosing_sources"
			return 0
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
	return _grant.get("source_files", {}).duplicate(true) if remaining() > 0 else {}


static func journal_limit() -> int:
	return mini(67108864, int(_grant.get("child_raw_bytes", 0))) if remaining() > 0 else 0


static func claim_root(seed: int) -> bool:
	if remaining() <= 0 or _root_index >= 16 or seed != 5421600 + _root_index:
		return false
	if _grant.get("mode") != "fixed_ordinary":
		return false
	_root_index += 1
	return true
