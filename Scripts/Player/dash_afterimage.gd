class_name DashAfterimage
extends Sprite2D

# Purely visual copy of the player's current frame. No collision, no gameplay logic.

const FADE_TIME := 0.25
const START_ALPHA := 0.5
const TINT := Color(0.55, 0.8, 1.0)


func setup(source: AnimatedSprite2D) -> void:
	texture = source.sprite_frames.get_frame_texture(source.animation, source.frame)
	global_position = source.global_position
	global_scale = source.global_scale
	flip_h = source.flip_h
	offset = source.offset
	centered = source.centered
	# just below the player so the real sprite always stays on top
	z_index = source.z_index - 1
	modulate = Color(TINT.r, TINT.g, TINT.b, START_ALPHA)


func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)
