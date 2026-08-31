# Implementation Plan — Atomic Enemy

## 1. Goal

Implement the `Atomic` flying enemy as a mobile nuisance/combat enemy that:

- Floats around the room.
- Periodically targets the player and slowly reaches out to them.
- Provides a clear visual warning before charging.
- Can activate an electric field around itself.
- Damages the player while the electric field is active. But contact with it also should damage. 
- Destroys/intercepts incoming missiles while the electric field is active.
- Cannot be damaged by missiles while the electric field is active.
- Communicates its current state clearly through animation and visual effects.

---

## 2. Preserve Existing Project Architecture

Before implementing new logic:

1. Inspect existing enemy scripts and identify the project's established patterns for:
   - Enemy health.
   - Hurtboxes.
   - Hitboxes/contact damage.
   - Player detection.
   - Projectiles/missiles.
   - Enemy movement.
   - Animation.
2. Reuse existing systems instead of creating parallel implementations.
3. Do not modify global player/projectile behavior unless necessary.
4. Keep Atomic-specific behavior contained within the Atomic enemy scene/script where possible.

---

## 3. Recommended Atomic Scene Structure

Use the existing enemy scene conventions, but conceptually organize the scene around:

```text
Atomic (CharacterBody2D)
├── Visuals (Node2D)
│   └── AnimatedSprite2D
│
├── ElectricFieldVisual (Sprite2D)
│
├── ElectricField (Area2D)
│   └── CollisionShape2D
│
├── Hurtbox
│   └── CollisionShape2D
│
├── ContactDamage / Hitbox
│   └── CollisionShape2D
│
└── DetectionArea (if the project already uses one)
    └── CollisionShape2D
```

Adapt the exact hierarchy to existing project conventions.

The important principle is that **visual rotation should not rotate gameplay collision nodes**.

---

# 4. Floating Movement

Atomic should fly rather than use ground-based movement.

Implement a slow floating movement system that does not depend on floor detection.

Possible initial behavior:

- Move through the room at a relatively slow speed.
- Periodically change direction or movement target.
- Maintain a floating/hovering feeling.
- Do not allow the enemy to fall due to gravity.

The exact movement pattern should be configurable so it can be tuned later.

Use exported variables where appropriate, for example:

```text
FLOAT_SPEED
FLOAT_CHANGE_INTERVAL
```

Do not over-engineer the movement yet.

---

# 5. Player Detection

Atomic should be able to determine when the player is within an appropriate range for its attack behavior.

Prefer the project's existing detection approach if one exists.

When the player becomes a valid target:

- Store/reference the player.
- Begin the attack sequence when appropriate.
- Avoid immediately dashing every frame.
- Include a cooldown between attacks.

If the player leaves the detection range, Atomic should eventually return to its normal floating behavior.

---

# 6. Atomic State Machine

Implement Atomic's behavior using explicit states.

Recommended initial states:

```text
FLOATING
CHARGING
DASHING
RECOVERING
ELECTRIC_CHARGING
ELECTRIC_FIELD
COOLDOWN
```

The exact implementation can use an enum/state variable consistent with existing project conventions.

### FLOATING

Default state.

- Slowly flies around.
- Breathing animation remains active.
- Visual rotation continues.
- Looks for the player.
- When attack conditions are met, transition to `CHARGING`.

### CHARGING

Telegraph the upcoming dash.

- Stop or significantly reduce normal movement.
- Determine the player's current position.
- Face/aim toward the player's position.
- Play a clear visual/audio warning.
- Briefly delay before attacking.

The warning should give the player enough time to recognize and avoid the upcoming dash.

### DASHING

- Move rapidly toward the chosen target position/direction.
- The dash should have a limited duration or distance.
- Do not continuously redirect toward the player during the dash unless testing shows that behavior is desirable.
- After the dash, transition to `RECOVERING`.

### RECOVERING

- Briefly slow down or stop.
- Prevent immediate repeated dashes.
- Use this state as a readable pause between attacks.

After recovery, either return to `FLOATING` or begin the electric-field sequence.

### ELECTRIC_CHARGING

Prepare the electric field.

- Display increasing electrical energy around Atomic.
- Increase the intensity of the electric-field visual.
- Use the shader to communicate that the field is about to activate.
- Keep this state short but clearly readable.

### ELECTRIC_FIELD

Activate the defensive/offensive field.

- Enable the `ElectricField` Area2D.
- The field damages the player on contact.
- The field intercepts/destroys missiles.
- Atomic should be immune to missile damage while the field is active.
- Keep the field active for a limited duration.

### COOLDOWN

After the electric field ends:

- Disable the electric field.
- Disable missile protection.
- Stop the electrical visual effect.
- Prevent immediate reactivation.
- Return to `FLOATING` when the cooldown finishes.

---

# 7. Electric Field Gameplay

The electric field should be implemented as an actual gameplay area rather than only a visual effect.

The field should have:

- A configurable radius.
- A collision shape independent from the visual sprite.
- A configurable active duration.
- A configurable damage value.

Suggested starting concept:

```text
Atomic sprite: 16x16
Electric field visual: approximately 48x48
Electric field collision: approximately 48x48
```

Do not assume the visual dimensions and collision dimensions must always be identical. Keep them independently configurable.

---

# 8. Missile Interaction

While `ELECTRIC_FIELD` is active:

- Incoming player missiles/projectiles should be detected by the electric field.
- Destroy the missile when it enters the field.
- Prevent the missile from damaging Atomic.
- Atomic should effectively be immune to missile-based attacks during this state.

Prefer using the project's existing projectile/hitbox architecture.

Do not modify every missile in the game specifically for Atomic if the collision/layer system can solve the interaction cleanly.

If the current projectile system supports hit detection through Areas/Hurtboxes, use the existing mechanism.

---

# 9. Player Damage

The electric field should damage the player while they are inside it.

Reuse the existing enemy hitbox/contact-damage system if available.

Avoid creating a completely separate damage system for the field.

The field should not necessarily damage the player every physics frame. Use the project's established damage cooldown/invulnerability behavior.

---

# 10. Electric Field Visual

Create a dedicated visual sprite/effect approximately 48x48 pixels around Atomic.

The visual should resemble electrical sparks surrounding the enemy.

Suggested palette:

```text
Dark green: #005800
Yellow:     #F8B800
White:      #FCFCFC
```

Use a shader to create the electrical/glowing appearance.

The shader should preferably provide a pulsing/animated effect rather than a static color change.

Suggested visual progression:

### Inactive

- Little or no electric effect.

### Electric charging

- Increasing brightness.
- White/yellow sparks become more visible.
- Energy appears to build up.

### Electric field active

- Strong yellow/white glow.
- Animated electrical movement.
- Clearly visible circular field around Atomic.

### Field ending

- Quickly reduce intensity.
- Return to the normal enemy appearance.

The visual effect must clearly communicate that the player should not fire missiles into the field.

---

# 11. Continuous Rotation

Atomic already has a breathing animation.

Add a separate visual rotation effect to make the entire creature continuously rotate clockwise.

Important:

**Do not rotate the root enemy node if that node contains gameplay collision/detection nodes.**

Instead, rotate a visual-only node such as:

```text
Atomic
└── Visuals
    └── AnimatedSprite2D
```

Rotate `Visuals`, not `Atomic`.

Example concept:

```gdscript
@export var rotation_speed := 1.0

func _process(delta: float) -> void:
    $Visuals.rotation += rotation_speed * delta
```

The exact speed should be exposed/configurable and tuned during testing.

Start with a slow rotation. The intended effect is a strange floating/rotating organism rather than a rapidly spinning object.

The breathing animation should continue independently of the rotation.

---

# 12. Dash Telegraph

The dash needs a strong visual warning.

Before the dash:

- Atomic should visibly prepare.
- Consider briefly stopping its normal movement.
- Consider increasing brightness or changing its animation.
- Consider a short electrical buildup.
- Consider a sound cue if the project has appropriate audio.

The player should be able to reasonably understand:

> Atomic is about to charge in this direction.

Avoid making the dash instantaneous or impossible to react to.

---

# 13. Tuning Variables

Expose important gameplay values so they can be tuned without rewriting the behavior.

Potential variables:

```text
float_speed
float_change_interval
detection_range

charge_duration
dash_speed
dash_duration
dash_cooldown

electric_charge_duration
electric_field_duration
electric_field_radius
electric_field_damage
electric_field_cooldown

visual_rotation_speed
```

Use sensible starting values based on the existing game's scale rather than arbitrary values.

---

# 14. Collision / Layer Considerations

Verify the project's existing collision layers before implementing the electric field.

The desired behavior is:

```text
Player
    ↓
Electric Field → damages player

Player Missile
    ↓
Electric Field → missile destroyed

Player Missile
    ↓
Atomic while field active → cannot damage Atomic
```

Avoid changing global collision layers without first checking how existing enemies, missiles, hitboxes, and hurtboxes are configured.

If possible, make the electric field's missile interaction through the existing hitbox/projectile architecture.

---

# 15. Animation Integration

Preserve the existing breathing animation.

Atomic should have:

- Normal floating/breathing animation.
- Optional charging visual/animation.
- Electric-field visual effect.
- Continuous slow rotation applied to the visual container.

Do not make the rotation part of the sprite animation itself. Keep it as a transform on the visual node so it can be independently tuned.

---

# 16. Testing Checklist

Test the enemy incrementally.

### Movement

- [ ] Atomic floats correctly.
- [ ] Atomic does not fall due to gravity.
- [ ] Atomic remains within intended movement space.
- [ ] Movement feels slow and organic.

### Rotation

- [ ] Atomic rotates continuously clockwise.
- [ ] Rotation does not rotate collision/detection nodes.
- [ ] Breathing animation continues normally.
- [ ] Rotation speed feels appropriate.

### Dash

- [ ] Atomic detects the player.
- [ ] Atomic enters charging state.
- [ ] Charging warning is clearly visible.
- [ ] Atomic charges toward the intended position.
- [ ] Dash has a readable duration.
- [ ] Atomic cannot immediately spam another dash.

### Electric Field

- [ ] Electric charging state is visible.
- [ ] Electric field activates correctly.
- [ ] Field damages the player.
- [ ] Field has the intended radius.
- [ ] Field ends after its duration.
- [ ] Atomic returns to normal behavior.

### Missile Interaction

- [ ] Missile entering the field is destroyed.
- [ ] Missile does not damage Atomic while the field is active.
- [ ] Missiles can damage Atomic normally when the field is inactive.
- [ ] The interaction is visually understandable.

### State Transitions

Verify that Atomic cannot become stuck in:

```text
CHARGING
DASHING
RECOVERING
ELECTRIC_CHARGING
ELECTRIC_FIELD
COOLDOWN
```

Test transitions when:

- Player dies.
- Player leaves detection range.
- Atomic is destroyed.
- Room changes.
- Multiple missiles enter the field simultaneously.

---

# 17. Final Design Goal

Atomic should feel like a dangerous, strange flying creature with a predictable combat rhythm:

```text
FLOAT
   ↓
NOTICE PLAYER
   ↓
CHARGE WARNING
   ↓
DASH
   ↓
RECOVER
   ↓
BUILD ELECTRIC ENERGY
   ↓
⚡ ELECTRIC FIELD
   ↓
MISSILES DESTROYED
   ↓
FIELD ENDS
   ↓
COOLDOWN
   ↓
FLOAT
```

The most important gameplay interaction is:

**Atomic becomes vulnerable during normal behavior → warns the player before attacking → dashes → activates an electric field → temporarily denies missile attacks → field expires → Atomic becomes vulnerable again.**

The player should be able to learn and anticipate this cycle rather than feeling that Atomic's behavior is random or unfair.