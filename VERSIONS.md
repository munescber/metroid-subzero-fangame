# Component Versions

Tracks the version and status of implemented game components.

## Enemies

### Atomic
- **Current Version:** 1.2
- **Status:** Electric field mechanics implemented and tuned
- **Last Updated:** 2026-09-30
- **Changes in 1.2:**
  - Electric field collision detection via direct physics query (handles pre-existing overlaps)
  - Instant area_entered signal path for immediate "spike" damage on field touch
  - Knockback visual feedback on damage via knockback lock timer (0.2s)
  - Field collision radius scaled to match visible sprite (no invisible oversizing)
  - Animation playback on electric field visual
  - Phosphorescent shader colors (white, yellow, green)
  - Reduced log spam via throttled damage ticks (0.5s intervals)
  - Debug-only radius outline when debug_enabled = true
  - Independent electric field schedule (runs every 10s, regardless of enable_attacks)

### Ghost Covern
- **Current Version:** 1.0
- **Status:** Core implementation stable
- **Last Updated:** TBD

### Phantoon
- **Current Version:** 1.0
- **Status:** Core implementation stable
- **Last Updated:** TBD

### Rhinobug
- **Current Version:** 1.0
- **Status:** Core implementation stable
- **Last Updated:** TBD

## Player

### Player (player_rundas)
- **Current Version:** 1.1
- **Status:** Core mechanics stable, knockback feedback improved
- **Last Updated:** 2026-09-30
- **Changes in 1.1:**
  - Added knockback lock timer (0.2s) to preserve knockback visual feedback
  - Prevents player input from immediately canceling knockback velocity

## Systems

### Health/Damage System
- **Current Version:** 1.0
- **Status:** Stable
- **Last Updated:** TBD

### Hitbox/Hurtbox System
- **Current Version:** 1.0
- **Status:** Stable
- **Last Updated:** TBD
