shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(0.06, 0.14, 0.19, 1.0);
uniform float darken_amount : hint_range(0.0, 1.0) = 0.28;
uniform float mist_strength : hint_range(0.0, 0.4) = 0.08;
uniform float vignette_strength : hint_range(0.0, 0.8) = 0.36;

void fragment() {
	vec4 tex_col = texture(TEXTURE, UV);
	vec3 col = mix(tex_col.rgb, tint_color.rgb, darken_amount);

	// Subtle drifting atmospheric mist
	float mist_a = sin(UV.x * 5.0 + TIME * 0.18) * cos(UV.y * 4.0 - TIME * 0.12);
	float mist_b = sin(UV.x * 8.0 - TIME * 0.11 + UV.y * 3.0);
	float mist = clamp((mist_a * 0.5 + mist_b * 0.5) * 0.5 + 0.5, 0.0, 1.0);
	col += vec3(0.05, 0.22, 0.24) * (mist * mist_strength);

	// Gentle framing vignette so center nodes pop cleanly
	vec2 centered = UV - vec2(0.5, 0.5);
	float dist = length(centered * vec2(1.0, 0.85));
	float vig = smoothstep(0.32, 0.82, dist) * vignette_strength;
	col *= (1.0 - vig);

	COLOR = vec4(col, tex_col.a);
}
