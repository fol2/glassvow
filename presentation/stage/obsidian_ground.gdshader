shader_type canvas_item;
uniform sampler2D court_plate : filter_linear_mipmap;
uniform vec4 stone_colour : source_color = vec4(.098,.11,.149,1.0);
void fragment() {
	vec4 original = texture(TEXTURE,UV);
	vec3 stone = texture(court_plate,UV).rgb;
	// The painted candidate has a black surround. Project nearby stone into that
	// surround before applying the existing silhouette; never punch holes in it.
	if (max(stone.r,max(stone.g,stone.b)) < .012) {
		stone = stone_colour.rgb;
		for (int i=1;i<=6;i++) {
			vec2 inset = vec2(clamp(UV.x,.08,.92),clamp(UV.y+float(i)*.025,.12,.86));
			vec3 nearby = texture(court_plate,inset).rgb;
			if (max(nearby.r,max(nearby.g,nearby.b)) >= .012) { stone=nearby; break; }
		}
	}
	COLOR = vec4(stone,original.a);
}
