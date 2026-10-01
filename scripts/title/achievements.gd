extends RefCounted
## Achievements: the list, what is unlocked (saved in user://achievements.cfg), and the
## call the game makes when one is earned. The list is still empty: add entries to
## DEFINITIONS and call Achievements.unlock("<id>") where it is earned; the title
## screen's 実績 page shows them (locked ones greyed, hidden ones as ？？？).
##
##     {"id": "first_win", "title": "初陣", "description": "戦闘に1回勝つ", "hidden": false}

const SAVE_PATH := "user://achievements.cfg"
const DEFINITIONS: Array[Dictionary] = []

static var _unlocked: Dictionary = {}
static var _loaded := false

static func all() -> Array[Dictionary]:
	return DEFINITIONS

static func is_unlocked(id: String) -> bool:
	_load()
	return _unlocked.has(id)

static func unlocked_count() -> int:
	return DEFINITIONS.filter(func(a: Dictionary) -> bool: return is_unlocked(a.id)).size()

## Mark one as earned (once; unknown ids are ignored). True when it was new.
static func unlock(id: String) -> bool:
	_load()
	if _unlocked.has(id) or not DEFINITIONS.any(func(a: Dictionary) -> bool: return a.id == id):
		return false
	_unlocked[id] = Time.get_datetime_string_from_system()
	_save()
	return true

## Forget every unlock, in memory and on disk (the trial version does this at every launch).
static func wipe() -> void:
	_unlocked = {}
	_loaded = true
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		for id in config.get_section_keys("unlocked") if config.has_section("unlocked") else PackedStringArray():
			_unlocked[id] = config.get_value("unlocked", id, "")

static func _save() -> void:
	var config := ConfigFile.new()
	for id in _unlocked:
		config.set_value("unlocked", id, _unlocked[id])
	config.save(SAVE_PATH)
