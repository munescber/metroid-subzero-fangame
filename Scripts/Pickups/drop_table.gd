extends Resource

class_name DropTable

## Enemy drop settings. Assign one to an enemy's `drop_table` to override the
## defaults; leave it empty to use DropManager's default table (these values).

## Chance (0-1) that a defeated enemy drops anything.
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.7
## Relative weight of a HealthPickup among drops.
@export_range(0.0, 100.0, 1.0, "or_greater") var health_weight: float = 55.0
## Relative weight of a MissileRefill among drops (ignored while missiles are locked).
@export_range(0.0, 100.0, 1.0, "or_greater") var missile_weight: float = 45.0
