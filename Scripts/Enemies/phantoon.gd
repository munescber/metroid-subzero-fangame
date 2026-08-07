extends CharacterBody2D

@export var hover_amplitude: float = 14.0
@export var hover_speed: float = 2.2
@export var drift_amplitude: float = 10.0
@export var drift_speed: float = 1.2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var spawn_position: Vector2
var phase: float


func _ready() -> void:
	spawn_position = global_position
	phase = randf_range(0.0, TAU)
	if sprite != null:
		sprite.play("idle")


func _physics_process(_delta: float) -> void:
	var time_value = Time.get_ticks_msec() / 1000.0
	var bobbing = sin(time_value * hover_speed + phase) * hover_amplitude
	var drifting = cos(time_value * drift_speed + phase * 0.75) * drift_amplitude

	global_position = spawn_position + Vector2(drifting, bobbing)

	if sprite != null:
		sprite.flip_h = drifting < 0
