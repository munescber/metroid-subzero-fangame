shader_type canvas_item;
// Clean NES/SNES-style CRT overlay. Place on a CanvasLayer above everything else.
// Limitation: hint_screen_texture only sees what was drawn on lower layers, so
// keep this overlay's CanvasLayer higher than every other layer.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

// 0 = effect off, 1 = full.
uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;
// Darkening at the scanline gaps (0.15 is subtle).
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.15;
// Number of scanlines across the full screen height (240 = every 2nd game pixel at 480p).
uniform float scanline_density : hint_range(60.0, 480.0, 1.0) = 240.0;
// Strength of the halo around bright pixels.
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.15;
// Glow reach in screen pixels.
uniform float glow_radius : hint_range(1.0, 6.0) = 2.5;
// Only pixels brighter than this contribute to glow.
uniform float glow_threshold : hint_range(0.3, 1.0) = 0.7;

vec3 bright(vec2 uv) {
	vec3 c = texture(screen_texture, uv).rgb;
	float l = max(c.r, max(c.g, c.b));
	return c * smoothstep(glow_threshold, 1.0, l);
}

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(screen_texture, 0));
	vec3 base = texture(screen_texture, SCREEN_UV).rgb;

	// Glow: 8 neighbours at two radii, thresholded so only bright pixels bloom.
	vec3 g = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 d = vec2(cos(a), sin(a)) * px;
		g += bright(SCREEN_UV + d * glow_radius);
		g += bright(SCREEN_UV + d * glow_radius * 2.0) * 0.5;
	}
	g /= 12.0;
	vec3 col = base + g * glow_intensity * 2.0;

	// Scanlines: soft, static, tied to screen height rather than window size.
	float s = 0.5 + 0.5 * cos(SCREEN_UV.y * scanline_density * 6.2831853);
	col *= 1.0 - scanline_strength * s;
	// Compensate the average darkening to keep overall brightness.
	col *= 1.0 + scanline_strength * 0.5;

	COLOR = vec4(mix(base, clamp(col, 0.0, 1.0), effect_strength), 1.0);
}
