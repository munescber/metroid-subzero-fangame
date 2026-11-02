extends RefCounted

class_name DropManager

## Static helper that rolls an enemy's drop and spawns the pickup. Call
## `DropManager.try_drop(self, drop_table)` once from an enemy's death handler.

const HEALTH_PICKUP_SCENE := preload("res://Scenes/Pickups/health_pickup.tscn")
const MISSILE_REFILL_SCENE := preload("res://Scenes/Pickups/missile_refill.tscn")

static var _default_table: DropTable = DropTable.new()

## Rolls a drop for `enemy` and spawns it at its position. Returns the spawned
## pickup, or null when nothing dropped.
static func try_drop(enemy: Node2D, table: DropTable = null) -> Pickup:
	if table == null:
		table = _default_table
	if randf() >= table.drop_chance:
		return null

	# Filter out invalid options first, then pick among the remaining weights, which
	# is equivalent to renormalizing them. No valid option means no drop.
	var player := _find_player(enemy)
	var missiles_unlocked: bool = player != null and player.get("missiles_unlocked") == true
	var health_w := maxf(table.health_weight, 0.0)
	var missile_w := maxf(table.missile_weight, 0.0) if missiles_unlocked else 0.0
	var total := health_w + missile_w
	if total <= 0.0:
		return null

	var scene: PackedScene = HEALTH_PICKUP_SCENE if randf() * total < health_w else MISSILE_REFILL_SCENE
	var pickup := scene.instantiate() as Pickup
	var parent := enemy.get_parent()
	var spawn_position := enemy.global_position
	# Deferred: death handlers can run inside physics callbacks, where adding
	# Area2D nodes is not allowed.
	parent.add_child.call_deferred(pickup)
	pickup.set_deferred("global_position", spawn_position)
	pickup.start_drop_behavior.call_deferred()
	return pickup

## Spawns an exact number of each pickup around `enemy`, with no roll and no missile-unlock check
## (used for boss deaths). Pickups scatter randomly within `spread` pixels horizontally. A
## `lifetime` above 0 overrides how long they stay before despawning.
static func drop_guaranteed(enemy: Node2D, health_count: int, missile_count: int, spread: float = 48.0, lifetime: float = -1.0) -> void:
	var parent := enemy.get_parent()
	if parent == null:
		return
	for i in health_count:
		_spawn_scattered(HEALTH_PICKUP_SCENE, parent, enemy.global_position, spread, lifetime)
	for i in missile_count:
		_spawn_scattered(MISSILE_REFILL_SCENE, parent, enemy.global_position, spread, lifetime)

static func _spawn_scattered(scene: PackedScene, parent: Node, origin: Vector2, spread: float, lifetime: float) -> void:
	var pickup := scene.instantiate() as Pickup
	if lifetime > 0.0:
		pickup.drop_lifetime = lifetime
	var spawn_position := origin + Vector2(randf_range(-spread, spread), randf_range(-8.0, 8.0))
	# Deferred for the same reason as try_drop: this can run inside a physics callback.
	parent.add_child.call_deferred(pickup)
	pickup.set_deferred("global_position", spawn_position)
	pickup.start_drop_behavior.call_deferred()

static func _find_player(enemy: Node) -> Node:
	return enemy.get_tree().get_first_node_in_group("player")
