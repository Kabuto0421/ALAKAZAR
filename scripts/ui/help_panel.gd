extends Control
## The field manual: a few short pages that teach a first-time player the game.
## Shared by the draft screens and the battle (H key / "ルール" button).

signal closed

const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const LATIN = preload("res://assets/fonts/VT323-Regular.ttf")
const INK := Color("e5dfc5")
const CYAN := Color("2bdcc8")
const GOLD := Color("ffd35b")
const MUTED := Color("92b3ae")

const Figure = preload("res://scripts/ui/help_figure.gd")
## Each page: a title and up to three pictures with one short line each.
const PAGES := [
	{"title": "基本", "items": [
		{"kind": "move", "caption": "光るマスへ動ける"},
		{"kind": "attack", "caption": "敵を押すと攻撃", "sub": "自分は動かない"},
		{"kind": "win", "caption": "全滅で勝ち"},
	]},
	{"title": "AP（行動力）", "items": [
		{"kind": "ap_actions", "caption": "1行動 = AP1", "sub": "1ターンにAP2"},
		{"kind": "ap_end", "caption": "AP0で敵のターン", "sub": "ボタンで早く渡せる"},
	]},
	{"title": "敵にもAPがある", "items": [
		{"kind": "enemy_ap1", "caption": "AP1の敵", "sub": "1マス動いて終わり"},
		{"kind": "enemy_ap2", "caption": "AP2の敵", "sub": "動いてから殴ってくる"},
		{"kind": "enemy_ap_info", "caption": "敵に乗せるとAP", "sub": "何回動くか見える"},
	]},
	{"title": "危険を読む", "items": [
		{"kind": "threat", "caption": "！は次に殴られる", "sub": "動いて避けよう"},
		{"kind": "inspect", "caption": "赤いマスは攻撃範囲"},
	]},
	{"title": "武器", "items": [
		{"kind": "switch", "caption": "3本を持ち替え", "sub": "0 AP・1〜3キー"},
		{"kind": "jump", "caption": "跳ぶ", "sub": "間を飛び越える"},
		{"kind": "slide", "caption": "滑る", "sub": "止まるまで進む"},
	]},
	{"title": "特殊効果", "items": [
		{"kind": "circle", "caption": "魔法陣", "sub": "白いマスで囲むと99"},
		{"kind": "push", "caption": "押出", "sub": "ぶつけるとさらに1"},
	]},
	{"title": "妖精", "items": [
		{"kind": "place", "caption": "光るマスに置く", "sub": "AP1・各戦闘1回"},
		{"kind": "cannon", "caption": "大砲は叩くと発射"},
		{"kind": "fade", "caption": "3ターンで消える"},
	]},
]

var page := 0
var body: Control
var title_label: Label
var page_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.size = size
	add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(176, 70)
	panel.size = Vector2(800, 580)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("060e10")
	style.border_color = Color("2bdcc8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var head := _label(panel, Vector2(28, 18), "FIELD MANUAL", 30, CYAN)
	head.add_theme_font_override("font", LATIN)
	title_label = _label(panel, Vector2(28, 62), "", 28, INK)
	page_label = _label(panel, Vector2(680, 24), "", 20, MUTED)
	body = Control.new()
	body.position = Vector2(28, 116)
	body.size = Vector2(744, 380)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(body)
	_button(panel, Vector2(28, 516), "← 前へ", func(): _turn(-1))
	_button(panel, Vector2(308, 516), "閉じる [H]", func(): close())
	_button(panel, Vector2(588, 516), "次へ →", func(): _turn(1))
	_show()

func _turn(step: int) -> void:
	page = clampi(page + step, 0, PAGES.size() - 1)
	_show()

func _show() -> void:
	for child in body.get_children():
		child.queue_free()
	var data: Dictionary = PAGES[page]
	title_label.text = data.title
	page_label.text = "%d / %d" % [page + 1, PAGES.size()]
	var items: Array = data["items"]
	for i in items.size():
		var item: Dictionary = items[i]
		var figure := Figure.new()
		figure.kind = item.kind
		# Two or three pictures, centred on the page.
		var left := (744.0 - (items.size() * 232 + (items.size() - 1) * 24)) / 2.0
		figure.position = Vector2(left + i * 256, 0)
		figure.size = Vector2(232, 232)
		body.add_child(figure)
		if item.caption != "":
			var caption := _label(body, figure.position + Vector2(0, 244), item.caption, 22, INK)
			caption.custom_minimum_size = Vector2(232, 0)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if item.has("sub"):
			var sub := _label(body, figure.position + Vector2(0, 276), item.sub, 17, MUTED)
			sub.custom_minimum_size = Vector2(232, 0)
			sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func close() -> void:
	visible = false
	closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode in [KEY_RIGHT, KEY_D]:
		_turn(1)
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_LEFT, KEY_A]:
		_turn(-1)
		get_viewport().set_input_as_handled()

func _label(parent: Node, at: Vector2, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, at: Vector2, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.position = at
	button.size = Vector2(184, 44)
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	parent.add_child(button)
