extends "res://greedy_policy.gd"
## Two public-information determinizations, native one-turn rollout.
## Not MCTS, optimality, P9 admission or protected-seed evidence.
const Cloner: GDScript=preload("res://public_rollout.gd")
const Greedy: GDScript=preload("res://greedy_policy.gd")
var last_alternatives: Array=[]
var rollout_count: int=0
func actions(g: GlassvowGame) -> Array[Dictionary]:
 var result: Array[Dictionary]=[{"t":"endTurn"}]
 for c: CardInst in g.cb.hand:
  var d: Dictionary=g.rules.card_data(c);var ts: Array=[null]
  if str(d.get("target",""))=="enemy":
   ts=[]
   for e: EnemyCombatant in g.cb.living_enemies():ts.append(e.idx)
  for t: Variant in ts:
   if g.rules.can_play(g.run,g.cb,c,t):result.append({"t":"playCard","uid":c.uid,"target":t})
 if g.rules.can_use_art(g.run,g.cb):result.append({"t":"useArt"})
 var worst: CardInst=null;var value: float=INF
 for c: CardInst in g.cb.hand:
  if g.rules.can_kindle(g.run,g.cb,c):
   var v: float=draft(g,g.rules.card_data(c),String(c.id),false)
   if v<value:value=v;worst=c
 if worst!=null:result.append({"t":"kindleFromHand","uid":worst.uid})
 return result
func future_value(g: GlassvowGame) -> float:
 if g.cb.over:
  return 1000000.0+10*g.cb.player.hp if g.cb.result=="win" else -1000000.0
 var p: PlayerCombatant=g.cb.player
 var result: float=7.0*p.hp+4.0*p.energy
 for e: EnemyCombatant in g.cb.enemies:
  if e.hp<=0:continue
  result-=e.hp
  var poison: int=si(e.statuses,"poison")
  result+=minf(e.hp,poison+maxi(0,poison-1)+maxi(0,poison-2))*0.8
  result-=non_damage_threat(g,e)*0.5
 var f: Dictionary=features(g)
 result+=si(p.statuses,"str")*clampf(2*float(f.hits)/maxf(1,float(f.attack)),2,8)
 result+=si(p.statuses,"dex")*4+si(p.statuses,"ritual")*10
 result+=si(p.statuses,"regen")*minf(5,1.0+(p.max_hp-p.hp)/8.0)
 result+=si(p.statuses,"metallicize")*4+si(p.statuses,"nightsight")*8+si(p.statuses,"emberflow")*4
 if si(p.statuses,"barricade")>0:result+=minf(p.block,40)*0.45
 var circ: float=clampf(cycle_repeats(g)-0.3*maxi(0,g.cb.turn-1),0,2)
 for arr: Array in [g.cb.hand,g.cb.draw,g.cb.discard]:
  for c: CardInst in arr:result+=c.bonus*circ*0.8
 result+=g.cb.embers*minf(3,ember_value(g))
 return result
func choose_action(g: GlassvowGame) -> Dictionary:
 if random_play or not params.get("native_rollout",false):return super.choose_action(g)
 var candidates: Array[Dictionary]=actions(g)
 var samples: int=clampi(ji(params.get("rollout_samples",2)),1,4)
 var steps: int=clampi(ji(params.get("rollout_steps",16)),1,32)
 var best: Dictionary={};var value: float=-INF;last_alternatives=[]
 for action: Dictionary in candidates:
  var total: float=0
  for s: int in range(samples):
   var model: GlassvowGame=Cloner.clone_public(g,s)
   var driver: RefCounted=Greedy.new();driver.route=route;driver.params=params.duplicate()
   model.apply(action);rollout_count+=1
   if action.t!="endTurn":
    for j: int in range(steps):
     if model.cb.over:break
     var next: Dictionary=driver.choose_action(model)
     if next.is_empty():break
     model.apply(next)
    if not model.cb.over:model.apply({"t":"endTurn"})
   total+=future_value(model)
  var score_value: float=total/samples
  last_alternatives.append({"action":action,"value":score_value})
  if score_value>value:value=score_value;best=action
 return {} if best.get("t")=="endTurn" else best
