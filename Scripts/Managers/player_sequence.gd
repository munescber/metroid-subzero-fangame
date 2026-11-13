extends Node

## Autoload "PlayerSequence". The short front-facing "presentation" of the player:
##   MISSION_START    full intro cue, after a new game, Continue, or loading a save
##   MISSION_CONTINUE short sting, after dying and respawning at the save point
## Both share one flow: lock the player and show PRESENT_ANIM (Player.begin_presentation), play the cue
## through AudioManager.play_jingle (background music keeps running, only ducked), wait, then hand the
## player back (Player.end_presentation). Nothing here moves the player or touches the save.
##
## Triggers (all in SaveManager; room transitions never queue anything):
##   queue(type)                  right before the scene is switched; waits for the new level, its player
##                                and the end of the SceneTransition fade, then plays.
##   queue(type, false)           same, for a level that is already running (continue_from_save).
## A request nobody consumes (the scene switch failed) expires after QUEUE_TIMEOUT seconds.
##
## Assets (optional; missing ones are skipped with a warning, the timing still runs):
##   Audio/Music/mission_start.ogg     full intro music (any format Godot imports: .ogg/.wav/.mp3)
##   Audio/Music/mission_continue.ogg  short sting, ~1-2 s
##   Player SpriteFrames animation "face_forward" (see Player.PRESENT_ANIM)
## Or assign `start_stream` / `continue_stream` from code.

signal sequence_started(type: int)
signal sequence_finished(type: int)

enum Type { MISSION_START, MISSION_CONTINUE }

const START_STREAM_PATHS: PackedStringArray = [
	"res://Audio/Music/mission_start.ogg", "res://Audio/Music/mission_start.wav", "res://Audio/Music/mission_start.mp3"]
const CONTINUE_STREAM_PATHS: PackedStringArray = [
	"res://Audio/Music/mission_continue.ogg", "res://Audio/Music/mission_continue.wav", "res://Audio/Music/mission_continue.mp3"]

## Seconds the start pose is held when there is no intro cue (with a cue: its length, at least start_min_seconds).
var start_fallback_seconds: float = 3.0
var start_min_seconds: float = 1.5
## The continue pose is brief by design, whatever the sting's length.
var continue_seconds: float = 1.5
const QUEUE_TIMEOUT := 8.0

var start_stream: AudioStream
var continue_stream: AudioStream

var _token: int = 0
var _player: Node = null
var _type: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_stream = _load_first(START_STREAM_PATHS)
	continue_stream = _load_first(CONTINUE_STREAM_PATHS)

## True while a presentation is on screen.
func is_playing() -> bool:
	return _player != null

## Schedules a sequence for the level that is about to load (or, with wait_for_new_scene false, the one
## already running). Replaces any earlier request or running sequence, so two never overlap.
func queue(type: Type, wait_for_new_scene: bool = true) -> void:
	cancel()
	var token := _token
	var scene_before: Node = get_tree().current_scene if wait_for_new_scene else null
	_run_queued(type, token, scene_before)

## Aborts a running or waiting sequence and gives the player back immediately. Safe at any time.
func cancel() -> void:
	_token += 1
	var player := _player
	_player = null
	_type = -1
	if player != null and is_instance_valid(player):
		if player.tree_exiting.is_connected(cancel):
			player.tree_exiting.disconnect(cancel)
		player.end_presentation()
	AudioManager.stop_jingle()

func _run_queued(type: Type, token: int, scene_before: Node) -> void:
	var tree := get_tree()
	var deadline := Time.get_ticks_msec() + int(QUEUE_TIMEOUT * 1000.0)
	var player: Node = null
	while Time.get_ticks_msec() < deadline:
		await tree.process_frame
		if token != _token:
			return
		var scene := tree.current_scene
		if scene == null or scene == scene_before:
			continue  # still the old level (or none yet)
		var candidate := tree.get_first_node_in_group("player")
		if candidate != null and candidate.is_inside_tree() and candidate.has_method("begin_presentation"):
			player = candidate
			break
	if player == null:
		push_warning("[PlayerSequence] No player appeared; skipping the sequence.")
		return
	await _play(type, token, player)

func _play(type: Type, token: int, player: Node) -> void:
	if not player.begin_presentation():
		return
	_player = player
	_type = type
	player.tree_exiting.connect(cancel)  # the level is being left: stop at once
	# Hold still while the screen is black: SaveManager is placing the player, and the fade must be over
	# before the pose and the cue mean anything.
	while SceneTransition.is_running():
		await get_tree().process_frame
		if token != _token:
			return
	var seconds := _start_cue() if type == Type.MISSION_START else _continue_cue()
	sequence_started.emit(type)
	await get_tree().create_timer(seconds).timeout
	if token != _token:
		return  # cancelled; cancel() already restored the player
	var finished_type := _type
	cancel()
	sequence_finished.emit(finished_type)

func _start_cue() -> float:
	var length := AudioManager.play_jingle(start_stream)
	return maxf(length, start_min_seconds) if start_stream != null else start_fallback_seconds

func _continue_cue() -> float:
	AudioManager.play_jingle(continue_stream)
	return continue_seconds

func _load_first(paths: PackedStringArray) -> AudioStream:
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null
