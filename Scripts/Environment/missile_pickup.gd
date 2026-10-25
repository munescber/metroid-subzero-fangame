extends Area2D

class_name MissilePickup

## Grants missiles to the player on touch (PlayerBody layer), then removes itself.

var _collected: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # PlayerBody
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _collected or not body.has_method("collect_missiles"):
		return
	_collected = true
	body.collect_missiles()
	queue_free()
