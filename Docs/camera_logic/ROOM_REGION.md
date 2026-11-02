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
| `respawn_delay` | `0` | Seconds after a respawnable enemy dies before a fresh copy appears while the player stays in the room (0 = only when the player comes back) |

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

## Room content and activation

A region can own its gameplay content: enemies, hazards, gates, pickups and breakable tiles are children of the region, with local positions relative to it. The player, `RoomCamera`, HUD, CRT filter, shared `TileMapLayer`s and the `Projectiles` container stay at the level root.

- `is_active` is `true` while the room simulates. A `RoomManager` switches it; regions start active.
- `activate()` sets `process_mode = INHERIT`, `visible = true`, and restores the collision state saved by `deactivate()`.
- `deactivate()` sets `process_mode = DISABLED`, `visible = false`, and takes every `CollisionObject2D` below the region out of the physics world, because a disabled node still keeps its collision registered. It saves each object's previous state first: `monitoring` / `monitorable` for `Area2D`s, `collision_layer` / `collision_mask` for bodies. No node names are involved.
- Both are no-ops in the editor and when the room is already in the requested state, so the `@tool` outline drawing is unaffected.
- Collision changes use `set_deferred`, so they are safe inside physics callbacks.
- A node in the group `always_active` (`RoomRegion.ALWAYS_ACTIVE_GROUP`) is skipped by the collision toggle. See `ROOM_MANAGER.md` for what else it needs.
- State a node changes by itself while its room is off (for example its own `monitoring`) is overwritten when the room reactivates.

## Enemy respawn

Enemies in the group `respawnable` (set on the `zoomer`, `ghost_covern`, `atomic` and `rhinobug` scenes) come back whenever the player leaves their room.

- When the region enters the tree, it stores a clean copy of each respawnable enemy (`duplicate()` with groups, scripts and scene instantiation, but no signal connections). It does this before the enemies' own `_ready()`, so the copy has no nodes or values the enemy creates for itself later.
- When `deactivate()` runs on a room the player has been in, each enemy is removed (dead or alive, so a freed one is fine) and replaced by a fresh copy at the same parent, child index and name. Old collision state is replaced too, because the collision pass runs after the swap.
- The copies are made while the room is hidden, so nothing pops in view. Rooms the player never entered are not touched.
- Bosses such as Phantoon are not in the group. Pickups dropped by enemies stay in the room.

### Delayed respawn

With `respawn_delay` above 0, an enemy that dies while the room is active is replaced after that many seconds. The countdown starts when the enemy leaves the tree and only runs while the room simulates. The new copy waits until its spawn point is outside the visible screen (the viewport rectangle grown by 16 px), so it never appears in view. A single enemy can use its own delay with a node metadata entry named `respawn_delay` (0 turns it off for that enemy). Leaving the room still resets every enemy at once and clears the countdowns.

## Hooks and helpers

- `allows_exit(cell, dir)` returns `true` by default. It is a hook for future locked doors and one-way exits; override or extend it to close an exit.
- `get_world_rect()` returns the region's world-space rectangle.
- `is_connected_to(other)` checks `connects_to`.
- `get_entry_marker(dir)` returns the marker for a movement direction, or null.
- `standard_screen_size()` reads the viewport size from project settings.

See `ROOM_CAMERA.md` for the transition logic.
