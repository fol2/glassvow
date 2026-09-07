shader_type spatial;
uniform vec4 stone_colour : source_color = vec4(0.15,0.15,0.19,1.0);
uniform vec2 roughness_range = vec2(0.68,0.82);
uniform vec2 slab_size = vec2(4.8,3.2);
uniform float joint_coverage : hint_range(0.0,1.0) = 0.25;
uniform float joint_strength : hint_range(0.0,1.0) = 0.25;
// Opt-in model-space courses for reusable architectural kit surfaces.
uniform bool architectural_mapping = false;
// Optional architectural inlay. Disabled unless the chapter supplies a radius.
uniform vec3 inlay_centre = vec3(0.0);
uniform float inlay_radius = 0.0;
uniform vec4 inlay_colour : source_color = vec4(0.25,0.22,0.28,1.0);
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 model_position;
varying vec3 model_normal;
float cell_hash(vec2 cell) {
	return fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
}
void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX*NORMAL;
	model_position = VERTEX;
	model_normal = NORMAL;
}
void fragment() {
	vec2 mapped = world_position.xz;
	if (architectural_mapping) {
		vec3 direction = abs(model_normal);
		mapped = model_position.xz;
		if (direction.y < 0.5) {
			mapped = direction.x > direction.z ? model_position.zy : model_position.xy;
		}
	}
	vec2 course = mapped/slab_size;
	course.x += mod(floor(course.y),2.0)*0.5;
	vec2 cell = floor(course);
	vec2 local = fract(course);
	vec2 edge_distance = min(local,1.0-local)*slab_size;
	float edge = min(edge_distance.x,edge_distance.y);
	float aa = max(fwidth(edge),0.001);
	float joint = 1.0-smoothstep(0.012-aa,0.012+aa,edge);
	float selected = step(cell_hash(cell+vec2(7.0,19.0)),joint_coverage);
	float face_variation = mix(0.96,1.04,cell_hash(cell));
	ALBEDO = stone_colour.rgb*face_variation*(1.0-joint*selected*joint_strength);
	if (inlay_radius > 0.0) {
		vec2 offset = world_position.xz-inlay_centre.xz;
		float radius = length(offset);
		float ring_distance = min(abs(radius-inlay_radius),abs(radius-inlay_radius*0.83));
		float filter_width = max(fwidth(radius),0.005);
		float ring = 1.0-smoothstep(0.045-filter_width,0.045+filter_width,ring_distance);
		float floor_mask = smoothstep(0.8,0.95,world_normal.y)*(1.0-smoothstep(0.1,0.2,abs(world_position.y-inlay_centre.y)));
		ALBEDO = mix(ALBEDO,inlay_colour.rgb,ring*floor_mask*0.55);
	}
	ROUGHNESS = mix(roughness_range.x,roughness_range.y,cell_hash(cell+vec2(21.0,4.0)));
	SPECULAR = 0.35;
}
