extends Area2D

class_name MapPoint

## Stand inside the area and press `interact_action` to obtain the map. The game pauses, the shared
## `Cutscene` (ObtainCutscene) plays, then a notification (NotificationManager) waits for the player
## to dismiss it and the minimap is enabled (MapManager.enable_minimap()). Once the map is obtained
## the point does nothing more.
## Place it in a room; the room's activation turns the area off while the player is elsewhere.
##
## The foreground animation lives in Scenes/Effects/obtain_cutscene.tscn (shared with SavePoint).

signal map_obtained

@export var interact_action: StringName = &"up"
@export var sfx_obtained: AudioStream
@export var notification_title: String = "MAP DATA ACQUIRED"
@export var notification_message: String = "Map data successfully downloaded."
@export var debug_enabled: bool = false

@onready var _cutscene: ObtainCutscene = $Cutscene

var _busy: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # PlayerBody
	add_to_group("map_point")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if _busy:
		return
	if MapManager.minimap_enabled:
		set_physics_process(false)
		return
	if Input.is_action_just_pressed(interact_action) and _player_can_interact():
		_obtain_map()

# Only while standing, so the player is not frozen in mid-air.
func _player_can_interact() -> bool:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	return player != null and player.is_on_floor()

func _obtain_map() -> void:
	_busy = true
	get_tree().paused = true
	AudioManager.play_ui(sfx_obtained)
	await _cutscene.play_animation(global_position)
	MapManager.enable_minimap()
	var id := NotificationManager.show_notification(notification_title, notification_message, null, true)
	await NotificationManager.wait_until_dismissed(id)
	_cutscene.finish()
	get_tree().paused = false
	_busy = false
	if debug_enabled:
		print_debug("[MapPoint] ", name, " map obtained")
	map_obtained.emit()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not MapManager.minimap_enabled:
		set_physics_process(true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		set_physics_process(false)
