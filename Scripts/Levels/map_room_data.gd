extends Resource

class_name MapRoomData

## Minimap data for one room (one RoomRegion). Edit `icons` to change the art; no code depends on it.

@export var level_id: StringName
@export var room_id: StringName
## The room's top-left cell on the world map.
@export var map_position: Vector2i
## Room size in map cells. Must equal the RoomRegion's `screens`.
@export var size: Vector2i = Vector2i.ONE
## One icon per cell (size.x * size.y entries), row by row.
@export var icons: Array[Texture2D] = []

## Absolute map cells covered by this room, row by row.
func get_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			cells.append(map_position + Vector2i(x, y))
	return cells

## Icon of an absolute map cell, or null if the cell is outside the room or has no icon.
func get_cell_icon(cell: Vector2i) -> Texture2D:
	var local := cell - map_position
	if local.x < 0 or local.y < 0 or local.x >= size.x or local.y >= size.y:
		return null
	var index := local.y * size.x + local.x
	return icons[index] if index < icons.size() else null
