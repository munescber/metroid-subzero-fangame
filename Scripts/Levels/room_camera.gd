extends Camera2D

class_name RoomCamera

## Room camera with two behaviours, chosen per RoomRegion (RoomRegion.camera_mode):
## - FIXED_SCREEN: shows exactly one standard screen (viewport size, 256x240) and slides one
##   screen over when the player crosses a screen edge, while the rest of the level is frozen.
## - SMOOTH_FOLLOW: follows the player inside the region, clamped to the region's outer edge.
##   Crossing internal screen edges does nothing; leaving the region still uses the slide.
## Place this node in the editor so that the camera's preview rectangle covers the room's first
## screen region: the node position is the CENTER of that region. The viewport must be 256x240 (zoom 1).
## Rooms are RoomRegion nodes under this camera's parent; they decide which cells exist and connect.
## See Docs/camera_logic/ and Docs/environment_logic/ROOM_SIZE_STANDARDS.md.

signal transition_started(from_cell: Vector2i, to_cell: Vector2i)
signal transition_finished(cell: Vector2i)

## Path to the node whose position decides which region is active.
@export var player_path: NodePath = ^"../player_rundas"
## Which screen region to show at start, relative to the region the node was placed on
## (x = column, y = row). (0, 0) shows exactly where the node is placed.
@export var screen_cell: Vector2i = Vector2i.ZERO
## Seconds a screen-to-screen slide takes.
@export_range(0.1, 5.0, 0.05) var transition_duration: float = 1.0
## Pixels the player is carried into the new region during the slide (skipped if a wall is in the way).
@export var entry_push: float = 24.0
## SMOOTH_FOLLOW only: how quickly the camera catches up with the player (0 = locked to the player).
@export_range(0.0, 30.0, 0.5) var follow_catch_up_speed: float = 8.0
@export var debug_enabled: bool = false

var player: CharacterBody2D
var screen_size: Vector2
## Top-left corner of the room, captured from the editor placement.
var room_origin: Vector2
## Screen cell the player is in. In SMOOTH_FOLLOW regions it tracks the player across internal edges.
var current_cell: Vector2i
var current_region: RoomRegion
var is_transitioning: bool = false

var _slide_from: Vector2
var _slide_to: Vector2
var _player_from: Vector2
var _player_to: Vector2
var _cell_regions: Dictionary = {}
var _frozen_modes: Dictionary = {}
var _warned_invalid: bool = false

func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position_smoothing_enabled = false
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	zoom = Vector2.ONE
	offset = Vector2.ZERO
	screen_size = get_viewport_rect().size
	room_origin = global_position - screen_size / 2.0
	current_cell = screen_cell
	global_position = _cell_center(current_cell)
	make_current()
	player = get_node_or_null(player_path) as CharacterBody2D
	_collect_regions()
	current_region = _cell_regions.get(current_cell)
	# Run after the player so the followed position is never one frame behind.
	process_physics_priority = 1
	if player == null:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		push_warning("[RoomCamera] No player assigned; screen transitions are disabled.")
	elif _is_smooth_follow(current_region):
		global_position = _clamped_follow_position(current_region, player.global_position)
	if debug_enabled:
		print("[RoomCamera] origin ", room_origin, " cell ", current_cell, " center ", global_position, " player ", player)

## Maps every screen cell to its RoomRegion. The grid is anchored at room_origin.
func _collect_regions() -> void:
	_cell_regions.clear()
	for region in _find_regions(get_parent()):
		var rel := (region.global_position - room_origin) / screen_size
		var first := Vector2i(rel.round())
		if not rel.is_equal_approx(Vector2(first)):
			push_warning("[RoomCamera] %s is not aligned to the screen grid (offset %s screens)." % [region.name, rel])
		for y in region.screens.y:
			for x in region.screens.x:
				var cell := first + Vector2i(x, y)
				if _cell_regions.has(cell):
					push_warning("[RoomCamera] Cell %s is claimed by both %s and %s." % [cell, _cell_regions[cell].name, region.name])
				_cell_regions[cell] = region
	if not _cell_regions.has(current_cell):
		push_warning("[RoomCamera] Start cell %s is not inside any RoomRegion; transitions are disabled." % current_cell)
	if debug_enabled:
		print("[RoomCamera] regions: ", _cell_regions.size(), " cells")

func _find_regions(node: Node) -> Array[RoomRegion]:
	var found: Array[RoomRegion] = []
	for child in node.get_children():
		if child is RoomRegion:
			found.append(child)
		found.append_array(_find_regions(child))
	return found

## Returns "" if the player may move from `from` one cell towards `dir`, otherwise the reason it can't.
func _refusal_reason(from: Vector2i, dir: Vector2i) -> String:
	var target := from + dir
	var src: RoomRegion = _cell_regions.get(from)
	var dest: RoomRegion = _cell_regions.get(target)
	if src == null:
		return "current cell %s is in no region" % from
	if dest == null:
		return "no region at cell %s" % target
	if not src.allows_exit(from, dir):
		return "%s closes this exit" % src.name
	if src != dest and not (src.is_connected_to(dest) or dest.is_connected_to(src)):
		return "%s is not connected to %s" % [src.name, dest.name]
	return ""

func _is_smooth_follow(region: RoomRegion) -> bool:
	return region != null and region.camera_mode == RoomRegion.CameraMode.SMOOTH_FOLLOW

## Camera center that keeps the view inside the region's rectangle while following `target`.
## An axis where the region is smaller than the view is centered instead.
func _clamped_follow_position(region: RoomRegion, target: Vector2) -> Vector2:
	var area := region.get_world_rect()
	var half_view := screen_size / 2.0
	var result := target
	for axis in 2:
		var lowest := area.position[axis] + half_view[axis]
		var highest := area.end[axis] - half_view[axis]
		result[axis] = area.get_center()[axis] if lowest > highest else clampf(target[axis], lowest, highest)
	return result

## SMOOTH_FOLLOW: moves the camera towards the player and keeps current_cell on the player's cell
## while the player stays inside the region, so only a real region exit reaches _exit_direction.
func _follow_player(delta: float) -> void:
	var player_cell := Vector2i(((player.global_position - room_origin) / screen_size).floor())
	if _cell_regions.get(player_cell) == current_region:
		current_cell = player_cell
	var target := _clamped_follow_position(current_region, player.global_position)
	if follow_catch_up_speed > 0.0:
		target = global_position.lerp(target, 1.0 - exp(-follow_catch_up_speed * delta))
	global_position = target.round()

func _physics_process(delta: float) -> void:
	if is_transitioning or player == null:
		return
	if _is_smooth_follow(current_region):
		_follow_player(delta)
	var dir := _exit_direction(player.global_position)
	if dir == Vector2i.ZERO:
		_warned_invalid = false
		return
	if debug_enabled:
		print("[RoomCamera] player left cell ", current_cell, " towards ", dir, " at ", player.global_position)
	_try_transition(dir)

func _cell_center(cell: Vector2i) -> Vector2:
	return room_origin + screen_size / 2.0 + Vector2(cell) * screen_size

## Horizontal exits take priority; a corner exit is resolved over two transitions.
func _exit_direction(pos: Vector2) -> Vector2i:
	var rel := pos - (_cell_center(current_cell) - screen_size / 2.0)
	if rel.x < 0.0:
		return Vector2i.LEFT
	if rel.x >= screen_size.x:
		return Vector2i.RIGHT
	if rel.y < 0.0:
		return Vector2i.UP
	if rel.y >= screen_size.y:
		return Vector2i.DOWN
	return Vector2i.ZERO

func _try_transition(dir: Vector2i) -> void:
	var target := current_cell + dir
	var reason := _refusal_reason(current_cell, dir)
	if reason != "":
		if not _warned_invalid:
			_warned_invalid = true
			print("[RoomCamera] transition %s -> %s refused: %s" % [current_cell, target, reason])
		return

	is_transitioning = true
	var from_cell := current_cell
	var start := global_position
	var target_region: RoomRegion = _cell_regions[target]
	_freeze_gameplay()
	var player_start := player.global_position
	var player_end := _entry_position(target_region, target, dir, player_start)
	var end := _clamped_follow_position(target_region, player_end) if _is_smooth_follow(target_region) else _cell_center(target)
	transition_started.emit(from_cell, target)
	if debug_enabled:
		print("[RoomCamera] transition ", from_cell, " -> ", target, " camera ", start, " -> ", end)

	_slide_from = start
	_slide_to = end
	_player_from = player_start
	_player_to = player_end
	var tween := create_tween()
	tween.tween_method(_slide_step, 0.0, 1.0, transition_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	global_position = end
	player.global_position = _player_to
	current_cell = target
	current_region = target_region
	_unfreeze_gameplay()
	is_transitioning = false
	transition_finished.emit(current_cell)
	if debug_enabled:
		print("[RoomCamera] transition done, cell ", current_cell, " camera ", global_position)

func _slide_step(t: float) -> void:
	global_position = _slide_from.lerp(_slide_to, t).round()
	player.global_position = _player_from.lerp(_player_to, t)

## Where the player ends up: the region's entry marker if it has a usable one, else pushed in.
func _entry_position(region: RoomRegion, cell: Vector2i, dir: Vector2i, from_pos: Vector2) -> Vector2:
	var marker := region.get_entry_marker(dir)
	if marker != null:
		var cell_rect := Rect2(room_origin + Vector2(cell) * screen_size, screen_size)
		if cell_rect.has_point(marker.global_position):
			return marker.global_position
		push_warning("[RoomCamera] %s/%s lies outside the destination screen; ignoring it." % [region.name, marker.name])
	return from_pos + _safe_push(Vector2(dir) * entry_push)

## Returns motion if the player can travel it unobstructed, otherwise zero.
func _safe_push(motion: Vector2) -> Vector2:
	if motion == Vector2.ZERO or player.test_move(player.global_transform, motion):
		return Vector2.ZERO
	return motion

## Disables every sibling of this camera (enemies, projectiles, hazards, platforms, the player...)
## except CanvasLayers, remembering each mode so it can be restored exactly.
func _freeze_gameplay() -> void:
	_frozen_modes.clear()
	for node in get_parent().get_children():
		if node == self or node is CanvasLayer:
			continue
		_frozen_modes[node] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED

func _unfreeze_gameplay() -> void:
	for node in _frozen_modes:
		if is_instance_valid(node):
			node.process_mode = _frozen_modes[node]
	_frozen_modes.clear()
