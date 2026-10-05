Beam & Charge Beam Logic
========================

Overview
--------
The player's primary weapon fires from the `shoot` action (`J`). It has two
forms:

- **Normal beam (`Bullet`)** — a small, fast projectile. Fired when `J` is
  released after a short hold or a tap.
- **Charge Beam (`ChargeBeam`)** — a larger, stronger projectile. Fired when
  `J` is released after being held for at least `charge_time_required`
  seconds (currently `2.0`).

The Charge Beam is not a separate weapon system. It is a second projectile
scene that reuses the normal beam's script (`ChargeBeam extends Bullet`), and
the player picks which scene to spawn on release. The secondary weapon,
missiles, is documented in `MISSILE_LOGIC.md`.

Player-facing behaviour (non-technical)
----------------------------------------
- Press and hold `J`: nothing is fired yet. A small glowing orb appears at the
  gun and grows and brightens as the charge builds.
- Release `J` early (before the charge is complete): one normal beam shot is
  fired.
- Keep holding until the orb stops growing and starts pulsing and flashing
  quickly: that is the "fully charged" cue. There is no on-screen timer.
- Release `J` while fully charged: the Charge Beam is fired instead of a
  normal shot, and no normal shot is fired as well.
- Holding `J` does not auto-fire. One press-and-release is one shot.
- Pressing `I` (missile mode) while holding `J` cancels the charge, and
  nothing is fired. Pressing `J` while already holding `I` fires a missile as
  before, with no charging.
- The Charge Beam is a bit bigger than the normal shot, deals more damage,
  looks different (animated ring sprite) and leaves a brighter trail. It still
  disappears when it hits a wall or an enemy.
- There is currently no charging or ready sound; the visual flash is the only
  cue.

Where to tune the timer
------------------------
`charge_time_required` in `Scripts/Player/player_rundas.gd`:

```
@export var charge_time_required: float = 2.0
```

It is exported, so it can also be changed in the Inspector on the player node
without editing code. This is the only number that defines how long it takes
to fully charge.

Files
-----
- `Scripts/Player/player_rundas.gd` — input handling, charge state, spawning
  and the charge indicator visual.
- `Scenes/Player/player.tscn` — contains the `Muzzle/ChargeEffect` `Sprite2D`
  used as the charge indicator (hidden by default).
- `Scripts/Player/bullet.gd` (`class_name Bullet`) — shared projectile logic.
- `Scenes/Player/bullet.tscn` — normal beam scene.
- `Scripts/Player/charge_beam.gd` (`class_name ChargeBeam`, `extends Bullet`)
  — intentionally empty apart from the class declaration.
- `Scenes/Player/charge_beam.tscn` — Charge Beam scene.
- `Scenes/Effects/bullet_trail.gdshader` — trail shader used by both scenes.

Input and firing flow (player side)
------------------------------------
State on the player:

| Variable | Meaning |
|---|---|
| `charge_time_required` | seconds the key must be held for a full charge (exported) |
| `is_charging` | `shoot` is being held and a charge is in progress |
| `is_charged` | `charge_time` has reached `charge_time_required` |
| `charge_time` | seconds the current charge has been held |

Flow, driven from `handle_shoot(delta)` every physics frame:

1. `shoot` just pressed:
   - with `missile_mode` held: `_try_fire_missile()`; no charge starts;
   - otherwise: `_start_charge()` (`is_charging = true`, `charge_time = 0`).
   Nothing is spawned on press.
2. `_update_charge(delta)` runs every frame while `is_charging`:
   - if `missile_mode` is now held: `_reset_charge()` and stop (no shot);
   - if `shoot` is no longer held (release):
     - `is_charged`: `_fire_charge_beam()`;
     - otherwise, if `shoot_timer <= 0`: `_fire_bullet()`;
     - then the charge is reset;
   - otherwise add `delta` to `charge_time`; when it reaches
     `charge_time_required`, set `is_charged = true`; update the indicator.
3. `_fire_bullet()` sets `shoot_timer = SHOOT_COOLDOWN` and spawns the normal
   beam. `_fire_charge_beam()` spawns the Charge Beam and does not use or set
   the cooldown.
4. Both go through `_spawn_projectile(scene)`, which instantiates the scene,
   calls `start(aim_direction, self)`, places it at `muzzle.global_position +
   dir * 6` and adds it to the player's parent. The player never touches
   projectile internals, so another beam type only needs a new scene and one
   more `_spawn_projectile(...)` call.

Aiming is unchanged: `get_aim_direction()` is read at the moment of release,
so the beam goes where the player is aiming when `J` is let go.

Charge indicator
-----------------
`_update_charge_visual()` drives the `Muzzle/ChargeEffect` sprite, which
inherits the muzzle's position, so it follows facing and aim:
- While charging: scale goes from `CHARGE_EFFECT_MIN_SCALE` (0.4) to
  `CHARGE_EFFECT_MAX_SCALE` (1.0) and opacity from 0.3 to 0.8, with a gentle
  pulse.
- Fully charged: faster, larger pulse (up to 1.3x) and a brightness flash.
- `_reset_charge()` hides it again.

The sprite uses `z_index = 1` so it draws over the player sprite.

Shared projectile logic (`Bullet`)
-----------------------------------
`bullet.gd` is a `CharacterBody2D` that moves in a straight line with
`move_and_collide`. Tunable per scene through exports:

| Export | Normal beam | Charge Beam |
|---|---|---|
| `speed` | 120 | 120 (default) |
| `lifetime` (seconds) | 2.0 | 2.0 (default) |
| `damage` | 1 | 3 |
| `one_shot` | true | true |

- `start(dir, shooter)` sets direction, resets the lifetime, rotates the node
  to face the direction and adds a collision exception for the shooter.
- Hits are handled the same way for both: the physical body hitting something
  calls `_on_hit`, and the child `Hitbox` (`Area2D`) triggers
  `_on_area_entered` / `_on_body_entered`. Damage goes through
  `Hurtbox.receive_hit(damage, shooter)` or `take_damage`, as described in
  `HITBOX_HURTBOX.md`. With `one_shot` the projectile frees itself after a hit.
- `activation_button.gd` identifies player projectiles with `is Bullet`.
  Because `ChargeBeam extends Bullet`, it triggers buttons too. Keep new beam
  types derived from `Bullet` (or update that check) for the same reason.
- Each frame the bullet adds the distance it moved to `distance_travelled`
  and writes it to the trail shader as `trail_length`.

Charge Beam scene (`charge_beam.tscn`)
---------------------------------------
Separate from `bullet.tscn` on purpose; it has its own:
- `CollisionShape2D` and `Hitbox/CollisionShape2D` (`7 x 7.5`, versus the
  normal beam's `4.75 x 5`), as separate shape resources;
- `AnimatedSprite2D` with a 4-frame ring animation (`idle`, from `beams.png`
  cells `(0,16)`..`(24,16)`), drawn at scale `1.5`;
- `Trail` node and material.

Node names (`AnimatedSprite2D`, `Hitbox`, `Trail`) and the `idle` animation
must stay the same as in `bullet.tscn`, because `bullet.gd` looks them up by
path.

Collision layers match the normal beam: body `collision_layer = 8`, default
mask (World), and `Hitbox` `collision_layer = 8`, `collision_mask = 16`
(enemy Hurtboxes). See `HITBOX_HURTBOX.md`.

Trail effect
------------
`bullet_trail.gdshader` is a `canvas_item` shader on a `Sprite2D` (`Trail`)
that sits behind the projectile (`show_behind_parent`). It draws a few
progressively smaller and more transparent solid circles along local `-X`,
which is the direction opposite to travel because the whole projectile is
rotated toward its direction.

Uniforms:
- `tint` — colour (solid; only opacity changes between copies).
- `copies` — number of circles (3 for both beams).
- `spacing` — distance in pixels between circle centres.
- `start_radius`, `scale_falloff` — radius of the first circle and the
  per-copy multiplier.
- `start_alpha`, `alpha_falloff` — opacity of the first circle and the
  per-copy multiplier.
- `trail_length` — set from code; a circle only appears once the projectile
  has travelled far enough to reach its position, so the trail grows out of the
  muzzle instead of appearing fully formed.

| Parameter | Normal beam | Charge Beam |
|---|---|---|
| `tint` | `#3cbcfc` | light cyan `(0.7, 0.93, 1.0)` |
| `spacing` | 5 | 7 |
| `start_radius` | 3.5 | 5.5 |
| `scale_falloff` | 0.75 | 0.8 |
| `start_alpha` | 0.6 | 0.7 |
| `alpha_falloff` | 0.55 | 0.6 |

Things to remember:
- The material is `resource_local_to_scene = true`. Without it every
  projectile would share one material and the same `trail_length`.
- The trail's texture (a placeholder `GradientTexture2D`) only provides the
  drawing area. It must be large enough to contain all circles, otherwise
  they get clipped: `24 x 8` for the normal beam, `40 x 16` for the Charge
  Beam, with an `offset` that places the right edge at the projectile.
- The trail is a straight line behind the projectile. It would not curve for
  bouncing or homing projectiles.

Adding another beam type
-------------------------
1. Create a new scene with the same node layout as `bullet.tscn`, its own
   collision shapes, sprite and trail material (set the exported `damage`,
   `speed` and `lifetime` on the root).
2. Give it a script that `extends Bullet` (even an empty one with a
   `class_name`).
3. Preload it in `player_rundas.gd` and call `_spawn_projectile(scene)` from
   wherever it should be chosen.

Gotchas
-------
- Because the normal beam now fires on release, there is a short delay
  between pressing and shooting, and the `0.2s` `SHOOT_COOLDOWN` still applies
  to normal shots. Very fast taps can therefore be skipped. The Charge Beam
  ignores the cooldown.
- If `charge_time_required` is set to `0`, the beam is armed on the first
  frame of the hold, so every release fires the Charge Beam.
- Changing `speed` / `lifetime` is done through the exports, not constants.
  Older code that referenced `Bullet.SPEED` / `Bullet.LIFETIME` would no longer
  work (none exists in the project today).
