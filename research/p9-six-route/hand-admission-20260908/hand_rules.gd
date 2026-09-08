extends CombatRules
## Research-only component interventions; omitted/zero mask delegates unchanged.
## Bits: draw=1, Energy=2, above-reserve Phantom payoff=4. Ash only.
## Producer costs, Exhaust, relic hooks, ordinary chips and all other effects stay native.
var intervention_mask: int = 0
var effect_observations: Array = []

func _apply_effect(run: RunState, cb: CombatState, inst: CardInst,
		d: Dictionary, fx: Dictionary, target: EnemyCombatant, damage_mult: int = 1) -> void:
	var kind: String = str(fx.get("kind", ""))
	var historical_supplier: bool = String(inst.id) in ["preparation", "surge"]
	var suppress: bool = run.aspect == 1 and historical_supplier and (
		(kind == "draw" and (intervention_mask & 1) != 0) or
		(kind == "energy" and (intervention_mask & 2) != 0))
	var before: Array = []
	for card: CardInst in cb.hand:
		before.append(card.uid)
	var energy_before: int = cb.player.energy
	var queue_start: int = cb.queue.size()
	if not suppress:
		super._apply_effect(run, cb, inst, d, fx, target, damage_mult)
	var after: Array = []
	for card: CardInst in cb.hand:
		after.append(card.uid)
	effect_observations.append({"kind":"effect", "uid":inst.uid, "card":String(inst.id),
		"effect":fx.duplicate(true), "suppressed":suppress, "before_hand":before,
		"after_hand":after, "before_energy":energy_before, "after_energy":cb.player.energy,
		"event_start":queue_start, "event_end":cb.queue.size(), "turn":cb.turn})

func _apply_special(run: RunState, cb: CombatState, inst: CardInst,
		fx: Dictionary, target: EnemyCombatant, damage_mult: int) -> void:
	if fx.get("id", "") != "phantom":
		super._apply_special(run, cb, inst, fx, target, damage_mult)
		return
	var delivered: Dictionary = fx
	var suppress: bool = run.aspect == 1 and (intervention_mask & 4) != 0
	if suppress:
		delivered = fx.duplicate(true)
		delivered["n"] = 0
	var q: int = cb.hand.size()
	effect_observations.append({"kind":"phantom", "uid":inst.uid, "turn":cb.turn,
		"q_after_removal":q, "effect":fx.duplicate(true), "suppressed":suppress,
		"factual_raw":resource_payoff(q, fx), "delivered_raw":resource_payoff(q, delivered),
		"target":target.idx if target != null else -1,
		"event_start":cb.queue.size()})
	super._apply_special(run, cb, inst, delivered, target, damage_mult)
