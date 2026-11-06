extends Node
## SaveSystem autoload.
##
## The active scene must implement:
##   get_save_state() -> Dictionary
##   apply_save_state(state: Dictionary) -> void
##
## The adapter dictionary must contain:
##   player: { hp: int, max_hp: int }
##   respawn: { x: float, y: float }
##   room_id: String
##   playtime_seconds: float

signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(slot: int, reason: String)
signal load_failed(slot: int, reason: String)

const SAVE_VERSION: int = 1
const SAVE_DIRECTORY: String = "user://saves"


func save_game(slot: int) -> bool:
	if not _is_valid_slot(slot):
		save_failed.emit(slot, "Save slot must be zero or a positive integer.")
		return false

	var scene: Node = get_tree().current_scene
	if scene == null or not scene.has_method("get_save_state"):
		save_failed.emit(slot, "The current scene does not implement get_save_state().")
		return false

	var raw_state: Variant = scene.call("get_save_state")
	if typeof(raw_state) != TYPE_DICTIONARY:
		save_failed.emit(slot, "get_save_state() must return a Dictionary.")
		return false

	var validation_error: String = _validate_game_state(raw_state)
	if not validation_error.is_empty():
		save_failed.emit(slot, validation_error)
		return false

	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"player": raw_state["player"].duplicate(true),
		"respawn": raw_state["respawn"].duplicate(true),
		"room_id": raw_state["room_id"],
		"playtime_seconds": float(raw_state["playtime_seconds"]),
		"saved_at": Time.get_datetime_string_from_system(true, false) + "Z"
	}

	var directory_error: String = _ensure_save_directory()
	if not directory_error.is_empty():
		save_failed.emit(slot, directory_error)
		return false

	var base_path: String = "%s/slot_%d.json" % [SAVE_DIRECTORY, slot]
	var temp_path: String = "%s/slot_%d.tmp" % [SAVE_DIRECTORY, slot]
	var backup_path: String = "%s/slot_%d.bak" % [SAVE_DIRECTORY, slot]

	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		save_failed.emit(slot, "Could not open temporary save file: %s" % error_string(FileAccess.get_open_error()))
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		save_failed.emit(slot, "Writing the temporary save file failed: %s" % error_string(write_error))
		return false

	var absolute_base: String = ProjectSettings.globalize_path(base_path)
	var absolute_temp: String = ProjectSettings.globalize_path(temp_path)
	var absolute_backup: String = ProjectSettings.globalize_path(backup_path)

	# Keep the previous save until the new file has been moved into place.
	if FileAccess.file_exists(backup_path):
		var remove_backup_error: Error = DirAccess.remove_absolute(absolute_backup)
		if remove_backup_error != OK:
			DirAccess.remove_absolute(absolute_temp)
			save_failed.emit(slot, "Could not remove the previous backup: %s" % error_string(remove_backup_error))
			return false

	var had_previous_save: bool = FileAccess.file_exists(base_path)
	if had_previous_save:
		var backup_error: Error = DirAccess.rename_absolute(absolute_base, absolute_backup)
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_temp)
			save_failed.emit(slot, "Could not protect the existing save: %s" % error_string(backup_error))
			return false

	var commit_error: Error = DirAccess.rename_absolute(absolute_temp, absolute_base)
	if commit_error != OK:
		if had_previous_save:
			DirAccess.rename_absolute(absolute_backup, absolute_base)
		save_failed.emit(slot, "Could not finalize the save file: %s" % error_string(commit_error))
		return false

	if had_previous_save and FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)

	save_completed.emit(slot)
	return true


func load_game(slot: int) -> bool:
	if not _is_valid_slot(slot):
		load_failed.emit(slot, "Save slot must be zero or a positive integer.")
		return false

	var path: String = "%s/slot_%d.json" % [SAVE_DIRECTORY, slot]
	if not FileAccess.file_exists(path):
		load_failed.emit(slot, "No save exists in slot %d." % slot)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_failed.emit(slot, "Could not open save file: %s" % error_string(FileAccess.get_open_error()))
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(json_text)
	if parse_error != OK:
		load_failed.emit(slot, "Save file contains invalid JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return false

	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		load_failed.emit(slot, "Save file root must be a JSON object.")
		return false

	var payload: Dictionary = parsed
	if not payload.has("version") or not _is_integer_number(payload["version"]):
		load_failed.emit(slot, "Save file has no valid version number.")
		return false
	var loaded_version: int = int(payload["version"])
	if loaded_version != SAVE_VERSION:
		load_failed.emit(slot, "Unsupported save version %d; this game supports version %d." % [loaded_version, SAVE_VERSION])
		return false

	var validation_error: String = _validate_game_state(payload, true)
	if not validation_error.is_empty():
		load_failed.emit(slot, "Save data is incomplete or invalid: %s" % validation_error)
		return false
	if not payload.has("saved_at") or typeof(payload["saved_at"]) != TYPE_STRING:
		load_failed.emit(slot, "Save data is missing its saved_at timestamp.")
		return false

	# JSON.parse() represents JSON numbers as floats; normalize integer fields
	# before passing the state to the scene adapter.
	var loaded_player: Dictionary = payload["player"]
	loaded_player["hp"] = int(loaded_player["hp"])
	loaded_player["max_hp"] = int(loaded_player["max_hp"])
	payload["version"] = loaded_version

	var scene: Node = get_tree().current_scene
	if scene == null or not scene.has_method("apply_save_state"):
		load_failed.emit(slot, "The current scene does not implement apply_save_state(state).")
		return false

	scene.call("apply_save_state", payload.duplicate(true))
	load_completed.emit(slot)
	return true


func has_save(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	return FileAccess.file_exists("%s/slot_%d.json" % [SAVE_DIRECTORY, slot])


func delete_save(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false

	var path: String = "%s/slot_%d.json" % [SAVE_DIRECTORY, slot]
	if not FileAccess.file_exists(path):
		return true

	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return remove_error == OK


func _is_valid_slot(slot: int) -> bool:
	return slot >= 0


func _ensure_save_directory() -> String:
	var absolute_directory: String = ProjectSettings.globalize_path(SAVE_DIRECTORY)
	if DirAccess.dir_exists_absolute(absolute_directory):
		return ""

	var make_error: Error = DirAccess.make_dir_recursive_absolute(absolute_directory)
	if make_error != OK and not DirAccess.dir_exists_absolute(absolute_directory):
		return "Could not create save directory: %s" % error_string(make_error)
	return ""


func _validate_game_state(state: Dictionary, allow_json_float_integers: bool = false) -> String:
	for required_key in ["player", "respawn", "room_id", "playtime_seconds"]:
		if not state.has(required_key):
			return "Missing required field '%s'." % required_key

	if typeof(state["player"]) != TYPE_DICTIONARY:
		return "'player' must be a Dictionary."
	var player: Dictionary = state["player"]
	if not player.has("hp") or not _is_integer_field_valid(player["hp"], allow_json_float_integers):
		return "'player.hp' must be an integer."
	if not player.has("max_hp") or not _is_integer_field_valid(player["max_hp"], allow_json_float_integers):
		return "'player.max_hp' must be an integer."

	if typeof(state["respawn"]) != TYPE_DICTIONARY:
		return "'respawn' must be a Dictionary."
	var respawn: Dictionary = state["respawn"]
	if not respawn.has("x") or not _is_number(respawn["x"]):
		return "'respawn.x' must be a number."
	if not respawn.has("y") or not _is_number(respawn["y"]):
		return "'respawn.y' must be a number."

	if typeof(state["room_id"]) != TYPE_STRING:
		return "'room_id' must be a String."
	if not _is_number(state["playtime_seconds"]):
		return "'playtime_seconds' must be a number."

	return ""


func _is_integer_field_valid(value: Variant, allow_json_float: bool) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return allow_json_float and _is_integer_number(value)


func _is_integer_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT and is_finite(value) and floor(value) == value


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT