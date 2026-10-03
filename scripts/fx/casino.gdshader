shader_type canvas_item;
// Rotorick's casino: a glowing rim of chasing marquee bulbs around the board, a slow
// colour-shifting glow at the edges and a few glittering sparkles.
uniform float time = 0.0;
uniform float bulbs = 28.0;
uniform float energy = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 d = abs(uv - 0.5) * 2.0;
	float edge = max(d.x, d.y);
	// Edge glow that drifts through gold, magenta and cyan.
	float glow = smoothstep(0.62, 1.0, edge);
	vec3 hue = 0.5 + 0.5 * cos(6.2831 * (time * 0.08 + uv.x * 0.4 + uv.y * 0.3 + vec3(0.0, 0.33, 0.67)));
	vec3 col = mix(vec3(1.0, 0.75, 0.2), hue, 0.55) * glow * (0.30 + 0.10 * sin(time * 2.6)) * energy;
	float alpha = glow * 0.30 * energy;
	// Marquee bulbs in the outer band.
	float rim = 0.045;
	vec2 inner = min(uv, 1.0 - uv);
	float band = min(inner.x, inner.y);
	if (band < rim) {
		// Position along the perimeter (0..4).
		float along;
		if (inner.x < inner.y) {
			along = uv.x < 0.5 ? 3.0 + (1.0 - uv.y) : 1.0 + uv.y;
		} else {
			along = uv.y < 0.5 ? uv.x : 2.0 + (1.0 - uv.x);
		}
		float cell = along * bulbs / 4.0;
		float id = floor(cell);
		float across = band / rim - 0.5;
		float lateral = fract(cell) - 0.5;
		float r = length(vec2(lateral, across * 1.0));
		float lit = step(mod(id - time * 8.0, 4.0), 2.0);
		vec3 tint = mod(id, 2.0) < 1.0 ? vec3(1.0, 0.83, 0.36) : vec3(1.0, 0.31, 0.85);
		float disc = smoothstep(0.42, 0.18, r);
		float halo = smoothstep(0.9, 0.2, r) * 0.35;
		float strength = (disc * (0.35 + 0.65 * lit) + halo * lit) * energy;
		col += tint * strength;
		alpha = max(alpha, strength);
	}
	// Sparkles.
	vec2 g = floor(uv * 14.0);
	float s = hash(g);
	float twinkle = step(0.965, s) * (0.5 + 0.5 * sin(time * 5.0 + s * 40.0));
	vec2 f = fract(uv * 14.0) - 0.5;
	float star = twinkle * smoothstep(0.35, 0.0, length(f)) * 0.5 * energy * glow;
	col += vec3(1.0, 0.95, 0.7) * star;
	alpha = max(alpha, star);
	COLOR = vec4(col, clamp(alpha, 0.0, 0.95));
}
