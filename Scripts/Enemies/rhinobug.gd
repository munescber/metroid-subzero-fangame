extends CharacterBody2D

# ==================================================
# Enemy Settings
# ==================================================

@export var max_health: int = 5
@export var contact_damage: int = 1
const SPEED := 40.0

# Node that contains all patrol points (Marker2D nodes).
# Export as NodePath (inspector will store a NodePath to the child).
@export var patrol_points: NodePath = NodePath("")

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

	# add HealthComponent at runtime using the exported health value
	const HealthComponent = preload("res://Scripts/Common/health_component.gd")
	health_comp = HealthComponent.new()
	health_comp.set_max_health(max_health)
	add_child(health_comp)
	health_comp.connect("damaged", Callable(self, "_on_health_damaged"))
	health_comp.connect("died", Callable(self, "_on_health_died"))

	# Resolve the exported NodePath to an actual node reference for runtime use.
	var patrol_points_node: Node = null
	if patrol_points != NodePath(""):
		if has_node(patrol_points):
			patrol_points_node = get_node(patrol_points)
	# fallback: try to find a child named PatrolPoints
	if patrol_points_node == null and has_node("PatrolPoints"):
		patrol_points_node = $PatrolPoints

	# Check if PatrolPoints was assigned.
	if patrol_points_node == null:
		push_error("Enemy: PatrolPoints node not assigned.")
		print("patrol_points is NULL")
		return

	print("Patrol node found:", patrol_points_node.name)
	print("Children found:", patrol_points_node.get_child_count())

	# Read every Marker2D.
	for child in patrol_points_node.get_children():

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

	# configure hitbox properties from exported values
	if has_node("ContactDamage"):
		var hb = $ContactDamage
		if hb is Area2D and hb.has_method("set"):
			hb.set("damage", contact_damage)
			hb.set("one_shot", false)
			hb.set("source", self)




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

# contact handled via Hitbox script on ContactDamage

func _on_timer_timeout() -> void:
	# reset sprite modulation after damage flash
	sprite.modulate = Color(1,1,1,1)

	if is_dying:
		queue_free()


func take_damage(amount: int, source = null) -> void:
	print_debug("[Rhinobug] take_damage called. amount=", amount, " source=", source)
	if health_comp:
		health_comp.take_damage(amount, source)

func _on_health_damaged(amount: int, new_health: int) -> void:
	print_debug("[Rhinobug] damaged: ", amount, "->", new_health)
	# flash red briefly
	sprite.modulate = Color(1,0.5,0.5,1)
	if timer:
		timer.start(0.12)

func _on_health_died() -> void:
	print_debug("[Rhinobug] died")
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
