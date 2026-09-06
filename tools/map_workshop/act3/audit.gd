extends RefCounted
## Bounded native proof of the real chapter paths, not the concept image.
static func measure(routes: Node3D,sample: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"nodes":routes.anchors.size(),"edges":routes.sampled_routes.size(),
		"source_digest":sample["layout_digest"],
		"rendered_deck":preload("res://tools/map_workshop/act2/deck_audit.gd").measure(routes),
		"bridge_walkway":preload("res://tools/map_workshop/act2/bridge_walkway_audit.gd").measure(routes),
		"destination_count":routes.ruin_plan.sites.size(),
		"destination_owner":routes.ruin_plan.sites[0]["node"],
		"scope":"Seed 717 native rendered routes; architectural and terrain clearance require separate proof"
	}
	return result
