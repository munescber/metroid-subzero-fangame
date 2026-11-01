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

var _collected: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # PlayerBody
	monitoring = true
	# Pickups with an AnimatedSprite2D loop its "default" animation while in the field.
	var animated_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite:
		animated_sprite.play("default")

func _physics_process(_delta: float) -> void:
	if _collected:
		return
	for body in get_overlapping_bodies():
		if _try_collect(body):
			_collected = true
			queue_free()
			return

## Apply the effect to the body. Return true if the item was absorbed.
func _try_collect(_body: Node) -> bool:
	return false

## Hop animation plus despawn timer for enemy drops. Call after entering the tree
## and positioning the item.
func start_drop_behavior() -> void:
	var base_y := position.y
	var hop := create_tween()
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
