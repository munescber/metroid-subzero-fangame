extends CharacterBody2D

class_name BouncingFireball

const LIFETIME = 10.0
const MAX_BOUNCES = 5

@export var damage: int = 1
@export var max_speed: float = 200.0

var gravity: float = 300.0
var initial_speed: float = 50.0
var horizontal_velocity: float = 0.0
var bounce_count: int = 0
var life_timer: float = LIFETIME
var has_hit_player: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	if sprite:
		sprite.play("idle")
	
	if hitbox:
		hitbox.connect("area_entered", Callable(self, "_on_area_entered"))
	
	# Random horizontal velocity for variation
	horizontal_velocity = randf_range(-initial_speed, initial_speed)


func _physics_process(delta: float) -> void:
	# Apply gravity
	velocity.y += gravity * delta
	
	# Clamp vertical velocity to max speed
	velocity.y = min(velocity.y, max_speed)
	
	# Horizontal movement
	velocity.x = horizontal_velocity
	
	# Move and detect collisions
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		var normal = collision.get_normal()
		
		# Check if hitting the floor (roughly)
		if normal.y < -0.5:  # Hit from above (floor)
			if bounce_count < MAX_BOUNCES:
				# Bounce
				velocity.y = -abs(velocity.y) * 0.7  # Reduce bounce height
				bounce_count += 1
				horizontal_velocity *= 0.8  # Reduce horizontal speed
				print_debug("[Fireball] Bounce #", bounce_count)
			else:
				# Max bounces reached, destroy
				queue_free()
				return
		else:
			# Hit something else (wall), destroy
			queue_free()
			return
	
	# Handle lifetime
	life_timer -= delta
	if life_timer <= 0.0:
		queue_free()


func setup(gravity_val: float, speed_val: float) -> void:
	gravity = gravity_val
	initial_speed = speed_val
	horizontal_velocity = randf_range(-initial_speed, initial_speed)


func _on_area_entered(area: Area2D) -> void:
	# Check if this is a player hurtbox
	if area == hitbox or area == null:
		return
	
	# Apply damage if this is a hurtbox and we haven't hit the player yet
	if area.has_method("receive_hit") and not has_hit_player:
		area.call("receive_hit", damage, self)
		has_hit_player = true
		# Don't destroy immediately - fireball continues bouncing
		print_debug("[Fireball] Hit player!")
