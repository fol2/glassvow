extends "res://rollout_policy.gd"
## A native-confirmed terminal extension at the sampled leaf.
## This is a bounded public-state forecast, not an optimal-play certificate.
var terminal_probes: int=0
var terminal_hits: int=0
func one_action_terminal(g: GlassvowGame) -> Dictionary:
 if g.cb.over:return {}
 var living: Array[EnemyCombatant]=g.cb.living_enemies()
 if living.is_empty():return {}
 for card: CardInst in g.cb.hand:
  var d: Dictionary=g.rules.card_data(card)
  var targeting: String=str(d.get("target",""))
  if targeting!="enemy" and targeting!="allEnemies":continue
  if targeting=="enemy" and living.size()!=1:continue
  var target: Variant=living[0].idx if targeting=="enemy" else null
  if not g.rules.can_play(g.run,g.cb,card,target):continue
  # Preview only selects work. Actual native terminal state is the authority.
  var plausible: bool=true
  for enemy: EnemyCombatant in living:
   var pv: Variant=g.rules.preview_play(g.cb,card,enemy.idx,g.run)
   if typeof(pv)!=TYPE_DICTIONARY or not pv.get("lethal",false):
    plausible=false;break
  if not plausible:continue
  var model: GlassvowGame=Cloner.clone_public(g,0)
  var command: Dictionary={"t":"playCard","uid":card.uid,"target":target}
  model.apply(command);terminal_probes+=1
  if model.last_ret==true and model.cb.over and model.cb.result=="win" and model.cb.player.hp>0:
   terminal_hits+=1
   return {"command":command,"value":1000000.0+10.0*model.cb.player.hp}
 return {}
func future_value(g: GlassvowGame) -> float:
 if g.cb.over or not params.get("leaf_terminal",false):return super.future_value(g)
 var terminal: Dictionary=one_action_terminal(g)
 return float(terminal.value) if not terminal.is_empty() else super.future_value(g)
