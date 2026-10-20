Beam Impact Effect
==================

Overview
--------
When the normal beam (`Bullet`) or the Charge Beam (`ChargeBeam`) hits
something, a short, purely visual impact animation plays at the hit point.
It is one shared scene, `Scenes/Effects/beam_impact.tscn`, and each beam picks
which of its animations to play. For beam behaviour itself see
`BEAM_LOGIC.md`.

The effect is only visuals. It has no collision, deals no damage, and does not
change the projectile's speed, damage, lifetime, hit handling or collision
layers.

Files
-----
- `Scenes/Effects/beam_impact.tscn` - `AnimatedSprite2D` named `BeamImpact`.
  Its SpriteFrames holds one animation per beam type (`impact`,
  `impact_charge`).
- `Scripts/Effects/beam_impact.gd` (`BeamImpact`) - plays the chosen
  animation once, then frees the node.
- `Scripts/Player/bullet.gd` (`Bullet`) - spawns the effect. `ChargeBeam`
  inherits this, so it needs no extra code.

How it works
------------
1. The projectile detects a hit through its existing logic:
   - wall / body hit via `move_and_collide` -> `_on_hit(collider, position)`
   - Hitbox overlap with a Hurtbox -> `_on_area_entered` / `_on_body_entered`
2. Right after the damage call, `Bullet._spawn_impact(position)` runs:
   - instantiates `impact_effect_scene`
   - sets its `impact_animation` to the projectile's own `impact_animation`
   - adds it to the projectile's **parent** (not the projectile itself), so
     it keeps playing after the projectile is freed
   - places it at the hit position and rotates it to the shot direction
3. `BeamImpact._ready()` plays that animation once. When it finishes
   (`animation_finished`) the effect calls `queue_free()`.

Hit position
------------
- Wall / body hits (`move_and_collide`): the real contact point
  (`collision.get_position()`).
- Hitbox overlaps: the projectile's `global_position` at the moment of the hit.

Rotation matches the projectile, so draw impact frames facing **right**
(the direction the shot travels).

Duplicate protection
--------------------
`_spawn_impact` does nothing if the projectile is already queued for deletion,
so two hit signals arriving in the same frame spawn only one effect. A beam
with `one_shot = false` (pierces) spawns one effect per target hit.

Properties on `Bullet` (set in the beam's scene)
------------------------------------------------
| Property | Default | Purpose |
|----------|---------|---------|
| `impact_effect_scene` | `beam_impact.tscn` | Which effect scene to spawn. |
| `impact_animation` | `impact` | Which animation of that scene to play. |

Current setup:
| Beam | Scene | `impact_animation` |
|------|-------|--------------------|
| Normal beam | `bullet.tscn` | `impact` (default) |
| Charge Beam | `charge_beam.tscn` | `impact_charge` |

Adding or editing the art
-------------------------
1. Open `Scenes/Effects/beam_impact.tscn` and select the `BeamImpact` node.
2. Open its Sprite Frames panel (bottom of the editor).
3. Pick the animation and add frames; set the FPS.
4. Keep **Loop off**. A looping animation never emits `animation_finished`,
   so the effect would never remove itself.
5. Save the scene.

An animation with no frames is valid: the effect frees itself immediately and
nothing is shown. This is the state of the placeholders until art is added.

Linking a new beam
------------------
Example: a new ice beam.

1. Create the projectile scene. Reuse the `Bullet` script (or a script that
   `extends Bullet`), like `charge_beam.tscn` does.
2. In `beam_impact.tscn`, add a new animation to the SpriteFrames, e.g.
   `impact_ice`, with Loop off, and add its frames.
3. Select the root node of the new beam scene and, in the Inspector, set
   **Impact Animation** to `impact_ice`.
4. Done. No script changes are needed.

If a beam needs a completely different effect (different node structure,
extra particles, sound), create a new effect scene and drag it into **Impact
Effect Scene** on that beam instead. A custom effect scene should:
- have a `Node2D`-based root (it is positioned and rotated by `Bullet`),
- free itself when finished,
- have no collision, so it cannot affect gameplay.

If the root script is `BeamImpact`, `impact_animation` is set for it
automatically.

Troubleshooting
---------------
- **Nothing shows up**: the animation is probably empty (no frames yet), or
  the name in **Impact Animation** does not match.
- **Warning `BeamImpact: animation 'x' not found`** in the Output panel: the
  name typed in **Impact Animation** does not exist in the effect's
  SpriteFrames. Names are case-sensitive.
- **Effect never disappears**: Loop is enabled on that animation.
- **Effect appears but is rotated wrong**: draw the frames facing right.
