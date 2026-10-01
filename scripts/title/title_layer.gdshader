shader_type canvas_item;
// A title art layer that moves with the music: `lift` brightens it on the kick (the
// menu frame, the heroes), `wave` ripples it so a row of fairies bobs in a wave
// across, and `red_glow` / `cyan_glow` flare the red and cyan lights of the Prison
// army (their eyes, lamps and visors) with a soft halo round them, on the war drums
// and on the cyber kicks.
uniform float lift = 0.0;
uniform vec3 lift_color : source_color = vec3(1.0, 0.88, 0.6);
uniform float wave = 0.0;
uniform float wave_phase = 0.0;
uniform float red_glow = 0.0;
uniform float cyan_glow = 0.0;
uniform vec3 red_color : source_color = vec3(1.0, 0.28, 0.16);
uniform vec3 cyan_color : source_color = vec3(0.25, 0.95, 1.0);

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float red_of(vec4 t) {
	return t.a * clamp((t.r - max(t.g, t.b) - 0.2) * 3.0, 0.0, 1.0);
}

float cyan_of(vec4 t) {
	return t.a * clamp((min(t.g, t.b) - t.r - 0.2) * 3.0, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV + vec2(0.0, sin(UV.x * 90.0 + wave_phase) * wave);
	vec4 c = texture(TEXTURE, uv) * tint;
	c.rgb += c.rgb * lift * 0.5 + lift_color * lift * 0.22 * c.a;
	if (red_glow > 0.0 || cyan_glow > 0.0) {
		float red = red_of(texture(TEXTURE, uv)) * 1.5;
		float cyan = cyan_of(texture(TEXTURE, uv)) * 1.5;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.7853982;
			vec2 dir = vec2(cos(a), sin(a)) * TEXTURE_PIXEL_SIZE;
			vec4 near = texture(TEXTURE, uv + dir * 7.0);
			vec4 far = texture(TEXTURE, uv + dir * 15.0);
			red += (red_of(near) + 0.6 * red_of(far)) * 0.16;
			cyan += (cyan_of(near) + 0.6 * cyan_of(far)) * 0.16;
		}
		// Laid over what is there: on solid pixels it adds, on empty ones it is the halo.
		vec3 add = (red_color * red * red_glow + cyan_color * cyan * cyan_glow) * tint.a;
		float halo = clamp(max(max(add.r, add.g), add.b), 0.0, 1.0);
		float a = c.a + halo * (1.0 - c.a);
		c.rgb = (c.rgb * c.a + add) / max(a, 0.0001);
		c.a = a;
	}
	COLOR = c;
}
