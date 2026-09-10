extends SceneTree
## Complete finite fast-path domain and hostile fallbacks; not a package test.
const Reference: GDScript = preload("res://reference_ji.gd")
const Refined: GDScript = preload("res://refined_ji.gd")
var reference: RefCounted = Reference.new()
var refined: RefCounted = Refined.new()
var count: int = 0
var failed: int = 0
var unsafe_counterexamples: int = 0
var types: Dictionary = {}
var eligible: int = 0
var numeric_values: Array = []
var out: FileAccess

func check(value: Variant, category: String) -> void:
 var expected: int = reference.ji(value)
 var actual: int = refined.ji(value)
 var unsafe: int = int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else expected
 count += 1
 if expected != actual:failed += 1
 if expected != unsafe:unsafe_counterexamples += 1
 out.store_line(JSON.stringify({"kind":"conversion", "category":category,
  "input":str(value), "type":typeof(value), "expected":expected,
  "actual":actual, "unsafe":unsafe}))

func walk(value: Variant) -> void:
 if value is Dictionary:
  for key: Variant in value:walk(value[key])
 elif value is Array:
  for item: Variant in value:walk(item)
 elif typeof(value) in [TYPE_INT, TYPE_FLOAT]:
  var key: String = str(typeof(value))
  types[key] = int(types.get(key, 0)) + 1
  numeric_values.append(value)
  if typeof(value)==TYPE_FLOAT and value>=-1024.0 and value<=1024.0 and value==float(int(value)):
   eligible += 1
  check(value,"pinned_content")

func timed(which: RefCounted, repeats: int) -> Dictionary:
 var checksum: int = 0
 var begin: int = Time.get_ticks_usec()
 for repetition: int in range(repeats):
  for value: Variant in numeric_values:checksum += which.ji(value)
 return {"usec":Time.get_ticks_usec()-begin, "checksum":checksum,
  "calls":repeats*numeric_values.size()}

func _initialize() -> void:
 var args: PackedStringArray = OS.get_cmdline_user_args()
 if args.size()!=2:quit(2);return
 out=FileAccess.open(args[1],FileAccess.WRITE)
 if out==null:quit(2);return
 var content: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 if not content is Dictionary:quit(2);return
 out.store_line(JSON.stringify({"kind":"header", "engine":Engine.get_version_info()["string"],
  "content_sha256":FileAccess.get_sha256(args[0]),
  "reference_sha256":FileAccess.get_sha256("res://reference_ji.gd"),
  "refined_sha256":FileAccess.get_sha256("res://refined_ji.gd")}))
 for integer: int in range(-1024,1025):
  check(float(integer),"exhaustive_float")
  check(integer,"existing_integer")
  for offset: float in [-0.25,0.25,-0.000000000001,0.000000000001]:
   check(float(integer)+offset,"fractional_neighbor")
 var extras: Array = [-0.0,0.0,-1025.0,1025.0,9.999999999999998,-9.999999999999998,
  9007199254740991,9007199254740992,9007199254740993,-9007199254740993,
  9223372036854775807,-9223372036854775807,1e-8,1e8,1.75,-1.75,
  "42","-1.75",&"42",true,false,null]
 for value: Variant in extras:check(value,"fallback")
 walk(content)
 var timings: Array = []
 for repetition: int in range(2):
  var pair: Dictionary = {}
  for name: String in (["reference","refined"] if repetition==0 else ["refined","reference"]):
   pair[name]=timed(reference if name=="reference" else refined, 32)
  if pair.reference.checksum!=pair.refined.checksum:failed+=1
  timings.append(pair)
 if unsafe_counterexamples==0 or eligible==0:failed+=1
 out.store_line(JSON.stringify({"kind":"terminal", "checks":count, "failed":failed,
  "exhaustive_integral_floats":2049, "unsafe_counterexamples":unsafe_counterexamples,
  "content_numeric_types":types, "content_guard_eligible":eligible,
  "numeric_timings_descriptive_only":timings, "packages_admitted":0,"p9_certified":false}))
 out.close()
 quit(0 if failed==0 else 3)
