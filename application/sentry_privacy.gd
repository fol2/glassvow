class_name SentryPrivacy
extends RefCounted
## Privacy filter for Sentry events. No Sentry types — unit-tested without
## the GDExtension. Strips unexpected free text and bounds noisy non-fatals.

const NONFATAL_CAP: int = 8
const MAX_TEXT: int = 240

var _nonfatal_counts: Dictionary = {}


static func redact(text: String) -> String:
	var out: String = _strip_user_paths(text)
	var trimmed: String = out.strip_edges()
	if trimmed.begins_with("{") and (
			trimmed.contains("\"seed\"")
			or trimmed.contains("\"deck\"")
			or trimmed.contains("glassvow_run")):
		return "[redacted]"
	if out.length() > MAX_TEXT:
		return out.substr(0, MAX_TEXT)
	return out


func allow_nonfatal(key: String) -> bool:
	var n: int = int(float(str(_nonfatal_counts.get(key, 0)))) + 1
	_nonfatal_counts[key] = n
	return n <= NONFATAL_CAP


static func _strip_user_paths(text: String) -> String:
	var out: String = text
	var at: int = out.find("user://")
	while at >= 0:
		var end: int = at + 7
		while end < out.length():
			var ch: String = out.substr(end, 1)
			if ch == " " or ch == "\n" or ch == "\t" or ch == "\"" or ch == "'":
				break
			end += 1
		out = out.substr(0, at) + "user://[redacted]" + out.substr(end)
		at = out.find("user://", at + 16)
	return out
