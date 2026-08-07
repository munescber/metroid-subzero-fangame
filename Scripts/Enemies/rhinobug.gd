extends CharacterBody2D

# ==================================================
# Enemy Settings
# ==================================================

const SPEED := 40.0

# Node that contains all patrol points (Marker2D nodes).
@export var patrol_points: Node2D

# Gravity defined in Project Settings.
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# ==================================================
# Node References
# ==================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# ==================================================
# Patrol Variables
# ==================================================

# Stores every patrol point position.
var point_positions: Array[Vector2] = []

# Index of the point we're currently walking toward.
var current_point_index := 0

# Horizontal movement direction.
var direction := 1


# ==================================================
# Initialization
# ==================================================

func _ready():
	sprite.play("walk")

	# Check if PatrolPoints was assigned.
	if patrol_points == null:
		push_error("Enemy: PatrolPoints node not assigned.")
		print("patrol_points is NULL")
		return

	print("Patrol node found:", patrol_points.name)
	print("Children found:", patrol_points.get_child_count())

	# Read every Marker2D.
	for child in patrol_points.get_children():

		print("Child:", child.name, " Type:", child.get_class())

		if child is Marker2D:
			point_positions.append(child.global_position)
			print("Added patrol point:", child.global_position)

	print("Total patrol points:", point_positions.size())

	if point_positions.size() < 2:
		push_error("Enemy needs at least two patrol points.")
		return



# ==================================================
# Main Physics Loop
# ==================================================

func _physics_process(delta):

	apply_gravity(delta)
	patrol()

	move_and_slide()


# ==================================================
# Gravity
# ==================================================

func apply_gravity(delta):

	if !is_on_floor():
		velocity.y += gravity * delta


# ==================================================
# Patrol Logic
# ==================================================

func patrol():

	var target := point_positions[current_point_index]

	# Check if we've reached the current target.
	if abs(global_position.x - target.x) < 2.0:

		current_point_index += 1

		# Loop back to the first patrol point.
		if current_point_index >= point_positions.size():
			current_point_index = 0

		target = point_positions[current_point_index]

	# Determine movement direction.
	direction = sign(target.x - global_position.x)

	velocity.x = direction * SPEED

	# Face the movement direction.
	sprite.flip_h = direction > 0
