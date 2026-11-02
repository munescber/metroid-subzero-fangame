extends Area2D

class_name SavePoint

## Stand inside the area and press `interact_action` to write the save slot through SaveManager.
## Place it in a room; the room's activation turns the area off while the player is elsewhere.

signal saved

## Unique id of this save point, stored in the save so the game can restart here.
@export var save_id: String = ""
@export var interact_action: StringName = &"up"
@export var sfx_saved: AudioStream
## Refills the player's health and missiles right before saving.
@export var refill_on_save: bool = true
@export var message_seconds: float = 1.5
@export var debug_enabled: bool = false

@onready var message: Label = $Message

var _message_tween: Tween

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # PlayerBody
	add_to_group("save_point")
	if save_id == "":
		push_warning("[SavePoint] %s has no save_id; using its name." % name)
		save_id = String(name)
	message.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(interact_action):
		save()

## Writes the slot. Returns false if SaveManager could not write the file.
func save() -> bool:
	if refill_on_save:
		var player := get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("restore_all"):
			player.restore_all()
	var ok := SaveManager.save_game(save_id)
	if ok:
		AudioManager.play_sfx_2d(sfx_saved, global_position)
		_show_message("GAME SAVED")
		saved.emit()
	else:
		_show_message("SAVE FAILED")
	if debug_enabled:
		print_debug("[SavePoint] ", save_id, " saved: ", ok)
	return ok

func _show_message(text: String) -> void:
	message.text = text
	message.visible = true
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(message_seconds)
	_message_tween.tween_callback(message.hide)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		set_physics_process(true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		set_physics_process(false)
