extends SceneTree
## New clone/observer qualification only; not a replay of old role fixtures.
const Observer: GDScript = preload("res://observed_game.gd")

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2); return
	var db: ContentDB = ContentDB.load_full(true)
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	if db == null or file == null:
		quit(2); return
	var index: int = 0
	for vow: int in [0, 5]:
		for block: int in [0, 50]:
			for energy: int in [1, 2]:
				for hp: int in [5, 100]:
					var run: RunState = RunState.new_run(db, 73409010, "clone-qualification", {"aspect":1,"vow":vow,"reveals":db.reveal_ids.duplicate(),"unlocks":["aspect2"],"quests":{},"shards":[]})
					run.omens = [null,null,null]
					var game: GlassvowGame = Observer.new(db,run)
					Observer.begin("qualify:%d" % index,file)
					game.apply({"t":"startCombat","enemies":["sporeling"],"kind":"normal"})
					game.cb.hand.clear()
					game.cb.hand.append(CardInst.new(900,&"leechBlade",true))
					game.cb.player.statuses["bloodfire"] = 2
					game.cb.player.energy = energy
					game.cb.player.hp = 30
					game.cb.player.max_hp = 80
					game.cb.enemies[0].hp = hp
					game.cb.enemies[0].max_hp = 100
					game.cb.enemies[0].block = block
					game.cb.enemies[0].statuses["thorns"] = 2
					game.apply({"t":"playCard","uid":900,"target":0})
					index += 1
	file.close(); quit(0)
