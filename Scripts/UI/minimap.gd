extends Control

class_name Minimap

## 3x3 minimap around the current map cell. It reads only from MapManager and never touches the
## player or the camera. It stays hidden until MapManager.minimap_enabled (the map pickup).
## Everything is static (no tweens or timers) because the HUD is frozen
## during room slides.

## Size of one map cell in pixels.
@export var cell_size: Vector2i = Vector2i(8, 8)
## Tint for cells that were seen but not visited.
@export var unexplored_tint: Color = Color(0.5, 0.5, 0.6)
@export var debug_enabled: bool = false

@onready var _grid: GridContainer = %Grid

var _cells: Array[TextureRect] = []

func _ready() -> void:
	for child in _grid.get_children():
		var cell := child as TextureRect
		cell.custom_minimum_size = Vector2(cell_size)
		_cells.append(cell)
	_connect_once(MapManager.map_updated, _refresh)
	_connect_once(MapManager.minimap_enabled_changed, _on_minimap_enabled_changed)
	visible = MapManager.minimap_enabled
	_refresh()

func _exit_tree() -> void:
	_disconnect_if(MapManager.map_updated, _refresh)
	_disconnect_if(MapManager.minimap_enabled_changed, _on_minimap_enabled_changed)

func _on_minimap_enabled_changed(enabled: bool) -> void:
	visible = enabled

func _refresh() -> void:
	var world_map := MapManager.world_map
	for row in 3:
		for col in 3:
			var cell := _cells[row * 3 + col]
			var info := MapManager.get_cell_info(MapManager.current_cell + Vector2i(col - 1, row - 1))
			cell.texture = null
			cell.modulate = Color.WHITE
			if not MapManager.has_current_cell or not info.exists:
				continue
			if info.state == MapManager.CellState.SEEN:
				cell.texture = world_map.unexplored_icon
				cell.modulate = unexplored_tint
			elif info.state == MapManager.CellState.VISITED:
				cell.texture = info.icon
	if debug_enabled:
		print("[Minimap] refreshed around ", MapManager.current_cell)

func _connect_once(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)

func _disconnect_if(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)
