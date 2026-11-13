extends Area2D

class_name Pickup

## Base for collectible items. Detects the player (PlayerBody layer) and collects
## once. Overlaps are re-checked every physics frame, so an item that is refused
## (e.g. refill while missiles are locked) is collected as soon as it is accepted.
##
## Items placed by hand in a level persist. Items spawned by DropManager call
## start_drop_behavior(): a small hop, then a timed blink-and-despawn.

## Seconds a dropped item stays before it despawns.
@export_range(1.0, 60.0, 0.5, "or_greater") var drop_lifetime: float = 8.0
## Seconds before despawn during which a dropped item blinks.
@export_range(0.0, 10.0, 0.1, "or_greater") var blink_duration: float = 2.0
## Height in pixels of the hop when a drop spawns.
@export var pop_height: float = 16.0

## Stable id for a hand-placed item that must stay collected after saving. Leave empty for items
## that are not part of the level's progress (drops use none).
@export var save_id: String = ""

## Sound played (via AudioManager, so it outlives the pickup) on a successful collection.
## Leave empty for silence.
@export var pickup_sound: AudioStream
## Audio bus the pickup sound plays on.
@export var pickup_bus: StringName = &"SFX"

## Whether the player's charge beam pulls this item in. Off by default; refills
## and health turn it on, progression items (expansions) stay put.
@export var magnet_enabled: bool = false
## Distance in pixels within which the charge beam attracts this item.
@export_range(0.0, 256.0, 1.0, "or_greater") var magnet_radius: float = 80.0
## Speed in pixels per second at which the item moves toward the player.
@export_range(0.0, 600.0, 1.0, "or_greater") var magnet_speed: float = 128.0

## Whether collecting this item shows a NotificationManager notification (items that have one).
@export var show_notification: bool = true

var _collected: bool = false
var _player: Node2D = null
var _hop_tween: Tween = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # PlayerBody
	monitoring = true
	if save_id != "":
		add_to_group("saveable")
	# Pickups with an AnimatedSprite2D loop its "default" animation while in the field.
	var animated_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite:
		animated_sprite.play("default")

func _physics_process(delta: float) -> void:
	if _collected:
		return
	if magnet_enabled:
		_apply_magnet(delta)
	for body in get_overlapping_bodies():
		if _try_collect(body):
			_collected = true
			if save_id != "":
				SaveManager.set_flag(save_id, {"collected": true})
			queue_free()
			return

# Pulls toward the player while they charge the beam and are within magnet_radius.
# Skipped during the drop hop so the two position tweens don't fight.
func _apply_magnet(delta: float) -> void:
	if _hop_tween and _hop_tween.is_running():
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	if not _player.has_method("attracts_pickups") or not _player.attracts_pickups():
		return
	if global_position.distance_to(_player.global_position) > magnet_radius:
		return
	global_position = global_position.move_toward(_player.global_position, magnet_speed * delta)

## A collected item removes itself, so it reports through SaveManager.set_flag() instead.
func get_save_data() -> Dictionary:
	return {}

func load_save_data(data: Dictionary) -> void:
	if data.get("collected", false):
		queue_free()

## Apply the effect to the body. Return true if the item was absorbed.
func _try_collect(_body: Node) -> bool:
	return false

## Plays pickup_sound at the pickup's position through the AudioManager, on `pickup_bus`.
func _play_pickup_sound() -> void:
	AudioManager.play_sfx_2d(pickup_sound, global_position, 0.0, 1.0, pickup_bus)

## Shows a pausing notification that the player closes with any key, using this item's sprite as
## the icon. Does nothing when `show_notification` is off.
func _notify(title: String, message: String) -> void:
	if not show_notification:
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	NotificationManager.show_notification(title, message, sprite.texture if sprite else null, true)

## Hop animation plus despawn timer for enemy drops. Call after entering the tree
## and positioning the item.
func start_drop_behavior() -> void:
	var base_y := position.y
	var hop := create_tween()
	_hop_tween = hop
	hop.tween_property(self, "position:y", base_y - pop_height, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(self, "position:y", base_y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	var life := create_tween()
	var solid_time := maxf(drop_lifetime - blink_duration, 0.0)
	life.tween_interval(solid_time)
	var blink_time := minf(blink_duration, drop_lifetime)
	var blinks := int(blink_time / 0.2)
	for i in blinks:
		life.tween_property(self, "modulate:a", 0.25, 0.1)
		life.tween_property(self, "modulate:a", 1.0, 0.1)
	life.tween_callback(queue_free)
