extends RefCounted
## Executable checks on the actual generated city's assembled triangles.
static func failures(report: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if report.get("nodes",-1)!=report.get("expected_nodes",-2) or report.get("edges",-1)!=report.get("expected_edges",-2):
		out.append("Generated node or route coverage changed")
	if not report.get("missing_route_samples",["missing"]).is_empty(): out.append("Uncovered route field samples")
	if report.get("rendered_deck",{}).get("missing",-1)!=0: out.append("Missing rendered deck")
	if report.get("bridge_walkway",{}).get("decoration_hits",-1)!=0: out.append("Masonry obstructs the walking corridor")
	var joints: float = report.get("bridgehead_overlap",{}).get("maximum_surface_separation",INF)
	if joints>.035: out.append("Bridgehead surfaces separate by more than 35 mm")
	var headroom: float = report.get("rendered_width_checks",{}).get("minimum_headroom",-INF)
	if headroom<2.45: out.append("Crossing headroom is below the production 2.45 m reservation")
	var dry: float = report.get("minimum_dry_margin",-INF)
	if dry<=0: out.append("A gameplay route lies below the waterline")
	var endpoint: float = report.get("maximum_endpoint_height_error",INF)
	if endpoint>.035: out.append("The fitted route does not meet its node height")
	return out
