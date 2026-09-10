extends SceneTree
const Observer: GDScript = preload("res://observed_game.gd")
const Public: GDScript = preload("res://public_rollout.gd")
const Planner: GDScript = preload("res://lab_policy.gd")
const FLAGS: Array[String] = ["hand_preparation_enabled", "hand_surge_enabled", "hand_phantom_enabled"]
var db: ContentDB
var output: FileAccess
var trace: FileAccess
var mode: String
var case_id: int = 0

func flags(g: GlassvowGame) -> Array:
 var out: Array = []
 for key: String in FLAGS:
  var v: Variant = g.rules.get(key)
  out.append(true if v == null else bool(v))
 return out

func make(source: String, up: bool, aspect: int, vow: int, context: String, mask: int) -> GlassvowGame:
 var r: RunState = RunState.new_run(db,73530010,"hand-clone-qualification",{"aspect":aspect,"vow":vow,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
 r.omens=[null,null,null];r.player.relics.clear()
 if context=="branch":r.player.relics.append(&"verdantBranch")
 var g: GlassvowGame=Observer.new(db,r)
 if mode!="reference":
  for i: int in range(3):g.rules.set(FLAGS[i],bool(mask & (1<<i)))
 Observer.begin("hand:"+str(case_id),trace)
 g.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal"})
 g.cb.affix=&"";g.cb.player.statuses={"str":2};g.cb.player.energy=1
 g.cb.player.hp=60;g.cb.player.max_hp=100;g.cb.player.block=0
 g.run.player.hp=60;g.run.player.max_hp=100
 g.cb.hand.clear();g.cb.draw.clear();g.cb.discard.clear();g.cb.exhaust.clear();g.run.player.deck.clear()
 for spec: Array in [[10001,source,up],[10002,"phantomBlades",up],[10003,"defend",false]]:
  var c: CardInst=CardInst.new(spec[0],StringName(spec[1]),spec[2])
  g.cb.hand.append(c);g.run.player.deck.append(c)
 if context!="empty":
  for i: int in range(6):
   var c: CardInst=CardInst.new(10100+i,&"defend")
   g.cb.draw.append(c);g.run.player.deck.append(c)
 var enemy: EnemyCombatant=g.cb.enemies[0]
 enemy.hp=1000;enemy.max_hp=1000;enemy.block=0;enemy.chips=0;enemy.facet_max=100
 enemy.statuses={};enemy.flags={};enemy.staggered=false
 g.cb.queue.clear()
 return g

func one(source: String, up: bool, aspect: int, vow: int, context: String, mask: int) -> void:
 var g: GlassvowGame=make(source,up,aspect,vow,context,mask)
 var catalogue: String=JSON.stringify(db.cards)
 var before: Dictionary=Observer.snapshot(g)
 var source_data: Dictionary=g.rules.card_data(g.cb.hand[0]).duplicate(true)
 var consumer_data: Dictionary=g.rules.card_data(g.cb.hand[1]).duplicate(true)
 var source_events: Array[Dictionary]=g.apply({"t":"playCard","uid":10001,"target":null})
 var after_source: Dictionary=Observer.snapshot(g)
 var source_ret: Variant=g.last_ret
 var exact: GlassvowGame=g.call("clone_game")
 var public: GlassvowGame=Public.clone_public(g,0)
 var unchanged: bool=Observer.snapshot(g)==after_source
 var f: Array=flags(g);var ef: Array=flags(exact);var pf: Array=flags(public)
 var query: Dictionary={}
 var alternatives: Array=[]
 if mode in ["reference","qualified"]:
  var planner: RefCounted=Planner.new()
  planner.route="balanced"
  planner.params={"bank_mode":"current-plus-next","native_rollout":true,"rollout_samples":1,"rollout_steps":12,"leaf_terminal":false}
  query=planner.choose_action(g)
  alternatives=planner.last_alternatives.duplicate(true)
  unchanged=unchanged and Observer.snapshot(g)==after_source and flags(g)==f
 var cmd: Dictionary={"t":"playCard","uid":10002,"target":0}
 var events: Array[Dictionary]=g.apply(cmd)
 var exact_events: Array[Dictionary]=exact.apply(cmd)
 var public_events: Array[Dictionary]=public.apply(cmd)
 output.store_line(JSON.stringify({"case":case_id,"source":source,"up":up,"aspect":aspect,"vow":vow,"context":context,"mask":mask,
  "before":before,"source_data":source_data,"consumer_data":consumer_data,"source_events":source_events,"source_ret":source_ret,
  "source_after":after_source,"after":Observer.snapshot(g),"events":events,
  "exact_after":Observer.snapshot(exact),"exact_events":exact_events,"public_after":Observer.snapshot(public),"public_events":public_events,
  "flags":f,"exact_flags":ef,"public_flags":pf,"readonly":unchanged,"catalogue_unchanged":catalogue==JSON.stringify(db.cards),
  "query":query,"alternatives":alternatives}))
 output.flush();case_id+=1

func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=3:quit(2);return
 mode=args[0];output=FileAccess.open(args[1],FileAccess.WRITE);trace=FileAccess.open(args[2],FileAccess.WRITE)
 db=BalanceCatalogue.load_prepared({"path":"res://content/full-content.json"})
 if db==null or output==null or trace==null:quit(2);return
 for source: String in ["preparation","surge"]:
  for up: bool in [false,true]:
   for aspect: int in [0,1]:
    for vow: int in [0,5]:
     for context: String in ["plain","empty","branch"]:
      if mode=="reference":one(source,up,aspect,vow,context,7)
      elif mode=="qualified":
       for mask: int in range(8):one(source,up,aspect,vow,context,mask)
      else:one(source,up,aspect,vow,context,0)
 output.store_line(JSON.stringify({"kind":"terminal","cases":case_id}))
 output.close();trace.close();quit(0)
