extends Area2D

class_name Hurtbox

# The entity that owns this hurtbox; defaults to the parent node
var owner_entity: Node = null

func _ready() -> void:
    if owner_entity == null:
        owner_entity = get_parent()

func receive_hit(damage: int, source = null) -> void:
    if owner_entity and owner_entity.has_method("take_damage"):
        owner_entity.call("take_damage", damage, source)
