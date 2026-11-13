extends Control

class_name MissionCompleteScreen

## Shown after the final objective: MISSION SUCCEEDED, CONTINUE EXPLORING / RETURN TO TITLE. It only
## presents the result and hands the choices to the existing systems: SaveManager (continue_game) and
## SceneTransition. Mirrors GameOverScreen.
##
## CONTINUE EXPLORING reloads the saved level like TRY AGAIN does (the player resumes at the last save
## point, with the boss still defeated and game_completed still set). It is unavailable if no slot exists.
##
## Keys: up/down (arrows, W/S, D-pad, left stick) move, ui_accept (Enter, Space, A) confirms.
## The "fade_in" animation (optional) plays on entry; input is ignored until it ends.

const MAIN_MENU_SCENE := "res://Scenes/UI/main_menu.tscn"
const FADE_IN := &"fade_in"
const SELECTED_COLOR := Color(1.0, 0.85, 0.3)
const NORMAL_COLOR := Color(1.0, 1.0, 1.0)
const DISABLED_COLOR := Color(0.4, 0.4, 0.4)

enum Option { CONTINUE_EXPLORING, RETURN_TO_TITLE }

@onready var _labels: Array[Label] = [$Options/Menu/ContinueExploring, $Options/Menu/ReturnToTitle]
@onready var _save_status: Label = $SaveStatus
@onready var _animation_player: AnimationPlayer = $AnimationPlayer

var _index: int = 0
var _accepting_input: bool = false
## Set once an action has started, so repeated confirmations cannot start a second one.
var _busy: bool = false

func _ready() -> void:
	get_tree().paused = false  # never leave the game paused after the sequence
	MissionManager.finish_sequence()
	for label in _labels:
		label.set_meta(&"base_text", label.text)
	_save_status.visible = not MissionManager.save_succeeded
	if not _is_enabled(Option.CONTINUE_EXPLORING):
		_index = Option.RETURN_TO_TITLE
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
		_move(1)
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"up"):
		_move(-1)
	elif event.is_action_pressed(&"ui_accept"):
		_activate()
	else:
		return
	get_viewport().set_input_as_handled()

func _is_enabled(option: int) -> bool:
	# Continuing needs a slot to reload; it is missing only if saving the completion failed.
	return option != Option.CONTINUE_EXPLORING or SaveManager.has_save()

func _move(step: int) -> void:
	for i in _labels.size():
		var next := posmod(_index + step * (i + 1), _labels.size())
		if _is_enabled(next):
			_index = next
			break
	_refresh()

func _refresh() -> void:
	for i in _labels.size():
		var text: String = _labels[i].get_meta(&"base_text")
		_labels[i].text = "> %s <" % text if i == _index else text
		if not _is_enabled(i):
			_labels[i].modulate = DISABLED_COLOR
		else:
			_labels[i].modulate = SELECTED_COLOR if i == _index else NORMAL_COLOR

func _activate() -> void:
	if not _is_enabled(_index):
		return
	_busy = true
	match _index:
		Option.CONTINUE_EXPLORING:
			var result: Variant = await SceneTransition.transition(SaveManager.continue_game)
			# Only reached while this screen is alive, i.e. when nothing could be loaded.
			_busy = false
			push_warning("[MissionCompleteScreen] Continue did not start (result: %s)." % str(result))
		Option.RETURN_TO_TITLE:
			await SceneTransition.change_scene(MAIN_MENU_SCENE)
			_busy = false
