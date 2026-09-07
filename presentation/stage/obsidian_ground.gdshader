shader_type canvas_item;
uniform sampler2D court_plate : filter_linear_mipmap;
uniform vec4 stone_colour : source_color = vec4(.098,.11,.149,1.0);
void fragment() {
	vec4 original = texture(TEXTURE,UV);
	vec3 stone = texture(court_plate,UV).rgb;
	// Keep the original coverage and shaded edge relief. Blend away the painted
	// candidate's black surround without stepped UV searches or alpha keying.
	float luminance = dot(original.rgb,vec3(.2126,.7152,.0722));
	vec3 edge_stone = mix(vec3(luminance*.55),stone_colour.rgb,.55);
	float coverage = smoothstep(.008,.028,max(stone.r,max(stone.g,stone.b)));
	COLOR = vec4(mix(edge_stone,stone,coverage),original.a);
}
