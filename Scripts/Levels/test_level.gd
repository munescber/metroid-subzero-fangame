extends Node2D

@onready var boil: ColorRect = $FX/boil
@onready var debug_panel: PanelContainer = $HUD/DebugPanel
@onready var toggle_boil: Button = $HUD/DebugPanel/MarginContainer/VBoxContainer/ToggleBoil


func _ready() -> void:
	debug_panel.hide()
	_update_boil_button()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		debug_panel.visible = not debug_panel.visible
		get_viewport().set_input_as_handled()


func _on_toggle_boil_pressed() -> void:
	boil.visible = not boil.visible
	_update_boil_button()


func _update_boil_button() -> void:
	var state := "ENCENDIDO" if boil.visible else "APAGADO"
	toggle_boil.text = "Efecto boil: %s" % state
