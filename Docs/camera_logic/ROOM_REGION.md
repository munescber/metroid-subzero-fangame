# RoomRegion

Script: `Scripts/Levels/room_region.gd` (`class_name RoomRegion`, extends `Node2D`, `@tool`)

Defines one room as a block of `screens` standard screen cells (256x240 each). `RoomCamera` discovers all regions under its parent and uses them to decide where the player may go.

## Placement

- Place the node on the room's **top-left corner**, aligned to the screen grid anchored at the camera's starting screen.
- In the editor it draws green outlines per screen and a tinted fill so you can see the grid and room extent.

## Exports

| Property | Default | Meaning |
|---|---|---|
| `camera_mode` | `FIXED_SCREEN` | `FIXED_SCREEN`: one screen at a time with slides between screens. `SMOOTH_FOLLOW`: camera follows the player inside the region. Never inferred from size |
| `screens` | `(1,1)` | Room size in screens (x = columns, y = rows); minimum 1x1 |
| `connects_to` | `[]` | Paths (relative to this node) to other regions this one connects to |

## Connection rules

- Cells inside one region are always connected.
- Two different regions connect only if **either** lists the other in `connects_to` (connections work both ways).
- A neighbouring cell with no region is never entered.

## Entry markers (optional)

Add `Marker2D` children named:

- `EntryFromLeft` — used when the player enters moving right
- `EntryFromRight` — used when moving left
- `EntryFromTop` — used when moving down
- `EntryFromBottom` — used when moving up

If the marker lies inside the destination screen, the player is placed there. Otherwise (missing, or outside the screen, which logs a warning) the camera's `entry_push` is used.

## Hooks and helpers

- `allows_exit(cell, dir)` returns `true` by default. It is a hook for future locked doors and one-way exits; override or extend it to close an exit.
- `get_world_rect()` returns the region's world-space rectangle.
- `is_connected_to(other)` checks `connects_to`.
- `get_entry_marker(dir)` returns the marker for a movement direction, or null.
- `standard_screen_size()` reads the viewport size from project settings.

See `ROOM_CAMERA.md` for the transition logic.
