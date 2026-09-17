class_name Dd1NativeLaunchReceipt
extends RefCounted
## Receipt-bound launch gate for DD1-N0-RECOVERY-1.
## File existence and environment variables are not permission.


const QUAL: String = "res://research/p9-six-route/dusk-design-1-20260916/native-qualification"
const RECOVERY: String = QUAL + "/recovery"
const BINDINGS_PATH: String = RECOVERY + "/RECEIPT-BINDINGS.json"
const ACCOUNT_PATH: String = RECOVERY + "/ACCOUNT.json"
const DEFAULT_RECEIPT_PATH: String = RECOVERY + "/LAUNCH-RECEIPT.json"
const RECEIPTS_DIR: String = RECOVERY + "/receipts"
const STARTING_G: String = "84cd143f44923294e614def62de74e720598648a"
const SCHEMA: String = "DD1-N0-RECOVERY-1-LAUNCH-RECEIPT-1"
const OPERATION: String = "DD1-N0-RECOVERY-1"


static func receipt_path() -> String:
	var override_path: String = OS.get_environment("DD1_NATIVE_LAUNCH_RECEIPT")
	if not override_path.is_empty():
		return override_path
	return DEFAULT_RECEIPT_PATH


static func sha256_text(text: String) -> String:
	return text.sha256_text()


static func file_sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return sha256_text(FileAccess.get_file_as_string(path))


static func _load_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw: String = FileAccess.get_file_as_string(path)
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func evaluate(path: String = "") -> Dictionary:
	var receipt_at: String = path if not path.is_empty() else receipt_path()
	if not FileAccess.file_exists(receipt_at):
		return _reject("missing receipt")
	var raw: String = FileAccess.get_file_as_string(receipt_at)
	if raw.is_empty():
		return _reject("empty receipt")
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _reject("receipt is not a JSON object")
	var receipt: Dictionary = parsed
	if str(receipt.get("schema", "")) != SCHEMA:
		return _reject("wrong schema")
	if str(receipt.get("operation", "")) != OPERATION:
		return _reject("wrong operation")
	var bindings: Dictionary = _load_object(BINDINGS_PATH)
	if bindings.is_empty():
		return _reject("bindings missing")
	var files_v: Variant = bindings.get("files", {})
	if typeof(files_v) != TYPE_DICTIONARY:
		return _reject("bindings files missing")
	var files: Dictionary = files_v
	var claimed_v: Variant = receipt.get("bodies", {})
	if typeof(claimed_v) != TYPE_DICTIONARY:
		return _reject("receipt bodies missing")
	var claimed: Dictionary = claimed_v
	var required: Array[String] = [
		"protocol-5717964158.md",
		"selection-5718178514.md",
		"review-5718202450.md",
		"binding-5718448223.md",
		"task-5718464731.md",
	]
	for name: String in required:
		var body_path: String = RECEIPTS_DIR + "/" + name
		if not FileAccess.file_exists(body_path):
			return _reject("stored body missing: %s" % name)
		var actual: String = file_sha256(body_path)
		var meta_v: Variant = files.get(name, {})
		if typeof(meta_v) != TYPE_DICTIONARY:
			return _reject("bindings meta missing: %s" % name)
		var meta: Dictionary = meta_v
		var expected: String = str(meta.get("sha256", ""))
		if actual.is_empty() or actual != expected:
			return _reject("stale stored body: %s" % name)
		if str(claimed.get(name, "")) != actual:
			return _reject("receipt stale identity: %s" % name)
	var source_v: Variant = receipt.get("source", {})
	if typeof(source_v) != TYPE_DICTIONARY:
		return _reject("source missing")
	var source: Dictionary = source_v
	if str(source.get("scientific_m", "")) != str(bindings.get("scientific_m", "")):
		return _reject("stale scientific M")
	if str(source.get("starting_overlay_commit", "")) != STARTING_G:
		return _reject("stale starting overlay")
	if str(source.get("driver", "")) != str(bindings.get("driver", "")):
		return _reject("stale driver")
	if str(source.get("pilot_version", "")) != str(bindings.get("pilot_version", "")):
		return _reject("stale pilot")
	var inputs_v: Variant = receipt.get("inputs", {})
	if typeof(inputs_v) != TYPE_DICTIONARY:
		return _reject("inputs missing")
	var inputs: Dictionary = inputs_v
	if int(float(str(inputs.get("pending_seed", -1)))) != 5420099:
		return _reject("wrong pending seed")
	var roots_v: Variant = inputs.get("pv_roots", [])
	if typeof(roots_v) != TYPE_ARRAY:
		return _reject("missing P_v roots")
	var roots: Array = roots_v
	if roots.size() != 16:
		return _reject("P_v root count")
	for i: int in range(16):
		if int(float(str(roots[i]))) != 5421600 + i:
			return _reject("P_v roots reordered or substituted")
	var account: Dictionary = _load_object(ACCOUNT_PATH)
	var recovery_v: Variant = account.get("recovery", {})
	if typeof(recovery_v) != TYPE_DICTIONARY:
		return _reject("recovery account missing")
	var recovery: Dictionary = recovery_v
	var used: int = int(float(str(recovery.get("starts_used", 0))))
	var cap: int = int(float(str(recovery.get("starts_cap", 0))))
	if cap <= 0 or used >= cap:
		return _reject("exhausted reservation")
	var expiry_v: Variant = receipt.get("expiry", {})
	if typeof(expiry_v) == TYPE_DICTIONARY:
		var expiry: Dictionary = expiry_v
		var deadline: String = str(expiry.get("deadline_utc", ""))
		if not deadline.is_empty() and deadline < Time.get_datetime_string_from_system(true):
			return _reject("expired")
	return {
		"ok": true,
		"path": receipt_at,
		"reason": "",
	}


static func permitted(path: String = "") -> bool:
	var row: Dictionary = evaluate(path)
	return row.get("ok", false) == true


static func _reject(reason: String) -> Dictionary:
	return {
		"ok": false,
		"path": "",
		"reason": reason,
	}
