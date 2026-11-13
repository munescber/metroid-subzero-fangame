extends Node

## Autoload "RoomBannerManager". Shows the room banner when the player enters a room whose
## `RoomRegion.banner_title` is not empty. RoomManager never references the UI: every frame this
## autoload looks for RoomManagers (group `room_manager`) it has not met yet and connects to their
## `room_entered` signal, so it works for whichever level is loaded, now or later, and after scene
## reloads. A newly met manager that is already in a room is handled at once, so a start-room signal
## that fired before the connection is not lost.
##
## Independent of NotificationManager: no queue, no pause, no input. The banner freezes if the game
## pauses.

const UI_SCENE: PackedScene = preload("res://Scenes/UI/room_banner.tscn")
const MANAGER_GROUP := &"room_manager"

var _ui: RoomBannerUI
## Region of the banner on screen, so a second `room_entered` for the same room (start room followed
## by the warp after loading a save) does not restart the animation.
var _region_id: int = 0

func _ready() -> void:
	_ui = UI_SCENE.instantiate() as RoomBannerUI
	add_child(_ui)

func _process(_delta: float) -> void:
	for node in get_tree().get_nodes_in_group(MANAGER_GROUP):
		if not node.is_connected(&"room_entered", _on_room_entered):
			_connect_manager(node)

## Shows `title` (slide in, hold, slide out), replacing any banner on screen. An empty title slides
## the visible banner out instead.
func show_banner(title: String) -> void:
	_region_id = 0
	_ui.show_banner(title)

## Slides out the visible banner, if any.
func hide_banner() -> void:
	_region_id = 0
	_ui.hide_banner()

func _connect_manager(node: Node) -> void:
	node.connect(&"room_entered", _on_room_entered)
	var region: RoomRegion = node.get("active_region")
	if region != null:
		_on_room_entered(region)

func _on_room_entered(region: RoomRegion) -> void:
	var id := region.get_instance_id()
	if id == _region_id and _ui.is_showing():
		return
	show_banner(region.banner_title)
	_region_id = id if not region.banner_title.is_empty() else 0
