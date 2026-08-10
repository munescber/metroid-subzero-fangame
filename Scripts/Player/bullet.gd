extends CharacterBody2D

# Bullet / beam settings.
const SPEED := 120.0
const LIFETIME := 2.0

var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null
var life_timer: float = LIFETIME

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	var motion := direction.normalized() * SPEED * delta
	var collision := move_and_collide(motion)

	if collision:
		_on_hit(collision)
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

func _on_hit(collision: KinematicCollision2D) -> void:
	var collider := collision.get_collider()
	if collider == shooter:
		return

	if collider is Node and collider.has_method("take_damage"):
		collider.call("take_damage", 1)

	queue_free()
