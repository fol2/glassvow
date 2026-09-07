extends CombatRules
## Only used in disposable observational clones, never by the live controller.
var erased_consumer: String=""
func card_data(inst: CardInst) -> Dictionary:
 var d: Dictionary=super.card_data(inst)
 if erased_consumer in ["multihit","handstock"]:
  d=d.duplicate(true)
  for fx: Dictionary in d.get("effects",[]):
   if erased_consumer=="multihit" and fx.get("kind")=="dmg":
    fx["n"]=_ji(fx["n"])*_ji(fx.get("times",1));fx["times"]=1
   elif erased_consumer=="handstock" and fx.get("id")=="phantom":
    # Retain the below-reserve base payoff; remove the above-reserve consumer.
    fx["n"]=0
 return d
func _apply_special(run: RunState,cb: CombatState,inst: CardInst,fx: Dictionary,target: EnemyCombatant,damage_mult: int) -> void:
 if erased_consumer=="growth" and fx.get("id")=="momentum":
  hit_enemy(run,cb,target,_ji(fx["n"]),true,damage_mult)
  inst.bonus+=_ji(fx.get("grow",0))
  return
 super._apply_special(run,cb,inst,fx,target,damage_mult)
