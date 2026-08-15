class_name NarrativeGates
extends RefCounted
## Shard-count gates shared by every narrative pool. The content ledger says
## what level a line carries; this class says whether that level may be drawn.
##
## L4 also requires being inside Act IV, so it is deliberately outside this
## shard-only helper. Its route owns that additional condition.

const L0: int = 0
const L1: int = 1
const L2: int = 2
const L3: int = 3

const L1_SHARDS: int = 1
const L2_SHARDS: int = 4
const L3_SHARDS: int = 6
const LOSS_POOL_SIZE: int = 50


static func allows(level: int, shard_count: int) -> bool:
	var carried: int = maxi(0, shard_count)
	match level:
		L0:
			return true
		L1:
			return carried >= L1_SHARDS
		L2:
			return carried >= L2_SHARDS
		L3:
			return carried >= L3_SHARDS
	return false


## Return the next never-repeated slot, or -1 when the channel is still sealed
## or its authored pool has been exhausted. `consumed` is persisted by the
## caller; this helper never mutates cross-run state.
static func pool_index(
		consumed: int, pool_size: int, level: int, shard_count: int
) -> int:
	if not allows(level, shard_count) or pool_size <= 0:
		return -1
	if consumed < 0 or consumed >= pool_size:
		return -1
	return consumed


static func loss_pool_index(consumed: int, shard_count: int) -> int:
	return pool_index(consumed, LOSS_POOL_SIZE, L1, shard_count)


## Existing variant dialogue is the first quest surface that can outrun its
## reveal level. -1 means the variant is not managed by this subsystem.
static func death_dialogue_level(variant_id: StringName) -> int:
	match variant_id:
		&"ownShade1", &"ownShade2":
			return L1
		&"ownShade3":
			return L2
	return -1
