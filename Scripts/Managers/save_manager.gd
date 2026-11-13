extends Node

## Autoload "SaveManager". Writes and reads the single save slot as JSON. Run from the editor, the slot is
## res://Saves/save_slot_1.json (inside the project, easy to open and delete). An exported game
## cannot write into its own project, so it uses user://save_slot_1.json instead.
##
## The manager knows nothing about gameplay. Two kinds of state reach the file:
## - Nodes that stay in the tree join the group `saveable`. They are asked at save time.
## - Things that remove themselves (a collected pickup, a broken tile, a dead boss) call
##   set_flag(id, data) when it happens, because they can no longer be asked later.
## Both land in the same `flags` dictionary, keyed by a stable `save_id`.
##
## A saveable node provides:
##   var save_id: String                      stable and unique (never a node path)
##   func get_save_data() -> Dictionary       what to store (JSON types only); {} = nothing to store
##   func load_save_data(data: Dictionary)    called with the stored dictionary after loading
## JSON turns every number into a float; convert back (int(value)) where an int is needed.
##
## Usage:
##   SaveManager.save_game("save_room_1")     # at a save point
##   SaveManager.restart_from_save()          # after dying: reload the level from the slot
## When the game starts, the slot (if any) is continued automatically; see auto_continue.

signal saved(save_point_id: String)

const EDITOR_SAVE_PATH := "res://Saves/save_slot_1.json"
const EXPORTED_SAVE_PATH := "user://save_slot_1.json"
const SAVE_VERSION := 1
## Where a new game begins (the main menu's START GAME and the game over screen's TRY AGAIN without a save).
const NEW_GAME_SCENE := "res://Scenes/Levels/demo_wrecked_ship_3.tscn"
const SAVEABLE_GROUP := &"saveable"
const SAVE_POINT_GROUP := &"save_point"
## Root nodes of the title screen and main menu join this group; auto_continue skips them.
const MENU_SCREEN_GROUP := &"menu_screen"
## Frames to wait after changing the scene before the level counts as ready (nodes are added
## the next frame and RoomManager sets up its rooms one frame after that).
const SETTLE_FRAMES := 3

## Continue from the slot when the game starts (only if it was saved in the scene being run).
## Turn it off, or delete the slot file, to start from the beginning.
@export var auto_continue: bool = true

## Where the slot lives.
var save_path: String = EDITOR_SAVE_PATH if OS.has_feature("editor") else EXPORTED_SAVE_PATH
## The save that was last written or read. Empty if there is none.
var data: Dictionary = {}
## World state since the level started: the slot's flags plus everything reported with set_flag().
var world_flags: Dictionary = {}
## True once the final objective was completed (see MissionManager). Stored as an optional top-level key
## of the slot (absent = false, so SAVE_VERSION is unchanged) and written into every later snapshot,
## so saving at a save point after the mission does not erase it.
var game_completed: bool = false

func _ready() -> void:
	if auto_continue:
		_continue_on_launch.call_deferred()

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

## Loads the slot and puts the running level in its saved state. Returns false (and changes
## nothing) if there is no usable slot or it was saved in a different scene.
func continue_from_save() -> bool:
	var scene := get_tree().current_scene
	if scene == null or not has_save():
		return false
	var flags_before := world_flags
	if not load_game():
		world_flags = flags_before
		return false
	if str(data.get("scene", "")) != scene.scene_file_path:
		print("[SaveManager] Slot was saved in %s, not %s; starting from the beginning." % [data.get("scene"), scene.scene_file_path])
		data = {}
		game_completed = false
		world_flags = flags_before
		return false
	restore_level()
	PlayerSequence.queue(PlayerSequence.Type.MISSION_START, false)  # a save was loaded into the running level
	print("[SaveManager] Continued from the save at '%s' (%s)." % [get_save_point_id(), save_path])
	return true

## Records state for something that is about to remove itself.
func set_flag(id: String, value: Dictionary) -> void:
	world_flags[id] = value

func get_flag(id: String, default: Dictionary = {}) -> Dictionary:
	return world_flags.get(id, default)

## Collects every saveable node and writes the slot. Returns false if the file could not be written.
func save_game(save_point_id: String) -> bool:
	var flags: Dictionary = world_flags.duplicate(true)
	var seen: Dictionary = {}
	for node in get_tree().get_nodes_in_group(SAVEABLE_GROUP):
		var id := _save_id_of(node)
		if id == "" or not node.has_method("get_save_data"):
			continue
		var node_data: Dictionary = node.get_save_data()
		if node_data.is_empty():
			continue
		if seen.has(id):
			push_warning("[SaveManager] Duplicate save_id '%s' on %s; the later one wins." % [id, node.name])
		seen[id] = true
		flags[id] = node_data
	var scene := get_tree().current_scene
	var snapshot := {
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"scene": scene.scene_file_path if scene != null else "",
		"save_point": save_point_id,
		"flags": flags,
		"game_completed": game_completed,
	}
	if not _write_file(JSON.stringify(snapshot, "\t")):
		return false
	data = snapshot
	world_flags = flags
	saved.emit(save_point_id)
	return true

## Persists the finished game (used by MissionManager). Rewrites the slot from the running level, so
## inventory, abilities, collected items and world flags are kept, and adds game_completed. The save
## point id is kept from the last save so the slot still restores at a real save point (a made-up id
## would skip the teleport in restore_level). Overwriting the previous save is intended here.
## Returns false, leaving game_completed unchanged, if the file could not be written.
func save_completed_game() -> bool:
	var previous := game_completed
	game_completed = true
	if save_game(get_save_point_id()):
		return true
	game_completed = previous
	return false

## Reads the slot into `data` and `world_flags`. Returns false (leaving both empty) if the slot is
## missing or unusable.
func load_game() -> bool:
	data = {}
	world_flags = {}
	game_completed = false
	if not has_save():
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("[SaveManager] Cannot open %s (error %d)." % [save_path, FileAccess.get_open_error()])
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("flags"):
		push_warning("[SaveManager] %s is not a valid save." % save_path)
		return false
	if int(parsed.get("version", 0)) != SAVE_VERSION:
		push_warning("[SaveManager] Save version %s is not supported (expected %d)." % [parsed.get("version"), SAVE_VERSION])
		return false
	data = parsed
	world_flags = parsed["flags"].duplicate(true)
	game_completed = bool(parsed.get("game_completed", false))
	return true

## Hands each saveable node the data stored under its id. Nodes with no entry keep their defaults.
func apply_save() -> void:
	for node in get_tree().get_nodes_in_group(SAVEABLE_GROUP):
		var id := _save_id_of(node)
		if world_flags.has(id) and node.has_method("load_save_data"):
			node.load_save_data(world_flags[id])

## Id of the save point the slot was written at, or "".
func get_save_point_id() -> String:
	return str(data.get("save_point", ""))

## The save point node with the given id in the current level, or null.
func find_save_point(id: String) -> Node2D:
	for node in get_tree().get_nodes_in_group(SAVE_POINT_GROUP):
		if node.get("save_id") == id:
			return node as Node2D
	return null

func delete_save() -> void:
	data = {}
	world_flags = {}
	game_completed = false
	if has_save():
		DirAccess.remove_absolute(save_path)

## Reloads the level from the slot and puts the player back at its save point. With no usable slot
## the level simply restarts from scratch. Call it without await; it finishes a few frames later.
func restart_from_save() -> bool:
	var tree := get_tree()
	var loaded := load_game()
	MapManager.reset()  # discoveries and the map pickup are restored from the slot, never kept from the dead run
	var scene_path := str(data.get("scene", ""))
	if scene_path == "" and tree.current_scene != null:
		scene_path = tree.current_scene.scene_file_path
	if scene_path == "":
		push_warning("[SaveManager] No scene to restart.")
		return false
	var error := tree.change_scene_to_file(scene_path)
	if error != OK:
		push_warning("[SaveManager] Cannot load %s (error %d)." % [scene_path, error])
		return false
	for i in SETTLE_FRAMES:
		await tree.process_frame
	if loaded:
		restore_level()
	return true

## Applies the loaded slot to the running level and moves the player to the saved save point.
func restore_level() -> void:
	apply_save()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var save_point := find_save_point(get_save_point_id())
	if player == null or save_point == null:
		return
	player.global_position = save_point.global_position
	var manager := get_tree().get_first_node_in_group("room_manager")
	if manager != null:
		manager.warp_to(player.global_position)

## Starts a fresh game in `scene_path` (used by the main menu). Deletes the slot, because dying later
## reloads from it and would otherwise resume the old run; the caller asks the player first. The
## in-memory state (flags, map) is cleared too. Nothing is touched if the scene cannot be loaded.
func start_new_game(scene_path: String, sequence: PlayerSequence.Type = PlayerSequence.Type.MISSION_START) -> Error:
	if not ResourceLoader.exists(scene_path):
		push_warning("[SaveManager] Cannot start a new game: %s does not exist." % scene_path)
		return ERR_FILE_NOT_FOUND
	delete_save()
	MapManager.reset()
	PlayerSequence.queue(sequence)
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		PlayerSequence.cancel()
	return error

## Continues the slot from outside a level (used by the main menu): reloads the scene it was saved in
## and restores it, like after dying. Returns false, changing nothing, if the slot is missing or
## unusable. Await it; it finishes once the level is restored.
func continue_game(sequence: PlayerSequence.Type = PlayerSequence.Type.MISSION_START) -> bool:
	if not load_game() or not ResourceLoader.exists(str(data.get("scene", ""))):
		data = {}
		world_flags = {}
		game_completed = false
		return false
	PlayerSequence.queue(sequence)
	if not await restart_from_save():
		PlayerSequence.cancel()
		return false
	return true

## TRY AGAIN after dying (used by the game over screen): continues the slot as it was last written, and
## starts a fresh game if there is no usable slot. Never writes or deletes a save that exists. Await it.
func retry_after_death() -> bool:
	if has_save() and await continue_game(PlayerSequence.Type.MISSION_CONTINUE):
		return true
	return start_new_game(NEW_GAME_SCENE) == OK

# The main scene is added after the autoloads, so wait for it and for RoomManager's setup.
func _continue_on_launch() -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene != null and scene.is_in_group(MENU_SCREEN_GROUP):
		return  # the title/main menu decides when to continue
	continue_from_save()

func _save_id_of(node: Node) -> String:
	var id: Variant = node.get("save_id")
	return str(id) if id != null else ""

# Written to a temporary file first so a crash never leaves a half-written slot.
func _write_file(text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveManager] Cannot write %s (error %d)." % [temp_path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.close()
	var error := DirAccess.rename_absolute(temp_path, save_path)
	if error != OK:
		push_warning("[SaveManager] Cannot replace %s (error %d)." % [save_path, error])
		return false
	return true
