extends Area2D

class_name ContactDamage

# Contact damage specifically for boss/enemy contact with player
# This is separate from the Hitbox system to avoid accidental damage interactions

@export var damage: int = 1
@export var one_shot: bool = false  # false = continuous damage
var source: Node = null

func _ready() -> void:
	connect("area_entered", Callable(self, "_on_area_entered"))


func _on_area_entered(area: Area2D) -> void:
	# Only damage if it's a player hurtbox (not a bullet)
	# This prevents bullets from triggering contact damage to the boss
	
	if area == null:
		return
	
	# Check if this is the player's hurtbox
	var parent = area.get_parent()
	if parent and parent.name == "Player":  # Adjust name as needed for your player
		# This is the player, apply damage
		if area.has_method("receive_hit"):
			area.call("receive_hit", damage, source)
			return
	
	# For anything else (including bullets), just ignore
	# Don't apply damage to the boss or process bullets here
