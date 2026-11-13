extends Resource

class_name WorldMapData

## Every room on the world map, plus the shared minimap icons.

@export var rooms: Array[MapRoomData] = []
## Shown for a cell that has been seen but not visited.
@export var unexplored_icon: Texture2D
## Optional frame drawn over the current cell.
@export var current_marker: Texture2D
