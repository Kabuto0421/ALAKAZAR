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

const Shot = preload("res://scripts/ui/help_shot.gd")
## Each page: a title, a short lead that states the rule, and up to three
## screenshot flipbooks (with a tag per frame) that show it happening.
const PAGES := [
	{"title": "基本", "lead": "あなたのターンにはAPが2つ。APの数だけ、今の武器の範囲（光るマス）で「移動」「攻撃」「妖精を置く」ができる。", "items": [
		{"shots": ["basic_move_a", "basic_move_b"], "tags": ["AP 2", "移動 −1 AP"], "caption": "移動", "sub": "光るマスへ"},
		{"shots": ["basic_attack_a", "basic_attack_b"], "tags": ["AP 2", "攻撃 −1 AP"], "caption": "攻撃", "sub": "敵を押す。自分は動かない"},
		{"shots": ["basic_fairy_a", "basic_fairy_b"], "tags": ["AP 2", "妖精 −1 AP"], "caption": "妖精を置く", "sub": "光るマスに置く"},
	]},
	{"title": "AP（行動力）", "lead": "移動・攻撃・妖精はどれもAP1。APが0になるか「ターン終了」で敵のターン。武器の持ち替えはAPを使わない。", "items": [
		{"shots": ["loop_0", "loop_1", "loop_2", "loop_3", "loop_4"], "tags": ["あなたのターン AP 2", "移動 −1 AP", "攻撃 −1 AP → 0", "敵のターン", "またあなたのターン AP 2"], "caption": "2回動いたら敵の番", "sub": "敵が動くとAPが2に戻る。これのくり返し", "wide": true},
		{"shots": ["switch_a", "switch_b"], "tags": ["前進剣", "持ち替え 0 AP"], "caption": "持ち替えは0AP", "sub": "光るマスが変わる"},
	]},
	{"title": "武器", "lead": "武器は3本まで。武器ごとに動ける方向と攻撃力が違う。いろんな方向の武器を集めて、組み合わせて戦おう。", "items": [
		{"shots": ["dir_a", "dir_b", "dir_c"], "tags": ["前進剣", "縦跳剣", "桂馬剣"], "caption": "動ける方向が違う", "sub": "下のカードの図が範囲"},
		{"shots": ["power_a", "power_b"], "tags": ["ハンマー 攻撃3", "攻撃 −1 AP"], "caption": "攻撃力も違う", "sub": "カードの「攻撃N」"},
		{"shots": ["combo_0", "combo_1", "combo_2", "combo_3"], "tags": ["縦跳剣", "移動 −1 AP", "持ち替え 0 AP", "攻撃 −1 AP"], "caption": "組み合わせる", "sub": "動いてから、別の武器で殴る"},
	]},
	{"title": "特殊効果", "lead": "一部の武器には特別な効果がある。白い枠は魔法陣。カードの「押出」「滑る」などのタグも見よう。", "items": [
		{"shots": ["circle_a", "circle_b", "circle_c"], "tags": ["囲める場所が光る", "発動", "99ダメージ"], "caption": "魔法陣", "sub": "歩いた跡で囲むと99ダメージ"},
		{"shots": ["push_a", "push_b"], "tags": ["押出", "ぶつかって +1"], "caption": "押出", "sub": "押された敵がぶつかると+1"},
		{"shots": ["slide"], "caption": "滑る", "sub": "ふさがるまで一直線に進む"},
	]},
	{"title": "妖精", "lead": "妖精はいっしょに戦う相棒。各戦闘1回ずつ力を貸してくれて、呼ぶとAP1。置ける場所は今の武器の範囲（光るマス）で、持ち替えると変わる。", "items": [
		{"shots": ["fairy_once_a", "fairy_once_b"], "tags": ["AP 2", "妖精 −1 AP"], "caption": "呼ぶとAP1", "sub": "1戦闘1回（次の戦闘でまた呼べる）"},
		{"shots": ["fairy_range_a", "fairy_range_b"], "tags": ["前進剣のとき", "前斜剣のとき"], "caption": "置ける場所は武器次第", "sub": "水色のマスに置ける"},
	]},
	{"title": "設置系の妖精", "lead": "壁・大砲・隠密妖精などの設置系は、置いたターンを含めて3ターンで消える。右下の数字が残りのターン。", "items": [
		{"shots": ["fade_3", "fade_2", "fade_1", "fade_0"], "tags": ["残り3", "残り2", "残り1", "消えた"], "caption": "3ターンで消える"},
		{"shots": ["cannon_a", "cannon_b"], "tags": ["大砲", "叩く −1 AP"], "caption": "大砲は武器で叩くと発射", "sub": "向きの直線上の敵すべてに1"},
	]},
	{"title": "敵にもAPがある", "lead": "敵にもAPがあり、移動も攻撃も1AP。同じ2マス先からでも、AP1の敵は寄るだけ、AP2の敵は寄ってそのまま殴ってくる。", "items": [
		{"shots": ["eap1_a", "eap1_b"], "tags": ["敵AP 1", "敵 移動 −1 → 終わり"], "caption": "AP1の敵", "sub": "寄ってきて終わり"},
		{"shots": ["eap2_a", "eap2_b"], "tags": ["敵AP 2", "敵 移動→攻撃"], "caption": "AP2の敵", "sub": "動いてから殴ってくる"},
		{"shots": ["inspect_ap"], "caption": "敵に乗せると情報", "sub": "HP・AP・動き・攻撃範囲"},
	]},
	{"title": "危険を読む", "lead": "！が付いた敵は、あなたが今の場所にいると次のターンに攻撃してくる。！が消える場所へ動けば避けられる。", "items": [
		{"shots": ["threat_rule"], "caption": "！は次に殴られる"},
		{"shots": ["dodge_0", "dodge_1", "dodge_2", "dodge_3"], "tags": ["！が付いた", "避ける場所へ", "移動 −1 AP", "敵のターン：無傷"], "caption": "実践：避ける", "sub": "寄られても殴られない"},
	]},
]

var page := 0
var body: Control
var title_label: Label
var page_label: Label
var lead_label: Label

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
	lead_label = _label(panel, Vector2(28, 104), "", 19, GOLD)
	lead_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	lead_label.custom_minimum_size = Vector2(744, 0)
	lead_label.size = Vector2(744, 0)
	body = Control.new()
	body.position = Vector2(28, 168)
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
	# Opened before it entered the tree: _ready builds the page itself.
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	var data: Dictionary = PAGES[page]
	title_label.text = data.title
	lead_label.text = data.get("lead", "")
	page_label.text = "%d / %d" % [page + 1, PAGES.size()]
	var items: Array = data["items"]
	for i in items.size():
		var item: Dictionary = items[i]
		var figure := Shot.new()
		for name in item.shots:
			figure.frames.append(load("res://assets/help/%s.png" % name))
		figure.tags = item.get("tags", [])
		# Two or three pictures, centred on the page; a "wide" one takes two slots.
		var slots := 0
		for other in items:
			slots += 2 if other.get("wide", false) else 1
		var before := 0
		for k in i:
			before += 2 if items[k].get("wide", false) else 1
		var left := (744.0 - (slots * 232 + (slots - 1) * 24)) / 2.0
		var span := 2 if item.get("wide", false) else 1
		figure.position = Vector2(left + before * 256, 0)
		figure.size = Vector2(232 * span + 24 * (span - 1), 262)
		body.add_child(figure)
		if item.caption != "":
			var caption := _label(body, figure.position + Vector2(0, 270), item.caption, 21, INK)
			caption.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			caption.custom_minimum_size = Vector2(figure.size.x, 0)
			caption.size = Vector2(figure.size.x, 0)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if item.has("sub"):
			var sub := _label(body, figure.position + Vector2(0, 298), item.sub, 15, MUTED)
			sub.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			sub.custom_minimum_size = Vector2(figure.size.x, 0)
			sub.size = Vector2(figure.size.x, 0)
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
