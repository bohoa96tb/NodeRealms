shader_type canvas_item;

uniform float speed : hint_range(-4.0, 4.0) = 0.85;
uniform float pulse_frequency : hint_range(1.0, 12.0) = 4.0;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.72;
uniform float glow_boost : hint_range(0.0, 2.0) = 0.65;

void fragment() {
	vec4 tex_col = texture(TEXTURE, UV) * COLOR;
	float wave = 0.5 + 0.5 * sin(UV.x * pulse_frequency * 6.283185 - TIME * speed * 6.283185);
	float pulse = mix(base_alpha, 1.0, wave);
	tex_col.rgb += tex_col.rgb * (wave * glow_boost);
	tex_col.a *= pulse;
	COLOR = tex_col;
}
