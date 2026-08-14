extends SceneTree
## Probe for #233 measurement item 4: does the cel quantiser turn triplanar's
## blend band into a visible contour on presentation/map/map_prop.gdshader?
## An appearance question, not an A12 question, so any GPU answers it.
##
## THE RIG. A cylinder whose axis lies along X under an orthographic camera
## looking down -Z. Its normal is (0, cos phi, sin phi), so a vertical scanline
## sweeps phi and the triplanar Y and Z weights cross over at 45 and 135. Two
## properties make it measurable: screen row is monotone in phi, and the
## cylinder axis is the one direction the camera does not foreshorten — so
## luminance statistics taken ALONG a row sit at constant phi, constant N.L and
## constant foreshortening, and the only thing varying along that row is
## albedo. The probe tile carries no mipmaps, so mip selection cannot
## masquerade as a blend effect. Y0 is 1.61 and not 0 on purpose: at phi = 45
## the Y plane samples world (x, z) and the Z plane samples (x, y), which are
## the same coordinate when the cylinder is centred on the origin — the two
## planes would fetch the same texel and the blend would have nothing to blend.
##
## MEASURED per (bands, sharpness). c90/c45/c135 are row contrast (stddev of
## luminance along the row) at phi 90 — where the weights are (0,0,1), a
## genuine single-tap reference — and at each crossover; dip is the contrast
## the blend destroys, for which two decorrelated samples averaged predict 29%.
## w_px is the contiguous rows about the crossover under 0.9 of reference, and
## pred_px the same width predicted from the weights alone, so a match confirms
## the mechanism rather than merely observing it. step45 is the largest single
## row luminance step at the crossover — an EDGE, which is what "contour"
## means — and stepmax the largest anywhere on the sweep, which at bands = 3 is
## a cel band edge: the thing a contour has to compete with to read as one.
## bands = 128 is the smooth control, the same shader with the quantiser
## effectively off. It also settles two things this repo has never run:
## whether MultiMesh custom data reaches INSTANCE_CUSTOM (#207 repair 4 rides
## on it) and where the ground/prop value gap (#207 repair 8) actually lands.
##
## Not a test; needs a real renderer, and it renders 3D:
##   godot --path . --position -4000,-4000 -s res://tools/probe_map_shaders.gd

const TEX: int = 256          # probe surface tile, px
const CELLS: int = 16         # value-noise cells across the tile
const R: float = 1.0          # cylinder radius, world
const Y0: float = 1.61        # cylinder centre height — see header
const ORTHO: float = 2.6      # camera vertical extent, world
const SWATCH_X: float = 1.55  # value-gap swatches, outside the analysis band

var _prop: ShaderMaterial
var _tex_mean: float = 0.5
var _ppd: float = 1.0         # px per degree of phi at the crossover
var _h: int = 1
var _segments: int = 0


func _initialize() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	root.add_child(world_env)

	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ORTHO
	cam.position = Vector3(0.0, Y0, 4.0)
	root.add_child(cam)
	cam.current = true

	var surface: ImageTexture = _noise_tex()
	var neutral: ImageTexture = _flat_tex()
	_prop = _material("res://presentation/map/map_prop.gdshader", surface, neutral, 0.100)

	var barrel: CylinderMesh = CylinderMesh.new()
	barrel.top_radius = R
	barrel.bottom_radius = R
	barrel.height = 12.0
	barrel.radial_segments = 512
	_segments = barrel.radial_segments
	barrel.cap_top = false
	barrel.cap_bottom = false
	var cyl: MeshInstance3D = MeshInstance3D.new()
	cyl.mesh = barrel
	cyl.material_override = _prop
	cyl.position = Vector3(0.0, Y0, 0.0)
	cyl.rotation = Vector3(0.0, 0.0, PI * 0.5)   # axis +Y -> axis +X
	root.add_child(cyl)

	_swatch(_material("res://presentation/map/map_ground.gdshader", surface, neutral, 0.420),
		-SWATCH_X)
	_swatch(_prop, SWATCH_X)
	_instance_strip(neutral)

	await process_frame
	await process_frame
	await _report()
	quit(0)


func _material(path: String, surface: ImageTexture, neutral: ImageTexture,
		value: float) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(path) as Shader
	mat.set_shader_parameter("surface_tex", surface)
	mat.set_shader_parameter("grade", neutral)
	mat.set_shader_parameter("tex_stop", 3)
	mat.set_shader_parameter("tex_mean", _tex_mean)
	mat.set_shader_parameter("surface_value", value)
	return mat


func _swatch(mat: ShaderMaterial, x: float) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.position = Vector3(x, Y0, 2.0)
	root.add_child(node)


## Three MultiMesh instances carrying custom data 0.25 / 0.50 / 0.75 in .r,
## drawn by a shader that outputs INSTANCE_CUSTOM.rgb and nothing else. This
## is the plumbing #207 repair 4 rides on and it has never been exercised in
## this tree, so it is measured rather than assumed.
func _instance_strip(neutral: ImageTexture) -> void:
	var probe_shader: Shader = Shader.new()
	probe_shader.code = "shader_type spatial;\n" \
		+ "render_mode unshaded, cull_disabled;\n" \
		+ "varying vec3 custom;\n" \
		+ "void vertex() { custom = INSTANCE_CUSTOM.rgb; }\n" \
		+ "void fragment() { ALBEDO = custom; }\n"
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = probe_shader
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = 3
	for i: int in range(3):
		mm.set_instance_transform(i,
			Transform3D(Basis(), Vector3(-0.6 + 0.6 * float(i), 0.45, 2.0)))
		mm.set_instance_custom_data(i, Color(0.25 + 0.25 * float(i), 0.0, 0.0, 1.0))
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	root.add_child(node)


# ── the surface tile ──────────────────────────────────────────────────────
func _hash01(ix: int, iy: int, cells: int) -> float:
	var a: int = posmod(ix, cells)
	var b: int = posmod(iy, cells)
	var h: int = (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


func _value(u: float, v: float, cells: int) -> float:
	var fx: float = u * float(cells)
	var fy: float = v * float(cells)
	var ix: int = floori(fx)
	var iy: int = floori(fy)
	var tx: float = fx - float(ix)
	var ty: float = fy - float(iy)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var lo: float = lerpf(_hash01(ix, iy, cells), _hash01(ix + 1, iy, cells), tx)
	var hi: float = lerpf(_hash01(ix, iy + 1, cells), _hash01(ix + 1, iy + 1, cells), tx)
	return lerpf(lo, hi, ty)


## Two octaves, tiling at the image edge, no mipmaps — see header.
func _noise_tex() -> ImageTexture:
	var img: Image = Image.create_empty(TEX, TEX, false, Image.FORMAT_RGB8)
	var total: float = 0.0
	for y: int in range(TEX):
		for x: int in range(TEX):
			var u: float = float(x) / float(TEX)
			var v: float = float(y) / float(TEX)
			var n: float = _value(u, v, CELLS) * 0.62 + _value(u, v, CELLS * 4) * 0.38
			n = clampf(0.10 + n * 0.90, 0.0, 1.0)
			total += n
			img.set_pixel(x, y, Color(n, n, n, 1.0))
	_tex_mean = total / float(TEX * TEX)
	return ImageTexture.create_from_image(img)


func _flat_tex() -> ImageTexture:
	var img: Image = Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(img)


# ── measurement ───────────────────────────────────────────────────────────
## Row means and row standard deviations of luminance over the central column
## band, which is clear of the swatches at +-SWATCH_X.
func _profile(img: Image) -> Array[PackedFloat32Array]:
	img.convert(Image.FORMAT_RGB8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var x0: int = int(float(w) * 0.30)
	var x1: int = int(float(w) * 0.70)
	var data: PackedByteArray = img.get_data()
	var mean: PackedFloat32Array = PackedFloat32Array()
	var dev: PackedFloat32Array = PackedFloat32Array()
	mean.resize(h)
	dev.resize(h)
	var n: float = float(x1 - x0)
	for y: int in range(h):
		var sum: float = 0.0
		var sq: float = 0.0
		var base: int = y * w * 3
		for x: int in range(x0, x1):
			var i: int = base + x * 3
			var l: float = (0.2126 * float(data[i]) + 0.7152 * float(data[i + 1])
				+ 0.0722 * float(data[i + 2])) / 255.0
			sum += l
			sq += l * l
		var m: float = sum / n
		mean[y] = m
		dev[y] = sqrt(maxf(sq / n - m * m, 0.0))
	return [mean, dev]


func _row(phi_deg: float) -> int:
	var wy: float = R * cos(deg_to_rad(phi_deg))
	return roundi(float(_h) * 0.5 - wy * float(_h) / ORTHO - 0.5)


func _band_mean(arr: PackedFloat32Array, a_deg: float, b_deg: float) -> float:
	var lo: int = _row(a_deg)
	var hi: int = _row(b_deg)
	var sum: float = 0.0
	for y: int in range(lo, hi + 1):
		sum += arr[y]
	return sum / float(hi - lo + 1)


func _steps(mean: PackedFloat32Array, a_deg: float, b_deg: float) -> float:
	var lo: int = _row(a_deg)
	var hi: int = _row(b_deg)
	var top: float = 0.0
	for y: int in range(lo, hi):
		top = maxf(top, absf(mean[y + 1] - mean[y]))
	return top


## Row contrast is a noisy statistic — a single row above threshold would
## truncate a contiguous run — so the profile is box-filtered over +-6 rows
## before the width is read off it.
func _smooth(src: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(src.size())
	for y: int in range(src.size()):
		var sum: float = 0.0
		var n: int = 0
		for k: int in range(maxi(y - 6, 0), mini(y + 7, src.size())):
			sum += src[k]
			n += 1
		out[y] = sum / float(n)
	return out


func _dip_width(dev: PackedFloat32Array, centre_deg: float, ref: float) -> int:
	var c: int = _row(centre_deg)
	var limit: float = ref * 0.9
	var span: int = 0
	for y: int in range(c, _row(centre_deg + 40.0)):
		if dev[y] >= limit:
			break
		span += 1
	for y: int in range(c - 1, _row(centre_deg - 40.0), -1):
		if dev[y] >= limit:
			break
		span += 1
	return span


func _patch(img: Image, cx: int, cy: int) -> float:
	var sum: float = 0.0
	for y: int in range(cy - 8, cy + 9):
		for x: int in range(cx - 8, cx + 9):
			var c: Color = img.get_pixel(x, y)
			sum += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	return sum / 289.0


func _report() -> void:
	var first: Image = root.get_viewport().get_texture().get_image()
	_h = first.get_height()
	var w: int = first.get_width()
	var ppw: float = float(_h) / ORTHO              # px per world unit
	_ppd = R * sin(deg_to_rad(45.0)) * ppw * deg_to_rad(1.0)
	print("viewport %dx%d, %.1f px/world, %.3f px/deg at the crossover"
		% [w, _h, ppw, _ppd])
	print("tile mean luminance %.4f, two octaves, no mipmaps; %d radial segments"
		% [_tex_mean, _segments])

	# INSTANCE_CUSTOM, and with it whether the render target is sRGB.
	var mid: int = roundi(float(_h) * 0.5 - (0.45 - Y0) * ppw)
	var got: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(3):
		got.append(first.get_pixel(int(float(w) * 0.5 + (-0.6 + 0.6 * float(i)) * ppw), mid).r)
	print("INSTANCE_CUSTOM set 0.250/0.500/0.750 -> read %.3f/%.3f/%.3f raw, "
		% [got[0], got[1], got[2]]
		+ "%.3f/%.3f/%.3f srgb-decoded"
		% [_to_linear(got[0]), _to_linear(got[1]), _to_linear(got[2])])

	# #207 repair 8, on screen rather than on paper.
	var gnd: float = _patch(first, int(float(w) * 0.5 - SWATCH_X * ppw), int(float(_h) * 0.5))
	var prp: float = _patch(first, int(float(w) * 0.5 + SWATCH_X * ppw), int(float(_h) * 0.5))
	print("value gap: ground %.3f, prop %.3f, gap %.3f (anchor 0.68/0.35, gap 0.33)"
		% [gnd, prp, gnd - prp])

	print("")
	print("bands sharp    c90    c45   dip%  c135 dip%  w_px pred_px  step45 stepmax ratio")
	var cels: Array[int] = [3, 128]
	var sharps: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0, 32.0]
	for cel: int in cels:
		for sharp: float in sharps:
			_prop.set_shader_parameter("bands", cel)
			_prop.set_shader_parameter("sharpness", sharp)
			await process_frame
			await process_frame
			var img: Image = root.get_viewport().get_texture().get_image()
			if cel == 3 and (sharp == 2.0 or sharp == 32.0):
				img.save_png("/tmp/p233-cel3-s%d.png" % int(sharp))
			elif cel == 128 and sharp == 2.0:
				img.save_png("/tmp/p233-smooth-s2.png")
			var prof: Array[PackedFloat32Array] = _profile(img)
			var mean: PackedFloat32Array = prof[0]
			var dev: PackedFloat32Array = prof[1]
			var c90: float = _band_mean(dev, 85.0, 95.0)
			var c45: float = _band_mean(dev, 43.0, 47.0)
			var c135: float = _band_mean(dev, 133.0, 137.0)
			var step45: float = _steps(mean, 41.0, 49.0)
			var stepmax: float = _steps(mean, 10.0, 170.0)
			var pred: float = 2.0 * (45.0 - rad_to_deg(atan(pow(_crit(c90, c45), 1.0 / sharp)))) * _ppd
			print("%5d %5.0f %6.4f %6.4f %5.1f %6.4f %4.1f %5d %7.1f %7.4f %7.4f %5.2f"
				% [cel, sharp, c90, c45, 100.0 * (1.0 - c45 / maxf(c90, 1e-6)),
				c135, 100.0 * (1.0 - c135 / maxf(c90, 1e-6)),
				_dip_width(_smooth(dev), 45.0, c90), pred, step45, stepmax,
				step45 / maxf(stepmax, 1e-6)])
	print("")
	print("shots: /tmp/p233-cel3-s2.png /tmp/p233-cel3-s32.png /tmp/p233-smooth-s2.png")


## The weight ratio at which a blend of two planes correlated like these two
## drops to 0.9 of single-tap contrast: contrast = sqrt(w1^2 + w2^2 + 2*rho*
## w1*w2) with w1 + w2 = 1, and rho recovered from the measured 50/50 dip.
func _crit(c90: float, c45: float) -> float:
	var half: float = c45 / maxf(c90, 1e-6)
	var rho: float = clampf(2.0 * half * half - 1.0, -0.99, 0.99)
	var d2: float = (0.81 - 0.5 * (1.0 + rho)) / maxf(2.0 - 2.0 * rho, 1e-6)
	if d2 <= 0.0:
		return 1.0
	var d: float = minf(sqrt(d2), 0.499)
	return (0.5 - d) / (0.5 + d)


func _to_linear(s: float) -> float:
	return s / 12.92 if s <= 0.04045 else pow((s + 0.055) / 1.055, 2.4)
