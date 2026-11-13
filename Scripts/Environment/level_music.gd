extends Node

class_name LevelMusic

## Starts looping background music for the level through the AudioManager.
## Rooms that share the same track continue it seamlessly across scene changes.

## Leave empty for silence (stops any music already playing).
@export var music: AudioStream
@export var volume_db: float = 0.0


func _ready() -> void:
	AudioManager.play_music(music, volume_db)
