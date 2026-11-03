// Falling / flowing water (the fountain's jets). Streaks run along the length of
// each column (the mesh's V coordinate), so the water visibly pours.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform float flow_speed = 2.2;   // streak speed along the column
uniform float streaks = 9.0;      // streaks per column
uniform float opacity = 0.75;

void fragment() {
	float s = sin(UV.y * streaks * 6.2832 - TIME * flow_speed * 6.2832 + UV.x * 18.85);
	float s2 = sin(UV.y * streaks * 2.3 * 6.2832 - TIME * flow_speed * 9.0 + UV.x * 31.4);
	float k = smoothstep(0.2, 1.0, s * 0.6 + s2 * 0.4);
	ALBEDO = mix(COLOR.rgb, vec3(1.0), k * 0.55);
	ALPHA = opacity * (0.7 + 0.3 * k);
}
