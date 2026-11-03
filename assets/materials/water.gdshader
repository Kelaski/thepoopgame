// Still water (the pond and the fountain's basins). Ripples drift across the
// surface in world space, so overlapping pieces of water line up seamlessly.
// The tint comes from each part's colour (the instance colour).
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform float flow_speed = 0.5;        // how fast the ripples drift
uniform float ripple_scale = 1.6;      // ripples per metre
uniform float sparkle = 0.35;          // brightness of the glints on ripple crests
uniform vec2 flow_dir = vec2(0.6, 0.8);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float waves(vec2 p, float t) {
	float w = sin(p.x * 1.3 + t * 1.1) * 0.45;
	w += sin(p.y * 1.7 - t * 0.9) * 0.35;
	w += sin((p.x + p.y) * 2.6 + t * 1.7) * 0.2;
	w += sin((p.x - p.y) * 3.9 - t * 2.3) * 0.12;
	return w;
}

void fragment() {
	float t = TIME * flow_speed * 3.0;
	vec2 p = world_pos.xz * ripple_scale + flow_dir * TIME * flow_speed;
	float e = 0.05;
	float h = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t) - h;
	float hz = waves(p + vec2(0.0, e), t) - h;
	// Bend the normal with the ripples so the light moves across the water.
	vec3 n_world = normalize(vec3(-hx * 6.0, 1.0, -hz * 6.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	vec3 base = COLOR.rgb;
	float crest = smoothstep(0.55, 0.95, h * 0.5 + 0.5);
	ALBEDO = base * (0.88 + 0.12 * h) + vec3(sparkle) * crest * 0.6;
	EMISSION = vec3(sparkle) * crest * 0.25;
	ROUGHNESS = 0.2;
	SPECULAR = 0.7;
}
