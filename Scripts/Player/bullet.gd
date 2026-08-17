extends CharacterBody2D

# Bullet / beam settings.
const SPEED := 120.0
const LIFETIME := 2.0

@export var damage: int = 1
@export var one_shot: bool = true

var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null
var life_timer: float = LIFETIME

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	sprite.play("idle")
	if hitbox:
		hitbox.connect("area_entered", Callable(self, "_on_area_entered"))
		hitbox.connect("body_entered", Callable(self, "_on_body_entered"))

func _physics_process(delta: float) -> void:
	var motion := direction.normalized() * SPEED * delta
	var collision := move_and_collide(motion)

	if collision:
		_on_hit(collision.get_collider())
		return

	life_timer -= delta
	if life_timer <= 0.0:
		queue_free()

func start(dir: Vector2, shooter_node: Node = null) -> void:
	direction = dir.normalized()
	shooter = shooter_node
	life_timer = LIFETIME
	rotation = direction.angle()

	if shooter is CollisionObject2D:
		add_collision_exception_with(shooter)

func _on_hit(collider: Variant) -> void:
	if collider == shooter:
		return

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
		if one_shot:
			queue_free()
		return
	if area and area.has_method("take_damage"):
		area.call("take_damage", damage, shooter)
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
			if one_shot:
				queue_free()
			return
	if body and body.has_method("take_damage"):
		body.call("take_damage", damage, shooter)
		if one_shot:
			queue_free()
		return
