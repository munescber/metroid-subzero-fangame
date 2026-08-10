extends CharacterBody2D

# ==================================================
# Player Movement Settings
# ==================================================

const MOVE_SPEED := 75.0
const JUMP_FORCE := -300.0
const SHOOT_COOLDOWN := 0.20
const BULLET_OFFSET := Vector2(12, 0)
const AIM_UP_ANGLE := PI/4
const AIM_DOWN_ANGLE := -PI/4
const DASH_DISTANCE := 48.0
const DASH_SPEED := 500.0
const DASH_COOLDOWN := 1

# Gravity defined in Project Settings
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Reference to the AnimatedSprite2D node
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle = $Muzzle

var shoot_timer: float = 0.0
var bullet_scene: PackedScene = preload("res://Scenes/Player/bullet.tscn")
var aim_angle: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_remaining_distance: float = 0.0
var dash_direction: float = 1.0
var is_dashing: bool = false

func get_aim_direction() -> Vector2:
	# horizontal is -1 when facing left, +1 when facing right
	var horizontal: float = -1.0 if sprite.flip_h else 1.0
	var vertical: float = 0.0

	if Input.is_action_pressed("up"):
		vertical = -1.0
	elif Input.is_action_pressed("down") and not is_on_floor():
		vertical = 1.0

	var dir := Vector2(horizontal, vertical)
	return dir.normalized()


# ==================================================
# Initialization
# ==================================================

func _ready():
	sprite.play("idle")
	_update_muzzle_position()
	

# ==================================================
# Main Physics Loop
# ==================================================

func _physics_process(delta):
	apply_gravity(delta)
	handle_jump()
	handle_aim()
	handle_shoot(delta)
	handle_dash(delta)

	if not is_dashing:
		handle_horizontal_movement()

	update_animation()

	move_and_slide()

	if is_dashing and is_on_wall():
		is_dashing = false
		velocity.x = 0.0


func handle_shoot(delta):
	shoot_timer = max(shoot_timer - delta, 0.0)

	if Input.is_action_just_pressed("shoot") and shoot_timer <= 0.0:
		shoot_timer = SHOOT_COOLDOWN
		var final_dir: Vector2 = get_aim_direction()
		var bullet = bullet_scene.instantiate()
		bullet.start(final_dir, self)
		# spawn slightly ahead so it doesn't immediately collide with player
		bullet.global_position = muzzle.global_position + final_dir * 6
		get_parent().add_child(bullet)


func handle_dash(delta):
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)

	if is_dashing:
		velocity.x = dash_direction * DASH_SPEED
		dash_remaining_distance -= DASH_SPEED * delta
		if dash_remaining_distance <= 0.0:
			is_dashing = false
			velocity.x = 0.0
		return

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		is_dashing = true
		dash_cooldown_timer = DASH_COOLDOWN
		dash_remaining_distance = DASH_DISTANCE
		dash_direction = -1.0 if sprite.flip_h else 1.0
		velocity.x = dash_direction * DASH_SPEED


# ==================================================
# Movement
# ==================================================

func apply_gravity(delta):
	if is_dashing:
		return
	if not is_on_floor():
		velocity.y += gravity * delta


func handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_FORCE


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
	var offset_x: float = abs(muzzle.position.x)
	muzzle.position.x = -offset_x if sprite.flip_h else offset_x
	# adjust muzzle rotation to match facing and aim
	var dir := get_aim_direction()
	aim_angle = dir.angle()
	muzzle.rotation = aim_angle


func handle_aim() -> void:
	# Update aim angle and muzzle rotation from vector direction
	var dir := get_aim_direction()
	aim_angle = dir.angle()
	muzzle.rotation = aim_angle


# ==================================================
# Animation
# ==================================================

func update_animation():

	if !is_on_floor():
		sprite.play("jump")

	elif abs(velocity.x) > 0:
		sprite.play("walk")

	else:
		sprite.play("idle")
