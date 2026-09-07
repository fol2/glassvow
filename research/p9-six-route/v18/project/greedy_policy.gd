extends "res://policy_buggy_v9.gd"
## A resource-scaled special enters the evaluator as its actual raw damage.
## The content and native state are untouched. Reserve=0 preserves v9 exactly.
func score(g: GlassvowGame,c: CardInst,d: Dictionary,target: Variant,art: bool) -> float:
 var effective: Dictionary=d.duplicate(true)
 var converted: Array=[]
 for fx: Dictionary in effective.get("effects",[]):
  if fx.get("kind")=="special" and fx.get("id")=="heldEmberWard":
   converted.append({"kind":"block","n":ji(fx.n)+ji(fx.per)*maxi(0,g.cb.embers-ji(fx.get("reserve",4)))})
  elif fx.get("kind")=="special" and fx.get("id")=="catalyst" and ji(fx.get("bonus",0))>0 and target!=null:
   var e: EnemyCombatant=g.cb.enemies[ji(target)];var q: int=si(e.statuses,"poison")
   converted.append({"kind":"status","who":"target","id":"poison","n":q*(ji(fx.n)-1)+ji(fx.bonus) if q>0 else 0})
  else:converted.append(fx)
 effective["effects"]=converted
 var needs_reserve: bool=false
 if not art:
  for fx: Dictionary in effective.get("effects",[]):
   if fx.get("kind")=="special" and fx.get("id") in ["phantom","emberNova"] and ji(fx.get("reserve",0))>0:
    needs_reserve=true
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

func draft(g: GlassvowGame,d: Dictionary,id: String,acquire: bool=true) -> float:
 var effective: Dictionary=d.duplicate(true)
 var effects: Array=[]
 for fx: Dictionary in effective.get("effects",[]):
  if fx.get("kind")=="special" and fx.get("id")=="heldEmberWard":
   effects.append({"kind":"block","n":float(fx.n)+float(fx.per)*maxf(0,expected_embers(g)-float(fx.get("reserve",4)))})
  else:effects.append(fx)
 effective["effects"]=effects
 var value: float=super.draft(g,effective,id,acquire)
 if id=="banklight" and route=="ember":value+=float(params.get("banklight_fit",12))
 for fx: Dictionary in d.get("effects",[]):
  if fx.get("kind")=="special" and fx.get("id")=="catalyst" and ji(fx.get("bonus",0))>0:
   value+=float(fx.bonus)*minf(1,float(features(g).poison)/8.0)
 return value
