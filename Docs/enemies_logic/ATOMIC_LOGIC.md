# Atomic — Logic Reference

Reference for the current implementation in `Scripts/Enemies/atomic.gd`. This describes what the code actually does (not a design proposal).

Script: `Scripts/Enemies/atomic.gd`
Scene: `Scenes/Enemies/atomic.tscn`

Atomic is a flying enemy that wanders/seeks the player, performs a charge-and-dash attack, and periodically erects a damaging electric field that also destroys incoming projectiles.

## State Machine

```gdscript
enum State { FLOATING, CHARGING, DASHING, RECOVERING, ELECTRIC_CHARGING, ELECTRIC_FIELD, COOLDOWN, DEAD }
```

- Pure flier — no continuous gravity is ever applied in any state; `current_velocity` is driven entirely by the state logic each physics frame.
- Visuals (`Visuals` node) rotate continuously at `rotation_speed` regardless of state, independent of the collision body.
- The **electric field schedule runs independently** of the dash/attack state machine: `electric_field_interval_timer` accumulates every frame that Atomic isn't already in `ELECTRIC_CHARGING`/`ELECTRIC_FIELD`, and once it reaches `electric_field_interval` the field sequence preempts whatever else is happening in `FLOATING`.

## FLOATING

- Electric field readiness is checked first and takes priority over everything else: if `enable_electric_field` and the interval timer has elapsed, transitions straight to `ELECTRIC_CHARGING`.
- If `player` is null (lookup failed at `_ready()`), retries `_find_player()` every frame as a fallback.
- Detection uses two different radii to avoid flicker: becomes `player_detected = true` within `detection_range`, only clears back to `false` once beyond the larger `disengage_range`.
- If the player is detected and `cooldown_timer <= 0.0` and `enable_attacks` is true, transitions to `CHARGING`.
- If the player is detected but attacks are disabled (or on cooldown), Atomic still gravitates toward the player via `_update_seeking()` instead of wandering.
- If no player is detected, wanders: picks a random point within 50–120px of its current position (`_choose_new_float_target`) every `float_change_interval` (3s), moving toward it at `float_speed`. Applies a small constant upward bias (`-float_speed * 0.3`) whenever vertical velocity is small, to keep it from sinking.
- If `enable_wandering` is false and no player is detected, velocity just decays (`* 0.95`) instead of picking new targets.

## CHARGING

- Continuously re-aims `dash_direction` at the player's current position every frame (not locked in at charge start).
- Velocity decays (`* 0.95`) while charging — the enemy visually "winds up" in place.
- `glow_intensity` ramps up as a warning telegraph.
- After `charge_duration` (0.6s), transitions to `DASHING`.

## DASHING

- Moves in a straight line along the (already-aimed) `dash_direction` at `dash_speed`.
- After `dash_duration` (0.4s), transitions to `RECOVERING`.

## RECOVERING

- Velocity decays (`* 0.9`).
- `cooldown_timer` counts up; after `dash_cooldown` (1.0s) elapses, transitions to `COOLDOWN`.

## ELECTRIC_CHARGING

- Comes to a **complete stop** (`current_velocity = Vector2.ZERO`) while telegraphing.
- `glow_intensity` and sprite `modulate` lerp from `GLOW_COLOR_IDLE` to `GLOW_COLOR_CHARGED` over `electric_charge_duration` (1.5s).
- After the duration elapses, transitions to `ELECTRIC_FIELD`.

## ELECTRIC_FIELD

- Stays stationary at max glow (`GLOW_COLOR_CHARGED`).
- `hurtbox.monitoring` is disabled and `electric_field_area.monitoring` is enabled for the duration of this state (set on transition) — Atomic is untargetable by the player while the field is up, and the field itself becomes the active hazard.
- Damage is applied via a **manual physics-shape overlap query** every frame (`_apply_electric_field_damage`), not just on `area_entered` — this is deliberate, since `area_entered` only fires on new overlaps and wouldn't hit a player already standing inside the field radius when it activates.
- Player matching uses both group membership (`is_in_group("player")`) and a name fallback (`"Player"` / `"player_rundas"`), mirroring the same defensive pattern used in `missile.gd`.
- `_on_electric_field_entered` separately destroys any `Hitbox`-named Area2D that touches the field (used by both the bullet and missile scenes), i.e. the field also eats incoming projectiles.
- After `electric_field_duration` (2.0s), transitions to `COOLDOWN`.

## COOLDOWN

- Velocity decays (`* 0.98`); glow fades back toward idle.
- `field_active` is cleared and `electric_field_area` monitoring is disabled, `hurtbox` monitoring is re-enabled, on entry to this state.
- After `electric_field_cooldown` (1.5s), `player_detected` is force-cleared and transitions back to `FLOATING` (so the enemy re-evaluates detection fresh rather than immediately re-charging).

## Damage & Death

- `take_damage()` is a no-op while `DEAD`, and **fully blocked while `field_active`** (the hurtbox is already disabled during the field, this check is a backstop).
- Taking damage flashes the sprite red briefly via `damage_flash_timer` (0.12s), then restores the idle/charged glow lerp based on current `glow_intensity`.
- On death (`HealthComponent.died`): state locks to `DEAD`, `is_dying = true`, all `CollisionShape2D` disabled and `Area2D` monitoring stopped (deferred), then fades sprite alpha to 0 over `death_duration` (0.5s) before `queue_free()`. Unlike Ghost Covern, no gravity is applied during the death fall — Atomic's corpse just fades in place.

## Feature toggles (for testing)

- `enable_wandering` — if `false`, Atomic holds position (decaying velocity) instead of picking wander targets when no player is detected.
- `enable_attacks` — if `false`, Atomic will still detect and seek the player but never charges/dashes.
- `enable_electric_field` — if `false`, the electric field sequence never triggers; Atomic only ever uses the charge/dash attack.

## Key differences vs. Ghost Covern

- Atomic's electric field schedule is a **third, independent timer track** running alongside the main state machine, whereas Ghost Covern's intangibility is triggered from a single cooldown timer that also only fires outside `DEAD`.
- Atomic re-aims continuously during its telegraph (`CHARGING`), while Ghost Covern has no equivalent telegraphed-attack state.
- Atomic's electric field actively destroys projectiles on contact; Ghost Covern has no equivalent hazard-vs-projectile interaction.
