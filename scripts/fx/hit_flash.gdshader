shader_type canvas_item;
// A struck unit blinks pure white for a moment (its shape, any colour turned white).
// Its soft shadow (semi-transparent) is left alone.
uniform float white = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, vec3(1.0), white * step(0.6, c.a)), c.a);
}
