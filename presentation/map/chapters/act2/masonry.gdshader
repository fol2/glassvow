shader_type spatial;
varying vec3 world_at;
varying vec3 world_normal;
void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX)*NORMAL);
}
void fragment() {
	float course = floor(world_at.y/.46);
	float horizontal = abs(world_normal.x) > .5 ? world_at.z : world_at.x;
	float seam_y = 1.0-smoothstep(.012,.028,abs(fract(world_at.y/.46)-.5)*.46);
	float seam_x = 1.0-smoothstep(.008,.021,abs(fract(horizontal/1.05+mod(course,2.0)*.5)-.5)*1.05);
	float joint = max(seam_y,seam_x*.65)*(1.0-step(.6,abs(world_normal.y)));
	float variation = sin(floor(horizontal/1.05)*7.3+course*3.6)*.006;
	float wet = 1.0-smoothstep(1.15,1.8,world_at.y);
	ALBEDO = (vec3(.055,.073,.107)+variation)*(1.0-joint*.3)*(1.0-wet*.24);
	ROUGHNESS = mix(.92,.55,wet);
}
