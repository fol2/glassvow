extends RefCounted
## Small reusable vertex-coloured aquatic silhouettes; three shapes per family.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
const KINDS: Array[String] = ["slate","reeds","kelp","floating_leaves","driftwood","snag"]
var surface: SurfaceTool
var meshes: Dictionary = {}
var material: StandardMaterial3D

func build() -> void:
	material = M.material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for kind: String in KINDS:
		for variant: int in range(3):
			surface = SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_smooth_group(-1)
			_shape(kind,variant)
			meshes[kind+str(variant)] = M.finish(surface)

func _shape(kind: String,v: int) -> void:
	if kind in ["slate","reeds","snag"]:
		for i: int in range(4):
			var angle: float = i*2.4+v*.7
			_rock(Vector3(sin(angle)*.7,-.1,cos(angle)*.65),Vector3(.85,.65 if kind!="slate" else 1.0+i*.16,.7),Color("3e555c").lightened(i*.025),angle)
	if kind=="slate":
		_rock(Vector3(.1,.3,0),Vector3(.9,1.0,.6),Color("607477"),v*.7)
	elif kind in ["reeds","kelp"]:
		for i: int in range(13 if kind=="reeds" else 8):
			var angle: float = i*2.399+v*.6
			var start: Vector3 = Vector3(sin(angle)*.5,-.55,cos(angle)*.5)
			var height: float = 1.8+_fraction(i*13+v*7)*1.2
			var bend: Vector3 = Vector3(sin(angle)*.55,0,cos(angle)*.55)
			var colour: Color = Color("567d73") if kind=="reeds" else Color("305e5b")
			_leaf(start,bend,height,.085 if kind=="reeds" else .3,colour.lightened((i%3)*.04),angle)
			if kind=="reeds" and i%3==0:
				_branch(start+Vector3.UP*height*.72+bend*.55,start+Vector3.UP*height*.87+bend*.72,.06,Color("8d9076"))
	elif kind=="floating_leaves":
		for i: int in range(7):
			var angle: float = i*2.4+v*.8
			var at: Vector3 = Vector3(sin(angle)*(.25+i*.16),1.205+i*.001,cos(angle)*(.25+i*.16))
			var radius: float = .25+_fraction(i*5+v)*.25
			for j: int in range(1,10):
				var a: float = angle+j*TAU/11
				var b: float = angle+(j+1)*TAU/11
				_tri(at+Vector3.UP*.025,at+Vector3(sin(a),0,cos(a))*radius,at+Vector3(sin(b),0,cos(b))*radius,Color("41685f").lightened((j%3)*.025))
	elif kind=="driftwood":
		_branch(Vector3(-1.2,.86,-.3),Vector3(1.2-v*.12,1.3,.4+v*.2),.18,Color("59635f"))
		_branch(Vector3(-.3,1.05,0),Vector3(.1+v*.2,1.5,-.8-v*.15),.09,Color("778076"))
		_branch(Vector3(.5,1.2,.2),Vector3(1.0,.86,1),.075,Color("3c514f"))
	elif kind=="snag":
		var top: Vector3 = Vector3(.2+v*.15,2.9-v*.3,.1)
		_branch(Vector3(0,-.5,0),top,.18,Color("596b69"))
		_branch(top*.5,Vector3(-.7,2.1,-.3),.085,Color("677874"))
		_branch(top*.65,Vector3(.85,2.65,.6),.075,Color("77857b"))

func _leaf(start: Vector3,bend: Vector3,height: float,width: float,colour: Color,angle: float) -> void:
	var side: Vector3 = Vector3(cos(angle),0,-sin(angle))
	for i: int in range(6):
		var t: float = i/6.0
		var u: float = (i+1)/6.0
		var a: Vector3 = start+Vector3.UP*height*t+bend*t*t+side*sin(t*PI*2)*width*.5
		var b: Vector3 = start+Vector3.UP*height*u+bend*u*u+side*sin(u*PI*2)*width*.5
		var wa: float = width*sin(.1+t*.9*PI)
		var wb: float = width*sin(.1+u*.9*PI)
		_tri(a-side*wa,a+side*wa,b+side*wb,colour)
		_tri(a-side*wa,b+side*wb,b-side*wb,colour.lightened(.035))

func _rock(at: Vector3,size: Vector3,colour: Color,yaw: float) -> void:
	for ring: int in range(4):
		var a: float = PI*ring/4
		var b: float = PI*(ring+1)/4
		for i: int in range(7):
			var c: float = i*TAU/7+yaw
			var d: float = (i+1)*TAU/7+yaw
			var p: Vector3 = at+Vector3(sin(a)*cos(c),cos(a),sin(a)*sin(c))*size
			var q: Vector3 = at+Vector3(sin(a)*cos(d),cos(a),sin(a)*sin(d))*size
			var r: Vector3 = at+Vector3(sin(b)*cos(d),cos(b),sin(b)*sin(d))*size
			var s: Vector3 = at+Vector3(sin(b)*cos(c),cos(b),sin(b)*sin(c))*size
			_tri(p,q,r,colour)
			_tri(p,r,s,colour)

func _branch(a: Vector3,b: Vector3,radius: float,colour: Color) -> void:
	var up: Vector3 = (b-a).normalized()
	var right: Vector3 = up.cross(Vector3.FORWARD).normalized()
	var forward: Vector3 = up.cross(right).normalized()
	for i: int in range(6):
		var p: Vector3 = (right*cos(i*TAU/6)+forward*sin(i*TAU/6))*radius
		var q: Vector3 = (right*cos((i+1)*TAU/6)+forward*sin((i+1)*TAU/6))*radius
		_tri(a+p,a+q,b+q*.5,colour)
		_tri(a+p,b+q*.5,b+p*.5,colour)
		_tri(b,b+p*.5,b+q*.5,colour.lightened(.1))

func _fraction(value: int) -> float:
	return fposmod(sin(value*17.13+2.5)*437.58,1.0)

func _tri(a: Vector3,b: Vector3,c: Vector3,colour: Color) -> void:
	M.triangle(surface,a,b,c,colour)
