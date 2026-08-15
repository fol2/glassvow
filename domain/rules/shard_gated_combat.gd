class_name ShardGatedCombatRules
extends CombatRules
## Production combat wrapper for reveal-ladder dialogue. Mechanics still run
## through CombatRules; only an ineligible encounter-local line is removed.


func start_combat(
		run: RunState,
		enemy_ids: Array,
		kind: StringName,
		affix: StringName = &""
) -> CombatState:
	var cb: CombatState = super.start_combat(run, enemy_ids, kind, affix)
	for enemy: EnemyCombatant in cb.enemies:
		var level: int = NarrativeGates.death_dialogue_level(enemy.variant_id)
		if level >= 0 and not NarrativeGates.allows(
				level, _projected_shard_count(run, enemy.variant_id)):
			enemy.def.erase("deathDialogue")
	return cb


## Current-run quest receipts count too: a player may reach the fourth pane
## earlier in this same journey before the third Shade falls.
func _projected_shard_count(run: RunState, variant_id: StringName) -> int:
	var seen: Dictionary = {}
	for shard_v: Variant in run.shards:
		seen[str(shard_v)] = true
	for completion_v: Variant in run.quest_completions:
		seen[str(completion_v)] = true
	if variant_id != &"ownShade3" or seen.has("ownShade"):
		return seen.size()
	var quest_v: Variant = run.quests.get("ownShade")
	if typeof(quest_v) != TYPE_DICTIONARY:
		return seen.size()
	var quest: Dictionary = quest_v
	if str(quest.get("state", "dormant")) not in ["armed", "revealed"]:
		return seen.size()
	var progress: int = int(float(str(quest.get("progress", 0))))
	var definition: Dictionary = content.quests["ownShade"]
	if progress + 1 >= int(float(str(definition.get("target", 3)))):
		seen["ownShade"] = true
	return seen.size()
