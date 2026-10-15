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
- **Current Version:** 1.2.0
- **Status:** Core mechanics stable, jump physics retuned, larger sprite in progress
- **Last Updated:** 2026-10-14
- **Changes in 1.2.0:**
  - Dedicated `jump_gravity` (800), independent of the project's `default_gravity`
  - Soft apex: reduced gravity (x0.65) while `abs(velocity.y)` is under 60 px/s
  - `max_fall_speed` cap (400 px/s) on normal airborne falling
  - New `fall` animation, played when descending
  - 16x16 player archived to `Scenes/Player/Archive/player_v1.tscn` (git tag `player-v1-16px`)
  - See `Docs/player_logic/PLAYER_LOGIC.md`
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
