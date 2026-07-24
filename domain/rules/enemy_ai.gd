class_name EnemyAi
extends RefCounted
## Per-enemy move selection — byte-faithful ports of the web engine's AI closures
## (roguecardv2 packs/core enemies). The number AND order of RNG draws must match
## the source so recorded combat traces replay identically; parity is checked in
## tests/test_enemy_ai.gd via rng.get_state() equality (a Mulberry32 state bijection).
##
## Slice scope: sporeling, duskfang, waylayer, gravewarden. The remaining 23
## species (+ shade/sovereign) land alongside the full content wave, post-slice.

const SLICE_IDS: Array[StringName] = [&"sporeling", &"duskfang", &"waylayer", &"gravewarden"]


## True when this module implements an AI for `id` (the ContentDB handler check).
static func handles(id: StringName) -> bool:
	return SLICE_IDS.has(id)


## Chosen move key. `last`/`prev` are prior move keys ("" == the JS `null`).
## `_prev`/`_hp_frac` are unused by the slice species but are part of the closure
## contract the remaining enemies consume.
static func decide(
	id: StringName, turn: int, last: String, _prev: String, _hp_frac: float, rng: Rng
) -> StringName:
	match id:
		&"sporeling":
			# ({ turn }) => turn % 3 === 2 ? 'grow' : 'spit'   — 0 draws
			return &"grow" if turn % 3 == 2 else &"spit"
		&"gravewarden":
			# ({ turn }) => ['entomb','crush','bulwark','crush'][(turn-1) % 4]  — 0 draws
			var seq: Array[StringName] = [&"entomb", &"crush", &"bulwark", &"crush"]
			return seq[(turn - 1) % 4]
		&"duskfang":
			# turn 1 => howl; else the rng.next() draw fires ONLY when last != 'howl'
			if turn == 1:
				return &"howl"
			if last != "howl" and rng.next() < 0.18:
				return &"howl"
			return &"rend" if last == "bite" else &"bite"
		&"waylayer":
			# turn 1 => trick; 1st draw always; 2nd draw only when 1st was >= 0.55
			if turn == 1:
				return &"trick"
			if rng.next() < 0.55:
				return &"stab"
			if rng.next() < 0.5:
				return &"smoke"
			return &"trick"
	push_error("EnemyAi.decide: unhandled enemy id %s" % id)
	return &""
