class_name EnemyAi
extends RefCounted
## Per-enemy move selection — byte-faithful ports of the web engine's AI closures
## (roguecardv2 packs/core enemies). The number AND order of RNG draws must match
## the source so recorded combat traces replay identically; parity is checked in
## tests/test_enemy_ai.gd via rng.get_state() equality (a Mulberry32 state bijection).
##
const ALL_IDS: Array[StringName] = [
	&"sporeling", &"duskfang", &"gloomslime", &"waylayer", &"thornling",
	&"ashAcolyte", &"gravewarden", &"alphaFang", &"rootheart", &"drownedOne",
	&"voltEel", &"mirelurker", &"tidecaller", &"shellback", &"deepmaw",
	&"abyssalKnight", &"siren", &"leviathan", &"voidWisp", &"obsidianGolem",
	&"starCultist", &"shade", &"chaosHound", &"watcherEye", &"voidColossus",
	&"heraldOfEnd", &"sovereign", &"eternalKeeper", &"unwalkedSelf",
	&"uncrossedSelf", &"unopenedSelf", &"unlitSelf", &"unsunkSelf",
	&"uncarvedSelf", &"unobsidianSelf",
]


## True when this module implements an AI for `id` (the ContentDB handler check).
static func handles(id: StringName) -> bool:
	return ALL_IDS.has(id)


## Chosen move key. `last`/`prev` are prior move keys ("" == the JS `null`).
## `_prev`/`_hp_frac` are unused by the slice species but are part of the closure
## contract the remaining enemies consume.
static func decide(
	id: StringName, turn: int, last: String, _prev: String, hp_frac: float, rng: Rng,
	flags: Dictionary = {}
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
		&"gloomslime":
			var gloom: Array[StringName] = [&"ooze", &"slam", &"harden"]
			return gloom[(turn - 1) % 3]
		&"thornling":
			return &"burst" if turn % 4 == 0 else (&"prick" if turn % 2 == 1 else &"bristle")
		&"ashAcolyte", &"starCultist":
			return &"ritual" if turn == 1 else &"scorch"
		&"alphaFang":
			return &"howl" if turn == 1 or turn % 4 == 0 else (&"throat" if last == "savage" else &"savage")
		&"rootheart":
			if turn == 1:
				return &"awaken"
			if turn % 4 == 0:
				return &"slam"
			var roots: Array[StringName] = [&"lash", &"spores", &"entangle"]
			return roots[(turn - 2) % 3]
		&"drownedOne":
			if hp_frac < 0.5 and last != "frenzy":
				return &"frenzy"
			return &"claw" if rng.next() < 0.6 else &"gurgle"
		&"voltEel":
			var eel: Array[StringName] = [&"shock", &"coil", &"discharge"]
			return eel[(turn - 1) % 3]
		&"mirelurker":
			if turn % 3 == 0:
				return &"burrow"
			return &"sting" if rng.next() < 0.55 else &"barb"
		&"tidecaller":
			return &"surge" if turn == 1 else (&"undertow" if turn % 3 == 0 else &"bolt")
		&"shellback":
			var shell: Array[StringName] = [&"snap", &"shell", &"jet", &"shell"]
			return shell[(turn - 1) % 4]
		&"deepmaw":
			var maw: Array[StringName] = [&"lure", &"bite", &"swallow"]
			return maw[(turn - 1) % 3]
		&"abyssalKnight":
			var knight: Array[StringName] = [&"condemn", &"blade", &"oath", &"execute"]
			return knight[(turn - 1) % 4]
		&"siren":
			if hp_frac < 0.55 and last != "mend":
				return &"mend"
			var song: Array[StringName] = [&"song", &"rend", &"shriek"]
			return song[(turn - 1) % 3]
		&"leviathan":
			if turn == 1:
				return &"tide"
			if turn % 4 == 0:
				return &"cataclysm"
			var sea: Array[StringName] = [&"crush", &"brine", &"consume"]
			return sea[(turn - 2) % 3]
		&"voidWisp":
			return &"zap" if rng.next() < 0.6 else &"siphon"
		&"obsidianGolem":
			var golem: Array[StringName] = [&"pound", &"harden", &"quake"]
			return golem[(turn - 1) % 3]
		&"shade":
			if flags.get("shadeKit") == "duskblade":
				var dusk_shade: Array[StringName] = [&"eclipse", &"chisel", &"spark"]
				return dusk_shade[(turn - 1) % 3]
			if flags.get("shadeKit") == "ashwarden":
				var ash_shade: Array[StringName] = [&"ashbite", &"smother", &"ashfall"]
				return ash_shade[(turn - 1) % 3]
			if turn % 3 == 0:
				return &"vanish"
			return &"slash" if rng.next() < 0.5 else &"gloom"
		&"chaosHound":
			return &"howl" if turn % 4 == 0 else &"bite"
		&"watcherEye":
			var eye: Array[StringName] = [&"gaze", &"beam", &"blink"]
			return eye[(turn - 1) % 3]
		&"voidColossus":
			var colossus: Array[StringName] = [&"shatter", &"slam", &"fortify", &"slam"]
			return colossus[(turn - 1) % 4]
		&"heraldOfEnd":
			if turn % 4 == 0:
				return &"rise"
			var herald: Array[StringName] = [&"doom", &"reave", &"flame"]
			return herald[(turn - 1) % 3]
		&"unwalkedSelf":
			return _counterfactual_cycle(turn, flags, {
				"ember": [&"scepterEcho", &"starfallEcho", &"ringbreak"],
				"ash": [&"gravitasEcho", &"ruinEcho", &"ringward"],
			}, "unwalkedSelf")
		&"uncrossedSelf":
			return _counterfactual_cycle(turn, flags, {
				"brine": [&"brineBite", &"falseLamp", &"undertowEcho"],
				"shell": [&"closedShell", &"stillWater", &"librarySpine"],
			}, "uncrossedSelf")
		&"unopenedSelf":
			return _counterfactual_cycle(turn, flags, {
				"ember": [&"glassCut", &"shardVolley", &"sealBlow"],
				"ash": [&"roseWard", &"darkPane", &"reliefWait"],
			}, "unopenedSelf")
		&"unlitSelf":
			return _counterfactual_cycle(turn, flags, {
				"ashroot": [&"rootLash", &"greyAsh", &"stillRoot"],
				"lantern": [&"pairedDark", &"wickUnlit", &"lampWait"],
			}, "unlitSelf")
		&"unsunkSelf":
			return _counterfactual_cycle(turn, flags, {
				"ember": [&"tideCut", &"unreadVolley", &"brineWake"],
				"ash": [&"stackWard", &"stillTide", &"waitPage"],
			}, "unsunkSelf")
		&"uncarvedSelf":
			return _counterfactual_cycle(turn, flags, {
				"carve": [&"stoneCut", &"glyphVolley", &"sealCrack"],
				"door": [&"doorWard", &"darkStamp", &"waitStone"],
			}, "uncarvedSelf")
		&"unobsidianSelf":
			return _counterfactual_cycle(turn, flags, {
				"star": [&"starGaze", &"lightHang", &"eyeMeet"],
				"obsidian": [&"obsidianWard", &"darkHarden", &"courtWait"],
			}, "unobsidianSelf")
		&"eternalKeeper":
			if hp_frac <= 0.5 and not flags.get("keptFire", false):
				flags["keptFire"] = true
				return &"keepTheFire"
			if flags.get("keptFire", false):
				var phase_turn: int = int(float(str(flags.get("p2", 0)))) + 1
				flags["p2"] = phase_turn
				if phase_turn % 3 == 0:
					return &"neverLeave"
				var phase: Array[StringName] = [&"hearthBlow", &"cinderFall", &"kindWord", &"sitDown"]
				return phase[phase_turn % 4]
			var keeper: Array[StringName] = [&"hearthBlow", &"sitDown", &"cinderFall", &"kindWord"]
			return keeper[(turn - 1) % 4]
		&"sovereign":
			if hp_frac <= 0.5 and not flags.get("heldCourt", false):
				flags["heldCourt"] = true
				return &"holdCourt"
			if flags.get("heldCourt", false):
				var phase_turn: int = int(float(str(flags.get("p2", 0)))) + 1
				flags["p2"] = phase_turn
				if phase_turn % 3 == 0:
					return &"annihilation"
				var phase: Array[StringName] = [&"scepter", &"starfall", &"ruin", &"gravitas"]
				return phase[phase_turn % 4]
			var sovereign: Array[StringName] = [&"scepter", &"gravitas", &"starfall", &"ruin"]
			return sovereign[(turn - 1) % 4]
	push_error("EnemyAi.decide: unhandled enemy id %s" % id)
	return &""


static func _counterfactual_cycle(turn: int, flags: Dictionary, sequences: Dictionary,
		who: String) -> StringName:
	var kit: String = str(flags.get(CounterfactualSelf.KIT_FLAG, ""))
	if not sequences.has(kit):
		push_error("EnemyAi.decide: %s missing kit" % who)
		return &""
	var seq_v: Variant = sequences[kit]
	if typeof(seq_v) != TYPE_ARRAY:
		push_error("EnemyAi.decide: %s kit %s is not a sequence" % [who, kit])
		return &""
	var seq: Array = seq_v
	if seq.is_empty():
		push_error("EnemyAi.decide: %s kit %s is empty" % [who, kit])
		return &""
	return StringName(str(seq[(turn - 1) % seq.size()]))
