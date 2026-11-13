# MapPoint

Scripts: `Scripts/Environment/map_point.gd` (`class_name MapPoint`), scene `Scenes/Environment/map_point.tscn`. An `Area2D` like the `SavePoint`. Standing in it and pressing Up (`interact_action`) while on the floor gives the player the map, which enables the minimap.

## Sequence

1. `get_tree().paused = true`. The whole game freezes; audio keeps playing (`AudioManager` runs always).
2. `sfx_obtained` plays and the shared `Cutscene` plays its animation.
3. When the animation finishes, `MapManager.enable_minimap()` is called and a blocking notification (`notification_title` / `notification_message`, via `NotificationManager`) shows.
4. After the player dismisses it (any key) the cutscene hides, the game resumes and `map_obtained` is emitted.

If the minimap is already enabled the point does nothing. The state lives in `MapManager` (saved under `"map"`), so the point needs no `save_id`.

## The shared cutscene (`ObtainCutscene`)

`Scenes/Effects/obtain_cutscene.tscn` (`Scripts/Effects/obtain_cutscene.gd`) is a `CanvasLayer` (layer 15, `process_mode = Always`, hidden) with `Layer1`..`Layer3` (`Sprite2D` spritesheets), an `AnimationPlayer` with the `get_map` animation. `MapPoint` and `SavePoint` both instance it as `Cutscene`, so editing the scene changes both. Open the scene itself to edit the animation: key `frame`, `visible`, `position`, `modulate`, etc. of all layers on the single `get_map` timeline so they stay in sync. The animation must not loop. The script exposes `play_animation(world_position)` and `finish()`; text is shown through `NotificationManager`, not by the cutscene; a missing animation is skipped with a warning. `play_animation` moves the layers (via the `CanvasLayer.offset`) so that `Layer1.position` lands on the screen position of `world_position`; both points pass their own `global_position`, so the animation is drawn around the point wherever the camera is. Keep the layers' positions as the animation's centre (default `(128, 120)`).

## Exports

| Export | Default | Meaning |
|---|---|---|
| `interact_action` | `up` | Input action that triggers it |
| `sfx_obtained` | empty | Sound played through `AudioManager.play_ui` |
| `notification_title` | `MAP DATA ACQUIRED` | Notification title |
| `notification_message` | `Map data successfully downloaded.` | Notification message |
| `debug_enabled` | false | Prints `[MapPoint]` lines |

The node joins the group `map_point`. Give its room a `map_room` of its own (see `MINIMAP.md`).
