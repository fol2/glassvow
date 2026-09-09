extends CombatRules
## Component contrasts only. Stock content/dispatch are never edited.
## Mask 1 removes the named producer's mediator effect, not its costs/hooks.
## Mask 2 removes amplification, keeping attack hit count or Catalyst's lifecycle.
var family: String = ""
var mask: int = 0
var repeat_hit: bool = false
var hit_indices: Dictionary = {}

func _apply_effect(run: RunState, cb: CombatState, inst: CardInst,
		d: Dictionary, fx: Dictionary, target: EnemyCombatant, damage_mult: int = 1) -> void:
	var scope: bool = (family == "fervor" and run.aspect == 0) or (family == "smolder" and run.aspect == 1)
	var producer: bool = (family == "fervor" and inst.id == &"empower" and fx.get("id") == "str") or (family == "smolder" and inst.id == &"venomStrike" and fx.get("id") == "poison")
	if scope and (mask & 1) != 0 and producer and fx.get("kind") == "status":
		return
	var old_repeat: bool = repeat_hit
	var old_indices: Dictionary = hit_indices
	repeat_hit = scope and family == "fervor" and (mask & 2) != 0 and inst.id == &"flurry" and fx.get("kind") == "dmg"
	hit_indices = {}
	super._apply_effect(run, cb, inst, d, fx, target, damage_mult)
	repeat_hit = old_repeat
	hit_indices = old_indices

func hit_enemy(run: RunState, cb: CombatState, e: EnemyCombatant, base: int,
		is_attack: bool = true, damage_mult: int = 1) -> int:
	var delivered: int = base
	if repeat_hit and is_attack:
		var i: int = int(hit_indices.get(e.idx, 0))
		hit_indices[e.idx] = i + 1
		if i > 0:
			delivered -= _sget(cb.player.statuses, "str")
	return super.hit_enemy(run, cb, e, delivered, is_attack, damage_mult)

func _apply_special(run: RunState, cb: CombatState, inst: CardInst,
		fx: Dictionary, target: EnemyCombatant, damage_mult: int) -> void:
	if family == "smolder" and run.aspect == 1 and (mask & 2) != 0 and fx.get("id") == "catalyst":
		# Remove the amplifier operation, not Exhaust/Ember/Branch or target checks.
		# Do not emit a fabricated zero-status event for the null consumer.
		return
	super._apply_special(run, cb, inst, fx, target, damage_mult)
