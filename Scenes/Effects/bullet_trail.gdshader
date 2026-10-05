shader_type canvas_item;

// Trail copies are drawn along local -X, which is the bullet's trajectory (the bullet is rotated by its direction).
uniform vec4 tint : source_color = vec4(0.235294, 0.737255, 0.988235, 1.0); // #3cbcfc
uniform int copies : hint_range(1, 8) = 3;
uniform float spacing = 5.0;
uniform float start_radius = 3.5;
uniform float scale_falloff : hint_range(0.1, 1.0) = 0.75;
uniform float start_alpha : hint_range(0.0, 1.0) = 0.6;
uniform float alpha_falloff : hint_range(0.1, 1.0) = 0.55;
// Distance travelled by the bullet; copies only appear once the bullet has moved far enough.
uniform float trail_length = 0.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float alpha = 0.0;
	for (int i = 1; i <= copies; i++) {
		float fi = float(i);
		if (fi * spacing > trail_length) {
			break;
		}
		float radius = start_radius * pow(scale_falloff, fi);
		float a = start_alpha * pow(alpha_falloff, fi - 1.0);
		vec2 center = vec2(-fi * spacing, 0.0);
		alpha = max(alpha, step(length(local_pos - center), radius) * a);
	}
	COLOR = vec4(tint.rgb, alpha * tint.a);
}
