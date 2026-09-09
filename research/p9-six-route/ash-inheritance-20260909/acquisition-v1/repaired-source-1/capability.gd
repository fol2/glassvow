extends SceneTree
const Aware: GDScript = preload("res://tools/balance_pilot.gd")
const Stock: GDScript = preload("res://tools/stock_pilot.gd")
const Policy: GDScript = preload("res://tools/balance_policy.gd")
var file: FileAccess
var count: int = 0
var failures: int = 0

func emit(r: Dictionary) -> void:
	count += 1
	if not r.okay:
		failures += 1
	file.store_line(JSON.stringify(r))

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2); return
	file = FileAccess.open(args[0], FileAccess.WRITE)
	var db: ContentDB = ContentDB.load_full(true)
	if file == null or db == null:
		quit(2); return
	var policies: Array[Dictionary] = Policy.sample_range(73509000, 0, 4)
	policies.append(Policy.default())
	var original_cards: Dictionary = db.cards.duplicate(true)
	for pi: int in range(policies.size()):
		Aware.apply_policy(policies[pi]); Stock.apply_policy(policies[pi])
		for aspect: int in [0, 1]:
			for random_build: bool in [false, true]:
				Aware.set_modes(random_build, false); Stock.set_modes(random_build, false)
				for deck_kind: String in ["empty", "source", "consumer", "duplicate"]:
					var deck: Array = []
					if deck_kind == "source": deck.append(CardInst.new(100, &"bloodRite", true))
					if deck_kind in ["consumer", "duplicate"]: deck.append(CardInst.new(101, &"leechBlade", true))
					if deck_kind == "duplicate": deck.append(CardInst.new(102, &"leechBlade", false))
					for id_v: Variant in db.cards:
						var id: String = str(id_v)
						for up: bool in [false, true]:
							var d: Dictionary = db.cards[id].duplicate(true)
							if up: d.merge(d.get("up", {}), true)
							var base: float = Stock.card_score(d, aspect, id)
							var expected: float = base
							if not random_build and aspect == 1:
								if id == "bloodRite":
									expected += float(str(policies[pi].status.venomousAsh))
									if deck_kind in ["consumer", "duplicate"]: expected += 2.0 * float(str(policies[pi].card.aspectBonus))
								if id == "leechBlade" and deck_kind == "source": expected += 2.0 * float(str(policies[pi].card.aspectBonus))
							var got: float = Aware.card_reward_score(d, aspect, id, deck, db)
							emit({"kind":"score", "policy":pi,"aspect":aspect,"random_build":random_build,"deck":deck_kind,"card":id,"up":up,"base":base,"expected":expected,"actual":got,"okay":got==expected and Aware.card_score(d, aspect, id)==base})
					var r1: Rng = Rng.new(73509010)
					var r2: Rng = Rng.new(73509010)
					var choices: Array = ["bloodRite","leechBlade","surge","preparation","phantomBlades"]
					var old: String = Stock.choose_card(choices, db, aspect, r1)
					var new: String = Aware.choose_card(choices, db, aspect, r2, deck)
					var null_mode: bool = random_build or aspect == 0
					emit({"kind":"choice", "policy":pi,"aspect":aspect,"random_build":random_build,"deck":deck_kind,"old":old,"new":new,"rng_old":r1.get_state(),"rng_new":r2.get_state(),"okay":r1.get_state()==r2.get_state() and (not null_mode or old==new)})
		# Remove the actual public producer effect: labels alone must not enable priority.
		Aware.set_modes(false,false); Stock.set_modes(false,false)
		var plain_source: Dictionary = original_cards.bloodRite.duplicate(true)
		plain_source.effects = plain_source.effects.filter(func(x: Variant) -> bool: return str(x.get("id", "")) != "bloodfire")
		db.cards.bloodRite = plain_source
		for id: String in ["bloodRite", "leechBlade"]:
			var d: Dictionary = original_cards[id]
			var deck: Array = [CardInst.new(103,&"bloodRite"),CardInst.new(104,&"leechBlade")]
			var score: float = Aware.card_reward_score(d,1,id,deck,db)
			emit({"kind":"absent_public_law","policy":pi,"card":id,"okay":score==Stock.card_score(d,1,id)})
		db.cards = original_cards.duplicate(true)
	emit({"kind":"content_unchanged","okay":db.cards==original_cards})
	file.store_line(JSON.stringify({"kind":"terminal","checks":count,"failures":failures}))
	file.close(); quit(0 if failures==0 else 3)
