extends Area2D

class_name Hitbox

@export var damage: int = 1
@export var one_shot: bool = true
@export var source: Node = null
## Entities in this group are never damaged by this hitbox (e.g. "zoomer" so
## zoomers don't hurt each other). Empty disables the filter.
@export var ignore_group: StringName = &""

func _ready() -> void:
    connect("area_entered", Callable(self, "_on_area_entered"))
    connect("body_entered", Callable(self, "_on_body_entered"))

func _is_ignored(node: Node) -> bool:
    return ignore_group != &"" and node != null and node.is_in_group(ignore_group)

func _on_area_entered(area: Area2D) -> void:
    # Ignore overlaps with our own entity's areas (prevent self-hits)
    if area and area.get_parent() == get_parent():
        return

    if area and _is_ignored(area.get_parent()):
        return

    # Prefer Hurtbox.receive_hit when available
    if area and area.has_method("receive_hit"):
        area.call("receive_hit", damage, source)
        if one_shot:
            queue_free()

func _on_body_entered(body: Node) -> void:
    # Ignore hits on our own parent (prevent self-hits)
    if body and body == get_parent():
        return

    if _is_ignored(body):
        return

    # If the body has a child Hurtbox, use it
    if body and body.has_node("Hurtbox"):
        var hb = body.get_node("Hurtbox")
        if hb and hb.has_method("receive_hit"):
            hb.call("receive_hit", damage, source)
            if one_shot:
                queue_free()
            return

    # Fallback: if body itself supports take_damage
    if body and body.has_method("take_damage"):
        body.call("take_damage", damage, source)
        if one_shot:
            queue_free()
