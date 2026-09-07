shader_type spatial;
uniform vec4 world_bounds = vec4(-48,-30,96,60);
uniform sampler2D route_distance : filter_linear, repeat_disable;
uniform sampler2D habitat : filter_linear, repeat_disable;
uniform bool bridge_surface = false;
uniform float river_level = -1000.0;
uniform vec2 gateway_position = vec2(-1000.0);
uniform vec4 soil_colour : source_color = vec4(.19,.173,.185,1.0);
uniform vec4 path_colour : source_color = vec4(.295,.267,.251,1.0);
uniform vec4 litter_colour : source_color = vec4(.245,.191,.203,1.0);
uniform vec4 gravel_colour : source_color = vec4(.345,.321,.310,1.0);
uniform vec4 rock_colour : source_color = vec4(.30,.285,.30,1.0);
uniform vec4 paving_colour : source_color = vec4(.325,.314,.31,1.0);
uniform vec4 damp_colour : source_color = vec4(.235,.217,.224,1.0);
varying vec3 world_at;
varying float deck_blend;
varying vec3 terrain_normal;
varying float deck_inset;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 world_at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 deck_blend=COLOR.r;
 deck_inset=COLOR.g;
 terrain_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
 vec2 p=world_at.xz;
 vec2 uv=(p-world_bounds.xy)/world_bounds.zw;
 float d=texture(route_distance,uv).r;
 vec3 setting=texture(habitat,uv).rgb;
 float broad=noise(p*.48);
 float patches=noise(p*1.8+8.0);
 float grain=noise(p*12.0);
 // Three edge scales make intermittent shoulders, with a calm worn centre.
 // Variation lives in the trail and verge; the open ground stays quiet.
 float edge=(noise(p*2.5)-.5)*.13+(noise(p*9.0)-.5)*.045;
 float width=.60+(noise(p*.62)-.5)*.20;
 width+=setting.b*.16;
 float core=1.0-smoothstep(width-.045,width+.03,d+edge);
 float shoulder=1.0-smoothstep(width-.02,width+.38,d+edge);
 float centre=1.0-smoothstep(.10,.48,d);
 float forest=setting.r;
 float mineral=setting.g;
 float bank=1.0-smoothstep(2.5,5.0,abs(p.x+5.0-sin(p.y*.12)*2.2));
 float entrance=1.0-smoothstep(1.3,3.8,distance(p,gateway_position));
 vec3 earth=soil_colour.rgb*(.94+.11*broad);
 // Broad slate faces expose the landform; fine noise stays out of open soil.
 float scarp=smoothstep(.10,.50,1.0-abs(terrain_normal.y));
 float strata=.88+.10*noise(vec2(p.x*.19+p.y*.11,world_at.y*1.1));
 earth=mix(earth,rock_colour.rgb*strata,scarp*.70);
 // Vegetation colour reaches the bank through scattered litter, not a halo.
 float litter=forest*smoothstep(.35,.75,patches)*shoulder*(1.0-centre*.85);
 vec3 worn=path_colour.rgb*(.73+.20*broad+.32*patches);
 worn*=.965+.07*grain;
 worn=mix(worn,litter_colour.rgb,litter*.55);
 worn=mix(worn,rock_colour.rgb,mineral*patches*.24);
 worn=mix(worn,gravel_colour.rgb,smoothstep(.66,.86,grain)*mineral*.28);
 worn=mix(worn,damp_colour.rgb,bank*.24*(1.0-centre*.6));
 earth=mix(earth,litter_colour.rgb,forest*patches*shoulder*.22);
 vec3 trail=mix(earth,worn,core*.88+shoulder*.12);
 // A shared world-space layout never resets at a ramp, bend or junction.
 // Broad, staggered flags remain legible as individual stones under soil.
 vec2 stone=vec2(p.x*.94+p.y*.342,-p.x*.342+p.y*.94)*vec2(1.55,1.85);
 float row=floor(stone.y);
 stone.x*=.88+.26*hash(vec2(row,23.0));
 stone.x+=hash(vec2(row,17.0))*.72;
 stone+=(vec2(noise(p*3.0),noise(p*3.0+17.0))-.5)*.12;
 vec2 cell_id=floor(stone);
 vec2 cell=abs(fract(stone)-.5);
 vec2 corner=cell-vec2(.418,.425);
 float stone_edge=length(max(corner,vec2(0)))+min(max(corner.x,corner.y),0.0)+.43;
 stone_edge+=(noise(p*17.0)-.5)*.025;
 float joint=smoothstep(.468,.492,stone_edge);
 float slab=hash(cell_id+9.0);
 vec3 masonry=paving_colour.rgb*(.89+.19*slab);
 masonry*=1.0-joint*.19;
 masonry*=.97+.06*noise(p*5.0);
 float wear=smoothstep(.3,.76,noise(p*1.1+31.0));
 float paving=entrance*(.65+.35*broad)*core;
 if(bridge_surface) {
  // Burial varies per flag: stones appear with firm edges, rather than the
  // whole pavement fading through a translucent, blurred strip of mud.
  float burial=.12+slab*.43+smoothstep(.34,.5,stone_edge)*.19;
  burial+=(noise(p*4.0)-.5)*.16+(noise(p*17.0)-.5)*.035;
  // Soil gathers at the verge and in recessed joints. Fully raised decks
  // keep a continuous paved edge; their earthbound ends disappear into it.
  burial+=(1.0-smoothstep(.0,.24,deck_inset))*.32;
  float exposed=smoothstep(burial-.035,burial+.035,deck_blend);
  exposed=mix(exposed,1.0,smoothstep(.92,1.0,deck_blend));
  paving=mix(paving,1.0,exposed);
  float dust=wear*.045+joint*(1.0-deck_blend)*.22;
  masonry=mix(masonry,worn,dust);
 }
 trail=mix(trail,masonry,paving);
 // A restrained wet margin binds the water to the actual stone bank.
 float wetted=(1.0-smoothstep(river_level-.08,river_level+.30,world_at.y))*bank;
 if(!bridge_surface) { trail=mix(trail,trail*vec3(.65,.72,.75),wetted); }
 ALBEDO=trail;
 // Fine relief belongs to the worn surface; the surrounding soil remains calm.
 float relief=core*((patches-.5)*.006+(grain-.5)*.002);
 float bevel=1.0-smoothstep(.38,.49,stone_edge);
 relief=mix(relief,bevel*.008+(noise(p*5.0)-.5)*.002,paving);
 vec3 dpdx=dFdx(VERTEX);
 vec3 dpdy=dFdy(VERTEX);
 vec3 r1=cross(dpdy,NORMAL);
 vec3 r2=cross(NORMAL,dpdx);
 float determinant=dot(dpdx,r1);
 if(abs(determinant)>.00000001) {
  vec3 gradient=(r1*dFdx(relief)+r2*dFdy(relief))/determinant;
  NORMAL=normalize(NORMAL-gradient);
 }
 ROUGHNESS=.97;
 SPECULAR=.10;
}
