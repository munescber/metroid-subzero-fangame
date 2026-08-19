extends CharacterBody2D

class_name RadialProjectile

const LIFETIME = 5.0

@export var damage: int = 1
var direction: Vector2 = Vector2.RIGHT
var speed: float = 100.0
var shooter: Node = null
var life_timer: float = LIFETIME

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	if sprite:
		sprite.play("idle")
	
	if hitbox:
		hitbox.connect("area_entered", Callable(self, "_on_area_entered"))


func _physics_process(delta: float) -> void:
	velocity = direction * speed
	move_and_collide(velocity * delta)
	
	# Update rotation to face direction
	rotation = direction.angle()
	
	# Handle lifetime
	life_timer -= delta
	if life_timer <= 0.0:
		queue_free()


func launch(dir: Vector2, proj_speed: float, source: Node = null) -> void:
	direction = dir.normalized()
	speed = proj_speed
	shooter = source
	life_timer = LIFETIME
	rotation = direction.angle()


func _on_area_entered(area: Area2D) -> void:
	# Check if this is an enemy hurtbox (not our own)
	if area == hitbox or area == null:
		return
	
	# Don't hit the shooter
	if area.get_parent() == shooter:
		return
	
	# Apply damage if this is a hurtbox
	if area.has_method("receive_hit"):
		area.call("receive_hit", damage, self)
		queue_free()
		return
	
	# Check if hit a solid object (wall)
	var collider = area.get_parent()
	if collider and collider != shooter:
		queue_free()
