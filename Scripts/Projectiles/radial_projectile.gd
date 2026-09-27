extends CharacterBody2D

class_name RadialProjectile

const LIFETIME = 5.0

@export var damage: int = 1
var direction: Vector2 = Vector2.RIGHT
var speed: float = 100.0
var shooter: Node = null
var life_timer: float = LIFETIME

# Fade animation
@export var enable_fade_animation: bool = true
var is_fading: bool = false
var fade_timer: float = 0.0
var fade_duration: float = 0.3

# Grace period so the projectile can't be destroyed by its own spawner's contact damage
var hurtbox_grace_period: float = 0.15

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
	
	# Re-enable hurtbox once clear of the spawner's own contact damage area
	if hurtbox_grace_period > 0.0:
		hurtbox_grace_period -= delta
		if hurtbox_grace_period <= 0.0 and hurtbox:
			hurtbox.monitorable = true
	
	velocity = direction * speed
	var collision = move_and_collide(velocity * delta)
	
	# Hit a wall/ceiling/floor (physical body collision only matches World layer) - fade instead of getting stuck
	if collision:
		initiate_fade(true)
		return
	
	# Update rotation to face direction (sprite art faces up, so offset by -90 degrees)
	rotation = direction.angle() - PI / 2.0
	
	# Handle lifetime
	life_timer -= delta
	if life_timer <= 0.0:
		queue_free()


func launch(dir: Vector2, proj_speed: float, source: Node = null) -> void:
	direction = dir.normalized()
	speed = proj_speed
	shooter = source
	life_timer = LIFETIME
	rotation = direction.angle() - PI / 2.0
	is_fading = false
	fade_timer = 0.0
	hurtbox_grace_period = 0.15
	if hurtbox:
		hurtbox.monitorable = false
	if sprite:
		sprite.modulate.a = 1.0


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
	
	if is_player:
		# Hit the player, apply damage
		if parent.has_method("take_damage"):
			parent.call("take_damage", damage, self)
			initiate_fade()
			return
	
	# Don't hit the shooter
	if parent == shooter:
		return
	
	# Apply damage if this is an enemy hurtbox
	if area.has_method("receive_hit"):
		area.call("receive_hit", damage, self)
		queue_free()
		return
	
	# Check if hit a solid object (wall)
	if parent and parent != shooter:
		queue_free()
