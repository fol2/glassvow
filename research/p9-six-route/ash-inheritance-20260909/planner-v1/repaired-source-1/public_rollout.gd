extends RefCounted
## Minimum runtime compatibility: preserve existing research intervention flags.
const Base: GDScript = preload("res://public_rollout_base.gd")
const SWITCHES: Array[String] = ["bloodfire_enabled", "bloodfire_producer_enabled", "bloodfire_consumer_enabled"]
static func clone_public(g: GlassvowGame, sample: int) -> GlassvowGame:
 var out: GlassvowGame = Base.clone_public(g,sample)
 for prop: Dictionary in g.rules.get_property_list():
  var key: String = str(prop.name)
  if key in SWITCHES:out.rules.set(key,g.rules.get(key))
 return out
