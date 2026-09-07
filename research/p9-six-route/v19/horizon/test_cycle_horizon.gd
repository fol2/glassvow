extends SceneTree
const Policy: GDScript=preload("res://lab_policy.gd")
const Clone: GDScript=preload("res://public_rollout.gd")
var db: ContentDB
func game(turn: int) -> GlassvowGame:
 var r: RunState=RunState.new_run(db,23090000,"cycle-horizon-fixture",{"aspect":0,"vow":0,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
 r.omens=[null,null,null];r.player.relics.clear();r.player.deck.clear()
 r.player.deck.append(CardInst.new(800,&"momentum"));r.player.deck.append(CardInst.new(801,&"strike"))
 r.player.energy_max=1;r.player.hp=7;r.player.max_hp=7
 var g: GlassvowGame=GlassvowGame.new(db,r)
 g.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal","affix":null})
 g.cb.affix=&"";g.cb.turn=turn;g.cb.player.hp=7;g.cb.player.max_hp=7;g.cb.player.energy=1;g.cb.player.energy_max=1;g.cb.player.block=0;g.cb.player.statuses={}
 g.cb.embers=0;g.cb.art_used_turn=turn;g.cb.kindled_turn=turn;g.cb.kindles_this_turn=1
 g.cb.hand.clear();g.cb.draw.clear();g.cb.discard.clear();g.cb.exhaust.clear()
 g.cb.hand.append(CardInst.new(800,&"momentum"));g.cb.hand.append(CardInst.new(801,&"strike"))
 var e: EnemyCombatant=g.cb.enemies[0]
 e.hp=21;e.max_hp=21;e.block=0;e.chips=0;e.facet_max=1000;e.statuses={};e.flags={};e.staggered=false
 e.def={"moves":{"spit":{"dmg":3,"intent":"attack"},"grow":{"dmg":3,"intent":"attack"}}};e.move_key=&"spit"
 g.cb.queue.clear()
 return g
var assertions: int=0
var failures: int=0
var states: int=0
var memo: Dictionary={}
func ck(ok: bool,label: String) -> void:
 assertions+=1
 if not ok:failures+=1;push_error("CYCLE_HORIZON_TEST "+label)
func all_actions(g: GlassvowGame) -> Array[Dictionary]:
 var out: Array[Dictionary]=[{"t":"endTurn"}]
 for c: CardInst in g.cb.hand:
  if g.rules.can_play(g.run,g.cb,c,0):out.append({"t":"playCard","uid":c.uid,"target":0})
  if g.rules.can_kindle(g.run,g.cb,c):out.append({"t":"kindleFromHand","uid":c.uid})
 if g.rules.can_use_art(g.run,g.cb):out.append({"t":"useArt"})
 return out
func key(g: GlassvowGame,limit: int) -> String:
 var zones: Array=[]
 for z: Array in [g.cb.hand,g.cb.draw,g.cb.discard,g.cb.exhaust]:
  var cards: Array=[]
  for c: CardInst in z:cards.append([c.uid,String(c.id),c.up,c.bonus])
  cards.sort_custom(func(a: Array,b: Array)->bool:return a[0]<b[0]);zones.append(cards)
 return JSON.stringify([limit-g.cb.turn,g.cb.player.to_dict(),g.cb.enemies[0].to_dict(),zones,g.cb.embers,g.cb.kindled_turn==g.cb.turn,g.cb.kindles_this_turn,g.cb.art_used_turn==g.cb.turn])
func can_win(g: GlassvowGame,limit: int) -> bool:
 if g.cb.over:return g.cb.result=="win" and g.run.player.hp>0
 if g.cb.turn>limit:return false
 var k: String=key(g,limit)
 if memo.has(k):return memo[k]
 states+=1
 for action: Dictionary in all_actions(g):
  var child: GlassvowGame=Clone.clone_public(g,0);child.apply(action)
  if can_win(child,limit):memo[k]=true;return true
 memo[k]=false;return false
func _initialize() -> void:
 db=ContentDB.load_from(OS.get_cmdline_user_args()[0],true)
 var rolling: bool=OS.get_cmdline_user_args().size()>1 and OS.get_cmdline_user_args()[1]=="on"
 var records: Array=[]
 for turn: int in [1,16]:
  var g: GlassvowGame=game(turn)
  var p: RefCounted=Policy.new();p.route="cycle";p.params={"native_rollout":true,"rollout_samples":2,"rollout_steps":12,"leaf_terminal":false,"rolling_growth":rolling}
  var before: String=JSON.stringify([g.run.to_dict(),g.cb.to_dict(),g.cb.queue])
  var selected: Dictionary=p.choose_action(g);var options: Array=[]
  ck(before==JSON.stringify([g.run.to_dict(),g.cb.to_dict(),g.cb.queue]),"planner read only")
  for uid: int in [800,801]:
   var model: GlassvowGame=Clone.clone_public(g,0);model.apply({"t":"playCard","uid":uid,"target":0})
   memo.clear();states=0
   var winning: bool=can_win(model,turn+2)
   ck(winning==(uid==800),"complete three-turn legal continuation "+str(uid))
   options.append({"uid":uid,"winning_continuation":winning,"states_checked":states})
  ck(selected.get("uid")== (800 if turn==1 or rolling else 801),"reproduced original controller choice")
  records.append({"turn":turn,"choice":selected,"root_values":p.last_alternatives,"oracle":options})
 var grown: GlassvowGame=game(16);grown.cb.hand[0].bonus=28
 var p: RefCounted=Policy.new();p.route="cycle";p.params={"native_rollout":true,"rollout_samples":2,"rollout_steps":12}
 ck(p.choose_action(grown).get("uid")==800,"immediate grown lethal remains selected")
 print(JSON.stringify({"status":"BOUNDED_NATIVE_POLICY_COUNTEREXAMPLE_NOT_P9","rolling_growth":rolling,"assertions":assertions,"failures":failures,"records":records}))
 quit(0 if failures==0 else 3)
