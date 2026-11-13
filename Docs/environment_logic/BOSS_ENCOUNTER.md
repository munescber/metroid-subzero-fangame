# Boss Encounter — Implementation Notes

Locks a boss room's door while the boss lives and unlocks it when the boss dies. It uses the locked
state of the [Room Gate](ROOM_GATE.md).

## Files

| File | Role |
|---|---|
| `Scripts/Environment/boss_encounter.gd` | Logic (`class_name BossEncounter`, extends `Node2D`) |
| `Scripts/Environment/room_gate.gd` | `lock()` / `unlock()` and the gray animations |
| `Scripts/Enemies/phantoon.gd` | `signal defeated` |

## Adding it to a level

1. Under the boss's `RoomRegion`, add a `BossEncounter` node (script above) with a child `Area2D` named `Trigger`: collision layer 0, mask 2 (the player body), and a `CollisionShape2D` covering the room past the doorway, so the player is fully through the door when it fires.
2. Set `boss_path` (the boss node), `gate_paths` (the doors to lock) and `boss_save_id` (the boss's own `save_id`).
3. Give the boss that `save_id`. A gate's partner (the door on the other side of the border) is locked and unlocked by the gate itself.

`Room_BossRoom_Phantoon` in `demo_wrecked_ship_3.tscn` is set up this way: trigger covers local x 56 to 256, the full height; `gate_paths = [RoomGate_BR]`; `boss_save_id = "boss_phantoon"`; the partner `RoomGate_S3_2` is locked through `RoomGate_BR`.

## Flow

1. `_ready`: if `SaveManager.get_flag(boss_save_id)` has `defeated`, the trigger is switched off and nothing ever locks. If the boss node is missing it warns and does the same.
2. The player enters the trigger: every gate is locked (gray, solid, cannot be opened by beams or missiles) and the trigger is switched off, so it fires once.
3. The boss emits `defeated` (after its 0.5 s death fade, just before it frees itself): every gate is unlocked. It slides open in gray and ends open (`open_on_unlock`), then recloses in blue after `close_delay` like any `close_again` gate.

The encounter keeps no reference to the boss, only the signal connection, so a freed boss is harmless. `RoomRegion` only saves and restores an Area2D's `monitoring` flags, so room deactivation and reactivation does not re-arm or break the trigger.

## Dying mid-fight

The locked state is not saved. `Player` calls `SaveManager.restart_from_save()`, which calls `change_scene_to_file`, so the whole level is rebuilt: gates are unlocked and the trigger is armed again. The boss flag is only set when the boss dies, so a death mid-fight leaves it alive. No `reset()` is needed.

## Notes

- `RoomGate_BR` keeps `close_again = true`. A gate unlocked by `unlock()` does not close again by itself.
- Several gates share `save_id = "gate_start_east"` in this level. It is harmless because `close_again` gates are never saved.

## Save flag

The boss writes `{"defeated": true}` under its `save_id` (`SaveManager.set_flag`) when it dies, and the flag is
written to disk at the next save point. `BossEncounter.boss_save_id` must be the same id.
- If the flag is already set in `_ready()` (level reloaded after dying or loading a save), the trigger is never armed.
- With auto-continue the save is applied a few frames after `_ready()`. The encounter is in the `saveable` group
  (its `save_id` returns `boss_save_id`), and `load_save_data()` disarms the trigger. Phantoon frees itself
  the same way, so the boss is not fought again and the door is never locked.
- If the player dies after the kill but before saving, the flag on disk is unset: the boss and the lock return.

## Why the trigger uses its own flag

`RoomRegion` snapshots every Area2D's `monitoring` when its room is deactivated and restores it on
reactivation. A trigger that was switched off through `monitoring` alone came back on, so after
auto-continue the door locked on a boss that was already dead. `_disarm()` therefore also sets
`_triggered`, and `_on_trigger_body_entered()` checks that flag first.
