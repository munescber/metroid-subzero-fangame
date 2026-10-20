class_name BeamImpact
extends AnimatedSprite2D

# Purely visual impact effect spawned where a Bullet / ChargeBeam hits something.
# No collision, no gameplay logic. Plays once and frees itself.

@export var impact_animation: StringName = &"impact"


func _ready() -> void:
	if sprite_frames == null:
		queue_free()
		return
	if not sprite_frames.has_animation(impact_animation):
		push_warning("BeamImpact: animation '%s' not found" % impact_animation)
		queue_free()
		return
	# No frames yet: clean up right away instead of leaving a node that never
	# emits animation_finished.
	if sprite_frames.get_frame_count(impact_animation) == 0:
		queue_free()
		return

	animation_finished.connect(queue_free)
	play(impact_animation)
