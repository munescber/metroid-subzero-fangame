# Room Gate — Implementation Notes

A bubble gate that blocks a doorway until the player shoots it. It plays an
opening animation while still solid, then loses all collision and stays open
permanently (there is no closing logic).

## Files

| File | Role |
|---|---|
| `Scripts/Environment/room_gate.gd` | Logic (`class_name RoomGate`, extends `StaticBody2D`) |
| `Scenes/Environment/room_gate.tscn` | Gate scene: sprite, collision, hurtbox |
| `Spritesheets/room_gate_animation.png` | 64×96 sheet; only the top 48 px is used |
| `Scripts/Common/hurtbox.gd` | Existing `Hurtbox`, forwards hits to the gate |
| `Scenes/Levels/level_wrecked_ship_0.tscn` | `RoomGate` instance + `ForegroundTileMapLayer` (hatch frame) |

Related docs: [BACKGROUND_LAYERS.md](BACKGROUND_LAYERS.md) (foreground layer),
[ACTIVATION_BUTTON.md](ACTIVATION_BUTTON.md), [RISING_GATE.md](RISING_GATE.md).

## How the gate looks in the level

The doorway at the far edge of `level_wrecked_ship_0` is made of two columns:

| Column | Content | Where it lives |
|---|---|---|
| x = 74 | Glass bubble, 16×48 (3 tiles tall, cells y = -6 to -4) | The `RoomGate` scene instance (animated) |
| x = 75 | Grey/blue hatch frame, atlas tiles `(9,0)`, `(9,1)`, `(9,2)` from `miscellaneous.png` | `ForegroundTileMapLayer` (`z_index = 2`) |

The bubble cells are **empty** in the terrain `TileMapLayer`; the gate scene
provides both their art and their collision. The hatch frame is purely visual
and is drawn above the player, so the player appears to go behind it.

## Scene structure

```text
RoomGate (StaticBody2D, script: room_gate.gd)   <- layer 1 (World), mask default
├── AnimatedSprite2D                            <- "idle" and "open" animations
├── CollisionShape2D                            <- RectangleShape2D 16x48
└── Hurtbox (Area2D, hurtbox.gd)                <- layer 16 (Hurtbox), mask 0
    └── CollisionShape2D                        <- RectangleShape2D 20x52
```

- The node origin is the center of the 16×48 bubble. In the level it sits at
  `(1192, -71)`: the center of the three tiles (x = 74 → 74·16 + 8, y = -6..-4)
  including the terrain layer's +1 y offset.
- The hurtbox is slightly larger than the body (2 px per side, 2 px top and
  bottom) so overlaps are detected reliably before a projectile touches the
  solid body.

## Sprite sheet and animations

`room_gate_animation.png` is 64×96 px. The four frames are 16×48 and sit side by
side at `x = 0, 16, 32, 48` in the top 48 px. The bottom half is empty and is
used for the empty "open" frame.

| Animation | Frames (region on the sheet) | Loop | Speed |
|---|---|---|---|
| `idle` | Frame 1: `Rect2(0, 0, 16, 48)` — closed bubble | yes | 5 fps (single frame) |
| `open` | `(0,0)`, `(16,0)`, `(32,0)`, `(48,0)`, then empty `(0,48)` — 5 frames | no | 10 fps |

Frames are `AtlasTexture` sub-resources of the sheet inside `room_gate.tscn`, so
the sheet can be re-painted without touching the scene as long as the layout
stays the same. The sprite stays on the last (empty) frame once `open` ends.

## Behavior

State flags: `is_opening` and `is_open` (both start `false`).

```text
closed (idle, solid)
   │  player projectile hits  ->  take_damage()
   ▼
opening (open animation plays, STILL solid)
   │  animation_finished("open")
   ▼
open (no collision, signal `opened` emitted)  -> stays open forever
```

1. `_ready()` applies `open_speed_scale`, connects `animation_finished` and
   plays `idle`.
2. `take_damage(amount, source)` is the single entry point. It does nothing if
   the gate is already opening/open, or if `source` is not the player.
3. Otherwise it sets `is_opening = true` and plays `open`.
4. On `animation_finished` for `open`, it sets `is_opening = false`,
   `is_open = true`, disables **both** collision shapes with `set_deferred`
   (body and hurtbox), and emits `opened`.

Disabling shapes must be deferred because the signal fires during physics
processing. Hits that arrive during or after the animation are ignored.

### Player-only filter

Enemy attack areas share the same physics layers as the player's projectiles,
so the gate checks the *source* instead:

```gdscript
source is CollisionObject2D and (source.collision_layer & PLAYER_BODY_LAYER) != 0
```

`PLAYER_BODY_LAYER` is `2` (PlayerBody). Projectiles pass the player as their
`shooter`/`source`, so any beam or missile fired by the player qualifies;
enemies (layer 4) do not. No scene-saved group is needed.

## How projectiles reach the gate

The gate does not detect projectile areas itself (see "Why not
ActivationButton"). It plugs into the project's existing damage path, so no
projectile script was changed:

| Projectile | What happens |
|---|---|
| `Bullet` | `move_and_collide()` hits the solid body → `_on_hit()` finds the `Hurtbox` child and calls `receive_hit()`, which calls `take_damage()` on the gate. The bullet's own `Hitbox` can also trigger `receive_hit()`. |
| `ChargeBeam` | Extends `Bullet`, so identical to the above. |
| `Missile` | Collides with the solid body and explodes at the contact point. The explosion queries layer 16 (Hurtbox) areas and calls `receive_hit()` on the gate's `Hurtbox`. |

`Hurtbox.receive_hit()` forwards to its parent's `take_damage()`, and the gate's
guards make repeated calls from the same shot harmless.

### Collision layers

| Layer | Name | Used by the gate for |
|---|---|---|
| 1 | World | `RoomGate` body: blocks the player and stops projectiles |
| 4 (bit 8) | Hitbox | Not used by the gate (projectile hitboxes live here) |
| 5 (bit 16) | Hurtbox | `Hurtbox` child: lets projectiles/explosions find the gate |

The player collides with layer 1, so the gate blocks them for as long as the
body shape is enabled (the whole `open` animation included).

## Draw order

- `RoomGate` keeps the default `z_index = 0`. It is a later node in the scene
  than the terrain layer, so it draws on top of the terrain, and nothing needs
  to hide it.
- The hatch frame is on `ForegroundTileMapLayer` (`z_index = 2`). Player,
  bullets, charge beam, missiles and dash afterimages are all at 0 (the
  player's charge effect at 1), so all of them draw behind the frame.

## Inspector settings (`RoomGate`)

| Property | Default | Meaning |
|---|---|---|
| `open_speed_scale` | 1.0 | Multiplier on the `open` animation speed (base 10 fps). 2.0 opens twice as fast |
| `debug_enabled` | off | Prints ignored hits, opening and open events |

Public API: `take_damage()` (called by projectiles), flags `is_opening` /
`is_open`, signal `opened`.

To change the base speed or the frames, edit the `open` animation in the
`SpriteFrames` resource of `AnimatedSprite2D`.

## Why not ActivationButton

`ActivationButton` listens for projectile *areas* entering its trigger. A solid
gate is different: `Bullet` and `Missile` collide with World-layer bodies and
are freed or explode on impact, so an area trigger behind or inside a solid body
is not reliably entered first. Routing through `take_damage()` / `Hurtbox`
works for all three projectile types and also keeps the gate solid until the
animation ends.

The button's "player group" check was also avoided, because the player is not
assigned to a `player` group; the collision-layer check is used instead.

## Placing another gate

1. Leave the doorway cells (3 tiles tall, 1 wide) empty in the terrain
   `TileMapLayer`.
2. Instance `Scenes/Environment/room_gate.tscn` and set its position to the
   center of those cells (remember the terrain layer's +1 y offset).
3. Paint any frame around it on `ForegroundTileMapLayer` (visual only).
4. Connect to the `opened` signal if something else should react (a door
   sound, unlocking the next room, etc.).

## Testing notes

Verified headless: the level loads, the foreground layer holds cells
`(75,-6..-4)` at `z_index = 2`, the gate is at `(1192, -71)`, an enemy-layer hit
is ignored, and a player `Bullet`, `ChargeBeam` and `Missile` each open the gate;
the body and hurtbox shapes are disabled when the animation ends.

Still worth confirming by playing: the player stays blocked until the last
frame, walking through the opened doorway feels right, and the hatch frame
covers the player as intended.

## Known limitations

- One-way: the gate never closes again and has no `toggle()`.
- Only the player's projectiles open it; there is no activation-button or
  contact trigger.
- The empty `open` frame is a region of the sheet; the sheet's bottom 48 px must
  stay transparent.
