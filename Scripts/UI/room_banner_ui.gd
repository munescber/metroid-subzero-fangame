extends CanvasLayer

class_name RoomBannerUI

## The room banner: a thin black bar with a yellow bottom border and a yellow title that slides down
## from the top of the screen, holds, and slides back up. It only draws and never touches input or the
## pause state (every Control ignores the mouse). It sits on layer 20: above the HUD, below the
## Notification window and the CRT filter. It uses the default process mode, so it freezes with the
## game when paused.

const BAR_HEIGHT: float = 16.0
const ENTER_SECONDS: float = 0.2
const HOLD_SECONDS: float = 2.5
const EXIT_SECONDS: float = 0.15

@onready var _bar: Control = %Bar
@onready var _title: Label = %Title

## Distance in pixels between the top of the screen and the top of the bar while the banner is shown.
## 0 = flush with the top edge. The slide still starts and ends fully off-screen.
@export var shown_y: float = 0.0

var _tween: Tween
var _showing: bool = false

func _ready() -> void:
	_set_y(-BAR_HEIGHT)
	visible = false

## True from the start of the slide-in until the slide-out begins.
func is_showing() -> bool:
	return _showing

## Slides in, holds and slides out. A banner that is already visible is replaced: the title changes
## at once and the slide-in continues from the bar's current position. An empty title hides it.
func show_banner(title: String) -> void:
	if title.is_empty():
		hide_banner()
		return
	_kill_tween()
	_title.text = title
	visible = true
	_showing = true
	_tween = create_tween()
	_tween.tween_method(_set_y, _bar.offset_top, shown_y, ENTER_SECONDS)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_callback(func() -> void: _showing = false)
	_tween.tween_method(_set_y, shown_y, -BAR_HEIGHT, EXIT_SECONDS)
	_tween.tween_callback(_finish)

## Slides a visible banner out. Does nothing when the banner is idle.
func hide_banner() -> void:
	_kill_tween()
	_showing = false
	if not visible:
		return
	_tween = create_tween()
	_tween.tween_method(_set_y, _bar.offset_top, -BAR_HEIGHT, EXIT_SECONDS)
	_tween.tween_callback(_finish)

func _finish() -> void:
	visible = false

func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null

# Rounded so the bar always sits on whole pixels. The offsets are set directly (not `position`) so
# the bar keeps its 16 px height whatever its cached size is.
func _set_y(value: float) -> void:
	var y := roundf(value)
	_bar.offset_top = y
	_bar.offset_bottom = y + BAR_HEIGHT
