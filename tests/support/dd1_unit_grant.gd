extends RefCounted
## A local reservation envelope issued AFTER the Python meter debits a complete
## unit. This does not replace the existing owner/method/binding receipt check.
## The process-wide counter cannot be reset by creating another Main/route.

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
		var raw: String = FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(raw)
		if typeof(parsed) != TYPE_DICTIONARY:
			error = "invalid_enclosing_reservation"
			return 0
		_grant = parsed
		if _grant.get("schema") != "DD1-RESERVED-UNIT-2" or _grant.get("operation") != "DD1-N0-RECOVERY-1":
			error = "wrong_enclosing_operation"
			return 0
		var files: Variant = _grant.get("source_files")
		if typeof(files) != TYPE_DICTIONARY or files.is_empty():
			error = "missing_enclosing_sources"
			return 0
		for path_v: Variant in files:
			var source_path: String = str(path_v)
			if not source_path.begins_with("res://") or FileAccess.get_sha256(source_path) != files[path_v]:
				error = "enclosing_source_mismatch"
				return 0
		for required: String in ["res://tests/support/dd1_unit_grant.gd",
				"res://tests/support/dd1_native_driver_main.gd", "res://tests/support/dd1_ordinary_capture.gd",
				"res://tests/support/dd1_route_journal.gd", "res://tests/support/dd1_native_main_route.gd",
				"res://tools/balance_pilot.gd", "res://application/main.gd", "res://domain/game.gd"]:
			if not files.has(required):
				error = "unbound_execution_source"
				return 0
	var limit: int = int(_grant.get("contained_starts", 0))
	if limit < 1 or limit > 2047 or float(_grant.get("contained_starts", -1)) != float(limit):
		error = "unsafe_enclosing_start_limit"
	if Time.get_unix_time_from_system() >= float(_grant.get("deadline_unix", 0)):
		error = "enclosing_reservation_expired"
	return maxi(0, limit - _used) if error.is_empty() else 0


static func consume() -> bool:
	if remaining() <= 0:
		return false
	_used += 1
	return true


static func claim_root(seed: int) -> bool:
	if remaining() <= 0 or _root_index >= 16 or seed != 5421600 + _root_index:
		return false
	if _grant.get("mode") != "fixed_ordinary":
		return false
	_root_index += 1
	return true
