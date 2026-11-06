shader_type spatial;
// Distant towers: floor bands and a grid of windows painted in world space, with a share of the windows
// lit. More come on, and glow brighter, as night falls.
render_mode diffuse_toon, specular_toon;

uniform float night = 0.0;
uniform vec3 window_light : source_color = vec3(1.0, 0.8, 0.45);
const float FLOOR_H = 3.6;
const float BAY_W = 3.2;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	if (n.y > 0.5) {
		ALBEDO = COLOR.rgb * 0.7;
	} else {
		float across = (n.x > n.z ? world_pos.z : world_pos.x) / BAY_W;
		float up = world_pos.y / FLOOR_H;
		vec2 cell = vec2(floor(across), floor(up));
		vec2 f = vec2(fract(across), fract(up));
		float pane = step(0.2, f.x) * step(f.x, 0.8) * step(0.3, f.y) * step(f.y, 0.75);
		float band = step(f.y, 0.12);
		ALBEDO = mix(COLOR.rgb, COLOR.rgb * 0.72, max(band, pane * 0.8));
		float lit = step(hash(cell + floor(world_pos.xz * 0.02)), mix(0.14, 0.5, night));
		EMISSION = window_light * pane * lit * mix(0.5, 1.8, night);
	}
}
