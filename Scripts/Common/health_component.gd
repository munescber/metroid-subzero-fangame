extends Node

class_name HealthComponent

signal damaged(amount, new_health)
signal died()

@export var max_health: int = 1
var current_health: int = 0

func _ready() -> void:
    current_health = max_health

func take_damage(amount: int) -> void:
    if amount <= 0:
        return

    # If already dead, ignore further damage
    if current_health == 0:
        return

    current_health = max(current_health - amount, 0)
    emit_signal("damaged", amount, current_health)

    if current_health == 0:
        emit_signal("died")

func heal(amount: int) -> void:
    if amount <= 0:
        return

    current_health = min(current_health + amount, max_health)

func set_max_health(new_max: int) -> void:
    max_health = max(1, new_max)
    current_health = min(current_health, max_health)
