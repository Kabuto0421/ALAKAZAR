extends Node

const Run = preload("res://scripts/run/run_model.gd")
const BattleView = preload("res://scripts/battle_view.gd")
const Card = preload("res://scripts/run/choice_card.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const LATIN = preload("res://assets/fonts/VT323-Regular.ttf")
const INK = Color("e5dfc5")
const CYAN = Color("2bdcc8")
var run := Run.new()
var screen: Control
var battle_view: Node2D

func _ready() -> void:
	run.start()
	_render()

func _render() -> void:
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
		screen = null
	if is_instance_valid(battle_view):
		remove_child(battle_view)
		battle_view.queue_free()
		battle_view = null
	if run.state == Run.State.BATTLE:
		battle_view = BattleView.new()
		battle_view.managed_run = true
		battle_view.model = run.battle
		battle_view.finished.connect(_battle_finished)
		add_child(battle_view)
		return
	screen = Control.new()
	screen.name = "DraftScreen"
	screen.size = Vector2(1152,720)
	screen.scale = Vector2.ONE*1.5
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 23
	screen.theme = theme
	add_child(screen)
	var backdrop := ColorRect.new()
	backdrop.size = screen.size
	backdrop.color = Color("080f13")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(backdrop)
	_label(Vector2(44,24),"ALAKAZAR",32,CYAN).add_theme_font_override("font",LATIN)
	_label(Vector2(795,35),"4 × 4  →  5 × 5  →  6 × 6",20,Color("9aafa9"))
	match run.state:
		Run.State.START_WEAPON:
			_label(Vector2(44,85),"最初の武器を選ぶ",36,INK)
			_label(Vector2(44,137),"1 / 2    前進剣 → と 後退剣 ← に、3本目を追加",22,Color("9aafa9"))
			_cards(run.offers)
			_label(Vector2(44,665),"明るいマスが移動・攻撃範囲。全武器1ダメージ、持ち替え0 AP。",20,INK)
		Run.State.START_FAIRY:
			_label(Vector2(44,85),"最初の妖精を選ぶ",36,INK)
			_label(Vector2(44,137),"2 / 2    妖精は各戦闘1回・使用1 AP",22,Color("9aafa9"))
			_cards(run.offers)
			_loadout()
			_button(Vector2(44,668),Vector2(152,36),"← 武器選択",_restart)
		Run.State.REWARD:
			_label(Vector2(44,85),"戦闘 %d クリア — 報酬を1つ選ぶ" % (run.stage+1),32,INK)
			_label(Vector2(44,137),"妖精の使用回数が回復。武器2候補・妖精2候補。",22,Color("9aafa9"))
			_cards(run.offers)
			_loadout()
			_button(Vector2(895,670),Vector2(214,36),"今の構成で進む",_skip)
		Run.State.REPLACE:
			var title: String = run.battle.WEAPONS[int(run.pending.value)].name if run.pending.kind=="weapon" else run.battle.item_definition(str(run.pending.value)).title
			_label(Vector2(44,85),"「%s」と交換する装備を選ぶ" % title,30,INK)
			_label(Vector2(44,137),"所持上限は3。選んだ装備を手放します。",22,Color("9aafa9"))
			var owned: Array[Dictionary] = []
			if run.pending.kind == "weapon":
				for index in run.battle.owned_weapons:
					owned.append({"kind":"weapon","value":index})
			else:
				for id in run.battle.fairy_loadout:
					owned.append({"kind":"fairy","value":id})
			_cards(owned,true)
			_button(Vector2(44,665),Vector2(230,40),"← 報酬へ戻る",_cancel)
		Run.State.FINISHED, Run.State.LOST:
			var won: bool = run.state == Run.State.FINISHED
			_label(Vector2(260,170),"全3戦クリア！" if won else "探索終了",52,CYAN if won else Color("ff987f"))
			_label(Vector2(260,249),"完成した構成で包囲網を突破した" if won else "別の武器と妖精でもう一度",25,INK)
			var owned: Array[Dictionary] = []
			for index in run.battle.owned_weapons:
				owned.append({"kind":"weapon","value":index})
			for slot in owned.size():
				var weapon: Dictionary = run.battle.WEAPONS[int(owned[slot].value)]
				_label(Vector2(260,320+slot*42),weapon.name+"  /  "+weapon.detail,23,Color(weapon.color))
			_button(Vector2(260,515),Vector2(500,62),"初期ビルドを選び直す →",_restart)

func _cards(offers: Array, replacing: bool = false) -> void:
	var gap := 20.0
	var width := (1064-gap*(offers.size()-1))/offers.size()
	for index in offers.size():
		var card := Card.new()
		card.position = Vector2(44+index*(width+gap),187)
		card.size = Vector2(width,440)
		card.offer = offers[index]
		card.model = run.battle
		card.action_text = "これと交換" if replacing else "選んで出発" if run.state == Run.State.START_FAIRY else "選ぶ"
		if replacing:
			card.pressed.connect(func():
				if run.replace(index):
					_render())
		else:
			card.pressed.connect(func():
				if run.choose(index):
					_render())
		screen.add_child(card)

func _loadout() -> void:
	var names: Array[String] = []
	for index in run.battle.owned_weapons:
		names.append(run.battle.WEAPONS[index].name)
	_label(Vector2(44,638),"武器："+" / ".join(names),19,Color("9aafa9"))

func _label(at: Vector2,value: String,font_size: int,color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(label)
	return label

func _button(at: Vector2,extent: Vector2,value: String,callback: Callable) -> Button:
	var button := Button.new()
	button.position = at
	button.size = extent
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size",21)
	button.pressed.connect(callback)
	screen.add_child(button)
	return button

func _battle_finished() -> void:
	if run.finish_battle():
		_render()

func _restart() -> void:
	run.start()
	_render()

func _skip() -> void:
	run.skip_reward()
	_render()

func _cancel() -> void:
	run.cancel_replace()
	_render()
