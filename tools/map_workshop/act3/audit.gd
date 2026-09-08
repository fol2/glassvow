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
	# Retain the receipt key for shared tooling; the obstacle geometry is chapter-specific.
	result["bridge_walkway"]["scope"] = "Actual solid terrace triangles over rendered treads; five lateral samples across a 1.5 m corridor, 2.12 m body height."
	return result
