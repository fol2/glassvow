extends "res://policy_buggy_v9.gd"
## A resource-scaled special enters the evaluator as its actual raw damage.
## The content and native state are untouched. Reserve=0 preserves v9 exactly.
func score(g: GlassvowGame,c: CardInst,d: Dictionary,target: Variant,art: bool) -> float:
 var effective: Dictionary=d
 var needs_reserve: bool=false
 if not art:
  for fx: Dictionary in d.get("effects",[]):
   if fx.get("kind")=="special" and fx.get("id") in ["phantom","emberNova"] and ji(fx.get("reserve",0))>0:
    effective=d.duplicate(true);needs_reserve=true
    break
  if needs_reserve:
   var effects: Array=[]
   for fx: Dictionary in effective.get("effects",[]):
    if fx.get("kind")=="special" and fx.get("id") in ["phantom","emberNova"] and ji(fx.get("reserve",0))>0:
     var stock: int=maxi(0,g.cb.hand.size()-1) if fx.id=="phantom" else g.cb.embers
     effects.append({"kind":"dmg","n":ji(fx.n)*maxi(0,stock-ji(fx.reserve))})
    else:effects.append(fx)
   effective["effects"]=effects
 return super.score(g,c,effective,target,art)
