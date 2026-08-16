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
@onready var timer: Timer = $Timer

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

	# Phase 1: add HealthComponent at runtime
	const HealthComponent = preload("res://Scripts/Common/health_component.gd")
	health_comp = HealthComponent.new()
	add_child(health_comp)
	health_comp.max_health = 2
	health_comp.connect("damaged", Callable(self, "_on_health_damaged"))
	health_comp.connect("died", Callable(self, "_on_health_died"))

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

	# contact area (Hitbox) monitoring is handled by Hitbox script

	# state
	is_dying = false




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


### --- Phase 1: Damage shim and handlers ---
var health_comp = null

var is_dying: bool = false

func _on_contact_body_entered(body: Node) -> void:
	# damage player on contact (only when entering)
	if body and body.has_method("take_damage") and not is_dying:
		body.call("take_damage", 1, self)

func _on_timer_timeout() -> void:
	# reset sprite modulation after damage flash
	sprite.modulate = Color(1,1,1,1)

	if is_dying:
		queue_free()


func take_damage(amount: int, source = null) -> void:
	if health_comp:
		health_comp.take_damage(amount)

func _on_health_damaged(amount: int, new_health: int) -> void:
	print("Rhinobug damaged:", amount, "->", new_health)
	# flash red briefly
	sprite.modulate = Color(1,0.5,0.5,1)
	if timer:
		timer.start(0.12)

func _on_health_died() -> void:
	print("Rhinobug died")
	# play death effect then remove
	is_dying = true
	# disable collisions
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
		elif child is Area2D:
			child.set_deferred("monitoring", false)
	if timer:
		timer.start(0.18)
	else:
		queue_free()
