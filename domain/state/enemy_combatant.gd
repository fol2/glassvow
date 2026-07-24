class_name EnemyCombatant
extends RefCounted
## One enemy's combat state. `def` is the resolved content definition
## (already-parsed data injected by the rules layer — no IO here).
## Slice scope: no variant/adamant/ramp flags; those land with the full
## content wave.


var key: StringName = &""
var def: Dictionary = {}
var idx: int = 0
var name: String = ""
var hp: int = 0
var max_hp: int = 0
var block: int = 0
var statuses: Dictionary = {}
var staggered: bool = false
var last_moves: Array[String] = []
var move_key: StringName = &""
var elite: bool = false
var boss: bool = false
var facet_max: int = 0
var chips: int = 0


## The move definition behind the current intent.
func move() -> Dictionary:
	var moves: Dictionary = def.get("moves", {})
	var mv: Dictionary = moves.get(String(move_key), {})
	return mv


func to_dict() -> Dictionary:
	return {
		"key": String(key),
		"idx": idx,
		"hp": hp,
		"maxHp": max_hp,
		"block": block,
		"chips": chips,
		"facetMax": facet_max,
		"moveKey": null if move_key == &"" else String(move_key),
		"statuses": statuses.duplicate(),
	}
