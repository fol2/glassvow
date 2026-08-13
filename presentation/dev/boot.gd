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
	ref.load_from(blob)
	return ref
