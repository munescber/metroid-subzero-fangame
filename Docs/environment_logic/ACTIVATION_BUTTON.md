# Activation Button — Implementation Notes

A reusable, fully decoupled trigger. Any number of instances can be dropped
into a level and pointed at any target — it has no knowledge of
`RisingPlatform` or any other specific receiver.

## Files

- `Scripts/Environment/activation_button.gd` — the trigger's behavior.
- `Scenes/Environment/activation_button.tscn` — the button scene (`Area2D`
  + `CollisionShape2D`, no visual — see "No sprite, on purpose" below).
- `Scripts/Player/bullet.gd` — has `class_name Bullet` so the button can
  identify player projectiles without relying on groups.

## What it does

An `Area2D` that reacts to two independent trigger paths and calls
`activate()`/`toggle()` on whatever `target_path` points to:

- **Stepped on** — `body_entered`, checks `body.is_in_group("player")`.
- **Shot** — `area_entered`, checks that the entering area's parent `is
  Bullet` (normal shot and `ChargeBeam`, which extends `Bullet`) or `is
  Missile` (`class_name Missile` in `missile.gd`). This intentionally
  does **not** use a scene-saved `group`, because a group added directly to
  a `.tscn` file can be silently lost if the scene is open in the editor and
  gets re-saved from stale in-memory state — using the script's own class
  identity is immune to that.

## Collision setup

- `collision_layer = 0` — the button itself is never something else
  collides *into*; it only listens.
- `collision_mask = 2 | 8` (PlayerBody + Hitbox).
- Trigger shape is 17.6×17.6, baked into the scene. Keep instance scale at 1
  in levels so every button has the same sensitivity.

### Why layer 8 needed filtering

Collision layer 8 ("Hitbox") is shared by **all** damage-dealing areas in
the project — the player's bullet, but also enemy `ContactDamage` and
`ElectricField` areas. Without the `is Bullet` check, any enemy attack area
that happened to overlap the button would also trigger it.

## Public API / exports

- `one_shot` — if true, the button fires once and then ignores further
  triggers.
- `toggle_mode` — if true, calls `toggle()` on the target instead of always
  `activate()`.
- `target_path: NodePath` — resolved once in `_ready()`. Must point at the
  node that actually exposes `activate()`/`toggle()` (e.g. the
  `RisingPlatform` root, not one of its children).
- `debug_enabled` — prints a log line whenever the button fires.

## No sprite, on purpose

`activation_button.tscn` has no `Sprite2D` — it's a pure invisible trigger
volume. This is intentional, not an oversight: it keeps the scene fully
decoupled from any specific art, so it can be:

- Instanced many times per level without visual duplication concerns.
- Positioned over existing level geometry (a cracked wall, a switch prop
  drawn as part of the tileset, an enemy corpse, etc.) instead of bringing
  its own graphic.
- Reused for completely different trigger concepts (switches, pressure
  plates, shootable targets) just by changing `target_path` and the
  collision mask, without touching the base scene.

If a level needs a visible cue, add that art as part of the level's own
tileset/decoration layer at the button's position rather than inside the
button scene itself — keeps the trigger logic and the visual presentation
independent, same as with `RisingPlatform`.

## Example wiring

```gdscript
[node name="ActivationButton" parent="." instance=ExtResource("8_button")]
position = Vector2(856, -39)
target_path = NodePath("../RisingPlatform")
debug_enabled = true
```

## Related

- [RISING_PLATFORM.md](RISING_PLATFORM.md) — the first (and so far only)
  consumer of this trigger.
- [BACKGROUND_LAYERS.md](BACKGROUND_LAYERS.md) — draw-order conventions for
  objects this button might reveal (e.g. a hidden platform or breakable
  wall insert).
