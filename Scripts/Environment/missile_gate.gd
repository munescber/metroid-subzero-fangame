extends StaticBody2D

## An iron fence that blocks a doorway until a missile explodes on it. It is meant to be placed on
## top of a normal RoomGate and is independent of it: it never touches the RoomGate's logic.
## Beams (Bullet and ChargeBeam) are stopped by the solid body but have no effect on it.
##
## There is deliberately no class_name: the gate needs the children from missile_gate.tscn
## (body, sprite, detector), so add it by instancing that scene, not from the Create Node dialog.
##
## Projectiles report hits to take_damage()/receive_hit() with only (damage, shooter), so a missile
## cannot be told apart from a beam there. Instead, the MissileDetector (an Area2D on mask 8, like
## ActivationButton) watches for Missile nodes, and the gate opens once a tracked missile has
## actually exploded next to it. The detector is slightly larger than the body so the missile is
## already tracked when it explodes against the RoomGate's Hurtbox or this body.

signal opened

const ANIM_IDLE := &"idle"
const ANIM_OPEN := &"open"  # must not loop, or animation_finished never fires

## Free the gate once the "open" animation finishes. If off, it stays on the animation's last frame.
@export var free_when_open: bool = true
## Stable id so the gate stays open after saving. Leave empty for gates that always come back.
@export var save_id: String = ""
@export var debug_enabled: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var detector: Area2D = $MissileDetector

var is_open: bool = false

# Missile -> number of its areas (Hitbox, ExplosionArea) currently overlapping the detector.
var _tracked: Dictionary = {}

func _ready() -> void:
	sprite.play(ANIM_IDLE)
	detector.area_entered.connect(_on_detector_area_entered)
	detector.area_exited.connect(_on_detector_area_exited)
	set_physics_process(false)
	if save_id != "":
		add_to_group("saveable")

func _on_detector_area_entered(area: Area2D) -> void:
	if is_open:
		return
	var missile := area.get_parent() as Missile
	if missile == null:
		return
	_tracked[missile] = _tracked.get(missile, 0) + 1
	# the missile may have exploded in the same physics step it reached the detector
	_check_missile(missile)
	if not is_open:
		set_physics_process(true)

func _on_detector_area_exited(area: Area2D) -> void:
	var missile := area.get_parent() as Missile
	if missile == null or not _tracked.has(missile):
		return
	_check_missile(missile)
	if is_open:
		return
	_tracked[missile] -= 1
	if _tracked[missile] <= 0:
		_tracked.erase(missile)
	if _tracked.is_empty():
		set_physics_process(false)

# Missiles explode inside move_and_collide / area callbacks, so has_exploded is polled each frame.
func _physics_process(_delta: float) -> void:
	for missile in _tracked.keys():
		if not is_instance_valid(missile):
			_tracked.erase(missile)
		elif _check_missile(missile):
			return
	if _tracked.is_empty():
		set_physics_process(false)

func _check_missile(missile: Missile) -> bool:
	if is_open or not missile.has_exploded:
		return false
	if debug_enabled:
		print_debug("[MissileGate] Missile impact, opening.")
	_open()
	return true

func _open() -> void:
	if is_open:
		return
	is_open = true
	_tracked.clear()
	set_physics_process(false)
	# physics callbacks may be running, so the collision is disabled deferred
	body_shape.set_deferred("disabled", true)
	detector.set_deferred("monitoring", false)
	if save_id != "":
		SaveManager.set_flag(save_id, {"open": true})
	opened.emit()

	# no "open" frames means there is nothing to wait for
	var frames := sprite.sprite_frames
	if frames and frames.has_animation(ANIM_OPEN) and frames.get_frame_count(ANIM_OPEN) > 0:
		sprite.animation_finished.connect(_on_open_finished, CONNECT_ONE_SHOT)
		sprite.play(ANIM_OPEN)
	else:
		_on_open_finished()

func _on_open_finished() -> void:
	if debug_enabled:
		print_debug("[MissileGate] Open, collision disabled.")
	if free_when_open:
		queue_free()

## An opened gate removes itself, so it reports through SaveManager.set_flag() instead.
func get_save_data() -> Dictionary:
	return {}

func load_save_data(data: Dictionary) -> void:
	if data.get("open", false):
		queue_free()
