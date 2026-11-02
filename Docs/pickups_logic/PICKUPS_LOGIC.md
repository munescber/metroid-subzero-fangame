# Pickups

Scenes in `Scenes/Pickups/`, scripts in `Scripts/Pickups/`. All extend `Pickup`
(`pickup.gd`): Area2D, layer 0, mask 2 (PlayerBody). Overlaps are re-checked every
physics frame, so a refused item (refill while missiles are locked) is collected once accepted.
`_try_collect(body)` returns true only when the effect was consumed.

| Item | Export | Player call | Consumed when |
|------|--------|-------------|---------------|
| MissileExpansion | `expansion_amount` (5) | `collect_missile_expansion(n)` | always; unlocks missiles, raises max and ammo by n |
| HealthPickup | `heal_amount` (10) | `heal(n)` | contact; absorbed even at full HP (heal is clamped) |
| MissileRefill | `refill_amount` (5) | `restore_missiles(n)` | contact once missiles are unlocked (refused while locked); absorbed even at full ammo; never raises max |

## Visuals
A pickup with a child node named `AnimatedSprite2D` plays its `default` animation (looping)
from `Pickup._ready()`. HealthPickup and MissileRefill use it; MissileExpansion still uses a
static `Sprite2D`. To change the art, edit the SpriteFrames; the collision shape is separate.

## Charge-beam magnet
While the player holds a charge (`player.attracts_pickups()` is true, i.e. `is_charging`),
pickups with `magnet_enabled` within `magnet_radius` (64 px) move toward the player at
`magnet_speed` (160 px/s). Enabled for HealthPickup and MissileRefill only; MissileExpansion
never moves. Disabled during a drop's hop. All three values are Inspector exports on the pickup.

## Enemy drops
`DropManager.try_drop(enemy, drop_table)` (static, `Scripts/Pickups/drop_manager.gd`) is called
from each enemy's `_on_health_died` (atomic, ghost_covern, phantoon, rhinobug, zoomer).

- `DropTable` resource (`drop_table.gd`): `drop_chance` 0.5, `health_weight` 60, `missile_weight` 40.
  Each enemy has an optional `drop_table` export; empty uses the default values above.
- MissileExpansion is a progression item and is never an enemy drop.
- Candidates are filtered first: MissileRefill is removed while `player.missiles_unlocked` is false,
  then the remaining weights are used as-is (equivalent to renormalizing). Nothing left means no drop.
- The pickup spawns at the enemy's position under the enemy's parent (deferred), hops, and
  calls `start_drop_behavior()`: despawn after `drop_lifetime` (8s), blinking for the last `blink_duration` (2s).
- Hand-placed pickups never despawn.
- spore_spawn has no script yet, so it has no drop hook.
- Phantoon no longer uses `try_drop` on death; it uses `drop_guaranteed` (below). Its burst projectiles
  and bouncing fireballs call `try_drop` when the player shoots them down.

## Guaranteed drops
`DropManager.drop_guaranteed(enemy, health_count, missile_count, spread = 48.0, lifetime = -1.0)` spawns an
exact number of HealthPickups and MissileRefills with no roll and no missile-unlock check. Used for the
Phantoon death (10 and 10).

- Each pickup spawns within `spread` pixels horizontally of the enemy, with a small random vertical offset.
- A `lifetime` above 0 overrides `drop_lifetime` so a large drop doesn't despawn before it can be collected.
- Spawning is deferred, like `try_drop`, so it is safe to call from a death handler in a physics callback.
- MissileRefills are still ignored by the player while missiles are locked; they just despawn on their timer.
- The player is found through the `"player"` group; see `Docs/player_logic/PLAYER_GROUP.md`.
