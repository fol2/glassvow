extends CombatRules
## Exactly equivalent effect expansion inside ONE native card envelope.
## This is an executable decomposition witness, not a product or balance change.
var family: String = ""
var mask: int = 0

func _apply_effect(run: RunState, cb: CombatState, inst: CardInst,
		d: Dictionary, fx: Dictionary, target: EnemyCombatant, damage_mult: int = 1) -> void:
	if family == "fervor" and inst.id == &"flurry" and fx.get("kind") == "dmg":
		var single: Dictionary = fx.duplicate(true)
		single["times"] = 1
		for _hit: int in range(_ji(fx.get("times", 1))):
			if cb.over:
				return
			super._apply_effect(run, cb, inst, d, single, target, damage_mult)
		return
	super._apply_effect(run, cb, inst, d, fx, target, damage_mult)

func _apply_special(run: RunState, cb: CombatState, inst: CardInst,
		fx: Dictionary, target: EnemyCombatant, damage_mult: int) -> void:
	if family == "smolder" and inst.id == &"catalyst" and fx.get("id") == "catalyst":
		# Legal Catalyst entry has a live target. Preserve stock fallback outside it.
		if target == null or target.hp <= 0:
			super._apply_special(run, cb, inst, fx, target, damage_mult)
			return
		var q: int = _sget(target.statuses, "poison")
		if q > 0:
			var increment: Dictionary = {"kind":"status","id":"poison","who":"enemy","n":q * (_ji(fx["n"]) - 1)}
			super._apply_effect(run, cb, inst, {"target":"enemy"}, increment, target, damage_mult)
		return
	super._apply_special(run, cb, inst, fx, target, damage_mult)
