extends Node

## Autoload "NotificationManager". One notification window for the whole game: any system calls
## show_notification() and the manager queues it, shows it (one at a time), optionally pauses the
## game while it is up and puts the pause state back afterwards.
##
## It runs with PROCESS_MODE_ALWAYS, so queueing, timers and the dismiss input keep working while the
## SceneTree is paused. Blocking notifications close on the first key or joypad button press; that
## press is consumed here, and the window closes with its exit animation before the game resumes, so
## the key that closed it does not also count as a "just pressed" gameplay action.

## Emitted once the entrance animation has finished.
signal notification_shown(id: int)
## Emitted after the exit animation, with the pause state already restored.
signal notification_dismissed(id: int)

const UI_SCENE: PackedScene = preload("res://Scenes/UI/notification.tscn")
## Seconds after a blocking notification appears during which input is ignored, so the press that
## triggered the pickup or interaction cannot close it at once.
const INPUT_GUARD_SECONDS: float = 0.3

signal _dismiss_requested

var _ui: NotificationUI
var _queue: Array[Dictionary] = []
var _next_id: int = 1
var _running: bool = false
var _waiting_for_input: bool = false
var _input_armed: bool = false
var _holding_pause: bool = false
var _paused_before: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = UI_SCENE.instantiate() as NotificationUI
	add_child(_ui)

## Queues a notification and returns its id (see wait_until_dismissed).
## `pause_game` pauses the tree while it is shown; the previous pause state is restored afterwards.
## `auto_dismiss` closes it after `duration` seconds, otherwise the player closes it with any key.
func show_notification(title: String, message: String, icon: Texture2D = null, pause_game: bool = false, auto_dismiss: bool = false, duration: float = 2.0) -> int:
	var id := _next_id
	_next_id += 1
	_queue.append({
		"id": id,
		"title": title,
		"message": message,
		"icon": icon,
		"pause": pause_game,
		"auto": auto_dismiss,
		"duration": duration,
	})
	if not _running:
		_run_queue()
	return id

## Whether a notification is showing or waiting.
func is_busy() -> bool:
	return _running

## Returns after notification `id` has been dismissed. Call it right after show_notification().
func wait_until_dismissed(id: int) -> void:
	while true:
		var dismissed: int = await notification_dismissed
		if dismissed == id:
			return

func _run_queue() -> void:
	_running = true
	while not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		if item.pause:
			_hold_pause()
		await _ui.present(item.title, item.message, item.icon, not item.auto, item.pause)
		notification_shown.emit(item.id)
		if item.auto:
			await get_tree().create_timer(item.duration, true).timeout
		else:
			await _wait_for_dismiss_input()
		await _ui.dismiss()
		var next_pauses: bool = not _queue.is_empty() and _queue[0].pause
		if _holding_pause and not next_pauses:
			_release_pause()
		notification_dismissed.emit(item.id)
	_running = false

func _wait_for_dismiss_input() -> void:
	_waiting_for_input = true
	_input_armed = false
	get_tree().create_timer(INPUT_GUARD_SECONDS, true).timeout.connect(func() -> void: _input_armed = true)
	await _dismiss_requested
	_waiting_for_input = false

func _input(event: InputEvent) -> void:
	if not _waiting_for_input or not _is_dismiss_event(event):
		return
	get_viewport().set_input_as_handled()
	if _input_armed:
		_input_armed = false
		_dismiss_requested.emit()

func _is_dismiss_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	return event is InputEventJoypadButton and event.pressed

func _hold_pause() -> void:
	if _holding_pause:
		return
	_paused_before = get_tree().paused
	get_tree().paused = true
	_holding_pause = true

func _release_pause() -> void:
	get_tree().paused = _paused_before
	_holding_pause = false
