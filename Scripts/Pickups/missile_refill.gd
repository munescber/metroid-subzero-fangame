extends Pickup

class_name MissileRefill

## Restores missile ammo up to the current max; never raises capacity. Absorbed
## on contact even when ammo is full, but ignored while missiles are locked.

## Ammo restored on collection.
@export_range(1, 999, 1, "or_greater") var refill_amount: int = 5

func _try_collect(body: Node) -> bool:
	if not body.has_method("restore_missiles") or not body.missiles_unlocked:
		return false
	body.restore_missiles(refill_amount)  # clamped by the player; may restore 0 when full
	return true
