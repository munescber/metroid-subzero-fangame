# Health & Damage System — Implementation Plan

This document outlines a step-by-step migration to a strict Hitbox/Hurtbox damage API and collision-layer configuration. Follow the numbered steps and test instructions — do not remove temporary fallbacks until tests pass for each stage.

## Goals
- Separate physics collision from damage collision.
- Provide a reusable `HealthComponent` for Player and Enemies.
- Standardize offensive `Hitbox` (Area2D) and defensive `Hurtbox` (Area2D) behavior.
- Use collision layers/masks to avoid accidental physics interference.

## Implementation Steps

1. Revert/remove the Player's temporary fallback damage detection.
   - Keep `Player.take_damage()` as the player-specific damage response (knockback, invul, VFX).

2. Reuse the `HealthComponent` for both Player and Enemies.
   - Ensure it exposes `take_damage(amount, source)` and signals `damaged(amount, new_health)` and `died()`.

3. Player setup
   - Ensure the Player scene has one `Hurtbox` Area2D using `hurtbox.gd`.
   - `Hurtbox` forwards `receive_hit(damage, source)` to the Player's `take_damage()`.

4. Enemy setup (example: `rhinobug`)
   - Add one `ContactDamage` Area2D using `hitbox.gd` (offensive hit area).
   - Add one `Hurtbox` Area2D using `hurtbox.gd` (defensive receiver).
   - Configure the `hitbox` node properties: `damage`, `one_shot`, `source`.

5. Collision layers (suggested mapping)
   - World (physics tiles)
   - Player Body (physics collision for player)
   - Enemy Body (physics collision for enemies)
   - Hitbox (damage sources)
   - Hurtbox (damage receivers)

6. Configure `Hitbox`
   - Set `collision_layer = Hitbox`.
   - Set `collision_mask = Hurtbox`.
   - `damage` is exported and configurable per attack.
   - `source` should be the owning entity (set in scene or at runtime).

7. Configure `Hurtbox`
   - Set `collision_layer = Hurtbox`.
   - Set `collision_mask = Hitbox`.
   - On `area_entered` / `body_entered`, prefer calling `receive_hit(damage, source)` if available; otherwise forward to owner's `take_damage()`.

8. Keep physics collision separate
   - `CollisionShape2D` on the `CharacterBody2D` root is only for movement/physics.
   - Damage Areas (Hitbox/Hurtbox) should not be used for physics resolution.

9. Shape placement
   - Configure Hitbox/Hurtbox shapes independently from physics shapes to control effective regions for damage.

10. Enemy contact flow (runtime)
    - Enemy `ContactDamage` Area2D overlaps Player `Hurtbox` → `Hurtbox.receive_hit(damage, source)` → Player `HealthComponent.take_damage()` → `Player.take_damage()` (knockback, invul).

11. Projectile flow
    - Projectile `Hitbox` overlaps Enemy `Hurtbox` → Enemy `HealthComponent` receives damage → `damaged` signal triggers visual feedback.

12. Death handling
    - Use `HealthComponent.died` to disable physics and Area2D monitoring, play VFX, and queue_free after any death animation.

13. Testing procedure
    - Test 1: Isolated enemy + player in empty scene. Verify ContactDamage → Hurtbox → Player.take_damage.
    - Test 2: Projectile → Enemy Hurtbox: verify `damaged` signal and flash.
    - Test 3: Edge cases: rapid repeated hits, `one_shot` `true` vs `false`, invulnerability.
    - After each test, verify there are no duplicate events or self-hits.

## Notes & Recommendations
- Use dedicated layers for Hitbox and Hurtbox to prevent accidental physics interactions.
- Keep `one_shot` semantics for short melee swings; set false for continuous hazards.
- Tune Hitbox offsets to avoid overlapping tiles or the enemy's physics body too deeply.
- Keep presentation (knockback, flashing) in entity scripts, not in the `HealthComponent`.

## Next Actions
- I can apply these scene and layer changes for `player` and `rhinobug` locally (no commits), then provide step-by-step test logs for you to run. Confirm if you want me to proceed.

---

Generated: Implementation plan for `Docs/health-damage-system/IMPLEMENTATION_PLAN.md`.
