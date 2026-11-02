extends StaticBody2D

class_name RoomGate

## A bubble gate that blocks a doorway until the player shoots it.
## Any player projectile (Bullet, ChargeBeam, Missile) opens it. It plays the
## "open" animation while still solid, then loses all collision and stays open.
## A gate can have a partner on the other side of a room border: opening one opens the other
## instantly, and with `close_again` both close again after `close_delay` seconds.
##
## Projectiles reach it through the project's usual damage path: Bullet/ChargeBeam
## call take_damage() on the body they hit, and Missile explosions call
## receive_hit() on the Hurtbox child, which forwards here. Layers: this body is on
## World (1) so it blocks the player; the Hurtbox is on layer 16 so projectiles see it.

signal opened
signal closed

## Playback speed of the "open" animation (1.0 = the speed set in the scene, 10 fps).
@export var open_speed_scale: float = 1.0
## The gate on the other side of the doorway (usually in the neighbouring room).
@export var partner_path: NodePath
## Closes again after being open for `close_delay` seconds by playing "open" backwards.
## It waits while the player is in the doorway, and the countdown only runs while its room is active.
@export var close_again: bool = false
@export_range(0.1, 60.0, 0.1) var close_delay: float = 3.0
## Stable id so the gate stays open after saving. Gates with `close_again` are never saved.
@export var save_id: String = ""
@export var debug_enabled: bool = false

const PLAYER_BODY_LAYER := 2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D

var is_opening: bool = false
var is_open: bool = false
var is_closing: bool = false

var _close_countdown: float = 0.0

func _ready() -> void:
	sprite.speed_scale = open_speed_scale
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle")
	set_physics_process(false)
	if save_id != "":
		add_to_group("saveable")

## Called by projectiles directly (Bullet) or through the Hurtbox (Missile).
func take_damage(_amount: int, source = null) -> void:
	if is_open or is_opening or is_closing:
		return
	if not _is_player_source(source):
		if debug_enabled:
			print_debug("[RoomGate] Ignored hit from non-player source: ", source)
		return

	is_opening = true
	sprite.play("open")
	if debug_enabled:
		print_debug("[RoomGate] Opening.")

# Only the player's shots may open the gate; enemy hitboxes share the same layers.
func _is_player_source(source) -> bool:
	return source is CollisionObject2D and (source.collision_layer & PLAYER_BODY_LAYER) != 0

func _on_animation_finished() -> void:
	if sprite.animation != &"open":
		return
	if is_closing:
		is_closing = false
		sprite.play("idle")
		if debug_enabled:
			print_debug("[RoomGate] Closed.")
		closed.emit()
		return
	_enter_open_state()
	if debug_enabled:
		print_debug("[RoomGate] Open, collision disabled.")
	opened.emit()
	var partner := _get_partner()
	if partner != null:
		partner.open_instantly()

func _physics_process(delta: float) -> void:
	_close_countdown -= delta
	if _close_countdown <= 0.0 and not _player_in_doorway():
		_start_closing()

## Skips the animation and leaves the gate open (used by the partner gate, which may be in a
## room that is not simulating).
func open_instantly() -> void:
	if is_open or is_opening:
		return
	is_closing = false
	sprite.animation = &"open"
	sprite.frame = sprite.sprite_frames.get_frame_count(&"open") - 1
	sprite.pause()
	_enter_open_state()
	opened.emit()

## Skips the animation and leaves the gate closed and solid.
func close_instantly() -> void:
	if not (is_open or is_opening or is_closing):
		return
	set_physics_process(false)
	is_open = false
	is_opening = false
	is_closing = false
	_set_collision_enabled(true)
	sprite.play("idle")
	closed.emit()

func _enter_open_state() -> void:
	is_opening = false
	is_closing = false
	is_open = true
	_set_collision_enabled(false)
	_close_countdown = close_delay
	set_physics_process(close_again)

# Solid again from the first frame of the closing animation, so nothing slips in behind it.
func _start_closing() -> void:
	set_physics_process(false)
	is_open = false
	is_closing = true
	_set_collision_enabled(true)
	sprite.animation = &"open"
	sprite.frame = sprite.sprite_frames.get_frame_count(&"open") - 1
	sprite.play_backwards(&"open")
	if debug_enabled:
		print_debug("[RoomGate] Closing.")
	var partner := _get_partner()
	if partner != null:
		partner.close_instantly()

func _set_collision_enabled(enabled: bool) -> void:
	body_shape.set_deferred("disabled", not enabled)
	hurtbox_shape.set_deferred("disabled", not enabled)

func _player_in_doorway() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hurtbox_shape.shape
	query.transform = hurtbox_shape.global_transform
	query.collision_mask = PLAYER_BODY_LAYER
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func get_save_data() -> Dictionary:
	return {"open": true} if is_open and not close_again else {}

func load_save_data(data: Dictionary) -> void:
	if data.get("open", false):
		open_instantly()

func _get_partner() -> RoomGate:
	return get_node_or_null(partner_path) as RoomGate
