@tool
extends Area2D

class_name SpikeHazard

## Invisible damage zone to place over spike tiles. Contact calls the player's
## existing take_damage(), so invulnerability frames and knockback come from there.
## Resize with `size` in the inspector; the zone is centered on this node.
## The editor-only outline is not drawn in game.

@export var damage: int = 1
@export var size: Vector2 = Vector2(16, 16):
	set(value):
		size = value.max(Vector2.ONE)
		_apply_size()
@export var debug_enabled: bool = false

@onready var _shape_node: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = 2  # PlayerBody
	body_entered.connect(_on_body_entered)

func _apply_size() -> void:
	if not is_node_ready():
		return
	var rect := _shape_node.shape as RectangleShape2D
	if rect:
		rect.size = size
	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-size * 0.5, size), Color(1, 0.2, 0.2, 0.25))
		draw_rect(Rect2(-size * 0.5, size), Color(1, 0.2, 0.2, 0.8), false)

func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("take_damage"):
		return
	if debug_enabled:
		print_debug("[SpikeHazard] Hit ", body.name, " damage=", damage)
	# source stays null so the player gets the generic upward knockback
	body.call("take_damage", damage, null)
