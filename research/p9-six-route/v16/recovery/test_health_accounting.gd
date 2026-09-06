extends SceneTree
const H: GDScript=preload("res://health_accounting.gd")
var n: int=0
var failures: int=0
func ck(ok: bool,label: String) -> void:
 n+=1
 if not ok:failures+=1;push_error("ACCOUNT_TEST_FAIL "+label)
func hit(amount: int,hp: int,poison: bool=false) -> Dictionary:
 return {"t":EventTypes.HIT_ENEMY,"idx":0,"amount":amount,"hpAfter":hp,"poison":poison}
func _initialize() -> void:
 var x: Dictionary=H.fold({0:7},[hit(30,0)],{0:0})
 ck(x.ok and x.nominal==30 and x.removed==7,"overkill clips health, not nominal event")
 x=H.fold({0:7},[hit(30,0,true)],{0:0})
 ck(x.ok and x.poison_removed==7,"poison overkill clips")
 x=H.fold({0:10},[hit(4,6),{"t":EventTypes.HEAL,"who":0,"n":3},hit(20,0)],{0:0})
 ck(x.ok and x.removed==13 and x.healed==3,"heal-damage conservation")
 ck(not H.fold({0:10},[hit(4,8)],{0:8}).ok,"wrong hpAfter rejects")
 ck(not H.fold({0:10},[hit(4,6)],{0:7}).ok,"wrong final HP rejects")
 ck(not H.fold({1:10},[hit(4,6)],{1:10}).ok,"unknown target rejects")
 ck(not H.fold({0:10},[hit(-2,12)],{0:12}).ok,"negative hit rejects")
 ck(H.fold({0:10},[{"t":EventTypes.HEAL,"who":"player","n":3}],{0:10}).ok,"player healing irrelevant")
 ck(not H.fold({0:10},[{"t":EventTypes.HEAL,"who":1,"n":3}],{0:10}).ok,"unknown heal target rejects")
 ck(not H.fold({0:10},[{"t":EventTypes.HIT_ENEMY,"idx":0}],{0:10}).ok,"missing fields reject")
 var db: ContentDB=ContentDB.load_full()
 var r: RunState=RunState.new_run(db,14030000,"health-fold",{"aspect":0,"vow":0,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
 r.omens=[null,null,null];r.player.relics.clear()
 var g: GlassvowGame=GlassvowGame.new(db,r)
 g.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal"})
 g.cb.enemies[0].hp=7;g.cb.enemies[0].block=0;g.cb.enemies[0].statuses={};g.cb.player.statuses={};g.cb.player.energy=10;g.cb.hand.clear()
 db.cards["strike"]["effects"]=[{"kind":"dmg","n":30}]
 g.cb.hand.append(CardInst.new(999,&"strike"))
 var before: Dictionary=H.snapshot(g.cb)
 var events: Array=g.apply({"t":"playCard","uid":999,"target":0})
 var saved: String=JSON.stringify([g.run.to_dict(),g.cb.to_dict(),events])
 x=H.fold(before,events,H.snapshot(g.cb))
 ck(x.ok and x.removed==7 and x.nominal==30,"native execution conservation")
 ck(saved==JSON.stringify([g.run.to_dict(),g.cb.to_dict(),events]),"accounting never mutates execution")
 print("HEALTH_ACCOUNT_TESTS "+str(n)+" FAILURES "+str(failures));quit(0 if failures==0 else 3)
