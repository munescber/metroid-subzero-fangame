extends CharacterBody2D

class_name Atomic

# ==============================================================================
# STATE MACHINE
# ==============================================================================

enum State {
	FLOATING,
	CHARGING,
	DASHING,
	RECOVERING,
	ELECTRIC_CHARGING,
	ELECTRIC_FIELD,
	COOLDOWN,
	DEAD
}

var current_state: State = State.FLOATING

# ==============================================================================
# HEALTH & DAMAGE
# ==============================================================================

@export var max_health: int = 10
@export var contact_damage: int = 2
@onready var health_comp: HealthComponent = $HealthComponent

# ==============================================================================
# MOVEMENT & FLOATING
# ==============================================================================

@export_category("Movement")
@export var float_speed: float = 40.0
@export var float_change_interval: float = 3.0

var current_velocity: Vector2 = Vector2.ZERO
var float_target: Vector2 = Vector2.ZERO
var float_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# ==============================================================================
# PLAYER DETECTION
# ==============================================================================

@export_category("Detection")
@export var detection_range: float = 200.0
@export var disengage_range: float = 250.0

var player: Node2D = null
var player_detected: bool = false

# ==============================================================================
# CHARGING & DASH
# ==============================================================================

@export_category("Attack")
@export var charge_duration: float = 0.6
@export var dash_speed: float = 150.0
@export var dash_duration: float = 0.4
@export var dash_cooldown: float = 1.0

var charge_timer: float = 0.0
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var cooldown_timer: float = 0.0

# ==============================================================================
# ELECTRIC FIELD
# ==============================================================================

@export_category("Electric Field")
@export var electric_charge_duration: float = 0.5
@export var electric_field_duration: float = 2.0
@export var electric_field_radius: float = 48.0
@export var electric_field_damage: int = 1
@export var electric_field_cooldown: float = 1.5

var electric_charge_timer: float = 0.0
var electric_field_timer: float = 0.0
var electric_cooldown_timer: float = 0.0
var field_active: bool = false

# ==============================================================================
# VISUAL & ANIMATION
# ==============================================================================

@export_category("Visual")
@export var rotation_speed: float = 1.0
@export var glow_intensity: float = 0.0

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var electric_field_visual: Sprite2D = $ElectricFieldVisual
@onready var electric_field_area: Area2D = $ElectricField
@onready var hurtbox: Area2D = $Hurtbox

# ==============================================================================
# DEBUG
# ==============================================================================

@export var debug_enabled: bool = false

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	# Initialize health component
	health_comp.set_max_health(max_health)
	health_comp.connect("damaged", Callable(self, "_on_health_damaged"))
	health_comp.connect("died", Callable(self, "_on_health_died"))
	
	# Find player
	player = get_tree().get_first_node_in_group("player")
	if not player and debug_enabled:
		push_warning("Atomic: Player not found in 'player' group")
	
	# Setup collision layers
	collision_layer = 4  # EnemyBody
	collision_mask = 1   # World only
	
	# Setup electric field area
	electric_field_area.collision_layer = 8   # Hitbox
	electric_field_area.collision_mask = 16   # Hurtbox
	electric_field_area.connect("area_entered", Callable(self, "_on_electric_field_entered"))
	
	# Setup hurtbox
	hurtbox.collision_layer = 16  # Hurtbox
	hurtbox.collision_mask = 8    # Hitbox
	
	# Start floating behavior
	_choose_new_float_target()
	animated_sprite.play("default")
	electric_field_visual.visible = false
	electric_field_area.set_deferred("monitoring", false)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	# Always apply continuous rotation to visuals (doesn't rotate collision nodes)
	if visuals:
		visuals.rotation += rotation_speed * delta
	
	# Update glow intensity based on state
	_update_glow_intensity(delta)
	
	# State machine
	match current_state:
		State.FLOATING:
			_update_floating(delta)
		State.CHARGING:
			_update_charging(delta)
		State.DASHING:
			_update_dashing(delta)
		State.RECOVERING:
			_update_recovering(delta)
		State.ELECTRIC_CHARGING:
			_update_electric_charging(delta)
		State.ELECTRIC_FIELD:
			_update_electric_field(delta)
		State.COOLDOWN:
			_update_cooldown(delta)
	
	# Apply gravity (but less aggressive for flying enemy)
	if not is_on_floor():
		current_velocity.y += gravity * 0.3 * delta
	else:
		current_velocity.y = 0.0
	
	velocity = current_velocity
	move_and_slide()

# ==============================================================================
# FLOATING STATE
# ==============================================================================

func _update_floating(delta: float) -> void:
	# Detect player
	if player and not player_detected:
		var dist_to_player = global_position.distance_to(player.global_position)
		if dist_to_player < detection_range:
			player_detected = true
			if debug_enabled:
				print("Atomic: Player detected!")
	
	# If player detected and conditions met, start charging
	if player_detected and cooldown_timer <= 0.0:
		_transition_to_state(State.CHARGING)
		return
	
	# Update float behavior
	float_timer -= delta
	
	if float_timer <= 0.0:
		_choose_new_float_target()
		float_timer = float_change_interval
	
	# Move toward float target
	var direction_to_target = (float_target - global_position).normalized()
	current_velocity.x = direction_to_target.x * float_speed
	
	# Small upward float bias to prevent sinking
	if abs(current_velocity.y) < float_speed * 0.5:
		current_velocity.y = -float_speed * 0.3

func _choose_new_float_target() -> void:
	var random_angle = randf() * TAU
	var random_distance = randf_range(50.0, 120.0)
	float_target = global_position + Vector2(cos(random_angle), sin(random_angle)) * random_distance

# ==============================================================================
# CHARGING STATE
# ==============================================================================

func _update_charging(delta: float) -> void:
	# Aim at player
	if player:
		var direction_to_player = (player.global_position - global_position).normalized()
		dash_direction = direction_to_player
	
	# Reduce movement during charge
	current_velocity *= 0.95
	
	# Increase glow as warning
	glow_intensity = min(1.0, glow_intensity + 2.0 * delta)
	
	charge_timer += delta
	if charge_timer >= charge_duration:
		_transition_to_state(State.DASHING)

# ==============================================================================
# DASHING STATE
# ==============================================================================

func _update_dashing(delta: float) -> void:
	current_velocity = dash_direction * dash_speed
	
	dash_timer += delta
	if dash_timer >= dash_duration:
		_transition_to_state(State.RECOVERING)

# ==============================================================================
# RECOVERING STATE
# ==============================================================================

func _update_recovering(delta: float) -> void:
	# Slow down
	current_velocity *= 0.9
	
	cooldown_timer += delta
	if cooldown_timer >= dash_cooldown:
		# Transition to electric field sequence
		_transition_to_state(State.ELECTRIC_CHARGING)

# ==============================================================================
# ELECTRIC CHARGING STATE
# ==============================================================================

func _update_electric_charging(delta: float) -> void:
	current_velocity *= 0.95
	glow_intensity = min(2.0, glow_intensity + 3.0 * delta)
	
	electric_charge_timer += delta
	if electric_charge_timer >= electric_charge_duration:
		_transition_to_state(State.ELECTRIC_FIELD)

# ==============================================================================
# ELECTRIC FIELD STATE
# ==============================================================================

func _update_electric_field(delta: float) -> void:
	current_velocity *= 0.98
	glow_intensity = 2.0
	
	electric_field_timer += delta
	if electric_field_timer >= electric_field_duration:
		_transition_to_state(State.COOLDOWN)

func _on_electric_field_entered(area: Area2D) -> void:
	if not field_active:
		return
	
	# Destroy missiles/projectiles
	if area.is_in_group("projectile") or area.name == "Hitbox":
		if area.get_parent().has_method("take_damage"):
			area.get_parent().queue_free()
		else:
			area.queue_free()

# ==============================================================================
# COOLDOWN STATE
# ==============================================================================

func _update_cooldown(delta: float) -> void:
	current_velocity *= 0.98
	glow_intensity = max(0.0, glow_intensity - 2.0 * delta)
	
	electric_cooldown_timer += delta
	if electric_cooldown_timer >= electric_field_cooldown:
		player_detected = false
		_transition_to_state(State.FLOATING)

# ==============================================================================
# STATE TRANSITIONS
# ==============================================================================

func _transition_to_state(new_state: State) -> void:
	if debug_enabled:
		print("Atomic: Transitioning from %s to %s" % [State.keys()[current_state], State.keys()[new_state]])
	
	current_state = new_state
	
	# Reset timers based on new state
	match new_state:
		State.CHARGING:
			charge_timer = 0.0
		State.DASHING:
			dash_timer = 0.0
		State.RECOVERING:
			cooldown_timer = 0.0
		State.ELECTRIC_CHARGING:
			electric_charge_timer = 0.0
		State.ELECTRIC_FIELD:
			electric_field_timer = 0.0
			field_active = true
			electric_field_area.set_deferred("monitoring", true)
		State.COOLDOWN:
			electric_cooldown_timer = 0.0
			field_active = false
			electric_field_area.set_deferred("monitoring", false)

# ==============================================================================
# GLOW/VISUAL UPDATES
# ==============================================================================

func _update_glow_intensity(_delta: float) -> void:
	# Update electric field visual based on state and glow intensity
	if electric_field_visual:
		electric_field_visual.modulate.a = glow_intensity / 2.0
	
	# Update field collision area size based on glow
	var field_scale = 0.5 + (glow_intensity / 2.0)
	if electric_field_area:
		electric_field_area.scale = Vector2(field_scale, field_scale)

# ==============================================================================
# DAMAGE & DEATH
# ==============================================================================

func take_damage(amount: int, source = null) -> void:
	if current_state == State.DEAD:
		return
	
	# Missiles cannot damage during electric field
	if field_active and source and source.is_in_group("projectile"):
		return
	
	health_comp.take_damage(amount, source)

func _on_health_damaged(amount: int, new_health: int) -> void:
	if debug_enabled:
		print("Atomic: Took %d damage! Health: %d/%d" % [amount, new_health, max_health])

func _on_health_died() -> void:
	if debug_enabled:
		print("Atomic: Died!")
	_transition_to_state(State.DEAD)
	
	# Disable collision and visibility
	collision_layer = 0
	collision_mask = 0
	electric_field_area.set_deferred("monitoring", false)
	
	# TODO: Add death animation/effects
	queue_free()
