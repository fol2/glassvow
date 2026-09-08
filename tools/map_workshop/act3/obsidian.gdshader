shader_type spatial;
uniform vec3 stone_colour : source_color = vec3(0.11,0.09,0.16);
uniform float joint_light = 0.06;
varying vec3 world_at;
varying vec3 world_normal;
vec2 cell_hash(vec2 p){
	return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}
void vertex(){
	world_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment(){
	// Nine coarse cells produce large cut slabs, with no fine noise or texture sampling.
	vec2 p = world_at.xz/5.8;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float nearest = 10.0;
	float second = 10.0;
	float tone = 0.5;
	for(int x=-1;x<=1;x++){
		for(int y=-1;y<=1;y++){
			vec2 offset = vec2(float(x),float(y));
			vec2 seed = cell_hash(cell+offset);
			vec2 delta = offset+0.28+seed*0.44-f;
			float distance = dot(delta,delta);
			if(distance<nearest){ second=nearest; nearest=distance; tone=seed.x; }
			else { second=min(second,distance); }
		}
	}
	float floor_plane = smoothstep(0.65,0.9,abs(world_normal.y));
	float edge = second-nearest;
	float joint = (1.0-smoothstep(0.004,0.015,edge))*floor_plane;
	float facet = smoothstep(0.015,0.022,edge)*(1.0-smoothstep(0.022,0.045,edge))*floor_plane;
	ALBEDO = stone_colour*mix(1.0,0.86+tone*0.24,floor_plane)*(1.0-joint*0.65)+vec3(.005,.004,.008)*facet;
	ROUGHNESS = 0.84;
	SPECULAR = 0.16;
	EMISSION = vec3(0.3,0.016,0.11)*joint*joint_light;
}
