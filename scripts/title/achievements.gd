extends RefCounted
## Achievements: the list, what is unlocked (saved in user://achievements.cfg), and the
## call the game makes when one is earned. To add one: an entry in DEFINITIONS (in the
## order the 実績 page shows them) and a call to Achievements.unlock("<id>") where it is
## earned (BattleView._check_achievements checks the battle ones); the title screen's 実績
## page shows them (locked ones greyed, hidden ones as ？？？).
##
##     {"id": "first_win", "title": "初陣", "description": "戦闘に1回勝つ", "icon": "res://...png", "hidden": false}

const SAVE_PATH := "user://achievements.cfg"
const DEFINITIONS: Array[Dictionary] = [
	{"id": "fairy_master", "title": "妖精マスター", "description": "妖精全員を使う", "progress_label": "使った妖精", "icon": "res://assets/achievements/fairy_master.png"},
	{"id": "the_world", "title": "ザ・ワールド", "description": "時を止めてる状態で試合を終える", "icon": "res://assets/achievements/the_world.png"},
]

## Off for the tests and the screenshot tools: unlocking then only counts in memory.
static var recording := DisplayServer.get_name() != "headless"

const Rules = preload("res://scripts/battle_model.gd")
const FairyBook = preload("res://scripts/fairy_book.gd")

## How far along an achievement is, as [done, total] (empty when it is not a counting one).
static func progress(id: String) -> Array:
	if id == "fairy_master":
		var used := Rules.ITEMS.filter(func(item: Resource) -> bool: return FairyBook.has_used(item.id)).size()
		return [used, Rules.ITEMS.size()]
	return []

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
	if recording:
		_save()
	return true

## Forget every unlock in memory only (the tests start from nothing).
static func reset_memory() -> void:
	_unlocked = {}
	_loaded = true

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
