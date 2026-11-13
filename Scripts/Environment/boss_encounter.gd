extends Node2D

class_name BossEncounter

## Locks a boss room's doors while the boss lives. Place it under the boss's RoomRegion with a child
## Area2D named "Trigger" (layer 0, mask = player body layer 2) covering the room past the doorway.
## - The first time the player enters the trigger, every gate in `gate_paths` is locked
##   (RoomGate.lock(); a gate's partner is locked with it) and the trigger is switched off.
## - When the boss emits `defeated` (after its death fade), the gates are unlocked.
## - If the flag `boss_save_id` says the boss is already defeated, nothing is ever locked.
## The locked state is not saved. Dying reloads the level (SaveManager.restart_from_save), which
## builds a fresh encounter with unlocked gates and an armed trigger.
## See Docs/environment_logic/BOSS_ENCOUNTER.md.

@export var boss_path: NodePath
@export var gate_paths: Array[NodePath] = []
## The save flag the boss sets when it dies (the boss's own `save_id`).
@export var boss_save_id: String = ""
## Turn on for the final boss: once it is defeated (and the doors unlock) the game's Mission Complete
## sequence starts via MissionManager. Off by default; no boss is marked final yet.
@export var completes_mission: bool = false
@export var debug_enabled: bool = false

@onready var _trigger: Area2D = $Trigger

## Set once the doors have locked or the boss is known to be defeated. The trigger's `monitoring`
## cannot be trusted for this: RoomRegion restores it when the room is reactivated.
var _triggered: bool = false

## SaveManager finds saveable nodes by this property. It reads the boss's flag, so a save that is
## applied after _ready() (auto-continue) still disarms the trigger.
var save_id: String:
	get:
		return boss_save_id

func _ready() -> void:
	if boss_save_id != "":
		add_to_group("saveable")
	if boss_save_id != "" and SaveManager.get_flag(boss_save_id).get("defeated", false):
		_disarm()
		return
	var boss := get_node_or_null(boss_path)
	if boss == null:
		push_warning("[BossEncounter] No boss at %s; the doors will never lock." % boss_path)
		_disarm()
		return
	boss.connect(&"defeated", _on_boss_defeated)
	_trigger.body_entered.connect(_on_trigger_body_entered)

func get_save_data() -> Dictionary:
	return {}  # The boss writes the flag itself when it dies.

func load_save_data(data: Dictionary) -> void:
	if data.get("defeated", false):
		_disarm()

func _on_trigger_body_entered(_body: Node2D) -> void:
	if _triggered:
		return
	_triggered = true
	_disarm()
	if debug_enabled:
		print_debug("[BossEncounter] Locking doors.")
	for gate in _get_gates():
		gate.lock()

func _on_boss_defeated() -> void:
	if debug_enabled:
		print_debug("[BossEncounter] Boss defeated, unlocking doors.")
	for gate in _get_gates():
		gate.unlock()
	if completes_mission:
		MissionManager.complete_mission()

func _get_gates() -> Array[RoomGate]:
	var gates: Array[RoomGate] = []
	for path in gate_paths:
		var gate := get_node_or_null(path) as RoomGate
		if gate != null:
			gates.append(gate)
	return gates

# Deferred: this can run inside the physics callback that reported the player.
func _disarm() -> void:
	_triggered = true
	_trigger.set_deferred("monitoring", false)
