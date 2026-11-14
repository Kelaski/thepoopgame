shader_type canvas_item;
// A glow along the screen's edges, clear in the middle. The rect's color tints it.

// How far in from the edges the glow reaches, as a share of the screen's height.
uniform float width = 0.14;

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = SCREEN_UV * size;
	float edge = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
	float a = 1.0 - smoothstep(0.0, width * size.y, edge);
	COLOR = vec4(COLOR.rgb, COLOR.a * a * a);
}
