shader_type canvas_item;

// Electric field shader with pulsing glow effect
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float base_intensity : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D noise_texture : hint_default_white;
uniform vec3 dark_green : hint_color = vec3(0.0, 0.345, 0.0);      // #005800
uniform vec3 yellow : hint_color = vec3(0.973, 0.722, 0.0);         // #F8B800
uniform vec3 white : hint_color = vec3(0.988, 0.988, 0.988);        // #FCFCFC

void fragment() {
	// Sample the original texture
	vec4 tex = texture(TEXTURE, UV);
	
	// Create a pulsing glow effect
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	float intensity = base_intensity * (0.5 + pulse * 0.5);
	
	// Distance from center creates a radial glow
	float dist = distance(UV, vec2(0.5));
	float radial_falloff = 1.0 - smoothstep(0.0, 0.7, dist);
	
	// Combine intensity with radial falloff
	float final_intensity = intensity * radial_falloff;
	
	// Blend colors based on intensity
	vec3 glow_color = mix(dark_green, yellow, pulse);
	glow_color = mix(glow_color, white, pulse * 0.3);
	
	// Apply glow to the texture
	vec3 result = tex.rgb;
	
	// If there's alpha in the original, use it for coloring
	if (tex.a > 0.0) {
		result = mix(result, glow_color, final_intensity * 0.7);
	} else {
		// For transparent areas, create the glow effect
		result = glow_color * final_intensity * 0.5;
	}
	
	// Output with pulsing alpha
	COLOR = vec4(result, tex.a * (0.5 + pulse * 0.5));
}
