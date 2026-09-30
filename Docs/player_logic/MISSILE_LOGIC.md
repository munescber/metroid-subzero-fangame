Missile Logic
=============

Overview
--------
`Scripts/Player/missile.gd` (`class_name Missile`) is the player's secondary
weapon: a slower, higher-damage projectile that explodes into a small
area-of-effect radius on impact instead of damaging whatever it directly
touches. It lives alongside `Scripts/Player/bullet.gd` and follows the same
physical-body-plus-Hitbox convention described in `HITBOX_HURTBOX.md`, with
one deliberate deviation for the explosion (see "Why not an Area2D for the
explosion?" below).

Files
-----
- `Scripts/Player/missile.gd` — the `Missile` class.
- `Scenes/Player/missile.tscn` — scene: `CharacterBody2D` root + `AnimatedSprite2D`
  + `CollisionShape2D` (physical, world collision) + `Hitbox` (`Area2D`, enemy
  detection).
- `Scripts/Player/player_rundas.gd` — fires missiles from `_try_fire_missile()`.
- `project.godot` — `missile_mode` input action, bound to `I`.

Input & firing (player side)
-----------------------------
- Holding the `missile_mode` action (`I`) switches the `shoot` action (`J`)
  from firing a `Bullet` to firing a `Missile`. `missile_mode` is a **hold**,
  not a toggle — release `I` and `J` goes back to the beam immediately.
- `@export var missile_ammo: int = 5` on the player, exported so it can be
  hand-set per test run in the Inspector.
- `MISSILE_COOLDOWN` (a separate constant from the beam's `SHOOT_COOLDOWN`)
  gates fire rate independently of the beam.
- If `missile_ammo <= 0` when the player tries to fire a missile, nothing is
  spawned and no ammo is consumed — the beam does **not** kick in as a
  fallback.
- When `debug_enabled` is true on the player, it logs:
  - `MISSILE STATE IS ON` / `MISSILE STATE IS OFF` on `missile_mode`
    press/release.
  - `Missiles left: N` after a successful missile fire.
  - `No missile ammo` when firing is attempted with `missile_ammo <= 0`.

Exported tuning fields (`Missile`)
-----------------------------------
- `damage: int` — flat damage applied to everything caught in the explosion.
  There is no separate "direct hit" bonus; hitting an enemy directly just
  triggers the explosion at that spot, same as hitting a wall.
- `start_speed` / `max_speed` — the missile accelerates linearly from
  `start_speed` to `max_speed` over `acceleration_time` seconds, then holds at
  `max_speed` for the rest of its flight.
- `acceleration_time` — seconds to reach `max_speed`.
- `explosion_size` — a `Vector2` used as the size of the rectangular
  area-of-effect damage zone (default `16x16`).
- `explosion_duration` — how long the explosion visual/lifetime lasts before
  the node frees itself. Damage is applied once, immediately on explosion —
  this duration is purely for the animation, not a damage-over-time window.
- `lifetime` — total seconds the missile can fly before self-destructing if it
  never hits anything.

Flight and rotation
--------------------
- `start(dir, shooter_node)` sets `direction`, resets the acceleration/life
  timers, and registers a collision exception with the shooter so the missile
  doesn't immediately explode on the player who fired it.
- The missile sprite art faces "up" by default (same convention as
  `radial_projectile.gd`). Rotation is set with `direction.angle() + PI / 2.0`
  (a `-90°` alignment offset, then flipped `180°`) so the sprite visually
  points the way it's travelling.
- `_physics_process` lerps `current_speed` from `start_speed` to `max_speed`
  based on `accel_timer / acceleration_time`, then calls `move_and_collide`.
  A wall collision calls `explode()` at the collision point.

Explosion trigger
-----------------
A missile explodes from either of two triggers, both of which call the same
`explode(at_position)`:
1. `move_and_collide` reports a physical collision (hit a wall/floor — the
   missile's physical body only collides with the World layer).
2. The child `Hitbox` `Area2D` (`collision_layer = 8`, `collision_mask = 16`)
   fires `area_entered` because it overlapped an enemy `Hurtbox`.

There is no separate "direct hit does more damage" path — both triggers just
relocate the explosion to that impact position and hand off to the same
damage logic.

`explode()` then:
- Sets `has_exploded = true` so `_physics_process` stops moving the missile
  and repeat triggers are ignored.
- Disables the physical `CollisionShape2D` and the `Hitbox`'s `monitoring`
  (both via `set_deferred`, see "Deferred property changes" below).
- Plays the `explode` sprite animation.
- Applies damage immediately (see next section).
- Waits `explosion_duration` seconds (for the animation to finish), then
  `queue_free()`s the whole node.

Why not an Area2D for the explosion? (important gotcha)
---------------------------------------------------------
An earlier version of this script spawned a disabled `ExplosionArea` `Area2D`
sized to `explosion_size`, then flipped `monitoring = true` at explosion time
and read `get_overlapping_areas()` a physics frame later. **This did not
work**, and the failure mode is a general Godot Area2D gotcha worth
remembering:

> An `Area2D` only tracks overlaps that *begin* while its `monitoring` is
> already `true`. If a shape is already overlapping the moment you flip
> `monitoring` on, that overlap is never recorded as an "entered" event, so
> `get_overlapping_areas()` will never report it — even many frames later.

Since the enemy that triggers the explosion is, by definition, already
touching the missile at the exact moment the explosion starts, this is
exactly the case that breaks. Enabling monitoring after the fact silently
missed the very hit that caused the explosion, so nothing ever took damage.

The fix: `_apply_explosion_damage()` uses
`get_world_2d().direct_space_state.intersect_shape()` with a
`PhysicsShapeQueryParameters2D` sized to `explosion_size`, masked to the
Hurtbox layer (`16`). This is a one-off, synchronous query of "what overlaps
this box right now," completely independent of any Area2D
monitoring/enter-tracking state — it reliably finds everything in the
explosion radius, including whatever triggered it.

**Guidance for future AoE/burst-style effects in this project:** prefer
`intersect_shape()` (or `intersect_point`/`intersect_ray` as appropriate) over
a toggled `Area2D` whenever the effect can start already overlapping its own
trigger. A toggled `Area2D` is only safe when you're certain nothing will
already be inside it the instant monitoring turns on.

Damage application
-------------------
`_apply_explosion_damage()` iterates the `intersect_shape()` results and, for
each collider:
- Skips it if its parent is the player (checked by node name `"Player"` /
  `"player_rundas"` or group `"player"`) — the explosion never damages the
  shooter, only enemies.
- Calls `receive_hit(damage, shooter)` on it if it implements that method
  (i.e. it's a `Hurtbox`), which forwards into that entity's normal
  `take_damage()` → `HealthComponent` flow like any other hit — see
  `HITBOX_HURTBOX.md`.
- Damage is applied exactly once per overlapping Hurtbox, in a single pass,
  not on a timer — an enemy standing in the blast at the instant of the query
  takes one hit, and walking into the lingering explosion sprite afterward
  does nothing (the query only runs once, at explosion time).

Deferred property changes (important gotcha)
------------------------------------------------
`collision_shape.set_deferred("disabled", true)` and
`hitbox.set_deferred("monitoring", false)` inside `explode()` use
`set_deferred` rather than a direct assignment. `explode()` can be entered
from `_on_hitbox_area_entered`, which itself fires from inside the physics
engine's collision query flush. Changing physics-related properties directly
from within that callback does not reliably apply before the query
completes; `set_deferred` queues the change to apply safely once the physics
step finishes. If you add more physics-property writes inside `explode()` (or
any other Area2D signal handler in this project), use `set_deferred` for
them too.

Collision layers used
----------------------
Matches the project-wide convention in `HITBOX_HURTBOX.md`:
- Missile physical body: `collision_layer = 8` (Hitbox layer), default
  `collision_mask = 1` (World only).
- Missile `Hitbox`: `collision_layer = 8`, `collision_mask = 16` (detects
  enemy Hurtboxes).
- The explosion damage query itself uses `collision_mask = 16` directly in
  the `PhysicsShapeQueryParameters2D`, matching the Hurtbox layer, with
  `collide_with_areas = true` and `collide_with_bodies = false`.
