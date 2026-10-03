shader_type canvas_item;
// Rotorick's casino: a glowing rim of chasing marquee bulbs around the board, a slow
// colour-shifting glow at the edges and a few glittering sparkles.
uniform float time = 0.0;
uniform float bulbs = 28.0;
uniform float energy = 1.0;
// 0 = normal casino, 5 = ERROR (glitch bars, scanlines, hazard stripes), 7 = jackpot alarm (red beacons).
uniform int mode = 0;

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
	if (mode == 7) {
		// Execution alarm: the edge goes red and pulses, and two beacons sweep the board.
		float pulse = 0.5 + 0.5 * sin(time * 9.0);
		col = vec3(1.0, 0.05, 0.08) * glow * (0.5 + 0.5 * pulse) * 1.6;
		alpha = glow * (0.38 + 0.3 * pulse);
		for (int k = 0; k < 2; k++) {
			vec2 origin = k == 0 ? vec2(0.0, 0.0) : vec2(1.0, 1.0);
			vec2 to = uv - origin;
			float ang = atan(to.y, to.x);
			float sweep = time * 3.2 + float(k) * 3.14159;
			float beam = pow(max(0.0, cos(ang - sweep * (k == 0 ? 0.5 : -0.5) - 0.8)), 24.0);
			float fall = 1.0 - clamp(length(to) / 1.5, 0.0, 1.0);
			col += vec3(1.0, 0.1, 0.1) * beam * fall * 0.45;
			alpha = max(alpha, beam * fall * 0.16);
		}
	}
	if (mode == 5) {
		// ERROR: scanlines, tearing bars of cyan/magenta/yellow and a flicker.
		float line = step(0.5, fract(uv.y * 90.0));
		col += vec3(0.0) * line;
		alpha = max(alpha, line * 0.04);
		float band_id = floor(uv.y * 14.0 + floor(time * 9.0) * 3.0);
		float on = step(0.86, hash(vec2(band_id, floor(time * 9.0))));
		vec3 bar = hash(vec2(band_id, 3.0)) < 0.33 ? vec3(0.0, 1.0, 1.0) : (hash(vec2(band_id, 7.0)) < 0.5 ? vec3(1.0, 0.1, 0.8) : vec3(1.0, 0.9, 0.1));
		float span = step(hash(vec2(band_id, 11.0)), uv.x) * step(uv.x, hash(vec2(band_id, 13.0)) * 0.6 + 0.4);
		col += bar * on * span * 0.35;
		alpha = max(alpha, on * span * 0.10);
		float flick = step(0.93, hash(vec2(floor(time * 14.0), 5.0)));
		col += vec3(1.0, 0.9, 0.3) * flick * 0.15;
		alpha = max(alpha, flick * 0.07);
	}
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
		if (mode == 7) {
			tint = vec3(1.0, 0.1, 0.1);
			lit = step(0.0, sin(time * 12.0));
		} else if (mode == 5) {
			tint = mod(id, 2.0) < 1.0 ? vec3(1.0, 0.85, 0.1) : vec3(0.15, 0.12, 0.0);
			lit = step(0.15, hash(vec2(id, floor(time * 12.0))));
		}
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
