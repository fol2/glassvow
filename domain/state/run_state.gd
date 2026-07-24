class_name RunState
extends RefCounted
## Run-scoped state the combat core reads and writes. M3 carries the minimal
## surface the recorded slice traces exercise; map/rewards/saves land in M4.
## The one rng stream: every draw goes through `rng`, whose signed 32-bit
## state is the fixture `rngState` cursor.


## Persistent run-scoped hero state (web run.player).
class Player:
	var hp: int = 0
	var max_hp: int = 0
	var gold: int = 0
	var energy_max: int = 0
	var relics: Array[String] = []
	var potions: Array[String] = []  # "" == empty slot (fixture null)
	var deck: Array[CardInst] = []


var seed: int = 0
var rng: Rng = Rng.new(0)
var act: int = 0
var floors_climbed: int = 0
var aspect: int = 0
var vow: int = 0
var art: StringName = &""
var uid: int = 1
var player: Player = Player.new()


func rng_state() -> int:
	return rng.get_state()


func has_relic(relic_id: String) -> bool:
	return player.relics.has(relic_id)


## Post-increment uid allocator (web run.uid++).
func next_uid() -> int:
	var u: int = uid
	uid += 1
	return u


## Fixture projection (web exporter projectRunSnapshot).
func to_dict() -> Dictionary:
	var deck_out: Array = []
	for c: CardInst in player.deck:
		deck_out.append(c.to_dict())
	var potions_out: Array = []
	for p: String in player.potions:
		potions_out.append(null if p == "" else p)
	return {
		"seed": seed,
		"rngState": rng.get_state(),
		"act": act,
		"floorsClimbed": floors_climbed,
		"aspect": aspect,
		"vow": vow,
		"art": String(art),
		"player": {
			"hp": player.hp,
			"maxHp": player.max_hp,
			"gold": player.gold,
			"energyMax": player.energy_max,
			"relics": player.relics.duplicate(),
			"potions": potions_out,
			"deck": deck_out,
		},
	}
