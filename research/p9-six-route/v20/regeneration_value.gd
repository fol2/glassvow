extends "res://greedy_ramp.gd"
## Explicit recurring-heal valuation hypothesis, tested against legacy on the same content.
## Six expected ticks is a controller forecast, not known future game information.
func draft(g: GlassvowGame,d: Dictionary,id: String,acquire: bool=true) -> float:
 var value: float=super.draft(g,d,id,acquire)
 var horizon: float=float(params.get("regeneration_horizon",0))
 if horizon<=0:return value
 for fx: Dictionary in d.get("effects",[]):
  if fx.get("kind")=="status" and fx.get("who")=="self" and fx.get("id")=="regen":
   # Replace the legacy five-value coefficient with 2 HP-value * forecast ticks.
   value+=float(fx.n)*(2.0*horizon-5.0)
 return value
