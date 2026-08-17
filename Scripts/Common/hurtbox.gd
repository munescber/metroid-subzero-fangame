extends Area2D

class_name Hurtbox

# The entity that owns this hurtbox; defaults to the parent node
var owner_entity: Node = null

func _ready() -> void:
	if owner_entity == null:
		owner_entity = get_parent()
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_area_entered(area: Area2D) -> void:
	if area == self:
		return
	if area and area.has_method("receive_hit"):
		return
	if owner_entity and owner_entity.has_method("take_damage"):
		# area_entered is used for other areas that expose damage data directly
		if area and area.has_method("get") and area.get("damage") != null:
			receive_hit(area.get("damage"), area.get("source"))
		return

func _on_body_entered(body: Node) -> void:
	if body == owner_entity:
		return
	if body and body.has_method("receive_hit"):
		body.call("receive_hit", 1, owner_entity)
		return
	if body and body.has_node("Hurtbox"):
		var hurtbox = body.get_node("Hurtbox")
		if hurtbox and hurtbox.has_method("receive_hit"):
			hurtbox.call("receive_hit", 1, owner_entity)
		return

func receive_hit(damage: int, source = null) -> void:
	if source == owner_entity:
		return
	if owner_entity and owner_entity.has_method("take_damage"):
		owner_entity.call("take_damage", damage, source)
