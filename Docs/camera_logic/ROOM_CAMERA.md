# RoomCamera

Script: `Scripts/Levels/room_camera.gd` (`class_name RoomCamera`, extends `Camera2D`)

A camera with two behaviours, chosen per region by `RoomRegion.camera_mode`:

- **FIXED_SCREEN** (default): shows one 256x240 cell at a time. Crossing a cell edge slides the camera one screen over while the rest of the level is frozen.
- **SMOOTH_FOLLOW**: follows the player inside the region, clamped to the region's outer rectangle. Internal cell edges cause no slide, no freeze and no player repositioning.

**Rule:** a slide happens when the player crosses a cell edge and either the region changes or the current region is FIXED_SCREEN. So leaving any region, smooth or not, always gives a camera step.

## Setup

- Place the node so its preview rectangle covers the room's first screen. The node position is the **center** of that screen.
- `room_origin` (top-left of the grid) is captured from this placement in `_ready()`. All cells are on a grid anchored there.
- `RoomRegion` nodes must sit under the camera's parent (found recursively).
- The player is found via `player_path` (default `../player_rundas`), falling back to the `player` group.

## Exports

| Property | Default | Meaning |
|---|---|---|
| `player_path` | `../player_rundas` | Player node used to detect exits |
| `screen_cell` | `(0,0)` | Starting cell, relative to the placement screen (x = column, y = row) |
| `transition_duration` | `1.0` | Seconds for a slide (sine in/out) |
| `entry_push` | `24` | Pixels the player is carried into the new screen when no entry marker exists (skipped if a wall blocks it) |
| `follow_catch_up_speed` | `8` | SMOOTH_FOLLOW only: how fast the camera catches up (0 = locked to the player) |
| `freeze_root_path` | empty | Node whose subtree is frozen during a slide. Empty = the scene root the camera was saved in |
| `debug_enabled` | `false` | Prints debug logs |

## Signals

- `transition_started(from_cell, to_cell)`: emitted **before** gameplay is frozen, so a listener (`RoomManager`) can activate the destination room and have it frozen in its active state.
- `transition_finished(cell)`: emitted after gameplay is unfrozen and `current_region` is updated.
- `cell_changed(cell)`: SMOOTH_FOLLOW only. `current_cell` changed because the player crossed an internal screen edge, so no slide ran. It is not emitted for slides, the start room or `snap_to()`.

## Helpers

- `get_regions()` returns every known `RoomRegion` once.
- `get_region_at(cell)` returns the region covering a cell, or null.
- `snap_to(world_position)` puts the camera on the screen containing a position without a slide and updates `current_cell` and `current_region`. It is used when loading a save, and the caller moves the player.

## How it works

1. **Region mapping** (`_collect_regions`): every cell covered by each `RoomRegion` is mapped to that region. Warns on misaligned regions, overlapping cells, or a start cell outside any region.
2. **Exit detection** (`_physics_process`): if the player's position leaves the current cell's rect, an exit direction is returned. Left/right take priority over up/down, so corner exits resolve over two transitions.
3. **Validation** (`_refusal_reason`): a transition is refused if the current cell has no region, the target cell has no region, `allows_exit` returns false, or the two regions differ and aren't connected. The refusal is logged once, until the player is back inside the cell.
4. **Transition** (`_try_transition`):
   - sets `is_transitioning`, emits `transition_started`, then freezes gameplay
   - tweens the camera (pixel-rounded) and the player together to the destination
   - the player's destination is the region's entry marker, or else the `entry_push` offset
   - on finish, snaps both to their final positions, updates `current_cell`, unfreezes, and emits `transition_finished`
5. **Freezing** (`_freeze_gameplay`): every child of the freeze root gets `process_mode = DISABLED`, except `CanvasLayer`s (HUD, CRT filter), nodes in the `always_active` group, and any branch that contains the camera. A branch containing the camera keeps running, and its other children are frozen instead, so the camera can be nested anywhere (for example under `Camera_Regions`). Autoloads are not in the scene and are never touched. The player, rooms, player projectiles and platforms are all frozen this way; rooms that are already deactivated stay disabled. Previous modes are saved and restored exactly after the slide.

See `ROOM_REGION.md` for how rooms are defined.

## Smooth-follow details

- `current_region` tracks the region the player is in. While in a smooth region, `current_cell` follows the player's cell, so only a real region exit reaches the normal exit check (connectivity and `allows_exit` still apply).
- **Limits** (`_clamped_follow_position`): the camera center is clamped to the region rectangle (`global_position`, `screens` x 256x240) shrunk by half the viewport on each side. An axis where the region is smaller than the view is centered. Zoom is assumed to be 1.
- **Slide into a smooth region** ends at the follow position for the player's entry point, not at a cell center.
- Positions are pixel-rounded, and the camera runs after the player (`process_physics_priority = 1`).
