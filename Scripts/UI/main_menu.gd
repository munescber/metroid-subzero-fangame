extends Control

class_name MainMenu

## START GAME / CONTINUE / QUIT. It only decides which action to run and hands it to the existing
## systems: SaveManager (save detection, new game, continue) and SceneTransition (fade).
##
## Keys: up/down (arrows, W/S, D-pad, left stick) move, ui_accept (Enter, Space, A) confirms,
## ui_cancel (Esc, B) backs out of the overwrite question. Disabled entries are skipped. The mouse is
## not used.
##
## With a save present, START GAME first asks "overwrite?" (CANCEL / NEW GAME), a second list handled by
## the same selection code.

const SELECTED_COLOR := Color(1.0, 0.85, 0.3)
const NORMAL_COLOR := Color(1.0, 1.0, 1.0)
const DISABLED_COLOR := Color(0.35, 0.35, 0.35)

enum Option { START_GAME, CONTINUE, QUIT }
enum Confirm { CANCEL, NEW_GAME }

## Where START GAME begins.
@export_file("*.tscn") var new_game_scene: String = SaveManager.NEW_GAME_SCENE

@onready var _options_box: Control = $MenuCenter
@onready var _confirm_box: Control = $ConfirmCenter
@onready var _option_labels: Array[Label] = [
	$MenuCenter/Options/StartGame, $MenuCenter/Options/Continue, $MenuCenter/Options/Quit]
@onready var _confirm_labels: Array[Label] = [
	$ConfirmCenter/Confirm/Cancel, $ConfirmCenter/Confirm/NewGame]

## The list being navigated (the options, or the overwrite question) and its enabled flags.
var _labels: Array[Label] = []
var _enabled: Array[bool] = []
var _in_confirm: bool = false
var _index: int = 0
## Set once an action has started, so nothing can start a second one.
var _busy: bool = false
var _continue_available: bool = false

func _ready() -> void:
	add_to_group(SaveManager.MENU_SCREEN_GROUP)
	for label in _option_labels + _confirm_labels:
		label.set_meta(&"base_text", label.text)
	_continue_available = SaveManager.has_save()
	_show_list(false)

func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"down"):
		_move(1)
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"up"):
		_move(-1)
	elif event.is_action_pressed(&"ui_accept"):
		_activate()
	elif event.is_action_pressed(&"ui_cancel") and _in_confirm:
		_show_list(false)
	else:
		return
	get_viewport().set_input_as_handled()

## Shows the options (`confirm` false) or the overwrite question and selects the first enabled entry.
func _show_list(confirm: bool) -> void:
	_in_confirm = confirm
	_options_box.visible = not confirm
	_confirm_box.visible = confirm
	if confirm:
		_labels = _confirm_labels
		_enabled = [true, true]
		_index = Confirm.CANCEL  # the safe answer is the default
	else:
		_labels = _option_labels
		_enabled = [true, _continue_available, true]
		_index = Option.START_GAME
	_refresh()

func _move(step: int) -> void:
	var count := _labels.size()
	for i in count:
		var candidate := posmod(_index + step * (i + 1), count)
		if _enabled[candidate]:
			_index = candidate
			break
	_refresh()

func _refresh() -> void:
	for i in _labels.size():
		var label := _labels[i]
		var text: String = label.get_meta(&"base_text")
		if not _enabled[i]:
			label.text = text
			label.modulate = DISABLED_COLOR
		elif i == _index:
			label.text = "> %s <" % text
			label.modulate = SELECTED_COLOR
		else:
			label.text = text
			label.modulate = NORMAL_COLOR

func _activate() -> void:
	if not _enabled[_index]:
		return
	if _in_confirm:
		if _index == Confirm.NEW_GAME:
			_start_new_game()
		else:
			_show_list(false)
		return
	match _index:
		Option.START_GAME:
			if SaveManager.has_save():
				_show_list(true)
			else:
				_start_new_game()
		Option.CONTINUE:
			_continue_game()
		Option.QUIT:
			_busy = true
			get_tree().quit()

func _start_new_game() -> void:
	_busy = true
	var result: Variant = await SceneTransition.transition(SaveManager.start_new_game.bind(new_game_scene))
	# Only reached while the menu is still alive, i.e. when the new game could not start.
	_busy = false
	push_warning("[MainMenu] New game did not start (result: %s)." % str(result))

func _continue_game() -> void:
	_busy = true
	var result: Variant = await SceneTransition.transition(SaveManager.continue_game)
	# Only reached while the menu is still alive: the slot was unusable, so it is no longer offered.
	_busy = false
	if result == false:
		_continue_available = false
		_show_list(false)
