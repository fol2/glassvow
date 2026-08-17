class_name CombatState
extends RefCounted
## One combat (web cb). The rules layer mutates this and appends GameEvent
## Dictionaries to `queue`; presentation drains the queue and never owns truth.


var kind: StringName = &"normal"
var affix: StringName = &""  # &"" == none (fixture null)
var turn: int = 0
var over: bool = false
var result: String = ""  # "" | "win" | "loss" (fixture null | "win" | "loss")
var queue: Array[Dictionary] = []
var player: PlayerCombatant = PlayerCombatant.new()
var enemies: Array[EnemyCombatant] = []
var draw: Array[CardInst] = []
var hand: Array[CardInst] = []
var discard: Array[CardInst] = []
var exhaust: Array[CardInst] = []
var embers: int = 0
var ember_cap: int = 9
var art_used_turn: int = 0
var kindled_turn: int = 0
var kindles_this_turn: int = 0
## Facet chips owed while a card resolves: enemy idx -> {"hit": bool, "extra": int}.
## Only "active" during play_card (web pendingChips Map vs null).
var pending_chips_active: bool = false
var pending_chips: Dictionary = {}
var counters_played: int = 0
var counters_attacks: int = 0
var first_card_played: bool = false
var hp_lost: int = 0
var prism_procd: bool = false
## True when the Eternal Keeper's lethal threshold handed the fight to #312.
var finale_handoff: bool = false


func living_enemies() -> Array[EnemyCombatant]:
	var out: Array[EnemyCombatant] = []
	for e: EnemyCombatant in enemies:
		if e.hp > 0:
			out.append(e)
	return out


## Fixture projection (web exporter projectCombatSnapshot).
func to_dict() -> Dictionary:
	var enemies_out: Array = []
	for e: EnemyCombatant in enemies:
		enemies_out.append(e.to_dict())
	return {
		"kind": String(kind),
		"affix": null if affix == &"" else String(affix),
		"turn": turn,
		"over": over,
		"result": null if result == "" else result,
		"embers": embers,
		"player": player.to_dict(),
		"enemies": enemies_out,
		"hand": _cards(hand),
		"draw": _cards(draw),
		"discard": _cards(discard),
		"exhaust": _cards(exhaust),
	}


static func _cards(arr: Array[CardInst]) -> Array:
	var out: Array = []
	for c: CardInst in arr:
		out.append(c.to_dict())
	return out
