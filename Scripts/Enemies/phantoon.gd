extends CharacterBody2D

class_name Phantoon

# Boss states
enum BossState { ORBIT, PAUSE, DASH, ATTACK_BURST, ATTACK_BOUNCE, INTANGIBLE, DEAD }

# Current state
var current_state: BossState = BossState.ORBIT

# Projectile scenes (lazy loaded)
var radial_projectile_scene: PackedScene = null
var bounce_projectile_scene: PackedScene = null

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

# Intangible state configuration
@export var intangible_interval: float = 15.0  # How often boss goes intangible
@export var intangible_duration: float = 3.0  # How long intangible state lasts
var intangible_timer: float = 0.0
var intangible_state_timer: float = 0.0

# Attack configuration (Stage 8 & 9)
@export var burst_projectile_count: int = 6
@export var phase_1_burst_speed: float = 100.0
@export var phase_2_burst_speed: float = 150.0
@export var phase_1_burst_rotation: float = 0.0
@export var phase_2_burst_rotation: float = 0.523599  # 30 degrees in radians
@export var phase_1_bounce_count: int = 4
@export var phase_2_bounce_count: int = 6
@export var bounce_projectile_speed: float = 50.0
@export var bounce_gravity: float = 300.0

# Hurtbox reference (for intangible state)
@onready var hurtbox: Area2D = $Hurtbox


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
	
	# Initialize timers
	intangible_timer = 0.0
	intangible_state_timer = 0.0
	
	# Lazy load projectile scenes
	if radial_projectile_scene == null:
		radial_projectile_scene = load("res://Scenes/Projectiles/radial_projectile.tscn")
		if radial_projectile_scene == null:
			print_debug("[Phantoon] WARNING: Could not load radial_projectile.tscn")
	
	if bounce_projectile_scene == null:
		bounce_projectile_scene = load("res://Scenes/Projectiles/bouncing_fireball.tscn")
		if bounce_projectile_scene == null:
			print_debug("[Phantoon] WARNING: Could not load bouncing_fireball.tscn")


func _physics_process(delta: float) -> void:
	# Handle attack timer (triggers pause/dash cycle)
	if current_state == BossState.ORBIT:
		attack_timer += delta
		if attack_timer >= orbit_duration:
			# Transition to pause
			current_state = BossState.PAUSE
			attack_timer = 0.0
			state_timer = 0.0
	
	# Handle intangible scheduling (all states except dead)
	if current_state != BossState.DEAD:
		intangible_timer += delta
		if intangible_timer >= intangible_interval and current_state != BossState.INTANGIBLE:
			enter_intangible_state()
	
	match current_state:
		BossState.ORBIT:
			update_orbit_movement(delta)
		BossState.PAUSE:
			update_pause_state(delta)
		BossState.DASH:
			update_dash_movement(delta)
		BossState.ATTACK_BURST:
			update_attack_burst_state(delta)
		BossState.ATTACK_BOUNCE:
			update_attack_bounce_state(delta)
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
		# After dash, trigger an attack
		orbit_angle = (dash_target - arena_center).angle()
		
		# Alternate between burst and bounce attacks
		# Phase 1: Mostly bursts with occasional bounces (30% chance bounce)
		# Phase 2: More balanced (50% chance bounce)
		var bounce_chance = 0.3 if phase == 1 else 0.5
		
		if randf() < bounce_chance:
			spawn_bounce_attack()
			current_state = BossState.ATTACK_BOUNCE
		else:
			spawn_burst_attack()
			current_state = BossState.ATTACK_BURST
		
		state_timer = 0.0
		attack_timer = 0.0  # Reset attack timer for next orbit cycle


func update_intangible_state(delta: float) -> void:
	intangible_state_timer += delta
	
	# Boss becomes translucent and cannot take damage
	if sprite != null:
		# Fade the sprite to semi-transparent
		sprite.modulate = Color(1, 1, 1, 0.5)
	
	# Disable the hurtbox so damage cannot be applied
	if hurtbox != null:
		hurtbox.monitoring = false
	
	# Check if intangible duration has elapsed
	if intangible_state_timer >= intangible_duration:
		# Exit intangible state and return to orbit
		exit_intangible_state()


func enter_intangible_state() -> void:
	print_debug("[Phantoon] Entering intangible state!")
	current_state = BossState.INTANGIBLE
	intangible_state_timer = 0.0
	intangible_timer = 0.0  # Reset intangible timer for next cycle


func exit_intangible_state() -> void:
	print_debug("[Phantoon] Exiting intangible state!")
	# Restore opacity
	if sprite != null:
		sprite.modulate = Color(1, 1, 1, 1)
	
	# Re-enable the hurtbox
	if hurtbox != null:
		hurtbox.monitoring = true
	
	# Return to orbit state
	current_state = BossState.ORBIT
	attack_timer = 0.0
	intangible_state_timer = 0.0


# ============================================================================
# Attack Methods (Stage 8 & 9)
# ============================================================================

func update_attack_burst_state(delta: float) -> void:
	state_timer += delta
	# Stay in attack state for 1 second, then return to orbit
	if state_timer >= 1.0:
		current_state = BossState.ORBIT
		state_timer = 0.0
		attack_timer = 0.0


func update_attack_bounce_state(delta: float) -> void:
	state_timer += delta
	# Stay in attack state for 2 seconds, then return to orbit
	if state_timer >= 2.0:
		current_state = BossState.ORBIT
		state_timer = 0.0
		attack_timer = 0.0


func spawn_burst_attack() -> void:
	print_debug("[Phantoon] Spawning radial burst attack!")
	
	if radial_projectile_scene == null:
		print_debug("[Phantoon] ERROR: radial_projectile_scene not loaded. Skipping attack.")
		return
	
	var projectile_speed = phase_1_burst_speed if phase == 1 else phase_2_burst_speed
	var rotation_offset = phase_1_burst_rotation if phase == 1 else phase_2_burst_rotation
	var angle_step = TAU / burst_projectile_count
	
	for i in range(burst_projectile_count):
		var angle = (i * angle_step) + rotation_offset
		var direction = Vector2(cos(angle), sin(angle))
		
		# Spawn projectile
		var projectile = radial_projectile_scene.instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = global_position
		
		# Configure projectile
		if projectile.has_method("launch"):
			projectile.launch(direction, projectile_speed, self)
		elif projectile.has_method("start"):
			projectile.start(direction, self)


func spawn_bounce_attack() -> void:
	print_debug("[Phantoon] Spawning bouncing fireball attack!")
	
	if bounce_projectile_scene == null:
		print_debug("[Phantoon] ERROR: bounce_projectile_scene not loaded. Skipping attack.")
		return
	
	var fireball_count = phase_1_bounce_count if phase == 1 else phase_2_bounce_count
	
	# Create evenly spaced spawn points below the boss
	# For example, if fireball_count = 5, they spawn at: -40, -20, 0, +20, +40 units horizontally
	var spacing = 20.0  # Distance between each fireball
	var start_offset = -(fireball_count - 1) * spacing / 2.0  # Center the pattern
	
	for i in range(fireball_count):
		# Calculate horizontal offset for this fireball
		var offset_x = start_offset + (i * spacing)
		var spawn_pos = global_position + Vector2(offset_x, 40.0)
		
		var fireball = bounce_projectile_scene.instantiate()
		get_parent().add_child(fireball)
		fireball.global_position = spawn_pos
		
		# Configure fireball
		if fireball.has_method("setup"):
			fireball.setup(bounce_gravity, bounce_projectile_speed)


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
	
	# Phase 2 modifications: Faster and more aggressive
	orbit_speed *= 1.5  # Faster orbit
	pause_duration *= 0.75  # Shorter pauses
	orbit_duration *= 0.8  # Attacks more frequently
	
	# Visual feedback for phase transition
	if sprite != null:
		# Briefly flash white to indicate phase change
		sprite.modulate = Color(2, 2, 2, 1)
		await get_tree().create_timer(0.2).timeout
		sprite.modulate = Color(1, 1, 1, 1)


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
