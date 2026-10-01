# Ghost Covern — Logic Reference

Reference for the current implementation in `Scripts/Enemies/ghost_covern.gd`. This describes what the code actually does (not a design proposal).

## State Machine

```gdscript
enum State { WANDERING, HAUNTING, INTANGIBLE, DEAD }
```

- No gravity is ever applied during `WANDERING`, `HAUNTING`, or `INTANGIBLE` — the ghost is a pure flier. Gravity (`200.0 * delta`) only appears in the death sequence, to make the corpse drop.
- `_process(delta)` runs independently of the state's movement, driving the intangibility cooldown timer regardless of physics state (except when `DEAD`).

## WANDERING

- Active only if `enable_wandering` is true; otherwise velocity is zeroed and the ghost holds position.
- Each frame, if `enable_detection` and `enable_haunting` are both true, checks `check_player_detection()` — if the player is within `detection_radius` and not already flagged, sets `player_detected = true`. If detected, immediately transitions to `HAUNTING`.
- Otherwise, moves toward `wander_target`: computes a direction, builds a `target_velocity` at `wander_speed`, and blends toward it with `current_velocity.lerp(target_velocity, acceleration * delta / wander_speed)`. Dividing by speed normalizes the lerp factor so `acceleration` behaves consistently across different speed values.
- Picks a new `wander_target` when within 10px of the current one or when `wander_choose_interval` (2s) elapses, whichever comes first. Target is a random point within `wander_radius` of the ghost's current position (not a fixed anchor point).

## HAUNTING

- Active only if `enable_haunting` is true; otherwise velocity is zeroed.
- Validates the player reference first — if it's null or freed, clears `player_detected` and falls back to `WANDERING`.
- If `enable_detection` and `enable_wandering` are both true, checks distance to player against `disengage_radius`; beyond that, returns to `WANDERING`. Note detection (entering haunting) and disengage (leaving haunting) use **different radii** (`detection_radius` vs `disengage_radius`) to avoid flicker at the boundary.
- Movement (`haunting_movement`) maintains a preferred distance rather than beelining into the player:
  - Farther than `preferred_distance + 5`: moves toward the player at full `haunt_speed`.
  - Closer than `preferred_distance - 5`: backs away at half `haunt_speed`.
  - Within the deadzone band: `target_velocity` is zero (hovers, decelerating via the same lerp).
  - Same speed-normalized lerp blending as wandering, but using `haunt_speed` as the divisor.

## INTANGIBLE

- Triggered independently of the WANDERING/HAUNTING logic via a separate cooldown timer in `_process()`: counts down `intangible_cooldown_timer`, and once it reaches zero (and the ghost isn't already intangible), calls `enter_intangible_state()`.
- While intangible: sprite alpha is set to `intangible_fade_amount`, `hurtbox.monitoring` and `contact_damage.monitoring` are both disabled (can't deal or receive damage), and movement is **not** updated here — the ghost keeps whatever velocity it had entering the state (movement logic for this state is effectively frozen, unlike the plan doc's suggestion to keep haunting while intangible).
- After `intangible_duration` elapses, `exit_intangible_state()` restores sprite alpha, re-enables hurtbox/contact damage, and returns to `HAUNTING` if a player is still detected, otherwise `WANDERING`.

## Detection

Two parallel detection paths exist:
1. **Area-based**: `DetectionArea` signals (`_on_detection_area_entered/exited`) directly set `player` and `player_detected` when a player-group body/area enters, and clear them on exit only if the player is already past `disengage_radius`.
2. **Distance-based**: `check_player_detection()` in `update_wandering_state()` also checks raw distance every frame as a fallback/redundant check.

## Damage & Death

- `take_damage()` is a no-op while `is_intangible` or already `DEAD`.
- On death: state locks to `DEAD`, velocity zeroed, all `CollisionShape2D` nodes disabled and all `Area2D` nodes stop monitoring (deferred), then a timed fade-out (`death_duration`) with gravity pulling the corpse down before `queue_free()`.

## Key Takeaways for Other Flying Enemies

- **No continuous gravity** while flying — only apply gravity in a death/fall sequence, never during active states. (This was the bug fixed in `atomic.gd`.)
- **Speed-normalized lerp** (`acceleration * delta / speed`) gives consistent accel/decel feel independent of the target speed value, useful when multiple states use different speeds against the same `current_velocity`.
- **Separate detection vs. disengage radii** to prevent state flicker at a single boundary distance.
- **Preferred-distance hovering** (not just binary seek) reads as "haunting" rather than "homing missile" — same idea could apply to Atomic's seek behavior if it ever needs to avoid overlapping the player.
