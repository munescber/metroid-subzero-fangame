# Room Size Standards

## Purpose

This document defines the standard room dimensions for the project.

The game uses a 16x16 pixel tile size and a room-based layout inspired by classic NES Metroid. Rooms should be designed around fixed screen-sized units so that camera behavior, room transitions, and level design remain consistent.

## Base Tile Size

- Tile width: 16 px
- Tile height: 16 px
- Tile format: square 16x16 tiles

## Standard Room / Screen

The base room is one screen:

- Width: 16 tiles
- Height: 15 tiles
- Pixel dimensions: 256x240 px
- Total tiles: 240

Formula:

- 16 tiles × 16 px = 256 px wide
- 15 tiles × 16 px = 240 px high

### Standard Room Grid

```text
16 tiles wide
┌────────────────────────────────┐
│                                │
│                                │
│                                │
│                                │
│                                │
│                                │
│                                │
│                                │
│                                │
│                                │
│                                │
│                                │
│                                │
│                                │
│                                │
└────────────────────────────────┘
15 tiles high
```

## Multi-Screen Rooms

Rooms may occupy multiple standard screen units.

### Horizontal

2 screens wide:

- 32 × 15 tiles
- 512 × 240 px

3 screens wide:

- 48 × 15 tiles
- 768 × 240 px

### Vertical

2 screens tall:

- 16 × 30 tiles
- 256 × 480 px

3 screens tall:

- 16 × 45 tiles
- 256 × 720 px

### Combined

2 × 2 screens:

- 32 × 30 tiles
- 512 × 480 px

3 × 2 screens:

- 48 × 30 tiles
- 768 × 480 px

## Design Rules

1. All level geometry should align to the 16x16 tile grid.
2. The standard camera/room unit is 256x240 pixels (16x15 tiles).
3. New rooms should default to one 16x15 screen unless there is a specific gameplay reason to make them larger.
4. Larger rooms should be exact multiples of the standard screen dimensions.
5. Do not create arbitrary room sizes such as 20x17 tiles unless explicitly required.
6. Room transitions should occur on standard screen boundaries whenever possible.
7. Important gameplay elements such as doors, exits, platforms, and room connections should align with the tile grid.
8. Keep collision geometry aligned to the same 16x16 grid.

## Godot Implementation

For a standard room:

```text
Room
├── Ground (TileMapLayer)
├── Decorations (TileMapLayer)
├── Player
└── Camera2D
```

The `Ground` TileMapLayer should use a 16x16 TileSet.

A standard room should occupy:

```text
256 x 240 pixels
16 x 15 tiles
```

## Camera Standard

The intended base camera view is one standard room:

```text
Camera viewport:
256 x 240 pixels
```

If the project uses a different window or viewport resolution, the game should preserve the same logical room dimensions through the project's viewport/scaling configuration rather than changing the underlying room grid.

## Why This Standard Exists

Using fixed room units provides:

- Consistent camera behavior
- Predictable room transitions
- Easier level planning
- Easier room-to-room connections
- Consistent placement of doors and exits
- A visual scale appropriate for the project's 16x16 pixel art
- A classic NES Metroid-inspired structure

## Reference

The original NES display is 256x240 pixels. With a 16x16 level-design tile size, that corresponds to a 16x15 tile screen.

The NES hardware itself uses 8x8 graphics tiles, so this project's 16x16 tiles should be understood as the project's level-design unit rather than a direct representation of the NES hardware tile format.

## Copilot Guidance

When generating or modifying levels, scripts, room layouts, camera logic, or level-generation tools:

- Assume a 16x16 pixel tile size unless explicitly overridden.
- Treat 256x240 pixels (16x15 tiles) as one standard room/screen.
- Prefer room dimensions that are integer multiples of 16 tiles horizontally and 15 tiles vertically.
- Do not introduce arbitrary room dimensions without explaining why.
- Keep room boundaries aligned to standard 256x240 pixel screen boundaries when implementing room transitions or camera constraints.
