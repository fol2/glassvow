extends "res://presentation/map/landscape/bridge_surfaces.gd"
## A single entrance apron, clipped against the actual causeway footprint.
var road: RefCounted
var origin: Vector3
var low: Vector2
var high: Vector2

func build(parent: Node3D, library_at: Vector3, causeways: Node3D) -> Node3D:
	origin = library_at
	road = causeways.fields[0]
	low = Vector2(origin.x-2.2,origin.z+5.5)
	high = Vector2(origin.x+2.2,origin.z+8.0)
	for x: int in range(floori(low.x/CELL)-1,ceili(high.x/CELL)+1):
		for z: int in range(floori(low.y/CELL)-1,ceili(high.y/CELL)+1):
			cells[Vector2i(x,z)] = []
	var top: SurfaceTool = SurfaceTool.new()
	var walls: SurfaceTool = SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	append(top,walls)
	var apron: Node3D = Node3D.new()
	apron.name = "FittedLibraryForecourt"
	parent.add_child(apron)
	var paving: ShaderMaterial = ShaderMaterial.new()
	paving.shader = preload("res://tools/map_workshop/stone_bridge/paving.gdshader")
	var stone: ShaderMaterial = ShaderMaterial.new()
	stone.shader = preload("res://tools/map_workshop/act2/masonry.gdshader")
	Meshes.node(apron,Meshes.finish(top),paving,"ForecourtSurface")
	Meshes.node(apron,Meshes.finish(walls),stone,"ForecourtFoundation")
	return apron

func field(at: Vector2) -> Dictionary:
	var centre: Vector2 = (low+high)*.5
	var extent: Vector2 = (high-low)*.5
	var delta: Vector2 = (at-centre).abs()-extent
	var rectangle_distance: float = Vector2(maxf(delta.x,0),maxf(delta.y,0)).length()+minf(maxf(delta.x,delta.y),0)
	var route: Dictionary = road.field(at)
	var road_distance: float = route["distance"]
	return {"distance":maxf(rectangle_distance,-road_distance),"height":origin.y+2.02,
		"bottom":.68,"blend":1.0,"uv":at}
