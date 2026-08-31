shader_type canvas_item;

uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float base_intensity : hint_range(0.0, 2.0) = 1.0;
uniform vec3 dark_green = vec3(0.0, 0.345, 0.0);
uniform vec3 yellow = vec3(0.973, 0.722, 0.0);
uniform vec3 white = vec3(0.988, 0.988, 0.988);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	float intensity = base_intensity * (0.5 + pulse * 0.5);
	
	float dist = distance(UV, vec2(0.5));
	float radial_falloff = 1.0 - smoothstep(0.0, 0.7, dist);
	
	float final_intensity = intensity * radial_falloff;
	
	vec3 glow_color = mix(dark_green, yellow, pulse);
	glow_color = mix(glow_color, white, pulse * 0.3);
	
	vec3 result = tex.rgb;
	
	if (tex.a > 0.0) {
		result = mix(result, glow_color, final_intensity * 0.7);
	} else {
		result = glow_color * final_intensity * 0.5;
	}
	
	COLOR = vec4(result, tex.a * (0.5 + pulse * 0.5));
}
