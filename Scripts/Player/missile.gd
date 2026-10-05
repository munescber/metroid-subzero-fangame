extends CharacterBody2D

class_name Missile

# Missile projectile: ramps from start_speed to max_speed, then explodes into a
# radius damage zone on impact instead of dealing damage on direct contact.

@export var damage: int = 5
@export var start_speed: float = 90.0
@export var max_speed: float = 140.0
@export var acceleration_time: float = 0.6
@export var explosion_size: Vector2 = Vector2(16, 16)
@export var explosion_duration: float = 0.6
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null
var current_speed: float = 0.0
var accel_timer: float = 0.0
var life_timer: float = 0.0
var has_exploded: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	sprite.play("idle")
	if hitbox:
		hitbox.connect("area_entered", Callable(self, "_on_hitbox_area_entered"))
	life_timer = lifetime
	current_speed = start_speed

func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	accel_timer = min(accel_timer + delta, acceleration_time)
	var t: float = accel_timer / acceleration_time if acceleration_time > 0.0 else 1.0
	current_speed = lerp(start_speed, max_speed, t)

	var motion := direction * current_speed * delta
	var collision := move_and_collide(motion)

	if collision:
		explode(collision.get_position())
		return

	life_timer -= delta
	if life_timer <= 0.0:
		queue_free()

func start(dir: Vector2, shooter_node: Node = null) -> void:
	direction = dir.normalized()
	shooter = shooter_node
	current_speed = start_speed
	accel_timer = 0.0
	life_timer = lifetime
	# sprite art faces up by default, offset by -90 degrees to align with direction, then flipped 180
	rotation = direction.angle() + PI / 2.0

	if shooter is CollisionObject2D:
		add_collision_exception_with(shooter)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if has_exploded or area == null:
		return
	if area.get_parent() == shooter:
		return
	explode(global_position)

func explode(at_position: Vector2) -> void:
	if has_exploded:
		return
	has_exploded = true

	global_position = at_position
	velocity = Vector2.ZERO

	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if hitbox:
		hitbox.set_deferred("monitoring", false)

	sprite.play("explode")

	# query the physics space directly instead of an Area2D: an Area2D only tracks
	# overlaps that begin while monitoring is already true, but the enemy that
	# triggered this explosion is already overlapping us at this exact position,
	# so enabling monitoring now would miss it entirely.
	_apply_explosion_damage()

	await get_tree().create_timer(explosion_duration).timeout
	queue_free()

func _apply_explosion_damage() -> void:
	var space_state := get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = explosion_size

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 16 # Hurtbox layer
	query.collide_with_areas = true
	query.collide_with_bodies = false

	for result: Dictionary in space_state.intersect_shape(query):
		var area: Area2D = result.get("collider")
		if area == null:
			continue

		var parent: Node = area.get_parent()
		if parent == null:
			continue

		# never damage the player who fired the missile
		var is_player: bool = (parent.name == "Player" or parent.name == "player_rundas" or parent.is_in_group("player"))
		if is_player:
			continue

		if area.has_method("receive_hit"):
			area.call("receive_hit", damage, shooter)
