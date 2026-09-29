extends Node2D

class_name RisingPlatform

## Place this node's origin at the floor tile where the pillar should emerge
## (snap it to the tile grid like a normal floor tile). The child "Body"
## starts tucked one tile_size below that origin automatically, so the
## sibling "ShaftCap" sprite hides it without any manual position math.

@export var rise_distance: float = 48.0
@export var rise_duration: float = 0.5
@export var start_raised: bool = false
@export var can_reverse: bool = true
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_QUAD
@export var tile_size: float = 16.0

@export var debug_enabled: bool = false

@onready var body: AnimatableBody2D = $Body

var is_raised: bool = false
var is_moving: bool = false

var _lowered_local: Vector2
var _raised_local: Vector2
var _tween: Tween = null

func _ready() -> void:
	_lowered_local = Vector2(0, tile_size)
	_raised_local = _lowered_local - Vector2(0, rise_distance)

	if start_raised:
		body.position = _raised_local
		is_raised = true
	else:
		body.position = _lowered_local
		is_raised = false

func activate() -> void:
	if debug_enabled:
		print_debug("[RisingPlatform] activate() called. is_raised=", is_raised, " is_moving=", is_moving)
	if is_raised or is_moving:
		return
	_move_to(_raised_local, true)

func lower() -> void:
	if debug_enabled:
		print_debug("[RisingPlatform] lower() called. can_reverse=", can_reverse, " is_raised=", is_raised, " is_moving=", is_moving)
	if not can_reverse or not is_raised or is_moving:
		return
	_move_to(_lowered_local, false)

func toggle() -> void:
	if debug_enabled:
		print_debug("[RisingPlatform] toggle() called. is_raised=", is_raised)
	if is_raised:
		lower()
	else:
		activate()

func _move_to(target_local: Vector2, raised_after: bool) -> void:
	is_moving = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(ease_type)
	_tween.set_trans(trans_type)
	_tween.tween_property(body, "position", target_local, rise_duration)
	_tween.finished.connect(_on_move_finished.bind(raised_after))
	if debug_enabled:
		print_debug("[RisingPlatform] Moving to ", target_local, " raised_after=", raised_after)

func _on_move_finished(raised_after: bool) -> void:
	is_moving = false
	is_raised = raised_after
	if debug_enabled:
		print_debug("[RisingPlatform] Move finished. is_raised=", is_raised)
