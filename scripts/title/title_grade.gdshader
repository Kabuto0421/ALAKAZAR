shader_type canvas_item;
// The title screen's colour grade, laid over the art (under the menu text). It reads
// what is behind it and regrades it with the music: the forest on the left and the
// neon city on the right are tinted on their own, so each part of the song can light
// them differently (moonlit forest, red-lit war, cold cyber, both worlds at full).
// The hits tear the picture (a colour split from the middle and a few sliding bands).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec3 gain_left = vec3(1.0);
uniform vec3 gain_right = vec3(1.0);
uniform float saturation = 1.0;
uniform float brightness = 1.0;
uniform float vignette = 0.0;
uniform float scan = 0.0;
uniform float aberration = 0.0;
uniform float glitch = 0.0;
uniform float pulse = 0.0;
uniform vec3 pulse_color = vec3(1.0, 0.92, 0.75);

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (glitch > 0.0) {
		float band = floor(uv.y * 34.0);
		float n = hash(band + floor(TIME * 22.0) * 7.0);
		if (n > 0.86) {
			uv.x += (n - 0.93) * 0.2 * glitch;
		}
	}
	vec2 away = uv - vec2(0.5);
	vec3 c = vec3(
		texture(screen_tex, uv + away * aberration).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - away * aberration).b);
	// The two sides are tinted apart, except behind the title, which gets the mean of both
	// (so the logo does not turn bright on one half and dull on the other).
	float side = smoothstep(0.38, 0.62, SCREEN_UV.x);
	float title_zone = (1.0 - smoothstep(0.2, 0.3, SCREEN_UV.y)) * smoothstep(0.22, 0.28, SCREEN_UV.x) * (1.0 - smoothstep(0.72, 0.78, SCREEN_UV.x));
	c *= mix(gain_left, gain_right, mix(side, 0.5, title_zone));
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation) * brightness;
	c += pulse_color * pulse * 0.1;
	float edge = length((SCREEN_UV - vec2(0.5)) * vec2(1.15, 1.0));
	c *= 1.0 - vignette * smoothstep(0.4, 0.95, edge);
	c *= 1.0 - scan * (0.5 + 0.5 * sin(FRAGCOORD.y * 2.0944));
	COLOR = vec4(c, 1.0);
}
