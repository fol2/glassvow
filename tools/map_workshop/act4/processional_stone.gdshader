shader_type spatial;
uniform vec4 stone_colour : source_color = vec4(.28,.29,.34,1.0);
uniform vec4 shadow_colour : source_color = vec4(.055,.065,.09,1.0);
varying vec3 world_position;
varying vec3 surface_normal;
float cell_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 surface_normal=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment() {
 bool top=abs(surface_normal.y)>.65;
 vec2 p=world_position.xz;
 vec2 scale=vec2(4.8,3.6);
 if(!top) { p=abs(surface_normal.x)>abs(surface_normal.z)?world_position.zy:world_position.xy; scale=vec2(2.4,.72); }
 vec2 grid=p/scale;
 grid.x+=mod(floor(grid.y),2.0)*.5;
 vec2 local=fract(grid);
 vec2 boundary=min(local,1.0-local)*scale;
 float edge=min(boundary.x,boundary.y);
 float aa=max(fwidth(edge),.001);
 float seam=1.0-smoothstep(.015-aa,.025+aa,edge);
 float course=cell_hash(floor(grid));
 vec3 colour=stone_colour.rgb*mix(.90,1.08,course);
 colour*=1.0-seam*(top?.28:.18);
 // Deep sides disappear into the unbounded space; no second floor below them.
 float underside=top?1.0:smoothstep(-1.4,2.0,world_position.y);
 ALBEDO=mix(shadow_colour.rgb,colour,underside);
 ROUGHNESS=top?.62:.86;
 SPECULAR=.32;
}
