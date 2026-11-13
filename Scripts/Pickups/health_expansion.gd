extends Pickup

class_name HealthExpansion

## Raises the player's max health and heals by the same amount (energy-tank style).

## Max health (and HP) granted by this expansion.
@export_range(1, 999, 1, "or_greater") var expansion_amount: int = 100

func _try_collect(body: Node) -> bool:
	if not body.has_method("collect_health_expansion"):
		return false
	body.collect_health_expansion(expansion_amount)
	_play_pickup_sound()
	_notify("HEALTH EXPANSION", "Maximum health increased by %d." % expansion_amount)
	return true
