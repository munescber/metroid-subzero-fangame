# Missile Gate — Implementation Notes

An iron fence that blocks a doorway until a missile explodes on it. It is placed on
top of a normal [Room Gate](ROOM_GATE.md) and is independent of it.

## Files

| File | Role |
|---|---|
| `Scripts/Environment/missile_gate.gd` | Logic (extends `StaticBody2D`, no `class_name`) |
| `Scenes/Environment/missile_gate.tscn` | Gate scene: sprite, solid body, missile detector |
| `Spritesheets/missile_gate.png` | Fence art; the idle frame is `Rect2(32, 0, 16, 48)` |

## Adding it to a level

Instance `Scenes/Environment/missile_gate.tscn` (drag it into the scene, or Ctrl+Shift+A).
Do not add a plain node from the Create Node dialog: that creates a bare `StaticBody2D` with no
collision shape, sprite or detector.

## Scene structure

```text
MissileGate (StaticBody2D, script: missile_gate.gd)   <- layer 1 (World): blocks the player
├── AnimatedSprite2D                                  <- "idle" and "open" animations
├── CollisionShape2D                                  <- RectangleShape2D 12x48 at (2, 0), same as RoomGate
└── MissileDetector (Area2D)                          <- layer 0, mask 8 (Hitbox), not monitorable
    └── CollisionShape2D                              <- RectangleShape2D 18x52 at (2, 0)
```

The "open" animation is empty and is meant to be filled in. It must not loop. With no frames,
the gate opens and is freed immediately.

## How it tells missiles from beams

`Bullet`, `ChargeBeam` and `Missile` all call `take_damage()` / `receive_hit()` with only
`(damage, shooter)`, so those calls cannot identify a missile. The gate has no `take_damage()`,
so beams are stopped by the solid body and do nothing. Missiles are found like `ActivationButton`
does it: the `MissileDetector` sees the missile's `Hitbox` / `ExplosionArea`, and
`area.get_parent() is Missile` identifies the projectile by class. The gate opens when a
tracked missile has `has_exploded == true`, so it opens only on an actual impact
(on this body or on the RoomGate underneath it), not on a missile that flies past.

## Opening

1. `is_open` is set, so a repeated hit does nothing.
2. The body is disabled and the detector stops monitoring (deferred).
3. `opened` is emitted and `"open"` plays.
4. The gate is freed when the animation ends (`free_when_open`).

## Exports

| Export | Meaning |
|---|---|
| `free_when_open` | Free the gate after the animation (default on). |
| `save_id` | Optional stable id; the open state is stored with `SaveManager.set_flag()` and the gate is freed on load. |
| `debug_enabled` | Prints state changes. |

## Notes

- Each instance tracks missiles itself, so several gates can share a room.
- The detector is wider than the body, so two gates less than about 18 px apart can open together.
- The RoomGate underneath keeps its own behaviour: a missile or beam that reaches its Hurtbox
  still opens it, but the player stays blocked until the Missile Gate opens.
