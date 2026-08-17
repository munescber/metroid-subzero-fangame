Possible Implementations / TODO
================================

Subtitle: Potential tooling and optimizations for Health & Damage system integration
----------------------------------------------------------------------------------

This document collects ideas and possible features to consider later. They're intentionally non-blocking for the current PR and meant for planning, optimization, or new tooling.

Short list of possibilities
--------------------------

- Hitbox / Hurtbox Editor
  - In-editor visualizer for hitboxes and hurtboxes with timeline support for attack windows.

- Hitbox/Projectile Pooling
  - Object pool for frequently spawned `Hitbox` and projectile instances to reduce GC and allocation cost.

- Damage Resolver / Combat Service
  - Central service to apply damage rules, handle resistances, armor, critical hits, and log combat events.

- Data-driven damage configs
  - Externalize damage, knockback, and resistances into JSON/TOML/CSV so designers can tweak values without changing code.

- Damage Types & Status Effects
  - Add typed damage (physical, fire, ice, etc.) and a status-effect system (burn, freeze, stun) with duration and stacking rules.

- Per-region Hurtboxes
  - Support multiple named hurtboxes per entity (head, torso) with per-region multipliers or effects.

- Invulnerability/Shield Utilities
  - Reusable `Invulnerability` helper, shield components, timed immunities, and visual helpers.

- Networked/Authoritative Damage
  - Server-side authoritative `HealthComponent` with validation and replay-safe damage application.

- Automated Tests & Scene Harnesses
  - Small scene-based unit tests for hitbox→hurtbox interactions, health boundaries, and invulnerability timing.

- UI / HUD Integration Tools
  - Reusable health bar components, boss health bar manager, and data bindings to `HealthComponent` signals.

- Editor Shortcuts & Templates
  - Scene templates for enemy with preconfigured `Hurtbox`/`Hitbox`/`HealthComponent` and editor script to add them quickly.

- Profiling & Metrics
  - Counters for hits/sec, allocations from projectiles/hitboxes, and a perf profile for combat-heavy scenes.

- ECS or Component Refactor (optional)
  - If the project grows, consider an ECS-style system for high-performance, data-oriented combat logic.

Notes
-----
- Each item should be evaluated for ROI: complexity vs benefit.
- Start with lightweight, high-impact items (pooling, editor visualizer, data-driven configs) before investing in heavy refactors (ECS, networking).

