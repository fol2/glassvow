extends RefCounted
## Post-decision observation only. Exact hidden-state copies never reach a policy.
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
  elif v is CardInst:
   out=CardInst.new(v.uid,v.id,v.up);out.bonus=v.bonus
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
 # Old queued history is append-only, not future gameplay state. New events are compared separately.
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
 for fx: Dictionary in g.rules.card_data(c).get("effects",[]):
  if fx.get("kind")=="dmg" and int(fx.get("times",1))>1:found["multihit"]=true
  elif fx.get("kind")=="special" and fx.get("id")=="momentum":found["growth"]=true
  elif fx.get("kind")=="special" and fx.get("id")=="phantom":found["handstock"]=true
 return str(found.keys()[0]) if found.size()==1 else ""
static func sample(g: GlassvowGame,cmd: Dictionary,id: String) -> Dictionary:
 var before: String=fingerprint(g)
 var queue_before: String=JSON.stringify(g.cb.queue)
 var inst: CardInst=find_card(g,int(cmd.uid))
 if inst==null:return {"ok":false,"reason":"MISSING_CARD"}
 var kind: String=role(g,cmd)
 if kind.is_empty():return {"ok":false,"reason":"UNSUPPORTED_OR_MIXED_ROLE"}
 var reserve: int=0
 if kind=="handstock":
  for fx: Dictionary in g.rules.card_data(inst).get("effects",[]):
   if fx.get("id")=="phantom":reserve=int(fx.get("reserve",0))
 var mediator: int=int(g.cb.player.statuses.get("str",0)) if kind=="multihit" else inst.bonus
 if kind=="handstock":mediator=maxi(0,g.cb.hand.size()-1-reserve)
 var gains: Array=[];var factual: Dictionary={}
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
     # A specified mediator intervention: retain the played card plus the declared reserve.
     # Move surplus cards to the bottom of draw, with no events or fuel change.
     for i: int in range(model.cb.hand.size()-1,-1,-1):
      if model.cb.hand.size()<=reserve+1:break
      var moved: CardInst=model.cb.hand[i]
      if moved.uid==target.uid:continue
      model.cb.hand.remove_at(i);model.cb.draw.push_front(moved)
   var hp: Dictionary=Health.snapshot(model.cb)
   var events: Array[Dictionary]=model.apply(cmd)
   var result: Dictionary=Health.fold(hp,events,Health.snapshot(model.cb))
   if model.last_ret!=true or not result.ok:return {"ok":false,"reason":"INVALID_COUNTERFACTUAL_CAPTURE"}
   gains.append(int(result.removed))
   if m==1 and c==1:factual={"events":events,"state":fingerprint(model),"ret":model.last_ret}
 if before!=fingerprint(g) or queue_before!=JSON.stringify(g.cb.queue):return {"ok":false,"reason":"OBSERVER_MUTATED_LIVE_STATE"}
 return {"ok":true,"gains":gains,"mediator":mediator,"factual":factual,
  "record":{"card":id,"role":kind,"act":g.run.act+1,"turn":g.cb.turn,"mediator":mediator,"up":inst.up,
   "gains":gains,"interaction":int(gains[3])-int(gains[2])-int(gains[1])+int(gains[0]),
   "target_hp":g.cb.enemies[int(cmd.target)].hp if cmd.get("target")!=null else -1,"before":before}}

static func verify_factual(g: GlassvowGame,events: Array[Dictionary],sampled: Dictionary) -> bool:
 return sampled.get("ok",false) and g.last_ret==sampled.factual.ret and events==sampled.factual.events and fingerprint(g)==sampled.factual.state
