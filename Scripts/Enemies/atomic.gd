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
# FEATURE TOGGLES (disable specific behaviors for testing)
# ==============================================================================

@export_category("Feature Toggles")
@export var enable_wandering: bool = true
@export var enable_attacks: bool = true
@export var enable_electric_field: bool = true

@export var max_health: int = 10
@export var contact_damage: int = 2
@onready var health_comp: HealthComponent = $HealthComponent

# ==============================================================================
# DEBUG
# ==============================================================================

@export var debug_enabled: bool = false

# ==============================================================================
# MOVEMENT & FLOATING
# ==============================================================================

@export_category("Movement")
@export var float_speed: float = 40.0
@export var float_change_interval: float = 3.0
@export var seek_speed: float = 28.0
@export var seek_smoothing: float = 4.0

var current_velocity: Vector2 = Vector2.ZERO
var float_target: Vector2 = Vector2.ZERO
var float_timer: float = 0.0

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
@export var electric_field_interval: float = 10.0  # time spent floating/seeking between activations
@export var electric_charge_duration: float = 1.5
@export var electric_field_duration: float = 2.0
@export var electric_field_radius: float = 24.0
@export var electric_field_damage: int = 5
@export var electric_field_damage_tick: float = 0.5  # how often the field re-checks for player damage
@export var electric_field_cooldown: float = 1.5

var electric_field_interval_timer: float = 0.0
var electric_field_damage_tick_timer: float = 0.0
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

const GLOW_COLOR_IDLE := Color(1, 1, 1, 1)
const GLOW_COLOR_CHARGED := Color(1, 0.85, 0.15, 1)

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var electric_field_visual: AnimatedSprite2D = $ElectricFieldVisual
@onready var electric_field_area: Area2D = $ElectricField
@onready var hurtbox: Area2D = $Hurtbox
@onready var contact_damage_area: Area2D = $ContactDamage
@onready var damage_flash_timer: Timer = $DamageFlashTimer

# ==============================================================================
# DEATH
# ==============================================================================

@export var death_duration: float = 0.5
var is_dying: bool = false
var death_timer: float = 0.0

# ==============================================================================
# DEBUG (moved here for organization)
# ==============================================================================

# @export var debug_enabled: bool = false  # Already declared above with other exports

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	# Initialize health component
	health_comp.max_health = max_health
	health_comp.current_health = max_health
	health_comp.connect("damaged", Callable(self, "_on_health_damaged"))
	health_comp.connect("died", Callable(self, "_on_health_died"))
	damage_flash_timer.connect("timeout", Callable(self, "_on_damage_flash_timer_timeout"))
	
	# Find player
	player = _find_player()
	if debug_enabled:
		print_debug("[Atomic] Ready. Player found: ", player, " | enable_attacks=", enable_attacks, " enable_electric_field=", enable_electric_field)
	if not player and debug_enabled:
		push_warning("Atomic: Player not found in 'player' group")
	
	# Setup collision layers
	collision_layer = 4  # EnemyBody
	collision_mask = 1   # World only
	
	# Setup electric field area
	electric_field_area.collision_layer = 8    # Hitbox
	electric_field_area.collision_mask = 16 | 8 # Hurtbox (player) + Hitbox (missiles)
	electric_field_area.connect("area_entered", Callable(self, "_on_electric_field_entered"))
	
	# electric_field_radius is the single source of truth for the field's actual reach,
	# so the visual, the bullet-blocking area, and the player-damage query all agree
	var electric_field_shape: CollisionShape2D = electric_field_area.get_node("CollisionShape2D")
	if electric_field_shape and electric_field_shape.shape is CircleShape2D:
		electric_field_shape.shape.radius = electric_field_radius
	
	# Setup hurtbox
	hurtbox.collision_layer = 16  # Hurtbox
	hurtbox.collision_mask = 8    # Hitbox
	
	# Setup contact damage so knockback direction and damage source logging work
	if contact_damage_area:
		contact_damage_area.damage = contact_damage
		contact_damage_area.source = self
	
	# Start floating behavior
	_choose_new_float_target()
	animated_sprite.play("default")
	electric_field_visual.play("default")
	electric_field_visual.visible = false
	electric_field_area.set_deferred("monitoring", false)

func _physics_process(delta: float) -> void:
	if is_dying:
		death_timer += delta
		var fade_progress = death_timer / death_duration
		if animated_sprite:
			animated_sprite.modulate.a = lerp(1.0, 0.0, fade_progress)
		if death_timer >= death_duration:
			queue_free()
		return
	
	if current_state == State.DEAD:
		return
	
	# Always apply continuous rotation to visuals (doesn't rotate collision nodes)
	if visuals:
		visuals.rotation += rotation_speed * delta
	
	# Electric field runs on its own independent schedule, regardless of enable_attacks
	if enable_electric_field and current_state != State.ELECTRIC_CHARGING and current_state != State.ELECTRIC_FIELD:
		electric_field_interval_timer += delta
	
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
	
	if debug_enabled:
		queue_redraw()
	
	velocity = current_velocity
	move_and_slide()

func _draw() -> void:
	# Visualizes the electric field's actual hit radius (debug_enabled only) since the sprite itself stays a fixed size
	if not debug_enabled or not electric_field_area:
		return
	var radius = electric_field_radius * electric_field_area.scale.x
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1, 1, 0, 0.6), 2.0)

# ==============================================================================
# FLOATING STATE
# ==============================================================================

func _update_floating(delta: float) -> void:
	# Electric field is fully independent of wandering/seeking/attacks and takes priority
	if enable_electric_field and electric_field_interval_timer >= electric_field_interval:
		_transition_to_state(State.ELECTRIC_CHARGING)
		return
	
	# Fallback: re-attempt player lookup if it was never found at _ready()
	if not player:
		player = _find_player()
		if player and debug_enabled:
			print_debug("[Atomic] Player found via fallback lookup: ", player)
	
	# Detect/disengage player (runs regardless of wandering toggle)
	if player:
		var dist_to_player = global_position.distance_to(player.global_position)
		if not player_detected and dist_to_player < detection_range:
			player_detected = true
			if debug_enabled:
				print_debug("[Atomic] Player detected at distance: ", dist_to_player)
		elif player_detected and dist_to_player > disengage_range:
			player_detected = false
			_choose_new_float_target()
			if debug_enabled:
				print_debug("[Atomic] Player disengaged at distance: ", dist_to_player)
	
	# If player detected and conditions met, start charging
	if player_detected and cooldown_timer <= 0.0:
		if enable_attacks:
			_transition_to_state(State.CHARGING)
			return
	
	# Gravitate slowly toward the player while detected (even without attacks)
	if player_detected:
		_update_seeking(delta)
		return
	
	if not enable_wandering:
		current_velocity *= 0.95
		return
	
	# Update float behavior
	float_timer -= delta
	
	if float_timer <= 0.0:
		_choose_new_float_target()
		float_timer = float_change_interval
		if debug_enabled:
			print_debug("[Atomic] New wander target: ", float_target)
	
	# Move toward float target
	var direction_to_target = (float_target - global_position).normalized()
	current_velocity.x = direction_to_target.x * float_speed
	
	# Small upward float bias to prevent sinking
	if abs(current_velocity.y) < float_speed * 0.5:
		current_velocity.y = -float_speed * 0.3

func _update_seeking(delta: float) -> void:
	var to_player = player.global_position - global_position
	var direction_to_player = to_player.normalized()
	var target_velocity = direction_to_player * seek_speed
	current_velocity = current_velocity.lerp(target_velocity, seek_smoothing * delta)
	
	# Avoid a steady downward drift when roughly level with the player
	if abs(to_player.y) < 8.0 and abs(current_velocity.y) < float_speed * 0.5:
		current_velocity.y = -float_speed * 0.3

func _choose_new_float_target() -> void:
	var random_angle = randf() * TAU
	var random_distance = randf_range(50.0, 120.0)
	float_target = global_position + Vector2(cos(random_angle), sin(random_angle)) * random_distance

# Group lookup can fail if the scene's group membership hasn't been picked up yet,
# so fall back to duck-typing any player-script node in the current scene.
func _find_player() -> Node2D:
	var found = get_tree().get_first_node_in_group("player")
	if found:
		return found
	var scene_root = get_tree().current_scene
	if scene_root:
		for child in scene_root.get_children():
			if child.has_method("get_aim_direction") and child.has_method("take_damage"):
				return child
	return null

# ==============================================================================
# CHARGING STATE
# ==============================================================================

func _update_charging(delta: float) -> void:
	# Aim at player
	if player:
		var direction_to_player = (player.global_position - global_position).normalized()
		dash_direction = direction_to_player
	
		if charge_timer == 0.0 and debug_enabled:
			print_debug("[Atomic] CHARGING towards player! Direction: ", dash_direction)
	
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
		_transition_to_state(State.COOLDOWN)

# ==============================================================================
# ELECTRIC CHARGING STATE
# ==============================================================================

func _update_electric_charging(delta: float) -> void:
	# Comes to a complete stop while telegraphing the upcoming field
	current_velocity = Vector2.ZERO
	
	var progress = clamp(electric_charge_timer / electric_charge_duration, 0.0, 1.0)
	glow_intensity = progress * 2.0
	if animated_sprite:
		animated_sprite.modulate = GLOW_COLOR_IDLE.lerp(GLOW_COLOR_CHARGED, progress)
	
	if electric_charge_timer == 0.0 and debug_enabled:
		print_debug("[Atomic] CHARGING electric field! Intensity building...")
	
	electric_charge_timer += delta
	if electric_charge_timer >= electric_charge_duration:
		_transition_to_state(State.ELECTRIC_FIELD)

# ==============================================================================
# ELECTRIC FIELD STATE
# ==============================================================================

func _update_electric_field(delta: float) -> void:
	current_velocity = Vector2.ZERO
	glow_intensity = 2.0
	if animated_sprite:
		animated_sprite.modulate = GLOW_COLOR_CHARGED
	
	if electric_field_timer == 0.0 and debug_enabled:
		print_debug("[Atomic] ELECTRIC FIELD ACTIVATED! Radius: ", electric_field_radius, " Damage: ", electric_field_damage)
	
	# Query overlaps on a fixed tick instead of every frame: area_entered only fires on new overlaps
	# (so a stationary player would never be hit), but querying 60x/sec is wasted work and log spam
	# once the player's own invulnerability window is already blocking repeat hits.
	electric_field_damage_tick_timer -= delta
	if electric_field_damage_tick_timer <= 0.0:
		electric_field_damage_tick_timer = electric_field_damage_tick
		_apply_electric_field_damage()
	
	electric_field_timer += delta
	if electric_field_timer >= electric_field_duration:
		if debug_enabled:
			print_debug("[Atomic] Electric field deactivating...")
		_transition_to_state(State.COOLDOWN)

func _apply_electric_field_damage() -> void:
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	# Match the area's current (glow-scaled) size so the damage range always equals what's visible/blocking bullets
	shape.radius = electric_field_radius * electric_field_area.scale.x
	
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 16  # Hurtbox layer
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	for result: Dictionary in space_state.intersect_shape(query):
		var area: Area2D = result.get("collider")
		if area == null:
			continue
		_try_hit_player_area(area)

func _try_hit_player_area(area: Area2D) -> bool:
	var area_parent: Node = area.get_parent()
	if area_parent == null or area_parent == self:
		return false
	# Group lookup can be unreliable depending on scene load order, so also
	# match by node name (same defensive pattern as missile.gd's explosion damage)
	var is_player: bool = (area_parent.name == "Player" or area_parent.name == "player_rundas" or area_parent.is_in_group("player"))
	if is_player and area.has_method("receive_hit"):
		if debug_enabled:
			print_debug("[Atomic] Electric field hit player for ", electric_field_damage, " damage!")
		area.call("receive_hit", electric_field_damage, self)
		return true
	return false

func _on_electric_field_entered(area: Area2D) -> void:
	if not field_active:
		return
	
	# Instant "spike" hit the moment the player's Hurtbox touches the field's edge
	if _try_hit_player_area(area):
		return
	
	# Destroy missiles/projectiles (both bullet and missile scenes name their combat Area2D "Hitbox")
	if area.name == "Hitbox":
		var area_parent = area.get_parent()
		if debug_enabled:
			print_debug("[Atomic] Electric field destroyed projectile: ", area.name)
		if area_parent and area_parent.has_method("take_damage"):
			area_parent.queue_free()
		else:
			area.queue_free()

# ==============================================================================
# COOLDOWN STATE
# ==============================================================================

func _update_cooldown(delta: float) -> void:
	current_velocity *= 0.98
	glow_intensity = max(0.0, glow_intensity - 2.0 * delta)
	if animated_sprite:
		animated_sprite.modulate = GLOW_COLOR_IDLE.lerp(GLOW_COLOR_CHARGED, glow_intensity / 2.0)
	
	electric_cooldown_timer += delta
	if electric_cooldown_timer >= electric_field_cooldown:
		player_detected = false
		_transition_to_state(State.FLOATING)

# ==============================================================================
# STATE TRANSITIONS
# ==============================================================================

func _transition_to_state(new_state: State) -> void:
	if debug_enabled:
		print_debug("[Atomic] State transition: %s → %s" % [State.keys()[current_state], State.keys()[new_state]])
	
	current_state = new_state
	
	# Reset timers based on new state
	match new_state:
		State.CHARGING:
			charge_timer = 0.0
		State.DASHING:
			dash_timer = 0.0
			if debug_enabled:
				print_debug("[Atomic] DASH ATTACK! Speed: ", dash_speed, " Duration: ", dash_duration, "s")
		State.RECOVERING:
			cooldown_timer = 0.0
		State.ELECTRIC_CHARGING:
			electric_charge_timer = 0.0
			current_velocity = Vector2.ZERO
		State.ELECTRIC_FIELD:
			electric_field_timer = 0.0
			electric_field_damage_tick_timer = 0.0
			field_active = true
			electric_field_area.set_deferred("monitoring", true)
			hurtbox.set_deferred("monitoring", false)
		State.COOLDOWN:
			electric_cooldown_timer = 0.0
			field_active = false
			electric_field_area.set_deferred("monitoring", false)
			hurtbox.set_deferred("monitoring", true)
			cooldown_timer = 0.0  # release the attack-trigger gate for the next cycle
		State.FLOATING:
			cooldown_timer = 0.0  # in case electric field was disabled and we skipped COOLDOWN's reset
			electric_field_interval_timer = 0.0

# ==============================================================================
# GLOW/VISUAL UPDATES
# ==============================================================================

func _update_glow_intensity(_delta: float) -> void:
	# Update field collision area size based on glow. Caps at 1.0 so the fully-active
	# field's real hit radius matches its resting/visible size instead of overshooting it.
	var field_scale = 0.5 + (glow_intensity / 4.0)
	
	if electric_field_visual:
		electric_field_visual.visible = glow_intensity > 0.01
		electric_field_visual.modulate.a = glow_intensity / 2.0
	
	if electric_field_area:
		electric_field_area.scale = Vector2(field_scale, field_scale)

# ==============================================================================
# DAMAGE & DEATH
# ==============================================================================

func take_damage(amount: int, source = null) -> void:
	if current_state == State.DEAD:
		return
	
	# Fully immune while the electric field is active (hurtbox is also disabled, this is a backstop)
	if field_active:
		if debug_enabled:
			print_debug("[Atomic] Damage blocked by electric field! Immunity active.")
		return
	
	if debug_enabled:
		print_debug("[Atomic] Taking damage: ", amount, " from source: ", source)
	
	health_comp.take_damage(amount, source)

func _on_health_damaged(amount: int, new_health: int) -> void:
	if debug_enabled:
		print_debug("[Atomic] Took damage: ", amount, " | Health: ", new_health, "/", max_health)
	# Visual feedback: sprite flash red briefly
	if animated_sprite:
		animated_sprite.modulate = Color(1, 0.5, 0.5, 1)
		damage_flash_timer.start(0.12)

func _on_damage_flash_timer_timeout() -> void:
	if animated_sprite:
		animated_sprite.modulate = GLOW_COLOR_IDLE.lerp(GLOW_COLOR_CHARGED, glow_intensity / 2.0)

func _on_health_died() -> void:
	if debug_enabled:
		print_debug("[Atomic] Defeated!")
	_transition_to_state(State.DEAD)
	is_dying = true
	death_timer = 0.0
	
	# Disable collision and visibility
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
		elif child is Area2D:
			child.set_deferred("monitoring", false)
