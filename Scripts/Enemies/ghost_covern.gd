extends CharacterBody2D

class_name GhostCovern

# ==============================================================================
# STATE MACHINE
# ==============================================================================

enum State {
	WANDERING,
	HAUNTING,
	INTANGIBLE,
	DEAD
}

var current_state: State = State.WANDERING

# ==============================================================================
# FEATURE TOGGLES (Allows selective enabling/disabling of features)
# ==============================================================================

@export_category("Feature Toggles")
@export var enable_wandering: bool = true
@export var enable_haunting: bool = true
@export var enable_intangibility: bool = true
@export var enable_detection: bool = true

# ==============================================================================
# DETECTION CONFIGURATION
# ==============================================================================

@export_category("Detection")
@export var detection_radius: float = 160.0
@export var disengage_radius: float = 220.0

# Player reference
var player: Node2D = null
var player_detected: bool = false

# ==============================================================================
# MOVEMENT CONFIGURATION
# ==============================================================================

@export_category("Movement")
@export var wander_speed: float = 25.0
@export var haunt_speed: float = 55.0
@export var acceleration: float = 100.0
@export var preferred_distance: float = 40.0
@export var wander_radius: float = 150.0  # How far from starting position to wander

# Movement state
var current_velocity: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var wander_choose_interval: float = 2.0  # Time between choosing new targets

# ==============================================================================
# INTANGIBILITY CONFIGURATION
# ==============================================================================

@export_category("Intangibility")
@export var intangible_duration: float = 1.0
@export var intangible_cooldown: float = 3.0
@export var intangible_fade_amount: float = 0.5  # 0.0 = invisible, 1.0 = visible

var is_intangible: bool = false
var intangible_state_timer: float = 0.0
var intangible_cooldown_timer: float = 0.0

# ==============================================================================
# HEALTH CONFIGURATION
# ==============================================================================

@export_category("Health")
@export var max_health: int = 10

# ==============================================================================
# NODE REFERENCES
# ==============================================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Area2D = $Hurtbox
@onready var detection_area: Area2D = $DetectionArea

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	# Initialize health component
	health.max_health = max_health
	health.current_health = max_health
	health.damaged.connect(_on_health_damaged)
	health.died.connect(_on_health_died)
	
	# Connect detection area signals if detection is enabled
	if enable_detection and detection_area:
		detection_area.area_entered.connect(_on_detection_area_entered)
		detection_area.area_exited.connect(_on_detection_area_exited)
	
	# Start with a wandering target if wandering is enabled
	if enable_wandering:
		choose_wander_target()
	
	# Play idle animation
	if sprite:
		sprite.play("default")
	
	# Initialize intangibility cooldown timer
	intangible_cooldown_timer = intangible_cooldown


# ==============================================================================
# MAIN PHYSICS LOOP
# ==============================================================================

func _physics_process(delta: float) -> void:
	match current_state:
		State.WANDERING:
			update_wandering_state(delta)
		State.HAUNTING:
			update_haunting_state(delta)
		State.INTANGIBLE:
			update_intangible_state(delta)
		State.DEAD:
			pass  # Dead ghosts don't move
	
	# Apply velocity
	velocity = current_velocity
	move_and_slide()


# ==============================================================================
# STATE: WANDERING
# ==============================================================================

func update_wandering_state(delta: float) -> void:
	if not enable_wandering:
		current_velocity = Vector2.ZERO
		return
	
	# Check if player should be detected
	if enable_detection and enable_haunting:
		check_player_detection()
		if player_detected and player:
			enter_haunting_state()
			return
	
	# Move toward wander target
	var direction_to_target = (wander_target - global_position).normalized()
	var target_velocity = direction_to_target * wander_speed
	
	# Apply acceleration
	current_velocity = current_velocity.lerp(target_velocity, acceleration * delta / wander_speed)
	
	# Choose new target if we're close enough
	wander_timer += delta
	if global_position.distance_to(wander_target) < 10.0 or wander_timer >= wander_choose_interval:
		choose_wander_target()
		wander_timer = 0.0


func choose_wander_target() -> void:
	"""Select a random point within the wander radius."""
	var angle = randf_range(0.0, TAU)
	var distance = randf_range(0.0, wander_radius)
	wander_target = global_position + Vector2(cos(angle), sin(angle)) * distance


# ==============================================================================
# STATE: HAUNTING
# ==============================================================================

func update_haunting_state(delta: float) -> void:
	if not enable_haunting:
		current_velocity = Vector2.ZERO
		return
	
	# Validate player reference
	if not player or not is_instance_valid(player):
		player = null
		player_detected = false
		enter_wandering_state()
		return
	
	# Check if player has moved far enough to disengage
	if enable_detection and enable_wandering:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player > disengage_radius:
			enter_wandering_state()
			return
	
	# Calculate haunting behavior
	haunting_movement(delta)


func haunting_movement(delta: float) -> void:
	"""Move toward player while maintaining preferred distance."""
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	var target_velocity = Vector2.ZERO
	
	if distance_to_player > preferred_distance + 5.0:
		# Too far from player, move closer
		target_velocity = direction_to_player * haunt_speed
	elif distance_to_player < preferred_distance - 5.0:
		# Too close to player, move away
		target_velocity = -direction_to_player * haunt_speed * 0.5
	else:
		# At preferred distance, maintain position with slight drift
		target_velocity = Vector2.ZERO
	
	# Apply acceleration for smooth movement
	current_velocity = current_velocity.lerp(target_velocity, acceleration * delta / haunt_speed)


# ==============================================================================
# STATE: INTANGIBLE
# ==============================================================================

func update_intangible_state(delta: float) -> void:
	if not enable_intangibility:
		return
	
	intangible_state_timer += delta
	
	# Apply intangible visual effect
	if sprite:
		sprite.modulate = Color(1, 1, 1, intangible_fade_amount)
	
	# Disable hurtbox to prevent damage
	if hurtbox:
		hurtbox.monitoring = false
	
	# Check if intangible duration has expired
	if intangible_state_timer >= intangible_duration:
		exit_intangible_state()


# ==============================================================================
# STATE TRANSITIONS
# ==============================================================================

func enter_wandering_state() -> void:
	"""Transition to wandering state."""
	if current_state == State.DEAD:
		return
	
	current_state = State.WANDERING
	current_velocity = Vector2.ZERO
	choose_wander_target()
	wander_timer = 0.0
	
	# Restore visual state if coming from intangible
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	if hurtbox:
		hurtbox.monitoring = true


func enter_haunting_state() -> void:
	"""Transition to haunting state."""
	if current_state == State.DEAD:
		return
	
	current_state = State.HAUNTING
	current_velocity = Vector2.ZERO


func enter_intangible_state() -> void:
	"""Transition to intangible state."""
	if current_state == State.DEAD or not enable_intangibility:
		return
	
	if is_intangible:
		return  # Already intangible
	
	current_state = State.INTANGIBLE
	is_intangible = true
	intangible_state_timer = 0.0
	intangible_cooldown_timer = 0.0


func exit_intangible_state() -> void:
	"""Exit intangible state and return to previous behavior."""
	is_intangible = false
	intangible_state_timer = 0.0
	intangible_cooldown_timer = intangible_cooldown
	
	# Restore visual state
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	
	# Re-enable hurtbox
	if hurtbox:
		hurtbox.monitoring = true
	
	# Return to haunting if player is nearby, otherwise wander
	if enable_haunting and enable_detection and player_detected and player:
		current_state = State.HAUNTING
	elif enable_wandering:
		enter_wandering_state()
	else:
		current_state = State.WANDERING


# ==============================================================================
# PLAYER DETECTION
# ==============================================================================

func check_player_detection() -> void:
	"""Check if player is within detection radius."""
	if not player or not is_instance_valid(player):
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= detection_radius and not player_detected:
		player_detected = true


func _on_detection_area_entered(area: Area2D) -> void:
	"""Handle player entering detection area."""
	if not enable_detection:
		return
	
	# Check if the detected area belongs to the player
	if area.is_in_group("player") or area.get_parent().name == "Player" or area.name == "Hitbox":
		player = area.get_parent() if area.get_parent() else area
		player_detected = true


func _on_detection_area_exited(area: Area2D) -> void:
	"""Handle player exiting detection area."""
	# Only clear player reference if no longer close
	if player and (area == player or area.get_parent() == player):
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player > disengage_radius:
			player = null
			player_detected = false


# ==============================================================================
# DAMAGE & HEALTH
# ==============================================================================

func take_damage(damage: int, source = null) -> void:
	"""Handle incoming damage."""
	# Cannot take damage while intangible or dead
	if is_intangible or current_state == State.DEAD:
		return
	
	health.take_damage(damage, source)


func _on_health_damaged(amount: int, new_health: int) -> void:
	"""Handle damage signal from HealthComponent."""
	print_debug("[GhostCovern] Took damage: %d | Health: %d/%d" % [amount, new_health, max_health])
	
	# Visual feedback: sprite flash
	if sprite:
		sprite.modulate = Color(1, 0.5, 0.5, 1)  # Red tint
		await get_tree().create_timer(0.1).timeout
		if sprite and current_state != State.INTANGIBLE:
			sprite.modulate = Color(1, 1, 1, 1)


func _on_health_died() -> void:
	"""Handle death signal from HealthComponent."""
	print_debug("[GhostCovern] Ghost defeated!")
	current_state = State.DEAD
	current_velocity = Vector2.ZERO
	
	# Fade out ghost
	if sprite:
		sprite.modulate = Color(1, 1, 1, 0)


# ==============================================================================
# INTANGIBILITY TIMER (Periodically triggers intangibility)
# ==============================================================================

func _process(delta: float) -> void:
	"""Update intangibility cooldown timer."""
	if not enable_intangibility:
		return
	
	if current_state == State.DEAD:
		return
	
	if is_intangible:
		return  # Currently intangible, don't start another cycle
	
	intangible_cooldown_timer -= delta
	if intangible_cooldown_timer <= 0.0:
		enter_intangible_state()


# ==============================================================================
# UTILITY
# ==============================================================================

func get_state_name() -> String:
	"""Return the current state as a string for debugging."""
	match current_state:
		State.WANDERING:
			return "WANDERING"
		State.HAUNTING:
			return "HAUNTING"
		State.INTANGIBLE:
			return "INTANGIBLE"
		State.DEAD:
			return "DEAD"
	return "UNKNOWN"
