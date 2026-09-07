extends "res://terminal_policy.gd"
## Optional research leaf valuation: do not subtract past turns from a new horizon.
func future_value(g: GlassvowGame) -> float:
 var base: float=super.future_value(g)
 if g.cb.over or not params.get("rolling_growth",false):return base
 var old_circ: float=clampf(cycle_repeats(g)-0.3*maxi(0,g.cb.turn-1),0,2)
 var new_circ: float=clampf(cycle_repeats(g),0,2)
 var growth: float=0.0
 for zone: Array in [g.cb.hand,g.cb.draw,g.cb.discard]:
  for card: CardInst in zone:growth+=card.bonus
 return base+growth*(new_circ-old_circ)*0.8
