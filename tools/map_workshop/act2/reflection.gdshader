shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 colour : source_color = vec4(.2,.3,.4,1.0);
varying vec3 world_at;
void vertex() { world_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	if (world_at.y < 1.18) { discard; }
	ALBEDO = colour.rgb;
}
