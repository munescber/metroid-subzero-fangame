# Background / Hidden-Object Layering — Implementation Notes

A general-purpose draw-order convention for anything that needs to be
visually masked by real terrain at rest and revealed later (or vice versa).
First established to fix `RisingPlatform`'s draw order (see
[RISING_PLATFORM.md](RISING_PLATFORM.md)), but the pattern applies to any
similar "hidden until triggered" object.

## The three conceptual layers

| Layer | Purpose | Mechanism | `z_index` |
|---|---|---|---|
| 0 — background | Decoration behind everything; never collides | `TileMapLayer` (or `Sprite2D`s) with a `TileSet` that defines **no physics layer** | `-2` |
| 1 — hidden/dynamic objects | Things that should be masked by real terrain until revealed | Individual nodes (e.g. `RisingPlatform.Body`) | `-1` |
| 2 — real walls/floor | Actual solid terrain, the thing players collide with | `TileMapLayer` with a `TileSet` that **does** define a physics layer | `0` (default) |

Godot resolves draw order by `z_index` first, and only falls back to
scene-tree order when `z_index` is tied. Giving every layer an explicit,
different `z_index` removes the fragility of depending on node order (which
is what caused the original `RisingPlatform` bug — `Body` had no override,
tied with the `TileMapLayer` at `0`, and won by being later in the tree).

## Current implementation

- `Scenes/Levels/level_wrecked_ship_0.tscn`:
  - `BackgroundTileMapLayer` (new) — `z_index = -2`, uses `TileSet_bg`
    (shares `wrecked_ship.png` via a dedicated `TileSetAtlasSource_bg` with
    no physics layer defined). Starts empty; paint into it directly in the
    editor by selecting the node and using the TileMap bottom panel.
  - `TileMapLayer` (existing) — unchanged, `z_index = 0` (default),
    `TileSet_gbtge` with `physics_layer_0` — this is the real collidable
    terrain.
- `Scenes/Environment/rising_platform.tscn`:
  - `Body` — `z_index = -1`, always draws behind the real terrain layer
    regardless of tree order.

### Important: content must match z-index intent

Z-index alone only hides an object behind whatever is actually *drawn* on
top of it. A cell that's meant to let a hidden object show through must be
genuinely empty in the terrain layer — not just a tile that happens to look
like black/empty space. This was the root cause of the original bug in
`level_wrecked_ship_0`: tiles that visually read as "sky" were real, opaque
tiles. Always verify by eye in both the resting and revealed state.

## Reusable pattern: other "hidden until revealed" objects

The same 3-layer idea generalizes beyond the rising platform. Example —
**a breakable wall that hides a passage**:

- Layer 2 (real walls): the breakable wall segment itself, painted as a
  normal solid tile/`StaticBody2D` so the player can't walk through it yet.
- Layer 1 (hidden objects): whatever is behind the wall (a passage, item,
  or another `RisingPlatform`-style object) — placed with `z_index = -1` so
  it's invisible while the wall tile is intact.
- Layer 0 (background): any decoration visible only once the passage is
  open, sitting furthest back.

When the wall breaks (e.g. the tile is erased/swapped via
`TileMapLayer.erase_cell()` or the `StaticBody2D` is freed), the layer-1
object is no longer covered by anything and becomes visible — no extra
visibility logic needed on the revealed object itself, the layering does it
for free.

## Conventions going forward

- Don't rely on node/tree order for draw order between layers — always set
  an explicit `z_index`.
- Background layers' `TileSet` resources must never define a physics layer.
- Add a dedicated middle/"props" `TileMapLayer` only when there's actual
  static decorative content for it — dynamic objects (like `Body`) can set
  their own `z_index` directly and don't need an empty tile layer reserved
  for them preemptively.

## Related

- [RISING_PLATFORM.md](RISING_PLATFORM.md) — first consumer of this
  convention, see its "Draw order — resolved" section for the original bug.
- [ACTIVATION_BUTTON.md](ACTIVATION_BUTTON.md) — reusable trigger that can
  reveal layer-1 objects (platforms, breakable walls, etc.).
