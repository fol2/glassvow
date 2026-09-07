extends "res://presentation/map/landscape/landform.gd"
## City terraces use the proven graph grading, without Act I's river incision.
func upland(_x: float, _z: float) -> float:
	return 4.8

func natural_height(x: float,z: float) -> float:
	return upland(x,z)-cut_depth(x,z)

func height(x: float,z: float) -> float:
	var at: Vector2 = Vector2(x,z)
	var total: float = 0
	var weight_sum: float = 0
	var candidates: Array = ground_cells.get(Vector2i(floori(x/4),floori(z/4)),[])
	for segment: Array in candidates:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(at,a,b)
		var distance: float = at.distance_to(closest)
		var t: float = clampf((closest-a).dot(b-a)/maxf(.000001,a.distance_squared_to(b)),0,1)
		var weight: float = exp(-distance*distance/.4)*a.distance_to(b)/maxf(.000001,distance*distance)
		var ha: float = segment[2]
		var hb: float = segment[3]
		total += lerpf(ha,hb,t)*weight
		weight_sum += weight
	# Close to a route, its own graded segments dominate neighbouring branches.
	# This preserves the shared bridgehead height without a radial height bump.
	return total/weight_sum if weight_sum>.000001 else natural_height(x,z)
