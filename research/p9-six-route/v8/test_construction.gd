extends SceneTree
var checks: int=0
var fails: int=0
func ck(ok: bool,s: String) -> void:
 checks+=1
 if not ok:fails+=1;push_error("CONSTRUCTION_FAIL "+s)
func game(path: String,aspect: int=0) -> GlassvowGame:
 var d: ContentDB=ContentDB.load_from(path,true)
 var r: RunState=RunState.new_run(d,8120000,"native-construction",{"aspect":aspect,"vow":0,"reveals":d.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
 var g: GlassvowGame=GlassvowGame.new(d,r);g.apply({"t":"startCombat","enemies":["rootheart"],"kind":"boss"})
 g.run.player.relics.clear();g.cb.player.energy=30;g.cb.player.statuses={};g.cb.embers=0;g.cb.hand.clear();g.cb.draw.clear();g.cb.discard.clear();g.cb.exhaust.clear()
 g.cb.enemies[0].hp=1000;g.cb.enemies[0].max_hp=1000;g.cb.enemies[0].block=0;g.cb.enemies[0].statuses={};g.cb.enemies[0].facet_max=100;g.cb.enemies[0].chips=0
 return g
func play(g: GlassvowGame,id: String,up: bool=false) -> Dictionary:
 var c: CardInst=CardInst.new(g.run.next_uid(),StringName(id),up);g.cb.hand.append(c)
 var before: int=g.cb.enemies[0].hp
 var target: Variant=0 if g.rules.card_data(c).get("target")=="enemy" else null
 var events: Array[Dictionary]=g.apply({"t":"playCard","uid":c.uid,"target":target})
 ck(g.last_ret==true,"legal "+id)
 return {"loss":before-g.cb.enemies[0].hp,"c":c,"events":events}
func _initialize() -> void:
 for path: String in OS.get_cmdline_user_args():
  var g: GlassvowGame=game(path)
  ck(play(g,"flurry").loss==0,"unprepared multihit is weak")
  play(g,"empower")
  ck(play(g,"flurry").loss==15,"native strength producer amplifies five hits")
  g=game(path)
  var c: CardInst=CardInst.new(g.run.next_uid(),&"momentum")
  var losses: Array=[]
  for _i: int in range(3):
   g.cb.discard.erase(c);g.cb.hand.append(c);var hp: int=g.cb.enemies[0].hp
   g.apply({"t":"playCard","uid":c.uid,"target":0});losses.append(hp-g.cb.enemies[0].hp)
  ck(losses==[0,15,30],"bounded same-card growth follows exact law")
  ck(c.combat_copy().bonus==0,"growth resets on new combat copy")
  for held: int in [3,6]:
   g=game(path,1)
   for _i: int in range(held):g.cb.hand.append(CardInst.new(g.run.next_uid(),&"defend"))
   ck(play(g,"phantomBlades").loss==7*maxi(0,held-3),"native hand reserve payoff")
  for emb: int in [4,7]:
   g=game(path,1);g.cb.embers=emb
   ck(play(g,"novaflare").loss==8*maxi(0,emb-4),"native Ember reserve payoff")
   ck(g.cb.embers==emb,"Nova samples stock without secretly consuming it")
  g=game(path,0);g.rules.add_status_enemy(g.cb,g.cb.enemies[0],"poison",10,g.run)
  ck(not g.cb.enemies[0].statuses.has("poison"),"Dusk poison prohibition retained")
  g=game(path,1);g.rules.apply_chips(g.run,g.cb,g.cb.enemies[0],200)
  ck(g.cb.enemies[0].chips==0 and not g.cb.enemies[0].staggered,"Ash cannot shatter/stun")
 print("CONSTRUCTION_NATIVE checks="+str(checks)+" failures="+str(fails));quit(0 if fails==0 else 3)
