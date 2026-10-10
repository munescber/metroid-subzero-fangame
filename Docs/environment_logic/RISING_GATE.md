# Rising Gate — Behavior Notes

A one-shot gate that slides straight up when an `ActivationButton` fires.
It is independent from the Rising Platform ([RISING_PLATFORM.md](RISING_PLATFORM.md))
and shares no code with it.

## Files

- `Scripts/Environment/rising_gate.gd` — movement logic (`class_name RisingGate`).
- `Scenes/Environment/rising_gate.tscn` — the gate scene.
- `Scripts/Environment/activation_button.gd` — the trigger, documented in
  [ACTIVATION_BUTTON.md](ACTIVATION_BUTTON.md).
- `Scenes/Levels/level_wrecked_ship_0.tscn` — test wiring (`RisingGate` + `GateButton`).

## Scene structure

```text
RisingGate (Node2D, script: rising_gate.gd)
└── Body (AnimatableBody2D)      <- the part that moves; z_index = -1, collision_mask = 0
    ├── TileTop (Sprite2D)       <- miscellaneous.png region (48, 32, 16, 16), at (0, -8)
    ├── TileBottom (Sprite2D)    <- same region, at (0, 8)
    └── CollisionShape2D         <- RectangleShape2D 16x32, centered
```

`Body` is centered on the gate's origin. Its position in the editor is the
**closed** position; the script reads it at `_ready()`, so moving the
`RisingGate` node (or `Body`) is all that is needed to place the gate.

## Button behavior (`ActivationButton`)

The button is an `Area2D` that knows nothing about the gate's internals.

- **Detection:** `collision_mask = 2 | 8`.
  - Layer 2 (PlayerBody): the button fires when a body in the `player` group
    steps on it.
  - Layer 8 (Hitbox): the button fires when the area belongs to a `Bullet`
    (normal shot, and `ChargeBeam` which extends it) or a `Missile`. Enemy
    attack areas on the same layer are ignored.
- **Same sensitivity everywhere:** the trigger area is baked into the button
  scene (17.6×17.6 shape, instance scale 1). Don't scale button instances in
  a level, or their sensitivity will differ.
- **Linking:** set `target_path` on the button to the gate
  (e.g. `../RisingGate`).
- **Calling the target:** on trigger the button calls `activate()` on the
  target. If `toggle_mode` is on and the target has `toggle()`, it calls
  `toggle()` instead. The gate has no `toggle()`, so it always receives
  `activate()`.
- **`one_shot`:** when on, the button ignores every trigger after the first.
  The gate is already safe against repeats, so `one_shot` is optional;
  `GateButton` enables it anyway.
- **`debug_enabled`:** logs triggers and ignored areas.

## Gate behavior (`rising_gate.gd`)

1. The gate starts closed (or open if `start_open` is on).
2. `activate()` is called by the button. It does nothing if the gate is
   already rising or already open, so repeated hits never restart the movement.
3. Otherwise `is_moving` becomes true and a `Tween` is created:
   - optional `start_delay` wait,
   - then `Body.position` moves from the closed position to
     `closed - Vector2(0, rise_distance)` over `rise_duration`
     (upward, decreasing Y).
4. When the tween finishes, `is_moving` becomes false, `is_open` becomes true
   and the `opened` signal is emitted.
5. The gate stays open permanently. There is no `lower()` or `toggle()`.

The tween runs in the physics step (`TWEEN_PROCESS_PHYSICS`) because `Body`
is an `AnimatableBody2D`, so the player is blocked and carried correctly
while it moves.

### Collision

- `Body` is on the default layer 1 (World), like normal terrain, with
  `collision_mask = 0`. The player collides with it before, during and after
  the rise.
- The collision shape is separate from the sprites. Changing the sprite does
  not change collision or movement distance.

### Draw order

`Body.z_index = -1` draws the gate behind the terrain `TileMapLayer`
(`z_index = 0`), so it can rise out of tiles that cover it. See
[BACKGROUND_LAYERS.md](BACKGROUND_LAYERS.md). Change `Body`'s Z Index in the
Inspector if the gate should draw in front instead.

## Inspector settings (`RisingGate`)

| Group | Property | Default | Meaning |
|---|---|---|---|
| Movement | `rise_distance` | 32 | Pixels moved upward |
| Movement | `rise_duration` | 1.0 | Seconds the rise takes |
| Movement | `start_delay` | 0.0 | Seconds to wait before rising |
| Movement | `ease_type` | In/Out | Tween easing |
| Movement | `trans_type` | Sine | Tween transition |
| State | `start_open` | off | Start in the raised position |
| — | `debug_enabled` | off | Print debug logs |

Public API: `activate()`, state flags `is_open` / `is_moving`, signal `opened`.

## Customizing the sprite

1. Open `rising_gate.tscn`.
2. Ctrl+click `Body/TileTop` and `Body/TileBottom` to edit both at once.
3. In the Inspector, change **Texture** or **Region → Rect**.

If the new sprite is not 16×32 in total, also resize `Body/CollisionShape2D`
and adjust `rise_distance`. Neither follows the sprite automatically.

## Level wiring

```gdscript
[node name="RisingGate" parent="." instance=ExtResource("9_gate")]
position = Vector2(904, -79)

[node name="GateButton" parent="." instance=ExtResource("8_button")]
position = Vector2(824, -24)
target_path = NodePath("../RisingGate")
one_shot = true
```

## Validation status

Checked in a headless Godot 4.7.1 run of the level: the button triggers the
gate, it rises smoothly to `-rise_distance`, stops there, and a second
`activate()` does nothing. The original `RisingPlatform` was unaffected.
Not yet tested in-game: blocking/carrying the player and the visual
placement of the gate in the level.
