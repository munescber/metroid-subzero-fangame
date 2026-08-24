extends Area2D

class_name ContactDamage

# Contact damage specifically for boss/enemy contact with player
# This is separate from the Hitbox system to avoid accidental damage interactions

@export var damage: int = 1
@export var one_shot: bool = false  # false = continuous damage
@export var debug_enabled: bool = false
var source: Node = null

func _ready() -> void:
	if debug_enabled:
		print_debug("[ContactDamage] Ready - damage=", damage, " source=", source)
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))
	if debug_enabled:
		print_debug("[ContactDamage] Signals connected. collision_layer=", collision_layer, " collision_mask=", collision_mask)


func _on_area_entered(area: Area2D) -> void:
	# Only damage if it's a player hurtbox (not a bullet)
	# This prevents bullets from triggering contact damage to the boss
	
	if area == null:
		return
	
	if debug_enabled:
		print_debug("[ContactDamage] area_entered: ", area.name, " (parent: ", area.get_parent().name if area.get_parent() else "none", ")")
	
	# Check if this is the player's hurtbox or player collision
	var parent = area.get_parent()
	var is_player = (parent and (parent.name == "Player" or 
								parent.name == "player_rundas" or
								parent.is_in_group("player") or
								(parent.get_script() and parent.get_script().resource_name.contains("player"))))
	
	if is_player:
		# This is the player, apply damage
		if area.has_method("receive_hit"):
			if debug_enabled:
				print_debug("[ContactDamage] Hitting player hurtbox with ", damage, " damage")
			area.call("receive_hit", damage, source)
			return
		# Also try direct damage if no receive_hit method
		if parent.has_method("take_damage"):
			if debug_enabled:
				print_debug("[ContactDamage] Hitting player directly with ", damage, " damage")
			parent.call("take_damage", damage, source)
			return
			return
	
	# For anything else (including bullets), just ignore
	# Don't apply damage to the boss or process bullets here


func _on_body_entered(body: Node2D) -> void:
	"""Handle contact with CharacterBody2D (like the player)."""
	if body == null:
		return
	
	if debug_enabled:
		print_debug("[ContactDamage] body_entered: ", body.name)
	
	# Check if this is the player - check multiple variants
	var is_player = (body.name == "Player" or 
					body.name == "player_rundas" or 
					body.is_in_group("player") or
					body.get_script() and body.get_script().resource_name.contains("player"))
	
	if is_player:
		if body.has_method("take_damage"):
			if debug_enabled:
				print_debug("[ContactDamage] Hitting player body with ", damage, " damage")
			body.call("take_damage", damage, source)
			return
	
	if debug_enabled:
		print_debug("[ContactDamage] body_entered but not player: ", body.name)
