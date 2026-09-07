extends Node3D
## Reusable roofless library assembly for the isolated Act II asset study.
const M = preload("res://presentation/map/landscape/mesh_tools.gd")
var stone: ShaderMaterial = ShaderMaterial.new()
var trim: StandardMaterial3D = M.material(Color("4c586a"))
var dark: StandardMaterial3D = M.material(Color("202d3c"))
var wood: StandardMaterial3D = M.material(Color("28383c"))
var glass: ShaderMaterial = ShaderMaterial.new()
var jade: StandardMaterial3D = M.material(Color("96dec7"), .3)

var flood: float = 1.18
var connected_forecourt: bool = false

func build(flood_level: float = 1.18) -> void:
	flood = flood_level
	stone.shader = preload("res://tools/map_workshop/act2/masonry.gdshader")
	glass.shader = preload("res://tools/map_workshop/act2/glass.gdshader")
	jade.emission_enabled = true
	jade.emission = Color("66d4aa")
	jade.emission_energy_multiplier = 1.4
	# The aisles stand above the flood; the central reading court lies below it.
	M.box(self, Vector3(0,flood-.85,0),Vector3(13,1.2,11), dark,"SubmergedFoundation")
	_slab(Vector3(-5.2,1.55,0),Vector3(2.5,.8,11))
	_slab(Vector3(5.2,1.55,0),Vector3(2.5,.8,11))
	_slab(Vector3(0,1.55,-4.6),Vector3(7.9,.8,1.8))
	_slab(Vector3(0,1.55,4.6),Vector3(7.9,.8,1.8))
	if not connected_forecourt:
		_slab(Vector3(0,1.55,6.6),Vector3(4.4,.8,2.2))
	var steps: int = maxi(4,ceili((1.95-flood)/.2))
	for i: int in range(steps):
		var top: float = 1.95-(i+1)*(1.95-flood)/steps
		var bottom: float = flood-.25
		M.box(self,Vector3(0,(top+bottom)*.5,3.45-i*.28),Vector3(3.6,top-bottom,.3),stone,"FloodStair")
	for i: int in range(4):
		var x: float = -4.8+i*3.2
		_bay(Vector3(x,1.95,-5.25),0,3.2,5.7 if i in [1,2] else 4.8)
	for side: int in [-1,1]:
		for i: int in range(3):
			_bay(Vector3(side*6.25,1.95,-3.45+i*3.45),side*PI*.5,3.45,5.0-i*.45)
		for i: int in range(3):
			_shelf(Vector3(side*5.45,1.96,-3.3+i*2.65),-side*PI*.5)
		_bay(Vector3(side*4.8,1.95,5.2),0,3.1,3.4)
	_gate(Vector3(0,1.95,5.2))
	# Low reading desks remain beneath the flood rather than floating props.
	for x: float in [-2.3,2.3]:
		M.box(self,Vector3(x,flood-.21,-.6),Vector3(1.15,.18,2.7),wood,"DrownedReadingDesk")
		for z: float in [-1.5,.3]:
			M.box(self,Vector3(x,flood-.6,z),Vector3(.18,.7,.18),wood,"DeskLeg")

func _slab(at: Vector3, size: Vector3) -> void:
	var top: float = at.y+size.y*.5
	var bottom: float = flood-.5
	M.box(self,Vector3(at.x,(top+bottom)*.5,at.z),Vector3(size.x,top-bottom,size.z),stone,"AisleFoundation")
	# Large fitted flags: sparse joints, no tiled noise texture.
	var nx: int = maxi(1,roundi(size.x/1.7))
	var nz: int = maxi(1,roundi(size.z/1.8))
	for x: int in range(nx):
		for z: int in range(nz):
			M.box(self,at+Vector3((x+.5)*size.x/nx-size.x*.5,size.y*.5+.035,(z+.5)*size.z/nz-size.z*.5),Vector3(size.x/nx-.018,.07,size.z/nz-.018),stone,"AisleFlag")

func _bay(at: Vector3, yaw: float, width: float, height: float) -> void:
	var bay: Node3D = Node3D.new()
	add_child(bay)
	bay.position = at
	bay.rotation.y = yaw
	for side: int in [-1,1]:
		var x: float = side*width*.5
		M.box(bay,Vector3(x,height*.5,0),Vector3(.55,height,.7),stone,"MasonryPier")
		M.box(bay,Vector3(x,.24,.22),Vector3(.93,.48,1.3),dark,"ButtressFoot")
		M.box(bay,Vector3(x,height*.31,.26),Vector3(.64,height*.62,.9),stone,"Buttress")
		for y: float in [.55,height*.6,height-.1]:
			M.box(bay,Vector3(x,y,.12),Vector3(.73,.15,1.02),trim,"PierCourse")
		M.box(bay,Vector3(x,height+.1,0),Vector3(.7,.22,.88),trim,"PierCap")
	M.box(bay,Vector3(0,.45,0),Vector3(width,.9,.64),stone,"WindowSillWall")
	M.box(bay,Vector3(0,.95,0),Vector3(width,.18,.85),trim,"Sill")
	var aperture: float = width-.78
	_arch(bay,Vector3(0,1.04,0),aperture,height-1.1,true)

func _outline(width: float, height: float) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var spring: float = height-width*.82
	points.append(Vector2(-width*.5,0))
	points.append(Vector2(-width*.5,spring))
	for i: int in range(1,13):
		var t: float = i/12.0
		var a: Vector2 = Vector2(-width*.5,spring)
		var b: Vector2 = Vector2(-width*.44,height-width*.26)
		var c: Vector2 = Vector2(0,height)
		points.append(a*(1-t)*(1-t)+b*2*(1-t)*t+c*t*t)
	for i: int in range(11,-1,-1):
		var p: Vector2 = points[i+1]
		points.append(Vector2(-p.x,p.y))
	points.append(Vector2(width*.5,0))
	return points

func _arch(parent: Node3D, at: Vector3, width: float, height: float, glazed: bool) -> void:
	var outline: PackedVector2Array = _outline(width,height)
	if glazed:
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var indices: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
		for i: int in range(0,indices.size(),3):
			for j: int in [0,2,1]:
				var p: Vector2 = outline[indices[i+j]]
				surface.add_vertex(at+Vector3(p.x,p.y,0))
		var glass_mesh: MeshInstance3D = M.node(parent,M.finish(surface),glass,"BlueGlazing")
		glass_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i: int in range(outline.size()-1):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[i+1]
		_beam(parent,at+Vector3(a.x,a.y,.03),at+Vector3(b.x,b.y,.03),.23,.48,trim,"ArchVoussoir")
	if not glazed:
		return
	for side: float in [-.25,0,.25]:
		var top: float = height-absf(side)*width*1.25
		_beam(parent,at+Vector3(side*width,0,.1),at+Vector3(side*width,top,.1),.055,.10,dark,"Mullion")
	for level: int in range(1,4):
		var y: float = (height-width*.82)*level/4.0
		_beam(parent,at+Vector3(-width*.5,y,.1),at+Vector3(width*.5,y,.1),.045,.09,dark,"Transom")
	for side: int in [-1,1]:
		_beam(parent,at+Vector3(side*width*.25,height-width*.7,.11),at+Vector3(0,height-width*.12,.11),.06,.12,dark,"Tracery")

func _beam(parent: Node3D,a: Vector3,b: Vector3,width: float,depth: float,mat: Material,label: String) -> void:
	var beam: MeshInstance3D = M.box(parent,(a+b)*.5,Vector3(width,a.distance_to(b),depth),mat,label)
	beam.rotation.z = -atan2(b.x-a.x,b.y-a.y)

func _shelf(at: Vector3,yaw: float) -> void:
	var shelf: Node3D = Node3D.new()
	add_child(shelf)
	shelf.position = at
	shelf.rotation.y = yaw
	M.box(shelf,Vector3(0,1.3,0),Vector3(2.25,2.6,.15),wood,"ShelfBack")
	for x: float in [-1.1,1.1]:
		M.box(shelf,Vector3(x,1.3,.3),Vector3(.14,2.65,.65),wood,"ShelfUpright")
	var colours: Array[Color] = [Color("526566"),Color("4a4557"),Color("71675b"),Color("344b59")]
	for row: int in range(4):
		M.box(shelf,Vector3(0,row*.62+.09,.3),Vector3(2.3,.12,.68),wood,"ShelfBoard")
		for i: int in range(11):
			var book_height: float = .34+.1*sin(i*3.1+row)
			M.box(shelf,Vector3(-.96+i*.187,row*.62+.15+book_height*.5,.34),Vector3(.14,book_height,.38),M.material(colours[(i+row)%4]),"BookSpine")

func _gate(at: Vector3) -> void:
	var gate: Node3D = Node3D.new()
	add_child(gate)
	gate.position = at
	_arch(gate,Vector3.ZERO,3.8,4.1,false)
	for side: int in [-1,1]:
		M.box(gate,Vector3(side*1.96,1.7,0),Vector3(.52,3.4,.7),stone,"GatewayPier")
		M.box(gate,Vector3(side*1.96,.2,0),Vector3(.8,.4,.95),trim,"GatewayFoot")
		_beam(gate,Vector3(side*1.96,3,0),Vector3(side*2.8,3,0),.1,.13,dark,"LanternArm")
		_beam(gate,Vector3(side*2.8,3,0),Vector3(side*2.8,2.35,0),.035,.04,dark,"LanternChain")
		M.box(gate,Vector3(side*2.8,2.12,0),Vector3(.3,.45,.3),jade,"JadeLantern")
		for y: float in [1.87,2.37]:
			M.box(gate,Vector3(side*2.8,y,0),Vector3(.4,.08,.4),dark,"LanternCrown")
		var light: OmniLight3D = OmniLight3D.new()
		gate.add_child(light)
		light.position = Vector3(side*2.8,2.15,.3)
		light.light_color = Color("81d5b0")
		light.light_energy = .65
		light.omni_range = 4
