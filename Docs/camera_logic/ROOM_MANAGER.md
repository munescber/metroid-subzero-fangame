# RoomManager

Script: `Scripts/Levels/room_manager.gd` (`class_name RoomManager`, extends `Node`)

Keeps only the room the player is in simulating, so cost does not grow with the size of the level. Add one node to a level that has a `RoomCamera` and `RoomRegion`s. Levels without it (such as `demo_wrecked_ship.tscn`) work as before.

## Setup

- `camera_path` (default `../Camera_Regions/RoomCamera`) points at the `RoomCamera`.
- Rooms own their content (see `ROOM_REGION.md`).
- Add a `Node2D` named `Projectiles` at the level root and put it in the group `projectiles`. The player spawns shots, missiles and dash afterimages there; without it they go to the level root and are never cleared.
- `debug_enabled` prints the activation flow.

## Activation flow

1. **Start**: one frame after `_ready` (so the camera has resolved its start region), every region except `camera.current_region` is deactivated.
2. **`transition_started`**: the destination region is activated (shown, collision restored). The camera then freezes it, together with everything else, so it slides into view without simulating.
3. **`transition_finished`**: the camera has already restored process modes, so the destination simulates. The source region is deactivated. Everything in the `projectiles` containers is freed, so player shots do not follow into the next room.

Every time a cell becomes final (start, `transition_finished`, `warp_to()` and the camera's `cell_changed`) the manager calls `_report_map_cell()`. It passes the region's map cell to `MapManager.enter_cell()` and does nothing for regions without `map_room`. It never reports on `transition_started`, so the minimap updates only after a slide ends. See `Docs/map_logic/MINIMAP.md`.

Slides inside one multi-screen room change nothing except the projectile cleanup. Refused transitions never emit the camera's signals, so the manager does nothing.

## `room_entered` signal

`signal room_entered(region: RoomRegion)` is emitted once the active room really changes, after the state update: in `_on_transition_finished` (only when `active_region` changed), in `warp_to()` and when the start room is activated. It is never emitted for `cell_changed`, slides inside one region or refused transitions. The start room and `warp_to()` emit even when the room is the first one, so loading a save into a Save Room shows its banner. The `RoomBannerManager` autoload consumes it; the manager itself knows nothing about the UI. See `Docs/ui_logic/ROOM_BANNER.md`.

Enemy projectiles are spawned with `get_parent().add_child(...)`, so they live in their enemy's room and are frozen, hidden and cleaned up with it.

## Warping (loading a save)

`warp_to(world_position)` jumps to the room containing a position without a slide. Move the player there first. It calls `RoomCamera.snap_to()`, activates the destination room, deactivates every other room and clears the projectiles. `SaveManager.restore_level()` uses it after a reload. The node is in the group `room_manager` so `SaveManager` can find it.

## Keeping something running (exceptions hook)

Design only; there is no save-state registry yet. To let a node survive its room being deactivated (escape timer, a boss that must keep fighting):

- Put the node in the group `always_active`. `RoomRegion.deactivate()` leaves its collision alone and `RoomCamera` does not freeze it.
- Give it `process_mode = PROCESS_MODE_ALWAYS` so the room's `DISABLED` mode is ignored. If it must stay visible, it should live at the level root, because a deactivated room is hidden.

Nodes left in a room are paused and hidden when the player leaves, which is the intended behaviour for bosses such as Phantoon.

## Known limits

- A `SceneTreeTimer` (`get_tree().create_timer`) ignores `process_mode`. Only `missile.gd` uses one, and it is in the projectile container.
- Tweens are bound to their node and pause with it.
