shader_type canvas_item;

uniform sampler2D mural;
uniform vec4 fill_colour : source_color = vec4(0.44, 0.41, 0.57, 0.08);
uniform bool show_mural = false;

void fragment() {
	float pane_alpha = texture(TEXTURE, UV).a;
	vec4 colour = show_mural ? texture(mural, UV) : fill_colour;
	COLOR = vec4(colour.rgb, colour.a * pane_alpha);
}
