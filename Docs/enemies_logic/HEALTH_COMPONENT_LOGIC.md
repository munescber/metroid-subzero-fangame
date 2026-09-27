HealthComponent Logic
=====================

Overview
--------
`Scripts/Common/health_component.gd` is a reusable, presentation-agnostic health
tracker attached as a child `Node` to any damageable entity (player, enemies,
bosses, some projectiles). It only tracks numeric health state and emits
signals; visual feedback (flash, fade, knockback) stays in the owning entity's
script.

State
-----
- `max_health: int` (exported, default `1`)
- `current_health: int` (runtime only, default `0`)
- `debug_enabled: bool` (exported) — enables `print_debug` tracing

Signals
-------
- `damaged(amount, new_health)` — emitted every time damage is applied
- `died()` — emitted once, the first time `current_health` reaches `0`

Core methods
------------
- `take_damage(amount, source = null)` — subtracts `amount` from `current_health`,
  clamped at `0`. Ignores non-positive `amount`. Ignores all damage once
  `current_health <= 0` (entity is already dead — repeated hits are no-ops).
- `heal(amount)` — adds `amount`, clamped to `max_health`. No-op if already dead.
- `set_max_health(new_max)` — sets `max_health` (minimum `1`) and **clamps**
  `current_health` into the new `[0, max_health]` range. It does **not** reset
  `current_health` to full.

Death rule
----------
Death is intentionally strict and deterministic:
- Triggered when `current_health <= 0`.
- Damage on an already-dead entity is ignored (no double-death, no negative health).

Initialization order pitfall (important)
-----------------------------------------
`HealthComponent._ready()` runs:

```gdscript
func _ready() -> void:
    current_health = max_health
```

Godot readies **children before parents**. If `HealthComponent` is placed as a
node directly inside an enemy's `.tscn` (e.g. Atomic, Phantoon, Ghost Covern),
its `_ready()` fires *before* the owning enemy's own `_ready()`. At that point
`max_health` is still whatever the exported default on the `HealthComponent`
node is (often `1`), so `current_health` gets initialized to that default —
not the enemy's intended `max_health`.

Calling `health_comp.set_max_health(enemy_max_health)` afterward is **not**
enough to fix this, because `set_max_health()` only clamps the existing
`current_health` into the new range instead of resetting it to full. This
previously caused Atomic to spawn with effectively 1 HP instead of 10, dying
to a single hit.

**Correct pattern for a scene-embedded `HealthComponent`:** in the owning
entity's `_ready()`, set both fields directly instead of calling
`set_max_health()`:

```gdscript
health_comp.max_health = max_health
health_comp.current_health = max_health
```

This is what `phantoon.gd` and `atomic.gd` do.

**Runtime-instantiated `HealthComponent` (alternative pattern):** `rhinobug.gd`
and `player_rundas.gd` instead create the component in code and configure it
*before* adding it to the tree, so `_ready()` naturally sees the correct value:

```gdscript
health_comp = HealthComponent.new()
health_comp.set_max_health(max_health)
add_child(health_comp)  # _ready() runs here, current_health = max_health
```

Either pattern works. The bug only appears when a `HealthComponent` is
pre-placed as a child node in the `.tscn` file *and* the owning script relies
on `set_max_health()` alone after the fact.

Usage checklist for new enemies
--------------------------------
1. Add `HealthComponent` as a child node (scene) or instantiate it at runtime.
2. If scene-embedded: in `_ready()`, set `health_comp.max_health` and
   `health_comp.current_health` directly (do not rely on `set_max_health()`).
3. If runtime-instantiated: call `set_max_health()` before `add_child()`.
4. Connect `damaged` and `died` signals to entity-specific handlers for visual
   feedback (damage flash, death fade, knockback) — see
   `_on_health_damaged()` / `_on_health_died()` in `phantoon.gd`, `rhinobug.gd`,
   and `atomic.gd` for the established flash/fade convention.
