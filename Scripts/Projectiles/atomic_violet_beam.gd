extends CharacterBody2D

class_name AtomicVioletBeam

# Fast straight-line bolt fired by AtomicViolet. The direction is fixed at launch (no homing) and the beam
# can't be shot down: it has no Hurtbox. Any hit (player, wall or lifetime end) plays the impact animation.

@export_category("Visual")
@export var fly_animation: StringName = &"fly"
## Must not loop, the beam is freed when it finishes.
@export var impact_animation: StringName = &"impact"

# The sheet art points up, so the sprite is turned by +90 degrees to face the travel direction
const SPRITE_ROTATION_OFFSET := PI / 2.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 180.0
var damage: int = 3
var life_timer: float = 2.5
var shooter: Node = null
var has_impacted: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D


func _ready() -> void:
	collision_layer = 8  # Hitbox layer
	collision_mask = 1   # World only, never the player/enemy bodies

	hitbox.collision_layer = 8
	hitbox.collision_mask = 16  # Hurtboxes
	hitbox.connect("area_entered", Callable(self, "_on_area_entered"))
	sprite.connect("animation_finished", Callable(self, "_on_animation_finished"))
	sprite.play(fly_animation)


func launch(dir: Vector2, proj_speed: float, proj_damage: int, lifetime: float, source: Node = null) -> void:
	direction = dir.normalized()
	speed = proj_speed
	damage = proj_damage
	life_timer = lifetime
	shooter = source
	rotation = direction.angle() + SPRITE_ROTATION_OFFSET


func _physics_process(delta: float) -> void:
	if has_impacted:
		return

	var collision := move_and_collide(direction * speed * delta)
	if collision:
		_impact()
		return

	life_timer -= delta
	if life_timer <= 0.0:
		_impact()


func _on_area_entered(area: Area2D) -> void:
	if has_impacted or area == null:
		return
	var target := area.get_parent()
	if target == null:
		return
	# The shooter is ignored for the beam's whole life (covers the spawn overlap), and hurtboxes of
	# other enemies share layer 16, so only the player counts
	if target == shooter:
		return
	var is_player: bool = target.name == "Player" or target.name == "player_rundas" or target.is_in_group("player")
	if not is_player or not target.has_method("take_damage"):
		return

	target.call("take_damage", damage, self)
	_impact()


# Stops the beam, turns off collision and plays the impact animation. Damage is applied by the
# caller before this runs, so it can only ever be applied once.
func _impact() -> void:
	if has_impacted:
		return
	has_impacted = true
	velocity = Vector2.ZERO
	body_shape.set_deferred("disabled", true)
	hitbox_shape.set_deferred("disabled", true)
	hitbox.set_deferred("monitoring", false)

	if sprite.sprite_frames.has_animation(impact_animation):
		sprite.play(impact_animation)
	else:
		queue_free()


func _on_animation_finished() -> void:
	if has_impacted:
		queue_free()
