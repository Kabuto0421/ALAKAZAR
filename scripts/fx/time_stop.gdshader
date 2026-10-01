shader_type canvas_item;
// 時の妖精: the stopped world. Over the board (drawn above the enemies, under the
// player and the allies) it reads what is behind it and drains the colour into a
// cold violet monochrome; `negative` flashes a photographic negative as time stops.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float amount = 0.0;
uniform float negative = 0.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 still = vec3(luma) * vec3(0.82, 0.8, 1.05) + vec3(0.04, 0.02, 0.08);
	vec3 shown = mix(c, still, amount);
	shown = mix(shown, vec3(1.0) - shown * vec3(1.0, 0.9, 0.75), negative);
	COLOR = vec4(shown, 1.0);
}
