# Rhinobug — Logic Reference

Reference for the current implementation in `Scripts/Enemies/rhinobug.gd`. This describes what the code actually does (not a design proposal).

Script: `Scripts/Enemies/rhinobug.gd`
Scene: `Scenes/Enemies/rhinobug.tscn`

Rhinobug is the simplest enemy in the project: a grounded patroller that walks back and forth between exported `Marker2D` patrol points, with no attack or detection logic of its own (contact damage only).

## Initialization (`_ready`)

- Plays the `"walk"` animation unconditionally — there's no idle/other animation state.
- `HealthComponent` is **not** a scene child like the other enemies; it's instantiated in code (`HealthComponent.new()`), configured with `max_health`, and added as a child at runtime.
- Patrol points are resolved from the exported `patrol_points` `NodePath`; if that path is empty/invalid, it falls back to looking for a child literally named `"PatrolPoints"`.
- Every `Marker2D` child under the resolved patrol node has its `global_position` collected into `point_positions`. Non-`Marker2D` children are ignored (logged if `debug_enabled`).
- Requires **at least 2** patrol points — `push_error`s and returns early (no movement) otherwise. Missing/unassigned patrol node is also a hard `push_error` with no movement.
- Configures the `ContactDamage` child (if present) with `damage = contact_damage`, `one_shot = false`, `source = self` — contact damage is otherwise fully handled by the `Hitbox`/`ContactDamage` script, not by Rhinobug itself.

## Movement — Patrol Only

- No detection, no seeking, no attacks — Rhinobug is unaware of the player entirely. It only ever walks its patrol loop.
- Gravity is applied manually each physics frame (`apply_gravity`) using the project's default 2D gravity, only while not `is_on_floor()`.
- `patrol()` logic:
  - Compares horizontal distance to the current target point; if within `2.0px`, advances `current_point_index` (wrapping back to `0` after the last point — the loop is a cycle, not ping-pong).
  - Sets `direction = sign(target.x - global_position.x)` and horizontal velocity to `direction * SPEED` (`SPEED` is a constant `40.0`, not exported/tunable).
  - Flips the sprite (`sprite.flip_h`) based on movement direction.
- Movement only considers the X axis for targeting; Y is left entirely to gravity/`move_and_slide()`.

## Damage & Death

- `take_damage()` is a thin shim that forwards to `health_comp.take_damage()` if the component exists.
- `_on_health_damaged`: flashes the sprite to a light red tint (`Color(1, 0.5, 0.5, 1)`) and starts `timer` for `0.12s`, which resets the tint back to white on timeout (`_on_timer_timeout`) — unless the enemy is dying, in which case the same timer firing triggers `queue_free()` instead.
- `_on_health_died`: sets `is_dying = true`, disables every `CollisionShape2D` child and stops monitoring on every `Area2D` child (deferred), then restarts `timer` for `0.18s` before despawning. There is **no fade-out or death animation** — the sprite just disappears via `queue_free()` once the timer elapses. If `timer` is somehow null, despawns immediately instead.

## Key differences vs. other enemies

- Only enemy that is **not** a flier and has no player-awareness of any kind (no detection radius, no seek/haunt state).
- Only enemy whose `HealthComponent` is added programmatically at runtime rather than being a pre-placed scene node.
- Only enemy with no death fade/animation — despawn is instant once the short post-hit timer elapses.
- Has no `debug_enabled`-gated state-machine logging beyond patrol-point setup, since there is no state machine — movement is a single linear patrol loop.
