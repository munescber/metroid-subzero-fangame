Hitbox / Hurtbox Guide

Overview
--------
This project now uses a clear separation between physics collision shapes and combat shapes:

- Physics `CollisionShape2D` (on `CharacterBody2D`): used for movement, environment collisions, and physics resolution.
- `Hurtbox` (`Area2D`): persistent area that represents where an entity can be damaged.
- `Hitbox` (`Area2D`): transient or persistent area that deals damage (melee swings, contact attacks, traps).

Files added
-----------
- `Scripts/Common/health_component.gd` — reusable health component (signals: `damaged(amount, new_health)`, `died()`). Handles health state only.
- `Scripts/Common/hurtbox.gd` — `Hurtbox` Area2D component; owns `receive_hit(damage, source)` which forwards damage to the entity owner.
- `Scripts/Common/hitbox.gd` — `Hitbox` Area2D component; configured with `damage`, `one_shot`, `source`. Applies damage to `Hurtbox` (preferred) or falls back to calling `take_damage` on bodies.

How the interaction flows
-------------------------
1. Attack activates a `Hitbox` (e.g., enable/instantiate it for the attack window) with `damage` and `source` set.
2. When the `Hitbox` overlaps a `Hurtbox`, the `Hurtbox.receive_hit(damage, source)` is called.
3. `Hurtbox.receive_hit` forwards to its owning entity's `take_damage(damage, source)` shim.
4. The entity `take_damage` shim enforces entity-specific rules (player invulnerability, knockback), then delegates to `HealthComponent.take_damage(amount)`.
5. `HealthComponent` reduces health, clamps it, emits `damaged` and `died` signals.
6. Entity scripts listen to `damaged` and `died` to drive visuals, sounds, knockback, and death behavior.

Why both Hurtbox and Hitbox?
----------------------------
- Physics shapes resolve movement and should not be repurposed to represent attack areas — keeping them separate avoids movement/attack conflicts.
- Hurtboxes let you define multiple damageable regions per entity (e.g., head, torso) and assign different responses or multipliers.
- Hitboxes let you define precise attack geometry and timing independent of the entity's physical body.
- Together they make it easy to implement projectiles, melee swings, traps, and bosses with large bodies but small vulnerable zones.

Practical notes for contributors
-------------------------------
- To make an entity damageable, add a `Hurtbox` Area2D child named `Hurtbox` (script attached) or ensure the entity exposes `take_damage(amount, source)`.
- For attacks:
  - Use `Hitbox` Area2D nodes that are enabled only during attack frames, or instantiate ephemeral `Hitbox` scenes at attack time.
  - Configure `damage`, `one_shot` (set to `true` for single-hit), and `source` (the attacker node) on the `Hitbox`.
- Projectiles (bullets) prefer `Hurtbox` on the collided body. If none exists, they fall back to calling `take_damage` on the collided body (backwards-compatible).
- Keep visual feedback and invulnerability outside `HealthComponent` — `HealthComponent` must remain presentation-agnostic.

Example usage
-------------
- Player Melee: enable a child `Hitbox` during the attack animation, set `source = player`, `damage = 1`.
- Enemy Contact: give the enemy a child `Hitbox` (used continuously or for short pulses) that damages the player's `Hurtbox`.
- Projectile: bullets call `receive_hit` on the target's `Hurtbox` or `take_damage` on the collided body; no change needed by default.

Extensibility
-------------
This design supports:
- Multiple damage types (add `damage_type` metadata to `Hitbox`/`HealthComponent`).
- Different damage multipliers on different `Hurtbox` regions.
- Bosses with large physics bodies but small `Hurtbox` areas.
- Projectiles, traps, and environmental hazards using the same interface.

If you need help wiring a new enemy or an attack animation to this system, open an issue or ask for a short example scene.
