class_name ScenarioReference
extends RefCounted
## Portable Scenario identity: `scenario-id@revision`, build SHA, seed, locale,
## Stage shape and bounded Custom Scenario overrides. Never a save blob.

## Named recipes live in presentation/dev/catalogue.gd; this map is id → revision.
const CATALOGUE: Dictionary = {
	"custom": 1,
	"title-continue": 1,
	"act-1-map-start": 1,
	"act-1-map-branch": 1,
	"act-1-map-terminus": 1,
	"act-2-map-start": 1,
	"act-2-map-branch": 1,
	"act-2-map-terminus": 1,
	"act-3-map-start": 1,
	"act-3-map-branch": 1,
	"act-3-map-terminus": 1,
	"combat-normal": 1,
	"combat-elite": 1,
	"combat-boss": 1,
	"combat-low-hp": 1,
	"shop-stocked": 1,
	"shop-insufficient-funds": 1,
	"rest": 1,
	"event": 1,
	"treasure": 1,
}
const LOCALES: PackedStringArray = ["en", "zh-Hant"]
const OVERRIDE_KEYS: PackedStringArray = [
	"aspect", "vow", "act", "node", "kind", "enemies",
	"hp", "max_hp", "gold", "potions",
	"add_cards", "remove_cards", "upgrade_cards",
	"add_relics", "remove_relics",
]

var error: String = ""
var scenario_id: String = "custom"
var revision: int = 1
var build: String = ""
var seed: int = 0
var locale: String = ""
var shape: String = "pad-landscape"
var overrides: Dictionary = {}


func identity() -> String:
	return "%s@%d" % [scenario_id, revision]


func encode() -> Dictionary:
	return {
		"id": scenario_id,
		"revision": revision,
		"build": build,
		"seed": seed,
		"locale": locale,
		"shape": shape,
		"overrides": overrides.duplicate(true),
	}


func load_from(raw: Dictionary) -> bool:
	error = ""
	if raw.has("player") or raw.has("rngState") or raw.has("pendingCombat") \
			or int(float(str(raw.get("v", 0)))) == RunState.SAVE_VERSION:
		error = "Scenario reference must not carry a save blob"
		return false
	var id: String = str(raw.get("id", ""))
	var rev: int = int(float(str(raw.get("revision", -1))))
	if raw.has("identity"):
		var parsed: PackedStringArray = str(raw["identity"]).split("@")
		if parsed.size() != 2 or not parsed[1].is_valid_int():
			error = "invalid Scenario identity %s" % raw["identity"]
			return false
		id = parsed[0]
		rev = int(parsed[1])
	if id.is_empty():
		error = "Scenario identity is missing"
		return false
	if not CATALOGUE.has(id):
		error = "unknown Scenario %s" % id
		return false
	var rv_check: int = int(float(str(CATALOGUE[id])))
	if rv_check != rev:
		error = "unsupported revision %s@%d" % [id, rev]
		return false
	var loc: String = str(raw.get("locale", ""))
	if not loc.is_empty() and not LOCALES.has(loc):
		error = "unsupported locale %s" % loc
		return false
	var shape_name: String = str(raw.get("shape", String(StageShape.IDENTITY)))
	if not StageShape.REFERENCES.has(StringName(shape_name)):
		error = "unknown Stage shape %s" % shape_name
		return false
	var ov_v: Variant = raw.get("overrides", {})
	if typeof(ov_v) != TYPE_DICTIONARY:
		error = "overrides must be a Dictionary"
		return false
	var ov: Dictionary = ov_v
	for key_v: Variant in ov.keys():
		if not OVERRIDE_KEYS.has(str(key_v)):
			error = "Custom Scenario does not expose %s" % key_v
			return false
	scenario_id = id
	revision = rev
	build = str(raw.get("build", ""))
	seed = int(float(str(raw.get("seed", 0))))
	locale = loc
	shape = shape_name
	overrides = ov.duplicate(true)
	return true
