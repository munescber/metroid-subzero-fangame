# Ghost Covern — Logic Reference

Reference for the current implementation in `Scripts/Enemies/ghost_covern.gd`. This describes what the code actually does (not a design proposal).

Script: `Scripts/Enemies/ghost_covern.gd` (`class_name GhostCovern`)
Scene: `Scenes/Enemies/ghost_covern.tscn`

The Ghost Covern is a pure flier that wanders, hovers near the player through the `player` group, and periodically phases out (intangible) so projectiles and the player pass straight through it.

## State Machine

```gdscript
enum State { WANDERING, HAUNTING, DEAD }
```

- Intangibility is **not a state**. It is an overlay flag (`is_intangible`) on top of `WANDERING`/`HAUNTING`, so the ghost keeps moving and chasing while phased out.
- No gravity is applied during `WANDERING` or `HAUNTING`. Gravity (`200.0 * delta`) only appears in the death sequence, to make the corpse drop.
- Everything runs in `_physics_process`: death timer or intangibility timers, then the state update, then `_update_visuals`, then `move_and_slide()`.

## WANDERING

- Active only if `enable_wandering` is true; otherwise velocity is zeroed and the ghost holds position.
- If `enable_detection` and `enable_haunting` are both true, calls `check_player_detection()`. Once `player_detected` is set, it transitions to `HAUNTING`.
- Otherwise it moves toward `wander_target`, blending with `current_velocity.lerp(target_velocity, acceleration * delta / wander_speed)`.
- Picks a new `wander_target` when within 10px of it or when `wander_choose_interval` (2s) elapses. The target is a random point within `wander_radius` of the ghost's *current* position (not a fixed anchor).

## HAUNTING

- Active only if `enable_haunting` is true; otherwise velocity is zeroed.
- If the player reference is null or freed, clears `player_detected` and falls back to `WANDERING`.
- Disengages back to `WANDERING` once the player is farther than `disengage_radius` (220). Detection uses `detection_radius` (160), so the two radii differ to avoid flicker at the boundary.
- Movement (`haunting_movement`) is a soft standoff: the ghost is meant to be an exploration nuisance, not a rammer. `current_velocity` is blended toward a target velocity with `lerp(..., haunt_smoothing * delta)`:
  - Each ghost has its own `hover_angle` (random at spawn), and aims for the **hover point**: a spot on a ring of radius `preferred_distance` (20) around the player at that angle. Different ghosts therefore settle at different sides of the player instead of stacking.
  - It moves toward the hover point at `haunt_speed`, scaled down linearly over the last `standoff_slow_range` (40px) so it eases to a stop.
  - `hover_angle` drifts by `hover_angle_drift` rad/s (0.4) in a random direction per ghost (`hover_drift_dir`), so the ghosts slowly orbit the player instead of freezing.
  - If the ghost is closer to the player than `preferred_distance - standoff_deadzone` (14), it drifts back out at 30% of `haunt_speed`.
  - `_separation_push()` is added to the target velocity (see Crowding).
- `preferred_distance` sits just outside the ~15px contact radius, so contact damage still lands when the player walks into it or it drifts into them. Raise it to make the ghost harmless unless approached.

## Crowding

- Every ghost joins the `ghost_covern` group in `_ready`.
- `_separation_push()` loops over the other living ghosts within `separation_radius` (28px) and pushes away from each, scaled by `1 - dist / separation_radius` (stronger when closer), times `separation_strength` (45 px/s).
- If two ghosts are exactly on top of each other, it picks a random push direction.
- It is added to the target velocity in both `WANDERING` and `HAUNTING`, so it affects steering only. The bodies stay non-solid, so there is no jitter or wedging.
- Dying ghosts are skipped. Intangible ghosts still count.
- Velocity is kept when switching from wandering to haunting, so the change is smooth.

## Detection

- Distance-based only. `check_player_detection()` looks the player up with `get_first_node_in_group("player")` if the reference is missing, then sets `player_detected` when within `detection_radius`.
- It only runs while `WANDERING`. Disengage is handled in `HAUNTING`.
- The scene still contains a `DetectionArea` node, but the script no longer references it. It can be deleted.

## Intangibility

Driven by `_update_intangibility(delta)` in `_physics_process` (skipped when `enable_intangibility` is false, or when dead).

- **Cooldown:** while tangible, `intangible_cooldown_timer` counts down from `intangible_cooldown` (3s). At zero, `enter_intangible_state()` runs.
- **Duration:** while intangible, `intangible_state_timer` counts up to `intangible_duration` (1s), then `exit_intangible_state()` runs and the cooldown restarts.
- **`_set_phased(phased)`** (all deferred) toggles every way the ghost can touch the world:
  - `collision_layer` is set to 0 and restored to the layer captured in `_ready`.
  - `Hurtbox.monitorable` and `monitoring` are switched off. `monitorable` is the important one: projectiles find the hurtbox by overlapping it, so with it off, bullets and missiles pass through. Missile explosion queries also skip it.
  - `ContactDamage.monitoring` and `monitorable` are switched off, so the player takes no contact damage and passes through.
- The ghost's world **mask is left alone**, so it can't phase itself into a wall.
- When it turns solid again, `ContactDamage` re-detects anything it is already overlapping, so damage resumes.
- `take_damage()` also returns early while `is_intangible`, as a backstop.
- Movement is **not** touched. The ghost keeps whatever state logic it was running.

## Visuals

`_update_visuals(delta)` computes the sprite `modulate` once per frame, so effects can't overwrite each other:

1. Start white, or `FLASH_COLOR` (red tint) while `flash_timer > 0` (`FLASH_DURATION` 0.1s, set on damage).
2. If intangible, alpha becomes `intangible_fade_amount` (0.5).
3. If dying, alpha fades from 1 to 0 over `death_duration` (0.5s).

## Damage & Death

- `take_damage()` is a no-op while intangible or `DEAD`; otherwise it forwards to `HealthComponent`.
- Contact damage is `contact_damage_value` (1), continuous (`one_shot = false`). The player's invulnerability window limits how often it lands.
- On death, `DropManager.try_drop(self, drop_table)` runs and `is_dying` is set. The state locks to `DEAD`, intangibility is cleared, and velocity is zeroed. All `CollisionShape2D` nodes are disabled, and all `Area2D` nodes stop monitoring and become non-monitorable (deferred).
- The corpse then fades out over `death_duration` while gravity pulls it down, followed by `queue_free()`.

## Exports

| Category | Export | Default |
|---|---|---|
| Feature Toggles | `enable_wandering`, `enable_haunting`, `enable_intangibility`, `enable_detection` | true |
| Detection | `detection_radius` / `disengage_radius` | 160 / 220 |
| Movement | `wander_speed` / `haunt_speed` | 25 / 55 |
| Movement | `acceleration` (wander lerp) / `haunt_smoothing` | 100 / 4.0 |
| Movement | `wander_radius` | 150 |
| Movement | `preferred_distance` / `standoff_slow_range` / `standoff_deadzone` | 20 / 40 / 6 |
| Crowding | `separation_radius` / `separation_strength` / `hover_angle_drift` | 28 / 45 / 0.4 |
| Intangibility | `intangible_duration` / `intangible_cooldown` / `intangible_fade_amount` | 1.0 / 3.0 / 0.5 |
| Health | `max_health` / `contact_damage_value` / `drop_table` | 10 / 1 / null |

## Key Takeaways for Other Flying Enemies

- **No continuous gravity** while flying. Only apply it in a death/fall sequence.
- **Make "can't be hit" mean non-monitorable.** Projectiles overlap the hurtbox, so `monitoring = false` alone does nothing. Switch off `monitorable` too.
- **Treat temporary effects as overlays** (flag plus timer), not states, when the enemy should keep behaving normally during them.
- **Separate detection and disengage radii** prevent state flicker at one boundary distance.
- **Compute `modulate` in one place** instead of setting it from several handlers and `await`s.
