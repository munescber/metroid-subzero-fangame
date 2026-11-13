extends Pickup

class_name DashPowerup

## Unlocks the dash, downward dash and slide (all on the "dash" action). Until collected,
## pressing dash does nothing. A progression item; set save_id so it stays collected
## after saving.

func _try_collect(body: Node) -> bool:
	if not body.has_method("collect_dash"):
		return false
	body.collect_dash()
	_play_pickup_sound()
	_notify("DASH SYSTEM ACQUIRED", "Dash, downward dash and slide unlocked.")
	return true
