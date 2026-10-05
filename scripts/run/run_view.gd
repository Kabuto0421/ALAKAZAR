extends Node

const Run = preload("res://scripts/run/run_model.gd")
const DebugStart = preload("res://scripts/debug/debug_start.gd")
const BattleView = preload("res://scripts/battle_view.gd")
const Card = preload("res://scripts/run/choice_card.gd")
const Weapons = preload("res://scripts/run/weapon_catalog.gd")
const Diagram = preload("res://scripts/run/range_diagram.gd")
const PlusBadge = preload("res://scripts/items/plus_badge.gd")
const RarityFrame = preload("res://scripts/run/rarity_frame.gd")
const Rarity = preload("res://scripts/run/rarity.gd")
const LineBreak = preload("res://scripts/ui/line_break.gd")
## The loadout boxes wear the rarity frame of their card, thinner.
const SLOT_FRAME := 7.0
const SHEATH_EMPTY = preload("res://assets/sprites/spirits/sheath_fairy.png")
const HelpPanel = preload("res://scripts/ui/help_panel.gd")
var help: Control
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const LATIN = preload("res://assets/fonts/VT323-Regular.ttf")
const INK = Color("e5dfc5")
const CYAN = Color("2bdcc8")
const BgmPlayer = preload("res://scripts/audio/bgm_player.gd")
const Achievements = preload("res://scripts/title/achievements.gd")
const AchievementToast = preload("res://scripts/title/achievement_toast.gd")
## Announces achievements earned between fights (the meteor class-ups at the camp).
var toast := AchievementToast.new()
var run := Run.new()
var screen: Control
var battle_view: Node2D
## Music for the screens between fights (the battle view brings its own).
var bgm: Node

func _ready() -> void:
	bgm = BgmPlayer.new()
	add_child(bgm)
	add_child(toast)
	if DebugStart.pending:
		DebugStart.pending = false
		run.start_layer2(DebugStart.build)
	else:
		run.start()
	_render()

func _render() -> void:
	toast.show_new(Achievements.check(run.battle))
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
	var sub := Rarity.INFO
	match run.state:
		Run.State.START_WEAPON:
			_label(Vector2(44,48),"最初の武器を選ぶ",30,INK)
			_label(Vector2(44,94),"1 / 2   目指すは監獄の王。まず3本目の武器を選ぶ（前進剣 → と 後退剣 ← は持っている）。盤面は、その武器で動けるマス。",17,sub)
			_cards(run.offers)
			_loadout()
		Run.State.START_FAIRY:
			_label(Vector2(44,48),"最初の妖精を選ぶ",30,INK)
			_label(Vector2(44,94),"2 / 2   妖精は各戦闘1回・使うAPはカードに表示",17,sub)
			_cards(run.offers)
			_loadout()
			_button(Vector2(894,92),Vector2(214,34),"← 武器選択",_back_to_weapon)
		Run.State.REWARD:
			var cleared := "2層目 %d戦目クリア" % (run.layer2_stage + 1) if run.layer == 2 else "ボス撃破" if run.battle.BOSS_LEVELS.has(run.stage) else "中盤 %d クリア" % (run.battle.MID_LEVELS.find(run.stage)+1) if run.battle.MID_LEVELS.has(run.stage) else "終盤 %d クリア" % (run.battle.LATE_LEVELS.find(run.stage)+1) if run.battle.LATE_LEVELS.has(run.stage) else "戦闘 %d クリア" % (run.stage+1)
			_label(Vector2(44,48),"%s — 報酬を1つ選ぶ" % cleared,30,INK)
			if run.is_before_boss():
				_label(Vector2(44,94),"ボス前の特別報酬：アンコモン以上の武器が出やすい。",17,Color("ffd35b"))
			else:
				_label(Vector2(44,94),("妖精の使用回数が回復・勝利でHP+1（持ち越し）。" if run.win_heal() > 0 else "妖精の使用回数が回復（HPは持ち越し）。") + "武器3候補・妖精2候補。",17,sub)
				if run.battle.BOSS_LEVELS.has(run.stage):
					# The boss reward's fairy cards lean rarer (Run.BOSS_FAIRY_BONUS): said
					# beside the heading.
					var heading: float = FONT.get_string_size("%s — 報酬を1つ選ぶ" % cleared,HORIZONTAL_ALIGNMENT_LEFT,-1,30).x
					_label(Vector2(44+heading+20,60),"ボーナス：レア・激レアの妖精が出やすい",17,Color("ffd35b"))
			_cards(run.offers)
			_loadout()
			# A plain light-blue border so it reads as a choice of its own.
			if run.can_sheath_swap():
				_button(Vector2(664,92),Vector2(214,34),"鞘と入れ替える",_sheath_open)
			var skip := _button(Vector2(894,92),Vector2(214,34),"今の構成で進む",_skip)
			skip.add_theme_color_override("font_color",Color.WHITE)
			for state in ["normal","hover","pressed"]:
				var style := _box(Color("172b2b") if state != "normal" else Color("0c181b"),Rarity.INFO)
				style.set_border_width_all(3 if state != "normal" else 2)
				skip.add_theme_stylebox_override(state,style)
		Run.State.SHEATH:
			var inside: Dictionary = Weapons.DATA[run.battle.sheathed_weapon]
			_label(Vector2(44,48),"鞘の妖精 — 入れ替える武器を選ぶ",30,INK)
			_label(Vector2(44,94),"鞘の中：%s（%s）。選んだ武器と入れ替わる。鞘の武器は戦闘に出ない。" % [inside.name, inside.detail],17,Color(inside.color))
			var carried: Array[Dictionary] = []
			for index in run.battle.owned_weapons:
				carried.append({"kind":"weapon","value":index})
			carried.append({"kind":"weapon","value":run.battle.sheathed_weapon,"sheathed":true})
			_cards(carried,false,false,false,true)
			_loadout()
			_button(Vector2(894,92),Vector2(214,34),"← 戻る",_sheath_back)
		Run.State.REPLACE:
			var title: String = run.battle.WEAPONS[int(run.pending.value)].name if run.pending.kind=="weapon" else run.battle.item_definition(str(run.pending.value)).title
			var need: int = run.pending.get("remaining", [1]).size()
			if run.pending.kind == "weapon" and Weapons.is_pair_head(int(run.pending.value)):
				title = "クロス短剣"
			_label(Vector2(44,48),"「%s」と交換する装備を選ぶ" % title,30,INK)
			_label(Vector2(44,94),("所持上限は3。手放すものを%dつ選ぶ（短剣は2本セット）。" % need) if run.pending.kind == "weapon" and Weapons.is_pair_head(int(run.pending.value)) else "所持上限は3。手放すものを1つ選ぶ。",17,sub)
			_replace_cards()
			_button(Vector2(894,92),Vector2(214,34),"← 報酬へ戻る",_cancel)
		Run.State.CAMP:
			_label(Vector2(44,48),"キャンプ — ひとつだけ選ぶ",30,INK)
			_label(Vector2(44,94),"この先は最終ボス：監獄の王（10×10）" if run.stage == run.battle.LATE_LEVELS[3] else "この先は終盤の残り2戦（終盤3・4戦目）" if run.stage == run.battle.LATE_LEVELS[1] else ("この先はボス：嵐鮫（8×8・大嵐）" if run.battle.boss2_variant == 1 else "この先はボス：ロトリック（8×8）") if run.stage == run.battle.MID_LEVELS[-1] else "この先はボス：馬3体（7×7）" if run.battle.boss_variant == 0 else "この先はボス：突進くん＋移動監獄（6×6）",17,Color("ff987f"))
			_camp_option(0,"休む","HP +%d\n（最大%d）" % [Run.CAMP_HEAL, run.battle.MAX_HP],Color("ff8b8f"),_rest,run.battle.start_hp < run.battle.MAX_HP)
			_camp_option(1,"鍛える","武器を1本選び\n動いて攻撃できる\nマスを1つ増やす",Color("ffd35b"),_forge,run.can_forge())
			_camp_option(2,"妖精のクラスアップ","妖精を1体選び\n効果を強化\n（1体につき1回）",Color("7fe0c8"),_class_up,run.can_class_up())
			_loadout()
		Run.State.CAMP_FORGE:
			_label(Vector2(44,48),"鍛える武器を選ぶ",30,INK)
			_label(Vector2(44,94),"緑のマスのどれか1つが増える（普通の武器は何回でも）。激レアは鍛えられない。",17,sub)
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
			# Beaten: back to the title screen. A cleared run may also go straight to a new build.
			if won:
				_button(Vector2(260,515),Vector2(500,62),"初期ビルドを選び直す →",_restart)
				_button(Vector2(260,595),Vector2(500,62),"タイトルへ戻る →",_to_title)
			else:
				_button(Vector2(260,515),Vector2(500,62),"タイトルへ戻る →",_to_title)

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

func _cards(offers: Array, replacing: bool = false, forging: bool = false, upgrading: bool = false, sheathing: bool = false) -> void:
	var gap := 20.0 if offers.size() < 5 else 14.0
	# Fairy cards lead with a wide animated example, weapon cards with a small square
	# diagram: when both are offered, fairy cards get the extra width.
	var mixed := offers.any(func(o: Dictionary) -> bool: return o.kind == "weapon") and offers.any(func(o: Dictionary) -> bool: return o.kind != "weapon")
	var weights: Array[float] = []
	for offer in offers:
		# A weapon with an effect to explain keeps the full width for its text.
		weights.append(0.7 if mixed and offer.kind == "weapon" and not Weapons.DATA[int(offer.value)].has("effect") else 1.0)
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
		card.show_pair = run.state in [Run.State.REWARD]
		card.model = run.battle
		card.action_text = "鞘へ入れる" if sheathing else "これと交換" if replacing else "鍛える" if forging else "強化する" if upgrading else "選んで出発" if run.state == Run.State.START_FAIRY else "選ぶ"
		if not upgrading:
			_compare(card, coverage, forging)
		if sheathing and offers[index].get("sheathed", false):
			card.disabled = true
			card.tag = "鞘の中"
			card.note = "ここに入っている"
			card.action_text = ""
		if forging or upgrading:
			# Camp: the card shows the result; items already improved cannot be picked again.
			var done: bool = not run.can_forge_weapon(int(card.offer.value)) if forging else not run.battle.can_class_up(str(card.offer.value))
			card.preview_plus = not done
			if forging and not done and run.camp_tiles.has(int(card.offer.value)):
				card.extra_tile = run.camp_tiles[int(card.offer.value)]
			card.disabled = done
			if done:
				card.tag = "強化できない" if forging and (not Rarity.can_forge(int(card.offer.value)) or Weapons.forge_kind(int(card.offer.value)) == "tile") else "強化済み"
				card.modulate = Color(1,1,1,0.45)
				card.note = ""
				card.action_text = ""
			elif upgrading:
				card.tag = "進化" if run.battle.EVOLUTIONS.has(str(card.offer.value)) else "クラスアップ後"
		if sheathing:
			card.pressed.connect(func():
				if index < run.battle.owned_weapons.size() and run.sheath_swap(index):
					_render())
		elif upgrading:
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
			# Forging never adds attack power: it adds a tile, widens a blow, or the like.
			match Weapons.forge_kind(index):
				"tile":
					card.note = "動いて攻撃できるマス +1"
				"area":
					card.note = "叩く範囲が広がる"
				"charge":
					card.note = "溜められる量 +1"
				"bow":
					card.note = "射程が斜めの端まで"
				"swap":
					card.note = "毎ターン最初の入れ替えが0 AP"
				_:
					card.note = ""
			card.note_color = Color("ffd35b")
			return
		var added := Weapons.offsets(index).filter(func(o: Vector2i) -> bool: return not coverage.has(o)).size()
		card.note = "新しく届く +%dマス" % added if added > 0 else "届く範囲は増えない"
		card.note_color = GOOD if added > 0 else Rarity.INFO
		if offer.get("enchant", "") == "circle":
			card.tag = "魔法陣武器"
			card.note = "囲むと99ダメージ"
			card.note_color = Card.ENCHANT
		if run.state == Run.State.REWARD and run.battle.owned_weapons.size() >= run.battle.WEAPON_LIMIT:
			card.action_text = "選んで交換"  # the loadout is full
	else:
		var id := str(offer.value)
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
	incoming.show_pair = true
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

## The owned weapons and fairies along the bottom. In layer 2 the sheath fairy sits between them
## holding its weapon, so the panel is a little wider and the slots a little narrower.
func _loadout() -> void:
	var top := 504.0
	var sheathed: int = run.battle.sheathed_weapon
	var wide := sheathed >= 0
	var panel_left := 24.0 if wide else 44.0
	var weapon_left := 36.0 if wide else 56.0
	var weapon_step := 140.0 if wide else 160.0
	var weapon_width := 132.0 if wide else 150.0
	var sheath_left := weapon_left + weapon_step * 2.0 + weapon_width + 12.0
	var sheath_width := 160.0
	var fairy_left := sheath_left + sheath_width + 12.0 if wide else 544.0
	var fairy_step := 160.0 if wide else 184.0
	var fairy_width := 152.0 if wide else 174.0
	var panel := Panel.new()
	panel.position = Vector2(panel_left,top)
	panel.size = Vector2(1092 if wide else 1064,200)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",_box(Color("0a1417"),Color("23403f")))
	screen.add_child(panel)
	var weapons: Array = run.battle.owned_weapons
	var fairies: Array = run.battle.fairy_loadout
	_label(Vector2(weapon_left+2,top+6),"所持武器 %d/%d" % [weapons.size(), run.battle.WEAPON_LIMIT],15,Rarity.INFO)
	if wide:
		_label(Vector2(sheath_left+2,top+6),"鞘の妖精",15,Rarity.INFO)
	_label(Vector2(fairy_left+2,top+6),"所持妖精 %d/%d" % [fairies.size(), run.battle.HAND_LIMIT],15,Rarity.INFO)
	for slot in run.battle.WEAPON_LIMIT:
		var at := Vector2(weapon_left+slot*weapon_step,top+30)
		if slot >= weapons.size():
			_empty_slot(at,Vector2(weapon_width,160))
			continue
		_weapon_box(at,weapon_width,weapons[slot])
	if wide:
		_weapon_box(Vector2(sheath_left,top+30),sheath_width,sheathed,_sheath_art(sheathed))
	for slot in run.battle.HAND_LIMIT:
		var at := Vector2(fairy_left+slot*fairy_step,top+30)
		if slot >= fairies.size():
			_empty_slot(at,Vector2(fairy_width,160))
			continue
		var item: Resource = run.battle.item_definition(str(fairies[slot]))
		var box := Panel.new()
		box.position = at
		box.size = Vector2(fairy_width,160)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_stylebox_override("panel",_box(Color("0c181b"),Color(item.color,0.6)))
		screen.add_child(box)
		_frame(at,box.size,Rarity.tier({"kind":"fairy","value":str(fairies[slot])}))
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = item.icon
		icon.position = at+Vector2((fairy_width-76)/2,10)
		icon.size = Vector2(76,76)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(icon)
		var plus: bool = run.battle.is_plus(str(fairies[slot]))
		if plus:
			_badge(icon.position+Vector2(84,0),20)
		_title(at+Vector2(10,90),item.title,17,plus)
		_summary(_label(at+Vector2(10,116),run.battle.fairy_summary(str(fairies[slot])),14,Rarity.INFO),fairy_width-20)

## The sheath fairy's picture, flipped, resting on the upper right corner of the weapon's frame.
func _sheath_art(_index: int) -> Texture2D:
	return SHEATH_EMPTY

## One weapon box of the loadout (the sheath fairy's too, with the fairy leaning on the frame's corner).
func _weapon_box(at: Vector2, width: float, index: int, backdrop: Texture2D = null) -> void:
	var data: Dictionary = Weapons.DATA[index]
	var accent := Color(data.color)
	var box := Panel.new()
	box.position = at
	box.size = Vector2(width,160)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel",_box(Color("0c181b"),Color(accent,0.6)))
	screen.add_child(box)
	_frame(at,box.size,Rarity.tier({"kind":"weapon","value":index,"enchant":run.battle.enchants.get(index,"")}))
	if backdrop != null:
		var art := TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture = backdrop
		art.flip_h = true
		art.position = at+Vector2(width-39,-29)
		art.size = Vector2(54,54)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(art)
	var diagram := Diagram.new()
	var diagram_side := 78.0
	diagram.position = at+Vector2((width-diagram_side)/2,10)
	diagram.size = Vector2(diagram_side,diagram_side)
	diagram.offsets = run.battle.weapon_offsets(index)
	var owned_extra: Array[Vector2i] = []
	for tile in run.battle.weapon_extra.get(index, []):
		owned_extra.append(Vector2i(tile))
	diagram.extra = owned_extra
	diagram.slides = Weapons.slides(index)
	diagram.echo = Weapons.hammer_echo(index, run.battle.weapon_power.has(index))
	diagram.attack = Weapons.attack_offsets(index, run.battle.weapon_power.has(index))
	diagram.hammer = Weapons.is_hammer(index)
	diagram.accent = accent
	screen.add_child(diagram)
	_title(at+Vector2(10,90),data.name,17,run.battle.weapon_power.has(index))
	if run.battle.weapon_power.has(index):
		_badge(diagram.position+Vector2(92,-2),20)
	var damage: int = run.battle.weapon_damage(index)
	if run.battle.is_circle(index):
		_label(at+Vector2(10,116),"魔法陣・攻撃不可",14,Card.ENCHANT)
	else:
		_summary(_label(at+Vector2(10,116),("ノックバック" if damage <= 0 else "攻撃%d・ノックバック" % damage) if Weapons.knockback(index) > 0 else ("入れ替え・初回0 AP" if run.battle.weapon_power.has(index) else "入れ替え") if Weapons.DATA[index].get("swap", false) else "攻撃 %d" % damage,14,Color("ffd35b") if damage > 1 else Rarity.INFO),width-20)

## A name with a yellow "+" after it when the item is upgraded.
func _title(at: Vector2, text: String, font_size: int, plus: bool) -> void:
	var label := _label(at,text,font_size,Color("eee7d2"))
	if plus:
		var width: float = label.get_theme_font("font").get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		_label(at+Vector2(width+2,0),"+",font_size,Color("ffd35b"))

## A summary too long for one line at 14px tries 13px, then wraps onto two lines
## (after a separator or particle, so no lone character is left on the second line).
func _summary(label: Label, width: float) -> void:
	var font: Font = label.get_theme_font("font")
	for font_size in [14, 13]:
		if font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x <= width:
			label.add_theme_font_size_override("font_size",font_size)
			return
	label.add_theme_font_size_override("font_size",13)
	label.add_theme_constant_override("line_spacing",-3)
	label.text = LineBreak.split(label.text,font,13,width)

func _frame(at: Vector2, extent: Vector2, tier: int) -> void:
	var frame := RarityFrame.new()
	frame.tier = tier
	frame.thickness = SLOT_FRAME
	frame.position = at
	frame.size = extent
	screen.add_child(frame)

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

const TITLE_SCENE := "res://title.tscn"

func _to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)

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

func _sheath_open() -> void:
	if run.sheath_open():
		_render()

func _sheath_back() -> void:
	run.sheath_back()
	_render()

func _cancel() -> void:
	run.cancel_replace()
	_render()
