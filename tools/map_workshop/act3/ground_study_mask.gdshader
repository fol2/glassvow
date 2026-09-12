shader_type canvas_item;
uniform sampler2D original_mask : filter_linear;
void fragment() {
	vec4 candidate = texture(TEXTURE, UV);
	float brightness = max(candidate.r,max(candidate.g,candidate.b));
	// Preview-only: retain the shipped alpha footprint and key pure black background.
	candidate.a = texture(original_mask,UV).a * smoothstep(0.002,0.012,brightness);
	COLOR = candidate;
}
