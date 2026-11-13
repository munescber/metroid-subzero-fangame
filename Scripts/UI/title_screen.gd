extends Node2D

class_name TitleScreen

## The first screen of the game. Plays the "intro" animation by itself, then blinks "PRESS ANY KEY"
## ("blink" animation) and, on the first key or joypad button press, fades to the main menu.
## It knows nothing about saves or gameplay.
##
## Art goes into the nodes of title_screen.tscn; their animation belongs to the AnimationPlayer:
## - "intro": everything that plays once. Input is ignored until it ends. Add tracks for
##   AnimatedBackground, AtmosphericEffects, GameLogo as needed (it currently only fades the logo in).
## - "blink": looping animation of PressAnyKeyLabel, started when the intro ends.
## Both are optional: a missing "intro" shows the prompt at once, a missing "blink" leaves it solid.

const MAIN_MENU_SCENE := "res://Scenes/UI/main_menu.tscn"
const INTRO := &"intro"
const BLINK := &"blink"
## Playback speed that finishes the intro in a single frame, with every track in its end state.
const SKIP_SPEED := 1000.0

## True once the intro has played in this run of the game, so coming back to the title screen later
## shows it already finished.
static var intro_played: bool = false

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _prompt: Label = $PressAnyKeyLabel

var _accepting_input: bool = false
var _leaving: bool = false

func _ready() -> void:
	add_to_group(SaveManager.MENU_SCREEN_GROUP)
	_prompt.visible = false
	if not _animation_player.has_animation(INTRO):
		_show_prompt()
		return
	_animation_player.animation_finished.connect(_on_animation_finished)
	_animation_player.play(INTRO, -1, SKIP_SPEED if intro_played else 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if not _accepting_input or _leaving or not _is_any_key(event):
		return
	_leaving = true
	get_viewport().set_input_as_handled()
	SceneTransition.change_scene(MAIN_MENU_SCENE)

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == INTRO:
		_show_prompt()

func _show_prompt() -> void:
	intro_played = true
	_prompt.visible = true
	if _animation_player.has_animation(BLINK):
		_animation_player.play(BLINK)
	_accepting_input = true

## A fresh key press or joypad button press. Key repeats, releases, stick motion and the mouse do not
## count.
func _is_any_key(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	return event is InputEventJoypadButton and event.pressed
