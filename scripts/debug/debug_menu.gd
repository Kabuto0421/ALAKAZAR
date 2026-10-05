extends Control
## F9 on the title screen: pick the build to enter layer 2 with (the state right after clearing layer 1).
## Keys: Left/Right = sheath weapon, 1-3 = cycle that fairy slot, P = class-up all, H = HP, Enter = go, Esc = close.

const Weapons = preload("res://scripts/run/weapon_catalog.gd")
const Battle = preload("res://scripts/battle_model.gd")
const Run = preload("res://scripts/run/run_model.gd")
const DebugStart = preload("res://scripts/debug/debug_start.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const SHEATH_ART = preload("res://assets/sprites/spirits/sheath_fairy.png")

var sheath := 2
var fairies: Array[String] = ["magic_bolt", "stealth_fairy", "acorn_fairy"]
var plus := true
var hp := Battle.MAX_HP
var pool: Array = []
var probe := Battle.new()
var info: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	pool = Run.new().reward_fairy_pool.duplicate()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	info = Label.new()
	info.position = Vector2(180, 140)
	info.add_theme_font_override("font", FONT)
	info.add_theme_font_size_override("font_size", 28)
	add_child(info)
	var art := TextureRect.new()
	art.texture = SHEATH_ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(1150, 120)
	art.size = Vector2(380, 380)
	add_child(art)
	_refresh()

func _refresh() -> void:
	var lines := ["デバッグ：2層目を最初から（1層クリア直後）", ""]
	lines.append("鞘の武器  ←/→ : %s（%s）" % [Weapons.DATA[sheath].name, Weapons.DATA[sheath].detail])
	for slot in fairies.size():
		lines.append("妖精%d  [%d]で切替 : %s" % [slot + 1, slot + 1, probe.item_definition(fairies[slot]).title])
	lines.append("クラスアップ済み  [P] : %s" % ("あり" if plus else "なし"))
	lines.append("HP  [H] : %d" % hp)
	lines.append("")
	lines.append("[Enter] 開始    [Esc] 閉じる")
	info.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_LEFT:
			sheath = _step_weapon(-1)
		KEY_RIGHT:
			sheath = _step_weapon(1)
		KEY_1, KEY_2, KEY_3:
			var slot: int = event.keycode - KEY_1
			var i: int = pool.find(fairies[slot])
			for k in pool.size():
				var next: String = pool[(i + 1 + k) % pool.size()]
				if not fairies.has(next):
					fairies[slot] = next
					break
		KEY_P:
			plus = not plus
		KEY_H:
			hp = hp % Battle.MAX_HP + 1
		KEY_ENTER, KEY_KP_ENTER:
			DebugStart.launch(get_tree(), {"weapons": [0, 1], "sheath": sheath, "fairies": fairies.duplicate(), "plus": plus, "hp": hp})
		KEY_ESCAPE:
			queue_free()
		_:
			return
	get_viewport().set_input_as_handled()
	_refresh()

func _step_weapon(direction: int) -> int:
	var n: int = Weapons.DATA.size()
	var i := sheath
	for k in n:
		i = (i + direction + n) % n
		if i >= 2 and not Weapons.is_pair_member(i) and not Weapons.horizontal_only(i):
			return i
	return sheath
