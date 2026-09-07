extends "res://greedy_echo_reference.gd"
## Current-state translation only; no new acquisition prior.
func score(g: GlassvowGame,c: CardInst,d: Dictionary,target: Variant,art: bool) -> float:
 var effective: Dictionary=d
 if not art and target!=null:
  var effects: Array=[]
  var changed: bool=false
  var enemy: EnemyCombatant=g.cb.enemies[ji(target)]
  for fx: Dictionary in d.get("effects",[]):
   if fx.get("kind")=="special" and fx.get("id")=="shatterEcho":
    var mult: int=ji(fx.get("staggeredMult",2)) if enemy.staggered else (2 if si(enemy.statuses,"vulnerable")>0 else 1)
    effects.append({"kind":"dmg","n":ji(fx.n)*mult})
    changed=true
   else:effects.append(fx)
  if changed:effective=d.duplicate(true);effective.effects=effects
 return super.score(g,c,effective,target,art)
