# Zoomer — Logic Reference

Reference for the current implementation in `Scripts/Enemies/zoomer.gd`. This describes what the code actually does (not a design proposal).

Script: `Scripts/Enemies/zoomer.gd`
Scene: `Scenes/Enemies/zoomer.tscn`

The Zoomer is a simple ground enemy. It walks back and forth between patrol points, takes gravity, and damages the player on contact. It has no state machine, no player detection and no attacks.

## Scene Structure

`zoomer` (`CharacterBody2D`, layer 4, default mask)
- `CollisionShape2D`: 14x14 rectangle.
- `AnimatedSprite2D`: 16x16 frames. `idle` has 4 frames at 5 fps (the one played), and `idle_2` has 2 frames at 3 fps (unused).
- `ContactDamage` (`Area2D`, script `hitbox.gd`): layer 8, mask 16.
- `Hurtbox` (`Area2D`, script `hurtbox.gd`): layer 16, mask 8.
- `Timer` (one-shot), connected to `_on_timer_timeout`.
- `PatrolPoints` is **not** part of the scene. Each level must add a `PatrolPoints` child with at least two `Marker2D` nodes, or assign the `patrol_points` NodePath.

## Initialization (`_ready`)

1. Plays the `idle` animation.
2. Creates a `HealthComponent` at runtime with `max_health` (5) and connects `damaged` and `died`. It is not a scene node, unlike the other enemies.
3. Resolves the patrol node from the `patrol_points` NodePath, falling back to a child named `PatrolPoints`.
4. Reads every `Marker2D` child's **global position** into `point_positions`. These positions are captured once at `_ready`.
5. If there are fewer than two points, it logs an error and returns.
6. Configures `ContactDamage` with `damage = contact_damage` (1), `one_shot = false` and `source = self`.

## Movement

Each physics frame: `apply_gravity(delta)`, then `patrol()`, then `move_and_slide()`.

- **Gravity** uses the project default and is only added when not on the floor.
- **Patrol** (`patrol()`):
  - It targets `point_positions[current_point_index]` and compares **x only**.
  - When within 2px of the target on the x axis, it advances to the next point (wrapping back to the first).
  - It sets `direction = sign(target.x - global_position.x)` and `velocity.x = direction * SPEED` (30, a constant).
  - `sprite.flip_h = direction > 0`, so the art faces left by default.
- There is no wall or ledge detection. The Zoomer only turns at patrol points.

## Damage & Death

- `take_damage()` forwards to the runtime `HealthComponent`. The `Hurtbox` calls it when a projectile hits.
- On damage, the sprite flashes red and `Timer` starts for 0.12s. `_on_timer_timeout` resets the modulate to white.
- Contact damage comes from `ContactDamage` (continuous, 1 damage). The player's invulnerability window limits how often it lands.
- On death:
  - `DropManager.try_drop(self, drop_table)` runs.
  - `is_dying` is set, all `CollisionShape2D` nodes are disabled and all `Area2D` nodes stop monitoring (deferred).
  - `Timer` starts for 0.18s, and `_on_timer_timeout` then calls `queue_free()`.
  - There is no death animation or fade.

## Exports

| Export | Default |
|---|---|
| `max_health` | 5 |
| `contact_damage` | 1 |
| `patrol_points` (NodePath) | empty (falls back to a `PatrolPoints` child) |
| `drop_table` | null (uses the default `DropManager` table) |
| `debug_enabled` | false |

`SPEED` (30) is a constant, not an export.

## Known Limitations / Room for Improvement

- **Crash risk:** if `_ready` returns early (no patrol node, or fewer than two points), `point_positions` stays empty, and `patrol()` then indexes an empty array every frame. Guard `_physics_process` or disable the node instead.
- **Shared timer:** the damage flash and the death delay both use `Timer`. A hit just before death can restart it at 0.12s, which changes how long the corpse lingers.
- **Dead enemies keep patrolling:** nothing stops `patrol()` during the 0.18s death delay, so the corpse keeps sliding while its collisions are off.
- **x-only patrol:** a point on a different height, or a gap between points, leaves the Zoomer stuck on a ledge or against a wall with no turn-around. Add `is_on_wall()` and ledge checks.
- **Patrol points are read in global space once.** Moving the enemy's parent afterwards leaves the points behind, and it could jitter when two points are within 2px of each other.
- **No wall crawling:** it is a flat floor walker, unlike the classic Metroid Zoomer.
- **Unused `idle_2` animation and no hit or death animation.**
- **Inconsistent setup:** the `HealthComponent` is created in code, and `ContactDamage` uses `hitbox.gd` with a `has_method("set")` guard. Other enemies use a scene node and `contact_damage.gd`. Matching them would make all enemies easier to maintain.
