class_name PlayerCombatant
extends RefCounted
## The hero's combat-scoped mutable state. Statuses map String id -> int stacks;
## a status never sits at 0 (it is erased instead), mirroring the web engine.


var hp: int = 0
var max_hp: int = 0
var block: int = 0
var energy: int = 0
var energy_max: int = 0
var statuses: Dictionary = {}
## Research-only, combat-local and omitted from the product projection.
var research421_ember_overflow: int = 0


func to_dict() -> Dictionary:
	return {
		"hp": hp,
		"maxHp": max_hp,
		"block": block,
		"energy": energy,
		"energyMax": energy_max,
		"statuses": statuses.duplicate(),
	}
