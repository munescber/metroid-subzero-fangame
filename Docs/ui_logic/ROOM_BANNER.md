# Room banner

Scripts: `Scripts/Managers/room_banner_manager.gd` (autoload `RoomBannerManager`), `Scripts/UI/room_banner_ui.gd` (`class_name RoomBannerUI`), scene `Scenes/UI/room_banner.tscn`.

A thin title-only bar (full viewport width, 16 px tall, black with a 1 px yellow bottom border and a centred yellow 8 px label) that slides down from the top of the screen when the player enters a designated room (Save, Map...), holds, and slides back up. It never pauses the game and never reads input.

## Setting a title

Each `RoomRegion` has `banner_title` (empty = no banner). Nothing else knows room names or types. Current uses in `demo_wrecked_ship_3.tscn`: the three save rooms (`Room_SouthEast_SaveRoom`, `Room_SaveRoom_2`, `Room_SaveRoom_3`) use `SAVE STATION`, `Room_GetMap` uses `MAP STATION`.

## Flow

1. `RoomManager` emits `room_entered(region)` when the active room really changes: after `transition_finished` (so never during the 1 s slide), in `warp_to()` and when it activates the start room. It does not emit for `cell_changed`, slides between screens of one room, or refused transitions. The start room and `warp_to()` emit even if it is the first room, so loading a save or starting a level in a titled room shows its banner.
2. `RoomBannerManager` checks the `room_manager` group every frame and connects to any `RoomManager` it has not met yet (a plain `SceneTree.node_added` hook did not fire for the level's manager). It works for any level, loaded now or later, including scene reloads. A manager that is already in a room when it is met is handled at once, so a start-room emit that came first is not lost. `RoomManager` does not reference the UI.
3. The manager calls `show_banner(region.banner_title)`. If the same region is still showing (start room followed by the load warp), the call is ignored so the animation does not restart.

## API

```gdscript
RoomBannerManager.show_banner(title)   # empty title = slide out any visible banner
RoomBannerManager.hide_banner()
```

A new `show_banner` kills the running tween and plays slide-in, hold, slide-out again, so a new room interrupts the previous banner. The title changes at once and the slide-in continues from the bar's current position (no pop back to the top). An empty title (a room without a banner) slides a visible banner out.

## Visuals and timing

- `CanvasLayer` layer 20: above the HUD (10) and obtain cutscene (15), below the Notification (50) and CRT filter (100). A blocking notification therefore covers it, and its pause/dismiss flow is unaffected.
- Every Control has `mouse_filter = IGNORE`; `texture_filter = 1` (nearest).
- A `Tween` on the bar's vertical position, rounded to whole pixels (it sets `offset_top`/`offset_bottom` so the bar keeps its 16 px height): enter 0.2 s, hold 2.5 s, exit 0.15 s (constants in `room_banner_ui.gd`). When idle the bar is off-screen (y = -16) and the layer is hidden.
- Resting height: the `shown_y` export on the root node of `room_banner.tscn` (default 0 = flush with the top edge) sets how many pixels below the top the bar rests. The slide always starts and ends fully off-screen.
- Default process mode: the banner freezes if the game pauses. It is independent of `NotificationManager` (no queue).

## Manual tests

1. Save Room shows SAVE STATION; Map Room shows MAP STATION.
2. A room with an empty title shows nothing.
3. A to B (both titled) shows A's then B's title; B interrupts A if still visible.
4. Nothing shows during the camera slide; the banner starts after it ends.
5. Moving between screens of one multi-screen room, or inside a SMOOTH_FOLLOW room, shows nothing new.
6. A to B to A shows A again; staying in A does not.
7. A refused transition shows nothing.
8. Loading a save into a titled room shows its banner once; starting a level in one does too.
9. The banner stays fixed while the camera slides; movement, aim and shooting are unaffected.
10. The banner is hidden beneath a blocking notification and does not break its pause/dismiss flow.
