shader_type spatial;
// Full-screen ink lines, drawn wherever depth or surface direction jumps. This is what gives every
// model its hand-drawn cartoon edge, without touching the models themselves.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform vec3 ink = vec3(0.07, 0.06, 0.09);
uniform float thickness = 1.0;
uniform float strength = 0.75;
// Lines fade out with distance, so far buildings don't turn into scribble.
uniform float fade_start = 40.0;
uniform float fade_end = 140.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, texture(depth_tex, uv).r, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	float center = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float d1 = view_depth(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float d2 = view_depth(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float d3 = view_depth(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float d4 = view_depth(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	// Second difference ignores smooth slopes such as a floor seen at a low angle.
	float depth_edge = (abs(d1 + d2 - 2.0 * center) + abs(d3 + d4 - 2.0 * center)) / max(center, 1.0);
	vec3 n0 = texture(normal_tex, SCREEN_UV).xyz;
	vec3 n1 = texture(normal_tex, SCREEN_UV + vec2(px.x, 0.0)).xyz;
	vec3 n2 = texture(normal_tex, SCREEN_UV + vec2(0.0, px.y)).xyz;
	float normal_edge = length(n0 - n1) + length(n0 - n2);
	float edge = max(smoothstep(0.04, 0.09, depth_edge), smoothstep(0.35, 0.6, normal_edge));
	float fade = 1.0 - smoothstep(fade_start, fade_end, center);
	ALBEDO = ink;
	ALPHA = edge * fade * strength;
}
