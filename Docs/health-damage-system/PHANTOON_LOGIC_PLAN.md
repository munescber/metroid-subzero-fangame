# Boss Implementation Plan — Floating Jellyfish Ghost

I am developing a 2D Metroidvania/platformer in Godot 4.7 using GDScript.

I want to implement a floating jellyfish/ghost-style boss.

**Do not immediately modify or rewrite the boss. First inspect the existing project and produce an implementation plan based on the current code and scene structure.**

The goal is to implement the boss in incremental, testable stages.

---

# Boss Design

The boss is a floating jellyfish ghost that fights the player inside an arena.

The boss should have:

* Health
* Phase-based behavior
* Circular/orbiting movement
* A 6-way projectile burst in Phase 1
* A faster/rotated 6-way burst in Phase 2
* Bouncy floor fireballs
* An optional temporary intangible state
* Visual feedback when damaged
* A death state using the existing health/death architecture where possible

The boss should use the existing project's health/damage architecture rather than introducing a separate health implementation.

---

# Important Existing Architecture

Please inspect the current project before planning implementation.

Pay particular attention to:

* Existing enemy scripts
* Existing boss/enemy scenes
* HealthComponent
* Hitbox
* Hurtbox
* Projectile implementation
* Enemy death behavior
* Player damage handling
* Existing timers
* Existing animation/visual feedback
* Existing movement conventions
* Existing collision layers and masks

Reuse existing systems wherever appropriate.

Do not create duplicate health, damage, hitbox, hurtbox, or projectile systems if the project already has reusable versions.

---

# Boss Behavior

## 1. Circular Movement

The boss should naturally move around the arena.

The intended behavior is:

```text
Slow clockwise orbit
        ↓
Pause briefly
        ↓
Dash to a new position
        ↓
Resume counter-clockwise orbit
        ↓
Pause
        ↓
Dash
        ↓
Resume clockwise orbit
```

The movement should feel deliberate rather than completely random.

### Requirements

The boss should:

* Orbit around a configurable arena center.
* Have a configurable orbit radius.
* Have configurable orbit speed.
* Gradually move around the orbit rather than teleporting.
* Pause briefly at configurable intervals.
* Perform a dash to a new position.
* Reverse orbit direction after the dash.
* Resume normal orbiting.

Please determine whether this should be implemented with:

* A small state machine
* Explicit movement states
* Timers
* Or another approach that fits the existing project.

Prefer the simplest architecture that can support the other boss behaviors later.

Suggested conceptual states:

```text
ORBIT
  ↓
PAUSE
  ↓
DASH
  ↓
ORBIT
```

The orbit direction should alternate between clockwise and counter-clockwise.

---

# 2. Projectile Burst Attack

The boss should have a radial projectile attack.

The projectile should be a separate reusable scene rather than being implemented entirely inside the boss script.

Suggested structure:

```text
Boss
└── Attack logic
       ↓
   Spawn projectile
       ↓
Projectile
├── AnimatedSprite2D
├── CollisionShape2D / Hitbox
└── movement logic
```

The projectile must use the project's existing Hitbox/Hurtbox architecture where appropriate.

The projectile should require a sprite asset.

## IMPORTANT ART TODO

The projectile/fireball sprite does not currently exist.

Do NOT silently substitute a placeholder asset and consider the feature complete.

The implementation plan must explicitly include an art task:

```text
TODO — Create fire projectile sprite
```

The projectile script/scene should be designed so that the missing sprite can be assigned later.

If a temporary placeholder is useful for testing, clearly mark it as temporary.

The final implementation should require the actual fireball sprite before considering the attack complete.

---

# Phase 1 — 6-Way Burst

The first boss phase should have:

* 6 projectiles
* Evenly distributed around 360 degrees
* 60 degrees between each projectile
* Relatively slow projectile speed

Conceptually:

```text
              ↑
          ↖       ↗

        ←    BOSS    →

          ↙       ↘
              ↓
```

The attack should calculate projectile directions mathematically rather than hardcoding six individual directions.

The projectile speed should be configurable.

Suggested configuration:

```text
burst_projectile_count = 6
burst_projectile_speed = configurable
burst_rotation_offset = 0°
```

---

# Phase 2 — 50% Health

When the boss reaches approximately 50% of maximum health, transition to Phase 2.

Phase 2 should modify the existing attack rather than introduce a completely new radial attack.

Changes:

* Still 6 projectiles
* Faster projectile speed
* Rotate the entire burst by approximately 30°
* Optionally reduce the delay between attacks

Conceptually:

```text
Phase 1:

       ↑
   ↖       ↗
 ←    BOSS    →
   ↙       ↘
       ↓


Phase 2:

     ↖   ↑   ↗
       BOSS
     ↙   ↓   ↘

        +30° rotation
```

The exact visual orientation should be determined by the mathematical rotation offset.

Make the following configurable:

```text
phase_1_burst_speed
phase_2_burst_speed

phase_1_burst_rotation
phase_2_burst_rotation

phase_1_attack_interval
phase_2_attack_interval
```

The phase transition should happen once and should not repeatedly toggle when health fluctuates around the threshold.

---

# 3. Bouncy Floor Fireballs

The boss should have a second projectile type/behavior involving fireballs that interact with the floor.

The fireballs should:

* Spawn above or near the arena floor.
* Fall toward the floor.
* Bounce when they hit the floor.
* Continue bouncing for a limited amount of time or number of bounces.
* Damage the player through the existing Hitbox/Hurtbox system.
* Eventually disappear.

The number of fireballs should increase between phases.

## Phase 1

Spawn:

```text
2–3 fireballs
```

## Phase 2

Spawn:

```text
4–5 fireballs
```

Avoid excessive numbers of bouncing projectiles.

The goal is to create temporary arena pressure without making the screen unreadable.

Please determine the cleanest way to detect the floor.

Prefer using the existing physics/collision system rather than hardcoding a Y coordinate unless the arena architecture specifically requires a fixed floor coordinate.

The implementation plan should consider:

* Bounce velocity
* Maximum number of bounces
* Maximum lifetime
* Horizontal velocity
* Damage
* Collision with the arena floor
* Collision with the player
* Cleanup when the projectile expires

---

# Fireball Architecture

Determine whether the radial projectile and bouncing fireball should:

1. Be the same projectile scene with configurable behavior, or
2. Be separate projectile scenes.

Prefer reuse where it remains simple.

Do not create an unnecessarily complex universal projectile framework.

For example, this may be appropriate:

```text
Boss
│
├── RadialFireProjectile.tscn
│
└── BouncingFireball.tscn
```

But if the existing project already has a reusable projectile architecture, use that instead.

---

# 4. Intangible State

I would like to experiment with an additional boss state where the boss temporarily becomes intangible.

This should be implemented as a distinct state rather than scattered boolean checks throughout the boss script.

Conceptually:

```text
NORMAL
   ↓
INTANGIBLE
   ↓
PERFORM ATTACK
   ↓
NORMAL
```

Every approximately 10–15 seconds:

1. Boss becomes translucent.
2. Boss cannot receive damage.
3. Boss performs one attack pattern.
4. Boss returns to its normal physical state.
5. Damage reception is restored.

The exact timing should be configurable.

Suggested values:

```text
intangible_interval = 10–15 seconds
intangible_duration = configurable
```

## Important

Be careful not to confuse:

* Visual transparency
* Damage invulnerability
* Physics collision

These are separate concepts.

The boss should become visually translucent and its Hurtbox should stop accepting damage.

Determine whether the boss should also become physically non-collidable based on the existing gameplay architecture.

Do not automatically disable every collision layer unless necessary.

The intended behavior is primarily:

```text
Intangible
    ↓
Boss cannot receive damage
    ↓
Player attacks pass through / do not damage boss
```

---

# 5. Boss State Machine

Because the boss now has multiple behaviors, evaluate whether a simple state machine would make the implementation clearer.

A possible structure is:

```text
Boss
│
├── ORBIT
│
├── PAUSE
│
├── DASH
│
├── ATTACK_BURST
│
├── BOUNCE_ATTACK
│
├── INTANGIBLE
│
└── DEAD
```

Do not blindly implement all of these as separate scripts.

First inspect the existing project and determine whether a simple enum/state variable is sufficient.

The important requirement is:

**Only one major boss behavior should control the boss at a time.**

Avoid situations where:

```text
orbit code
+
dash code
+
attack code
+
intangible code
```

are all independently modifying the boss's position every frame.

---

# 6. Attack Scheduling

The boss needs a predictable but varied attack cycle.

Do not make every attack happen randomly every frame.

Consider a high-level cycle such as:

```text
Orbit
  ↓
Pause
  ↓
Burst attack
  ↓
Orbit
  ↓
Bouncing fireballs
  ↓
Orbit
  ↓
Dash
  ↓
Repeat
```

The exact sequence can be determined after inspecting the existing project.

The implementation should make it easy to adjust:

* Attack frequency
* Attack duration
* Attack order
* Phase-specific attack behavior
* Intangible timing

Prefer timers/state transitions over large collections of booleans.

---

# 7. Phase System

The boss should have at least two phases.

Suggested structure:

```text
Phase 1
100% → 50% HP
```

and:

```text
Phase 2
50% → 0% HP
```

Phase 2 should modify existing behaviors:

### Movement

Potentially:

* Faster orbit
* Shorter pauses
* Faster dashes

### Radial attack

* Same 6 projectiles
* Faster
* 30° rotation

### Bouncing fireballs

* More fireballs
* Potentially faster bouncing

Do not implement completely new attacks for Phase 2 yet.

The goal is to make the boss feel more dangerous through modifications to existing patterns.

---

# 8. Health Integration

Use the existing HealthComponent.

Do NOT create a separate boss health system.

The boss should:

```text
HealthComponent
    ↓
damaged signal
    ↓
Boss hurt reaction
```

and:

```text
HealthComponent
    ↓
died signal
    ↓
Boss death behavior
```

The boss's Phase 2 transition should be based on its current health.

For example:

```text
if current_health <= max_health * 0.5:
    enter_phase_2()
```

Make sure Phase 2 only activates once.

---

# 9. Damage / Intangibility Interaction

When the boss is intangible:

```text
Player projectile
      ↓
Boss Hurtbox
      ↓
Damage rejected
```

Do not destroy or permanently remove the Hurtbox.

Prefer temporarily disabling its ability to receive damage.

Determine whether this should be handled by:

* A Hurtbox enabled/disabled property
* A boss state check
* Collision layer changes
* Another mechanism already used by the project

Choose the approach that best fits the existing Hitbox/Hurtbox implementation.

---

# 10. Visual Feedback

The boss should have clear visual states.

At minimum:

### Normal

Normal sprite.

### Damaged

Use the existing damage feedback system if one exists.

### Intangible

Boss becomes translucent.

### Phase 2

Consider a subtle visual change to indicate the phase transition, but do not implement elaborate effects yet unless the project already supports them.

The visual state should not be responsible for the actual gameplay state.

For example:

```text
Boss state = INTANGIBLE
        ↓
visual controller makes boss translucent
        +
Hurtbox stops accepting damage
```

not:

```text
sprite.modulate.a = 0.5
```

being the only indication that the boss is invulnerable.

---

# 11. Arena Considerations

Inspect how the current test arena is structured.

The orbit movement requires a defined center and radius.

Prefer configurable boss properties such as:

```text
arena_center
orbit_radius
orbit_speed
dash_speed
dash_distance
```

Do not hardcode these values into the movement logic if they can reasonably be exposed as properties.

Determine whether the arena center should be:

* A Marker2D
* A Node2D
* A position exported in the boss
* Another existing arena reference

Prefer a Marker2D or similar scene reference if that fits the current level architecture.

---

# 12. Art / Asset TODOs

The following art assets need to be tracked separately from programming.

## Required

### Fire projectile sprite

Create the sprite used by:

* 6-way burst projectiles
* Bouncing floor fireballs

Determine whether one sprite can serve both projectile types.

The projectile scene/script should reference the expected sprite location, but the implementation should clearly identify the asset as missing until it is created.

### Optional future assets

Consider later:

* Boss phase transition effect
* Intangible visual effect
* Boss attack telegraph
* Fireball trail
* Fireball explosion/death effect
* Boss death animation

Do not block the core programming implementation on optional effects.

---

# 13. Implementation Order

Please organize the actual implementation into these incremental milestones.

## Milestone 1 — Inspect and document current architecture

Before changing anything:

* Inspect existing boss/enemy scene.
* Inspect existing health system.
* Inspect existing Hitbox/Hurtbox.
* Inspect projectile system.
* Inspect collision layers.
* Inspect player damage system.
* Identify reusable code.
* Identify anything that needs refactoring.

Do not modify unrelated systems.

---

## Milestone 2 — Boss health and phases

Implement/verify:

* Boss HealthComponent
* Phase 1
* Phase 2
* 50% transition
* Phase-specific configuration

Test:

```text
Boss starts Phase 1
Boss reaches 50% HP
Boss transitions once to Phase 2
Boss remains Phase 2
```

---

## Milestone 3 — Circular movement

Implement:

```text
ORBIT
→ PAUSE
→ DASH
→ reverse direction
→ ORBIT
```

Test movement independently from attacks.

The boss should be able to orbit the arena without firing anything.

---

## Milestone 4 — Radial projectile

Create the projectile scene and implementation.

**Remember: the fire projectile sprite is a required missing art asset.**

Implement:

```text
6 projectiles
60° spacing
Phase 1 speed
```

Then Phase 2:

```text
6 projectiles
30° rotation
faster speed
```

Test projectile damage against the Player.

---

## Milestone 5 — Bouncing fireballs

Implement:

```text
Phase 1 → 2–3
Phase 2 → 4–5
```

Add:

* Gravity/falling
* Floor collision
* Bounce
* Lifetime/bounce limit
* Player damage
* Cleanup

Test independently.

---

## Milestone 6 — Attack scheduling

Combine movement and attacks.

Create a controlled attack cycle.

Ensure movement and attacks do not fight over the boss's position/state.

---

## Milestone 7 — Intangible state

Implement:

```text
NORMAL
 ↓
INTANGIBLE
 ↓
ATTACK
 ↓
NORMAL
```

During INTANGIBLE:

* Boss is translucent.
* Boss cannot take damage.
* Boss performs one attack.
* Boss becomes vulnerable again afterward.

Test that player attacks cannot damage the boss during this state.

---

## Milestone 8 — Final integration

Combine:

* Health
* Phase transitions
* Orbit movement
* Dash
* Radial attack
* Bouncing fireballs
* Intangible state
* Damage feedback
* Death

Then test the entire encounter.

---

# 14. Testing Checklist

Create tests for each behavior independently.

### Health

* [ ] Boss starts with configured max health.
* [ ] Boss takes damage through Hurtbox.
* [ ] Boss dies at 0 HP.
* [ ] Phase 2 triggers at 50%.
* [ ] Phase 2 does not trigger repeatedly.

### Movement

* [ ] Boss orbits clockwise.
* [ ] Boss pauses.
* [ ] Boss dashes.
* [ ] Boss reverses orbit direction.
* [ ] Boss resumes orbit.
* [ ] Boss stays within the intended arena.

### Radial Attack

* [ ] Six projectiles spawn.
* [ ] Projectiles are evenly spaced.
* [ ] Phase 1 uses slower speed.
* [ ] Phase 2 uses faster speed.
* [ ] Phase 2 uses approximately 30° rotation.
* [ ] Projectiles damage Player correctly.
* [ ] Projectiles clean themselves up.

### Bouncing Fireballs

* [ ] Phase 1 spawns 2–3.
* [ ] Phase 2 spawns 4–5.
* [ ] Fireballs fall toward the floor.
* [ ] Fireballs bounce correctly.
* [ ] Fireballs damage Player.
* [ ] Fireballs eventually disappear.
* [ ] Fireballs do not remain indefinitely.

### Intangible State

* [ ] Boss becomes intangible at the configured interval.
* [ ] Boss becomes translucent.
* [ ] Boss cannot receive damage.
* [ ] Boss can still perform its intended attack.
* [ ] Boss becomes vulnerable again.
* [ ] Visual state returns to normal.

### Phase 2

* [ ] Movement can become more aggressive.
* [ ] Radial attack is faster.
* [ ] Radial attack has 30° rotation.
* [ ] More bouncing fireballs spawn.

### Art

* [ ] Fire projectile sprite has been created.
* [ ] Projectile scene references the final sprite.
* [ ] No temporary placeholder remains in the final implementation.

---

# 15. Important Constraints

Do not:

* Rewrite unrelated Player code.
* Rewrite the existing health system without first explaining why.
* Create duplicate Hitbox/Hurtbox systems.
* Create an unnecessarily complicated generic AI framework.
* Hardcode attack positions when they can be calculated.
* Make projectile spawning dependent on individual hardcoded projectile nodes.
* Make visual transparency responsible for invulnerability.
* Let multiple independent systems modify boss movement simultaneously.
* Implement all attacks at once without testing each milestone.

Prefer:

```text
Small state machine
+
Existing HealthComponent
+
Existing Hitbox/Hurtbox
+
Reusable projectile scenes
+
Configurable exported properties
+
Incremental testing
```

---

# Expected Output Before Implementation

Before modifying the project, provide:

1. **Current architecture assessment**
2. **Recommended boss scene tree**
3. **Recommended state structure**
4. **Files/scenes to create**
5. **Files/scripts to modify**
6. **Data/configuration to expose**
7. **Collision/layer requirements**
8. **Projectile architecture**
9. **Phase architecture**
10. **Intangible-state architecture**
11. **Art assets that must be created**
12. **Step-by-step implementation order**
13. **Testing strategy**
14. **Potential risks or conflicts with the existing project**

Do not begin implementation until this plan has been produced and reviewed.
