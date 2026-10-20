# Spike Hazard — Implementation Notes

A reusable, invisible damage zone. Drop it over spike tiles already painted
in a level; touching it damages the player through the player's existing
`take_damage()`.

## Files

- `Scripts/Environment/spike_hazard.gd` — the hazard's behavior
  (`class_name SpikeHazard`, `@tool`).
- `Scenes/Environment/SpikeHazard.tscn` — the scene (`Area2D` +
  `CollisionShape2D`, no visual — see "No sprite, on purpose" below).

## What it does

On `body_entered`, if the body has a `take_damage` method, the hazard calls
`take_damage(damage, null)`. It adds no health, knockback or invulnerability
logic of its own — all of that comes from `player_rundas.gd`:

- `invulnerable` / `invulnerability_time` (0.8 s) blocks repeat hits.
- Knockback and the brief input lock are applied by the player.
- `HealthComponent` applies the damage and emits `damaged` / `died`.

The `source` argument is `null` on purpose. The player then gets the generic
upward knockback instead of being pushed horizontally away from the hazard's
center, which would feel wrong when landing on the spikes.

### Player detection

The player is **not** in a `"player"` group, so the hazard uses the existing
damage interface (`has_method("take_damage")`) instead. Only the PlayerBody
layer is in the mask, so nothing else can reach this check.

## Collision setup

- `collision_layer = 0` — the hazard is only a listener.
- `collision_mask = 2` — PlayerBody (the player's `CharacterBody2D`). The
  player's Hurtbox (layer 16) is not used.
- The mask and layer are set in the scene and again in `_ready()` (game
  only), so they stay correct even if a level overrides them.

## Repeated damage

The hazard only reacts to `body_entered`, which fires once per entry, so it
never damages every physics frame. The player's invulnerability frames cover
quick re-entries. No cooldown is added in the hazard.

Known limitation: if the player enters while invulnerable (for example right
after an enemy hit), that entry is ignored by `take_damage()`. The player
takes no damage from the spikes until they leave and re-enter. If this ever
feels wrong, the fix would be to re-check overlapping bodies when
`invulnerable` turns false.

## Exports

- `size: Vector2` — rectangle size in pixels, default `16×16`. The zone is
  centered on the node's position. Clamped to at least 1×1.
- `damage: int` — damage per hit, default `1`.
- `debug_enabled` — prints a log line on each hit.

## Placing and resizing

1. Instance `SpikeHazard.tscn` in the level.
2. Move it so it sits over the spikes.
3. Set `size` in the instance's inspector. No need to enable "Editable
   Children" or edit the `CollisionShape2D`.

The shape is `resource_local_to_scene`, so each instance has its own shape and
resizing one never affects another.

- **Single tile:** leave the default `16×16`.
- **Longer section:** widen `size.x`, e.g. `Vector2(48, 16)` for three tiles.
  Move the node to the *center* of the section.
- **Fairer hitbox:** shrink the height so only the spike tips count, e.g.
  `Vector2(48, 8)`, and place the node over the upper part of the tiles.

Keep the instance scale at 1. Use `size` to resize instead of scaling the
node.

In the editor a translucent red outline shows the zone so you can align it
with the tiles. It is drawn only while `Engine.is_editor_hint()` is true and
never appears in the game.

## No sprite, on purpose

Like [ACTIVATION_BUTTON.md](ACTIVATION_BUTTON.md), the scene has no
`Sprite2D`. The spike art stays in the level's tileset, and the hazard only
supplies the damage volume. Spike art and damage logic stay independent.

## Example wiring

```gdscript
[node name="SpikeHazard" parent="." instance=ExtResource("9_spike")]
position = Vector2(312, 56)
size = Vector2(48, 8)
```

## Related

- [HITBOX_HURTBOX.md](../enemies_logic/HITBOX_HURTBOX.md) — the project's
  damage-area conventions and collision layers.
- [HEALTH_COMPONENT_LOGIC.md](../enemies_logic/HEALTH_COMPONENT_LOGIC.md) —
  the health component the player's `take_damage()` ends up calling.
- [ACTIVATION_BUTTON.md](ACTIVATION_BUTTON.md) — the other invisible,
  tileset-independent trigger.
