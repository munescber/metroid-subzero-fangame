extends Node

## Autoload "AudioManager". Central sound-effect playback using reusable player pools.
## Playback is independent of the caller's lifecycle, so a node may request a sound
## and free itself immediately.
##
## Usage:
##   AudioManager.play_sfx(stream)                       # non-positional, SFX bus
##   AudioManager.play_sfx_2d(stream, global_position)   # positional, SFX bus
##   AudioManager.play_ui(stream)                        # non-positional, UI bus
##   AudioManager.play_music(stream)                     # looping, Music bus, survives scene changes
##   AudioManager.play_jingle(stream)                    # one-shot cue over the music (ducks it, never restarts it)
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
var _music_player: AudioStreamPlayer
var _jingle_player: AudioStreamPlayer
## True while the background music is lowered under a jingle; _duck_base_db is the volume to restore.
var _ducked: bool = false
var _duck_base_db: float = 0.0

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

## Plays looping background music on the Music bus. The player is owned by this autoload, so
## music carries on across scene changes; asking for the track that is already playing does
## nothing (no restart), and a different track replaces it. Null stops the music.
func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		stop_music()
		return
	_ensure_music_player()
	_music_player.volume_db = volume_db
	_ducked = false  # the caller's volume wins over a running duck
	if _music_player.stream == stream and _music_player.playing:
		return
	if "loop" in stream:
		stream.loop = true
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	_ducked = false
	if _music_player:
		_music_player.stop()
		_music_player.stream = null

## Plays a one-shot musical cue (intro, sting) on the Music bus. The background music is NOT stopped or
## restarted: it is only lowered by duck_db while the cue plays, then restored. One cue at a time; a new
## one replaces the old. Returns the cue's length in seconds (0.0 if the stream is null or has no length).
func play_jingle(stream: AudioStream, volume_db: float = 0.0, duck_db: float = -12.0) -> float:
	stop_jingle()
	if stream == null:
		return 0.0
	if _jingle_player == null:
		_jingle_player = AudioStreamPlayer.new()
		_jingle_player.bus = _valid_bus(BUS_MUSIC)
		_jingle_player.finished.connect(_end_duck)
		add_child(_jingle_player)
	_jingle_player.stream = stream
	_jingle_player.volume_db = volume_db
	if _music_player and _music_player.playing and not _ducked:
		_duck_base_db = _music_player.volume_db
		_music_player.volume_db = _duck_base_db + duck_db
		_ducked = true
	_jingle_player.play()
	return stream.get_length()

## Stops the current cue early (e.g. the scene changed) and brings the background music back up.
func stop_jingle() -> void:
	if _jingle_player and _jingle_player.playing:
		_jingle_player.stop()
	_end_duck()

func _end_duck() -> void:
	if _ducked and _music_player:
		_music_player.volume_db = _duck_base_db
	_ducked = false

func _ensure_music_player() -> void:
	if _music_player:
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = _valid_bus(BUS_MUSIC)
	# restart on finish so it loops even for formats without a loop flag (e.g. WAV without loop points)
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

func _on_music_finished() -> void:
	if _music_player.stream != null:
		_music_player.play()

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
