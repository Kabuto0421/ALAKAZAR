shader_type canvas_item;
// The title logo (layer_30_logo.png, 1920x1080): ALAKAZAR's eight letters each light
// up gold on their own when the melody plays a note, the whole logo flares on a big
// hit, and a diagonal glint can sweep across. Only the cream strokes (and a little of
// the soft halo round them) are lit; the subtitle line below is left alone.
uniform float shine[8];
uniform float flare = 0.0;
uniform float sweep = -1.0;
uniform vec3 shine_color : source_color = vec3(1.0, 0.84, 0.45);

const float LETTER_X0 = 536.0;  // the first letter's cell starts here...
const float PITCH = 103.0;  // ...and each letter's cell is this wide
const float TITLE_BOTTOM = 212.0;  // the subtitle starts below this row

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * tint;
	vec2 px = UV * vec2(1920.0, 1080.0);
	float body = smoothstep(0.55, 0.85, dot(c.rgb, vec3(0.299, 0.587, 0.114))) * c.a;
	float k = 0.0;
	if (px.y < TITLE_BOTTOM) {
		int i = int(floor((px.x - LETTER_X0) / PITCH));
		if (i >= 0 && i < 8) {
			k = shine[i];
		}
	}
	float glint = 0.0;
	if (sweep >= 0.0) {
		float d = px.x + px.y * 0.7 - sweep;
		glint = exp(-d * d / 1800.0);
	}
	c.rgb += shine_color * (body * k * 0.85 + c.a * k * 0.12);
	c.rgb += vec3(1.0, 0.95, 0.8) * body * (flare * 0.55 + glint * 0.8);
	c.rgb += shine_color * c.a * flare * 0.12;
	COLOR = c;
}
