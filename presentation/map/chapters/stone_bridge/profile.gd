extends RefCounted
## Chapter-independent masonry proportions. Distances are world metres.
static func soffit(height: float, station: float, total: float, raised: bool,
		settings: Dictionary = {}) -> float:
	var thickness: float = settings.get("crown_thickness", .46)
	if raised:
		var end: float = minf(station,total-station)
		var pier: float = settings.get("pier_width",1.3)*.5
		if end<=pier:
			return -.4
		var half_opening: float = maxf(.3,total*.5-pier)
		var unit: float = (station-total*.5)/half_opening
		var sag: float = settings.get("crossing_arch_rise",.85)
		return height-thickness-sag+sag*sqrt(maxf(0.0,1.0-unit*unit))
	var spacing: float = settings.get("arch_spacing", 8.0)
	var pier_width: float = settings.get("pier_width", 1.3)
	var arches: int = maxi(1,roundi(total/spacing))
	var bay: float = total/arches
	var half_opening: float = maxf(.3,(bay-pier_width)*.5)
	var local: float = fposmod(station,bay)-bay*.5
	if absf(local)>=half_opening:
		return -.4
	var crown: float = height-thickness
	var spring: float = minf(1.35,crown-.25)
	var unit: float = local/half_opening
	return spring+(crown-spring)*sqrt(maxf(0.0,1.0-unit*unit))
