shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D mineral : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D groundcover : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.73, 0.83, 0.88);
uniform float metres_per_tile = 9.5;
uniform vec3 region_tint : source_color = vec3(1.0);
uniform bool heath = true;
uniform bool trail = false;
uniform bool basin = false;
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

// Mirroring keeps generated tile edges continuous without raster resampling.
// Explicit derivatives avoid a false coarse mip at each mirrored boundary.
vec3 tile(sampler2D source, vec2 uv) {
    vec2 mirrored = 1.0 - abs(mod(uv, 2.0) - 1.0);
    return textureGrad(source, mirrored, dFdx(uv), dFdy(uv)).rgb;
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
	vec3 colour = tile(mineral, p.zy) * weights.x;
	colour += tile(mineral, p.xz) * weights.y;
	colour += tile(mineral, p.xy) * weights.z;
	vec3 rock = colour * tint;
    float patches = noise(world_position.xz * 0.16);
    vec3 floor_colour = tile(groundcover, world_position.xz / metres_per_tile) * tint;
    ALBEDO = heath ? floor_colour * mix(0.70, 1.05, patches) : rock;
    if (trail) {
        float edge = abs(UV.x - 0.5) + noise(world_position.xz * 5.0) * 0.09;
        float wear = 1.0 - smoothstep(0.27, 0.48, edge);
        ALBEDO = mix(ALBEDO, mix(vec3(0.075, 0.080, 0.060), rock, 0.3), wear);
    }
    float ripples = sin(world_position.z * 8.0 + sin(world_position.x * 1.7) * 1.5);
    if (basin) {
        float flow = noise(world_position.xz * vec2(0.7, 3.0));
        ALBEDO = vec3(mix(0.62, 1.02, flow) + pow(0.5 + 0.5 * ripples, 8.0) * 0.07);
    }
	ALBEDO *= region_tint;
	float height = basin ? ripples * 0.006 : dot(colour, vec3(0.21, 0.72, 0.07)) * 0.075;
    vec3 dpdx = dFdx(view_position);
    vec3 dpdy = dFdy(view_position);
    vec3 rx = cross(dpdy, NORMAL);
    vec3 ry = cross(NORMAL, dpdx);
    float determinant = dot(dpdx, rx);
    vec3 gradient = sign(determinant) * (dFdx(height) * rx + dFdy(height) * ry);
    NORMAL = normalize(abs(determinant) * NORMAL - gradient);
    ROUGHNESS = basin ? 0.56 : 0.94;
}
