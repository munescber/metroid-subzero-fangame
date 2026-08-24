# Ghost Enemy — Implementation Plan

## 1. Objective

Implement a reusable ghost enemy for the Godot 2D platformer.

The ghost should:

* Float around the room while idle.
* Ignore the player while they remain outside its detection radius.
* Begin haunting/following the player when they enter a configurable detection radius.
* Stop haunting only after the player moves sufficiently far away.
* Maintain a preferred distance from the player instead of constantly moving directly into them.
* Periodically become intangible and therefore immune to damage.
* Visually communicate intangibility through the existing/project's shader approach.
* Integrate with the existing health, Hitbox, and Hurtbox systems.
* Keep movement and state logic modular and configurable through exported properties.

The implementation should prioritize simple, readable code and avoid introducing unnecessary systems that are not required for this enemy.

---

## 2. Inspect the Existing Enemy Architecture First

Before modifying the ghost script:

* Inspect the existing enemy base/script structure.
* Inspect how enemies currently move and process physics.
* Inspect the existing player reference/access pattern.
* Inspect the existing Hitbox/Hurtbox implementation.
* Inspect how `take_damage()` is currently implemented.
* Inspect how enemy animations are controlled.
* Inspect whether there is already a reusable timer/state-machine pattern.
* Inspect any existing shader/material setup that could be reused for an intangible visual effect.

Do not duplicate functionality that already exists in the project.

The new ghost should follow the project's existing conventions whenever possible.

---

## 3. Create a Simple State Machine

Use an enum to represent the ghost's high-level behavior.

Recommended states:

```gdscript
enum State {
    WANDERING,
    HAUNTING,
    INTANGIBLE
}
```

Add:

```gdscript
var current_state := State.WANDERING
```

The state machine should determine which movement/behavior logic is active.

### State responsibilities

#### `WANDERING`

* Ghost floats around its assigned room/area.
* Ghost does not intentionally follow the player.
* Detection remains active.
* Entering the detection radius transitions to `HAUNTING`.

#### `HAUNTING`

* Ghost follows/haunts the player.
* Ghost should use smooth floating movement.
* Ghost should attempt to maintain a preferred distance rather than continuously overlap the player.
* If the player moves beyond the disengage radius, return to `WANDERING`.
* Intangibility can be triggered from this state.

#### `INTANGIBLE`

* Ghost becomes immune to damage.
* Ghost receives the intangible visual effect.
* Ghost continues its haunting behavior while intangible unless there is a strong reason to suspend it.
* After the intangible duration, return to `HAUNTING`.

Avoid creating unnecessary additional states unless the existing architecture requires them.

---

## 4. Add Configurable Ghost Properties

Expose the main tuning values in the Inspector.

Suggested starting values:

```gdscript
@export_category("Detection")

@export var detection_radius := 160.0
@export var disengage_radius := 220.0

@export_category("Movement")

@export var wander_speed := 25.0
@export var haunt_speed := 55.0
@export var acceleration := 100.0
@export var preferred_distance := 40.0

@export_category("Intangibility")

@export var intangible_duration := 1.0
@export var intangible_cooldown := 3.0
```

Use appropriate types for the existing project conventions.

Do not hard-code these values throughout the implementation.

The purpose is to make enemy balancing possible directly from the Godot Inspector.

---

## 5. Implement Player Detection

Use an `Area2D` with a `CircleShape2D` for detection.

Recommended scene structure:

```text
Ghost
├── AnimatedSprite2D
├── CollisionShape2D
├── DetectionArea
│   └── CollisionShape2D
├── Hurtbox
└── ContactDamage
```

The `DetectionArea` should use the configured `detection_radius`.

Connect the appropriate `body_entered` / `area_entered` signal according to the project's existing player detection architecture.

When the player enters the detection area:

1. Confirm that the detected object is actually the player.
2. Store a reference to the player.
3. Transition from `WANDERING` to `HAUNTING`.
4. Optionally trigger a short detection/reaction animation if the existing animation system supports it.

Do not repeatedly search the scene tree for the player every frame if a reference can be stored.

---

## 6. Implement Separate Detection and Disengage Distances

Do not use the same distance for entering and leaving the haunting state.

Use:

```text
detection_radius = 160
disengage_radius = 220
```

Behavior:

```text
Player enters 160 px
    ↓
Ghost starts haunting

Player remains between 160–220 px
    ↓
Ghost continues haunting

Player moves beyond 220 px
    ↓
Ghost stops haunting
    ↓
Return to wandering
```

This prevents the ghost from rapidly switching between `WANDERING` and `HAUNTING` when the player is near the detection boundary.

The disengage check can use the player's actual distance from the ghost rather than another physics area.

---

## 7. Implement Wandering Movement

While in `WANDERING`:

* Select a target point within a configurable wandering area.
* Move toward the target smoothly.
* When the target is reached, wait briefly and choose another target.
* Avoid selecting a completely new random target every frame.
* Keep the movement slow.

The ghost should feel like it is naturally floating around the room.

If the project does not already have a room/area boundary system, keep the initial implementation simple and use a configurable wandering radius or points rather than introducing a complete navigation system.

Suggested conceptual behavior:

```text
Choose target
    ↓
Float toward target
    ↓
Reach target
    ↓
Short pause
    ↓
Choose another target
```

Avoid adding complex pathfinding unless existing level geometry makes it necessary.

---

## 8. Implement Smooth Floating Movement

Do not instantly assign maximum velocity toward the target.

Use acceleration/deceleration or the project's existing movement helper.

The goal is:

```text
slowly accelerate
      ↓
smooth movement
      ↓
slowly decelerate
```

This should apply to both wandering and haunting where appropriate.

The ghost should visually feel different from a normal walking enemy.

If the sprite supports it, consider a subtle vertical bobbing motion for visual presentation, but keep visual bobbing separate from the actual collision/movement position whenever possible.

---

## 9. Implement Haunting Movement

When `current_state == State.HAUNTING`:

1. Validate that the player reference is still valid.
2. Calculate the direction from the ghost to the player.
3. Calculate the current distance to the player.
4. Compare that distance with `preferred_distance`.

Behavior:

```text
Distance > preferred_distance
    → move toward player

Distance ≈ preferred_distance
    → slow down / hover

Distance < preferred_distance
    → move away slightly
```

This prevents the ghost from constantly trying to occupy the player's exact position.

Use smooth velocity changes rather than instantly setting velocity.

The ghost should feel like it is **haunting** the player, not simply functioning as a homing missile.

---

## 10. Add Optional Hover/Orbit Feel

If the implementation remains simple enough, add a small lateral or circular component to the haunting movement.

For example, instead of:

```text
Ghost → Player
```

allow:

```text
       Ghost
         ↘
          ↘
Player ←───
```

The ghost can slowly move around the player's position while maintaining its preferred distance.

This should be subtle.

Do not implement a complex orbit system unless testing shows that the basic preferred-distance behavior feels too static.

---

## 11. Implement Intangibility as a Gameplay State

Add:

```gdscript
var is_intangible := false
```

or derive it from the state if appropriate.

When intangibility begins:

1. Set the gameplay state to intangible.
2. Set the intangible flag.
3. Disable/ignore damage received by the ghost.
4. Disable the ghost's offensive contact damage if the design requires the ghost to become completely intangible.
5. Start the intangible duration.
6. Activate the visual effect.

When the duration expires:

1. Set `is_intangible` back to `false`.
2. Re-enable damage reception.
3. Re-enable offensive collision if it was disabled.
4. Disable the visual effect.
5. Return to `HAUNTING`.

Keep the gameplay logic independent from the shader.

---

## 12. Integrate With the Existing Hurtbox

The ghost should use the existing Hurtbox/damage architecture rather than creating a second damage system.

When the ghost is intangible, incoming damage should be ignored.

Prefer integrating this into the existing damage flow, for example:

```gdscript
if is_intangible:
    return
```

The exact implementation should follow the project's current Hurtbox/`take_damage()` architecture.

Do not modify the player's damage system unless absolutely necessary.

Do not introduce a second health system specifically for the ghost.

---

## 13. Integrate With the Existing Contact Damage

The ghost's offensive Hitbox/ContactDamage should remain compatible with the existing player Hurtbox system.

Decide based on the existing architecture whether intangibility should:

* Only make the ghost immune to incoming attacks, or
* Make the ghost completely intangible, including disabling its contact damage.

Recommended behavior:

```text
Normal:
Ghost can damage player.
Ghost can receive damage.

Intangible:
Ghost cannot receive damage.
Ghost does not damage player through contact.
```

This makes the state conceptually consistent and prevents confusing situations where the ghost appears intangible but can still hurt the player.

---

## 14. Implement Intangibility Timing

Do not make intangibility happen every frame or purely randomly.

Use a controlled cooldown/timer.

Recommended initial behavior:

```text
Haunting
    ↓
Cooldown expires
    ↓
Become intangible
    ↓
Remain intangible for ~1 second
    ↓
Become vulnerable
    ↓
Cooldown starts again
```

The cooldown should be configurable.

If the existing project has a reusable Timer-based pattern, use it.

Otherwise, a small internal timer variable is acceptable.

The implementation should avoid creating multiple timers unnecessarily.

---

## 15. Add Intangibility Visual Feedback

Use the project's shader/material system if available.

The visual state should clearly communicate:

```text
Normal ghost
    ↓
Intangible
    ↓
Ghost becomes translucent/distorted/flickering
    ↓
Normal appearance
```

Possible shader effects:

* Increased transparency.
* Slight distortion.
* Flickering.
* Ghostly displacement.
* Reduced opacity.
* Subtle glow.

The shader must remain a **visual representation** of the gameplay state.

Do not put damage immunity logic inside the shader.

A useful architecture is:

```text
Ghost script
    ↓
set intangible visual parameter
    ↓
Shader
    ↓
visual effect only
```

---

## 16. Handle State Transitions Carefully

Implement explicit transition functions where useful:

```gdscript
enter_wandering()
enter_haunting()
enter_intangible()
exit_intangible()
```

These functions should handle side effects such as:

* Starting/stopping animations.
* Enabling/disabling Hitbox/Hurtbox behavior.
* Updating the shader.
* Resetting timers.
* Choosing a new wandering target.

Avoid scattering state-transition side effects throughout `_physics_process()`.

---

## 17. Handle Player Reference Safely

The ghost should gracefully handle situations where:

* The player leaves the scene.
* The player is freed.
* The ghost is instantiated before the player exists.
* The player changes rooms.

If the player reference becomes invalid:

```text
HAUNTING
    ↓
Player unavailable
    ↓
Clear player reference
    ↓
Return to WANDERING
```

Do not generate errors every frame if the player is temporarily unavailable.

Follow the project's existing player-reference conventions.

---

## 18. Keep Room Boundaries in Mind

The ghost is intended to float around a room.

Do not allow the wandering system to blindly choose points across the entire level.

The implementation should leave room for a configurable boundary later.

Possible future-friendly approaches:

```text
Ghost
  └── WanderArea
```

or exported bounds/points.

For the first implementation, use the simplest approach compatible with the existing level architecture.

Do not implement full navigation/pathfinding unless testing proves it is necessary.

---

## 19. Animation Requirements

Use the existing `AnimatedSprite2D` conventions.

At minimum, consider:

```text
idle / float
haunting
intangible
```

If separate animations do not exist yet, the implementation should not block gameplay logic on them.

The state machine should be independent from animation names.

For example:

```text
State.HAUNTING
    ↓
play haunting animation if available
```

rather than making the state machine itself dependent on a specific animation existing.

---

## 20. Testing Checklist

After implementation, test each behavior independently.

### Wandering

* [ ] Ghost starts in `WANDERING`.
* [ ] Ghost chooses a target.
* [ ] Ghost moves smoothly toward the target.
* [ ] Ghost does not jitter or constantly change direction.
* [ ] Ghost remains within its intended wandering area.

### Detection

* [ ] Player outside detection radius does not trigger the ghost.
* [ ] Player entering the radius triggers haunting.
* [ ] Detection only responds to the player.
* [ ] Ghost does not repeatedly re-trigger detection while already haunting.

### Haunting

* [ ] Ghost follows the player smoothly.
* [ ] Ghost does not instantly snap onto the player.
* [ ] Ghost maintains its preferred distance.
* [ ] Ghost can move around the player naturally.
* [ ] Player escaping beyond the disengage radius returns the ghost to wandering.

### Intangibility

* [ ] Ghost becomes intangible at the configured interval.
* [ ] Ghost cannot receive damage while intangible.
* [ ] Ghost becomes vulnerable again afterward.
* [ ] Intangibility does not permanently disable the Hurtbox.
* [ ] Intangibility does not break the haunting state.
* [ ] Contact damage behaves consistently with the chosen design.

### Visuals

* [ ] Intangible shader activates correctly.
* [ ] Shader deactivates correctly.
* [ ] No material/resource is unintentionally shared with other enemies.
* [ ] Visual state always matches gameplay state.

### Edge cases

* [ ] Player dies while being haunted.
* [ ] Player leaves the room.
* [ ] Ghost is destroyed while intangible.
* [ ] Ghost is spawned without a valid player reference.
* [ ] Multiple ghosts can exist simultaneously without interfering with each other.
* [ ] Multiple ghosts do not share mutable state accidentally.

---

## 21. Recommended Initial Tuning

Start with these values and adjust through playtesting:

```text
Detection radius:       160 px
Disengage radius:       220 px
Wander speed:            25 px/s
Haunt speed:             55 px/s
Acceleration:           100 px/s²
Preferred distance:      40 px
Intangible duration:      1.0 s
Intangible cooldown:     3–4 s
```

These are starting points, not requirements.

All gameplay values should remain configurable through the Inspector.

---

## 22. Implementation Constraints

While implementing:

* Follow the existing project's coding conventions.
* Reuse existing Hitbox/Hurtbox and health systems.
* Do not introduce a new global enemy framework just for this ghost.
* Do not modify unrelated enemies unless required for shared functionality.
* Keep the state machine simple.
* Keep movement logic separate from combat logic.
* Keep shader/visual logic separate from gameplay logic.
* Prefer exported properties over magic numbers.
* Avoid unnecessary scene-tree searches every frame.
* Avoid unnecessary timers/nodes when existing project patterns can be reused.
* Preserve existing functionality of the enemy and player systems.

---

## 23. Suggested Implementation Order

Implement in this order so each stage can be tested independently:

1. Inspect existing enemy/combat architecture.
2. Set up the ghost scene structure.
3. Add exported movement/detection/intangibility parameters.
4. Add the state enum and state-management logic.
5. Implement wandering.
6. Implement player detection.
7. Implement haunting movement.
8. Add preferred-distance behavior.
9. Add disengage behavior.
10. Integrate the existing Hurtbox/damage system.
11. Implement intangibility timing.
12. Disable damage reception while intangible.
13. Disable contact damage while intangible if appropriate.
14. Add shader-based intangible visuals.
15. Connect animations to the states.
16. Test multiple ghosts simultaneously.
17. Tune movement, detection, haunting, and intangibility values through playtesting.
18. Refactor only after the complete behavior is working.

## Definition of Done

The implementation is complete when the ghost behaves as follows:

```text
             PLAYER FAR AWAY

        👻
      wandering
         ~~~


             PLAYER APPROACHES

        👻   →   🧍
             detection
                 ↓

        👻  ~~~ 🧍
            haunting


        👻  ~ 🧍
          intangible
        (shader active)
        (cannot be hurt)
        (cannot damage)


             PLAYER ESCAPES

        👻              🧍
        wandering again
```

The final result should feel like a **ghost that occupies and patrols a room, notices the player when they get too close, actively haunts them for a while, and periodically phases out of reality**, rather than simply behaving like a flying enemy that permanently homes in on the player.
