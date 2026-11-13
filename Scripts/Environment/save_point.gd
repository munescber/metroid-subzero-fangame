extends Area2D

class_name SavePoint

## Stand inside the area and press `interact_action` to write the save slot through SaveManager.
## Place it in a room; the room's activation turns the area off while the player is elsewhere.
## A successful save pauses the game, plays the shared `Cutscene` (ObtainCutscene) animation and then
## shows a notification (NotificationManager) that the player dismisses with any key. With
## `use_cutscene` off, only a short non-pausing toast appears.

signal saved

## Unique id of this save point, stored in the save so the game can restart here.
@export var save_id: String = ""
@export var interact_action: StringName = &"up"
@export var sfx_saved: AudioStream
## Refills the player's health to full right before saving.
@export var refill_health_on_save: bool = true
## Refills the player's missiles to max right before saving.
@export var refill_missiles_on_save: bool = true
## Pause the game, play the cutscene animation and wait for the player to dismiss the notification.
@export var use_cutscene: bool = true
@export var notification_title: String = "GAME SAVED"
@export var notification_message: String = "Your progress has been saved."
## Seconds the toast stays when `use_cutscene` is off (and for "SAVE FAILED").
@export var notification_seconds: float = 2.0
@export var debug_enabled: bool = false

@onready var _cutscene: ObtainCutscene = $Cutscene

var _busy: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # PlayerBody
	add_to_group("save_point")
	if save_id == "":
		push_warning("[SavePoint] %s has no save_id; using its name." % name)
		save_id = String(name)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if _busy:
		return
	if Input.is_action_just_pressed(interact_action):
		if save() and use_cutscene:
			_play_cutscene()

## Writes the slot. Returns false if SaveManager could not write the file.
func save() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		if refill_health_on_save and player.has_method("restore_health_full"):
			player.restore_health_full()
		if refill_missiles_on_save and player.has_method("restore_missiles"):
			player.restore_missiles(player.missile_max_ammo)
	var ok := SaveManager.save_game(save_id)
	if ok:
		AudioManager.play_sfx_2d(sfx_saved, global_position)
		if not use_cutscene:
			NotificationManager.show_notification(notification_title, notification_message, null, false, true, notification_seconds)
		saved.emit()
	else:
		NotificationManager.show_notification("SAVE FAILED", "Your progress could not be saved.", null, false, true, notification_seconds)
	if debug_enabled:
		print_debug("[SavePoint] ", save_id, " saved: ", ok)
	return ok

func _play_cutscene() -> void:
	_busy = true
	get_tree().paused = true
	await _cutscene.play_animation(global_position)
	var id := NotificationManager.show_notification(notification_title, notification_message, null, true)
	await NotificationManager.wait_until_dismissed(id)
	_cutscene.finish()
	get_tree().paused = false
	_busy = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		set_physics_process(true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		set_physics_process(false)
