extends CharacterBody2D

#@export var animation_player : AnimationPlayer
@onready var animation = $AnimationPlayer
@onready var sprite = $Sprite2D 

@export var speed = 200.0
@export var jump_height = -400.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	if Input.is_action_just_pressed("left"):
		sprite.scale.x = abs(sprite.scale.x) * -1
	
	if Input.is_action_just_pressed("right"):
		sprite.scale.x = abs(sprite.scale.x)
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle jump.
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_height

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	# var direction = Input.get_axis("ui_left", "ui_right")
	var direction = Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * speed
	else:
		#animation.play("idle")
		velocity.x = move_toward(velocity.x, 0, speed)

	update_animation()
	move_and_slide()

func update_animation():
	if velocity.x != 0:
		animation.play("run")
	else:
		animation.play("idle")
	
	if velocity.y < 0:
		animation.play("jump")
	if velocity.y > 0:
		animation.play("fall")
