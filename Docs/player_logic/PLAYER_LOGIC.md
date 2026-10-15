Player Logic
============

Overview
--------
The player is `player_rundas`, a `CharacterBody2D` in `Scenes/Player/player.tscn`
driven by `Scripts/Player/player_rundas.gd`. This file describes how the
whole controller fits together. The details of the dash, the missile and the
beams are in their own files: `DASH_LOGIC.md`, `MISSILE_LOGIC.md` and
`BEAM_LOGIC.md`.

Controls
--------
| Action | Key | Used for |
|---|---|---|
| `left` / `right` | `A` / `D` | Walk, and facing direction. |
| `up` | `W` | Aim diagonally up. |
| `down` | `S` | Aim diagonally down (only while airborne). |
| `jump` | `Space` | Jump (hold for a higher jump). |
| `shoot` | `J` | Fire a bullet, or hold to charge the beam. |
| `missile_mode` | `I` | Hold it and press `shoot` to fire a missile. |
| `dash` | `K` | Dash. |

Scene structure
---------------
- `player_rundas` (`CharacterBody2D`, collision layer 2 "PlayerBody") — the
  script lives here.
  - `CollisionShape2D` — the body's collision with the world.
  - `Camera2D` — follows the player, zoom 4, smoothing on, offset `(0, -20)`.
  - `Muzzle` (`Marker2D`) — where projectiles spawn. It is mirrored and rotated
    with the facing and aim direction.
    - `ChargeEffect` (`Sprite2D`) — the visual shown while charging.
  - `AnimatedSprite2D` — animations `idle`, `walk`, `jump`, `fall`.
  - `Hurtbox` (`Area2D`, layer 16, mask 8, `Scripts/Common/hurtbox.gd`) — takes
    damage from enemy hitboxes.

Other scripts and scenes look for the player by its node name (`player_rundas`
or `Player`). **Do not rename the root node** without
updating `atomic.gd`, `missile.gd`, `contact_damage.gd`, `radial_projectile.gd`
and `bouncing_fireball.gd`.

Physics loop
------------
`_physics_process` runs these steps in order:

1. `apply_gravity`
2. `handle_jump`
3. `handle_aim`
4. `handle_shoot` (bullet, charge beam and missile)
5. `handle_dash`
6. Knockback lock timer, or `handle_horizontal_movement` (skipped while
   dashing or locked by knockback)
7. `update_animation`
8. Invulnerability blink and timer
9. `move_and_slide()` — the **only** place that moves the body
10. Wall check that ends a dash

All systems only change `velocity`. Calling `move_and_slide()` more than once
per frame would move the player twice.

Horizontal movement
-------------------
- Walking sets `velocity.x = direction * MOVE_SPEED` (`75`) directly, with no
  acceleration. Releasing the keys stops the player right away
  (`move_toward` with the same speed). Air control is the same as ground
  control.
- The sprite flips (`flip_h`) with the direction. The sprite art is assumed to
  face right by default.

Jump and gravity
----------------
Tuning variables at the top of `player_rundas.gd`:

| Variable | Default | Meaning |
|---|---|---|
| `jump_velocity` | `-320` | Initial upward speed in px/s. |
| `jump_release_multiplier` | `0.5` | Fraction of upward speed kept when the jump button is released while rising. |
| `jump_gravity` | `800` | The player's own gravity in px/s². It is independent of the project's `default_gravity`, which other bodies such as the rhinobug still use. |
| `apex_gravity_multiplier` | `0.65` | Gravity scale near the apex. `1.0` disables it. |
| `apex_velocity_threshold` | `60` | The apex band: gravity is scaled while `abs(velocity.y)` is below this value. |
| `max_fall_speed` | `400` | Terminal downward speed in px/s. |

**Gravity.** `apply_gravity` is the only place gravity is applied. It does
nothing while dashing or on the floor. Otherwise it adds `jump_gravity * delta`
(scaled by `apex_gravity_multiplier` inside the apex band) and clamps the result
to `max_fall_speed`. The cap only limits downward speed, so knockback and jumps
(upward) are never reduced by it.

**Soft apex.** Near the top of a jump the vertical speed passes through the band
around zero, where gravity is lower, so the player hangs for a short time. It
applies to tap jumps and held jumps alike. It only changes acceleration, never
velocity, so it cannot undo the jump cut.

**Variable jump height.** The jump always starts at full `jump_velocity` when
`jump` is just pressed and the player is on the floor. `is_jump_rising` is set
at that moment. If the button is released while the player is still rising,
`velocity.y` is multiplied once by `jump_release_multiplier` and the flag is
cleared, giving a shorter jump. The flag is also cleared at the apex (when
`velocity.y` becomes non-negative), when a dash starts and when damage is taken,
so the cut can never affect a fall, a dash or a knockback hop.

**Ceiling.** `move_and_slide()` zeroes `velocity.y` when the player hits a
ceiling. The next frame starts from zero speed, which is inside the apex band,
so the descent begins gently and then speeds up like any other apex. Nothing in
the script adds extra gravity after a bonk.

Approximate result with the defaults (60 physics ticks per second): a full jump
reaches about 62 px and lasts about 0.87 s, of which about 0.23 s is spent in
the apex band. There is no coyote time or jump buffering; the jump needs
`is_on_floor()` on the frame it is pressed.

Aiming and shooting
-------------------
- `get_aim_direction` returns a normalised vector. The horizontal part is always
  the facing direction, so aiming is never straight up. Holding `up` aims 45°
  up. Holding `down` aims 45° down, but only while not on the floor.
- The muzzle position and rotation are updated from this direction every frame.
- Projectiles are instantiated with `start(direction, player)` and spawned
  6 px ahead of the muzzle in the aim direction, added to the player's parent
  (not the player) so they do not move with it.

**Bullet and charge beam.** Pressing `shoot` starts a charge. On release:
- if the charge time reached `charge_time_required` (`1.0` s), the charge beam
  is fired;
- otherwise a normal bullet is fired if the shoot cooldown
  (`SHOOT_COOLDOWN`, `0.20` s) has finished.

While charging, the `ChargeEffect` sprite grows and fades in, then pulses once
the beam is ready. Holding `missile_mode` while charging cancels the charge.

**Missile.** Pressing `shoot` while holding `missile_mode` fires a missile
(`MISSILE_COOLDOWN` `0.6` s, one ammo per shot, `missile_ammo` defaults to
`100`). Nothing fires when ammo is 0.

Dash
----
A fixed-distance horizontal burst on `K`. While dashing, gravity and jumping are
skipped, `velocity.y` is held at zero and horizontal input is ignored. It ends
when the distance is used, on touching a wall, or when damage is taken, and
leaves no leftover velocity. See `DASH_LOGIC.md` for the full description.

Health, damage and knockback
----------------------------
- `HealthComponent` is created in `_ready` with `max_health` (`100`) and
  connected to the `damaged` and `died` signals.
- `take_damage(amount, source)` is called by the hurtbox and by enemies.
  - It does nothing while the player is invulnerable.
  - It cancels an active dash so the knockback is not overwritten.
  - Knockback: `velocity.x` is pushed away from `source` by `knockback_x`
    (`140`), and `velocity.y = -knockback_y` (`160`). Without a source the
    knockback is straight up.
  - `knockback_lock_timer` (`knockback_lock_duration`, `0.2` s) disables
    horizontal input so the knockback is visible, and also blocks starting a
    dash.
  - `is_jump_rising` is cleared so releasing jump cannot cut the knockback hop.
  - The player becomes invulnerable for `invulnerability_time` (`0.8` s). During
    that time the sprite blinks (alpha 0.5, every `0.08` s).
- On `died`, physics processing stops and velocity is zeroed. There is no death
  animation or game-over handling yet.
- `player_damage_taken` and `debug_enabled` are only debugging aids.

Animation
---------
`update_animation` runs every physics frame:

| Condition | Animation |
|---|---|
| Not on the floor, not dashing, moving up (`velocity.y < 0`) | `jump` |
| Not on the floor, not dashing, otherwise | `fall` |
| Not on the floor, dashing | Keeps the current animation (the dash zeroes `velocity.y`, which would otherwise switch to `fall`). |
| On the floor, `velocity.x != 0` | `walk` |
| On the floor, standing still | `idle` |

Calling `play` with the animation that is already playing does not restart it,
so calling it every frame is safe.

Previous (archived) player scene
--------------------------------
The 16x16 version of the player, before the larger sprite work, is kept for
reference:

- `Scenes/Player/Archive/player_v1.tscn` — copy of the scene as it was on `main`
  (animations `idle`, `jump`, `walk`; collision `9x15`; muzzle at `(7, 3)`).
  Nothing instances it, so it has no effect in the game.
- Git tag `player-v1-16px` — the exact repository state before the changes.

The archive shares `player_rundas.gd` with the live scene, so it can drift if the
script starts relying on the new sprites (for example the `fall` animation). Use
the git tag if you need the exact old behaviour. `Scenes/Player/player.tscn`
keeps its UID, so every level still instances the live scene.

Files
-----
- `Scripts/Player/player_rundas.gd` — all player logic.
- `Scenes/Player/player.tscn` — the live player scene.
- `Scenes/Player/Archive/player_v1.tscn` — the archived 16x16 player.
- `Scripts/Player/bullet.gd`, `charge_beam.gd`, `missile.gd`,
  `dash_afterimage.gd` and their scenes in `Scenes/Player/`.
- `Scripts/Common/hurtbox.gd` — the player's hurtbox.
- `Scripts/Deprecated/player_legacy.gd` — an older controller, not used.
- `project.godot` — the input actions listed above.
