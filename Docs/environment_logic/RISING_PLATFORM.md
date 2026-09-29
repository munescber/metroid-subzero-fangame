# Rising Platform — Implementation Notes

Branch: `feat/rising-platform` (based on `origin/main` @ `e97f230`).

## Goal

A pillar-like platform that starts retracted (hidden below/behind the floor)
and rises out of the floor when an external trigger (button, lever, shot,
etc.) calls `activate()`. Fully decoupled from whatever triggers it.

## Files

- `Scripts/Environment/rising_platform.gd` — the platform's behavior.
- `Scripts/Environment/activation_button.gd` — a reusable trigger.
- `Scenes/Environment/rising_platform.tscn` — the platform scene.
- `Scenes/Environment/activation_button.tscn` — the button scene.
- `Scripts/Player/bullet.gd` — has `class_name Bullet` (added for this
  feature) so triggers can identify player projectiles.
- `Scenes/Levels/level_wrecked_ship_0.tscn` — test wiring for both.
- `Scenes/Environment/shaft_cap.tscn` — **unused/orphaned**, superseded by
  the bundled `ShaftCap` node inside `rising_platform.tscn`. Safe to delete.

## Scene structure

```text
RisingPlatform (Node2D, script: rising_platform.gd)
├── Body (AnimatableBody2D)            <- the part that actually moves
│   ├── TileTop (Sprite2D)             <- miscellaneous.png tile (16,0,16,16)
│   ├── TileMiddle (Sprite2D)          <- same tile, stacked
│   ├── TileBottom (Sprite2D)          <- same tile, stacked
│   └── CollisionShape2D               <- RectangleShape2D 16x48, centered
└── ShaftCap (Sprite2D)                <- static, does NOT move
```

`Body`'s three stacked 16×16 tiles form the visible 16×48 pillar and share one
`CollisionShape2D`. `Body` is on `collision_layer = 1` (World), `collision_mask
= 0`, so the player collides with it exactly like normal terrain and can
stand on / be carried by it via `move_and_slide()`'s built-in platform
handling.

`ShaftCap` is a plain decorative `Sprite2D`, not a child of `Body`, so it
never moves. Its `texture`/`region_rect` are overridden per level instance to
match that level's floor tileset (see wiring below).

## Positioning model (important)

`RisingPlatform`'s own origin **is the anchor point** — place the whole
prefab wherever the floor tile/shaft opening should be, snapped to the grid
like a normal tile. Everything else is computed automatically in
`_ready()`:

- `_lowered_local = Vector2(0, tile_size)` — retracted position, one tile
  row (`tile_size`, default `16`) below the anchor. This puts `Body`'s
  `TileTop` cell exactly where `ShaftCap` is, so the top segment is visually
  covered at rest.
- `_raised_local = _lowered_local - Vector2(0, rise_distance)` — raised
  position, `rise_distance` (default `48`, i.e. the pillar's own height)
  above the retracted position.

`Body.position` (local, relative to the wrapper) is tweened between these
two values — never the wrapper's own `position`, so `ShaftCap` is unaffected
by movement.

## Public API (`rising_platform.gd`)

- `activate()` — starts rising. No-op if already raised or mid-move.
- `lower()` — starts lowering. No-op if `can_reverse == false`, already
  lowered, or mid-move.
- `toggle()` — calls whichever of the above applies.
- State flags: `is_raised`, `is_moving`.
- Exported tuning: `rise_distance`, `rise_duration`, `start_raised`,
  `can_reverse`, `ease_type`, `trans_type`, `tile_size`, `debug_enabled`.
- Movement is a `Tween` (`create_tween()`), not `AnimationPlayer` — matches
  this project's convention of procedural/code-driven behavior over
  keyframed animation (see `atomic.gd`, `phantoon.gd`).

All state-changing calls (`activate`/`lower`/`toggle`) print a debug log when
`debug_enabled` is true, as does the tween's move-start and move-finished
callback.

## Trigger: `activation_button.gd`

An `Area2D` that reacts to two independent trigger paths, fully decoupled
from `RisingPlatform` (it just calls `activate()`/`toggle()` on whatever
`target_path` points to):

- **Stepped on** — `body_entered`, checks `body.is_in_group("player")`.
- **Shot** — `area_entered`, checks that the entering area's parent `is
  Bullet` (the `class_name Bullet` added to `bullet.gd`). This intentionally
  does **not** use a scene-saved `group`, because a group added directly to
  a `.tscn` file can be silently lost if the scene is open in the editor and
  gets re-saved from stale in-memory state — using the script's own class
  identity is immune to that.
- `collision_layer = 0`, `collision_mask = 2 | 8` (PlayerBody + Hitbox).
- `one_shot` / `toggle_mode` exported for reusability.
- `target_path: NodePath`, resolved once in `_ready()`. Must point at the
  `RisingPlatform` node itself (not `Body`), since that's where
  `activate()`/`toggle()` live.

### Why layer 8 needed filtering

Collision layer 8 ("Hitbox") is shared by **all** damage-dealing areas in
the project — the player's bullet, but also enemy `ContactDamage` and
`ElectricField` areas. Without the `is Bullet` check, any enemy attack area
that happened to overlap the button would also trigger it.

## Level wiring (`level_wrecked_ship_0.tscn`)

```gdscript
[node name="RisingPlatform" parent="." instance=ExtResource("7_platform")]
position = Vector2(872, -23)
rise_duration = 1.0
debug_enabled = true

[node name="ShaftCap" parent="RisingPlatform"]
texture = ExtResource("1_7sarq")           # wrecked_ship.png
region_rect = Rect2(32, 0, 16, 16)          # solid tan/orange floor tile

[node name="ActivationButton" parent="." instance=ExtResource("8_button")]
position = Vector2(856, -39)
target_path = NodePath("../RisingPlatform")
debug_enabled = true
```

`ShaftCap`'s art is overridden per level instance (it's just a `Sprite2D`
property override) to match whatever tileset that level uses — no need to
duplicate the whole platform scene per tileset.

## Known issue — not yet resolved

**Draw order between the retracted/rising pillar and the level's solid
tiles is unresolved.**

- With no `z_index` override on `Body`, ties with the `TileMapLayer`
  (`z_index = 0`) resolve by scene-tree order. Since `Body` is added after
  the `TileMapLayer`, it currently always draws **in front of** solid
  ground tiles. Net effect: only the single tile directly behind `ShaftCap`
  (which is explicitly `z_index = 1`) is properly hidden; the other two
  retracted segments visibly poke through the solid checkered ground tiles
  below the floor line.
- Setting `Body.z_index = -1` (tried and reverted) makes it draw behind the
  `TileMapLayer` correctly — but in `level_wrecked_ship_0`, the area that
  visually reads as open black "sky" above the floor line is **not actually
  empty** — it's real, solid-colored wall/floor tiles from
  `wrecked_ship.png`. With `z_index = -1`, the platform ends up hidden
  behind those tiles in every position, including fully raised, i.e.
  invisible at all times.
- **This is a level-geometry problem, not a script problem.** The
  `TileMapLayer`'s tile data is a binary `PackedByteArray` blob in the
  `.tscn` — not safely hand-editable as text. The fix requires manually
  erasing tiles in the Godot editor's tile-painting tool, in the platform's
  column, from underground up through **all** solid rows to genuinely open
  space, not just the 3 rows the pillar occupies.
- Once that gap exists: re-add `z_index = -1` to `Body` in
  `rising_platform.tscn`, and the layering should resolve correctly in both
  states.

## Housekeeping

- `Scenes/Environment/shaft_cap.tscn` is dead code from an earlier iteration
  (before the cap was bundled into `rising_platform.tscn`) — candidate for
  deletion once confirmed unused elsewhere.
- Git: branch `feat/rising-platform` was created from `main` after a
  fetch+rebase to include `origin/main`'s latest merge (`feature/atomic-enemy`).
  Nothing has been committed yet as of this document.
