shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

uniform float distortion_strength : hint_range(0.0, 0.05) = 0.006;
uniform float color_variation : hint_range(0.0, 0.3) = 0.04;
uniform float speed : hint_range(0.1, 15.0) = 4.0;
uniform float noise_scale : hint_range(1.0, 100.0) = 25.0;

float hash(vec2 p)
{
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment()
{
	vec2 uv = SCREEN_UV;

	float t = floor(TIME * speed);
	vec2 cell = floor(uv * noise_scale);

	float n1 = hash(cell + t);
	float n2 = hash(cell + t + 17.3);
	float n3 = hash(cell + t + 42.7);

	vec2 offset = (vec2(n1, n2) - 0.5) * distortion_strength;
	vec4 col = texture(screen_tex, uv + offset);

	float shift = (n3 - 0.5) * color_variation;
	col.rgb += shift;

	COLOR = col;
}
