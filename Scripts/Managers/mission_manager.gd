extends Node

## Autoload "MissionManager". The one place that coordinates finishing the game. The final boss or
## objective only calls complete_mission(); it knows nothing about saving or UI scenes.
##
## complete_mission() runs once: freezes the world, saves through SaveManager (save_completed_game),
## lets the player play the victory pose, then moves to the Mission Complete screen.
##
## Three distinct states:
##   player death   -> the player's own _is_dead (is_dead())
##   is_completing  -> the sequence is running (this node, transient)
##   game_completed -> persisted in the save (SaveManager.game_completed)
## Completion is refused while the player is dead or already completing; death handling in the
## player ignores damage and death once the victory has begun.
##
## Usage:  MissionManager.complete_mission()

signal mission_completed

const MISSION_COMPLETE_SCENE := "res://Scenes/UI/mission_complete_screen.tscn"

## True while the sequence runs. MissionCompleteScreen clears it with finish_sequence().
var is_completing: bool = false
## False if the completed state could not be written to the slot (the screen reports it).
var save_succeeded: bool = true

## Returns true if this call started the sequence. Fire and forget: do not await it from a node that
## frees itself (a boss); it lives on this autoload.
func complete_mission() -> bool:
	if is_completing or SaveManager.game_completed:
		return false
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("is_dead") and player.is_dead():
		return false  # death (game over) wins; it has already started
	is_completing = true
	save_succeeded = true
	get_tree().paused = true  # enemies, projectiles, hazards and timers stop; the player and UI keep running
	save_succeeded = SaveManager.save_completed_game()
	if not save_succeeded:
		push_warning("[MissionManager] The completed game could not be saved.")
	mission_completed.emit()
	_run_sequence.call_deferred(player)
	return true

## Called by MissionCompleteScreen once it is showing, so the manager is ready for a later game.
func finish_sequence() -> void:
	is_completing = false

func _run_sequence(player: Node) -> void:
	if player != null and player.has_method("play_victory"):
		await player.play_victory()
		if player.has_method("is_dead") and player.is_dead():
			is_completing = false  # died in the frame before the pose began; game over owns the flow
			return
	await SceneTransition.change_scene(MISSION_COMPLETE_SCENE)
