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
- `Scripts/Common/hurtbox.gd` — forwards `receive_hit(damage, source)` to the owning entity's `take_damage(amount, source)`. Purely passive; relies on an overlapping Hitbox to call it, does not connect any signals itself.
- `Scripts/Common/hitbox.gd` — shared damage-dealing area logic with `damage`, `one_shot`, and `source` properties. Used by Phantoon and Rhinobug's `ContactDamage` nodes and by all projectile `Hitbox` nodes.
- `Scripts/Common/contact_damage.gd` — specialized damage-dealing area used by Ghost Covern. Functionally equivalent to `hitbox.gd` but adds explicit player-name/group checks and per-instance debug logging.
- `Scripts/Player/player_rundas.gd` — player-specific `take_damage()` shim, invulnerability, knockback, and death handling.
- `Scripts/Enemies/rhinobug.gd` — enemy health setup, contact damage config, and death visuals/cleanup.
- `Scripts/Player/bullet.gd` — projectile physics collision is kept on the `CharacterBody2D`, while a child `Hitbox` Area2D handles combat overlap.
- `Scripts/Player/missile.gd` — same physical-body-plus-`Hitbox` convention as `Bullet`, but on impact it explodes into a small area-of-effect radius instead of damaging only what it directly touched. See `Docs/player_logic/MISSILE_LOGIC.md` for the full breakdown, including why its explosion uses a direct physics-space query instead of a toggled `Area2D` (see "Area-of-effect / burst damage" below).

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

Spatial Proximity Validation
----------------------------
**This section is historical and no longer reflects the current code.** An earlier version of `Hurtbox.receive_hit()` rejected hits from sources farther than ~10 units away, intended to support boss weak-point targeting (e.g. Phantoon's eye). That distance check caused legitimate bullet hits to be rejected and was removed. `Hurtbox.receive_hit()` now trusts the Area2D collision system: if a Hitbox overlaps a Hurtbox, the hit is always accepted. If per-region weak-point damage is needed again in the future, implement it with a dedicated small Hurtbox shape positioned at the weak point rather than a distance check in `receive_hit()`.

Why both Hurtbox and Hitbox?
----------------------------
- Physics collision and combat collision are intentionally separated.
- Hurtboxes define where an entity can be damaged.
- Hitboxes define the shape and timing of an attack.
- This allows projectiles, melee, traps, and contact damage to share the same API without contaminating movement physics.

Project-specific collision setup
--------------------------------
Godot layers/masks are bitmasks: layer N in the editor corresponds to bit value `2^(N-1)`. The project uses:

| Editor layer # | Bit value | Purpose               |
|----------------|-----------|------------------------|
| 1              | 1         | World (terrain/walls) |
| 2              | 2         | PlayerBody             |
| 3              | 4         | EnemyBody              |
| 4              | 8         | Hitbox (damage-dealing areas) |
| 5              | 16        | Hurtbox (damage-receiving areas) |

Standard node configuration:

- Player `CharacterBody2D`: `collision_layer = 2`, `collision_mask = 1` (world only)
- Player `Hurtbox`: `collision_layer = 16`, `collision_mask = 8`
- Enemy `CharacterBody2D`: `collision_layer = 4`, `collision_mask = 1` (world only)
- Enemy `ContactDamage`/`Hitbox`: `collision_layer = 8`, `collision_mask = 16` (detects player Hurtbox)
- Enemy `Hurtbox`: `collision_layer = 16`, `collision_mask = 8` (detected by player bullets' Hitbox)
- Bullet/projectile `CharacterBody2D` (physical body): `collision_layer = 8`, `collision_mask = 1` (world only — must NOT include the player/enemy body layers, otherwise the player or enemies will physically collide with the projectile like a wall instead of only taking damage through the Hurtbox/Hitbox overlap)
- Bullet/projectile child `Hitbox`: `collision_layer = 8`, `collision_mask = 16` (detects Hurtboxes to damage)
- Bullet/projectile child `Hurtbox` (so it can be destroyed by player bullets): `collision_layer = 16`, `collision_mask = 8`

Ghost Covern's `ContactDamage` additionally sets `collision_mask = 18` (`16 | 2`) so it detects the player's Hurtbox *and* falls back to detecting the player's physical body directly, since `contact_damage.gd` implements both `_on_area_entered` and `_on_body_entered`. Its `DetectionArea` (used for haunting AI) sets `collision_mask = 16` to detect the player's Hurtbox and is non-monitorable so nothing else can detect it back.

Typical setup summary:

- Player body collision layer: `PlayerBody`
- Enemy body collision layer: `EnemyBody`
- Player hurtbox collision layer: `Hurtbox`, mask matches `Hitbox`
- Enemy contact hitbox collision layer: `Hitbox`, mask matches `Hurtbox`
- Bullet/projectile main body: `collision_layer = Hitbox`, `collision_mask = World` only
- Bullet/projectile child `Hitbox` Area2D: `collision_mask = Hurtbox`

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

Area-of-effect / burst damage (important gotcha)
-------------------------------------------------
Some attacks (e.g. `Missile`'s explosion) need to damage everything inside a
radius at a single instant, rather than a single target via continuous
Hitbox/Hurtbox overlap tracking. The naive approach — spawn a disabled
`Area2D` sized to the blast radius, flip `monitoring = true` at the moment of
the explosion, then read `get_overlapping_areas()` — **does not work** if
anything is already touching that shape the instant monitoring turns on.

This is a general Godot behavior, not a bug in this project's code:

> An `Area2D` only tracks overlaps that *begin* while its `monitoring` is
> already `true`. If a shape is already overlapping the moment you enable
> `monitoring`, that overlap is never recorded as an "entered" event, so
> `get_overlapping_areas()` will never report it, no matter how many frames
> you wait afterward.

For an explosion triggered by the thing it needs to damage (e.g. a missile
exploding on the exact enemy that set it off), this is always the case — the
target is already overlapping at the moment the explosion starts, so the
toggled-`Area2D` approach silently misses it.

**Use a direct physics-space query instead of a toggled `Area2D` for
instant-radius damage:**

```gdscript
var space_state := get_world_2d().direct_space_state
var shape := RectangleShape2D.new()
shape.size = explosion_size

var query := PhysicsShapeQueryParameters2D.new()
query.shape = shape
query.transform = Transform2D(0.0, global_position)
query.collision_mask = 16 # Hurtbox layer
query.collide_with_areas = true
query.collide_with_bodies = false

for result: Dictionary in space_state.intersect_shape(query):
    var area: Area2D = result.get("collider")
    if area and area.has_method("receive_hit"):
        area.call("receive_hit", damage, source)
```

This queries "what overlaps this shape right now" synchronously, independent
of any `Area2D` monitoring/enter-tracking state, so it reliably finds
everything in range — including whatever triggered the explosion in the
first place. See `Scripts/Player/missile.gd` for the full worked example.

Deferred property changes from signal callbacks (important gotcha)
---------------------------------------------------------------------
If a `Hitbox`/`Hurtbox` signal callback (e.g. `area_entered`) needs to change
another physics-related property — disabling a `CollisionShape2D`, flipping
an `Area2D`'s `monitoring`, etc. — do it with `set_deferred(...)` rather than
a direct assignment. These signals fire from inside the physics engine's
collision query flush, and direct property writes at that point are not
guaranteed to apply before the query finishes. `Scripts/Player/missile.gd`
does this for both its `CollisionShape2D.disabled` and its `Hitbox.monitoring`
when it explodes.

Extensibility
-------------
This design supports:
- multiple damage types
- different hurtbox regions
- traps and environmental hazards
- projectile and melee attack reuse
- boss or enemy-specific damage hooks
- instant area-of-effect / burst damage (via direct physics-space queries)

This documentation reflects the current repo implementation and should be kept in sync with future script changes.
