extends RefCounted
## Which fairies the player has used in a battle, kept between sessions
## (user://fairy_book.cfg). The title screen shows only these in colour; the rest stand
## there as dark silhouettes until they are used. Using a fairy for the first time is
## recorded by the battle screen (BattleView._commit_item).

const SAVE_PATH := "user://fairy_book.cfg"

## Where it is kept (the tests point it somewhere else).
static var path := SAVE_PATH
## Off for the tests and the screenshot tools, so they leave the player's book alone.
static var recording := true

static var _used: Dictionary = {}
static var _seen: Dictionary = {}
static var _loaded := false

static func has_used(id: String) -> bool:
	_load()
	return _used.has(id)

## Note that fairy `id` was used. True when it was the first time.
static func record_use(id: String) -> bool:
	_load()
	if not recording or _used.has(id):
		return false
	_used[id] = Time.get_datetime_string_from_system()
	_save()
	return true

## Used fairies the title screen has not shown in colour yet (they pop in when it does).
static func unseen() -> Array[String]:
	_load()
	var result: Array[String] = []
	for id in _used:
		if not _seen.has(id):
			result.append(str(id))
	return result

## The title screen has shown them.
static func mark_seen() -> void:
	_load()
	if not recording:
		return
	for id in _used:
		_seen[id] = true
	_save()

static func used_count() -> int:
	_load()
	return _used.size()

## Forget everything, in memory and on disk (the trial version does this at every launch).
static func wipe() -> void:
	reset_memory()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

## Forget everything in memory (the tests start from nothing; the file is untouched).
static func reset_memory() -> void:
	_used = {}
	_seen = {}
	_loaded = true

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	for id in config.get_section_keys("used") if config.has_section("used") else PackedStringArray():
		_used[id] = config.get_value("used", id)
	for id in config.get_section_keys("seen") if config.has_section("seen") else PackedStringArray():
		_seen[id] = true

static func _save() -> void:
	var config := ConfigFile.new()
	for id in _used:
		config.set_value("used", id, _used[id])
	for id in _seen:
		config.set_value("seen", id, true)
	config.save(path)
