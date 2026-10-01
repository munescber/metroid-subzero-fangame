# Rising Platform — Implementation Notes

Branch: `feat/rising-platform` (based on `origin/main` @ `e97f230`).

## Goal

A pillar-like platform that starts retracted (hidden below/behind the floor)
and rises out of the floor when an external trigger (button, lever, shot,
etc.) calls `activate()`. Fully decoupled from whatever triggers it.

## Files

- `Scripts/Environment/rising_platform.gd` — the platform's behavior.
- `Scripts/Environment/activation_button.gd` — a reusable trigger, documented
  separately in [ACTIVATION_BUTTON.md](ACTIVATION_BUTTON.md).
- `Scenes/Environment/rising_platform.tscn` — the platform scene.
- `Scenes/Environment/activation_button.tscn` — the button scene.
- `Scripts/Player/bullet.gd` — has `class_name Bullet` (added for this
  feature) so triggers can identify player projectiles.
- `Scenes/Levels/level_wrecked_ship_0.tscn` — test wiring for both, plus the
  `BackgroundTileMapLayer`/draw-order setup described in
  [BACKGROUND_LAYERS.md](BACKGROUND_LAYERS.md).

## Scene structure

```text
RisingPlatform (Node2D, script: rising_platform.gd)
└── Body (AnimatableBody2D)            <- the part that actually moves
    ├── TileTop (Sprite2D)             <- miscellaneous.png tile (16,0,16,16)
    ├── TileMiddle (Sprite2D)          <- same tile, stacked
    ├── TileBottom (Sprite2D)          <- same tile, stacked
    └── CollisionShape2D               <- RectangleShape2D 16x48, centered
```

`Body`'s three stacked 16×16 tiles form the visible 16×48 pillar and share one
`CollisionShape2D`. `Body` is on `collision_layer = 1` (World), `collision_mask
= 0`, so the player collides with it exactly like normal terrain and can
stand on / be carried by it via `move_and_slide()`'s built-in platform
handling.

`Body` no longer carries its own decorative cap — the level's real terrain
`TileMapLayer` covers the retracted segment instead. See
[BACKGROUND_LAYERS.md](BACKGROUND_LAYERS.md) for the full draw-order model.

## Positioning model (important)

`RisingPlatform`'s own origin **is the anchor point** — place the whole
prefab wherever the floor tile/shaft opening should be, snapped to the grid
like a normal tile. Everything else is computed automatically in
`_ready()`:

- `_lowered_local = Vector2(0, tile_size)` — retracted position, one tile
  row (`tile_size`, default `16`) below the anchor. This puts `Body`'s
  `TileTop` cell exactly where the level's real floor "cap" tile is, so the
  top segment is visually covered at rest.
- `_raised_local = _lowered_local - Vector2(0, rise_distance)` — raised
  position, `rise_distance` (default `48`, i.e. the pillar's own height)
  above the retracted position.

`Body.position` (local, relative to the wrapper) is tweened between these
two values.

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

`RisingPlatform` is deliberately unaware of what triggers it — it only
exposes `activate()`/`lower()`/`toggle()`. In this scene the trigger is
`ActivationButton`, fully documented on its own in
[ACTIVATION_BUTTON.md](ACTIVATION_BUTTON.md) since it's a general-purpose,
reusable node not specific to this platform.

## Level wiring (`level_wrecked_ship_0.tscn`)

```gdscript
[node name="RisingPlatform" parent="." instance=ExtResource("7_platform")]
position = Vector2(872, -23)
rise_duration = 1.0
debug_enabled = true

[node name="ActivationButton" parent="." instance=ExtResource("8_button")]
position = Vector2(856, -39)
target_path = NodePath("../RisingPlatform")
debug_enabled = true
```

## Draw order — resolved

Previously `ShaftCap` was a separate `Sprite2D` painted per-level to fake a
floor tile covering the retracted pillar, and `Body` had no `z_index`
override, so it tied with the `TileMapLayer` (`z_index = 0`) and drew **in
front of** solid ground by scene-tree order.

The fix adopted a project-wide draw-order convention instead of per-node
hacks:

- `Body.z_index = -1` — always draws behind the main terrain `TileMapLayer`
  (`z_index = 0`), regardless of tree order.
- `ShaftCap` node removed from `rising_platform.tscn` entirely. The real
  terrain tile now plays that role: the level's `TileMapLayer` must have an
  actual floor tile painted at the retracted top segment's position (the
  "cap"), and genuinely empty cells (no tile) for every row above it that
  the pillar passes through while rising.
- This requires level geometry to match: any cell that should let the
  raised pillar show through must be truly empty, not just a tile that
  looks like black sky. `level_wrecked_ship_0`'s shaft column was manually
  corrected in the tile-painting tool to satisfy this.
- `Scenes/Environment/shaft_cap.tscn` is now fully superseded and can be
  deleted (see Housekeeping).
- See [BACKGROUND_LAYERS.md](BACKGROUND_LAYERS.md) for the general-purpose
  background/hidden-object/foreground layering convention this fix
  established — it applies beyond just this platform.

## Housekeeping

- `Scenes/Environment/shaft_cap.tscn` is dead code from an earlier iteration
  (before the cap was bundled into `rising_platform.tscn`) — candidate for
  deletion once confirmed unused elsewhere.
- Git: branch `feat/rising-platform` was created from `main` after a
  fetch+rebase to include `origin/main`'s latest merge (`feature/atomic-enemy`).
  Nothing has been committed yet as of this document.
