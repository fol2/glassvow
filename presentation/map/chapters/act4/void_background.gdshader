shader_type canvas_item;
render_mode unshaded;
uniform float motion = 1.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float mist(vec2 p) {
 vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 vec2 p=UV*vec2(SCREEN_PIXEL_SIZE.y/SCREEN_PIXEL_SIZE.x,1.0);
 float n=mist(p*2.1+vec2(.3,(TIME*motion)*.002))+mist(p*5.3+vec2(2.0,-(TIME*motion)*.003))*.32;
 float band=smoothstep(.48,1.22,n);
 vec3 ink=vec3(.024,.029,.047);
 vec3 cloud=vec3(.027,.020,.047)*band;
 vec2 field=p*80.0;vec2 cell=floor(field);vec2 local=fract(field)-.5;
 vec2 offset=vec2(hash(cell+8.0),hash(cell+29.0))*.65-.325;
 float r=length(local-offset);
 float star=exp(-r*r*330.0)*step(.993,hash(cell));
 float dither=(hash(FRAGCOORD.xy)-.5)/255.0;
 COLOR=vec4(ink+cloud+vec3(dither)+vec3(.23,.21,.18)*star*(.8+.2*sin((TIME*motion)*.3+hash(cell)*6.28)),1.0);
}
