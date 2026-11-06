shader_type spatial;
// Flat cartoon surface: clean colour with hard-edged toon light and, on floors and ground, a soft
// world-space pattern. No image files or UVs needed.
render_mode diffuse_toon, specular_toon;

uniform vec3 color : source_color = vec3(0.7);
uniform vec3 color2 : source_color = vec3(0.5);
// 0 flat, 2 tile, 3 planks, 4 corrugated, 5 grass, 6 asphalt, 7 soft wash, 8 bark, 9 paving, 10 stripes
uniform int pattern = 0;
uniform float pattern_scale = 1.0;
uniform float glow = 0.0;
uniform float roughness_value = 0.85;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.y > 0.6 ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	uv *= pattern_scale;
	vec3 albedo = color;
	if (pattern == 2) {
		vec2 f = fract(uv);
		float grout = step(0.025, f.x) * step(0.025, f.y);
		float check = mod(floor(uv.x) + floor(uv.y), 2.0);
		albedo = mix(color2, mix(color, color * 0.94, check), grout);
	} else if (pattern == 3) {
		vec2 b = uv * vec2(0.5, 3.0);
		b.x += hash(vec2(floor(b.y), 3.0));
		float seam = step(0.04, fract(b.y)) * step(0.012, fract(b.x));
		albedo = mix(color2, color * (0.92 + 0.14 * hash(floor(b))), seam);
	} else if (pattern == 4) {
		albedo = mix(color, color2, smoothstep(0.4, 0.6, abs(fract(uv.x * 2.0) - 0.5) * 2.0));
	} else if (pattern == 5) {
		albedo = mix(color, color2, smoothstep(0.42, 0.58, noise(uv * 0.8)));
	} else if (pattern == 6) {
		albedo = mix(color, color2, smoothstep(0.45, 0.55, noise(uv * 0.5)) * 0.5);
	} else if (pattern == 7) {
		albedo = mix(color, color2, smoothstep(0.4, 0.7, noise(uv * 0.7)));
	} else if (pattern == 8) {
		float ridge = uv.x * 2.5 + noise(vec2(uv.x * 3.0, uv.y * 0.6)) * 1.1;
		albedo = mix(color2, color, smoothstep(0.1, 0.4, abs(fract(ridge) - 0.5) * 2.0));
	} else if (pattern == 9) {
		// Paving slabs in a running bond, each a slightly different tone, flecked like real stone.
		vec2 b = uv;
		b.x += 0.5 * mod(floor(b.y), 2.0);
		vec2 f = fract(b);
		float joint = step(0.025, f.x) * step(f.x, 0.975) * step(0.04, f.y) * step(f.y, 0.96);
		float tone = 0.93 + 0.11 * hash(floor(b));
		float fleck = noise(uv * 11.0) * 0.06;
		albedo = mix(color2, color * (tone - fleck), joint);
	} else if (pattern == 10) {
		// Runs across any axis-aligned edge, so awnings stripe the same whichever way they face.
		albedo = fract((world_pos.x + world_pos.z) * pattern_scale) < 0.5 ? color : color2;
	}
	ALBEDO = albedo * COLOR.rgb;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.1;
	EMISSION = color * COLOR.rgb * glow;
}
