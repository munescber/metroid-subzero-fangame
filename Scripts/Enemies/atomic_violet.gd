extends CharacterBody2D

class_name AtomicViolet

# Stationary ranged variant of Atomic. It never moves; the floating look comes from the sprite animation.

enum State {
	IDLE,
	CHARGING,
	FIRING,
	COOLDOWN,
	DEAD
}

var current_state: State = State.IDLE

@export var max_health: int = 10
@export var contact_damage: int = 2
@export var death_duration: float = 0.5
## Optional drop override; empty uses the default DropManager table.
@export var drop_table: DropTable
@export var debug_enabled: bool = false

@export_category("Attack")
## The player must be within this distance for an attack to start (and to keep charging).
@export var detection_radius: float = 160.0
## Seconds between the end of a shot and the enemy looking for its next target.
@export var attack_cooldown: float = 2.0
## Seconds spent winding up. The player's position is captured when this ends.
@export var charge_duration: float = 0.8
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 180.0
@export var projectile_damage: int = 3
@export var projectile_lifetime: float = 2.5

@export_category("Visual")
## Animation played while charging. Empty reuses the floating animation with a tint pulse.
@export var charge_animation: StringName = &""
@export var idle_animation: StringName = &"default"
@export var charge_tint: Color = Color(1.0, 0.45, 1.0, 1.0)
## Colour and size of the glow drawn behind the sprite while charging.
@export var charge_halo_color: Color = Color(0.85, 0.4, 1.0, 1.0)
@export var charge_halo_radius: float = 22.0
## Extra sprite scale at the peak of a pulse, at full charge.
@export var charge_scale_pulse: float = 0.2

@export_group("Sounds")
## Loops while the attack is charging; stops when the shot fires or the charge is cancelled.
@export var sfx_charge_loop: AudioStream
## Played once when the projectile is fired.
@export var sfx_shoot: AudioStream
@export_group("")

var _charge_loop_player: AudioStreamPlayer2D

const FLASH_COLOR := Color(1, 0.5, 0.5, 1)
const FLASH_DURATION := 0.12

var is_dying: bool = false
var death_timer: float = 0.0

var player: Node2D = null
var state_timer: float = 0.0
var target_position: Vector2 = Vector2.ZERO

@onready var health_comp: HealthComponent = $HealthComponent
@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var contact_damage_area: Area2D = $ContactDamage
@onready var damage_flash_timer: Timer = $DamageFlashTimer


func _ready() -> void:
	health_comp.max_health = max_health
	health_comp.current_health = max_health
	health_comp.connect("damaged", Callable(self, "_on_health_damaged"))
	health_comp.connect("died", Callable(self, "_on_health_died"))
	damage_flash_timer.connect("timeout", Callable(self, "_on_damage_flash_timer_timeout"))

	collision_layer = 4  # EnemyBody
	collision_mask = 1   # World only

	hurtbox.collision_layer = 16  # Hurtbox
	hurtbox.collision_mask = 8    # Hitbox

	contact_damage_area.damage = contact_damage
	contact_damage_area.source = self

	player = _find_player()
	animated_sprite.play(idle_animation)


func _physics_process(delta: float) -> void:
	if is_dying:
		death_timer += delta
		animated_sprite.modulate.a = lerp(1.0, 0.0, death_timer / death_duration)
		if death_timer >= death_duration:
			queue_free()
		return

	if debug_enabled:
		queue_redraw()

	match current_state:
		State.IDLE:
			_update_idle()
		State.CHARGING:
			_update_charging(delta)
		State.FIRING:
			_update_firing()
		State.COOLDOWN:
			_update_cooldown(delta)


func _draw() -> void:
	# Charge telegraph: a pulsing halo behind the sprite that grows and brightens as the charge builds
	if current_state == State.CHARGING:
		var progress := clampf(state_timer / charge_duration, 0.0, 1.0)
		var pulse := _charge_pulse(progress)
		for i in 3:
			var ring := 1.0 - i * 0.25
			var alpha := (0.15 + 0.35 * progress) * (0.5 + 0.5 * pulse) * (i + 1) / 3.0
			draw_circle(Vector2.ZERO, charge_halo_radius * (0.6 + 0.6 * progress) * ring, Color(charge_halo_color, alpha))
	if not debug_enabled:
		return
	draw_arc(Vector2.ZERO, detection_radius, 0.0, TAU, 48, Color(0.8, 0.3, 1.0, 0.6), 2.0)


# ==============================================================================
# ATTACK CYCLE
# ==============================================================================

# The player joins the "player" group in its own _ready(), so this can come back empty
# if the enemy readies first; the lookup is retried while it is missing.
func _find_player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _player_in_range() -> bool:
	if not is_instance_valid(player):
		player = _find_player()
	if not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) <= detection_radius


func _update_idle() -> void:
	if _player_in_range():
		_transition_to_state(State.CHARGING)


func _update_charging(delta: float) -> void:
	if not _player_in_range():
		if debug_enabled:
			print_debug("[AtomicViolet] Player left range, charge cancelled")
		_transition_to_state(State.IDLE)
		return

	state_timer += delta
	var progress := clampf(state_timer / charge_duration, 0.0, 1.0)
	var pulse := _charge_pulse(progress)
	if charge_animation == &"":
		animated_sprite.modulate = Color.WHITE.lerp(charge_tint, progress * (0.5 + 0.5 * pulse))
	visuals.scale = Vector2.ONE * (1.0 + charge_scale_pulse * progress * pulse)
	queue_redraw()

	if state_timer >= charge_duration:
		# The attack is committed here: the aim point is locked and never updated afterwards
		target_position = player.global_position
		_transition_to_state(State.FIRING)


# 0..1 wave that pulses faster the closer the charge is to completing
func _charge_pulse(progress: float) -> float:
	return 0.5 + 0.5 * sin(state_timer * TAU * lerpf(2.0, 6.0, progress))


func _update_firing() -> void:
	_fire_projectile()
	_transition_to_state(State.COOLDOWN)


func _update_cooldown(delta: float) -> void:
	state_timer += delta
	if state_timer >= attack_cooldown:
		_transition_to_state(State.IDLE)


func _fire_projectile() -> void:
	if projectile_scene == null:
		push_warning("AtomicViolet: projectile_scene is not set, nothing to fire")
		return
	var projectile := projectile_scene.instantiate() as Node2D
	var direction := (target_position - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	projectile.call("launch", direction, projectile_speed, projectile_damage, projectile_lifetime, self)
	AudioManager.play_sfx_2d(sfx_shoot, global_position)
	if debug_enabled:
		print_debug("[AtomicViolet] Fired toward ", target_position)


func _transition_to_state(new_state: State) -> void:
	if debug_enabled:
		print_debug("[AtomicViolet] State transition: %s → %s" % [State.keys()[current_state], State.keys()[new_state]])

	current_state = new_state
	state_timer = 0.0
	visuals.scale = Vector2.ONE
	queue_redraw()

	_update_charge_loop(new_state == State.CHARGING)

	match new_state:
		State.CHARGING:
			if charge_animation != &"":
				animated_sprite.play(charge_animation)
		State.IDLE, State.COOLDOWN:
			animated_sprite.modulate = Color.WHITE
			if animated_sprite.animation != idle_animation:
				animated_sprite.play(idle_animation)


func _update_charge_loop(active: bool) -> void:
	if not active:
		if _charge_loop_player:
			_charge_loop_player.stop()
		return
	if sfx_charge_loop == null:
		return
	if _charge_loop_player == null:
		_charge_loop_player = AudioStreamPlayer2D.new()
		_charge_loop_player.bus = AudioManager.BUS_SFX
		# restart on finish so it loops even if the imported stream has looping off
		_charge_loop_player.finished.connect(_on_charge_loop_finished)
		add_child(_charge_loop_player)
	_charge_loop_player.stream = sfx_charge_loop
	_charge_loop_player.play()


func _on_charge_loop_finished() -> void:
	if current_state == State.CHARGING:
		_charge_loop_player.play()


# ==============================================================================
# DAMAGE & DEATH
# ==============================================================================

func take_damage(amount: int, source = null) -> void:
	if current_state == State.DEAD:
		return
	if debug_enabled:
		print_debug("[AtomicViolet] Taking damage: ", amount, " from source: ", source)
	health_comp.take_damage(amount, source)


func _on_health_damaged(amount: int, new_health: int) -> void:
	if debug_enabled:
		print_debug("[AtomicViolet] Took damage: ", amount, " | Health: ", new_health, "/", max_health)
	animated_sprite.modulate = FLASH_COLOR
	damage_flash_timer.start(FLASH_DURATION)


func _on_damage_flash_timer_timeout() -> void:
	animated_sprite.modulate = Color.WHITE


func _on_health_died() -> void:
	DropManager.try_drop(self, drop_table)
	if debug_enabled:
		print_debug("[AtomicViolet] Defeated!")
	current_state = State.DEAD
	_update_charge_loop(false)
	is_dying = true
	death_timer = 0.0
	visuals.scale = Vector2.ONE
	queue_redraw()

	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
		elif child is Area2D:
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)
