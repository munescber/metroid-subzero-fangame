# Minimap

A 3x3 minimap in the HUD's top-right corner, centred on the room cell the player is in. It is hidden until `MapManager.minimap_enabled` is true (the player's `MapPoint` gives it).

## Data (Resources)

- `MapRoomData` (`Scripts/Levels/map_room_data.gd`): `level_id`, `room_id`, `map_position` (top-left cell on the world map), `size` (must equal the region's `screens`) and `icons` (`size.x * size.y` textures, row by row).
- `WorldMapData` (`Scripts/Levels/world_map_data.gd`): all rooms plus `unexplored_icon` and an optional `current_marker` (not used yet; the centre frame is a `StyleBoxFlat`).
- Files live in `Resources/Map/`: `world_map.tres`, `Rooms/*.tres` and shared placeholder icons in `Icons/*.tres` (`AtlasTexture`s of `Tilesets/wrecked_ship_map.png`, 8x8 px). To change the art, edit those icons. No code depends on the PNG.
- A `RoomRegion` points at its room data with `map_room`. A region with no `map_room` is off the map; the minimap keeps showing the last cell.

Map cells are absolute world-map coordinates, not camera cells. `RoomRegion.get_map_cell()` converts.

## Flow

1. `RoomManager._report_map_cell()` calls `MapManager.enter_cell(cell)` at the start, after `transition_finished`, after `warp_to()` and on `RoomCamera.cell_changed`. Never on `transition_started`.
2. `MapManager.enter_cell()` ignores unknown cells (one warning) and unchanged cells. Otherwise it sets `current_cell`, marks it `VISITED`, marks existing 4-neighbours `SEEN` if they were `UNKNOWN`, then emits `current_cell_changed` and `map_updated`.
3. `Minimap` refreshes on `map_updated` and in `_ready()`. It reads only from `MapManager`.

## MapManager (autoload)

- `CellState { UNKNOWN, SEEN, VISITED }` in `cell_states`. `is_discovered(cell)`, `is_visited(cell)`.
- `get_cell_info(cell)` returns `exists`, `state`, `icon`, `room_id`, `level_id`. `get_bounds()` returns the rectangle of all cells. Both are meant for a future full-screen map.
- `reset()` clears states, the current cell and the map pickup (`minimap_enabled`).
- `minimap_enabled` / `enable_minimap()` / signal `minimap_enabled_changed(enabled)`: the minimap is hidden until the player obtains the map (see `MAP_POINT.md`). Cells are tracked either way.
- Saved under `save_id = "map"` as `{"visited": ["x,y"], "seen": ["x,y"], "minimap_enabled": bool, "current": "x,y"}` (`current` only when something was visited). Nothing is written when nothing was visited and the map was not obtained.
- `debug_enabled` prints `[MapManager]` lines.
- `SaveManager.restart_from_save()` always calls `reset()` first, so unsaved discoveries and an unsaved map pickup do not survive death. `load_save_data()` then restores the slot.

## Minimap (`Scenes/UI/minimap.tscn`)

`Control` > `PanelContainer` > `GridContainer` (3 columns) > 9 `MapCell`s. Cell 4 has a static `Panel` frame. `cell_size` is exported (default 8x8). Missing and `UNKNOWN` cells are empty, `SEEN` cells show `unexplored_icon` tinted by `unexplored_tint`, `VISITED` cells show the room icon. Everything is static because the HUD is frozen during slides.

## Limits

- `demo_wrecked_ship.tscn` has no `RoomManager`, so it does not drive the map.
- `map_room.size` and `icons` are only checked by the inspector warning and by `MapManager` at startup.
