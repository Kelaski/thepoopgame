shader_type canvas_item;
// The round-clock bar: fills `fill` of the width from the middle out, with the
// edges faded across one pixel so it shrinks smoothly instead of in pixel steps.

uniform float fill : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float d = abs(UV.x - 0.5) * 2.0;   // 0 in the middle, 1 at either end
	float edge = fwidth(d);
	COLOR.a *= 1.0 - smoothstep(fill - edge, fill + edge, d);
}
