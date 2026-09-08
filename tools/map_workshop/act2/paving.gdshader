shader_type spatial;
varying vec3 world_at;
void vertex() { world_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p = world_at.xz;
	float row = floor(p.y/2.4);
	vec2 cell = vec2(p.x/2.8+mod(row,2.0)*.5,p.y/2.4);
	vec2 edge = abs(fract(cell)-.5);
	float joint = smoothstep(.492,.498,max(edge.x,edge.y));
	float variation = sin(floor(cell.x)*7.3+row*2.3)*.006;
	ALBEDO = (vec3(.085,.10,.14)+variation)*(1.0-joint*.3);
	ROUGHNESS = .82;
}
