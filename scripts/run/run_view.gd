extends Node

const Run = preload("res://scripts/run/run_model.gd")
const BattleView = preload("res://scripts/battle_view.gd")
const Card = preload("res://scripts/run/choice_card.gd")
const Weapons = preload("res://scripts/run/weapon_catalog.gd")
const Diagram = preload("res://scripts/run/range_diagram.gd")
const PlusBadge = preload("res://scripts/items/plus_badge.gd")
const HelpPanel = preload("res://scripts/ui/help_panel.gd")
var help: Control
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const LATIN = preload("res://assets/fonts/VT323-Regular.ttf")
const INK = Color("e5dfc5")
const CYAN = Color("2bdcc8")
const BgmPlayer = preload("res://scripts/audio/bgm_player.gd")
var run := Run.new()
var screen: Control
var battle_view: Node2D
## Music for the screens between fights (the battle view brings its own).
var bgm: Node

func _ready() -> void:
	bgm = BgmPlayer.new()
	add_child(bgm)
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
		bgm.player.stop()
		bgm.player.stream = null
		battle_view = BattleView.new()
		battle_view.managed_run = true
		battle_view.model = run.battle
		battle_view.finished.connect(_battle_finished)
		add_child(battle_view)
		return
	# Camp tune at the camp; the draft tune for picks, rewards and the end screens.
	bgm.theme = "camp" if run.state in [Run.State.CAMP, Run.State.CAMP_FORGE, Run.State.CAMP_FAIRY] else "draft"
	bgm.sync(false, false)
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
	_label(Vector2(44,14),"ALAKAZAR",30,CYAN).add_theme_font_override("font",LATIN)
	_button(Vector2(894,12),Vector2(214,32),"遊び方 [H]",_open_help)
	if run.state not in [Run.State.START_WEAPON, Run.State.START_FAIRY]:
		_label(Vector2(972,50),"HP %d / %d" % [run.battle.start_hp, run.battle.MAX_HP],24,Color("ff8b8f"))
	else:
		# Optional rules, off by default: the plain game stays as it is.
		_rule_toggle(Vector2(292,12),"rule_siege","包囲の輪","4ターンごとに外周から1周ずつ包囲される。\n包囲の中にいると敵ターン開始時に1ダメージ（敵も）。\n次に狭まる輪は赤く点滅する。")
		_rule_toggle(Vector2(492,12),"rule_friendly","同士討ち","投げ槍は範囲の敵にも当たる。\n突進は、止められた敵・壁に挟まれた敵にも1ダメージ。\n（弓の矢は元から敵にも当たる）")
		_rule_toggle(Vector2(692,12),"rule_combo","連撃","1回の行動で2体以上倒すとAPが1戻る。")
	var sub := Color("9aafa9")
	match run.state:
		Run.State.START_WEAPON:
			_label(Vector2(44,48),"最初の武器を選ぶ",30,INK)
			_label(Vector2(44,94),"1 / 2   前進剣 → と 後退剣 ← に3本目を追加。小さな盤面はその武器で動けるマス。",17,sub)
			_cards(run.offers)
			_loadout()
		Run.State.START_FAIRY:
			_label(Vector2(44,48),"最初の妖精を選ぶ",30,INK)
			_label(Vector2(44,94),"2 / 2   妖精は各戦闘1回・使用1 AP",17,sub)
			_cards(run.offers)
			_loadout()
			_button(Vector2(894,92),Vector2(214,34),"← 武器選択",_back_to_weapon)
		Run.State.REWARD:
			var cleared := "ボス撃破" if run.battle.BOSS_LEVELS.has(run.stage) else "中盤 %d クリア" % (run.battle.MID_LEVELS.find(run.stage)+1) if run.battle.MID_LEVELS.has(run.stage) else "終盤 %d クリア" % (run.battle.LATE_LEVELS.find(run.stage)+1) if run.battle.LATE_LEVELS.has(run.stage) else "戦闘 %d クリア" % (run.stage+1)
			_label(Vector2(44,48),"%s — 報酬を1つ選ぶ" % cleared,30,INK)
			if run.is_before_boss():
				_label(Vector2(44,94),"ボス前の特別報酬：武器は3マスの強い武器から。",17,Color("ffd35b"))
			else:
				_label(Vector2(44,94),("妖精の使用回数が回復・勝利でHP+1（持ち越し）。" if run.win_heal() > 0 else "妖精の使用回数が回復（HPは持ち越し）。") + "武器3候補・妖精2候補。",17,sub)
			_cards(run.offers)
			_loadout()
			_button(Vector2(894,92),Vector2(214,34),"今の構成で進む",_skip)
		Run.State.REPLACE:
			var title: String = run.battle.WEAPONS[int(run.pending.value)].name if run.pending.kind=="weapon" else run.battle.item_definition(str(run.pending.value)).title
			_label(Vector2(44,48),"「%s」と交換する装備を選ぶ" % title,30,INK)
			_label(Vector2(44,94),"所持上限は3。手放すものを1つ選ぶ。",17,sub)
			_replace_cards()
			_button(Vector2(894,92),Vector2(214,34),"← 報酬へ戻る",_cancel)
		Run.State.CAMP:
			_label(Vector2(44,48),"キャンプ — ひとつだけ選ぶ",30,INK)
			_label(Vector2(44,94),"この先は最終ボス：監獄の王（10×10）" if run.stage == run.battle.LATE_LEVELS[2] else "この先は終盤の最後の戦い（8×8・突進くん＋移動監獄）" if run.stage == run.battle.LATE_LEVELS[1] else "この先はボス：ロトリック（8×8）" if run.stage == run.battle.MID_LEVELS[-1] else "この先はボス：馬3体（7×7）" if run.battle.boss_variant == 0 else "この先はボス：突進くん＋移動監獄（6×6）",17,Color("ff987f"))
			_camp_option(0,"休む","HP +%d\n（最大%d）" % [Run.CAMP_HEAL, run.battle.MAX_HP],Color("ff8b8f"),_rest,run.battle.start_hp < run.battle.MAX_HP)
			_camp_option(1,"鍛える","武器を1本選び\n攻撃力 +1\n（1本につき1回）",Color("ffd35b"),_forge,run.can_forge())
			_camp_option(2,"妖精のクラスアップ","妖精を1体選び\n効果を強化\n（1体につき1回）",Color("7fe0c8"),_class_up,run.can_class_up())
			_loadout()
		Run.State.CAMP_FORGE:
			_label(Vector2(44,48),"鍛える武器を選ぶ",30,INK)
			_label(Vector2(44,94),"選んだ武器の攻撃力が +1 される。鍛えられるのは1本につき1回。",17,sub)
			var owned_weapons: Array[Dictionary] = []
			for index in run.battle.owned_weapons:
				owned_weapons.append({"kind":"weapon","value":index})
			_cards(owned_weapons,false,true)
			_loadout()
			_button(Vector2(894,92),Vector2(214,34),"← キャンプへ戻る",_camp_back)
		Run.State.CAMP_FAIRY:
			_label(Vector2(44,48),"クラスアップする妖精を選ぶ",30,INK)
			_label(Vector2(44,94),"カードは強化後の姿。強化できるのは1体につき1回。",17,sub)
			_cards(run.offers,false,false,true)
			_loadout()
			_button(Vector2(894,92),Vector2(214,34),"← キャンプへ戻る",_camp_back)
		Run.State.FINISHED, Run.State.LOST:
			var won: bool = run.state == Run.State.FINISHED
			_label(Vector2(260,170),"遠征達成！" if won else "探索終了",52,CYAN if won else Color("ff987f"))
			_label(Vector2(260,249),"監獄の王を倒し、遠征を踏破した" if won else "別の武器と妖精でもう一度",25,INK)
			var owned: Array[Dictionary] = []
			for index in run.battle.owned_weapons:
				owned.append({"kind":"weapon","value":index})
			for slot in owned.size():
				var weapon: Dictionary = run.battle.WEAPONS[int(owned[slot].value)]
				_label(Vector2(260,320+slot*42),weapon.name+"  /  "+weapon.detail,23,Color(weapon.color))
			_button(Vector2(260,515),Vector2(500,62),"初期ビルドを選び直す →",_restart)

const CARD_TOP := 136.0
const CARD_HEIGHT := 350.0
const GOOD := Color("7be08a")

## Every tile the owned weapons reach.
func _coverage() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for index in run.battle.owned_weapons:
		for offset in Weapons.offsets(index):
			if not tiles.has(offset):
				tiles.append(offset)
	return tiles

func _cards(offers: Array, replacing: bool = false, forging: bool = false, upgrading: bool = false) -> void:
	var gap := 20.0 if offers.size() < 5 else 14.0
	# Fairy cards lead with a wide animated example, weapon cards with a small square
	# diagram: when both are offered, fairy cards get the extra width.
	var mixed := offers.any(func(o: Dictionary) -> bool: return o.kind == "weapon") and offers.any(func(o: Dictionary) -> bool: return o.kind != "weapon")
	var weights: Array[float] = []
	for offer in offers:
		weights.append(0.7 if mixed and offer.kind == "weapon" else 1.0)
	var total := 0.0
	for weight in weights:
		total += weight
	var unit := (1064-gap*(offers.size()-1))/total
	var coverage := _coverage()
	var x := 44.0
	for index in offers.size():
		var width: float = unit*weights[index]
		var card := Card.new()
		card.position = Vector2(x,CARD_TOP)
		x += width+gap
		card.size = Vector2(width,CARD_HEIGHT)
		card.offer = offers[index]
		card.model = run.battle
		card.action_text = "これと交換" if replacing else "鍛える" if forging else "強化する" if upgrading else "選んで出発" if run.state == Run.State.START_FAIRY else "選ぶ"
		if not upgrading:
			_compare(card, coverage, forging)
		if forging or upgrading:
			# Camp: the card shows the result; items already improved cannot be picked again.
			var done: bool = (run.battle.weapon_power.has(int(card.offer.value)) or not Weapons.can_forge(int(card.offer.value))) if forging else not run.battle.can_class_up(str(card.offer.value))
			card.preview_plus = not done
			card.disabled = done
			if done:
				card.tag = "強化できない" if forging and not Weapons.can_forge(int(card.offer.value)) else "強化済み"
				card.modulate = Color(1,1,1,0.45)
				card.note = ""
				card.action_text = ""
			elif upgrading:
				card.tag = "進化" if run.battle.EVOLUTIONS.has(str(card.offer.value)) else "クラスアップ後"
		if upgrading:
			card.pressed.connect(func():
				if run.camp_class_up_fairy(index):
					_render())
		elif forging:
			card.pressed.connect(func():
				if run.camp_forge_weapon(index):
					_render())
		elif replacing:
			card.pressed.connect(func():
				if run.replace(index):
					_render())
		else:
			card.pressed.connect(func():
				if run.choose(index):
					_render())
		screen.add_child(card)

## Tells an offer card how it compares with the current loadout.
func _compare(card: Card, coverage: Array[Vector2i], forging: bool) -> void:
	var offer: Dictionary = card.offer
	if offer.kind == "weapon":
		var index := int(offer.value)
		if forging:
			var damage: int = run.battle.weapon_damage(index)
			card.note = "攻撃 %d → %d" % [damage, damage+1]
			card.note_color = Color("ffd35b")
			return
		var added := Weapons.offsets(index).filter(func(o: Vector2i) -> bool: return not coverage.has(o)).size()
		card.note = "新しく届く +%dマス" % added if added > 0 else "届く範囲は増えない"
		card.note_color = GOOD if added > 0 else Color("92b3ae")
		if offer.get("enchant", "") == "circle":
			card.tag = "魔法陣の武器"
			card.note = "囲むと99ダメージ"
			card.note_color = Card.ENCHANT
		if run.state == Run.State.REWARD and run.battle.owned_weapons.size() >= run.battle.WEAPON_LIMIT:
			card.action_text = "選んで交換"  # the loadout is full
	else:
		var id := str(offer.value)
		if offer.get("rare", false):
			card.tag = "レア妖精"
			card.note = "ボスのレアドロップ"
			card.note_color = Color("ffd35b")
		if run.battle.fairy_loadout.has(id):
			card.note = "同じ妖精を所持中"
			card.note_color = Color("ffd35b")
		if run.state == Run.State.REWARD and run.battle.fairy_loadout.size() >= run.battle.HAND_LIMIT:
			card.action_text = "選んで交換"

## Replacement: the incoming item on the left, the owned ones to give up on the right.
func _replace_cards() -> void:
	var weapon: bool = run.pending.kind == "weapon"
	var holder := Control.new()
	holder.position = Vector2(44,CARD_TOP)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(holder)
	var incoming := Card.new()
	incoming.size = Vector2(236,CARD_HEIGHT)
	incoming.offer = run.pending
	incoming.model = run.battle
	incoming.tag = "入手する"
	incoming.action_text = ""
	incoming.disabled = true
	incoming.mouse_default_cursor_shape = Control.CURSOR_ARROW
	holder.add_child(incoming)
	_label(Vector2(284,CARD_TOP+CARD_HEIGHT/2-20),"⇄",28,INK)
	var slots: int = run.battle.owned_weapons.size() if weapon else run.battle.fairy_loadout.size()
	var gap := 16.0
	var left := 318.0
	var width := (1108-left-gap*(slots-1))/slots
	for slot in slots:
		var card := Card.new()
		card.position = Vector2(left+slot*(width+gap),CARD_TOP)
		card.size = Vector2(width,CARD_HEIGHT)
		card.model = run.battle
		card.action_text = "これを手放す"
		card.tag = "所持中"
		# Kept plain on purpose: the new item on the left, what you would give up on the right.
		card.offer = {"kind":"weapon","value":run.battle.owned_weapons[slot]} if weapon else {"kind":"fairy","value":run.battle.fairy_loadout[slot]}
		card.pressed.connect(func():
			if run.replace(slot):
				_render())
		screen.add_child(card)

## The owned weapons and fairies along the bottom.
func _loadout() -> void:
	var top := 504.0
	var panel := Panel.new()
	panel.position = Vector2(44,top)
	panel.size = Vector2(1064,200)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",_box(Color("0a1417"),Color("23403f")))
	screen.add_child(panel)
	var weapons: Array = run.battle.owned_weapons
	var fairies: Array = run.battle.fairy_loadout
	_label(Vector2(58,top+6),"所持武器 %d/%d" % [weapons.size(), run.battle.WEAPON_LIMIT],15,Color("9aafa9"))
	_label(Vector2(546,top+6),"所持妖精 %d/%d" % [fairies.size(), run.battle.HAND_LIMIT],15,Color("9aafa9"))
	for slot in run.battle.WEAPON_LIMIT:
		var at := Vector2(56+slot*160,top+30)
		if slot >= weapons.size():
			_empty_slot(at,Vector2(150,160))
			continue
		var index: int = weapons[slot]
		var data: Dictionary = Weapons.DATA[index]
		var accent := Color(data.color)
		var box := Panel.new()
		box.position = at
		box.size = Vector2(150,160)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_stylebox_override("panel",_box(Color("0c181b"),Color(accent,0.6)))
		screen.add_child(box)
		var diagram := Diagram.new()
		diagram.position = at+Vector2(29,6)
		diagram.size = Vector2(92,92)
		diagram.offsets = Weapons.offsets(index)
		diagram.slides = Weapons.slides(index)
		diagram.accent = accent
		screen.add_child(diagram)
		_title(at+Vector2(10,104),data.name,17,run.battle.weapon_power.has(index))
		if run.battle.weapon_power.has(index):
			_badge(diagram.position+Vector2(104,-6),20)
		var damage: int = run.battle.weapon_damage(index)
		if run.battle.is_circle(index):
			_label(at+Vector2(10,130),"魔法陣・攻撃不可",14,Card.ENCHANT)
		else:
			_label(at+Vector2(10,130),"攻撃 %d" % damage + ("  押し出し" if Weapons.knockback(index) > 0 else ""),14,Color("ffd35b") if damage > 1 else Color("92b3ae"))
	for slot in run.battle.HAND_LIMIT:
		var at := Vector2(544+slot*184,top+30)
		if slot >= fairies.size():
			_empty_slot(at,Vector2(174,160))
			continue
		var item: Resource = run.battle.item_definition(str(fairies[slot]))
		var box := Panel.new()
		box.position = at
		box.size = Vector2(174,160)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_stylebox_override("panel",_box(Color("0c181b"),Color(item.color,0.6)))
		screen.add_child(box)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = item.icon
		icon.position = at+Vector2(42,6)
		icon.size = Vector2(90,90)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(icon)
		var plus: bool = run.battle.is_plus(str(fairies[slot]))
		if plus:
			_badge(icon.position+Vector2(94,-2),20)
		_title(at+Vector2(10,104),item.title,17,plus)
		_label(at+Vector2(10,130),run.battle.fairy_summary(str(fairies[slot])),14,Color(item.color))

## A name with a yellow "+" after it when the item is upgraded.
func _title(at: Vector2, text: String, font_size: int, plus: bool) -> void:
	var label := _label(at,text,font_size,Color("eee7d2"))
	if plus:
		var width: float = label.get_theme_font("font").get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		_label(at+Vector2(width+2,0),"+",font_size,Color("ffd35b"))

func _badge(corner: Vector2, side: float) -> void:
	var badge := PlusBadge.new()
	badge.position = corner-Vector2(side,0)
	badge.size = Vector2.ONE*side
	screen.add_child(badge)

func _empty_slot(at: Vector2, extent: Vector2) -> void:
	var box := Panel.new()
	box.position = at
	box.size = extent
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel",_box(Color("08111a",0.0),Color("2c3d3d")))
	screen.add_child(box)
	_label(at+extent/2-Vector2(15,12),"空き",15,Color("4b6663"))

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

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

func _rule_toggle(at: Vector2, key: String, title: String, tip: String) -> void:
	var on: bool = run.battle.get(key)
	var button := _button(at,Vector2(190,32),("● " if on else "○ ") + title + ("  ON" if on else "  OFF"),func():
		run.battle.set(key, not run.battle.get(key))
		_render())
	button.tooltip_text = tip
	button.add_theme_color_override("font_color", Color("ffd35b") if on else Color("7f9591"))

func _open_help() -> void:
	if not is_instance_valid(screen):
		return
	if not is_instance_valid(help) or help.get_parent() != screen:
		help = HelpPanel.new()
		help.size = screen.size
		screen.add_child(help)
	help.visible = true
	help.move_to_front()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_H and is_instance_valid(screen):
		if is_instance_valid(help) and help.visible:
			help.close()
		else:
			_open_help()

func _battle_finished() -> void:
	if run.finish_battle():
		_render()

func _restart() -> void:
	run.start()
	_render()

func _back_to_weapon() -> void:
	run.back_to_weapon()
	_render()

func _skip() -> void:
	run.skip_reward()
	_render()

func _camp_option(index: int, title: String, detail: String, accent: Color, callback: Callable, enabled: bool) -> void:
	var button := Button.new()
	button.position = Vector2(44+index*362,CARD_TOP)
	button.size = Vector2(340,CARD_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not enabled
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("172b2b") if state in ["hover","pressed"] else Color("0c181b")
		style.border_color = accent if state != "disabled" else Color("40514f")
		style.set_border_width_all(3 if state in ["hover","pressed"] else 1)
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override(state,style)
	button.pressed.connect(callback)
	screen.add_child(button)
	_label(button.position+Vector2(20,24),title,30,accent if enabled else Color("5b6e6a"))
	_label(button.position+Vector2(20,110),detail,24,INK if enabled else Color("5b6e6a"))
	_label(button.position+Vector2(20,CARD_HEIGHT-56),"選ぶ  →" if enabled else "—",23,accent if enabled else Color("5b6e6a"))

func _rest() -> void:
	if run.camp_rest():
		_render()

func _class_up() -> void:
	if run.camp_class_up():
		_render()

func _forge() -> void:
	if run.camp_forge():
		_render()

func _camp_back() -> void:
	run.camp_back()
	_render()

func _cancel() -> void:
	run.cancel_replace()
	_render()
