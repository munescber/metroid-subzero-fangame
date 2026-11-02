extends Node

## Autoload "AudioManager". Central sound-effect playback using reusable player pools.
## Playback is independent of the caller's lifecycle, so a node may request a sound
## and free itself immediately.
##
## Usage:
##   AudioManager.play_sfx(stream)                       # non-positional, SFX bus
##   AudioManager.play_sfx_2d(stream, global_position)   # positional, SFX bus
##   AudioManager.play_ui(stream)                        # non-positional, UI bus
## Optional args: volume_db, pitch_scale, bus.

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"

## Players created up front per pool; pools grow on demand beyond this.
const INITIAL_POOL_SIZE := 8
## Hard cap per pool so runaway spam cannot create unbounded nodes.
const MAX_POOL_SIZE := 64

var _players: Array[AudioStreamPlayer] = []
var _players_2d: Array[AudioStreamPlayer2D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in INITIAL_POOL_SIZE:
		_players.append(_make_player())
		_players_2d.append(_make_player_2d())

## Plays a non-positional sound. Returns the player used, or null if skipped.
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0, bus: StringName = BUS_SFX) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player: AudioStreamPlayer = _acquire(_players, _make_player)
	if player == null:
		return null
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.bus = _valid_bus(bus)
	player.play()
	return player

## Plays a positional sound at a world position. Returns the player used, or null if skipped.
func play_sfx_2d(stream: AudioStream, world_position: Vector2, volume_db: float = 0.0, pitch_scale: float = 1.0, bus: StringName = BUS_SFX) -> AudioStreamPlayer2D:
	if stream == null:
		return null
	var player: AudioStreamPlayer2D = _acquire(_players_2d, _make_player_2d)
	if player == null:
		return null
	player.stream = stream
	player.global_position = world_position
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.bus = _valid_bus(bus)
	player.play()
	return player

## Convenience for interface sounds (UI bus).
func play_ui(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	return play_sfx(stream, volume_db, pitch_scale, BUS_UI)

## Stops everything currently playing from the pools.
func stop_all() -> void:
	for p in _players:
		p.stop()
	for p in _players_2d:
		p.stop()

# Returns an idle player from the pool, growing it if needed. Never steals a playing one.
func _acquire(pool: Array, factory: Callable):
	for p in pool:
		if not p.playing:
			return p
	if pool.size() >= MAX_POOL_SIZE:
		push_warning("AudioManager: pool exhausted (%d), sound skipped" % MAX_POOL_SIZE)
		return null
	var created = factory.call()
	pool.append(created)
	return created

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = BUS_SFX
	add_child(p)
	return p

func _make_player_2d() -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.bus = BUS_SFX
	add_child(p)
	return p

func _valid_bus(bus: StringName) -> StringName:
	if AudioServer.get_bus_index(bus) == -1:
		push_warning("AudioManager: unknown bus '%s', using Master" % bus)
		return BUS_MASTER
	return bus
