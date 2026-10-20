# Breakable Tile — Implementation Notes

A reusable solid block that player beams destroy. Place each one as an
individual scene instance; no TileMap tiles are modified.

## Files

- `Scripts/Environment/breakable_tile.gd` — behavior (`class_name
  BreakableTile`, `@tool`).
- `Scenes/Environment/BreakableTile.tscn` — `StaticBody2D` root with a
  `Sprite2D` and a `CollisionShape2D` child.

## How it integrates with the existing beams

No projectile code was changed. `Bullet._on_hit()` (`bullet.gd`) already
handles solid collisions: the beam's `CharacterBody2D` uses
`move_and_collide()`, and for the collider it hits it calls
`take_damage(damage, shooter)` (or `Hurtbox.receive_hit`), then frees itself.
`ChargeBeam` extends `Bullet` and only differs in `damage` (3 vs 1) and
visuals, so one `take_damage()` serves both beams. The beam also spawns its
own impact effect on every hit, so the block adds no effect of its own.

Damage goes into the shared `HealthComponent` (same as the player and
Rhinobug). When it reaches 0, the block disables its collision (deferred,
immediately), hides its children, emits `destroyed` and calls `queue_free()`.
Further damage after that is ignored.

### Why the root is a `StaticBody2D`, not a `Node2D`

A beam calls `take_damage` on the *physics body* it collides with. With a
`Node2D` root and a `StaticBody2D` child, the body would need a `Hurtbox` or
a forwarding script. A `Hurtbox` would also add a second hit path (the beam's
`Hitbox` overlap on top of its body collision) and risk double damage. With
the script on the body, there is exactly one damage path per beam. Sprite and
collision are still separate child nodes.

### Missiles

`Missile` explodes on contact and normally only damages `Hurtbox` areas
(layer 16). `missile.gd` has a second pass, `_apply_solid_damage()`, that
queries the World layer (1) for bodies with `take_damage()` inside the
explosion area and calls `take_damage(damage, shooter)` on them. It skips the
shooter and any body that has a `Hurtbox` child (those, like `RoomGate`, are
already damaged through the Hurtbox pass, so they are not hit twice). The
missile's damage is 5, so a 5-health block breaks in one missile; blocks
inside the explosion area are each hit once.

### Single hit per beam

The beam only checks collision via `move_and_collide()` (its `Hitbox` only
watches layer 16, which the block is not on), and it frees itself right after
the hit. One beam can therefore only deal damage once, which was verified in
the test below.

## Collision setup

- `collision_layer = 1` (World), same as the solid tiles, so the player
  (mask 1), enemies and beams (mask 1) are all blocked.
- `collision_mask = 0` — the block never collides into anything itself.

## Editing (from the instance's inspector)

No "Editable Children" needed:

| Export | Purpose |
|---|---|
| `max_health` | Hits to destroy. Default `1`. Normal beam deals 1, Charge Beam 3. |
| `texture` | Artwork. Defaults to an `AtlasTexture` of `wrecked_ship.png` (tile at 96,48, a placeholder). Click it and change **Atlas / Region** to pick another tile or tileset. |
| `sprite_offset` | Moves only the sprite. |
| `collision_size` | Size of the solid rectangle. Default `16×16`. |
| `collision_offset` | Moves only the collision. |
| `debug_enabled` | Prints damage/destroy logs. |

The texture and shape are `resource_local_to_scene`, so each instance has its
own copies and editing one never changes another.

To make a variant (e.g. needs a Charge Beam hit), instance the scene and raise
`max_health`, or save an inherited scene with it preset.

## Placement

1. Drag `BreakableTile.tscn` from the FileSystem panel into the level.
2. Optionally group instances under a `BreakableTiles` `Node2D`, like the
   `Hazards` container used for spikes.
3. Set `texture` / `max_health` as needed.

## Known gaps

- **No destroy animation.** The block disappears instantly. The `destroyed`
  signal is available for a later effect or for saving state.
- **Not persistent.** Destroyed blocks come back when the level reloads.

## Related

- [HITBOX_HURTBOX.md](../enemies_logic/HITBOX_HURTBOX.md)
- [SPIKE_HAZARD.md](SPIKE_HAZARD.md) — same inspector-driven placement style.
