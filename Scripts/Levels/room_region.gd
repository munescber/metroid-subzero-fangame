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
## Other regions this one connects to (paths relative to this node). Connections work both ways.
@export var connects_to: Array[NodePath] = []

const ENTRY_NAMES := {
	Vector2i.RIGHT: &"EntryFromLeft",
	Vector2i.LEFT: &"EntryFromRight",
	Vector2i.DOWN: &"EntryFromTop",
	Vector2i.UP: &"EntryFromBottom",
}

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

## Hook for future locked doors / one-way exits. Called before leaving `cell` towards `dir`.
func allows_exit(_cell: Vector2i, _dir: Vector2i) -> bool:
	return true

## Entry marker for a player moving in `dir` into this room, or null.
func get_entry_marker(dir: Vector2i) -> Marker2D:
	return get_node_or_null(NodePath(ENTRY_NAMES.get(dir, &""))) as Marker2D

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var size := standard_screen_size()
	for y in screens.y:
		for x in screens.x:
			draw_rect(Rect2(Vector2(x, y) * size, size), Color(0.2, 0.9, 0.4, 0.9), false, 2.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(screens) * size), Color(0.2, 0.9, 0.4, 0.07), true)
