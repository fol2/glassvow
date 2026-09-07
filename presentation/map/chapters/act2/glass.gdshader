shader_type spatial;
render_mode cull_disabled;
varying vec3 local_at;
void vertex() { local_at = VERTEX; }
void fragment() {
	float diamond = abs(fract((local_at.x+local_at.y)*1.1)-.5);
	float cross = abs(fract((local_at.x-local_at.y)*1.1)-.5);
	float lead = 1.0-smoothstep(.015,.028,min(diamond,cross));
	float pane = floor((local_at.x+local_at.y)*1.1)*3.8+floor((local_at.x-local_at.y)*1.1)*7.1;
	vec3 colour = mix(vec3(.008,.024,.055),vec3(.008,.07,.12),sin(pane)*.5+.5);
	ALBEDO = mix(colour,vec3(.025,.04,.055),lead*.8);
	EMISSION = colour*.16*(1.0-lead);
	ROUGHNESS = .3;
}
