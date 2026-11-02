extends CanvasLayer

class_name HUD

## Read-only display of the player's health and missile ammo. It never writes to
## the player; it only listens to its signals. By default it binds to its parent
## (the HUD is instanced inside player.tscn, so it persists across rooms).

@export var debug_enabled: bool = false

@onready var health_label: Label = %HealthLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var missile_panel: Control = %MissilePanel
@onready var missile_label: Label = %MissileLabel
@onready var missile_bar: ProgressBar = %MissileBar

var _player: Node = null


func _ready() -> void:
	missile_panel.visible = false
	var parent := get_parent()
	if parent and parent.has_signal("health_changed"):
		# Parent's _ready runs after ours; wait so health_comp exists.
		bind_player.call_deferred(parent)


func _exit_tree() -> void:
	_unbind()


## Connects to the player's signals and initialises the display from its current state.
func bind_player(player: Node) -> void:
	_unbind()
	if player == null or not is_instance_valid(player):
		return
	_player = player
	_connect_once(player.health_changed, _on_health_changed)
	_connect_once(player.missiles_changed, _on_missiles_changed)
	_connect_once(player.missiles_acquired, _on_missiles_acquired)

	var health_comp = player.get("health_comp")
	if health_comp:
		_on_health_changed(health_comp.current_health, health_comp.max_health)
	_on_missiles_changed(player.missile_ammo, player.missile_max_ammo)
	missile_panel.visible = player.missiles_unlocked


func _unbind() -> void:
	if _player and is_instance_valid(_player):
		_disconnect_if(_player.health_changed, _on_health_changed)
		_disconnect_if(_player.missiles_changed, _on_missiles_changed)
		_disconnect_if(_player.missiles_acquired, _on_missiles_acquired)
	_player = null


func _connect_once(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)


func _disconnect_if(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_health_changed(current_hp: int, max_hp: int) -> void:
	health_label.text = "HP %d/%d" % [current_hp, max_hp]
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	if debug_enabled:
		print_debug("[HUD] health %d/%d" % [current_hp, max_hp])


func _on_missiles_changed(current_ammo: int, max_ammo: int) -> void:
	missile_label.text = "MSL %d/%d" % [current_ammo, max_ammo]
	missile_bar.max_value = maxi(max_ammo, 1)
	missile_bar.value = current_ammo


func _on_missiles_acquired() -> void:
	missile_panel.visible = true
