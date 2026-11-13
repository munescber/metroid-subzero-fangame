extends Control

class_name GameOverScreen

## Shown after the player dies: MISSION FAILED, TRY AGAIN / RETURN TO TITLE. It only presents the two
## choices and hands them to the existing systems: SaveManager (retry_after_death) and SceneTransition.
##
## Keys: up/down (arrows, W/S, D-pad, left stick) move, ui_accept (Enter, Space, A) confirms.
## The "fade_in" animation (optional) plays on entry; input is ignored until it ends.

const MAIN_MENU_SCENE := "res://Scenes/UI/main_menu.tscn"
const FADE_IN := &"fade_in"
const SELECTED_COLOR := Color(1.0, 0.85, 0.3)
const NORMAL_COLOR := Color(1.0, 1.0, 1.0)

enum Option { TRY_AGAIN, RETURN_TO_TITLE }

@onready var _labels: Array[Label] = [$Options/Menu/TryAgain, $Options/Menu/ReturnToTitle]
@onready var _animation_player: AnimationPlayer = $AnimationPlayer

var _index: int = 0
var _accepting_input: bool = false
## Set once an action has started, so repeated confirmations cannot start a second one.
var _busy: bool = false

func _ready() -> void:
	get_tree().paused = false  # never leave the game paused after dying
	for label in _labels:
		label.set_meta(&"base_text", label.text)
	_refresh()
	if _animation_player.has_animation(FADE_IN):
		_animation_player.animation_finished.connect(func(_name: StringName) -> void: _accepting_input = true)
		_animation_player.play(FADE_IN)
	else:
		_accepting_input = true

func _unhandled_input(event: InputEvent) -> void:
	if _busy or not _accepting_input:
		return
	if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"down"):
		_index = posmod(_index + 1, _labels.size())
		_refresh()
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"up"):
		_index = posmod(_index - 1, _labels.size())
		_refresh()
	elif event.is_action_pressed(&"ui_accept"):
		_activate()
	else:
		return
	get_viewport().set_input_as_handled()

func _refresh() -> void:
	for i in _labels.size():
		var text: String = _labels[i].get_meta(&"base_text")
		_labels[i].text = "> %s <" % text if i == _index else text
		_labels[i].modulate = SELECTED_COLOR if i == _index else NORMAL_COLOR

func _activate() -> void:
	_busy = true
	match _index:
		Option.TRY_AGAIN:
			var result: Variant = await SceneTransition.transition(SaveManager.retry_after_death)
			# Only reached while this screen is alive, i.e. when nothing could be loaded.
			_busy = false
			push_warning("[GameOverScreen] Retry did not start (result: %s)." % str(result))
		Option.RETURN_TO_TITLE:
			await SceneTransition.change_scene(MAIN_MENU_SCENE)
			_busy = false
