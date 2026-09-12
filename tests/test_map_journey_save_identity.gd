extends RefCounted
## A JSON save round-trip must not invalidate a visually identical section.
const Binding = preload("res://presentation/map/map_journey_input.gd")
static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	for act: int in range(4):
		for seed_value: int in [0,1,4,7,42,717,17634]:
			var run: RunState = RunState.new_run(content,seed_value)
			run.act=act
			var world: WorldMap = WorldMap.for_run(run,content)
			var before: Dictionary = world.to_dict()
			var rng_before: int = run.rng_state()
			var original: Dictionary = Binding.bind(world,act)
			var digest: String = MapLayoutCanonical.digest(original)
			if world.to_dict()!=before or run.rng_state()!=rng_before:
				fails.append("journey save identity: presentation mutated game truth")
			var raw: Dictionary = before
			for iteration: int in range(3):
				raw=JSON.parse_string(JSON.stringify(raw))
				var restored: WorldMap = WorldMap.from_dict(raw)
				if restored==null or MapLayoutCanonical.digest(Binding.bind(restored,act))!=digest:
					fails.append("journey save identity: changed across save: act=%d seed=%d round=%d"%[act,seed_value,iteration])
					break
				raw=restored.to_dict()
			var raw_bound: Dictionary = MapLayoutInputBinding.bind(world,act)
			for i: int in range(original["nodes"].size()):
				var a: Dictionary = original["nodes"][i]
				var b: Dictionary = raw_bound["nodes"][i]
				for axis: int in range(2):
					if absf(float(str(a["jitter"][axis]))-float(str(b["jitter"][axis])))>.000000000501:
						fails.append("journey save identity: changed geometry beyond the declared sub-nanounit rounding")
				a=a.duplicate(true)
				a["jitter"]=b["jitter"]
				if a!=b: fails.append("journey save identity: changed node truth")
			if original["edges"]!=raw_bound["edges"]:
				fails.append("journey save identity: changed topology")
