extends SceneTree
const Sim: GDScript=preload("res://tools/observed_sim.gd")
const Stock: GDScript=preload("res://tools/balance_sim.gd")
const Policy: GDScript=preload("res://tools/balance_policy.gd")
const Observer: GDScript=preload("res://observed_game.gd")
const Bridge: GDScript=preload("res://combat_bridge.gd")

func _initialize() -> void:
 var args: PackedStringArray=OS.get_cmdline_user_args()
 if args.size()!=3:push_error("VALUE_INPUT");quit(2);return
 var cfg: Variant=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 var output: FileAccess=FileAccess.open(args[1],FileAccess.WRITE)
 var traces: FileAccess=FileAccess.open(args[2],FileAccess.WRITE)
 var db: ContentDB=BalanceCatalogue.load_prepared({"path":"res://content/full-content.json"})
 if not cfg is Dictionary or output==null or traces==null or db==null:push_error("VALUE_FILES");quit(2);return
 var policy_list: Array[Dictionary]=Policy.sample_range(int(cfg.root),int(cfg.first),int(cfg.count))
 var sources: Dictionary={}
 for name: String in ["balance_sim.gd","observed_sim.gd","balance_pilot.gd","balance_policy.gd","balance_metrics.gd","vow_incentives.gd"]:
  sources[name]=FileAccess.get_sha256("res://tools/"+name)
 var planned: bool=FileAccess.get_file_as_string("res://method.txt").strip_edges()=="planner"
 output.store_line(JSON.stringify({"kind":"header","config":cfg,"policies":policy_list,"engine":Engine.get_version_info()["string"],"sources":sources,
  "content_sha256":FileAccess.get_sha256("res://content/full-content.json"),"combat_sha256":FileAccess.get_sha256("res://domain/rules/combat.gd"),
  "probe_sha256":FileAccess.get_sha256("res://probe.gd"),"observer_sha256":FileAccess.get_sha256("res://observed_game.gd"),
  "bridge_sha256":FileAccess.get_sha256("res://combat_bridge.gd"),"method":"planner" if planned else "stock"}))
 output.flush()
 for offset: int in range(policy_list.size()):
  var index: int=int(cfg.first)+offset
  for seed_v: Variant in cfg.seeds:
   var seed: int=int(seed_v);var key: String="%d:%d:%d" % [int(cfg.vow),index,seed]
   Observer.begin(key,traces);Bridge.reset();Bridge.configure(planned)
   var started: int=Time.get_ticks_usec()
   var row: Dictionary=Sim.simulate(db,"ashwarden",seed,int(cfg.vow),PackedStringArray(),policy_list[offset],false,false)
   var elapsed: int=Time.get_ticks_usec()-started
   var same: Variant=null
   if bool(cfg.integration):
    Bridge.configure(false)
    var original: Dictionary=Stock.simulate(db,"ashwarden",seed,int(cfg.vow),PackedStringArray(),policy_list[offset],false,false)
    same=row==original
   output.store_line(JSON.stringify({"kind":"outcome","row_key":key,"index":index,"seed":seed,"vow":int(cfg.vow),"policy":policy_list[offset],"row":row,"observer_matches_stock":same,
    "method":"planner" if planned else "stock","query_count":Bridge.queries,"root_rollouts":Bridge.root_rollouts,"query_usec":Bridge.query_usec,"run_usec":elapsed,"faults":Bridge.faults,"decisions":Bridge.decisions}))
   output.flush()
 output.store_line(JSON.stringify({"kind":"terminal","rows":policy_list.size()*cfg.seeds.size()}))
 output.close();traces.close();quit(0)
