shader_type spatial;
uniform vec3 stone_colour : source_color = vec3(.333333,.372549,.439216);
uniform vec2 flag_size = vec2(.9,1.15);
varying vec3 world_at;
void vertex() { world_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float row = floor(world_at.z/flag_size.y);
	vec2 cell = vec2(world_at.x/flag_size.x+mod(row,2.0)*.5,world_at.z/flag_size.y);
	vec2 edge = min(fract(cell),1.0-fract(cell))*flag_size;
	float aa = max(fwidth(world_at.x),fwidth(world_at.z));
	float joint = 1.0-smoothstep(.007,.012+aa,min(edge.x,edge.y));
	float variation = fract(sin(dot(floor(cell),vec2(37.17,19.31)))*9137.51);
	ALBEDO = stone_colour * mix(.94,1.06,variation) * (1.0-joint*.38);
	ROUGHNESS = .92;
	SPECULAR = .20;
}
