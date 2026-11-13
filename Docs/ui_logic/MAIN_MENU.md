# Title screen and main menu

Scripts: `Scripts/UI/title_screen.gd`, `Scripts/UI/main_menu.gd`, `Scripts/Managers/scene_transition.gd` (autoload `SceneTransition`).
Scenes: `Scenes/UI/title_screen.tscn` (the project's main scene), `Scenes/UI/main_menu.tscn`.

```
launch -> TitleScreen -(any key)-> MainMenu -+- START GAME -> [overwrite? CANCEL / NEW GAME] -> SaveManager.start_new_game()
                                             +- CONTINUE   -> SaveManager.continue_game()
                                             +- QUIT       -> get_tree().quit()
```

The screens are independent and never build the gameplay world. The menu only picks an action and hands it to `SaveManager` and `SceneTransition`.

## TitleScreen

- Plays the AnimationPlayer animation `intro` by itself; input is ignored until it ends. Then the label `PressAnyKeyLabel` is shown and `blink` loops.
- First key press (not a repeat) or joypad button press fades to the main menu once. Mouse and stick motion do nothing.
- `TitleScreen.intro_played` (static) is true after the first intro, so a later visit plays `intro` at 1000x speed (every track ends in its end state, the prompt appears at once).
- Art: fill `Background`, `AnimatedBackground`, `AtmosphericEffects`, `GameLogo` and add tracks for them to `intro`. Both animations are optional. The shipped `intro` only fades the logo in; there is no artwork yet.

## MainMenu

- Up/Down (arrows, W/S, D-pad, left stick), `ui_accept` (Enter, Space, pad A) confirms, `ui_cancel` backs out of the overwrite question. Selected entry: `> TEXT <` in yellow. Disabled: dark grey, skipped when navigating.
- CONTINUE is enabled when `SaveManager.has_save()`. If `continue_game()` then fails (unreadable slot, scene missing) the menu stays and CONTINUE becomes disabled.
- START GAME with a save asks the overwrite question (default: CANCEL). Without one it starts directly. `new_game_scene` (export) is the first level.
- `_busy` blocks input as soon as an action starts, so an action runs once.

## SceneTransition

`transition(action)` fades to black, awaits `action` (it must switch the scene), waits 2 frames and fades in. It returns the result of `action`, or null if one is already running. It lives in an autoload `CanvasLayer` (layer 100, `PROCESS_MODE_ALWAYS`) so it survives the scene switch. `change_scene(path)` is the plain-switch shortcut.

## SaveManager additions

| Call | Meaning |
|---|---|
| `start_new_game(scene_path)` | Deletes the slot (dying later would otherwise reload the old run), resets flags and `MapManager`, then switches scene. Returns an Error and touches nothing if the scene does not exist |
| `continue_game()` | Await it. Returns false and changes nothing if the slot is missing or unusable, otherwise `restart_from_save()` and true |

`auto_continue` skips scenes in the group `menu_screen` (both screens join it). Running a level directly (F6) still continues from the slot.
