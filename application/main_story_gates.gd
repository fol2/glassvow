class_name MainStoryGates
extends "res://application/main.gd"
## Thin composition override for #270. Main keeps every route and persistence
## seam; this layer changes only the monument's narrative copy.

const LOSS_WORDS_PREFIX: String = "content.lossWords."


static func monument_title(shard_count: int, locale: Locale) -> String:
	return "" if shard_count <= 0 else locale.t("ui.end.monument.title")


## `lastWords` -1 is deliberately silent; 0..49 is a non-repeating slot.
## Marker-less records are legacy v2 saves. Until #228 authors the full pool,
## slot 0 retains the shipped generic line and missing later slots stay silent.
static func monument_body(
		monument: Dictionary, shard_count: int, locale: Locale
) -> String:
	if shard_count <= 0:
		return ""
	if monument.has("lastWords"):
		var index: int = int(float(str(monument.get("lastWords", -1))))
		if index < 0:
			return ""
		var key: String = LOSS_WORDS_PREFIX + str(index)
		var line: String = locale.t(key)
		if line != key:
			return line
		if index > 0:
			return ""
	var bequest_v: Variant = monument.get("bequest")
	return locale.t("ui.end.monument.bodyWithBequest") \
		if typeof(bequest_v) == TYPE_DICTIONARY \
		else locale.t("ui.end.monument.body")


func _show_monument() -> void:
	_remember_route(_show_monument)
	if typeof(game.run.monument) != TYPE_DICTIONARY:
		_finish_node()
		return
	var monument: Dictionary = game.run.monument
	var shard_count: int = game.run.shards.size()
	var claim: String = Locale.active.t("ui.end.monument.claim") \
		if shard_count > 0 else Locale.active.t("ui.common.use")
	_show_choice(monument_title(shard_count, Locale.active),
		monument_body(monument, shard_count, Locale.active), [
			{"id": "claim", "label": claim},
			{"id": "leave", "label": Locale.active.t("ui.common.leave"), "quiet": true},
		], _on_monument_choice, {"overlay": true})
