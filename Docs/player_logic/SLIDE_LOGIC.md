Slide Logic
===========

Overview
--------
The player has a ground slide: a quick low burst that fits through passages too
small for the standing body. It starts with `S + K` while standing on the floor
(`dash` + `down`, no new input action). In the air `S + K` is still the downward
dash; see `DASH_LOGIC.md`.

The slide is locked together with the dashes: it needs `dash_unlocked` on the player
(set by collecting the `DashPowerup`, or ticked in the Inspector for testing).

Player-facing behaviour (non-technical)
----------------------------------------
- Press `K` while holding `S` on the ground: the player drops into a low pose
  and slides forward in the direction they face. `S` does not have to stay held.
- The first part of the slide is a fixed burst (`slide_duration`). If the player
  is still under a low ceiling when it ends, the slide **keeps going at the same
  speed** until they have left the low passage and there is room to stand. The
  player never stops and waits, and never stands up inside the ceiling.
- A wall stops the slide at once. Under a low ceiling with a wall ahead (a dead
  end) the player can press the opposite direction to turn around and slide out.
- While sliding the player cannot jump, shoot, charge, dash, or turn around
  (except the dead-end turn above).
- After standing, `slide_cooldown` seconds must pass before the next slide. This
  cooldown is separate from the dash cooldown.
- A hit during a slide keeps the player low until it is safe to stand; the
  normal knockback and hit-lock still apply, and a slide cannot start while the
  knockback lock is active.

Where to tune it
----------------
Exports on the player (`Scenes/Player/player.tscn`, inspector groups):

| Export | Meaning |
|---|---|
| `slide_speed` | Pixels per second while sliding and recovering (`180`). |
| `slide_duration` | Seconds of the initial burst (`0.45`). Not a limit: the slide goes on while the player cannot stand. |
| `slide_cooldown` | Seconds after standing before the next slide (`0.5`). |
| `slide_collision_size` | Size of the slide collision, body and hurtbox (`16 x 9.5`). |

`slide_collision_size.y` should stay slightly below the narrowest gap to slide
through: `9.5` fits a 10 px gap, and an exact fit jams on the physics safe
margin. A one-tile tunnel (16 px) has plenty of room. The bottom edge is
aligned with the standing shape at startup, so the position typed into the
`SlideCollisionShape2D` nodes in the scene is overridden.

Collision
---------
Two shapes exist under the single `CharacterBody2D`, and exactly one is enabled:

| State | Body | Hurtbox |
|---|---|---|
| Standing | `CollisionShape2D` (14 x 29: 7 x 14.5 at scale 2) | `Hurtbox/CollisionShape2D` |
| Slide / recovery | `SlideCollisionShape2D` | `Hurtbox/SlideCollisionShape2D` |

`set_slide_collision_active(bool)` swaps all four. It must not be called from a
physics callback (signals such as `take_damage`); `take_damage` only changes the
state and never swaps shapes.

How it works
------------
State: `slide_state` (`SlideState.NONE`, `SLIDING`, `SLIDE_RECOVERY`),
`slide_direction`, `slide_timer`, `slide_cooldown_timer`. `is_dashing` and the
dash code are unchanged.

**Starting.** `handle_slide` runs right after `apply_gravity`. A slide starts when
`dash` is just pressed, `down` is held, the player is on the floor, not dashing,
not under knockback lock, the slide cooldown is 0, and the slide shape fits at
the current position. `handle_dash` ignores grounded `S + K` (and every dash
press while a slide is active), so the ground dash never starts instead.

**SLIDING.** `velocity.x = slide_direction * slide_speed` each frame for
`slide_duration`. It ends early on a wall or when the floor is lost.

**Ending and clearance.** After `move_and_slide`, `_update_slide_after_move`
decides what happens, using the final position of the frame. At the end of the
burst it asks `_shape_fits(normal_shape)`. If the standing shape fits, the player
stands (`_end_slide`: normal shape on, slide shape off, `velocity.x = 0`, cooldown
starts). If not, the state becomes `SLIDE_RECOVERY`: the slide shape stays, the
player keeps moving, and the same check runs every frame until it passes.

**The clearance query.** `_shape_fits` calls `intersect_shape` on the physics
space with the player's own RID excluded, the player's collision mask, bodies
only. The query uses the shape's real size (scale included) at its global
position, `SLIDE_CLEARANCE_MARGIN` wider on the sides and top (more than the
engine's 0.08 px safe margin, so enabling the shape never triggers a push-out)
and `SLIDE_FLOOR_TOLERANCE` shorter at the bottom (the player rests slightly
above the floor). Nothing is ever repositioned to resolve an overlap.

**Restrictions.** `handle_jump`, `handle_shoot` (which also drops a charge in
progress), `handle_horizontal_movement` and `handle_dash` return early while
`slide_state != NONE`. The walking sound is muted.

**Damage.** `take_damage` moves `SLIDING` to `SLIDE_RECOVERY` (the short shape stays
and the standing check decides when to stand). While `knockback_lock_timer` is
active the slide does not overwrite the knockback velocity.

Animation
---------
The animation is `slide` (constant `SLIDE_ANIM`); it must be added to the
`AnimatedSprite2D` SpriteFrames by hand. `update_animation` plays it from its first
frame when the slide begins and does not restart it during the burst or the
recovery (a looping animation loops, a non-looping one holds its last frame).
The `hurt` pose still has priority, like for every other pose, and `slide`
returns after it. When the player stands up, the normal animation logic
(`idle`, `walk`, `fall`, ...) takes over. Without a `slide` animation the normal
poses are used and a warning is printed once.

Room transitions and camera
---------------------------
Neither depends on the collision shape. `RoomCamera` uses `player.global_position`
and freezes the player with `process_mode` during a transition, which pauses the
slide state and timers and resumes them afterwards.

Files
-----
- `Scripts/Player/player_rundas.gd` — `handle_slide`, `_start_slide`,
  `_update_slide_after_move`, `_end_slide`, `_steer_recovery`, `_shape_fits`,
  `set_slide_collision_active`, and the layout of the slide shapes.
- `Scenes/Player/player.tscn` — `SlideCollisionShape2D` under the body and under
  `Hurtbox`.
