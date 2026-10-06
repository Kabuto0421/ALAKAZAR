extends Control
## F9 on the title screen: pick the build to enter layer 2 with (the state right after clearing layer 1).
## Each row has a button (or a key) that opens the catalog to pick from; Enter = go, Esc = close.
## Keys: S = sheath weapon, W = third weapon, 1-3 = fairy slots, X = clear the third weapon, P = class-up all, H = HP.

const Weapons = preload("res://scripts/run/weapon_catalog.gd")
const Battle = preload("res://scripts/battle_model.gd")
const DebugStart = preload("res://scripts/debug/debug_start.gd")
const CatalogView = preload("res://scripts/ui/catalog_view.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const SHEATH_ART = preload("res://assets/sprites/spirits/sheath_fairy.png")

var sheath := 2
## A weapon in the third slot besides 前進剣 and 後退剣 (-1: none).
var third := -1
var fairies: Array[String] = ["magic_bolt", "stealth_fairy", "acorn_fairy"]
var plus := true
var hp := Battle.MAX_HP
var probe := Battle.new()
var info: Label
var catalog: Control
var rows: Array[Button] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	info = Label.new()
	info.position = Vector2(180, 140)
	info.add_theme_font_override("font", FONT)
	info.add_theme_font_size_override("font_size", 28)
	info.add_theme_constant_override("line_spacing", 14)
	add_child(info)
	var art := TextureRect.new()
	art.texture = SHEATH_ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(1150, 120)
	art.size = Vector2(380, 380)
	add_child(art)
	# One button per pickable row, lined up with the text rows.
	_row_button(0, "鞘の武器を選ぶ [S]", func() -> void: _pick("weapon", func(id: Variant) -> void: sheath = int(id)))
	_row_button(1, "3本目の武器を選ぶ [W]", func() -> void: _pick("weapon", func(id: Variant) -> void: third = int(id)))
	for slot in 3:
		_row_button(2 + slot, "妖精%dを選ぶ [%d]" % [slot + 1, slot + 1], func() -> void: _pick("fairy", func(id: Variant) -> void: fairies[slot] = str(id)))
	_refresh()

func _row_button(row: int, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	# The text rows are 56 px apart; the pickable ones start at the fourth line.
	button.position = Vector2(930, 162 + (3 + row) * 56 - 21)
	button.size = Vector2(210, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	add_child(button)
	rows.append(button)

func _pick(kind: String, apply: Callable) -> void:
	if is_instance_valid(catalog):
		return
	catalog = CatalogView.new()
	catalog.pick_kind = kind
	catalog.picked.connect(func(offer: Dictionary) -> void:
		apply.call(offer.value)
		_refresh())
	add_child(catalog)

func _weapon_name(index: int) -> String:
	return "なし" if index < 0 else "%s（%s）" % [Weapons.DATA[index].name, Weapons.DATA[index].detail]

func _refresh() -> void:
	var lines := ["デバッグ：2層目を最初から（1層クリア直後）", "武器：前進剣・後退剣は固定", ""]
	lines.append("鞘の武器 : %s" % _weapon_name(sheath))
	lines.append("3本目の武器 : %s" % _weapon_name(third))
	for slot in fairies.size():
		lines.append("妖精%d : %s" % [slot + 1, probe.item_definition(fairies[slot]).title])
	lines.append("クラスアップ済み [P] : %s" % ("あり" if plus else "なし"))
	lines.append("HP [H] : %d" % hp)
	lines.append("")
	lines.append("[Enter] 開始    [X] 3本目を外す    [Esc] 閉じる")
	info.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(catalog) or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_S:
			_row_press(0)
		KEY_W:
			_row_press(1)
		KEY_1, KEY_2, KEY_3:
			_row_press(2 + event.keycode - KEY_1)
		KEY_X:
			third = -1
		KEY_P:
			plus = not plus
		KEY_H:
			hp = hp % Battle.MAX_HP + 1
		KEY_ENTER, KEY_KP_ENTER:
			var weapons: Array = [0, 1]
			if third >= 2:
				weapons.append(third)
			DebugStart.launch(get_tree(), {"weapons": weapons, "sheath": sheath, "fairies": fairies.duplicate(), "plus": plus, "hp": hp})
		KEY_ESCAPE:
			queue_free()
		_:
			return
	get_viewport().set_input_as_handled()
	_refresh()

func _row_press(index: int) -> void:
	rows[index].pressed.emit()
