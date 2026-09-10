extends SceneTree
## New four-world observer plumbing, not a repeat of the old360 role study.
const O: GDScript = preload("res://observed_game.gd")

func _initialize() -> void:
 var args: PackedStringArray = OS.get_cmdline_user_args()
 if args.size()!=3:push_error("GATE_ARGS");quit(2);return
 var db: ContentDB = BalanceCatalogue.load_prepared({"path":"res://content/full-content.json"})
 var records: FileAccess = FileAccess.open(args[0],FileAccess.WRITE)
 var traces: FileAccess = FileAccess.open(args[1],FileAccess.WRITE)
 if db==null or records==null or traces==null:push_error("GATE_IO");quit(2);return
 var index: int = 0
 for aspect: int in [0,1]:
  for vow: int in [0,5]:
   for upgraded: bool in [false,true]:
    for initial_hp: int in [2,30]:
     for enemy_block: int in [0,50]:
      var run: RunState = RunState.new_run(db,73520010,"causal-plumbing",{"aspect":aspect,"vow":vow,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
      run.omens=[null,null,null]
      run.player.relics.clear()
      var g: GlassvowGame = O.new(db,run)
      O.begin("gate:%d" % index,traces)
      g.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal"})
      g.cb.hand.clear()
      g.cb.hand.append(CardInst.new(900,&"bloodRite",upgraded))
      g.cb.hand.append(CardInst.new(901,&"leechBlade",upgraded))
      g.cb.player.energy=0
      g.cb.player.hp=initial_hp
      g.cb.player.max_hp=80
      g.cb.player.statuses.clear()
      g.cb.enemies[0].hp=100
      g.cb.enemies[0].max_hp=100
      g.cb.enemies[0].block=enemy_block
      g.cb.enemies[0].statuses.clear()
      var before: Dictionary=O.snapshot(g)
      var source_events: Array[Dictionary]=g.apply({"t":"playCard","uid":900})
      var source_after: Dictionary=O.snapshot(g)
      var consumer_events: Array[Dictionary]=g.apply({"t":"playCard","uid":901,"target":0})
      records.store_line(JSON.stringify({"index":index,"world":args[2],"aspect":aspect,"vow":vow,"upgraded":upgraded,"initial_hp":initial_hp,"enemy_block":enemy_block,"before":before,"source_after":source_after,"consumer_after":O.snapshot(g),"source_events":source_events,"consumer_events":consumer_events,"flags":{"producer":g.rules.get("bloodfire_producer_enabled"),"consumer":g.rules.get("bloodfire_consumer_enabled")}}))
      index+=1
 records.store_line(JSON.stringify({"kind":"terminal","cases":index}))
 records.close();traces.close();quit(0)
