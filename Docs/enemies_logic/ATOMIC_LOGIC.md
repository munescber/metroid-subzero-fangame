# Atomic — Logic Reference

Reference for the current implementation in `Scripts/Enemies/atomic.gd`. This describes what the code actually does (not a design proposal).

Script: `Scripts/Enemies/atomic.gd` (`class_name Atomic`)
Scene: `Scenes/Enemies/atomic.tscn`

Atomic is a flying enemy that floats, slowly seeks the player once detected, and periodically erects a damaging electric field that also destroys incoming projectiles. There is no dash or charge attack.

## State Machine

```gdscript
enum State { FLOATING, ELECTRIC_CHARGING, ELECTRIC_FIELD, COOLDOWN, DEAD }
```

- Pure flier. No gravity is applied in any state. `current_velocity` is driven by the state logic each physics frame, then applied with `move_and_slide()`.
- Collision layers are also set in `_ready`: body layer 4, mask 1 (world only); `ElectricField` layer 8, mask 16 | 8; `Hurtbox` layer 16, mask 8.
- The **electric field schedule** is a timer that runs alongside the state machine. `electric_field_interval_timer` accumulates every physics frame that Atomic is not in `ELECTRIC_CHARGING` or `ELECTRIC_FIELD`. Once it reaches `electric_field_interval` (10s), `FLOATING` hands off to `ELECTRIC_CHARGING`.
- The timer resets to 0 when entering `FLOATING`.

## FLOATING

- The electric-field check comes first. If `enable_electric_field` is true and the interval has elapsed, it transitions to `ELECTRIC_CHARGING`.
- If `player` is null, it retries `get_first_node_in_group("player")` every frame (the player may not be in the group yet at `_ready()`).
- Detection uses two radii to avoid flicker. `player_detected` becomes true within `detection_range` (200) and clears only beyond `disengage_range` (250). On disengage it picks a new float target.
- While detected, `_update_seeking()` runs, even if wandering is disabled:
  - `current_velocity` lerps toward `direction_to_player * seek_speed` (28) with factor `seek_smoothing * delta` (4.0).
  - Atomic never stops short, so it can drift into the player.
  - When roughly level with the player (`|dy| < 8`) and vertical speed is small, it applies the upward bias (`-float_speed * 0.3`) to avoid a steady downward drift.
- While not detected, it wanders:
  - Every `float_change_interval` (3s) it picks a random point 50–120px away.
  - It moves horizontally toward it at `float_speed` (40).
  - A small constant upward bias applies whenever vertical speed is small.
- If `enable_wandering` is false and no player is detected, velocity decays (`* 0.95`).

## ELECTRIC_CHARGING

- Atomic comes to a **complete stop** while telegraphing.
- `glow_intensity` rises from 0 to 2 over `electric_charge_duration` (1.5s), and the sprite colour lerps from `GLOW_COLOR_IDLE` to `GLOW_COLOR_CHARGED`.
- `electric_field_area` starts monitoring on entry (deferred), so the growing field can spike-hit the player the instant their hurtbox touches the edge.
- `_tick_field_damage` is already active, so the growing field hurts the player. Projectiles are **not** blocked yet.
- After the duration, it transitions to `ELECTRIC_FIELD`.

## ELECTRIC_FIELD

- Stays stationary at max glow.
- On entry: `field_active = true`, `hurtbox.monitoring` is disabled, and `_clear_projectiles_in_field()` removes any projectile already inside the field.
- **Size:** `_field_scale()` is `0.5 + glow_intensity / 4.0`, so the radius is `electric_field_radius * _field_scale()`. The visual, the blocking area and the damage query all use it. It reaches full size at full glow.
- **Damage:** `_tick_field_damage` runs on a fixed tick (`electric_field_damage_tick`, 0.5s) instead of every frame. It runs a physics-shape query on the Hurtbox layer (16) and calls `receive_hit` on the player's hurtbox for `electric_field_damage` (5, the scene overrides it to 10). A tick is needed because `area_entered` only fires on new overlaps and would miss a player standing still.
- **Player matching** uses node name (`Player` / `player_rundas`) or group membership.
- **Projectile blocking:** `_on_electric_field_entered` destroys `Hitbox` areas that touch the field, but only once `field_active` is true:
  - A `Missile` detonates at its current position.
  - A `Bullet` spawns its impact effect and is freed.
- After `electric_field_duration` (2.0s, the scene overrides it to 1.0), it transitions to `COOLDOWN`.

## COOLDOWN

- Velocity decays (`* 0.98`), and glow fades back toward idle at 2 per second.
- On entry: `field_active` is cleared, field monitoring is disabled, and `hurtbox.monitoring` is re-enabled.
- After `electric_field_cooldown` (1.5s), `player_detected` is force-cleared and it returns to `FLOATING`, so detection is re-evaluated from scratch.

## Damage & Death

- `take_damage()` is a no-op while `DEAD`, and **blocked while `field_active`**. The hurtbox is already disabled then, so this is a backstop.
- On damage, the sprite flashes red for 0.12s via `DamageFlashTimer`, then returns to the idle/charged glow colour for the current `glow_intensity`.
- Contact damage is a `ContactDamage` area using `hitbox.gd`, with `damage = contact_damage` (2) and `source = self`.
- On death:
  - `DropManager.try_drop(self, drop_table)` runs.
  - The state moves to `DEAD`, `is_dying` is set, and all `CollisionShape2D` nodes are disabled while `Area2D` nodes stop monitoring (deferred).
  - The sprite fades to 0 alpha over `death_duration` (0.5s), then `queue_free()`.
  - No gravity applies, so the corpse fades in place.

## Exports

| Category | Export | Default |
|---|---|---|
| Feature Toggles | `enable_wandering`, `enable_electric_field` | true |
| Top level | `max_health` / `contact_damage` / `drop_table` | 10 / 2 / null |
| Movement | `float_speed` / `float_change_interval` | 40 / 3.0 |
| Movement | `seek_speed` / `seek_smoothing` | 28 / 4.0 |
| Detection | `detection_range` / `disengage_range` | 200 / 250 |
| Electric Field | `electric_field_interval` | 10.0 |
| Electric Field | `electric_charge_duration` / `electric_field_duration` / `electric_field_cooldown` | 1.5 / 2.0 / 1.5 |
| Electric Field | `electric_field_radius` / `electric_field_damage` / `electric_field_damage_tick` | 24 / 5 / 0.5 |
| Visual | `glow_intensity` | 0.0 |
| Death | `death_duration` | 0.5 |

## Notes

- Atomic's seeking is the model the Ghost Covern now follows: steady smoothed drift straight at the player, with no standoff distance.
- Atomic's "untargetable" window during the field works by disabling the hurtbox's `monitoring` plus the `take_damage` guard. The Ghost Covern's intangibility also clears `monitorable`, so projectiles pass through instead of being consumed. The same change would make Atomic's field window behave the same way.
- The electric field is a separate timer track from the state machine, whereas the Ghost's intangibility is an overlay with its own cooldown.
