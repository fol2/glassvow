class_name CardInst
extends RefCounted
## One owned copy of a card: deck entries and in-combat instances.
## `bonus` is combat-scoped growth (momentum); deck copies keep it 0.


var uid: int = 0
var id: StringName = &""
var up: bool = false
var bonus: int = 0


func _init(uid_: int, id_: StringName, up_: bool = false) -> void:
	uid = uid_
	id = id_
	up = up_


## Fresh combat instance of a deck card (web: `{ ...c, bonus: 0 }`).
func combat_copy() -> CardInst:
	return CardInst.new(uid, id, up)


## Fixture projection (web exporter projectCardInst): up/bonus only when set.
func to_dict() -> Dictionary:
	var out: Dictionary = {"id": String(id), "uid": uid}
	if up:
		out["up"] = true
	if bonus != 0:
		out["bonus"] = bonus
	return out
