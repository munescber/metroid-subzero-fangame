extends CharacterBody2D

class_name Phantoon

# Boss states
enum BossState { ORBIT, PAUSE, DASH, ATTACK_BURST, ATTACK_BOUNCE, INTANGIBLE, DEAD }

# Current state
var current_state: BossState = BossState.ORBIT

# Movement configuration
@export var arena_center: Vector2 = Vector2.ZERO
@export var orbit_radius: float = 40.0
@export var orbit_speed: float = 1.5
var orbit_direction: float = 1.0  # 1.0 = clockwise, -1.0 = counter-clockwise
var orbit_angle: float = 0.0

# Health configuration
@export var max_health: int = 100
var phase: int = 1
var phase_2_triggered: bool = false

# State timers
var state_timer: float = 0.0
@export var pause_duration: float = 1.0
@export var dash_duration: float = 0.5
@export var dash_speed: float = 200.0
var dash_target: Vector2 = Vector2.ZERO

# References
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var damage_flash_timer: Timer = $DamageFlashTimer
@onready var contact_damage: Node = $ContactDamage

# Contact damage configuration
@export var contact_damage_value: int = 1

# Attack timing
var attack_timer: float = 0.0
@export var orbit_duration: float = 3.0  # How long to orbit before pausing


func _ready() -> void:
	# Initialize health
	health.max_health = max_health
	health.current_health = max_health
	
	# Set arena center to current position
	arena_center = global_position
	
	# Connect health signals
	health.damaged.connect(_on_health_damaged)
	health.died.connect(_on_health_died)
	
	# Connect damage flash timer
	damage_flash_timer.timeout.connect(_on_damage_flash_timer_timeout)
	
	# Configure contact damage (hitting the player)
	if contact_damage and contact_damage.has_method("set"):
		contact_damage.set("damage", contact_damage_value)
		contact_damage.set("one_shot", false)  # Continuous damage, not one-shot
		contact_damage.set("source", self)
	
	# Start animation
	if sprite != null:
		sprite.play("idle")
	
	# Initialize orbit angle to current position
	orbit_angle = 0.0


func _physics_process(delta: float) -> void:
	# Handle attack timer (triggers pause/dash cycle)
	if current_state == BossState.ORBIT:
		attack_timer += delta
		if attack_timer >= orbit_duration:
			# Transition to pause
			current_state = BossState.PAUSE
			attack_timer = 0.0
			state_timer = 0.0
	
	match current_state:
		BossState.ORBIT:
			update_orbit_movement(delta)
		BossState.PAUSE:
			update_pause_state(delta)
		BossState.DASH:
			update_dash_movement(delta)
		BossState.ATTACK_BURST:
			pass  # Attacks handled separately, boss stays still
		BossState.ATTACK_BOUNCE:
			pass  # Attacks handled separately, boss stays still
		BossState.INTANGIBLE:
			update_intangible_state(delta)
		BossState.DEAD:
			pass  # Boss stays still when dead
	
	# Update sprite flip based on movement direction
	update_sprite_direction()


# ============================================================================
# Movement Methods
# ============================================================================

func update_orbit_movement(delta: float) -> void:
	orbit_angle += orbit_speed * delta * orbit_direction
	var offset = Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
	global_position = arena_center + offset


func update_pause_state(delta: float) -> void:
	state_timer += delta
	if state_timer >= pause_duration:
		# Transition to dash
		current_state = BossState.DASH
		state_timer = 0.0
		# Pick a random point on the orbit to dash to
		var random_angle = randf_range(0.0, TAU)
		dash_target = arena_center + Vector2(cos(random_angle), sin(random_angle)) * orbit_radius
		# Reverse orbit direction for next orbit
		orbit_direction *= -1.0


func update_dash_movement(delta: float) -> void:
	state_timer += delta
	var progress = min(state_timer / dash_duration, 1.0)
	
	# Interpolate from current position to dash target
	global_position = global_position.lerp(dash_target, progress)
	
	if progress >= 1.0:
		# Transition back to orbit
		orbit_angle = (dash_target - arena_center).angle()
		current_state = BossState.ORBIT
		state_timer = 0.0
		attack_timer = 0.0  # Reset attack timer for next orbit cycle


func update_intangible_state(delta: float) -> void:
	# Boss can still orbit while intangible for now
	# This can be changed later if needed
	update_orbit_movement(delta)


# ============================================================================
# Health & Damage Methods
# ============================================================================

func take_damage(damage: int, source = null) -> void:
	# Cannot take damage while intangible or dead
	if current_state == BossState.INTANGIBLE or current_state == BossState.DEAD:
		return
	
	health.take_damage(damage, source)
	check_phase_transition()


func check_phase_transition() -> void:
	if phase == 1 and not phase_2_triggered:
		if health.current_health <= max_health / 2:
			enter_phase_2()


func enter_phase_2() -> void:
	phase = 2
	phase_2_triggered = true
	print_debug("[Phantoon] Entering Phase 2!")
	# Phase 2 modifications will happen here later
	# - Faster orbit
	# - Faster attacks
	# - More projectiles


# ============================================================================
# Signal Handlers
# ============================================================================

func _on_health_damaged(amount: int, new_health: int) -> void:
	print_debug("[Phantoon] Took damage: ", amount, " | Health: ", new_health, "/", max_health)
	# Visual feedback: sprite flash red briefly
	if sprite != null:
		sprite.modulate = Color(1, 0.5, 0.5, 1)  # Red tint
		damage_flash_timer.start(0.12)  # Flash duration


func _on_health_died() -> void:
	print_debug("[Phantoon] Boss defeated!")
	current_state = BossState.DEAD
	# Death behavior can be added here later
	# For now, just stop moving


# ============================================================================
# Utility Methods
# ============================================================================

func update_sprite_direction() -> void:
	if sprite != null:
		# Flip sprite based on orbit direction
		sprite.flip_h = orbit_direction < 0


func _on_damage_flash_timer_timeout() -> void:
	# Reset sprite modulation after damage flash
	if sprite != null:
		sprite.modulate = Color(1, 1, 1, 1)
