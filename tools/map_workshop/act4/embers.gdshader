shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
varying float glow;
void vertex() {
 float phase=INSTANCE_CUSTOM.r*6.283;
 mat4 billboard=INV_VIEW_MATRIX;
 vec3 centre=MODEL_MATRIX[3].xyz;
 centre.y+=sin(TIME*.11+phase)*2.0;
 centre.x+=sin(TIME*.07+phase*2.0)*1.5;
 centre.z+=cos(TIME*.09+phase)*1.3;
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(billboard[0],billboard[1],billboard[2],vec4(centre,1.0));
 glow=.25+.3*pow(.5+.5*sin(TIME*.6+phase),2.0);
}
void fragment() {
 vec2 p=UV*2.0-1.0;
 float core=exp(-dot(p,p)*4.5);
 ALBEDO=vec3(.85,.36,.07);
 EMISSION=ALBEDO*.7;
 ALPHA=core*glow;
}
