extends Area2D

class_name ActivationButton

## Detects the player stepping on it (PlayerBody layer) or being shot (Hitbox layer)
## and calls activate()/toggle() on the configured target, without the target
## needing to know why it was triggered.

@export var target_path: NodePath
@export var one_shot: bool = false
@export var toggle_mode: bool = false
@export var debug_enabled: bool = false

var _target: Node = null
var _triggered: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 8  # PlayerBody (step on) + Hitbox (shoot)
	monitoring = true

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	if target_path != NodePath(""):
		_target = get_node(target_path)
		if _target == null:
			push_warning("ActivationButton: target_path did not resolve to a node.")
	elif debug_enabled:
		print_debug("[ActivationButton] No target_path set.")

func _on_body_entered(body: Node) -> void:
	if debug_enabled:
		print_debug("[ActivationButton] Body entered: ", body.name)
	if body.is_in_group("player"):
		if debug_enabled:
			print_debug("[ActivationButton] Hit by player (stepped on).")
		_trigger()

func _on_area_entered(area: Area2D) -> void:
	# Layer 8 (Hitbox) is shared by the player's bullets AND enemy attack
	# areas (ContactDamage, ElectricField, etc). Only the player's bullet
	# should trigger this button, so check bullet.gd's own "shooter" property
	# instead of a scene-saved group (which is fragile if the scene is open
	# and re-saved by the editor without the group).
	if not _is_player_projectile(area):
		if debug_enabled:
			print_debug("[ActivationButton] Ignored area (not a player projectile): ", area.name)
		return
	if debug_enabled:
		print_debug("[ActivationButton] Area entered: ", area.name, " (shot).")
	_trigger()

func _is_player_projectile(area: Area2D) -> bool:
	var owner_node := area.get_parent()
	return owner_node is Bullet

func _trigger() -> void:
	if one_shot and _triggered:
		if debug_enabled:
			print_debug("[ActivationButton] Ignored, already triggered (one_shot).")
		return
	_triggered = true

	if debug_enabled:
		print_debug("[ActivationButton] Triggered. target=", _target)

	if _target == null:
		push_warning("ActivationButton: triggered but target_path is not resolved, nothing to activate.")
		return

	if toggle_mode and _target.has_method("toggle"):
		_target.toggle()
	elif _target.has_method("activate"):
		_target.activate()
