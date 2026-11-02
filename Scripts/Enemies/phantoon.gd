extends CharacterBody2D

class_name Phantoon

# Debug toggle
@export var debug_enabled: bool = false
## Stable id so the boss stays defeated after saving.
@export var save_id: String = ""

# Feature Toggles (disable specific attacks/states for testing)
@export_category("Feature Toggles")
@export var enable_dash: bool = true
@export var enable_burst_attack: bool = true
@export var enable_bounce_attack: bool = true
@export var enable_intangibility: bool = true

# Boss states. Intangibility is not a state: it is an overlay (is_intangible) on top of ORBIT,
# so the boss keeps orbiting while phased out and never gets cut off mid-attack.
enum BossState { ORBIT, PAUSE, DASH, ATTACK_WINDUP, ATTACK_BURST, ATTACK_BOUNCE, DEAD }

# Current state
var current_state: BossState = BossState.ORBIT

# Attacks run as a fixed, learnable sequence per phase (see _next_attack)
enum AttackType { BURST, BOUNCE }
const PHASE_1_ATTACK_SEQUENCE := [AttackType.BURST, AttackType.BURST, AttackType.BOUNCE]
const PHASE_2_ATTACK_SEQUENCE := [AttackType.BURST, AttackType.BOUNCE]
var attack_index: int = 0
var pending_attack: int = AttackType.BURST

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
@export var dash_duration: float = 0.5  # Safety cap: the dash ends after this even if it hasn't arrived
@export var dash_speed: float = 200.0
@export var attack_telegraph_duration: float = 0.4  # Windup glow before an attack spawns
@export var show_dash_marker: bool = true  # Ring + path line at the dash target
var dash_target: Vector2 = Vector2.ZERO

# References
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var damage_flash_timer: Timer = $DamageFlashTimer
@onready var contact_damage: Node = $ContactDamage
@onready var hurtbox: Area2D = $Hurtbox

# Contact damage configuration
@export var contact_damage_value: int = 1

# Attack timing
var attack_timer: float = 0.0
@export var orbit_duration: float = 3.0  # How long to orbit before pausing

# Intangible configuration (defensive: the boss phases out and keeps orbiting, no attacks)
@export var intangible_interval: float = 15.0  # Tangible time between intangible phases
@export var intangible_duration: float = 3.0  # How long intangible state lasts
@export var intangible_warning_duration: float = 0.5  # Flicker before phasing out
@export var intangible_fade_amount: float = 0.5  # 0.0 = invisible, 1.0 = visible
var is_intangible: bool = false
var intangible_timer: float = 0.0
var intangible_state_timer: float = 0.0
var intangible_warning_timer: float = 0.0

# Attack configuration (Stage 8 & 9)
@export var burst_projectile_count: int = 6  # Phase 1 burst size
@export var phase_2_burst_count: int = 8  # Phase 2 burst size: one every 45 degrees
@export var burst_spawn_offset: float = 24.0  # Distance from boss center each burst projectile spawns at
@export var phase_1_burst_speed: float = 100.0
@export var phase_2_burst_speed: float = 150.0
@export var phase_1_burst_rotation: float = 0.0
@export var phase_2_burst_rotation: float = -PI / 2.0  # Straight up: the first projectile is at 0 degrees, then every 45
@export var phase_1_bounce_count: int = 6
@export var phase_2_bounce_count: int = 8
@export var bounce_spawn_height: float = 40.0  # How far above the boss the fireball curtain spawns
@export var bounce_spacing: float = 20.0  # Horizontal distance between fireballs in the curtain
@export var bounce_horizontal_drift: float = 50.0  # Max random sideways speed (px/s) when a fireball falls; 0 = straight down
@export var burst_hold_duration: float = 0.5  # Seconds the burst ring hovers before every projectile launches at once
@export var bounce_gravity: float = 300.0
@export var bounce_release_delay: float = 0.12  # Seconds between each fireball starting to fall (the curtain sweep)
var bounce_sweep_direction: float = 1.0  # 1.0 = left to right, -1.0 = right to left; flips every cast

# Death drops: guaranteed, not rolled. They scatter horizontally around the boss.
@export_category("Death Drops")
@export var death_health_drops: int = 10
@export var death_missile_drops: int = 10
@export var death_drop_spread: float = 48.0  # Max horizontal scatter in pixels
@export var death_drop_lifetime: float = 20.0  # Seconds the pickups stay (the usual drop time is shorter)

# Visual feedback
const DAMAGE_FLASH_COLOR := Color(1, 0.5, 0.5, 1)
const PHASE_FLASH_COLOR := Color(2, 2, 2, 1)
const PHASE_FLASH_DURATION: float = 0.2
const WINDUP_COLOR := Color(1.6, 1.2, 0.6, 1)  # Warm yellow glow before any attack
const FIREBALL_WALL_MARGIN: float = 8.0  # Gap kept between a fireball spawn point and a wall or ceiling
const FIREBALL_MIN_SPAWN_DISTANCE: float = 14.0  # Closer to the boss than this, a blocked fireball is skipped
const DASH_MARKER_COLOR := Color(1, 1, 1, 0.8)
var phase_flash_timer: float = 0.0
var _dash_marker_visible: bool = false

# Layer captured at _ready so intangibility can be undone exactly
var _body_layer: int = 0

# Death state
var is_dying: bool = false
var death_timer: float = 0.0
var death_duration: float = 0.5  # Time to fade out


func _ready() -> void:
	_body_layer = collision_layer
	if save_id != "":
		add_to_group("saveable")

	# Initialize health
	health.max_health = max_health
	health.current_health = max_health

	# Orbit angle 0 puts the boss at the right of the ring, so place the ring's center such that
	# the boss's spawn position is already on it (otherwise the first frame teleports it)
	orbit_angle = 0.0
	arena_center = global_position - Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius

	# Connect health signals
	health.damaged.connect(_on_health_damaged)
	health.died.connect(_on_health_died)

	# Configure contact damage (hitting the player)
	if contact_damage and contact_damage.has_method("set"):
		contact_damage.set("damage", contact_damage_value)
		contact_damage.set("one_shot", false)  # Continuous damage, not one-shot
		contact_damage.set("source", self)

	# Start animation
	if sprite != null:
		sprite.play("idle")

	# Initialize timers
	intangible_timer = 0.0
	intangible_state_timer = 0.0
	intangible_warning_timer = 0.0

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
	# Handle death animation
	if is_dying:
		death_timer += delta
		if death_timer >= death_duration:
			queue_free()
			return
	else:
		_update_intangibility(delta)

	# Handle attack timer (triggers pause/dash cycle). Held while phasing out or phased out so
	# intangibility never overlaps an attack.
	if current_state == BossState.ORBIT and not _is_holding_attacks():
		attack_timer += delta
		if attack_timer >= orbit_duration:
			# Transition to pause. The dash target is fixed now so the marker can show it.
			current_state = BossState.PAUSE
			attack_timer = 0.0
			state_timer = 0.0
			dash_target = _opposite_orbit_point()

	match current_state:
		BossState.ORBIT:
			update_orbit_movement(delta)
		BossState.PAUSE:
			update_pause_state(delta)
		BossState.DASH:
			update_dash_movement(delta)
		BossState.ATTACK_WINDUP:
			update_attack_windup_state(delta)
		BossState.ATTACK_BURST:
			update_attack_burst_state(delta)
		BossState.ATTACK_BOUNCE:
			update_attack_bounce_state(delta)
		BossState.DEAD:
			pass  # Boss stays still when dead

	# Update sprite flip based on movement direction
	update_sprite_direction()
	_update_visuals(delta)


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
		if not enable_dash:
			# Skip the dash entirely and attack from the current position
			state_timer = 0.0
			perform_attack_selection()
			return
		# Transition to dash (toward the target picked when the pause began)
		current_state = BossState.DASH
		state_timer = 0.0
		# Reverse orbit direction for next orbit
		orbit_direction *= -1.0


## The point on the orbit ring directly opposite the boss: a constant-length, predictable dash.
func _opposite_orbit_point() -> Vector2:
	return arena_center - (global_position - arena_center)


func update_dash_movement(delta: float) -> void:
	state_timer += delta

	# Constant-speed dash toward the target
	global_position = global_position.move_toward(dash_target, dash_speed * delta)

	if global_position.is_equal_approx(dash_target) or state_timer >= dash_duration:
		perform_attack_selection()


func perform_attack_selection() -> void:
	"""Pick the next attack from the sequence and start its windup, or return to orbit if no attack is enabled."""
	orbit_angle = (global_position - arena_center).angle()

	var next_attack := _next_attack()
	if next_attack < 0:
		# No attacks enabled, just return to orbit
		current_state = BossState.ORBIT
		state_timer = 0.0
		attack_timer = 0.0
		return

	pending_attack = next_attack
	current_state = BossState.ATTACK_WINDUP
	state_timer = 0.0
	attack_timer = 0.0  # Reset attack timer for next orbit cycle


## Phase 1: burst, burst, bounce, repeat. Phase 2: burst, bounce, repeat. If only one attack is
## enabled it is always used; returns -1 when none are.
func _next_attack() -> int:
	if not enable_burst_attack and not enable_bounce_attack:
		return -1
	if not enable_bounce_attack:
		return AttackType.BURST
	if not enable_burst_attack:
		return AttackType.BOUNCE

	var sequence := PHASE_1_ATTACK_SEQUENCE if phase == 1 else PHASE_2_ATTACK_SEQUENCE
	var attack: int = sequence[attack_index % sequence.size()]
	attack_index += 1
	return attack


## Holds still and glows so the attack can be read before it spawns.
func update_attack_windup_state(delta: float) -> void:
	state_timer += delta
	if state_timer < attack_telegraph_duration:
		return

	if pending_attack == AttackType.BOUNCE:
		spawn_bounce_attack()
		current_state = BossState.ATTACK_BOUNCE
	else:
		spawn_burst_attack()
		current_state = BossState.ATTACK_BURST
	state_timer = 0.0


# ============================================================================
# Intangibility (overlay; defensive: orbits only, no attacks)
# ============================================================================

## True while the boss is flickering before phasing out or is phased out. Attacks don't start then.
func _is_holding_attacks() -> bool:
	return is_intangible or intangible_warning_timer > 0.0


func _update_intangibility(delta: float) -> void:
	if not enable_intangibility or current_state == BossState.DEAD:
		return

	if is_intangible:
		intangible_state_timer += delta
		if intangible_state_timer >= intangible_duration:
			exit_intangible_state()
		return

	if intangible_warning_timer > 0.0:
		intangible_warning_timer -= delta
		if intangible_warning_timer <= 0.0:
			enter_intangible_state()
		return

	# The interval only counts tangible time. Phasing waits for ORBIT so it never cuts an attack off.
	intangible_timer += delta
	if intangible_timer >= intangible_interval and current_state == BossState.ORBIT:
		if intangible_warning_duration > 0.0:
			intangible_warning_timer = intangible_warning_duration
		else:
			enter_intangible_state()


func enter_intangible_state() -> void:
	if debug_enabled:
		print_debug("[Phantoon] Entering intangible state!")
	is_intangible = true
	intangible_state_timer = 0.0
	intangible_warning_timer = 0.0
	_set_phased(true)


func exit_intangible_state() -> void:
	if debug_enabled:
		print_debug("[Phantoon] Exiting intangible state!")
	is_intangible = false
	intangible_state_timer = 0.0
	intangible_timer = 0.0  # Next phase-out is a full interval away
	_set_phased(false)


## Toggles every way the boss can touch the world. Hurtbox `monitorable` is the important one:
## projectiles find the hurtbox by overlapping it, which depends on monitorable, not monitoring.
func _set_phased(phased: bool) -> void:
	set_deferred("collision_layer", 0 if phased else _body_layer)
	if hurtbox:
		hurtbox.set_deferred("monitorable", not phased)
		hurtbox.set_deferred("monitoring", not phased)
	if contact_damage:
		contact_damage.set_deferred("monitoring", not phased)
		contact_damage.set_deferred("monitorable", not phased)


# ============================================================================
# Attack Methods (Stage 8 & 9)
# ============================================================================

func update_attack_burst_state(delta: float) -> void:
	state_timer += delta
	# Stay in attack state for 1 second (longer if the ring is held longer), then return to orbit
	if state_timer >= maxf(1.0, burst_hold_duration + 0.3):
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


func _current_burst_count() -> int:
	return burst_projectile_count if phase == 1 else phase_2_burst_count


func spawn_burst_attack() -> void:
	if debug_enabled:
		print_debug("[Phantoon] Spawning radial burst attack!")

	if radial_projectile_scene == null:
		if debug_enabled:
			print_debug("[Phantoon] ERROR: radial_projectile_scene not loaded. Skipping attack.")
		return

	var projectile_speed = phase_1_burst_speed if phase == 1 else phase_2_burst_speed
	var rotation_offset = phase_1_burst_rotation if phase == 1 else phase_2_burst_rotation
	var count = _current_burst_count()
	var angle_step = TAU / count

	for i in range(count):
		var angle = (i * angle_step) + rotation_offset
		var direction = Vector2(cos(angle), sin(angle))

		# Spawn projectile just outside the boss's own sprite/collision
		var projectile = radial_projectile_scene.instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = global_position + direction * burst_spawn_offset

		# Configure projectile. The whole ring spawns now, held pointing outward, and every
		# projectile launches together once the hold ends, so the player can see where they will come from.
		if projectile.has_method("launch"):
			projectile.launch(direction, projectile_speed, self, burst_hold_duration)
		elif projectile.has_method("start"):
			projectile.start(direction, self)


func spawn_bounce_attack() -> void:
	if debug_enabled:
		print_debug("[Phantoon] Spawning bouncing fireball attack!")

	if bounce_projectile_scene == null:
		if debug_enabled:
			print_debug("[Phantoon] ERROR: bounce_projectile_scene not loaded. Skipping attack.")
		return

	var fireball_count = phase_1_bounce_count if phase == 1 else phase_2_bounce_count

	# Create evenly spaced spawn points above the boss, forming a curtain
	# For example, if fireball_count = 5 and bounce_spacing = 20, they spawn at: -40, -20, 0, +20, +40 horizontally
	var spacing = bounce_spacing
	var start_offset = -(fireball_count - 1) * spacing / 2.0  # Center the pattern
	var space_state = get_world_2d().direct_space_state

	for i in range(fireball_count):
		# Calculate horizontal offset for this fireball
		var offset_x = start_offset + (i * spacing)
		var spawn_pos = global_position + Vector2(offset_x, -bounce_spawn_height)

		# A ceiling or wall between the boss and this spot would destroy the fireball on its first
		# move (a non-floor collision), so pull it back from whatever is in the way, or skip it.
		var ray = PhysicsRayQueryParameters2D.create(global_position, spawn_pos, 1)  # World layer
		var blocked = space_state.intersect_ray(ray)
		if not blocked.is_empty():
			var toward_spawn = (spawn_pos - global_position).normalized()
			spawn_pos = blocked.position - toward_spawn * FIREBALL_WALL_MARGIN
			if global_position.distance_to(spawn_pos) < FIREBALL_MIN_SPAWN_DISTANCE:
				continue

		var fireball = bounce_projectile_scene.instantiate()
		get_parent().add_child(fireball)
		fireball.global_position = spawn_pos

		# Configure fireball
		if fireball.has_method("setup"):
			# All fireballs spawn now; each starts falling after its turn in the sweep
			var sweep_order = i if bounce_sweep_direction > 0.0 else fireball_count - 1 - i
			fireball.setup(bounce_gravity, bounce_horizontal_drift, self, sweep_order * bounce_release_delay)

	# Next cast sweeps the other way so the player can't just wait on one side
	bounce_sweep_direction *= -1.0


# ============================================================================
# Health & Damage Methods
# ============================================================================

func take_damage(damage: int, source = null) -> void:
	# Backstop: the hurtbox is already unreachable while intangible
	if is_intangible or current_state == BossState.DEAD:
		return

	health.take_damage(damage, source)
	check_phase_transition()


func check_phase_transition() -> void:
	# The hit that triggers death must not also start phase 2
	if current_state == BossState.DEAD or is_dying:
		return
	if phase == 1 and not phase_2_triggered:
		if health.current_health <= max_health / 2.0:
			enter_phase_2()


func enter_phase_2() -> void:
	phase = 2
	phase_2_triggered = true
	if debug_enabled:
		print_debug("[Phantoon] Entering Phase 2!")

	# Phase 2 modifications: Faster and more aggressive
	orbit_speed *= 1.5  # Faster orbit
	pause_duration *= 0.75  # Shorter pauses
	orbit_duration *= 0.8  # Attacks more frequently
	intangible_interval *= 0.75  # Phases out more often
	attack_index = 0  # Phase 2 starts its own attack sequence from the top

	# Visual feedback for phase transition: brief white flash (drawn by _update_visuals)
	phase_flash_timer = PHASE_FLASH_DURATION


# ============================================================================
# Signal Handlers
# ============================================================================

func _on_health_damaged(amount: int, new_health: int) -> void:
	if debug_enabled:
		print_debug("[Phantoon] Took damage: ", amount, " | Health: ", new_health, "/", max_health)
	# Visual feedback: red tint while the flash timer runs (drawn by _update_visuals)
	damage_flash_timer.start(0.12)


## A defeated boss removes itself, so it reports through SaveManager.set_flag() instead.
func get_save_data() -> Dictionary:
	return {}

func load_save_data(data: Dictionary) -> void:
	if data.get("defeated", false):
		queue_free()


func _on_health_died() -> void:
	if save_id != "":
		SaveManager.set_flag(save_id, {"defeated": true})
	DropManager.drop_guaranteed(self, death_health_drops, death_missile_drops, death_drop_spread, death_drop_lifetime)
	if debug_enabled:
		print_debug("[Phantoon] Boss defeated!")
	is_dying = true
	is_intangible = false
	intangible_warning_timer = 0.0
	current_state = BossState.DEAD
	death_timer = 0.0

	# Disable collisions immediately
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
		elif child is Area2D:
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)


# ============================================================================
# Utility Methods
# ============================================================================

func update_sprite_direction() -> void:
	if sprite != null:
		# Flip sprite based on orbit direction
		sprite.flip_h = orbit_direction < 0


## Single place that decides the sprite's colour each frame, so the damage flash, the phase flash,
## intangibility and the death fade can't overwrite each other.
func _update_visuals(delta: float) -> void:
	if sprite == null:
		return

	if phase_flash_timer > 0.0:
		phase_flash_timer -= delta

	var color := Color.WHITE
	if current_state == BossState.ATTACK_WINDUP:
		# Glow ramps up over the windup
		var windup_progress := clampf(state_timer / maxf(attack_telegraph_duration, 0.001), 0.0, 1.0)
		color = Color.WHITE.lerp(WINDUP_COLOR, windup_progress)
	if phase_flash_timer > 0.0:
		color = PHASE_FLASH_COLOR
	if damage_flash_timer.time_left > 0.0:
		color = DAMAGE_FLASH_COLOR

	if is_intangible:
		color.a = intangible_fade_amount
	elif intangible_warning_timer > 0.0:
		# Flicker as a warning that it's about to phase out
		color.a = intangible_fade_amount if int(Time.get_ticks_msec() / 80.0) % 2 == 0 else 1.0

	if is_dying:
		color.a = lerpf(1.0, 0.0, clampf(death_timer / death_duration, 0.0, 1.0))

	sprite.modulate = color

	# Redraw the dash marker while it shows, and once more when it should disappear
	var show_marker := _should_show_dash_marker()
	if show_marker or _dash_marker_visible:
		queue_redraw()
	_dash_marker_visible = show_marker


func _should_show_dash_marker() -> bool:
	return enable_dash and show_dash_marker and not is_dying and (current_state == BossState.PAUSE or current_state == BossState.DASH)


## Dash telegraph: a ring at the dash target and a faint line along the path, shown from the start
## of the pause until the boss arrives.
func _draw() -> void:
	if not _should_show_dash_marker():
		return
	var target_local := to_local(dash_target)
	draw_line(Vector2.ZERO, target_local, Color(DASH_MARKER_COLOR, 0.25), 1.0)
	draw_arc(target_local, 8.0, 0.0, TAU, 24, DASH_MARKER_COLOR, 1.5)
