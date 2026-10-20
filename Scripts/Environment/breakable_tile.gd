@tool
extends StaticBody2D

class_name BreakableTile

## Solid block that player projectiles can destroy. Beams already call
## take_damage(damage, shooter) on whatever solid they collide with
## (Bullet._on_hit), so no projectile code needs to know about this block.
## Health uses the shared HealthComponent, same as the player and enemies.
##
## Everything visual/physical is editable from this node's inspector, so there
## is no need to enable "Editable Children":
## - texture: any Texture2D. The default is an AtlasTexture, so click it and
##   change its Atlas / Region to pick another tile.
## - sprite_offset: shifts only the artwork.
## - collision_size / collision_offset: change only the solid collision.

signal destroyed

@export var max_health: int = 1
@export var texture: Texture2D:
	set(value):
		texture = value
		_apply_visuals()
@export var sprite_offset: Vector2 = Vector2.ZERO:
	set(value):
		sprite_offset = value
		_apply_visuals()
@export var collision_size: Vector2 = Vector2(16, 16):
	set(value):
		collision_size = value.max(Vector2.ONE)
		_apply_collision()
@export var collision_offset: Vector2 = Vector2.ZERO:
	set(value):
		collision_offset = value
		_apply_collision()
@export var debug_enabled: bool = false

var health_comp: HealthComponent = null
var _is_destroyed: bool = false

func _ready() -> void:
	_apply_visuals()
	_apply_collision()
	if Engine.is_editor_hint():
		return
	health_comp = HealthComponent.new()
	health_comp.set_max_health(max_health)
	add_child(health_comp)
	health_comp.died.connect(_on_died)

func _apply_visuals() -> void:
	if not is_node_ready():
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = texture
		sprite.position = sprite_offset

func _apply_collision() -> void:
	if not is_node_ready():
		return
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	shape_node.position = collision_offset
	var rect := shape_node.shape as RectangleShape2D
	if rect:
		rect.size = collision_size

func take_damage(amount: int, source = null) -> void:
	if _is_destroyed or health_comp == null:
		return
	if debug_enabled:
		print_debug("[BreakableTile] take_damage amount=", amount, " source=", source)
	health_comp.take_damage(amount, source)

func _on_died() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	if debug_enabled:
		print_debug("[BreakableTile] destroyed")
	# physics callbacks may be running, so shapes are disabled deferred
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
		elif child is CanvasItem:
			child.hide()
	destroyed.emit()
	queue_free()
