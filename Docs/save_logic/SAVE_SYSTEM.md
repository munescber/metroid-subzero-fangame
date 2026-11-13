# Save system

Scripts: `Scripts/Managers/save_manager.gd` (autoload `SaveManager`), `Scripts/Environment/save_point.gd` (`class_name SavePoint`), scene `Scenes/Environment/save_point.tscn`.

One save slot, written only at save points. Enemies are not saved (they respawn, see `camera_logic/ROOM_REGION.md`).

## Where the file is

| How the game runs | Slot |
|---|---|
| From the editor (F5 / F6) | `res://Saves/save_slot_1.json`, inside the project folder |
| Exported build | `user://save_slot_1.json` (an exported game cannot write into its own project) |

`SaveManager.save_path` holds the active path. To start from the beginning, delete the file or set `auto_continue` off. Consider adding `Saves/` to `.gitignore`.

## Starting the game

When the game starts, `SaveManager` waits 3 frames and calls `continue_from_save()`: if a slot exists and it was saved in the scene being run, the flags are applied and the player and camera are put at the save point. A line in the output says what happened, for example `[SaveManager] Continued from the save at 'save_room_southeast'`. A slot saved in another scene is ignored. The `auto_continue` property (on the autoload) switches this off.

## Overview

1. The player stands in a `SavePoint` and presses Up. Health and missiles are refilled (each controlled by its own export flag), then `SaveManager.save_game()` writes the slot.
2. When the player dies, the level reloads. `SaveManager` applies the slot to the new level and `RoomManager.warp_to()` puts the player and camera at the save point.
3. Progress made after the last save is lost, because only the slot is applied to the reloaded level.

## SaveManager

Autoload that reads and writes `user://save_slot_1.json`. It knows nothing about gameplay.

| Call | Meaning |
|---|---|
| `continue_from_save()` | Applies the slot to the running level if it was saved in this scene. Returns false and changes nothing otherwise. Called automatically at startup |
| `save_game(save_point_id)` | Writes the slot from `world_flags` plus every `saveable` node. Returns false if the file could not be written. Emits `saved` |
| `load_game()` | Reads the slot into `data` and `world_flags`. Returns false (and leaves both empty) if it is missing, not valid JSON, has no `flags`, or has another `version` |
| `apply_save()` | Hands each `saveable` node the dictionary stored under its `save_id` |
| `set_flag(id, value)`, `get_flag(id)` | Records state for something that is about to remove itself |
| `restart_from_save()` | Loads the slot, reloads its scene, waits 3 frames, then calls `restore_level()`. With no usable slot the level restarts from scratch. `MapManager.reset()` always runs first, so unsaved map discoveries and an unsaved map pickup are cleared before the slot is applied. Call it without `await` |
| `restore_level()` | `apply_save()`, then moves the player to the save point named in the slot and calls `RoomManager.warp_to()` |
| `start_new_game(scene_path)`, `continue_game()` | Used by the main menu, see `ui_logic/MAIN_MENU.md`. A new game deletes the slot; continue is `restart_from_save()` with a validity check first (await it) |
| `find_save_point(id)`, `get_save_point_id()`, `has_save()`, `delete_save()` | Helpers |

The file is written to `save_slot_1.json.tmp` first and then renamed, so a crash never leaves a half-written slot.

### File format

```json
{
	"version": 1,
	"saved_at": 1793560784,
	"scene": "res://Scenes/Levels/demo_wrecked_ship_3.tscn",
	"save_point": "save_room_southeast",
	"flags": {
		"player": { "max_health": 100, "health": 100, "missiles_unlocked": true, "missile_max_ammo": 105, "missile_ammo": 105, "charge_beam_unlocked": true, "dash_unlocked": true },
		"gate_start_east": { "open": true },
		"missile_exp_central": { "collected": true },
		"boss_phantoon": { "defeated": true }
	}
}
```

`version` is checked on load, so a future format change can reject or convert old saves. JSON turns every number into a float, so convert with `int(value)` where needed.

## Two kinds of state

| Kind | Examples | How it reaches the file |
|---|---|---|
| Nodes that stay in the tree | Gates, platforms, the player | They join the group `saveable` and are asked with `get_save_data()` at save time |
| Things that remove themselves | Collected pickups, broken tiles, defeated bosses | They call `SaveManager.set_flag(id, data)` when it happens, because they cannot be asked later |

`world_flags` holds both. It starts as the slot's flags when a save is loaded, collects `set_flag()` calls while playing, and is written out at the next save.

A saveable node provides:

```gdscript
var save_id: String                       # stable and unique; never a node path
func get_save_data() -> Dictionary: ...   # JSON types only; {} means nothing to store
func load_save_data(data: Dictionary) -> void: ...
```

A duplicate `save_id` logs a warning and the later node wins. Nodes with no entry in the slot keep their defaults.

## What is saved

An empty `save_id` means the node is never saved. Set the id on the instance in the level scene.

| Class | Exported id | Stored | On load |
|---|---|---|---|
| `Pickup` (for example `MissileExpansion`) | `save_id` | `collected` via `set_flag` | Frees itself. Drops from enemies have no id and are never saved |
| `RoomGate` | `save_id` | `open`, only if open and not `close_again` | `open_instantly()` |
| `RisingGate` | `save_id` | `open` | Jumps to the open position |
| `Phantoon` | `save_id` | `defeated` via `set_flag` | Frees itself |
| `MapManager` | built in (`"map"`) | `visited`, `seen` (lists of `"x,y"` strings), `minimap_enabled` and `current` | Restores the minimap discoveries and whether the map was obtained |
| Player | built in (`"player"`) | max health, health, `missiles_unlocked`, `missile_max_ammo`, `missile_ammo`, `charge_beam_unlocked`, `dash_unlocked` | Restores them |

Gates set to `close_again` are never saved, because they return to closed. `BreakableTile` and `RisingPlatform` are intentionally not saved either: broken tiles come back and platforms start lowered whenever the level is reloaded.

In `demo_wrecked_ship_3.tscn` every expansion, gate and Phantoon has an id (for example `gate_start_east`, `boss_phantoon`).

## SavePoint

An `Area2D` (mask: PlayerBody) that reports the result through `NotificationManager` (see `Docs/ui_logic/NOTIFICATION_SYSTEM.md`). The player stands inside and presses `interact_action` (default `up`). The script only polls input while the player is inside.

| Property | Default | Meaning |
|---|---|---|
| `save_id` | empty | Unique id, stored in the slot as `save_point`. An empty id falls back to the node name with a warning |
| `interact_action` | `up` | Input action that saves |
| `refill_health_on_save` | on | Heals the player to full right before saving; turn off to store current HP instead |
| `refill_missiles_on_save` | on | Refills missiles to max right before saving |
| `sfx_saved` | none | Sound played through `AudioManager` |
| `use_cutscene` | on | After a successful save, pauses the game, plays the shared `Cutscene` (`Scenes/Effects/obtain_cutscene.tscn`, the same layered animation as `MapPoint`), then shows a blocking notification (any key to dismiss) before resuming. Off: only a short non-pausing toast shows |
| `notification_title` | `GAME SAVED` | Notification title |
| `notification_message` | `Your progress has been saved.` | Notification message |
| `notification_seconds` | 2.0 | How long the toast stays when `use_cutscene` is off (also used for "SAVE FAILED") |

`saved` is emitted after a successful write. The node joins the group `save_point`. After a reload the player is placed at the save point's position, so put the node where the player should stand.

Place it inside a room. The room's activation turns the area off while the player is elsewhere. In `demo_wrecked_ship_3.tscn` there is one at the centre of `Room_SouthEast_SaveRoom`; move it onto the floor.

## Death and reload

On death the player stops, emits `died`, waits `reload_delay` seconds (default 1.5) and calls `SaveManager.restart_from_save()`.

- With a slot: the saved scene reloads, the flags are applied, and the player and camera are warped to the save point (`RoomManager.warp_to()` uses `RoomCamera.snap_to()`). Only that room is active. Enemies are fresh.
- Without a slot: the current scene reloads from scratch and the flags are cleared.

## Adding something to the save

1. Give the class an exported `save_id` and, in `_ready()`, `add_to_group("saveable")` when it is not empty.
2. State that stays in the tree: return it from `get_save_data()` and restore it in `load_save_data()`.
3. Things that remove themselves: call `SaveManager.set_flag(save_id, {...})` when it happens, return `{}` from `get_save_data()`, and free the node in `load_save_data()`.
4. Set a unique `save_id` on each instance in the level.

## Known limits

- One slot, and saving is only possible at save points. There is no title screen, so the game always continues from the slot; delete the file for a new game.
- Respawned enemy copies and the activation of buttons are not saved. A restored `RisingGate` ignores its button until it changes again.
- The player is placed at the save point node's position. If it is above the floor, the player falls to it.
- No fade or death animation yet: the level reloads after the delay.
- The save stores one scene path, so every level that uses saves needs a scene that contains the player, camera, `RoomManager` and save points.
