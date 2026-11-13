@tool
extends Node2D

class_name RoomRegion

## One room, made of `screens` standard screen regions (viewport size, 256x240 each).
## Place the node on the room's TOP-LEFT corner, on the screen grid anchored at the RoomCamera's
## starting region. RoomCamera discovers every RoomRegion under its parent.
##
## Connections: cells inside one region are always connected. Two different regions are connected
## only if one lists the other in `connects_to`. A neighbouring cell with no region is never entered.
##
## Optional entry positions: add Marker2D children named EntryFromLeft, EntryFromRight,
## EntryFromTop or EntryFromBottom. A marker inside the destination screen replaces the default
## push-in when the player enters through that side.
##
## Content: gameplay nodes (enemies, hazards, gates, pickups...) are children of the region, so a
## RoomManager can switch the whole room on and off with activate() / deactivate().
## A node in the group `always_active` is left alone by the collision toggle (see below).
## Enemies in the group `respawnable` are replaced by fresh copies when the player leaves the room.

## Camera modes (chosen per region, never inferred from size):
## FIXED_SCREEN  - the camera shows one screen at a time and slides whenever the player crosses a
##                 screen edge (also between the screens of one multi-screen region).
## SMOOTH_FOLLOW - the camera follows the player inside the region and stops at the region's outer
##                 edge. Internal screen edges cause no slide; leaving the region still slides.
enum CameraMode { FIXED_SCREEN, SMOOTH_FOLLOW }

@export var camera_mode: CameraMode = CameraMode.FIXED_SCREEN

## Size of the room in screens (x = columns, y = rows).
@export var screens: Vector2i = Vector2i.ONE:
	set(value):
		screens = value.max(Vector2i.ONE)
		queue_redraw()
		update_configuration_warnings()
## Minimap data for this room. Empty = the room is off the map.
@export var map_room: MapRoomData:
	set(value):
		map_room = value
		update_configuration_warnings()
## Title shown in the room banner (Save, Map...) when the player enters this room. Empty = no banner.
@export var banner_title: String = ""
## Other regions this one connects to (paths relative to this node). Connections work both ways.
@export var connects_to: Array[NodePath] = []
## Seconds after a respawnable enemy dies before a fresh copy appears while the player stays in this
## room. It waits until the spawn point is off screen. 0 = only when the player comes back.
## One enemy can override this with a node metadata entry named `respawn_delay`.
@export_range(0.0, 600.0, 0.5, "or_greater") var respawn_delay: float = 0.0

## Nodes in this group keep their collision state while their room is deactivated. They also
## need `process_mode = PROCESS_MODE_ALWAYS` (and must stay visible) to keep running.
const ALWAYS_ACTIVE_GROUP := &"always_active"

## Enemies in this group get a fresh copy of themselves when the player leaves their room,
## or after `respawn_delay` seconds.
const RESPAWN_GROUP := &"respawnable"
## Signal connections are left out: the copy's own _ready() connects them again.
const COPY_FLAGS := Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION

## Pixels around the screen where a delayed respawn still counts as visible.
const SCREEN_MARGIN := 16.0

const ENTRY_NAMES := {
	Vector2i.RIGHT: &"EntryFromLeft",
	Vector2i.LEFT: &"EntryFromRight",
	Vector2i.DOWN: &"EntryFromTop",
	Vector2i.UP: &"EntryFromBottom",
}

## False while a RoomManager has switched this room off.
var is_active: bool = true

var _saved_collision: Dictionary = {}
var _respawns: Array[Dictionary] = []
var _entered: bool = false

static func standard_screen_size() -> Vector2:
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 256),
		ProjectSettings.get_setting("display/window/size/viewport_height", 240))

## The region's area in world space (top-left corner = node position).
func get_world_rect() -> Rect2:
	return Rect2(global_position, Vector2(screens) * standard_screen_size())

func is_connected_to(other: RoomRegion) -> bool:
	for path in connects_to:
		if get_node_or_null(path) == other:
			return true
	return false

## World-map cell for `cell`, a RoomCamera grid cell (anchored at `room_origin`) inside this region.
## Only valid when `map_room` is set.
func get_map_cell(cell: Vector2i, room_origin: Vector2) -> Vector2i:
	var first_cell := Vector2i(((global_position - room_origin) / standard_screen_size()).round())
	return map_room.map_position + (cell - first_cell)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if map_room != null:
		if map_room.size != screens:
			warnings.append("map_room.size %s does not match screens %s." % [map_room.size, screens])
		if map_room.icons.size() != map_room.size.x * map_room.size.y:
			warnings.append("map_room.icons has %d entries, expected %d." % [map_room.icons.size(), map_room.size.x * map_room.size.y])
	return warnings

## Hook for future locked doors / one-way exits. Called before leaving `cell` towards `dir`.
func allows_exit(_cell: Vector2i, _dir: Vector2i) -> bool:
	return true

## Entry marker for a player moving in `dir` into this room, or null.
func get_entry_marker(dir: Vector2i) -> Marker2D:
	return get_node_or_null(NodePath(ENTRY_NAMES.get(dir, &""))) as Marker2D

func _init() -> void:
	set_physics_process(false)

## Runs before the children's _ready(), so the templates hold the pristine scene state, without
## nodes or values the enemies create for themselves later.
func _enter_tree() -> void:
	if Engine.is_editor_hint() or not _respawns.is_empty():
		return
	for enemy in _find_respawnables(self):
		_respawns.append({
			"template": enemy.duplicate(COPY_FLAGS),
			"current": enemy,
			"parent": enemy.get_parent(),
			"index": enemy.get_index(),
			"countdown": -1.0,
		})
	set_physics_process(not _respawns.is_empty())

func _physics_process(delta: float) -> void:
	for entry in _respawns:
		var wait: float = entry.template.get_meta("respawn_delay", respawn_delay)
		if wait <= 0.0:
			continue
		if is_instance_valid(entry.current) and entry.current.is_inside_tree():
			entry.countdown = -1.0
			continue
		if entry.countdown < 0.0:
			entry.countdown = wait
		entry.countdown = maxf(entry.countdown - delta, 0.0)
		if entry.countdown <= 0.0 and not _is_on_screen(entry):
			_spawn_fresh(entry)

func _exit_tree() -> void:
	for entry in _respawns:
		if is_instance_valid(entry.template):
			entry.template.free()
	_respawns.clear()

## Shows the room and restores its collision. Processing resumes unless a parent freezes it.
func activate() -> void:
	if Engine.is_editor_hint():
		return
	_entered = true
	if is_active:
		return
	is_active = true
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	for object in _saved_collision:
		if is_instance_valid(object):
			_apply_collision_state(object, _saved_collision[object])
	_saved_collision.clear()

## Stops the room from simulating, hides it and takes its collision objects out of the physics
## world, remembering their previous state for activate().
func deactivate() -> void:
	if Engine.is_editor_hint() or not is_active:
		return
	is_active = false
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false
	if _entered:
		_entered = false
		_respawn_enemies()
	_saved_collision.clear()
	for object in _find_collision_objects(self):
		_saved_collision[object] = _read_collision_state(object)
		_apply_collision_state(object, _disabled_state(object))

func _find_respawnables(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		if child.is_in_group(RESPAWN_GROUP):
			found.append(child)
		else:
			found.append_array(_find_respawnables(child))
	return found

## Swaps every respawnable enemy for a fresh copy of its starting state, dead or alive. The old one
## leaves the tree first so the copy keeps its name.
func _respawn_enemies() -> void:
	for entry in _respawns:
		_spawn_fresh(entry)

## Replaces the entry's enemy (if it is still there) with a new copy of the template.
func _spawn_fresh(entry: Dictionary) -> void:
	var old = entry.current
	if is_instance_valid(old) and old.is_inside_tree():
		old.get_parent().remove_child(old)
		old.queue_free()
	entry.countdown = -1.0
	var parent = entry.parent
	if not is_instance_valid(parent):
		return
	var fresh: Node = entry.template.duplicate(COPY_FLAGS)
	parent.add_child(fresh)
	parent.move_child(fresh, mini(entry.index, parent.get_child_count() - 1))
	entry.current = fresh

## True if the entry's spawn point is inside the visible screen, with a small margin.
func _is_on_screen(entry: Dictionary) -> bool:
	var parent = entry.parent
	if not parent is Node2D or not entry.template is Node2D:
		return false
	var spawn: Vector2 = parent.to_global(entry.template.position)
	var visible_area := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	return visible_area.grow(SCREEN_MARGIN).has_point(spawn)

func _find_collision_objects(node: Node) -> Array[CollisionObject2D]:
	var found: Array[CollisionObject2D] = []
	for child in node.get_children():
		if child.is_in_group(ALWAYS_ACTIVE_GROUP):
			continue
		if child is CollisionObject2D:
			found.append(child)
		found.append_array(_find_collision_objects(child))
	return found

## Area2Ds keep their previous monitoring flags; every other collision object keeps its layer and mask.
func _read_collision_state(object: CollisionObject2D) -> Array:
	var area := object as Area2D
	if area != null:
		return [area.monitoring, area.monitorable]
	return [object.collision_layer, object.collision_mask]

func _disabled_state(object: CollisionObject2D) -> Array:
	return [false, false] if object is Area2D else [0, 0]

func _apply_collision_state(object: CollisionObject2D, state: Array) -> void:
	if object is Area2D:
		object.set_deferred("monitoring", state[0])
		object.set_deferred("monitorable", state[1])
	else:
		object.set_deferred("collision_layer", state[0])
		object.set_deferred("collision_mask", state[1])

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var size := standard_screen_size()
	for y in screens.y:
		for x in screens.x:
			draw_rect(Rect2(Vector2(x, y) * size, size), Color(0.2, 0.9, 0.4, 0.9), false, 2.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(screens) * size), Color(0.2, 0.9, 0.4, 0.07), true)
