extends CombatRules
## Disposable post-decision clones only; never installed in a live policy.
var erased_consumer: String=""
func card_data(inst: CardInst) -> Dictionary:
 var d: Dictionary=super.card_data(inst)
 if erased_consumer in ["multihit","handstock","catalyst","chip_supply"]:
  d=d.duplicate(true)
  if erased_consumer=="chip_supply":d["chip"]=0
  for fx: Dictionary in d.get("effects",[]):
   if erased_consumer=="multihit" and fx.get("kind")=="dmg":
    fx["n"]=_ji(fx["n"])*_ji(fx.get("times",1));fx["times"]=1
   elif erased_consumer=="handstock" and fx.get("id")=="phantom":
    fx["n"]=0 # Preserve floor_per and every below-reserve term.
   elif erased_consumer=="catalyst" and fx.get("id")=="catalyst":
    fx["n"]=1;fx["bonus"]=0
   elif erased_consumer=="chip_supply" and fx.get("kind")=="chip":
    fx["n"]=0
 return d
func _apply_special(run: RunState,cb: CombatState,inst: CardInst,fx: Dictionary,target: EnemyCombatant,damage_mult: int) -> void:
 if erased_consumer=="growth" and fx.get("id")=="momentum":
  hit_enemy(run,cb,target,_ji(fx["n"]),true,damage_mult)
  inst.bonus+=_ji(fx.get("grow",0))
  return
 if erased_consumer=="echo" and fx.get("id")=="shatterEcho":
  hit_enemy(run,cb,target,_ji(fx["n"]),true,damage_mult)
  return
 super._apply_special(run,cb,inst,fx,target,damage_mult)
