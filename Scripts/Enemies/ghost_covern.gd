extends CharacterBody2D

class_name GhostCovern

# Debug toggle
@export var debug_enabled: bool = false

# ==============================================================================
# STATE MACHINE
# ==============================================================================
# Intangibility is an overlay on top of WANDERING/HAUNTING (see is_intangible), not a
# state of its own, so the ghost keeps moving and chasing while it phases out.

enum State {
	WANDERING,
	HAUNTING,
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
@export var haunt_smoothing: float = 4.0  # How quickly the chase velocity catches up to the player direction
@export var wander_radius: float = 150.0  # How far from starting position to wander
@export var preferred_distance: float = 20.0  # Hover distance from the player while haunting (contact radius is ~15)
@export var standoff_slow_range: float = 40.0  # Distance over which it eases down to a stop near preferred_distance
@export var standoff_deadzone: float = 6.0  # Closer than preferred_distance minus this, it drifts back out

@export_category("Crowding")
@export var separation_radius: float = 28.0  # Other ghosts closer than this push this ghost away
@export var separation_strength: float = 45.0  # Max push speed (px/s) when another ghost is fully overlapping
@export var hover_angle_drift: float = 0.4  # Radians/sec the ghost's hover spot orbits the player (direction is random per ghost)

# Movement state
var current_velocity: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var wander_choose_interval: float = 2.0  # Time between choosing new targets

# Each ghost hovers at its own spot on a ring around the player so several ghosts spread out
var hover_angle: float = 0.0
var hover_drift_dir: float = 1.0

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
@export var contact_damage_value: int = 1

## Optional drop override; empty uses the default DropManager table.
@export var drop_table: DropTable

# Damage flash
const FLASH_DURATION: float = 0.1
const FLASH_COLOR := Color(1, 0.5, 0.5, 1)
var flash_timer: float = 0.0

# Death animation
var is_dying: bool = false
var death_timer: float = 0.0
var death_duration: float = 0.5  # Time to fade out

# ==============================================================================
# NODE REFERENCES
# ==============================================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Area2D = $Hurtbox
@onready var contact_damage: Node = $ContactDamage

# Layers captured at _ready so intangibility can be undone exactly
var _body_layer: int = 0

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_body_layer = collision_layer
	add_to_group("ghost_covern")
	hover_angle = randf_range(0.0, TAU)
	hover_drift_dir = 1.0 if randf() < 0.5 else -1.0

	# Initialize health component
	health.max_health = max_health
	health.current_health = max_health
	health.damaged.connect(_on_health_damaged)
	health.died.connect(_on_health_died)

	# Configure contact damage (ghost touching player)
	if contact_damage:
		contact_damage.damage = contact_damage_value
		contact_damage.one_shot = false  # Continuous damage, not one-shot
		contact_damage.source = self
		contact_damage.debug_enabled = debug_enabled
		if debug_enabled:
			print_debug("[GhostCovern] ContactDamage initialized: damage=", contact_damage_value, " source=", self)

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
	if is_dying:
		death_timer += delta
		# Apply gravity during death (fall down)
		current_velocity.y += 200.0 * delta
		if death_timer >= death_duration:
			queue_free()
			return
	else:
		_update_intangibility(delta)

	match current_state:
		State.WANDERING:
			update_wandering_state(delta)
		State.HAUNTING:
			update_haunting_state(delta)
		State.DEAD:
			pass  # Dead ghosts only fall

	_update_visuals(delta)

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
	var target_velocity = direction_to_target * wander_speed + _separation_push()

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

	# Disengage once the player is far enough away (wider than detection to avoid flicker)
	if global_position.distance_to(player.global_position) > disengage_radius:
		player_detected = false
		enter_wandering_state()
		return

	haunting_movement(delta)


func haunting_movement(delta: float) -> void:
	"""Hover near the player like a nuisance: close enough to pester, but it eases off instead of
	ramming. The ghost aims for its own spot on a ring of radius preferred_distance around the
	player (hover_angle), slowing over standoff_slow_range as it arrives. Other ghosts push it
	away so they don't stack."""
	hover_angle = wrapf(hover_angle + hover_drift_dir * hover_angle_drift * delta, 0.0, TAU)

	var hover_point = player.global_position + Vector2.from_angle(hover_angle) * preferred_distance
	var to_hover = hover_point - global_position
	var speed_scale = clampf(to_hover.length() / standoff_slow_range, 0.0, 1.0)
	var target_velocity = to_hover.normalized() * haunt_speed * speed_scale

	# Sitting on top of the player: drift back out gently
	var to_player = player.global_position - global_position
	if to_player.length() < preferred_distance - standoff_deadzone:
		target_velocity = -to_player.normalized() * haunt_speed * 0.3

	target_velocity += _separation_push()
	current_velocity = current_velocity.lerp(target_velocity, haunt_smoothing * delta)


## Velocity pushing this ghost away from other ghosts that are too close (stronger when closer).
## Ghosts that are not processing (their room is deactivated) are ignored.
func _separation_push() -> Vector2:
	var push = Vector2.ZERO
	for other in get_tree().get_nodes_in_group("ghost_covern"):
		if other == self or not is_instance_valid(other) or other.is_dying or not other.can_process():
			continue
		var offset: Vector2 = global_position - other.global_position
		var dist = offset.length()
		if dist >= separation_radius:
			continue
		# Exactly stacked: pick a random direction so they can still part ways
		var away = offset / dist if dist > 0.001 else Vector2.from_angle(randf_range(0.0, TAU))
		push += away * (1.0 - dist / separation_radius)
	return push * separation_strength


# ==============================================================================
# INTANGIBILITY (overlay; the ghost keeps moving while phased out)
# ==============================================================================

func _update_intangibility(delta: float) -> void:
	if not enable_intangibility or current_state == State.DEAD:
		return

	if is_intangible:
		intangible_state_timer += delta
		if intangible_state_timer >= intangible_duration:
			exit_intangible_state()
	else:
		intangible_cooldown_timer -= delta
		if intangible_cooldown_timer <= 0.0:
			enter_intangible_state()


func enter_intangible_state() -> void:
	if current_state == State.DEAD or is_dying or not enable_intangibility or is_intangible:
		return

	is_intangible = true
	intangible_state_timer = 0.0
	_set_phased(true)


func exit_intangible_state() -> void:
	if not is_intangible:
		return

	is_intangible = false
	intangible_state_timer = 0.0
	intangible_cooldown_timer = intangible_cooldown
	_set_phased(false)


## Toggles every way the ghost can touch the world. Hurtbox `monitorable` is the important one:
## projectiles detect the hurtbox by overlapping it, which depends on monitorable, not monitoring.
## The ghost's world mask is left alone so it can't phase itself into a wall.
func _set_phased(phased: bool) -> void:
	set_deferred("collision_layer", 0 if phased else _body_layer)
	if hurtbox:
		hurtbox.set_deferred("monitorable", not phased)
		hurtbox.set_deferred("monitoring", not phased)
	if contact_damage:
		contact_damage.set_deferred("monitoring", not phased)
		contact_damage.set_deferred("monitorable", not phased)


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


func enter_haunting_state() -> void:
	"""Transition to haunting state."""
	if current_state == State.DEAD:
		return

	current_state = State.HAUNTING
	# Velocity is kept so the switch from wandering to chasing is smooth


# ==============================================================================
# PLAYER DETECTION
# ==============================================================================
# Distance-based (like Atomic) instead of relying on the DetectionArea and node names.

func check_player_detection() -> void:
	"""Look the player up through the 'player' group and flag them once within detection_radius."""
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	if global_position.distance_to(player.global_position) <= detection_radius:
		player_detected = true


# ==============================================================================
# VISUALS
# ==============================================================================

func _update_visuals(delta: float) -> void:
	if not sprite:
		return

	if flash_timer > 0.0:
		flash_timer -= delta

	var color := FLASH_COLOR if flash_timer > 0.0 else Color.WHITE
	if is_intangible:
		color.a = intangible_fade_amount
	if is_dying:
		color.a = lerpf(1.0, 0.0, clampf(death_timer / death_duration, 0.0, 1.0))
	sprite.modulate = color


# ==============================================================================
# DAMAGE & HEALTH
# ==============================================================================

func take_damage(damage: int, source = null) -> void:
	"""Handle incoming damage."""
	# Backstop: the hurtbox is already unreachable while intangible
	if is_intangible or current_state == State.DEAD:
		return

	health.take_damage(damage, source)


func _on_health_damaged(amount: int, new_health: int) -> void:
	"""Handle damage signal from HealthComponent."""
	if debug_enabled:
		print_debug("[GhostCovern] Took damage: %d | Health: %d/%d" % [amount, new_health, max_health])

	flash_timer = FLASH_DURATION


func _on_health_died() -> void:
	"""Handle death signal from HealthComponent."""
	DropManager.try_drop(self, drop_table)
	if debug_enabled:
		print_debug("[GhostCovern] Ghost defeated!")
	is_dying = true
	is_intangible = false
	current_state = State.DEAD
	current_velocity = Vector2.ZERO
	death_timer = 0.0

	# Disable collisions immediately
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
		elif child is Area2D:
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)


# ==============================================================================
# UTILITY
# ==============================================================================

func get_state_name() -> String:
	"""Return the current state as a string for debugging."""
	if is_intangible:
		return "INTANGIBLE"
	match current_state:
		State.WANDERING:
			return "WANDERING"
		State.HAUNTING:
			return "HAUNTING"
		State.DEAD:
			return "DEAD"
	return "UNKNOWN"
