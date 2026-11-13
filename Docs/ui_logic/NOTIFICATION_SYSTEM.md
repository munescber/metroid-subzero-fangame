# Notification system

Scripts: `Scripts/Managers/notification_manager.gd` (autoload `NotificationManager`), `Scripts/UI/notification_ui.gd` (`class_name NotificationUI`), scene `Scenes/UI/notification.tscn`.

A black panel with a thin yellow border and yellow text (title, optional icon, message and a blinking "PRESS ANY KEY" footer for blocking notifications). It is a `CanvasLayer` on layer 50 (HUD 10, obtain cutscene 15, CRT filter 100), so it is screen-fixed during room slides and the CRT shader still covers it. It enters with a fade and an 8 px slide (rounded to whole pixels) and leaves the same way.

## API

```gdscript
var id := NotificationManager.show_notification(title, message, icon = null, pause_game = false, auto_dismiss = false, duration = 2.0)
await NotificationManager.wait_until_dismissed(id)   # call right after show_notification
```

- Notifications are queued and shown one at a time, in order.
- `pause_game`: the tree is paused while the notification is up; the pause state from before it appeared is restored when the last queued pausing notification ends (so a caller that paused the game itself, like `MapPoint`, stays paused). A pausing notification is centred; a non-pausing one sits in the lower part of the screen.
- `auto_dismiss`: closes after `duration` seconds. Otherwise any key or joypad button press closes it. The press is consumed by the manager, input is ignored for the first 0.3 s, and the exit animation finishes before the game resumes, so the key does not leak into gameplay.
- The manager and the UI use `PROCESS_MODE_ALWAYS`, so they work while the tree is paused.
- Signals: `notification_shown(id)`, `notification_dismissed(id)`.

## Current uses

| Event | Notification | Pause | Dismiss |
|---|---|---|---|
| `SavePoint` saved | GAME SAVED / Your progress has been saved., after the cutscene animation | yes | any key |
| `SavePoint` with `use_cutscene` off | same text as a toast; SAVE FAILED on error (always a toast) | no | auto |
| First `MissileExpansion` | MISSILE SYSTEM ACQUIRED / Missile launcher unlocked. | yes | any key |
| Later `MissileExpansion`s | MISSILE EXPANSION / Missile capacity increased by N. | yes | any key |
| `DashPowerup`, `ChargeBeamPowerup` | DASH SYSTEM ACQUIRED, CHARGE BEAM ACQUIRED | yes | any key |
| `HealthExpansion` | HEALTH EXPANSION / Maximum health increased by N. | yes | any key |
| `MapPoint` | MAP DATA ACQUIRED / Map data successfully downloaded. | yes | any key |

Pickups use `Pickup._notify()`, which passes the pickup's `Sprite2D` texture as the icon. Turn it off per item with the `show_notification` export. Pickups notify only when actually collected, so loading a save never shows one.

## Limits

Gameplay scripts poll `Input` directly, so a *non-pausing* blocking notification cannot stop the player from acting. Use `pause_game` for notifications the player must read.
