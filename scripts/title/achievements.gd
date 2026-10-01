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
	{"id": "alakazar_king", "title": "ALAKAZAR's KING", "description": "監獄の王を一回倒す", "icon": "res://assets/achievements/alakazar_king.png"},
	{"id": "guardian_sky", "title": "天の守護神、ここにあり。", "description": "守護神の妖精で妖精を一体以上引き連れる", "icon": "res://assets/achievements/guardian_sky.png"},
	{"id": "you_died", "title": "Y O U　 D I E D", "title_color": "d8281e", "description": "暴食の妖精に一回喰われる", "icon": "res://assets/achievements/you_died.png"},
	{"id": "garden", "title": "戦場の庭師", "description": "設置妖精を3体以上、盤面に置く", "icon": "res://assets/achievements/garden.png"},
	{"id": "chain", "title": "ばよえ〜ん！", "description": "5CHAIN以上を起こす", "icon": "res://assets/achievements/chain.png"},
	{"id": "surprise", "title": "え、これできるんだ...", "description": "攻撃系の妖精で設置系妖精を起動する", "icon": "res://assets/achievements/surprise.png"},
	{"id": "circle", "title": "魔法陣最高！魔法陣最高！", "description": "魔法陣武器で魔法陣を完成させる", "icon": "res://assets/achievements/circle.png"},
	{"id": "meteor_hell", "title": "これは一体、どうなっちゃうんだ〜！？", "description": "隕石妖精を3回強化する", "icon": "res://assets/achievements/meteor_hell.png"},
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

## Earn every achievement the battle's state now qualifies for. Returns the new ones.
## Called after every change in a battle and at the camp (the meteor class-ups).
static func check(model: RefCounted) -> Array[String]:
	var earned: Array[String] = []
	var stats: Dictionary = model.stats
	var won: bool = model.phase == Rules.Phase.WON
	var met := {
		"fairy_master": Rules.ITEMS.all(func(item: Resource) -> bool: return FairyBook.has_used(item.id)),
		"alakazar_king": won and model.level == Rules.FINAL_LEVEL,
		"guardian_sky": int(stats.guardian_calls) >= GUARDIAN_CALLS,
		"you_died": bool(stats.eaten),
		"garden": model.placed_recently() >= PLACED_NEEDED,
		"chain": int(stats.max_chain) >= CHAIN_NEEDED,
		"surprise": bool(stats.fairy_set_off),
		"circle": int(stats.circles) >= 1,
		"meteor_hell": model.plus_level("meteor_fairy") >= METEOR_NEEDED,
		"the_world": won and model.time_stopped(),
	}
	for id: String in met:
		if met[id] and unlock(id):
			earned.append(id)
	return earned

## The numbers the descriptions promise.
const GUARDIAN_CALLS := 1
const PLACED_NEEDED := 3
const CHAIN_NEEDED := 5
const METEOR_NEEDED := 3

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
