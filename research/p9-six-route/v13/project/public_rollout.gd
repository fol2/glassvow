extends RefCounted
## Research rollouts clone native state but replace hidden randomness/order.
## This is a finite public-information forecast, never an exact win oracle.
static func copy_value(v: Variant, memo: Dictionary) -> Variant:
 if v is Rng:return Rng.new(0)
 if v is CardInst:
  var c: CardInst=CardInst.new(v.uid,v.id,v.up);c.bonus=v.bonus
  return c
 if v is Array:
  var a: Array=v.duplicate()
  for i: int in range(a.size()):a[i]=copy_value(a[i],memo)
  return a
 if v is Dictionary:
  var d: Dictionary={}
  for k: Variant in v:d[k]=copy_value(v[k],memo)
  return d
 if v is RefCounted:
  var id: int=v.get_instance_id()
  if memo.has(id):return memo[id]
  var obj: RefCounted=v.get_script().new();memo[id]=obj
  for p: Dictionary in v.get_property_list():
   if not (int(p.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE):continue
   var key: String=str(p.name)
   if key=="queue":continue
   if key=="rng":obj.set(key,Rng.new(0));continue
   if key=="seed":obj.set(key,0);continue
   if key=="run_id":obj.set(key,"public-rollout");continue
   obj.set(key,copy_value(v.get(key),memo))
  return obj
 return v
static func card_order(a: CardInst,b: CardInst) -> bool:
 var ka: String=String(a.id)+":"+str(a.up)+":"+str(a.bonus)+":"+str(a.uid)
 var kb: String=String(b.id)+":"+str(b.up)+":"+str(b.bonus)+":"+str(b.uid)
 return ka<kb
static func clone_public(g: GlassvowGame, sample: int) -> GlassvowGame:
 var memo: Dictionary={}
 var run: RunState=copy_value(g.run,memo)
 var cb: CombatState=copy_value(g.cb,memo)
 # Only the multiset is used. Never retain the actual top-of-deck order.
 cb.draw.sort_custom(card_order)
 var random: Rng=Rng.new(918317+7919*sample)
 for i: int in range(cb.draw.size()-1,0,-1):
  var j: int=random.pick_index(i+1)
  var card: CardInst=cb.draw[i];cb.draw[i]=cb.draw[j];cb.draw[j]=card
 run.rng=Rng.new(318193+15427*sample)
 var out: GlassvowGame=GlassvowGame.new(g.content,run);out.cb=cb
 return out
