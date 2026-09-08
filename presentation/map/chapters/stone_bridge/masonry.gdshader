shader_type spatial;
uniform vec3 stone_colour : source_color = vec3(.267,.325,.420);
uniform float block_length = .84;
uniform float course_height = .32;
uniform float water_level = 1.18;
varying vec3 world_at;
varying vec3 world_normal;
void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX)*NORMAL);
}
vec2 bond(float along) {
	float course = floor(world_at.y/course_height);
	vec2 cell = vec2(along/block_length + mod(course,2.0)*.5,world_at.y/course_height);
	vec2 edge = min(fract(cell),1.0-fract(cell))*vec2(block_length,course_height);
	float aa = max(fwidth(along),fwidth(world_at.y));
	float joint = 1.0-smoothstep(.006,.012+aa,min(edge.x,edge.y));
	float variation = fract(sin(dot(floor(cell),vec2(17.13,63.71)))*4137.73);
	return vec2(joint,variation);
}
void fragment() {
	vec2 weights = pow(abs(world_normal.xz),vec2(8.0));
	weights /= max(.0001,weights.x+weights.y);
	vec2 stone = bond(world_at.z)*weights.x+bond(world_at.x)*weights.y;
	float wall = 1.0-smoothstep(.5,.85,abs(world_normal.y));
	float wet = 1.0-smoothstep(water_level,water_level+.65,world_at.y);
	ALBEDO = stone_colour * mix(.92,1.07,stone.y) * (1.0-stone.x*wall*.38) * (1.0-wet*.20);
	ROUGHNESS = mix(.95,.72,wet);
	SPECULAR = .22;
}
