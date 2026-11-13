# Player Sequence (Mission Start / Continue)

Autoload `PlayerSequence` (`Scripts/Managers/player_sequence.gd`). Shows the player front-facing with a music cue.

| Type | Triggered by | Cue | Length |
|---|---|---|---|
| `MISSION_START` | `SaveManager.start_new_game`, `continue_game` (main menu CONTINUE, mission-complete screen), `continue_from_save` (save loaded into a running level) | `mission_start` (full intro) | cue length (min 1.5 s), 3 s if no asset |
| `MISSION_CONTINUE` | `SaveManager.retry_after_death` (TRY AGAIN with a save) | `mission_continue` (sting) | 1.5 s |

Room transitions never queue a sequence. `retry_after_death` with no save starts a new game, so it plays MISSION_START.

## Flow
`queue(type)` is called just before the scene switch. It waits for the new level, its player, and the end of the SceneTransition fade (so the save position is already restored), then:
`Player.begin_presentation()` → `AudioManager.play_jingle()` → timer → `Player.end_presentation()`.
A new `queue()`, `cancel()`, or the player leaving the tree stops the sequence at once and restores the player. Unconsumed requests expire after 8 s.

## Player side
`begin_presentation()` turns off `_physics_process` and input (movement, jump, shoot, charge, dash and `update_animation` all live there), zeroes velocity, makes the player invulnerable and plays `face_forward`. `end_presentation()` restores `flip_h`, the previous invulnerability, plays `idle` and resumes. Position, health, ammo and save data are never touched.

## Assets still needed
- Player SpriteFrames animation **`face_forward`** (front-facing pose, loop or one-shot; a one-shot holds its last frame). Until it exists the idle pose is held and a warning is printed.
- `Audio/Music/mission_start.(ogg|wav|mp3)` and `Audio/Music/mission_continue.(ogg|wav|mp3)`. Missing files are skipped silently; timing still runs.

## Audio
`AudioManager.play_jingle(stream)` plays on the Music bus and ducks the background music by 12 dB while it runs. The background track is never stopped or restarted.
