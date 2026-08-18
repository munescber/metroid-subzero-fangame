extends CharacterBody2D

class_name BouncingFireball

const LIFETIME = 10.0
const MAX_BOUNCES = 5

@export var damage: int = 1
@export var max_speed: float = 200.0

var gravity: float = 300.0  # Default gravity - will be overridden by setup()
var initial_speed: float = 30.0  # Initial horizontal speed
var horizontal_velocity: float = 0.0
var bounce_count: int = 0
var life_timer: float = LIFETIME
var has_hit_player: bool = false
var spawn_grace_period: float = 0.15  # Don't collide for first 0.15 seconds after spawn

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	if sprite:
		sprite.play("idle")
	
	if hitbox:
		hitbox.connect("area_entered", Callable(self, "_on_area_entered"))
	
	# Random horizontal velocity for variation
	horizontal_velocity = randf_range(-initial_speed, initial_speed)
	
	# Start with a small downward velocity to ensure falling immediately
	velocity.y = 10.0


func _physics_process(delta: float) -> void:
	# Reduce grace period
	spawn_grace_period -= delta
	
	# Apply gravity
	velocity.y += gravity * delta
	
	# Clamp vertical velocity to max speed to prevent going too fast
	velocity.y = min(velocity.y, max_speed)
	
	# Horizontal movement (apply friction over time)
	velocity.x = horizontal_velocity
	
	# Move and detect collisions
	var collision = move_and_collide(velocity * delta)
	
	# Only process collisions after grace period expires
	if collision and spawn_grace_period <= 0.0:
		var normal = collision.get_normal()
		
		# Check if hitting the floor (normal points up, so y < -0.5)
		if normal.y < -0.5:  # Hit from above (floor)
			if bounce_count < MAX_BOUNCES:
				# Bounce with energy loss
				velocity.y = -abs(velocity.y) * 0.6  # Reduce bounce height (was 0.7)
				bounce_count += 1
				horizontal_velocity *= 0.7  # Reduce horizontal speed more (was 0.8)
				print_debug("[Fireball] Bounce #", bounce_count, " | velocity.y: ", velocity.y)
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
