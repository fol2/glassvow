extends RefCounted
## Exact-state post-decision factorial; no clone is exposed to a policy.
const Diagnostic: GDScript=preload("res://diagnostic_rules.gd")
const Health: GDScript=preload("res://health_accounting.gd")
static var field_cache: Dictionary={}
static func fields(v: RefCounted) -> Array:
 var script: GDScript=v.get_script()
 if not field_cache.has(script):
  var names: Array=[]
  for p: Dictionary in v.get_property_list():
   if int(p.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE and str(p.name)!="queue":names.append(str(p.name))
  field_cache[script]=names
 return field_cache[script]
static func duplicate_value(v: Variant,memo: Dictionary) -> Variant:
 if v is RefCounted:
  var id: int=v.get_instance_id()
  if memo.has(id):return memo[id]
  var out: RefCounted
  if v is Rng:out=Rng.new(v.get_state())
  elif v is CardInst:out=CardInst.new(v.uid,v.id,v.up);out.bonus=v.bonus
  else:out=v.get_script().new()
  memo[id]=out
  if not v is Rng and not v is CardInst:
   for key: String in fields(v):out.set(key,duplicate_value(v.get(key),memo))
  return out
 if v is Array:
  var a: Array=v.duplicate()
  for i: int in range(a.size()):a[i]=duplicate_value(a[i],memo)
  return a
 if v is Dictionary:
  var d: Dictionary={}
  for key: Variant in v:d[key]=duplicate_value(v[key],memo)
  return d
 return v
static func projection(v: Variant,memo: Dictionary) -> Variant:
 if v is Rng:return {"rng_state":v.get_state()}
 if v is RefCounted:
  var id: int=v.get_instance_id()
  if memo.has(id):return {"ref":memo[id]}
  var tag: int=memo.size();memo[id]=tag
  var d: Dictionary={"object":tag}
  for key: String in fields(v):d[key]=projection(v.get(key),memo)
  return d
 if v is Array:
  var a: Array=[]
  for x: Variant in v:a.append(projection(x,memo))
  return a
 if v is Dictionary:
  var d: Dictionary={}
  for key: Variant in v:d[key]=projection(v[key],memo)
  return d
 return v
static func fingerprint(g: GlassvowGame) -> String:
 # Past append-only queue is separately checked; all future state/RNG is included.
 return JSON.stringify(projection([g.run,g.cb,g.last_ret],{})).sha256_text()
static func clone_exact(g: GlassvowGame) -> GlassvowGame:
 var memo: Dictionary={}
 var r: RunState=duplicate_value(g.run,memo)
 var cb: CombatState=duplicate_value(g.cb,memo)
 var out: GlassvowGame=GlassvowGame.new(g.content,r);out.cb=cb
 out.rules=Diagnostic.new(g.content);out.last_ret=g.last_ret
 return out
static func find_card(g: GlassvowGame,uid: int) -> CardInst:
 for c: CardInst in g.cb.hand:
  if c.uid==uid:return c
 return null
static func role(g: GlassvowGame,cmd: Dictionary) -> String:
 if str(cmd.get("t",""))!="playCard":return ""
 var c: CardInst=find_card(g,int(cmd.get("uid",0)))
 if c==null:return ""
 var found: Dictionary={}
 var definition: Dictionary=g.rules.card_data(c)
 if int(definition.get("chip",0))>0:found["chip_supply"]=true
 for fx: Dictionary in definition.get("effects",[]):
  if fx.get("kind")=="dmg" and int(fx.get("times",1))>1:found["multihit"]=true
  elif fx.get("kind")=="chip" and int(fx.get("n",0))>0:found["chip_supply"]=true
  elif fx.get("kind")=="special":
   var k: String=str({"momentum":"growth","phantom":"handstock","catalyst":"catalyst","shatterEcho":"echo"}.get(str(fx.get("id","")),""))
   if not k.is_empty():found[k]=true
 return str(found.keys()[0]) if found.size()==1 else ""
static func reserve_for(g: GlassvowGame,c: CardInst) -> int:
 for fx: Dictionary in g.rules.card_data(c).get("effects",[]):
  if fx.get("id")=="phantom":return int(fx.get("reserve",0))
 return 0
static func mediator(g: GlassvowGame,cmd: Dictionary,kind: String) -> int:
 var c: CardInst=find_card(g,int(cmd.uid))
 if kind=="multihit":return int(g.cb.player.statuses.get("str",0))
 if kind=="growth":return c.bonus
 if kind=="handstock":return maxi(0,g.cb.hand.size()-1-reserve_for(g,c))
 if cmd.get("target")==null:return 0
 var e: EnemyCombatant=g.cb.enemies[int(cmd.target)]
 if kind=="catalyst":return int(e.statuses.get("poison",0))
 if kind=="chip_supply":return e.chips
 if kind=="echo":return int(e.staggered or int(e.statuses.get("vulnerable",0))>0)
 return 0
static func poison(cb: CombatState) -> int:
 var value: int=0
 for e: EnemyCombatant in cb.enemies:value+=int(e.statuses.get("poison",0))
 return value
static func sample(g: GlassvowGame,cmd: Dictionary) -> Dictionary:
 var before: String=fingerprint(g);var queue_before: String=JSON.stringify(g.cb.queue)
 var inst: CardInst=find_card(g,int(cmd.uid))
 if inst==null:return {"ok":false,"reason":"MISSING_CARD"}
 var kind: String=role(g,cmd)
 if kind.is_empty():return {"ok":false,"reason":"UNSUPPORTED_OR_MIXED_ROLE"}
 var reserve: int=reserve_for(g,inst);var value: int=mediator(g,cmd,kind)
 var outcomes: Array=[];var factual: Dictionary={}
 for m: int in [0,1]:
  for c: int in [0,1]:
   var model: GlassvowGame=clone_exact(g)
   if fingerprint(model)!=before:return {"ok":false,"reason":"CLONE_STATE_DIFF"}
   model.rules.erased_consumer=kind if c==0 else ""
   var target: CardInst=find_card(model,int(cmd.uid))
   if m==0:
    if kind=="multihit":model.cb.player.statuses["str"]=0
    elif kind=="growth":target.bonus=0
    elif kind=="handstock":
     # Controlled stock intervention, not a playable move or a policy observation.
     for i: int in range(model.cb.hand.size()-1,-1,-1):
      if model.cb.hand.size()<=reserve+1:break
      var moved: CardInst=model.cb.hand[i]
      if moved.uid==target.uid:continue
      model.cb.hand.remove_at(i);model.cb.draw.push_front(moved)
    elif cmd.get("target")!=null:
     var enemy: EnemyCombatant=model.cb.enemies[int(cmd.target)]
     if kind=="catalyst":enemy.statuses["poison"]=0
     elif kind=="chip_supply":enemy.chips=0
     elif kind=="echo":enemy.staggered=false;enemy.statuses["vulnerable"]=0
   var hp: Dictionary=Health.snapshot(model.cb);var q: int=poison(model.cb)
   var events: Array[Dictionary]=model.apply(cmd)
   var h: Dictionary=Health.fold(hp,events,Health.snapshot(model.cb))
   if model.last_ret!=true or not h.ok:return {"ok":false,"reason":"INVALID_COUNTERFACTUAL_CAPTURE"}
   var sh: int=0
   for event: Dictionary in events:
    if event.get("t")==EventTypes.SHATTER:sh+=1
   outcomes.append([int(h.removed),int(h.nominal),poison(model.cb)-q,sh])
   if m==1 and c==1:factual={"events":events,"state":fingerprint(model),"ret":model.last_ret}
 if before!=fingerprint(g) or queue_before!=JSON.stringify(g.cb.queue):return {"ok":false,"reason":"OBSERVER_MUTATED_LIVE_STATE"}
 var interaction: Array=[]
 for j: int in range(4):interaction.append(int(outcomes[3][j])-int(outcomes[2][j])-int(outcomes[1][j])+int(outcomes[0][j]))
 return {"ok":true,"factual":factual,"record":{"card":String(inst.id),"role":kind,"act":g.run.act+1,"turn":g.cb.turn,"mediator":value,"up":inst.up,"arms":outcomes,"interaction":interaction,"target_hp":g.cb.enemies[int(cmd.target)].hp if cmd.get("target")!=null else -1,"before":before}}
static func verify_factual(g: GlassvowGame,events: Array[Dictionary],sampled: Dictionary) -> bool:
 return sampled.get("ok",false) and g.last_ret==sampled.factual.ret and events==sampled.factual.events and fingerprint(g)==sampled.factual.state
