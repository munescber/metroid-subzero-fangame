extends CanvasLayer

class_name ObtainCutscene

## Foreground cutscene shared by MapPoint and SavePoint: the layered `animation_name` animation. It
## runs with PROCESS_MODE_ALWAYS so it keeps playing while the game is paused. The owner pauses the
## game, awaits play_animation(), shows its message through NotificationManager and then calls finish().

## Animation of the AnimationPlayer to play. If it does not exist, play_animation() skips it.
@export var animation_name: StringName = &"get_map"

@onready var _animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	visible = false

## Shows the layers and plays the animation. Returns when it has finished.
## `world_position` is the world point the animation is drawn around (the layers are drawn around
## `Layer1.position` on screen, which is moved there).
func play_animation(world_position: Vector2 = Vector2.INF) -> void:
	_anchor_to(world_position)
	visible = true
	if _animation_player.has_animation(animation_name):
		_animation_player.play(animation_name)
		await _animation_player.animation_finished
	else:
		push_warning("[ObtainCutscene] No animation '%s'." % animation_name)

func _anchor_to(world_position: Vector2) -> void:
	var shift := Vector2.ZERO
	if world_position.is_finite():
		var screen_position := get_viewport().get_canvas_transform() * world_position
		shift = screen_position - $Layer1.position
	offset = shift

## Hides everything.
func finish() -> void:
	_animation_player.stop()
	visible = false
