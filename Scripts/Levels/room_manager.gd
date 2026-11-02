extends Node

class_name RoomManager

## Keeps only the room the player is in simulating. Add one node of this type to a level that has a
## RoomCamera and RoomRegions (the regions may be anywhere under the camera's parent).
## - At start every room except the camera's current one is deactivated.
## - When a slide starts, the destination room is shown and its collision restored; the camera freezes
##   it until the slide ends, so it does not simulate while it scrolls into view.
## - When the slide ends, the source room is deactivated and the destination starts simulating.
## Refused transitions never emit the camera's signals, so nothing changes for them.
## `warp_to()` jumps straight to a room (used by SaveManager after loading).
## Player shots live under the `projectiles` group node and are cleared when a slide ends.
## See Docs/camera_logic/ROOM_MANAGER.md.

## Group of the node that holds the player's shots, afterimages and their impact effects.
const PROJECTILES_GROUP := &"projectiles"

@export var camera_path: NodePath = ^"../Camera_Regions/RoomCamera"
@export var debug_enabled: bool = false

var camera: RoomCamera
var active_region: RoomRegion

func _ready() -> void:
	add_to_group("room_manager")
	camera = get_node_or_null(camera_path) as RoomCamera
	if camera == null:
		push_warning("[RoomManager] No RoomCamera at %s; rooms are not managed." % camera_path)
		return
	camera.transition_started.connect(_on_transition_started)
	camera.transition_finished.connect(_on_transition_finished)
	# Deferred so the camera has resolved its start region, whatever the tree order.
	_activate_start_room.call_deferred()

func _activate_start_room() -> void:
	active_region = camera.current_region
	for region in camera.get_regions():
		if region == active_region:
			region.activate()
		else:
			region.deactivate()
	if debug_enabled:
		print("[RoomManager] start room ", active_region.name if active_region else "none")

func _on_transition_started(_from_cell: Vector2i, to_cell: Vector2i) -> void:
	var destination := camera.get_region_at(to_cell)
	if destination != null:
		destination.activate()
	if debug_enabled:
		print("[RoomManager] activating ", destination.name if destination else "none")

func _on_transition_finished(_cell: Vector2i) -> void:
	var destination := camera.current_region
	if active_region != null and active_region != destination:
		active_region.deactivate()
	active_region = destination
	_clear_projectiles()
	if debug_enabled:
		print("[RoomManager] active room ", active_region.name if active_region else "none")

## Jumps to the room containing `world_position` without a slide, for loading a save. Move the
## player there first. The destination room simulates and every other room is switched off.
func warp_to(world_position: Vector2) -> void:
	camera.snap_to(world_position)
	var destination := camera.current_region
	if destination == null:
		return
	for region in camera.get_regions():
		if region == destination:
			region.activate()
		else:
			region.deactivate()
	active_region = destination
	_clear_projectiles()
	if debug_enabled:
		print("[RoomManager] warped to ", destination.name)

func _clear_projectiles() -> void:
	for container in get_tree().get_nodes_in_group(PROJECTILES_GROUP):
		for projectile in container.get_children():
			projectile.queue_free()
