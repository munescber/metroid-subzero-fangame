extends CharacterBody2D

# ==================================================
# Player Movement Settings
# ==================================================

const MOVE_SPEED := 80.0
const SHOOT_COOLDOWN := 0.20
const MISSILE_COOLDOWN := 0.6
const BULLET_OFFSET := Vector2(12, 0)
const AIM_UP_ANGLE := PI/4
const AIM_DOWN_ANGLE := -PI/4
const DASH_DISTANCE := 48.0
const DASH_SPEED := 280.0
const DASH_COOLDOWN := 1.0
const DASH_WINDUP := 0.06  # brief mid-air hang before the burst
const DASH_AFTERIMAGE_INTERVAL := 0.04
const CHARGE_EFFECT_MIN_SCALE := 0.4
const CHARGE_EFFECT_MAX_SCALE := 1.0

# Variable jump height: the jump always starts at jump_velocity (full jump). Releasing
# the button while still rising multiplies the upward speed once by jump_release_multiplier.
# Initial upward speed in px/s (negative = up). More negative = higher full jump.
@export var jump_velocity: float = -320.0
# Fraction of the upward speed kept when jump is released early (0 = stop rising at once,
# 1 = no cut). Lower values give shorter tap jumps. Suggested range: 0.3 - 0.6.
@export_range(0.0, 1.0, 0.05) var jump_release_multiplier: float = 0.5
# True from the jump start until the player lands, starts falling, dashes or gets hit.
# It restricts the cut to the player's own jump, and makes it happen at most once.
var is_jump_rising: bool = false

# The player's own gravity in px/s^2, independent of the project's default_gravity
# (which other bodies, such as the rhinobug, still read).
@export var jump_gravity: float = 750.0
# Near the apex (|velocity.y| below the threshold) gravity is scaled by this multiplier,
# which makes the player hang briefly. It applies to tap and held jumps alike, and it
# never touches velocity, so the jump-release cut keeps working. 1.0 disables it.
@export_range(0.1, 1.0, 0.05) var apex_gravity_multiplier: float = 0.65
# Vertical speed in px/s under which the apex multiplier is active.
@export var apex_velocity_threshold: float = 60.0
# Terminal downward speed in px/s, applied to normal airborne falling only.
@export var max_fall_speed: float = 400.0

# Reference to the AnimatedSprite2D node
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle = $Muzzle
# Holds the fixed per-aim Marker2D positions (authored for the right-facing pose)
@onready var muzzle_markers: Node2D = $Muzzles
@onready var charge_effect: Sprite2D = $Muzzle/ChargeEffect

var shoot_timer: float = 0.0
var missile_timer: float = 0.0
var bullet_scene: PackedScene = preload("res://Scenes/Player/bullet.tscn")
var charge_beam_scene: PackedScene = preload("res://Scenes/Player/charge_beam.tscn")
var missile_scene: PackedScene = preload("res://Scenes/Player/missile.tscn")

# Charge beam state: pressing "shoot" starts a charge. On release the player fires
# a normal bullet, or the charge beam if held past charge_time_required.
@export var charge_time_required: float = 1.0
var is_charging: bool = false
var is_charged: bool = false
var charge_time: float = 0.0
var aim_angle: float = 0.0
# Held aim actions, oldest press first (see get_aim_direction for the priority rule)
const AIM_ACTIONS: Array[String] = ["up", "down", "aim_diag_up", "aim_diag_down"]
var _aim_press_order: Array[String] = []
var dash_cooldown_timer: float = 0.0
var dash_remaining_distance: float = 0.0
var dash_direction: float = 1.0
var is_dashing: bool = false
var dash_windup_timer: float = 0.0
var dash_afterimage_timer: float = 0.0
var dash_afterimage_scene: PackedScene = preload("res://Scenes/Player/dash_afterimage.tscn")

# Health component (instantiated at runtime)
var health_comp: HealthComponent = null

# Health and damage tuning
@export var max_health: int = 100
@export var debug_enabled: bool = false

# Missiles: unlock state and ammo are independent (unlocked with 0 ammo can't fire).
## Whether missile shooting is unlocked at start (set true to test without a pickup).
@export var missiles_unlocked: bool = false
## Current missile ammo. Starting value is editable for testing; never negative.
@export_range(0, 9999, 1, "or_greater") var missile_ammo: int = 0:
	set(value):
		missile_ammo = maxi(value, 0)
## Ammo granted by each missile pickup.
@export_range(1, 999, 1, "or_greater") var missile_pickup_amount: int = 5

# Damage / invulnerability
@export var invulnerability_time: float = 0.8
var invulnerable: bool = false
var invul_timer: float = 0.0
var invul_blink_interval: float = 0.08
var invul_blink_timer: float = 0.0
var _original_modulate: Color = Color(1,1,1,1)

# Knockback
@export var knockback_x: float = 120.0
@export var knockback_y: float = 140.0
@export var knockback_lock_duration: float = 0.2  # briefly ignores movement input so the knockback is actually felt
var knockback_lock_timer: float = 0.0

# Hurt animation: while hurt_timer > 0 the "hurt" animation overrides every other pose.
# It is skipped if the SpriteFrames has no animation named "hurt".
@export var hurt_animation_duration: float = 0.3
var hurt_timer: float = 0.0

# Player damage tuning for debugging
@export var player_damage_taken: int = 1



# Hold-to-aim. Single source of truth for where bullets, charge beams and missiles go.
#   no key        -> horizontal (facing side)
#   up (W)        -> straight up, any state
#   down (S)      -> airborne only: straight down (ignored on the ground)
#   aim_diag_up   (Q) -> diagonal up, any state
#   aim_diag_down (E) -> diagonal down, ignored while grounded and standing still
# Priority rule: the most recently pressed key that is valid in the current state wins.
# When it is released (or becomes invalid, e.g. S on landing) the next most recent held
# valid key is used, and with none left the aim returns to horizontal.
# Diagonals and horizontal follow the facing side; straight up/down do not.
func get_aim_direction() -> Vector2:
	# horizontal is -1 when facing left, +1 when facing right
	var horizontal: float = -1.0 if sprite.flip_h else 1.0
	var grounded: bool = is_on_floor()

	for i in range(_aim_press_order.size() - 1, -1, -1):
		var action: String = _aim_press_order[i]
		if action == "up":
			return Vector2.UP
		elif action == "down" and not grounded:
			return Vector2.DOWN
		elif action == "aim_diag_up":
			return Vector2(horizontal, -1.0).normalized()
		elif action == "aim_diag_down" and not (grounded and not _is_moving_horizontally()):
			return Vector2(horizontal, 1.0).normalized()

	return Vector2(horizontal, 0.0)


# True while the player is running (move key held) or still carrying horizontal speed,
# e.g. from knockback or a dash. Same "moving" notion as the walk animation.
func _is_moving_horizontally() -> bool:
	return abs(velocity.x) > 0.0 or Input.get_axis("left", "right") != 0.0


# Keeps _aim_press_order sorted by press time (oldest first) for the held aim keys.
func _update_aim_press_order() -> void:
	for action in AIM_ACTIONS:
		if Input.is_action_just_pressed(action):
			_aim_press_order.erase(action)
			_aim_press_order.append(action)
		elif Input.is_action_pressed(action):
			# held but never seen as pressed (e.g. pressed while physics was paused)
			if not _aim_press_order.has(action):
				_aim_press_order.append(action)
		else:
			_aim_press_order.erase(action)


# ==================================================
# Initialization
# ==================================================

func _ready():
	sprite.play("idle")
	_update_muzzle_position()

	# initialize HealthComponent with the exported max health before any fight damage occurs
	health_comp = HealthComponent.new()
	health_comp.set_max_health(max_health)
	add_child(health_comp)
	health_comp.connect("damaged", Callable(self, "_on_health_damaged"))
	health_comp.connect("died", Callable(self, "_on_health_died"))

	# save original sprite modulate for blinking
	_original_modulate = sprite.modulate

	# Hurtbox signals are handled by the Hurtbox API (no fallback hookup)

# ==================================================
# Main Physics Loop
# ==================================================

func _physics_process(delta):
	apply_gravity(delta)
	handle_jump()
	handle_aim()
	handle_shoot(delta)
	handle_dash(delta)
	
	if knockback_lock_timer > 0.0:
		knockback_lock_timer -= delta
	elif not is_dashing:
		handle_horizontal_movement()

	hurt_timer = maxf(hurt_timer - delta, 0.0)
	update_animation()

	# invulnerability handling (blink + timer)
	if invulnerable:
		invul_timer = max(invul_timer - delta, 0.0)
		invul_blink_timer -= delta
		if invul_blink_timer <= 0.0:
			invul_blink_timer = invul_blink_interval
			# toggle alpha for blink effect
			sprite.modulate = Color(1,1,1, 0.5) if sprite.modulate.a == 1.0 else _original_modulate
		if invul_timer <= 0.0:
			invulnerable = false
			sprite.modulate = _original_modulate

	move_and_slide()

	# the wall check is skipped during the windup, since no dash movement has happened yet
	if is_dashing and dash_windup_timer <= 0.0 and is_on_wall():
		_end_dash()


func handle_shoot(delta):
	shoot_timer = max(shoot_timer - delta, 0.0)
	missile_timer = max(missile_timer - delta, 0.0)

	if Input.is_action_just_pressed("missile_mode") and debug_enabled:
		print_debug("[Player] MISSILE STATE IS ON")
	if Input.is_action_just_released("missile_mode") and debug_enabled:
		print_debug("[Player] MISSILE STATE IS OFF")

	if Input.is_action_just_pressed("shoot"):
		if Input.is_action_pressed("missile_mode"):
			_try_fire_missile()
		else:
			_start_charge()

	_update_charge(delta)


func _fire_bullet() -> void:
	shoot_timer = SHOOT_COOLDOWN
	_spawn_projectile(bullet_scene)


func _fire_charge_beam() -> void:
	_spawn_projectile(charge_beam_scene)


func _spawn_projectile(scene: PackedScene) -> void:
	var shot := _get_shot_origin_and_dir()
	var final_dir: Vector2 = shot[1]
	var projectile = scene.instantiate()
	projectile.start(final_dir, self)
	# spawn slightly ahead so it doesn't immediately collide with player
	projectile.global_position = shot[0]
	get_parent().add_child(projectile)


func _start_charge() -> void:
	is_charging = true
	is_charged = false
	charge_time = 0.0


func _update_charge(delta: float) -> void:
	if not is_charging:
		return

	# entering missile mode while holding cancels the charge
	if Input.is_action_pressed("missile_mode"):
		_reset_charge()
		return

	if not Input.is_action_pressed("shoot"):
		var was_charged := is_charged
		_reset_charge()
		if was_charged:
			_fire_charge_beam()
		elif shoot_timer <= 0.0:
			_fire_bullet()
		return

	charge_time += delta
	if not is_charged and charge_time >= charge_time_required:
		is_charged = true
		if debug_enabled:
			print_debug("[Player] Charge beam ready")
	_update_charge_visual()


func _reset_charge() -> void:
	is_charging = false
	is_charged = false
	charge_time = 0.0
	charge_effect.visible = false


func _update_charge_visual() -> void:
	var ratio: float = clampf(charge_time / maxf(charge_time_required, 0.001), 0.0, 1.0)
	charge_effect.visible = true
	if is_charged:
		# fast pulse + brighter flash so "ready" is obvious without a UI timer
		var pulse: float = 0.5 + 0.5 * sin(charge_time * 30.0)
		charge_effect.scale = Vector2.ONE * CHARGE_EFFECT_MAX_SCALE * (1.0 + 0.3 * pulse)
		charge_effect.modulate = Color(1, 1, 1, 1).lerp(Color(1.4, 1.4, 1.4, 1), pulse)
	else:
		# grows and fades in as the charge builds
		var pulse: float = 0.5 + 0.5 * sin(charge_time * 12.0)
		charge_effect.scale = Vector2.ONE * lerpf(CHARGE_EFFECT_MIN_SCALE, CHARGE_EFFECT_MAX_SCALE, ratio)
		charge_effect.modulate = Color(1, 1, 1, lerpf(0.3, 0.8, ratio) * (0.8 + 0.2 * pulse))


## Called by MissilePickup. There is no ammo cap in this project, so the
## "y" in the log is shown as ∞ rather than an invented maximum.
func collect_missiles() -> void:
	if not missiles_unlocked:
		missiles_unlocked = true
		print("Missile enabled")
	missile_ammo += missile_pickup_amount
	print("Missiles obtained. Count %d/∞" % missile_ammo)


func _try_fire_missile() -> void:
	if not missiles_unlocked:
		return

	if missile_timer > 0.0:
		return

	if missile_ammo <= 0:
		if debug_enabled:
			print_debug("[Player] No missile ammo")
		return

	missile_timer = MISSILE_COOLDOWN
	missile_ammo -= 1
	var shot := _get_shot_origin_and_dir()
	var final_dir: Vector2 = shot[1]
	var missile = missile_scene.instantiate()
	missile.start(final_dir, self)
	# spawn slightly ahead so it doesn't immediately collide with player
	missile.global_position = shot[0]
	get_parent().add_child(missile)

	if debug_enabled:
		print_debug("[Player] Missiles left: %d" % missile_ammo)



func handle_dash(delta):
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)

	if is_dashing:
		_update_dash(delta)
		return

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and knockback_lock_timer <= 0.0:
		_start_dash()


func _start_dash() -> void:
	is_dashing = true
	dash_cooldown_timer = DASH_COOLDOWN
	dash_remaining_distance = DASH_DISTANCE
	dash_windup_timer = DASH_WINDUP
	dash_afterimage_timer = 0.0
	dash_direction = -1.0 if sprite.flip_h else 1.0
	# the dash replaces any jump/fall momentum instead of inheriting it
	velocity = Vector2.ZERO
	is_jump_rising = false


func _update_dash(delta: float) -> void:
	# movement itself is done by the single move_and_slide() in _physics_process
	velocity.y = 0.0

	if dash_windup_timer > 0.0:
		dash_windup_timer -= delta
		velocity.x = 0.0
		return

	velocity.x = dash_direction * DASH_SPEED
	dash_remaining_distance -= DASH_SPEED * delta

	dash_afterimage_timer -= delta
	if dash_afterimage_timer <= 0.0:
		dash_afterimage_timer = DASH_AFTERIMAGE_INTERVAL
		_spawn_afterimage()

	if dash_remaining_distance <= 0.0:
		_end_dash()


func _end_dash() -> void:
	is_dashing = false
	dash_windup_timer = 0.0
	# no leftover momentum: gravity takes over from zero if airborne
	velocity = Vector2.ZERO


func _spawn_afterimage() -> void:
	var afterimage: DashAfterimage = dash_afterimage_scene.instantiate()
	get_parent().add_child(afterimage)
	afterimage.setup(sprite)


# ==================================================
# Movement
# ==================================================

func apply_gravity(delta):
	if is_dashing:
		return
	if is_on_floor():
		return

	var applied_gravity := jump_gravity
	if abs(velocity.y) < apex_velocity_threshold:
		applied_gravity *= apex_gravity_multiplier
	velocity.y = min(velocity.y + applied_gravity * delta, max_fall_speed)


func handle_jump():
	if is_dashing:
		return
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		is_jump_rising = true

	if not is_jump_rising:
		return

	# the jump ends at the apex, so later releases can't touch falling speed
	if velocity.y >= 0.0:
		is_jump_rising = false
	elif not Input.is_action_pressed("jump"):
		velocity.y *= jump_release_multiplier
		is_jump_rising = false


func handle_horizontal_movement():
	if is_dashing:
		return

	var direction := Input.get_axis("left", "right")

	if direction != 0:
		velocity.x = direction * MOVE_SPEED

		# Flip the sprite depending on movement direction.
		# Assumes the sprite faces RIGHT by default.
		sprite.flip_h = direction < 0
		_update_muzzle_position()

	else:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)


func _update_muzzle_position() -> void:
	handle_aim()


func handle_aim() -> void:
	# Update aim angle and muzzle from the resolved aim direction
	_update_aim_press_order()
	_apply_aim_to_muzzle(get_aim_direction())


func _apply_aim_to_muzzle(dir: Vector2) -> void:
	aim_angle = dir.angle()
	muzzle.rotation = aim_angle
	var marker: Marker2D = _get_muzzle_marker(dir)
	if marker == null:
		return
	# Markers are authored for the right-facing pose; the player node itself never flips
	# (only the sprite does), so mirror x here when facing left.
	var pos: Vector2 = marker.position
	if sprite.flip_h:
		pos.x = -pos.x
	muzzle.position = pos


# Maps the resolved aim direction to its marker. Straight up/down have x == 0,
# horizontal has y == 0, anything else is a diagonal.
func _get_muzzle_marker(dir: Vector2) -> Marker2D:
	var key: StringName
	if is_zero_approx(dir.x):
		key = &"MuzzleUp" if dir.y < 0.0 else &"MuzzleDown"
	elif is_zero_approx(dir.y):
		key = &"MuzzleHorizontal"
	else:
		key = &"MuzzleDiagonalUp" if dir.y < 0.0 else &"MuzzleDiagonalDown"
	var marker := muzzle_markers.get_node_or_null(NodePath(key)) as Marker2D
	if marker == null:
		push_error("[Player] Missing muzzle marker '%s' under Muzzles" % key)
	return marker


# Returns the spawn origin and direction for a shot, with the muzzle synced to the
# current aim and facing (facing may have changed after handle_aim ran this frame).
func _get_shot_origin_and_dir() -> Array:
	var dir: Vector2 = get_aim_direction()
	_apply_aim_to_muzzle(dir)
	return [muzzle.global_position + dir * 6, dir]


# ==================================================
# Animation
# ==================================================

func update_animation():

	if hurt_timer > 0.0 and sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")

	elif is_dashing and sprite.sprite_frames.has_animation("dash"):
		sprite.play("dash")

	elif !is_on_floor():
		# the air dash zeroes velocity.y, so keep the current pose instead of flipping to "fall"
		if not is_dashing:
			sprite.play("jump" if velocity.y < 0.0 else "fall")

	elif abs(velocity.x) > 0:
		sprite.play("walk")

	else:
		sprite.play("idle")


### --- Phase 1: Damage shim and handlers ---
func take_damage(amount: int, source = null) -> void:
	if debug_enabled:
		print_debug("[Player] take_damage called. amount=", amount, " source=", source, " invulnerable=", invulnerable)
	if invulnerable:
		if debug_enabled:
			print_debug("[Player] Ignored due to invulnerability.")
		return

	# damage cancels the dash so the knockback isn't overwritten
	if is_dashing:
		_end_dash()

	# apply knockback using source if available
	if source and source is Node2D:
		var dir: Vector2 = (global_position - source.global_position).normalized()
		velocity.x = dir.x * knockback_x
		velocity.y = -abs(knockback_y)
	else:
		# generic upward knockback
		velocity.y = -abs(knockback_y)
	knockback_lock_timer = knockback_lock_duration
	# the knockback's upward speed must not be cut by releasing jump
	is_jump_rising = false
	
	# mark invulnerable and start timers
	invulnerable = true
	invul_timer = invulnerability_time
	invul_blink_timer = invul_blink_interval

	# restart the hurt pose from frame 0 even if it was already playing
	hurt_timer = hurt_animation_duration
	if sprite.sprite_frames.has_animation("hurt"):
		sprite.stop()
		sprite.play("hurt")

	if health_comp:
		health_comp.take_damage(amount, source)

func _on_health_damaged(amount: int, new_health: int) -> void:
	print("Player damaged:", amount, "->", new_health)
	# potential place to trigger hurt animation/sound

func _on_health_died() -> void:
	print("Player died")
	# disable physics and input
	set_physics_process(false)
	velocity = Vector2.ZERO
	# optional: play death animation or notify game manager
# End of player_rundas.gd
