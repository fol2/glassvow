extends "res://greedy_stock.gd"
## Expose the native capped debit to continuation scoring; native rollout pays it.
func score(g: GlassvowGame, c: CardInst, d: Dictionary, target: Variant, art: bool) -> float:
 var adjusted: Dictionary=d
 var debit: int=0
 for fx: Dictionary in d.get("effects",[]):
  if fx.get("kind")=="special" and fx.get("id")=="emberNova":
   debit+=mini(g.cb.embers,maxi(0,ji(fx.get("consumeEmbers",0))))
 if debit>0:
  adjusted=d.duplicate(true)
  adjusted.effects.append({"kind":"ember","n":-debit})
 return super.score(g,c,adjusted,target,art)
