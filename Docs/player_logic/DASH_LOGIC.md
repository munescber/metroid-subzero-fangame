Dash Logic
==========

Overview
--------
The player has a short horizontal dash on the `dash` action (`K`). It is a
fixed-distance burst of movement in the direction the player is facing. It
works on the ground and in the air.

Player-facing behaviour (non-technical)
----------------------------------------
- Press `K`: the player stops for a very short moment (a brief "hang"), then
  shoots forward a short distance in a perfectly straight horizontal line.
- In the air, the jump or fall is cancelled the moment `K` is pressed. The
  player stays at the same height for the whole dash, then falls normally
  afterwards, with none of the old jump/fall speed left over.
- A trail of faint, blue-tinted copies of the player fades out behind the dash.
- Left/right and jump input are ignored while dashing.
- Only the player is "slowed": the slower dash and the hang give a slow-motion
  feel, but the rest of the game (enemies, timers, camera) runs at normal speed.
- After a dash you must wait `DASH_COOLDOWN` seconds to dash again.
- Taking damage cancels the dash, so the knockback is felt.

Where to tune it
----------------
Constants at the top of `Scripts/Player/player_rundas.gd`:

| Constant | Meaning |
|---|---|
| `DASH_DISTANCE` | Pixels travelled during the burst (`48`). |
| `DASH_SPEED` | Pixels per second during the burst (`330`). |
| `DASH_COOLDOWN` | Seconds before the next dash can start (`1.0`). |
| `DASH_WINDUP` | Seconds of hang before the burst (`0.06`). |
| `DASH_AFTERIMAGE_INTERVAL` | Seconds between afterimages (`0.03`). |

Afterimage look (fade time, start opacity, tint) is set in
`Scripts/Player/dash_afterimage.gd`.

Files
-----
- `Scripts/Player/player_rundas.gd` — dash state and logic
  (`handle_dash`, `_start_dash`, `_update_dash`, `_end_dash`,
  `_spawn_afterimage`).
- `Scripts/Player/dash_afterimage.gd` (`class_name DashAfterimage`) — one fading
  copy of the player.
- `Scenes/Player/dash_afterimage.tscn` — a single `Sprite2D` with that script.
- `project.godot` — the `dash` input action.

How it works
------------
State on the player: `is_dashing`, `dash_remaining_distance`, `dash_direction`,
`dash_cooldown_timer`, `dash_windup_timer`, `dash_afterimage_timer`.

**Starting.** `handle_dash` ticks the cooldown every frame. A dash starts when
`dash` is just pressed, the cooldown is 0 and the knockback lock is not active.
`_start_dash` stores the facing direction (`flip_h` → left, otherwise right),
fills `dash_remaining_distance`, starts the cooldown and the windup, and sets
`velocity = Vector2.ZERO`.

**Cancelling vertical momentum.** The whole velocity is zeroed on start, and
`velocity.y` is forced to 0 on every dash frame. Gravity is skipped while
dashing and `handle_jump` returns early. Just turning gravity off is not
enough: the old `velocity.y` would still move the player diagonally and would
come back when the dash ends.

**Windup (the hang).** For `DASH_WINDUP` seconds velocity stays at zero, so the
player visibly freezes in place before the burst. Nothing else is slowed.

**Burst.** After the windup, `velocity.x = dash_direction * DASH_SPEED` each
frame and `DASH_SPEED * delta` is subtracted from `dash_remaining_distance`.
At `330` px/s the `48` px dash lasts about 0.15 s, so total time is roughly
windup + 0.15 s. Dash code only sets velocity; the single
`move_and_slide()` in `_physics_process` does the movement. Calling it a second
time would move the player twice per frame.

**Ending.** `_end_dash` sets `is_dashing = false` and zeroes velocity. It is
called when:
- the distance is used up (in `_update_dash`),
- the player touches a wall (checked after `move_and_slide()`, and not during the
  windup, so standing next to a wall does not instantly cancel the dash),
- the player takes damage (`take_damage`).

Because velocity is zero afterwards, an airborne player starts falling from
zero speed and normal movement resumes next frame.

**Cooldown.** It starts when the dash starts (not when it ends) and counts down
in `handle_dash` using `delta`.

**Order in `_physics_process`.** gravity → jump → aim → shoot → `handle_dash`
→ horizontal movement (skipped while dashing) → `move_and_slide()` → wall check.
If jump and dash are pressed on the same frame, the dash start zeroes the jump
velocity, so the dash wins.

Slow-motion: why it is local
-----------------------------
`Engine.time_scale` was deliberately not used. It would also slow enemies,
the camera smoothing and every `create_timer` await (Phantoon, Ghost Covern,
missiles), and it would need to be reset on death or scene change. The feel is
produced locally instead: a moderate `DASH_SPEED` plus the short hang before
the burst. Lower `DASH_SPEED` or raise `DASH_WINDUP` for more of the effect.

Afterimages
-----------
- While bursting, `_update_dash` calls `_spawn_afterimage` every
  `DASH_AFTERIMAGE_INTERVAL` seconds (the first one on the first burst frame).
- The afterimage is added to the player's parent, not the player, so it stays
  where it was spawned instead of moving with the player (same approach as
  projectiles).
- `DashAfterimage.setup` copies the player's current animation frame
  (`sprite_frames.get_frame_texture`), position, scale, `flip_h` and offset, so
  it works facing either direction and for any animation. It is drawn one
  `z_index` below the player, tinted and semi-transparent.
- On `_ready`, a `Tween` fades `modulate:a` to 0 over `FADE_TIME`, then calls
  `queue_free`, so copies remove themselves.
- It has no collision and no logic, so it cannot interact with enemies.
- No shader is used. A tinted, fading sprite is enough here.
