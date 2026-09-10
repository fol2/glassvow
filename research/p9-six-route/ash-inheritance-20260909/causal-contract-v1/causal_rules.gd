extends CombatRules
## Controlled command-sequence instrument, NOT an adaptive gameplay controller.
## Disabled pathways receive no compensation. HP cost and all ordinary hooks remain.
var source_uid: int = 900
var consumer_uid: int = 901
var energy_path: bool = true
var mediator_path: bool = true
var consumer_path: bool = true
var source_id: String = ""

func configure(id: String, energy: bool, mediator: bool, consumer: bool) -> void:
	source_id = id
	energy_path = energy
	mediator_path = mediator
	consumer_path = consumer
	bloodfire_producer_enabled = mediator if id == "bloodRite" else true
	bloodfire_consumer_enabled = consumer if id == "bloodRite" else true

func _apply_effect(run: RunState, cb: CombatState, inst: CardInst, d: Dictionary,
		fx: Dictionary, target: EnemyCombatant, damage_mult: int = 1) -> void:
	if inst != null and inst.uid == source_uid:
		var kind: String = str(fx.get("kind", ""))
		if kind == "energy" and not energy_path:
			return
		if kind == "draw" and source_id != "bloodRite" and not mediator_path:
			return
	super._apply_effect(run, cb, inst, d, fx, target, damage_mult)

func _apply_special(run: RunState, cb: CombatState, inst: CardInst, fx: Dictionary,
		target: EnemyCombatant, damage_mult: int) -> void:
	if source_id != "bloodRite" and inst != null and inst.uid == consumer_uid \
			and str(fx.get("id", "")) == "phantom" and not consumer_path:
		# Suppress the hand-count coefficient, not the hit, Strength, hooks or payment.
		var disabled: Dictionary = fx.duplicate(true)
		disabled["n"] = 0
		super._apply_special(run, cb, inst, disabled, target, damage_mult)
		return
	super._apply_special(run, cb, inst, fx, target, damage_mult)
