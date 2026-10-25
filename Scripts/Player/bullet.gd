extends CharacterBody2D

class_name Bullet

# Bullet / beam settings. Exported so derived projectiles (e.g. ChargeBeam)
# can tune them from their own scene.
@export var speed: float = 140.0
@export var lifetime: float = 3.0
@export var damage: int = 1
@export var one_shot: bool = true
# Visual-only effect spawned on impact. impact_animation picks which animation of
# the effect scene plays, so each beam can have its own look from one shared scene.
@export var impact_effect_scene: PackedScene = preload("res://Scenes/Effects/beam_impact.tscn")
@export var impact_animation: StringName = &"impact"

var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null
var life_timer: float = lifetime

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var trail: Sprite2D = $Trail

var distance_travelled: float = 0.0

func _ready() -> void:
	sprite.play("idle")
	if hitbox:
		hitbox.connect("area_entered", Callable(self, "_on_area_entered"))
		hitbox.connect("body_entered", Callable(self, "_on_body_entered"))

func _physics_process(delta: float) -> void:
	var motion := direction.normalized() * speed * delta
	var collision := move_and_collide(motion)

	if collision:
		_on_hit(collision.get_collider(), collision.get_position())
		return

	distance_travelled += motion.length()
	trail.material.set_shader_parameter("trail_length", distance_travelled)

	life_timer -= delta
	if life_timer <= 0.0:
		queue_free()

func start(dir: Vector2, shooter_node: Node = null) -> void:
	direction = dir.normalized()
	shooter = shooter_node
	life_timer = lifetime
	rotation = direction.angle()

	if shooter is CollisionObject2D:
		add_collision_exception_with(shooter)

func _spawn_impact(at_position: Vector2) -> void:
	# queued for deletion means this projectile already handled an impact this frame
	if impact_effect_scene == null or is_queued_for_deletion():
		return
	var parent := get_parent()
	if parent == null:
		return
	var effect := impact_effect_scene.instantiate() as Node2D
	if effect == null:
		return
	if effect is BeamImpact:
		effect.impact_animation = impact_animation
	# added to the parent (not to self) so it outlives the projectile
	parent.add_child(effect)
	effect.global_position = at_position
	effect.global_rotation = global_rotation

func _on_hit(collider: Variant, hit_position: Vector2 = global_position) -> void:
	if collider == shooter:
		return

	_spawn_impact(hit_position)

	if collider is Node:
		if collider.has_node("Hurtbox"):
			var hurtbox = collider.get_node("Hurtbox")
			if hurtbox and hurtbox.has_method("receive_hit"):
				hurtbox.call("receive_hit", damage, shooter)
				queue_free()
				return
		if collider.has_method("take_damage"):
			collider.call("take_damage", damage, shooter)
			queue_free()
			return

	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area == hitbox or area == null:
		return
	if area and area.get_parent() == shooter:
		return
	if area and area.has_method("receive_hit"):
		area.call("receive_hit", damage, shooter)
		_spawn_impact(global_position)
		if one_shot:
			queue_free()
		return
	if area and area.has_method("take_damage"):
		area.call("take_damage", damage, shooter)
		_spawn_impact(global_position)
		if one_shot:
			queue_free()
		return

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body and body.has_node("Hurtbox"):
		var hurtbox = body.get_node("Hurtbox")
		if hurtbox and hurtbox.has_method("receive_hit"):
			hurtbox.call("receive_hit", damage, shooter)
			_spawn_impact(global_position)
			if one_shot:
				queue_free()
			return
	if body and body.has_method("take_damage"):
		body.call("take_damage", damage, shooter)
		_spawn_impact(global_position)
		if one_shot:
			queue_free()
		return
