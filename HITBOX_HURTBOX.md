Hitbox / Hurtbox Guide

Overview
--------
This project uses a clear separation between physics collision and combat collision:

- Physics `CollisionShape2D` on `CharacterBody2D`: used for movement, wall resolution, and environment collisions.
- `Hurtbox` (`Area2D`): the damageable region of an entity. It receives hits and forwards them to the owning entity.
- `Hitbox` (`Area2D`): the damaging region of an attack. It applies damage when it overlaps a `Hurtbox`.

This repo-specific pattern keeps the movement body and the damage body separate, which avoids accidental physics interference.

Core files
-----------
- `Scripts/Common/health_component.gd` — reusable health state for any actor. Emits `damaged(amount, new_health)` and `died()`.
- `Scripts/Common/hurtbox.gd` — forwards `receive_hit(damage, source)` to the owning entity's `take_damage(amount, source)`.
- `Scripts/Common/hitbox.gd` — shared contact hitbox logic with `damage`, `one_shot`, and `source` properties.
- `Scripts/Player/player_rundas.gd` — player-specific `take_damage()` shim, invulnerability, knockback, and death handling.
- `Scripts/Enemies/rhinobug.gd` — enemy health setup, contact damage config, and death visuals/cleanup.
- `Scripts/Player/bullet.gd` — projectile physics collision is kept on the `CharacterBody2D`, while a child `Hitbox` Area2D handles combat overlap.

Current project behavior
------------------------
The repo currently follows this flow:

1. The physical body (`CharacterBody2D`) handles movement and wall collisions.
2. The bullet keeps its physical `CollisionShape2D` for wall blocking.
3. A child `Hitbox` Area2D on the projectile handles damage overlap against enemy hurtboxes.
4. When a hitbox overlaps a hurtbox, `Hurtbox.receive_hit(damage, source)` is called.
5. The owning entity's `take_damage(amount, source)` handles invulnerability, knockback, and entity-specific response logic.
6. That method then delegates to `HealthComponent.take_damage(amount, source)`.
7. `HealthComponent` applies damage and emits `damaged` and `died` once the remaining health reaches `0` or below.

Important death rule
--------------------
The death condition is intentionally strict:

- Death is triggered when `current_health <= 0`
- Damage is ignored when the entity is already dead
- Repeated hits are ignored after death

This keeps death deterministic and prevents accidental repeated death triggers from overlap events.

How the repo sets values
------------------------
The project exposes the key tuning values directly in the script Inspector so they are easy to debug:

- `Player` max health: exported as `max_health`
- `Rhinobug` max health: exported as `max_health`
- `Rhinobug` contact damage: exported as `contact_damage`
- `Player bullet` damage: exported as `damage`
- `Player` invulnerability: exported as `invulnerability_time`
- `Player` knockback: exported as `knockback_x` and `knockback_y`

Current defaults in the repo are:

- Player max health: `100`
- Rhinobug max health: `5`
- Rhinobug contact damage: `1`
- Bullet damage: `1`
- Player invulnerability time: `0.8`
- Player knockback x: `120`
- Player knockback y: `140`

Why both Hurtbox and Hitbox?
----------------------------
- Physics collision and combat collision are intentionally separated.
- Hurtboxes define where an entity can be damaged.
- Hitboxes define the shape and timing of an attack.
- This allows projectiles, melee, traps, and contact damage to share the same API without contaminating movement physics.

Project-specific collision setup
--------------------------------
The project uses dedicated physics layers for this separation:

- World: layer 1
- PlayerBody: layer 2
- EnemyBody: layer 3
- Hitbox: layer 4
- Hurtbox: layer 5

Typical setup:

- Player body collision layer: `PlayerBody`
- Enemy body collision layer: `EnemyBody`
- Player hurtbox collision layer: `Hurtbox`, mask matches `Hitbox`
- Enemy contact hitbox collision layer: `Hitbox`, mask matches `Hurtbox`
- Bullet main body keeps `collision_layer = Hitbox` or projectile collision while wall collision continues on the `CharacterBody2D`
- Bullet child `Hitbox` Area2D uses `collision_mask = Hurtbox`

Practical usage notes
---------------------
- To make an entity damageable, add a child `Hurtbox` Area2D with the `Hurtbox` script, or ensure the entity exposes `take_damage(amount, source)`.
- For entries that should only hit once, set `one_shot = true`.
- For continuous damage zones, set `one_shot = false`.
- Keep visual feedback (flash, knockback, death animation) in entity scripts, not in `HealthComponent`.
- The `HealthComponent` should remain presentation-agnostic and only manage health state.

Example flow in this repo
------------------------
- Player bullet: bullet physics body hits a wall; child `Hitbox` overlaps the enemy `Hurtbox` -> enemy receives `receive_hit` -> enemy `take_damage` -> `HealthComponent.take_damage()`.
- Rhinobug contact: enemy `ContactDamage` Area2D overlaps the player `Hurtbox` -> player `take_damage()` -> player invul + knockback -> `HealthComponent.take_damage()`.
- Death: once `current_health <= 0`, the entity plays death logic and disables collisions.

Extensibility
-------------
This design supports:
- multiple damage types
- different hurtbox regions
- traps and environmental hazards
- projectile and melee attack reuse
- boss or enemy-specific damage hooks

This documentation reflects the current repo implementation and should be kept in sync with future script changes.
