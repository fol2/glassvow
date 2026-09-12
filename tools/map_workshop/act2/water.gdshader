shader_type spatial;
render_mode cull_disabled;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D reflection_texture : source_color, filter_linear_mipmap;
uniform mat4 reflection_matrix;
uniform bool has_reflection = false;
uniform float captured_time = -1.0;
varying vec3 world_at;
void vertex() { world_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float water_time = captured_time >= 0.0 ? captured_time : TIME;
	vec2 p = world_at.xz;
	float wave = sin(p.x*2.1+p.y*1.3+water_time*.7)*.035 + sin(p.x*.73-p.y*2.4-water_time*.53)*.022;
	NORMAL = normalize(mat3(VIEW_MATRIX)*vec3(wave,1.0,cos(p.y*1.8+water_time*.6)*.045));
	vec2 uv = SCREEN_UV + vec2(wave,cos(p.x+water_time*.3)*.024)*.018;
	float depth = texture(depth_texture,uv).r;
	vec4 position = INV_PROJECTION_MATRIX * vec4(uv*2.0-1.0,depth,1.0);
	if (-position.z/position.w < -VERTEX.z) {
		uv = SCREEN_UV;
		depth = texture(depth_texture,uv).r;
		position = INV_PROJECTION_MATRIX * vec4(uv*2.0-1.0,depth,1.0);
	}
	float thickness = max(0.0,-position.z/position.w+VERTEX.z);
	float transmit = exp(-thickness*1.3)*.55;
	vec3 behind = texture(screen_texture,uv).rgb;
	ALBEDO = mix(vec3(.006,.028,.038),behind,transmit);
	vec3 reflected = mat3(INV_VIEW_MATRIX)*reflect(-VIEW,NORMAL);
	float sky = smoothstep(-.08,.45,reflected.y);
	float ripple = .35+.12*sin(p.x*.83+p.y*.48+water_time*.35)*sin(p.y*.67-p.x*.32-water_time*.21)+.08*sin(p.x*1.9-p.y*1.2+water_time*.18);
	EMISSION = vec3(.001,.003,.004)*sky*ripple;
	if (has_reflection) {
		vec4 projected = reflection_matrix*vec4(world_at,1.0);
		vec2 reflection_uv = projected.xy/projected.w*.5+.5;
		reflection_uv.y = 1.0-reflection_uv.y;
		reflection_uv += vec2(wave*.022,cos(p.x*1.3+p.y+water_time*.4)*.0015);
		if (all(greaterThan(reflection_uv,vec2(0.0))) && all(lessThan(reflection_uv,vec2(1.0)))) {
			vec3 reflection = textureLod(reflection_texture,reflection_uv,1.4).rgb;
			float fresnel = pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),3.0);
			EMISSION += reflection*(.08+.12*fresnel);
		}
	}
	ROUGHNESS = .42;
	METALLIC = .06;
	SPECULAR = .28;
}
