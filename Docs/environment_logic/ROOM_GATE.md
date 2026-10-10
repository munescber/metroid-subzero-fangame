# Room Gate — Implementation Notes

A bubble gate that blocks a doorway until the player shoots it. Once opened
it stays open permanently.

## Files

- `Scripts/Environment/room_gate.gd` — logic (`class_name RoomGate`).
- `Scenes/Environment/room_gate.tscn` — the gate scene.
- `Spritesheets/room_gate_animation.png` — 64×96 sheet; the top 48 px holds four
  16×48 frames, the rest is empty.
- `Scenes/Levels/level_wrecked_ship_0.tscn` — `RoomGate` instance at the far
  edge of the room, plus the `ForegroundTileMapLayer` with the hatch frame
  (see [BACKGROUND_LAYERS.md](BACKGROUND_LAYERS.md)).

## Scene structure

```text
RoomGate (StaticBody2D, script: room_gate.gd)   <- layer 1 (World), blocks the player
├── AnimatedSprite2D                            <- "idle" and "open" animations
├── CollisionShape2D                            <- RectangleShape2D 16x48
└── Hurtbox (Area2D, hurtbox.gd)                <- layer 16, shape 20x52
    └── CollisionShape2D
```

The node origin is the center of the 16×48 bubble. In the level it sits at the
center of the three tiles it covers (column 74, rows -6 to -4, plus the tile
layer's +1 y offset).

## Animations

| Animation | Frames | Loop | Speed |
|---|---|---|---|
| `idle` | sheet frame 1 (closed bubble) | yes | — |
| `open` | frames 1, 2, 3, 4 (`x = 0, 16, 32, 48`), then an empty 16×48 region at `(0, 48)` | no | 10 fps |

## Behavior

1. The gate starts closed and solid, playing `idle`.
2. A player projectile hits it. `Bullet` and `ChargeBeam` call `take_damage()`
   on the body they collide with; `Missile` explosions call `receive_hit()` on
   the `Hurtbox`, which forwards to `take_damage()` on the gate. This is the
   project's normal damage path, so no projectile code was changed.
3. `take_damage()` only reacts if the source is the player
   (`source.collision_layer & 2`, PlayerBody). Enemy attack areas share the same
   layers and are ignored.
4. The `open` animation plays while the gate is **still solid**.
5. When it finishes, the body and hurtbox collision shapes are disabled
   (deferred), `is_open` becomes true and `opened` is emitted. The sprite stays
   on the last, empty frame. There is no closing logic.

Hits during the animation or after opening are ignored.

## Inspector settings

| Property | Default | Meaning |
|---|---|---|
| `open_speed_scale` | 1.0 | Multiplier on the `open` animation speed |
| `debug_enabled` | off | Print debug logs |

Public API: `take_damage()` (called by projectiles), state flags `is_opening` /
`is_open`, signal `opened`.

## Why not ActivationButton

`ActivationButton` detects projectile *areas*, but projectiles collide with
World-layer solids and are freed on impact, so a solid gate would stop them
before an area trigger reliably fires. Using the existing damage path avoids
that.

## Placing another gate

Instance `room_gate.tscn`, set its position to the center of the doorway tiles,
and keep the doorway cells empty in the terrain `TileMapLayer`. Draw any frame
around it on the foreground layer.
