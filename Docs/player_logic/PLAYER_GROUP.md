# Player Group

The player node (`player_rundas.gd`) adds itself to the `"player"` group in `_ready()`:

```gdscript
add_to_group("player")
```

Anything that needs "the player" can call `get_tree().get_first_node_in_group("player")`.

## Why it was done

Several systems needed to find the player, and the player was not in any group:

- `DropManager` must know whether missiles are unlocked before it may drop a Missile Refill.
  It first found the player by looking for a node with `restore_missiles` among the direct
  children of the current scene. That broke silently if the player was nested deeper:
  missile refills would simply never drop.
- Several scripts (`contact_damage`, projectiles, `activation_button`, ghost_covern) already
  check `is_in_group("player")`, but the check never matched because nothing joined the group.
  They worked only through name checks (`"Player"`, `"player_rundas"`) and script-name checks.

A single group is the standard Godot way to do this and does not depend on scene structure.

## Why in code and not in the scene

`ActivationButton` documents that a group saved in the `.tscn` is fragile: if the scene is open
in the editor and re-saved, the group can be lost. Joining the group in `_ready()` cannot be
lost that way and needs no scene edit.

## What uses it
- `DropManager._find_player()` (`Scripts/Pickups/drop_manager.gd`): reads `missiles_unlocked`
  to decide whether a Missile Refill is a valid drop. See `Docs/pickups_logic/PICKUPS_LOGIC.md`.

## Side effect to know about
Existing `is_in_group("player")` checks now return true for the player. Most are `or` chains
with the name checks, so nothing changes for them. The exception is `ActivationButton`'s
step-on branch: its docs say stepping on the button triggers it, but that branch never ran
because the group was missing. It now triggers when the player walks onto the button.
If buttons should only react to shots, remove the `_on_body_entered` connection there.

## Atomic
`Atomic._find_player()` now uses the group too. It can come back empty if Atomic readies before the player, so Atomic retries each physics frame until found.
