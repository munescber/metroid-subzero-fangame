extends Pickup

class_name MissileExpansion

## Raises the player's max missile capacity and grants the same ammo. The first
## one also unlocks missiles.

## Capacity and ammo granted by this expansion.
@export_range(1, 999, 1, "or_greater") var expansion_amount: int = 5

func _try_collect(body: Node) -> bool:
	if not body.has_method("collect_missile_expansion"):
		return false
	var first_pickup: bool = not body.missiles_unlocked
	body.collect_missile_expansion(expansion_amount)
	_play_pickup_sound()
	if first_pickup:
		_notify("MISSILE SYSTEM ACQUIRED", "Missile launcher unlocked.")
	else:
		_notify("MISSILE EXPANSION", "Missile capacity increased by %d." % expansion_amount)
	return true
