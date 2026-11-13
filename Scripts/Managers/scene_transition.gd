extends CanvasLayer

## Autoload "SceneTransition". A black fade that sits above every other CanvasLayer and survives scene
## changes, so a screen can ask for "fade out, switch, fade in" and be freed in the middle of it.
##
## Use transition(action): it fades to black, awaits `action` (which must do the scene switch, and may
## be a coroutine), waits for the new scene to settle, then fades back in. It returns whatever
## `action` returned, or null if another transition is already running. A caller that was freed by the
## scene switch never sees the return value; one that is still alive (the action failed) does.
##
##   SceneTransition.change_scene("res://Scenes/UI/main_menu.tscn")
##   var ok = await SceneTransition.transition(SaveManager.continue_game)
##
## It does not touch cameras, rooms or other UI; it only draws one ColorRect. Input is not blocked, so
## screens guard against double input themselves.

const FADE_SECONDS := 0.3
## Frames to wait after the switch before fading in (the new scene is added the next frame).
const SETTLE_FRAMES := 2

var _rect: ColorRect
var _running: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

func is_running() -> bool:
	return _running

func fade_out(seconds: float = FADE_SECONDS) -> void:
	await _fade_to(1.0, seconds)

func fade_in(seconds: float = FADE_SECONDS) -> void:
	await _fade_to(0.0, seconds)

## Fade out, run `action`, fade in. See the class comment.
func transition(action: Callable) -> Variant:
	if _running:
		return null
	_running = true
	await fade_out()
	var result: Variant = await action.call()
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await fade_in()
	_running = false
	return result

## transition() for a plain scene switch. Returns the Error of change_scene_to_file.
func change_scene(path: String) -> Variant:
	return await transition(func() -> Error: return get_tree().change_scene_to_file(path))

func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", alpha, seconds)
	await tween.finished
