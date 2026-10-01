shader_type canvas_item;

uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float base_intensity : hint_range(0.0, 2.0) = 1.5;
uniform vec3 dark_green = vec3(0.18, 1.0, 0.35);
uniform vec3 yellow = vec3(0.973, 0.722, 0.0);
uniform vec3 white = vec3(0.988, 0.988, 0.988);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	float intensity = base_intensity * (0.7 + pulse * 0.3);
	
	float dist = distance(UV, vec2(0.5));
	float radial_falloff = 1.0 - smoothstep(0.0, 0.7, dist);
	
	float final_intensity = intensity * radial_falloff;
	
	vec3 glow_color = mix(dark_green, yellow, pulse);
	glow_color = mix(glow_color, white, pow(pulse, 2.0) * 0.6);
	
	vec3 result = tex.rgb;
	
	if (tex.a > 0.0) {
		// Additive glow keeps the sprite bright/phosphorescent instead of darkening it
		result = mix(result, glow_color, 0.5) + glow_color * final_intensity * 0.8;
	} else {
		result = glow_color * final_intensity;
	}
	
	COLOR = vec4(result, tex.a * clamp(0.7 + pulse * 0.3, 0.0, 1.0));
}

