extends SceneTree
const Sim: GDScript = preload("res://tools/balance_sim.gd")
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size()!=1:quit(2);return
	var db: ContentDB = BalanceCatalogue.load_prepared({"path":"res://content/full-content.json"})
	var out: FileAccess = FileAccess.open(args[0],FileAccess.WRITE)
	if db==null or out==null:quit(2);return
	for aspect: String in ["duskblade","ashwarden"]:
		for vow: int in [0,5]:
			var row: Dictionary = Sim.simulate(db,aspect,73509010,vow,PackedStringArray(),{},true,false)
			out.store_line(JSON.stringify({"aspect":aspect,"vow":vow,"row":row}))
	out.close();quit(0)
