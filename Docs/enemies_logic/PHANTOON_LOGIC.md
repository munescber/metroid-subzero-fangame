# Phantoon Boss Logic

Script: `Scripts/Enemies/phantoon.gd`
Scene: `Scenes/Enemies/phantoon.tscn`

Phantoon is an orbiting boss that alternates between circling an arena center point, dashing to a new position, and firing one of two attacks. It has two health-based phases and a periodic intangibility window, during which it casts a Flame Wall.

The eye is the weak zone: the `Hurtbox` is a deliberately small 5px circle, so the player has to aim at it. `ContactDamage` still covers the whole body.

## States (`BossState` enum)

| State | Purpose |
|---|---|
| `ORBIT` | Circles `arena_center` at `orbit_radius`/`orbit_speed`. Default/resting state. |
| `PAUSE` | Stops orbiting briefly before dashing (or before attacking, if dash is disabled). The dash target is shown by a marker. |
| `DASH` | Moves at constant `dash_speed` to the point on the orbit circle directly opposite the boss. |
| `ATTACK_WINDUP` | Holds still and glows for `attack_telegraph_duration`, then spawns the pending attack. |
| `ATTACK_BURST` | Radial burst attack is in-flight; boss holds position. |
| `ATTACK_BOUNCE` | Bouncing fireball attack is in-flight; boss holds position. |
| `DEAD` | Boss is fading out and about to `queue_free()`. |

Intangibility is **not a state**. It is an overlay flag (`is_intangible`) that only ever happens during `ORBIT`. The Flame Wall is cast from that overlay and is **not** a `BossState` or an `AttackType`. See [Intangibility](#intangibility) and [Flame Wall](#flame-wall).

## State machine flow

```mermaid
stateDiagram-v2
    [*] --> ORBIT
    ORBIT --> PAUSE: attack_timer >= orbit_duration
    PAUSE --> DASH: enable_dash == true
    PAUSE --> ATTACK_WINDUP: enable_dash == false (attack from current spot)
    DASH --> ATTACK_WINDUP: dash complete
    ATTACK_WINDUP --> ATTACK_BURST: after attack_telegraph_duration (burst is next in sequence)
    ATTACK_WINDUP --> ATTACK_BOUNCE: after attack_telegraph_duration (bounce is next in sequence)
    ATTACK_BURST --> ORBIT: after 1.0s
    ATTACK_BOUNCE --> ORBIT: after 2.0s
    ORBIT --> DEAD: health <= 0
    PAUSE --> DEAD: health <= 0
    DASH --> DEAD: health <= 0
    ATTACK_WINDUP --> DEAD: health <= 0
    ATTACK_BURST --> DEAD: health <= 0
    ATTACK_BOUNCE --> DEAD: health <= 0
    DEAD --> [*]
```

Notes:
- Intangibility is an overlay on `ORBIT` and does not appear in the diagram. It never interrupts a dash or an attack.
- Death (`take_damage` → `HealthComponent` → `died` signal) can happen from any state and immediately forces `DEAD`, disabling all `CollisionShape2D`/`CollisionPolygon2D`/`Area2D` children.
- On spawn, `arena_center` is set so the boss's starting position is already on the orbit ring (orbit angle 0). The first orbit frame no longer teleports it.

## Transition timings (defaults)

| Transition | Duration/condition |
|---|---|
| `ORBIT` → `PAUSE` | `orbit_duration` (3.0s, phase 1) |
| `PAUSE` → `DASH` (or directly to attack if `enable_dash = false`) | `pause_duration` (1.0s, phase 1) |
| `DASH` → `ATTACK_WINDUP` | arrival at the target at `dash_speed` (200 px/s); `dash_duration` (0.5s) is a safety cap |
| `ATTACK_WINDUP` → attack state | `attack_telegraph_duration` (0.4s) |
| `ATTACK_BURST` → `ORBIT` | fixed 1.0s |
| `ATTACK_BOUNCE` → `ORBIT` | fixed 2.0s |

In Phase 2 (`enter_phase_2()`), `orbit_speed` is multiplied by 1.5, `pause_duration` by 0.75, `orbit_duration` by 0.8 and `intangible_interval` by 0.75. The boss orbits faster, pauses for less time, starts its attack cycle sooner and phases out more often. `intangible_duration` is unaffected by phase.

## Intangibility

A defensive behavior: the boss phases out and keeps orbiting. It can't be damaged and doesn't use its normal attacks (burst, bounce) while phased. The one exception is the [Flame Wall](#flame-wall), cast during the window.

- **Scheduling:** `intangible_timer` only counts tangible time. Once it reaches `intangible_interval` (15s) **and** the boss is in `ORBIT`, it starts. If the boss is mid-pause, dash or attack, it waits, so it never cuts an attack off.
- **Warning:** the sprite flickers for `intangible_warning_duration` (0.5s) before phasing out.
- **Attack hold:** while flickering or intangible, the `ORBIT` → `PAUSE` timer is frozen. The boss only orbits (and casts the Flame Wall). The attack timer keeps the value it had, so after the window ends the normal cycle continues from there.
- **Phased out (`is_intangible`):** lasts `intangible_duration` (3s). `_set_phased(true)` (deferred) does the following:
  - `Hurtbox.monitorable` and `monitoring` are switched off. `monitorable` is the important one: projectiles find the hurtbox by overlapping it, so bullets and missiles pass straight through instead of being consumed. Missile explosion queries skip it too.
  - `ContactDamage.monitoring` and `monitorable` are switched off, so the player takes no contact damage and passes through.
  - `collision_layer` is set to 0.
  - The sprite alpha becomes `intangible_fade_amount` (0.5).
  - If `enable_flame_wall` is on, `_wall_waves_left` and `_wall_timer` are set up (see [Flame Wall](#flame-wall)).
- **Exit:** `_set_phased(false)` restores everything, `_wall_waves_left` is reset to 0 (nothing spawns after the window), and `intangible_timer` resets to 0, so the next phase-out is a full interval away.
- `take_damage()` also returns early while intangible, as a backstop.

## Dash

- When the `ORBIT` → `PAUSE` transition happens, `dash_target` is set to `_opposite_orbit_point()`: `arena_center - (global_position - arena_center)`, the point on the ring directly across from the boss.
- The dash is always the same length (2 × `orbit_radius`, 80px by default), so it takes about 0.4s at `dash_speed` 200 and always passes through the arena center.
- **Dash marker:** from the start of the pause until the boss arrives, `_draw()` shows a ring at the target and a faint line along the path. It's redrawn every frame while visible. Turn it off with the `show_dash_marker` export (default on).
- The orbit direction reverses at the moment the dash starts.

## Attack sequence (`_next_attack()`)

Attacks are a fixed sequence, not random. Every time the boss reaches the end of a dash (or skips the dash, if disabled), `perform_attack_selection()` takes the next attack and goes to `ATTACK_WINDUP`:

- **Phase 1:** burst, burst, bounce, repeat (`PHASE_1_ATTACK_SEQUENCE`).
- **Phase 2:** burst, bounce, repeat (`PHASE_2_ATTACK_SEQUENCE`). `attack_index` resets to 0 when phase 2 starts.
- If only one attack toggle is enabled, that attack is always used.
- If both `enable_burst_attack` and `enable_bounce_attack` are `false`, no attack is spawned and the boss returns straight to `ORBIT`.

### Windup telegraph

In `ATTACK_WINDUP` the boss holds still for `attack_telegraph_duration` (0.4s) while the sprite glows more and more in the same warm yellow (`WINDUP_COLOR`) for both attacks. The attack spawns when the windup ends. The damage flash and the phase-2 flash still draw over it.

## Attacks

### Radial Burst (`spawn_burst_attack`)
- **Phase 1:** `burst_projectile_count` (6) `RadialProjectile` instances in an evenly spaced ring, offset by `phase_1_burst_rotation` (0, so the first one points right).
- **Phase 2:** `phase_2_burst_count` (8) projectiles, one every 45°. `phase_2_burst_rotation` is -90° (`-PI / 2`), so the first projectile points straight up (0°) and the rest follow every 45° around the ring.
- The angle step is `TAU / count`, so the ring stays even if you change the count.
- **Held ring, launched together:** after the yellow windup glow, the whole ring spawns at once, held in place and already pointing outward, so the player can see where each projectile will come from. After `burst_hold_duration` (0.5s) **every projectile launches at the same moment**, with no order. `launch(dir, speed, source, delay, lifetime)` carries the delay (the same for all) and the optional flight time (default `LIFETIME`, 2.0s, which keeps the burst unchanged), and `launch_delay` counts down in the projectile's `_physics_process`, which skips movement and the lifetime timer until it reaches 0.
- **Live while held:** a hovering projectile is fully active. It can hurt the player and be shot down for a drop. Only its flight is delayed.
- `ATTACK_BURST` normally lasts 1.0s. If the hold is longer than 0.7s (`burst_hold_duration + 0.3`), the state lasts that long instead, so the boss stays still until the ring has launched.
- Each projectile spawns at `global_position + direction * burst_spawn_offset` (24px outside the boss's own body by default) so it doesn't visually spawn inside the boss sprite.
- Speed is `phase_1_burst_speed` (100) or `phase_2_burst_speed` (150) depending on phase.
- Projectiles fly in a straight line and self-destruct (fade) on hitting a wall, the player, or after their lifetime expires.
- The player can shoot them down. A projectile shot down this way has a chance to drop a pickup (see [Projectile drops](#projectile-drops)).

### Bouncing Fireballs (`spawn_bounce_attack`)
- Spawns `phase_1_bounce_count` (6) or `phase_2_bounce_count` (8) `BouncingFireball` instances in a horizontal line `bounce_spawn_height` (40px) **above** the boss, evenly spaced `bounce_spacing` (20px) apart and centered over the boss. The curtain falls from above, which gives the player a longer fall time to react.
- **Walls and ceilings:** a non-floor collision destroys a fireball on its first move, so each spawn point is checked with a ray from the boss to that point (World layer). If something is in the way, the point is pulled back `FIREBALL_WALL_MARGIN` (8px) from it. If that leaves it closer than `FIREBALL_MIN_SPAWN_DISTANCE` (14px) to the boss, that fireball is skipped. Near a low ceiling the curtain bends under it, and some fireballs may be missing.
- **No self-collision:** fireballs pass through the boss that fired them. Their bodies only collide with the world, and their hitbox ignores the boss's hurtbox (`shooter`). The boss's `ContactDamage` area is a `Hitbox` that calls `receive_hit` on any hurtbox it overlaps, so `_shot_down()` also ignores any hit whose `source` is the shooter. Without that, fireballs falling through the boss's body (the middle ones, under the curtain) faded when they touched its contact area. Burst projectiles have the same exception.
- **Curtain sweep:** all fireballs spawn at once, but each hovers in place for `sweep_order * bounce_release_delay` (0.12s per fireball) before it starts to fall. The row drops from one end to the other like a wave. `setup(gravity, speed, source, delay)` carries the delay, and `release_delay` counts down in the fireball's `_physics_process`, which skips gravity and movement until it reaches 0.
- **Alternating direction:** `bounce_sweep_direction` flips after every cast. One cast sweeps left to right, the next right to left, so the player can't just wait on one side. The first cast of a fight is left to right.
- **Live while held:** a hovering fireball is fully active. It can hurt the player and can be shot down for a drop. Only its fall is delayed.
- The sweep fits inside the 2s `ATTACK_BOUNCE` state: the last fireball of 6 starts falling after about 0.6s.
- Each fireball falls under `bounce_gravity` and bounces off floors up to `MAX_BOUNCES` (5) times, losing speed each bounce, before self-destructing. Sideways drift is random up to `bounce_horizontal_drift` (50 px/s) and applied when the fireball is released. Set it to 0 for fireballs that fall straight down in clean columns.
- Fireballs can also be shot down for a drop.

### Projectile drops

Both `RadialProjectile` and `BouncingFireball` have a `drop_table` export and a `_shot_down()` method, called when the player's shot hits their `Hurtbox`.

- On the first hit only (`is_fading` guard), `_shot_down(source)` fades the projectile. It calls `DropManager.try_drop(self, drop_table)` **only if `source` is in the `player` group**. The `source` is whoever fired the shot: bullets, charge beams and missile explosions all pass the player.
- A hit from anything else still fades the projectile but never drops. This covers any non-player damage.

### Projectiles ignore each other

`BouncingFireball` and `RadialProjectile` each have a `Hitbox` and a `Hurtbox` on the shared hitbox and hurtbox layers. Without a filter, one projectile's hitbox counts a neighbouring projectile's hurtbox as an enemy, and makes it fade. Fireballs spawn only 20px apart with 12px-wide hitboxes, so they touched easily while falling and faded before reaching the floor.

- Both scripts now skip any overlapping area whose parent is a `BouncingFireball` or a `RadialProjectile`. A burst crossing the fireballs no longer cancels either.
- Fireballs also store `shooter` (passed as the third argument of `setup(gravity, speed, source)`) and skip the boss that fired them, so a fireball can't damage its own boss.
- Player shots hit a projectile's `Hurtbox` through the player's own hitbox, so shooting projectiles down is unaffected.
- Projectiles that fade on their own never drop anything: a wall hit, a player hit, max bounces or the lifetime running out.
- If `drop_table` is empty, `_ready` creates a default `DropTable` with `drop_chance = DEFAULT_DROP_CHANCE` (0.2). That's lower than the enemy default (0.7) since up to 6 projectiles spawn at once.
- Health vs missile weights are the `DropTable` defaults. Missile refills only drop once the player has missiles unlocked, as for other enemies.

## Flame Wall

The boss's one action while phased out. A vertical column of flames appears at the left or right wall of the room and flies along the floor towards the player, who has to **jump over it**. It is not a `BossState` and is not in `AttackType` or the attack sequences: intangibility stays an overlay on `ORBIT`, and the boss is still undamageable and doesn't use its normal attacks while phased.

### Jump-height constraint

The column is `wall_flame_count` flames (default 4, hard cap `FLAME_WALL_MAX_FLAMES` = 4, also enforced in code if the export is changed) spaced `wall_flame_spacing` (16px) apart, so it is exactly `count * spacing` = 64px tall (4 tiles). Flame `i` is at `y = floor_y - spacing * (i + 0.5)`, so the lowest flame sits flush on the floor. The column is never shrunk to fit: if it doesn't fit, the wave is skipped.

> Note: with the current player values (`jump_velocity` -320, `jump_gravity` 750) a full jump peaks at about 68px (about 4.3 tiles; a spin jump about 79px), not 5 to 6 tiles. A 4-flame column leaves little margin at the default speed, so check it in play (see the testing exports) and lower `wall_flame_count` or raise `wall_speed` if it feels unfair.

### Scheduling

- `enter_intangible_state()`: if `enable_flame_wall`, `_wall_waves_left = 1` in phase 1 or `2` in phase 2, and `_wall_timer = wall_cast_delay` (0.8s).
- `_update_intangibility()` (intangible branch, after the duration check, so nothing spawns on the frame the window ends) calls `_update_flame_wall(delta)`. When `_wall_timer` reaches 0 and waves remain, it calls `_spawn_flame_wall()`, decrements `_wall_waves_left` and sets `_wall_timer = wall_wave_gap` (0.7s). A skipped wave still counts as cast.
- `exit_intangible_state()` and `_on_health_died()` set `_wall_waves_left = 0`.
- **Phase 1:** one column per window. **Phase 2:** two columns about `wall_wave_gap` (0.7s) apart; each wave picks its own random side.
- `wall_waves` is not an export: it is derived from `phase` when the window starts.

### Spawning (`_spawn_flame_wall`)

All rays use the World layer (mask 1) and report geometry they start inside of (`hit_from_inside`), so nothing spawns in a wall.

1. Find the player (`player` group). Return if there is none.
2. Ray **down** from the player to find `floor_y`. No floor means the wave is skipped.
3. For each side, ray **left/right** from the player to find the wall. A side is **invalid** if:
   - the ray finds no wall;
   - the column (`wall_x ∓ wall_spawn_margin`) is less than `FLAME_WALL_MIN_PLAYER_DISTANCE` (32px) from the player;
   - there is less than `count * spacing` of free headroom above the floor at the column x (ray up);
   - any flame's row is blocked between the column and the player (one horizontal ray per flame, e.g. a pillar).
4. Pick randomly among the valid sides. If none is valid, the wave is skipped. With `debug_enabled`, every rejected side prints why, including the node it hit (for example a closed room gate).
   - `wall_spawn_margin` (24px) has to clear anything that sticks out of the wall. A closed `RoomGate` reaches about 13px into the room, and with the old 12px margin the left column in `Room_ToBoss` sat inside the gate, so that side was always rejected.
5. Instantiate `Scenes/Projectiles/flame_wall_projectile.tscn` (falls back to `radial_projectile_scene`) for each flame, add it, set `global_position`, and call `launch(Vector2(±1, 0), wall_speed, self, wall_hold_duration, wall_lifetime)`. Left wall flies +X, right wall flies -X.

### Telegraph and simultaneous launch

The existing hover mechanic is reused: every flame gets the same `launch_delay` (`wall_hold_duration`, 0.6s), so the column hovers pointing along its travel direction, then **every flame launches on the same frame**. Hovering flames are live (they can hurt and be shot down).

### Flame behaviour

Flames are `RadialProjectile`s, so everything in [Projectile drops](#projectile-drops) and [Projectiles ignore each other](#projectiles-ignore-each-other) applies: they can be shot down (with the usual drop), don't damage or fade each other or Phantoon, and fade on walls.

`flame_wall_projectile.tscn` inherits `radial_projectile.tscn` and only scales the sprite 2x across its width. The burst flame art is 8px wide and the column pitch is 16px, so unscaled flames would leave 8px visual gaps (the 16px-diameter hitbox is already solid). The art faces its direction of travel because `RadialProjectile` rotates by `direction.angle() - PI/2`, so no extra flip is needed; the burst scene is unchanged.

### Timing (defaults)

Window = 3.0s (`intangible_duration`), starting at the end of the 0.5s warning.

| Event | Phase 1 | Phase 2 |
|---|---|---|
| Wave 1 spawns (hovers) | 0.8s | 0.8s |
| Wave 1 launches | 1.4s | 1.4s |
| Wave 2 spawns | - | 0.8 + 0.7 = 1.5s |
| Wave 2 launches | - | 2.1s |
| Window ends | 3.0s | 3.0s |

Both waves spawn and launch inside the window. A 256px room takes about 1.6s to cross at 140 px/s, so the last flames can still be flying for up to about 0.9s after the boss re-solidifies; they fade on the far wall (`wall_lifetime` 4s only caps flames that never hit anything). The next normal attack can't spawn that soon: after the window the attack timer resumes, and the shortest path to an attack is pause + dash + windup (0.75 + 0.4 + 0.4 = about 1.55s in phase 2; 1.15s with the dash disabled). So Flame Wall flames and normal attacks don't overlap.

### Testing exports

Under the `Testing` category (all off by default):

- `test_loop_intangibility` / `test_intangible_interval` (1.0s): phase out again every `test_intangible_interval` seconds of tangible time instead of `intangible_interval`.
- `test_start_phase`: 0 = normal, 1 or 2 starts the fight in that phase (2 applies the phase 2 changes at spawn, so the two-wave rule can be checked without damaging the boss).

For isolated testing, also turn off `enable_burst_attack` and `enable_bounce_attack`.

## Phases

- **Phase 1:** default values, attack sequence burst, burst, bounce.
- **Phase 2:** triggered once when `health.current_health <= max_health / 2`. Increases orbit speed and attack frequency, and switches to the burst, bounce sequence. Triggers a brief white flash on the sprite as a visual cue. Phase 2 only triggers once (`phase_2_triggered` guard), and never on the hit that kills the boss.

## Visuals

`_update_visuals(delta)` computes the sprite `modulate` once per frame, so effects can't overwrite each other:

1. White by default, or the phase-2 flash (`PHASE_FLASH_COLOR`, 0.2s), or the red damage tint while `damage_flash_timer` is running (0.12s).
2. Alpha is `intangible_fade_amount` while intangible, or flickers during the warning.
3. If dying, alpha fades from 1 to 0 over `death_duration`.

## Damage & Death

- `take_damage()` is ignored while intangible or `DEAD`.
- Taking damage tints the sprite red briefly (`damage_flash_timer`, 0.12s) and checks for the Phase 2 transition.
- **Death drops are guaranteed.** On death, `DropManager.drop_guaranteed()` spawns `death_health_drops` (10) health pickups and `death_missile_drops` (10) missile refills. There is no roll and no missile-unlock check.
  - They scatter horizontally within `death_drop_spread` (48px) of the boss, with a small random vertical offset.
  - They stay for `death_drop_lifetime` (20s) instead of the default 8s, since there are 20 of them to collect.
  - The old `drop_table` export no longer exists on the boss.
  - Missile refills are ignored by the player while missiles are locked. They are still spawned, and despawn on their timer.
- On death (`HealthComponent.died` signal), the boss clears intangibility and disables all its `CollisionShape2D`/`CollisionPolygon2D` children. `Area2D` children stop monitoring and become non-monitorable, so projectiles stop being consumed. It then fades its sprite out over `death_duration` (0.5s), emits `defeated` and `queue_free()`s. `defeated` fires just before the node frees itself, after the fade; the boss door's `BossEncounter` listens to it (not to `tree_exiting`, which also fires when the level reloads). See `environment_logic/BOSS_ENCOUNTER.md`. In `demo_wrecked_ship_3` the boss has `save_id = "boss_phantoon"`.

## Feature toggles (for testing)

All default to `true`, meant to be disabled individually for isolated testing:

- `enable_dash` — if `false`, the boss skips the dash and attacks immediately from its current orbit position after the pause.
- `enable_burst_attack` — if `false`, only bounce attacks are ever chosen.
- `enable_bounce_attack` — if `false`, only burst attacks are ever chosen.
- `enable_intangibility` — if `false`, the boss never becomes intangible (so no Flame Wall either).
- `enable_flame_wall` — if `false`, intangibility behaves exactly as before: the boss only orbits while phased. (Lives in the `Flame Wall` export category.)

## Other exports

The inspector is split into categories, with sub-groups inside the bigger ones. All of them are declared together at the top of `phantoon.gd`:

| Category | Groups / contents |
|---|---|
| General | `debug_enabled`, `save_id`, `max_health`, `contact_damage_value` |
| Feature Toggles | `enable_dash`, `enable_burst_attack`, `enable_bounce_attack`, `enable_intangibility` |
| Movement | Orbit, Dash |
| Attacks | Windup, Radial Burst, Bouncing Fireballs |
| Intangibility | one flat list |
| Flame Wall | `enable_flame_wall`, then Column, Timing, Flight |
| Death Drops | one flat list |
| Testing | Flame Wall / phase test helpers |

| Export | Default |
|---|---|
| `bounce_release_delay` | 0.12 |
| `burst_hold_duration` | 0.5 |
| `phase_1_bounce_count` / `phase_2_bounce_count` | 6 / 8 |
| `bounce_spawn_height` / `bounce_spacing` | 40 / 20 |
| `bounce_horizontal_drift` | 50 (replaces the old `bounce_projectile_speed`, which only controlled this) |
| `phase_2_burst_count` | 8 |
| `phase_2_burst_rotation` | -PI/2 (straight up) |
| `death_health_drops` / `death_missile_drops` | 10 / 10 |
| `death_drop_spread` / `death_drop_lifetime` | 48 / 20 |
| `attack_telegraph_duration` | 0.4 |
| `show_dash_marker` | true |

## Intangibility exports

| Export | Default |
|---|---|
| `intangible_interval` | 15.0 |
| `intangible_duration` | 3.0 |
| `intangible_warning_duration` | 0.5 |
| `intangible_fade_amount` | 0.5 |

## Flame Wall exports

| Export | Default |
|---|---|
| `enable_flame_wall` | true |
| `wall_flame_count` | 4 (range 1 to 4) |
| `wall_flame_spacing` | 16.0 |
| `wall_speed` | 140.0 |
| `wall_hold_duration` | 0.6 |
| `wall_cast_delay` | 0.8 |
| `wall_wave_gap` | 0.7 |
| `wall_spawn_margin` | 24.0 |
| `wall_lifetime` | 4.0 |
| `test_loop_intangibility` | false |
| `test_intangible_interval` | 1.0 |
| `test_start_phase` | 0 |
