shader_type canvas_item;
render_mode unshaded;
// Quiet peripheral haze conceals the finite landscape cut, including foliage.
// World-space coverage follows the same orthographic view as the live scene.
uniform vec4 world_bounds;
uniform vec2 ground_centre;
uniform vec2 ground_span;
uniform vec4 haze_colour : source_color = vec4(.145098,.145098,.188235,1.0);
void fragment() {
 vec4 scene=texture(TEXTURE,UV);
 vec2 at=ground_centre+(UV-.5)*ground_span;
 vec2 inset=min(at-world_bounds.xy,world_bounds.xy+world_bounds.zw-at);
 float edge=min(inset.x,inset.y);
 float drift=sin(at.x*.37+sin(at.y*.21))*sin(at.y*.31)*1.2;
 float veil=1.0-smoothstep(.6,6.0+drift,edge);
 COLOR=vec4(mix(scene.rgb,haze_colour.rgb,veil),scene.a);
}
