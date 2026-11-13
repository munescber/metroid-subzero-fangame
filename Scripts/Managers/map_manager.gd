extends Node

## Autoload "MapManager". Knows the world map (which room owns which map cell) and which cell the
## player is in. RoomManager reports the current cell through enter_cell(); UI only reads from here.
## Cells are absolute world-map coordinates, see MapRoomData.
## The player's discoveries are saved through SaveManager (group `saveable`, save_id "map").

enum CellState { UNKNOWN, SEEN, VISITED }

signal current_cell_changed(cell: Vector2i)
signal map_updated
signal minimap_enabled_changed(enabled: bool)

@export var world_map: WorldMapData = preload("res://Resources/Map/world_map.tres")
@export var debug_enabled: bool = false

## Vector2i -> CellState. Cells missing from the dictionary are UNKNOWN.
var cell_states: Dictionary = {}
var current_cell: Vector2i
var has_current_cell: bool = false
## Whether the player has obtained the map (shows the minimap). Cells are tracked either way.
var minimap_enabled: bool = false
## Stable id for SaveManager.
var save_id: String = "map"

## Vector2i -> {"room": MapRoomData, "icon": Texture2D}
var _cells: Dictionary = {}
var _warned_cells: Dictionary = {}

func _ready() -> void:
	add_to_group("saveable")
	_build_catalog()

func _build_catalog() -> void:
	_cells.clear()
	if world_map == null:
		push_warning("[MapManager] No world map assigned.")
		return
	for room in world_map.rooms:
		if room.icons.size() != room.size.x * room.size.y:
			push_warning("[MapManager] Room '%s' has %d icons for size %s." % [room.room_id, room.icons.size(), room.size])
		for cell in room.get_cells():
			if _cells.has(cell):
				push_warning("[MapManager] Cell %s is claimed by both '%s' and '%s'." % [cell, _cells[cell].room.room_id, room.room_id])
				continue
			_cells[cell] = {"room": room, "icon": room.get_cell_icon(cell)}

## Makes `cell` the current cell. Called by RoomManager once the camera is on that cell.
func enter_cell(cell: Vector2i) -> void:
	if not _cells.has(cell):
		if not _warned_cells.has(cell):
			_warned_cells[cell] = true
			push_warning("[MapManager] Cell %s is not in the world map; ignored." % cell)
		return
	if has_current_cell and cell == current_cell:
		return
	current_cell = cell
	has_current_cell = true
	cell_states[cell] = CellState.VISITED
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbour: Vector2i = cell + dir
		if _cells.has(neighbour) and not cell_states.has(neighbour):
			cell_states[neighbour] = CellState.SEEN
	if debug_enabled:
		print("[MapManager] enter cell ", cell, " room ", _cells[cell].room.room_id)
	current_cell_changed.emit(cell)
	map_updated.emit()

## Turns the minimap on (the map pickup). Safe to call more than once.
func enable_minimap() -> void:
	_set_minimap_enabled(true)

func _set_minimap_enabled(enabled: bool) -> void:
	if minimap_enabled == enabled:
		return
	minimap_enabled = enabled
	if debug_enabled:
		print("[MapManager] minimap enabled: ", enabled)
	minimap_enabled_changed.emit(enabled)

func is_discovered(cell: Vector2i) -> bool:
	return cell_states.get(cell, CellState.UNKNOWN) != CellState.UNKNOWN

func is_visited(cell: Vector2i) -> bool:
	return cell_states.get(cell, CellState.UNKNOWN) == CellState.VISITED

func get_cell_info(cell: Vector2i) -> Dictionary:
	var entry: Variant = _cells.get(cell)
	if entry == null:
		return {"exists": false}
	return {
		"exists": true,
		"state": cell_states.get(cell, CellState.UNKNOWN),
		"icon": entry.icon,
		"room_id": entry.room.room_id,
		"level_id": entry.room.level_id,
	}

## Smallest rectangle containing every map cell.
func get_bounds() -> Rect2i:
	var bounds := Rect2i()
	var first := true
	for cell in _cells:
		if first:
			bounds = Rect2i(cell, Vector2i.ONE)
			first = false
		else:
			bounds = bounds.expand(cell)
	return bounds

## Forgets every discovery, the current cell and the map pickup.
func reset() -> void:
	cell_states.clear()
	has_current_cell = false
	current_cell = Vector2i.ZERO
	_warned_cells.clear()
	_set_minimap_enabled(false)
	if debug_enabled:
		print("[MapManager] reset")
	map_updated.emit()

func get_save_data() -> Dictionary:
	var visited: Array[String] = []
	var seen: Array[String] = []
	for cell in cell_states:
		if cell_states[cell] == CellState.VISITED:
			visited.append(_cell_to_string(cell))
		elif cell_states[cell] == CellState.SEEN:
			seen.append(_cell_to_string(cell))
	if visited.is_empty() and not minimap_enabled:
		return {}
	var result := {"visited": visited, "seen": seen, "minimap_enabled": minimap_enabled}
	if not visited.is_empty():
		result["current"] = _cell_to_string(current_cell)
	return result

func load_save_data(data: Dictionary) -> void:
	cell_states.clear()
	_set_minimap_enabled(bool(data.get("minimap_enabled", false)))
	for text in data.get("seen", []):
		cell_states[_string_to_cell(str(text))] = CellState.SEEN
	for text in data.get("visited", []):
		cell_states[_string_to_cell(str(text))] = CellState.VISITED
	if data.has("current"):
		current_cell = _string_to_cell(str(data["current"]))
		has_current_cell = true
	if debug_enabled:
		print("[MapManager] loaded ", cell_states.size(), " cells, current ", current_cell)
	current_cell_changed.emit(current_cell)
	map_updated.emit()

func _cell_to_string(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _string_to_cell(text: String) -> Vector2i:
	var parts := text.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))
