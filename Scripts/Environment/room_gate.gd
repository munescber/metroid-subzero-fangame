extends StaticBody2D

class_name RoomGate

## A bubble gate that blocks a doorway until the player shoots it.
## Any player projectile (Bullet, ChargeBeam, Missile) opens it. It plays the
## "open" animation while still solid, then loses all collision and stays open.
##
## Projectiles reach it through the project's usual damage path: Bullet/ChargeBeam
## call take_damage() on the body they hit, and Missile explosions call
## receive_hit() on the Hurtbox child, which forwards here. Layers: this body is on
## World (1) so it blocks the player; the Hurtbox is on layer 16 so projectiles see it.

signal opened

## Playback speed of the "open" animation (1.0 = the speed set in the scene, 10 fps).
@export var open_speed_scale: float = 1.0
@export var debug_enabled: bool = false

const PLAYER_BODY_LAYER := 2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D

var is_opening: bool = false
var is_open: bool = false

func _ready() -> void:
	sprite.speed_scale = open_speed_scale
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle")

## Called by projectiles directly (Bullet) or through the Hurtbox (Missile).
func take_damage(_amount: int, source = null) -> void:
	if is_open or is_opening:
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
	is_opening = false
	is_open = true
	# the last frame is empty, so the sprite simply stays on it
	body_shape.set_deferred("disabled", true)
	hurtbox_shape.set_deferred("disabled", true)
	if debug_enabled:
		print_debug("[RoomGate] Open, collision disabled.")
	opened.emit()
