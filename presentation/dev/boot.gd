extends RefCounted
## Excluded Development boot. Parses a Scenario reference off the command
## line and hands it to the composition root. No construct/reset of its own.


static func apply(host: Object, args: PackedStringArray) -> void:
	var ref: ScenarioReference = parse_scenario_arg(args)
	if ref == null:
		return
	if not host.has_method("apply_dev_scenario"):
		push_error("host cannot apply a Development Scenario")
		return
	host.call("apply_dev_scenario", ref)


static func parse_scenario_arg(args: PackedStringArray) -> ScenarioReference:
	var found: bool = false
	var raw: String = ""
	for arg: String in args:
		if arg.begins_with("--scenario="):
			found = true
			raw = arg.trim_prefix("--scenario=")
			break
	if not found:
		return null
	var ref: ScenarioReference = ScenarioReference.new()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		ref.error = "Scenario reference is unreadable"
		return ref
	var blob: Dictionary = parsed
	if not blob.has("seed") and not blob.has("overrides"):
		_fill_catalogue_recipe(blob)
	ref.load_from(blob)
	return ref


## Id-only references resolve against catalogue ENTRIES. Named recipes live
## here, not in ScenarioReference — that type only holds the id→revision contract.
static func _fill_catalogue_recipe(blob: Dictionary) -> void:
	var entry: Dictionary = _catalogue_entry(str(blob.get("id", "")))
	if entry.is_empty():
		return
	blob["seed"] = int(float(str(entry.get("seed", 0))))
	var ov_v: Variant = entry.get("overrides", {})
	var ov: Dictionary = ov_v if typeof(ov_v) == TYPE_DICTIONARY else {}
	blob["overrides"] = ov.duplicate(true)


static func _catalogue_entry(id: String) -> Dictionary:
	var script: GDScript = load("res://presentation/dev/catalogue.gd") as GDScript
	if script == null:
		return {}
	var rows_v: Variant = script.get("ENTRIES")
	if typeof(rows_v) != TYPE_ARRAY:
		return {}
	var rows: Array = rows_v
	for row_v: Variant in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		if str(row.get("id", "")) == id:
			return row
	return {}
