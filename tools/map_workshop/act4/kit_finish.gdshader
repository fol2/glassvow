shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(.18,.20,.25,1.0);
uniform float glass = 0.0;
varying vec3 p;
float hash(vec3 q) { return fract(sin(dot(q,vec3(127.1,311.7,74.7)))*43758.5453); }
void vertex() { p=VERTEX; }
void fragment() {
 // Fine weathering is confined to architecture. The walking surface stays calm.
 float grain=hash(floor(p*42.0));
 float age=.5+.5*sin(p.x*1.7+sin(p.z*2.4)+p.y*3.1);
 float variation=mix(.82,1.04,age)*mix(.96,1.02,grain);
 ALBEDO=tint.rgb*variation;
 ROUGHNESS=mix(.82,.28,glass);
 SPECULAR=mix(.26,.5,glass);
 EMISSION=tint.rgb*glass*(.30+.18*age);
}
