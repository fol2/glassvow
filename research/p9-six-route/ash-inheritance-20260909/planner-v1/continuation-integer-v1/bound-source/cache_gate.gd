extends SceneTree
const Stock: GDScript = preload("res://greedy_policy.gd")
const Memo: GDScript = preload("res://continuation_cache.gd")
const Observe: GDScript = preload("res://observed_game.gd")

func _initialize() -> void:
 var args: PackedStringArray = OS.get_cmdline_user_args()
 if args.size()!=1:quit(2);return
 var out: FileAccess = FileAccess.open(args[0],FileAccess.WRITE)
 var db: ContentDB = ContentDB.load_full(true)
 if out==null or db==null:quit(2);return
 var run: RunState = RunState.new_run(db,73409010,"memo-lifecycle",{"aspect":1,"vow":5,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
 run.omens=[null,null,null]
 var game: GlassvowGame = GlassvowGame.new(db,run)
 game.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal"})
 var reference: RefCounted = Stock.new()
 var memo: RefCounted = Memo.new()
 reference.params={"bank_mode":"current-plus-next"};memo.params=reference.params.duplicate()
 var failures: int=0
 var ids: Array[String]=["empower","flurry","preparation","phantomBlades","momentum","leechBlade","bloodRite","defend"]
 var numeric_inputs: Array=[0, 1, -1, 42, -42, 1000000, -1000000, 2147483647, -2147483648, 9007199254740990, 9007199254740991, 9007199254740992, 9007199254740993, -9007199254740991, -9007199254740992, -9007199254740993, 9223372036854775807, -9223372036854775807, 0.0, 1.0, 1.75, -1.75, 1e-08, 100000000.0, "42", "-1.75", "9007199254740993"]
 var unsafe_witnesses: int=0
 for v: Variant in numeric_inputs:
  var expected: int=reference.ji(v)
  var actual: int=memo.ji(v)
  var unbounded: int=int(v) if typeof(v)==TYPE_INT else expected
  if actual!=expected:failures+=1
  if unbounded!=expected:unsafe_witnesses+=1
  out.store_line(JSON.stringify({"kind":"integer_conversion","input":str(v),"type":typeof(v),"expected":expected,"actual":actual,"unbounded":unbounded}))
 if unsafe_witnesses==0:failures+=1
 for i: int in range(24):
  reference.route=["balanced","hand","cycle","ember"][i%4];memo.route=reference.route
  game.cb.player.energy=i%4;game.cb.player.hp=10+i;game.cb.player.max_hp=100
  game.cb.player.block=i%7;game.cb.embers=i%6
  game.cb.player.statuses={"str":i%3,"nightsight":i%2}
  game.cb.enemies[0].hp=15+i;game.cb.enemies[0].block=i%9
  game.cb.enemies[0].staggered=(i%5==0)
  game.cb.enemies[0].statuses={"poison":i%4,"vulnerable":i%2}
  game.cb.hand.clear();game.run.player.deck.clear()
  for j: int in range(3+i%6):
   var card: CardInst=CardInst.new(900+j,StringName(ids[j]),i%2==1)
   game.cb.hand.append(card);game.run.player.deck.append(card)
  var before: Dictionary=Observe.snapshot(game)
  var a: Dictionary=reference.choose_action(game)
  var b: Dictionary=memo.choose_action(game)
  var equal: bool=a==b and Observe.snapshot(game)==before
  var reset: bool=memo._memo.is_empty() and memo._memo_game==null
  var memory: bool=reference._draw_seen==memo._draw_seen and reference.repeat_draw_avoided==memo.repeat_draw_avoided
  if not equal or not reset or not memory:failures+=1
  out.store_line(JSON.stringify({"case":i,"reference":a,"memo":b,"equal_and_readonly":equal,"cache_reset":reset,"policy_memory_equal":memory}))
 out.store_line(JSON.stringify({"kind":"terminal","cases":24,"failures":failures}))
 out.close();quit(0 if failures==0 else 3)
