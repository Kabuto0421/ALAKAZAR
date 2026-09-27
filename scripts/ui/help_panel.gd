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

const PAGES := [
	{"title": "1. 目的と基本", "lines": [
		["監獄都市ALAKAZARへ攻め込む遠征。盤上の敵を全滅させると戦闘に勝ち。HPが0で遠征終了。", INK],
		["あなたのターンには AP が2つ。移動・攻撃・妖精の使用はそれぞれ 1 AP。", INK],
		["AP を使い切るか「ターン終了」で敵のターン。そのあと、またあなたの番。", INK],
		["! マーク：その敵は、あなたが今の場所にいると次のターンに攻撃してくる。", GOLD],
		["敵にカーソルを乗せると、動き方と攻撃範囲が右の「敵の情報」に出る。右クリックで固定。", MUTED],
	]},
	{"title": "2. 武器 = 動ける場所", "lines": [
		["このゲームの武器は「動ける形」。盤面の光るマスが、今の武器で行ける場所。", INK],
		["空きマスを押すと移動。敵のマスを押すと攻撃（自分は動かない）。", INK],
		["武器は3本まで。画面下のカードか 1〜3 キーで持ち替え（0 AP）。", INK],
		["跳ぶ：途中のマスを飛び越える。滑る：ふさがるまで一直線。押出：当てた敵を押し出し、ぶつけると +1。", MUTED],
	]},
	{"title": "3. 妖精", "lines": [
		["妖精は各戦闘1回ずつ使える道具（1 AP）。左のボタンか 4〜6 キーで選ぶ。", INK],
		["多くの妖精は「今の武器で届くマス」に置く。武器を持ち替えると置ける場所も変わる。", INK],
		["置いた壁・大砲・隠密妖精は3ターンで消える。大砲は、そのマスを武器で叩くと発射する。", INK],
		["大砲の弾が別の大砲を通ると、そちらも誘爆する。連鎖を狙おう。", MUTED],
		["選んだ妖精の説明と動きの例は、右の欄に出る。Esc で取り消し。", MUTED],
	]},
	{"title": "4. 遠征の流れ", "lines": [
		["各章は 戦闘×3 → キャンプ → ボス。序盤の章のあと中盤の章があり、最後のボスで踏破。", INK],
		["勝つと報酬：武器3・妖精2 から1つ選ぶ（何も取らずに進むこともできる）。3枠が満杯なら1つと交換。", INK],
		["HPは次の戦闘へ持ち越し。勝つたびに +1 回復。妖精の使用回数は毎戦闘回復。", INK],
		["キャンプ：休む（HP+2）／武器を鍛える（攻撃+1）／妖精のクラスアップ。どれか1つ。", INK],
		["黄色い＋は強化済みのしるし。紫の縁の武器は「魔法陣」付き（次のページ）。", MUTED],
	]},
	{"title": "5. 特別なもの", "lines": [
		["魔法陣の武器：攻撃できない代わりに、歩いた跡が白いマスになる。白いマスで囲むと中の敵すべてに 99。", Color("c9b3ff")],
		["　斜めにつながっていても囲める。盤の端は壁にならない。移動先に乗せると囲める範囲が紫に光る。", Color("c9b3ff")],
		["レア妖精：最初のボスの後、まれに2×2の妖精が報酬に出る。", INK],
		["2×2のボスや敵は、4マスのどこを叩いても当たる。", INK],
		["わからなくなったら H キーでいつでもこの説明を開ける。", GOLD],
	]},
	{"title": "6. 操作", "lines": [
		["クリック：移動・攻撃・妖精の配置　　右クリック：敵の情報を固定", INK],
		["1〜3：武器の持ち替え　　4〜6：妖精を選ぶ　　Esc：取り消し", INK],
		["SPACE：ターン終了　　R：戦闘をやり直す　　H：この説明", INK],
		["履歴ボタン：これまでの出来事のログ", MUTED],
	]},
]

var page := 0
var body: VBoxContainer
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
	body = VBoxContainer.new()
	body.position = Vector2(28, 116)
	body.size = Vector2(744, 380)
	body.add_theme_constant_override("separation", 14)
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
	for entry in data.lines:
		var line := Label.new()
		line.text = entry[0]
		line.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		line.custom_minimum_size = Vector2(744, 0)
		line.add_theme_font_override("font", FONT)
		line.add_theme_font_size_override("font_size", 20)
		line.add_theme_color_override("font_color", entry[1])
		body.add_child(line)

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
