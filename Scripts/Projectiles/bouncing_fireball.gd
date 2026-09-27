extends CharacterBody2D

class_name BouncingFireball

# Debug toggle
@export var debug_enabled: bool = false

const LIFETIME = 6000.0
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

# Fade animation
@export var enable_fade_animation: bool = true
var is_fading: bool = false
var fade_timer: float = 0.0
var fade_duration: float = 0.3

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	if sprite:
		sprite.play("idle")
	
	if hitbox:
		hitbox.connect("area_entered", Callable(self, "_on_area_entered"))
	
	if hurtbox:
		hurtbox.monitorable = false
	
	# Random horizontal velocity for variation
	horizontal_velocity = randf_range(-initial_speed, initial_speed)
	
	# Start with a small downward velocity to ensure falling immediately
	velocity.y = 10.0


func _physics_process(delta: float) -> void:
	# Handle fade animation
	if is_fading:
		if enable_fade_animation and sprite:
			if not sprite.is_playing():
				queue_free()
		else:
			fade_timer += delta
			if sprite:
				var fade_progress = fade_timer / fade_duration
				sprite.modulate.a = lerp(1.0, 0.0, fade_progress)
			if fade_timer >= fade_duration:
				queue_free()
		return
	
	# Reduce grace period
	spawn_grace_period -= delta
	
	# Re-enable hurtbox once clear of the spawner's own contact damage area
	if spawn_grace_period <= 0.0 and hurtbox and not hurtbox.monitorable:
		hurtbox.monitorable = true
	
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
				if debug_enabled:
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
	is_fading = false
	fade_timer = 0.0
	spawn_grace_period = 0.15
	if hurtbox:
		hurtbox.monitorable = false
	if sprite:
		sprite.modulate.a = 1.0


func _on_area_entered(area: Area2D) -> void:
	# Check if this is our own hitbox
	if area == hitbox or area == hurtbox or area == null:
		return
	
	# Check if hit the player
	var parent = area.get_parent()
	var is_player = (parent and (parent.name == "Player" or 
							parent.name == "player_rundas" or
							parent.is_in_group("player") or
							(parent.get_script() and parent.get_script().resource_name.contains("player"))))
	
	if is_player and not has_hit_player:
		# Hit the player, apply damage
		if parent.has_method("take_damage"):
			if debug_enabled:
				print_debug("[Fireball] Hit player!")
			parent.call("take_damage", damage, self)
			has_hit_player = true
			initiate_fade()
			return
	
	# Apply damage if this is an enemy hurtbox and we haven't hit the player yet
	if area.has_method("receive_hit") and not has_hit_player:
		area.call("receive_hit", damage, self)
		has_hit_player = true
		# Don't destroy immediately - fireball continues bouncing


func receive_hit(_damage_amount: int, _source = null) -> void:
	"""Called when hit by a player bullet's hitbox."""
	initiate_fade()


func take_damage(_damage_amount: int, _source = null) -> void:
	"""Called by our own Hurtbox when hit by a player bullet."""
	initiate_fade()


func initiate_fade(_play_fade_animation: bool = true) -> void:
	"""Start the fade-out animation."""
	if not is_fading:
		is_fading = true
		fade_timer = 0.0
		if enable_fade_animation and sprite:
			sprite.play("fade")
