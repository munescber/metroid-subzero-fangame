extends Node

class_name HealthComponent

signal damaged(amount, new_health)
signal died()

@export var max_health: int = 1
var current_health: int = 0

func _ready() -> void:
    current_health = max_health

func take_damage(amount: int, source = null) -> void:
    if amount <= 0:
        print_debug("[HealthComponent] Ignoring non-positive damage: ", amount, " source=", source)
        return

    # Only dead entities can stay dead; a health value of 0 or less is a death state.
    if current_health <= 0:
        print_debug("[HealthComponent] Ignoring damage on dead entity. current_health=", current_health, " amount=", amount, " source=", source)
        return

    var previous_health = current_health
    current_health = max(current_health - amount, 0)
    print_debug("[HealthComponent] Damage applied: ", amount, " from=", source, " previous=", previous_health, " current=", current_health)
    emit_signal("damaged", amount, current_health)

    if current_health <= 0:
        current_health = 0
        print_debug("[HealthComponent] Death triggered for health component on source=", source)
        emit_signal("died")

func heal(amount: int) -> void:
    if amount <= 0:
        return

    if current_health <= 0:
        return

    current_health = min(current_health + amount, max_health)

func set_max_health(new_max: int) -> void:
    max_health = max(1, new_max)
    current_health = clamp(current_health, 0, max_health)
