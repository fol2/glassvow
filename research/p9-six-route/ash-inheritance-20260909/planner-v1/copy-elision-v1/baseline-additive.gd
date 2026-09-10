extends "res://policy_buggy_v9.gd"
## Resource candidates pay the native spend; the fallback controller can price it.

func score(g: GlassvowGame,c: CardInst,d: Dictionary,target: Variant,art: bool) -> float:
 var effective: Dictionary=d.duplicate(true)
 var converted: Array=[]
 for fx: Dictionary in d.get("effects",[]):
  if fx.get("kind")=="special" and fx.get("id")=="heldEmberWard":
   var n: int=ji(fx.get("n",0))+maxi(0,g.cb.embers-ji(fx.get("reserve",0)))*ji(fx.get("per",0))
   converted.append({"kind":"block","n":n})
  elif fx.get("kind")=="special" and fx.get("id")=="catalyst" and ji(fx.get("bonus",0))>0 and target!=null:
   var base: int=ji(fx.get("n",0))
   var n: int=base+mini(g.cb.embers,maxi(0,ji(fx.get("bonus",0))))
   converted.append({"kind":"special","id":"catalyst","n":n})
  else:converted.append(fx)
 effective["effects"]=converted
 # v9 already prices its fixed reserve for Phantom/Nova; feed their paid result
 # to the original generic policy to avoid subtracting a second time.
 var needs_reserve: bool=false
 if not art:
  for fx: Dictionary in effective.get("effects",[]):
   if fx.get("kind")=="special" and fx.get("id") in ["phantom","emberNova"] and ji(fx.get("reserve",0))>0:
    needs_reserve=true
 if needs_reserve:
  var effects: Array=[]
  for fx: Dictionary in effective.get("effects",[]):
   if fx.get("kind")=="special" and fx.get("id")=="phantom":
    var paid: int=maxi(0,g.cb.hand.size()-1-ji(fx.get("reserve",0)))
    effects.append({"kind":"dmg","n":ji(fx.get("n",0))*paid})
   elif fx.get("kind")=="special" and fx.get("id")=="emberNova":
    var paid: int=maxi(0,g.cb.embers-ji(fx.get("reserve",0)))
    effects.append({"kind":"dmg","n":ji(fx.get("n",0))*paid})
   else:effects.append(fx)
  effective["effects"]=effects
 return super.score(g,c,effective,target,art)

func draft(g: GlassvowGame,d: Dictionary,id: String="",acquire: bool=false) -> float:
 var effective: Dictionary=d.duplicate(true)
 var effects: Array=[]
 for fx: Dictionary in d.get("effects",[]):
  if fx.get("kind")=="special" and fx.get("id")=="heldEmberWard":effects.append({"kind":"block","n":ji(fx.get("n",0))+2*ji(fx.get("per",0))})
  else:effects.append(fx)
 effective["effects"]=effects
 var value: float=super.draft(g,effective,id,acquire)
 if id=="banklight" and route=="ember":value+=12.0
 for fx: Dictionary in d.get("effects",[]):
  if fx.get("kind")=="special" and fx.get("id")=="catalyst" and ji(fx.get("bonus",0))>0:value+=float(ji(fx.get("bonus",0)))*3.0
 return value
