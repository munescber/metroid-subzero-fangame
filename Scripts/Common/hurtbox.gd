extends Area2D

class_name Hurtbox

# The entity that owns this hurtbox; defaults to the parent node
var owner_entity: Node = null

func _ready() -> void:
	if owner_entity == null:
		owner_entity = get_parent()

func receive_hit(damage: int, source = null) -> void:
	# Validate that the source is actually near this hurtbox
	# This prevents damage from physics collisions on other parts of the body
	if source and source.has_method("get_global_position"):
		# Check distance between source and hurtbox center
		var source_pos = source.get_global_position()
		var hurtbox_pos = get_global_position()
		var distance = source_pos.distance_to(hurtbox_pos)
		
		# Only accept damage if source is within ~10 units of hurtbox
		# (hurtbox radius is 5, plus some tolerance for bullet size)
		if distance > 10.0:
			print_debug("[Hurtbox] Damage rejected - source too far (distance: %.1f)" % distance)
			return
	
	if owner_entity and owner_entity.has_method("take_damage"):
		owner_entity.call("take_damage", damage, source)
