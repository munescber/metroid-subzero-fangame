extends CanvasLayer

class_name NotificationUI

## The notification window: black panel, thin yellow border, yellow text. It only draws; queueing,
## pausing and input belong to the NotificationManager autoload. It lives on a CanvasLayer below the
## CRT filter (layer 100) so the filter still covers it, and runs with PROCESS_MODE_ALWAYS so it keeps
## animating while the game is paused.

const SLIDE_PIXELS: float = 8.0
const ENTER_SECONDS: float = 0.18
const EXIT_SECONDS: float = 0.12
## Vertical position of the panel centre as a fraction of the screen height.
const CENTER_Y: float = 0.5
const TOAST_Y: float = 0.8
const FOOTER_BLINK_SECONDS: float = 0.5

@onready var _root: Control = %Root
@onready var _panel: PanelContainer = %Panel
@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _message: Label = %Message
@onready var _footer: Label = %Footer

var _progress: float = 0.0
var _tween: Tween
var _footer_tween: Tween

func _ready() -> void:
	visible = false
	_set_progress(0.0)

## Fills the panel and plays the entrance animation. Returns when it has finished.
## `dismissible` shows the footer. `centered` puts the panel mid-screen, otherwise it sits lower
## so a short toast does not cover the player.
func present(title: String, message: String, icon: Texture2D, dismissible: bool, centered: bool) -> void:
	_title.text = title
	_message.text = message
	_icon.texture = icon
	_icon.visible = icon != null
	_footer.visible = dismissible
	_set_progress(0.0)
	visible = true
	_panel.reset_size()
	# The container needs a couple of frames to settle its size (wrapped text) before it is centred.
	await get_tree().process_frame
	await get_tree().process_frame
	var screen := get_viewport().get_visible_rect().size
	_panel.position = Vector2(
		floorf((screen.x - _panel.size.x) * 0.5),
		floorf(screen.y * (CENTER_Y if centered else TOAST_Y) - _panel.size.y * 0.5))
	await _animate_to(1.0, ENTER_SECONDS)
	if dismissible:
		_start_footer_blink()

## Plays the exit animation and hides the layer. Returns when it has finished.
func dismiss() -> void:
	_stop_footer_blink()
	await _animate_to(0.0, EXIT_SECONDS)
	visible = false

func _animate_to(target: float, seconds: float) -> void:
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_set_progress, _progress, target, seconds)
	await _tween.finished

# 0 = hidden, 1 = fully shown. The slide is rounded so the panel stays on whole pixels.
func _set_progress(value: float) -> void:
	_progress = value
	_root.modulate.a = value
	_root.position.y = roundf((1.0 - value) * SLIDE_PIXELS)

func _start_footer_blink() -> void:
	_stop_footer_blink()
	_footer.modulate.a = 1.0
	_footer_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_loops()
	_footer_tween.tween_interval(FOOTER_BLINK_SECONDS)
	_footer_tween.tween_property(_footer, "modulate:a", 0.3, 0.0)
	_footer_tween.tween_interval(FOOTER_BLINK_SECONDS)
	_footer_tween.tween_property(_footer, "modulate:a", 1.0, 0.0)

func _stop_footer_blink() -> void:
	if _footer_tween != null:
		_footer_tween.kill()
		_footer_tween = null
	_footer.modulate.a = 1.0
