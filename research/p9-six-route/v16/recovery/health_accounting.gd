extends RefCounted
## Read-only event accounting. Never changes combat state or its event stream.
static func snapshot(cb: CombatState) -> Dictionary:
 var hp: Dictionary={}
 for e: EnemyCombatant in cb.enemies:hp[e.idx]=maxi(0,e.hp)
 return hp
static func fold(initial: Dictionary, events: Array, final_hp: Dictionary) -> Dictionary:
 var hp: Dictionary=initial.duplicate(true)
 var nominal: int=0;var removed: int=0;var poison: int=0;var healed: int=0
 for ev: Dictionary in events:
  if ev.get("t")==EventTypes.HIT_ENEMY:
   var id: Variant=ev.get("idx")
   if not hp.has(id):return {"ok":false,"reason":"UNKNOWN_TARGET"}
   if not ev.has("amount") or not ev.has("hpAfter"):return {"ok":false,"reason":"MISSING_HIT_FIELD"}
   var n: int=int(ev.amount)
   if n<0:return {"ok":false,"reason":"NEGATIVE_DAMAGE"}
   var actual: int=mini(int(hp[id]),n)
   hp[id]=maxi(0,int(hp[id])-n)
   if int(ev.hpAfter)!=int(hp[id]):return {"ok":false,"reason":"HIT_STATE_MISMATCH"}
   nominal+=n;removed+=actual
   if ev.get("poison",false):poison+=actual
  elif ev.get("t")==EventTypes.HEAL and str(ev.get("who"))!="player":
   var id: Variant=ev.get("who")
   if not hp.has(id):return {"ok":false,"reason":"UNKNOWN_HEAL_TARGET"}
   var n: int=int(ev.get("n",-1))
   if n<0:return {"ok":false,"reason":"INVALID_HEAL"}
   hp[id]=int(hp[id])+n;healed+=n
 if hp!=final_hp:return {"ok":false,"reason":"FINAL_STATE_MISMATCH"}
 return {"ok":true,"nominal":nominal,"removed":removed,"poison_removed":poison,"healed":healed}
