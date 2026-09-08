extends CombatRules
## Research-only consumer intervention. Never substituted into frozen validation.
## Keep hit topology; remove strength only from additional hits on each target.
var remove_amplification: bool = false
var in_multihit: bool = false
var target_hits: Dictionary = {}

func _apply_effect(run: RunState, cb: CombatState, inst: CardInst, d: Dictionary,
	fx: Dictionary, target: EnemyCombatant, damage_mult: int = 1) -> void:
	var previous: bool = in_multihit
	var previous_hits: Dictionary = target_hits
	in_multihit = remove_amplification and fx.get("kind") == "dmg" and _ji(fx.get("times", 1)) > 1
	target_hits = {}
	super._apply_effect(run, cb, inst, d, fx, target, damage_mult)
	in_multihit = previous
	target_hits = previous_hits

func hit_enemy(run: RunState, cb: CombatState, e: EnemyCombatant, base: int,
	is_attack: bool = true, damage_mult: int = 1) -> int:
	var adjusted: int = base
	if in_multihit and is_attack:
		var index: int = int(target_hits.get(e.idx, 0))
		target_hits[e.idx] = index + 1
		if index > 0:
			adjusted -= _sget(cb.player.statuses, "str")
	return super.hit_enemy(run, cb, e, adjusted, is_attack, damage_mult)
