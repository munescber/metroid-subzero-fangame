extends Pickup

class_name HealthPickup

## Restores player HP (clamped to max). Absorbed on contact even when HP is full.

## HP restored on collection.
@export_range(1, 999, 1, "or_greater") var heal_amount: int = 10

func _init() -> void:
	magnet_enabled = true

func _try_collect(body: Node) -> bool:
	if not body.has_method("heal"):
		return false
	body.heal(heal_amount)  # clamped by the player; may restore 0 when full
	_play_pickup_sound()
	return true
