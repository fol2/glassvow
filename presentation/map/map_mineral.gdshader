shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D mineral : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.73, 0.83, 0.88);
uniform float metres_per_tile = 9.5;
uniform vec3 region_tint : source_color = vec3(1.0);
uniform bool heath = true;
uniform bool trail = false;
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 view_position;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
               mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}

void vertex() {
	view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 weights = pow(abs(world_normal), vec3(5.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 p = world_position / metres_per_tile;
	vec3 colour = texture(mineral, p.zy).rgb * weights.x;
	colour += texture(mineral, p.xz).rgb * weights.y;
	colour += texture(mineral, p.xy).rgb * weights.z;
	vec3 rock = colour * tint;
    float patches = noise(world_position.xz * 0.16);
    float grit = noise(world_position.xz * 2.0);
    vec3 soil = mix(vec3(0.020, 0.045, 0.041), vec3(0.035, 0.058, 0.046), patches);
    soil *= mix(0.90, 1.10, grit);
    ALBEDO = heath ? mix(soil, rock, smoothstep(0.28, 0.72, patches) * 0.32) : rock;
    if (trail) { ALBEDO = mix(vec3(0.12, 0.125, 0.095), rock, 0.22); }
	ALBEDO *= region_tint;
	float height = dot(colour, vec3(0.21, 0.72, 0.07)) * 0.075;
    vec3 dpdx = dFdx(view_position);
    vec3 dpdy = dFdy(view_position);
    vec3 rx = cross(dpdy, NORMAL);
    vec3 ry = cross(NORMAL, dpdx);
    float determinant = dot(dpdx, rx);
    vec3 gradient = sign(determinant) * (dFdx(height) * rx + dFdy(height) * ry);
    NORMAL = normalize(abs(determinant) * NORMAL - gradient);
    ROUGHNESS = 0.94;
}
