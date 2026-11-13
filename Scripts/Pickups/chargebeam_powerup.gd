extends Pickup

class_name ChargeBeamPowerup

## Unlocks the charge beam: holding shoot charges, and a full charge fires the charge beam.
## Until collected, the player only fires normal bullets. A progression item; set save_id
## so it stays collected after saving.

func _try_collect(body: Node) -> bool:
	if not body.has_method("collect_charge_beam"):
		return false
	body.collect_charge_beam()
	_play_pickup_sound()
	_notify("CHARGE BEAM ACQUIRED", "Hold the shoot button to charge a powerful shot.")
	return true
