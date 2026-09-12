shader_type canvas_item;
uniform vec4 stone_colour : source_color = vec4(.255,.259,.306,1.0);
varying vec4 plate_modulation;
void vertex() { plate_modulation=COLOR; }
void fragment() {
 vec4 original=texture(TEXTURE,UV);
 // Preserve the painted silhouette and its teal stelae. Quiet the warm cracks
 // across the fighting surface, retaining bevel relief and authored modulation.
 float floor_mask=smoothstep(.22,.34,UV.y);
 float luminance=dot(original.rgb,vec3(.2126,.7152,.0722));
 float relief=clamp(luminance*.8,.015,.22);
 vec3 quiet=stone_colour.rgb*(.30+relief*1.5);
 float warmth=max(original.r-original.b,0.0);
 quiet+=vec3(.13,.065,.018)*warmth*.25;
 COLOR=vec4(mix(original.rgb,quiet,floor_mask*.93),original.a)*plate_modulation;
}
