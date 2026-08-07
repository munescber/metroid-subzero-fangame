extends CharacterBody2D

# ==================================================
# Player Movement Settings
# ==================================================

const MOVE_SPEED := 75.0
const JUMP_FORCE := -300.0

# Gravity defined in Project Settings
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Reference to the AnimatedSprite2D node
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# ==================================================
# Initialization
# ==================================================

func _ready():
	sprite.play("idle")
	

# ==================================================
# Main Physics Loop
# ==================================================

func _physics_process(delta):
	apply_gravity(delta)
	handle_jump()
	handle_horizontal_movement()
	update_animation()

	move_and_slide()


# ==================================================
# Movement
# ==================================================

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta


func handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_FORCE


func handle_horizontal_movement():
	var direction := Input.get_axis("left", "right")

	if direction != 0:
		velocity.x = direction * MOVE_SPEED

		# Flip the sprite depending on movement direction.
		# Assumes the sprite faces RIGHT by default.
		sprite.flip_h = direction < 0

	else:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)


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
