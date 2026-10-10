extends Node2D

class_name RisingGate

## A one-shot gate that slides straight up when its ActivationButton fires.
## Movement lives here; appearance and collision live in the scene:
##   Body/TileTop, Body/TileMiddle, Body/TileBottom -> texture + region_rect (multi-select all and edit in the Inspector)
##   Body/CollisionShape2D         -> collision size (edit separately if the sprite size changes)
## The gate's closed position is wherever Body sits in the editor, so move the
## whole node (or Body) to place it. It rises toward decreasing Y by rise_distance.

signal opened

@export_group("Movement")
@export var rise_distance: float = 48.0
@export var rise_duration: float = 1.0
@export var start_delay: float = 0.0
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_SINE

@export_group("State")
@export var start_open: bool = false

@export var debug_enabled: bool = false

@onready var body: AnimatableBody2D = $Body

var is_open: bool = false
var is_moving: bool = false

var _closed_local: Vector2
var _open_local: Vector2
var _tween: Tween = null

func _ready() -> void:
	_closed_local = body.position
	_open_local = _closed_local - Vector2(0, rise_distance)

	if start_open:
		body.position = _open_local
		is_open = true

## Called by ActivationButton. Does nothing once the gate is rising or open.
func activate() -> void:
	if debug_enabled:
		print_debug("[RisingGate] activate() called. is_open=", is_open, " is_moving=", is_moving)
	if is_open or is_moving:
		return

	is_moving = true
	_tween = create_tween()
	# AnimatableBody2D should move in the physics step so the player is carried/blocked correctly.
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_ease(ease_type)
	_tween.set_trans(trans_type)
	if start_delay > 0.0:
		_tween.tween_interval(start_delay)
	_tween.tween_property(body, "position", _open_local, rise_duration)
	_tween.finished.connect(_on_rise_finished)

func _on_rise_finished() -> void:
	is_moving = false
	is_open = true
	if debug_enabled:
		print_debug("[RisingGate] Rise finished.")
	opened.emit()
