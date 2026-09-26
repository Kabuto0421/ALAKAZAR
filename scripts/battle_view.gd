extends Node2D

signal finished
var managed_run := false

const Rules = preload("res://scripts/battle_model.gd")
const Planner = preload("res://scripts/enemy_planner.gd")
const WeaponEffect = preload("res://scripts/weapon_effect.gd")
const UnitView = preload("res://scripts/unit_view.gd")
const InventoryView = preload("res://scripts/items/inventory_view.gd")
const ItemPreview = preload("res://scripts/items/item_preview.gd")
const SpiritIcon = preload("res://scripts/items/spirit_icon.gd")
const RangeDiagram = preload("res://scripts/run/range_diagram.gd")
const DirectionSheet = preload("res://scripts/items/direction_sheet.gd")
const BgmPlayer = preload("res://scripts/audio/bgm_player.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const LATIN = preload("res://assets/fonts/VT323-Regular.ttf")
const HP_EMPTY = preload("res://assets/sprites/editor_ui/part_capacity_unit_empty.png")
const HP_FULL = preload("res://assets/sprites/editor_ui/part_capacity_unit_filled.png")
const GADGET = preload("res://assets/sprites/editor_ui/part_gadget_editor_icon.png")
const EFFECTS = preload("res://assets/sprites/effects/element_connection_atlas_24.png")
var BOARD := Vector2(384,176)
const TILE = 64
const UI_SCALE := 1.5
const INK = Color("e5dfc5")
const MUTED = Color("92b3ae")
const CYAN = Color("2bdcc8")
const GOLD = Color("f4d56f")
const ITEM_ARROW_POSITIONS = [Vector2(956,449),Vector2(1010,483),Vector2(956,511),Vector2(902,483)]

var ui_font: Font = FONT
var selected_weapon := -1
var show_history := false
var history_text: RichTextLabel
var model := Rules.new()
var planner := Planner.new()
var actors: Dictionary = {}
var weapon_effects: Node2D
var buttons: Array[Button] = []
var end_button: Button
var result_button: Button
var weapon_buttons: Array[Button] = []
var grid_buttons: Array[Button] = []
var busy := false
var generation := 0
var hover_cell := Vector2i(-1,-1)
var flashes: Array[Dictionary] = []
var clock := 0.0
var show_rules := false
var move_tween: Tween
var selected_enemy_id := -2
var inventory_ui: Control
var selected_item := ""
var selected_item_slot := -1
var item_origin := Vector2i(-1,-1)
var aim := Vector2i.UP
var direction_buttons: Array[Button] = []
var cancel_button: Button
var rules_button: Button
var bgm: Node

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * UI_SCALE
	if not managed_run:
		model.reset()
	weapon_effects = Node2D.new()
	add_child(weapon_effects)
	bgm = BgmPlayer.new()
	add_child(bgm)
	_make_ui()
	_start(model.level,true)

func _make_ui() -> void:
	var theme := Theme.new()
	theme.default_font = ui_font
	theme.default_font_size = 21
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.scale = Vector2.ONE * UI_SCALE
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = theme
	canvas.add_child(ui)
	_button(ui,Rect2(962,34,146,36),"やり直す [R]",func(): _start(model.level,true))
	for slot in range(3):
		var button := _button(ui,Rect2(352+slot*260,620,248,94),"",func():
			if slot < model.owned_weapons.size():
				_equip(model.owned_weapons[slot]))
		weapon_buttons.append(button)
	for y in range(6):
		for x in range(6):
			var cell := Vector2i(x,y)
			var tile_button := _button(ui,Rect2(BOARD+Vector2(cell)*TILE,Vector2(TILE,TILE)),"",func(): _act(cell))
			grid_buttons.append(tile_button)
	end_button = _button(ui,Rect2(24,580,280,58),"ターン終了 [SPACE]",_enemy_turn)
	rules_button = _button(ui,Rect2(802,34,142,36),"ルール [H]",_toggle_rules)
	cancel_button = _button(ui,Rect2(832,552,296,42),"取消 [Esc]",_cancel_item)
	var arrow_positions := ITEM_ARROW_POSITIONS
	var arrows := ["↑","→","↓","←"]
	for i in range(4):
		var direction: Vector2i = Rules.CARDINALS[i]
		var arrow := _button(ui,Rect2(arrow_positions[i],Vector2(48,30)),arrows[i],func(): _choose_direction(direction))
		arrow.add_theme_font_size_override("font_size",24)
		arrow.mouse_entered.connect(func():
			aim = direction
			queue_redraw())
		direction_buttons.append(arrow)
	_button(ui,Rect2(660,34,126,36),"履歴",func():
		_cancel_item()
		show_history = not show_history
		_update_controls())
	history_text = RichTextLabel.new()
	history_text.position = Vector2(850,153)
	history_text.size = Vector2(260,430)
	history_text.add_theme_font_size_override("normal_font_size",19)
	ui.add_child(history_text)
	result_button = _button(ui,Rect2(432,428,288,46),"次の戦闘へ →",_advance)
	result_button.visible = false
	inventory_ui = InventoryView.new()
	ui.add_child(inventory_ui)
	inventory_ui.setup(model)
	inventory_ui.item_selected.connect(_select_item)
	inventory_ui.open_changed.connect(_cancel_item)

func _button(parent: Control, rect: Rect2, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("142523") if state == "hover" else Color("091314")
		style.border_color = CYAN if state == "hover" else Color("355552")
		style.set_border_width_all(2 if state == "hover" else 1)
		if title.is_empty():
			style.bg_color.a = 0.0
			style.border_color.a = 0.0 if state != "hover" else 0.7
		button.add_theme_stylebox_override(state,style)
	button.add_theme_color_override("font_color",INK)
	button.add_theme_color_override("font_hover_color",CYAN)
	button.add_theme_color_override("font_disabled_color",Color("56716c"))
	button.pressed.connect(callback)
	parent.add_child(button)
	buttons.append(button)
	return button

func _start(level: int, keep_inventory: bool = false) -> void:
	generation += 1
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	for actor in actors.values():
		actor.queue_free()
	actors.clear()
	flashes.clear()
	for effect in weapon_effects.get_children():
		weapon_effects.remove_child(effect)
		effect.queue_free()
	model.reset(level,keep_inventory)
	BOARD = Vector2(384,176)+Vector2.ONE*(6-model.board_size)*TILE/2.0
	for i in range(grid_buttons.size()):
		var cell := Vector2i(i%6,i/6)
		grid_buttons[i].position = BOARD+Vector2(cell)*TILE
		grid_buttons[i].visible = model.inside(cell)
	selected_item = ""
	selected_weapon = -1
	show_history = false
	item_origin = Vector2i(-1,-1)
	inventory_ui.set_open(false)
	busy = false
	show_rules = false
	selected_enemy_id = -2
	_sync_units(false)
	_enemy_turn()

func _advance() -> void:
	if managed_run:
		finished.emit()
	else:
		_start(model.level+1 if model.level < 2 else 0,true)

func _equip(index: int) -> void:
	if busy or show_rules or model.phase != Rules.Phase.PLAYER:
		return
	if model.equip(index):
		_cancel_item()
		selected_weapon = index
		selected_enemy_id = -2
		show_history = false
		_sync_units(false)
		_update_controls()

func _choose_direction(direction: Vector2i) -> void:
	if busy or show_rules or inventory_ui.opened or model.phase != Rules.Phase.PLAYER:
		return
	_confirm_direction(direction)


func _enemy_turn() -> void:
	if busy or model.terminal() or show_rules or inventory_ui.opened:
		return
	_cancel_item()
	selected_weapon = -1
	busy = true
	var token := generation
	model.act_allies()
	_sync_units(true)
	_feedback()
	_update_controls()
	if not model.allies.is_empty():
		await get_tree().create_timer(0.22).timeout
		if token != generation:
			return
	if model.terminal():
		busy = false
		_update_controls()
		return
	planner.begin(model)
	_update_controls()
	await get_tree().create_timer(0.12).timeout
	if token != generation:
		return
	for beat in range(2):
		planner.beat(model,beat)
		_sync_units(true)
		_feedback()
		queue_redraw()
		await get_tree().create_timer(0.17).timeout
		if token != generation:
			return
		if model.terminal():
			break
	planner.finish(model)
	_sync_units(false)
	busy = false
	_update_controls()
	queue_redraw()

func _act(cell: Vector2i) -> void:
	if busy or show_rules or inventory_ui.opened:
		return
	if not selected_item.is_empty():
		_item_act(cell)
		return
	if cell == model.player.cell:
		return
	selected_weapon = -1
	_update_controls()
	var enemy := model.enemy_at(cell)
	if not enemy.is_empty():
		# Attackable enemies resolve immediately. Out-of-range enemies are
		# inspectable with one click and keep their movement panel open.
		if not model.targets().has(cell):
			selected_enemy_id = int(enemy.id)
			queue_redraw()
			return
		selected_enemy_id = -2
	var origin: Vector2i = model.player.cell
	var attacking := not enemy.is_empty()
	if not model.player_action(cell):
		if not model.targets().has(cell):
			selected_enemy_id = -2
			queue_redraw()
		return
	selected_enemy_id = -2
	_finish_player_action(true,{"origin":origin,"destination":cell,"attacking":attacking,"weapon":model.weapon})

func _finish_player_action(animate: bool, weapon_action: Dictionary = {}) -> void:
	busy = true
	var token := generation
	var sword_attack: bool = not weapon_action.is_empty() and weapon_action.attacking
	if sword_attack:
		# The model resolves immediately; keep the prior enemy visuals until contact.
		var player_view = actors[-1]
		player_view.play_sword_attack(model.facing)
		var impact_time: float = player_view.sword_impact_time()
		var duration: float = player_view.sword_attack_duration()
		_update_controls()
		await get_tree().create_timer(impact_time).timeout
		if token != generation:
			return
		_sync_units(false)
		_feedback(true)
		var hit_direction := Vector2(weapon_action.destination - weapon_action.origin)
		for event in model.events:
			if event.kind == "hit" and actors.has(event.id):
				actors[event.id].play_hit_reaction(hit_direction)
		queue_redraw()
		await get_tree().create_timer(duration - impact_time).timeout
	else:
		_sync_units(animate)
		var action_duration := 0.13
		if not weapon_action.is_empty():
			var effect := WeaponEffect.new()
			effect.weapon = 1
			effect.attacking = weapon_action.attacking
			effect.origin = _center(weapon_action.origin)
			effect.destination = _center(weapon_action.destination)
			weapon_effects.add_child(effect)
			action_duration = effect.duration()
		_feedback(not weapon_action.is_empty() and weapon_action.attacking)
		_update_controls()
		await get_tree().create_timer(action_duration).timeout
	if token != generation:
		return
	busy = false
	_update_controls()
	if not model.terminal() and model.player.ap == 0:
		_enemy_turn()

func _select_item(id: String, slot: int = -1) -> void:
	if busy or show_rules or model.phase != Rules.Phase.PLAYER:
		return
	var item: Resource = model.item_definition(id)
	if item == null or model.inventory.get(id,0) <= 0 or model.player.ap < item.ap_cost:
		return
	selected_item = id
	selected_item_slot = slot
	selected_weapon = -1
	show_history = false
	selected_enemy_id = -2
	item_origin = Vector2i(-1,-1)
	aim = Vector2i.UP
	_update_controls()

func _cancel_item() -> void:
	selected_item = ""
	item_origin = Vector2i(-1,-1)
	_update_controls()

func _item_act(cell: Vector2i) -> void:
	if item_origin != Vector2i(-1,-1):
		var delta := cell-item_origin
		if delta != Vector2i.ZERO and (delta.x == 0 or delta.y == 0):
			_confirm_direction(Vector2i(signi(delta.x),signi(delta.y)))
		return
	if not model.item_targets(selected_item).has(cell):
		return
	if model.item_definition(selected_item).directional:
		item_origin = cell
		_update_controls()
	else:
		_commit_item(cell,Vector2i.ZERO)

func _confirm_direction(direction: Vector2i) -> void:
	if busy or show_rules or inventory_ui.opened or item_origin == Vector2i(-1,-1):
		return
	_commit_item(item_origin,direction)

func _commit_item(cell: Vector2i, direction: Vector2i) -> void:
	if model.use_item(selected_item,cell,direction,selected_item_slot):
		_cancel_item()
		_finish_player_action(false)

func _toggle_rules() -> void:
	inventory_ui.set_open(false)
	_cancel_item()
	show_rules = not show_rules
	_update_controls()

func _sync_units(animate: bool) -> void:
	var living: Array[int] = [-1]
	var units: Array = [model.player]+model.enemies+model.allies
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	if animate:
		move_tween = create_tween().set_parallel(true)
	for unit in units:
		var id: int = unit.id
		living.append(id)
		if not actors.has(id):
			var actor := UnitView.new()
			actor.kind = unit.type
			actor.position = _center(unit.cell)
			actor.z_index = 2
			add_child(actor)
			actors[id] = actor
		var view: Node2D = actors[id]
		view.hp = unit.hp
		view.charge_warning = unit.get("state", "") == "charge"
		view.weapon_row = Rules.WEAPONS[model.weapon].row
		var target := _center(unit.cell)
		view.facing = 1 if id < 0 else 3
		view.hop_height = 0.0
		if animate:
			var jumping := false
			move_tween.tween_property(view,"position",target,0.18 if jumping else 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if jumping:
				move_tween.tween_method(func(t: float): view.hop_height = sin(t*PI)*18.0,0.0,1.0,0.18)
		else:
			view.position = target
	for id in actors.keys():
		if not living.has(id):
			actors[id].queue_free()
			actors.erase(id)

func _feedback(weapon_attack: bool = false) -> void:
	for event in model.events:
		var kind: String = "weapon_hit" if weapon_attack and event.kind == "hit" else event.kind
		var flash: Dictionary = event.duplicate()
		flash.kind = kind
		flash.life = FX_LIFE.get(kind,0.42)
		flash.max_life = flash.life
		flashes.append(flash)
		if actors.has(event.id) and event.kind != "plant":
			actors[event.id].flash = 0.18

func _update_controls() -> void:
	weapon_effects.visible = not show_rules and not inventory_ui.opened and (not model.terminal() or busy)
	end_button.disabled = busy or model.phase != Rules.Phase.PLAYER or show_rules or inventory_ui.opened
	for button in grid_buttons:
		button.disabled = end_button.disabled
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE if show_rules or inventory_ui.opened else Control.MOUSE_FILTER_STOP
	for button in weapon_buttons:
		button.disabled = end_button.disabled
	history_text.visible = show_history and not show_rules and not inventory_ui.opened
	history_text.text = "\n\n".join(model.logs)
	result_button.visible = model.terminal() and not busy and not show_rules and not inventory_ui.opened
	bgm.sync(model.terminal() and not busy,model.phase == Rules.Phase.WON)
	result_button.text = "報酬を選ぶ →" if model.phase == Rules.Phase.WON else "ビルド選択へ →"
	for actor in actors.values():
		actor.visible = (not model.terminal() or busy) and not show_rules and not inventory_ui.opened
	inventory_ui.model = model
	inventory_ui.visible = not show_rules
	inventory_ui.refresh(not busy and model.phase == Rules.Phase.PLAYER and not show_rules,selected_item)
	for index in range(direction_buttons.size()):
		var button := direction_buttons[index]
		button.visible = (not selected_item.is_empty() and item_origin != Vector2i(-1,-1)) and not show_rules and not inventory_ui.opened and not show_history
		button.position = ITEM_ARROW_POSITIONS[index]
		button.disabled = end_button.disabled
		button.self_modulate = Color.WHITE
	cancel_button.visible = not selected_item.is_empty() and not show_rules and not show_history
	rules_button.visible = true
	queue_redraw()

func _selected_enemy() -> Dictionary:
	for enemy in model.enemies:
		if int(enemy.id) == selected_enemy_id:
			return enemy
	return {}

func _preview_enemy() -> Dictionary:
	var selected := _selected_enemy()
	if not selected.is_empty():
		return selected
	return model.enemy_at(hover_cell)

func _enemy_moves(enemy: Dictionary) -> Array[Vector2i]:
	if enemy.is_empty():
		return []
	var result: Array[Vector2i] = []
	for direction in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var cell: Vector2i = enemy.cell + direction
		if model.inside(cell):
			result.append(cell)
	return result

func _process(delta: float) -> void:
	clock += delta
	for i in range(flashes.size()-1,-1,-1):
		flashes[i].life -= delta
		if flashes[i].life <= 0:
			flashes.remove_at(i)
	var point := get_local_mouse_position()-BOARD
	hover_cell = Vector2i(floori(point.x/TILE),floori(point.y/TILE))
	if item_origin != Vector2i(-1,-1) and model.inside(hover_cell):
		var offset := hover_cell-item_origin
		if offset != Vector2i.ZERO and (offset.x == 0 or offset.y == 0):
			aim = Vector2i(signi(offset.x),signi(offset.y))
	var attack_cells: Array = model.targets() if not busy and selected_item.is_empty() and model.phase == Rules.Phase.PLAYER else []
	for id in actors:
		var actor = actors[id]
		actor.attack_target = id >= 0 and attack_cells.has(Vector2i((actor.position-BOARD)/TILE))
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not selected_item.is_empty() or inventory_ui.opened:
			inventory_ui.set_open(false)
			_cancel_item()
		elif not show_rules and not busy:
			var enemy := model.enemy_at(hover_cell)
			selected_enemy_id = int(enemy.id) if not enemy.is_empty() and selected_enemy_id != int(enemy.id) else -2
			selected_weapon = -1
			show_history = false
			_update_controls()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and (selected_weapon >= 0 or show_history):
			selected_weapon = -1
			show_history = false
			_update_controls()
			return
		if event.keycode == KEY_ESCAPE and (inventory_ui.opened or not selected_item.is_empty()):
			inventory_ui.set_open(false)
			_cancel_item()
			return
		if event.keycode == KEY_H or (event.keycode == KEY_ESCAPE and show_rules):
			_toggle_rules()
			return
		if event.keycode == KEY_M:
			bgm.toggle_mute()
			return
		if event.keycode == KEY_B:
			inventory_ui.toggle()
			return
		if event.keycode in [KEY_4,KEY_5,KEY_6]:
			inventory_ui.activate_slot(event.keycode-KEY_4)
			return
		if item_origin != Vector2i(-1,-1):
			var directions := {KEY_UP:Vector2i.UP,KEY_RIGHT:Vector2i.RIGHT,KEY_DOWN:Vector2i.DOWN,KEY_LEFT:Vector2i.LEFT}
			if directions.has(event.keycode):
				_choose_direction(directions[event.keycode])
				return
		if event.keycode == KEY_R:
			_start(model.level,true)
		elif event.keycode in [KEY_1,KEY_2,KEY_3]:
			var slot: int = event.keycode-KEY_1
			if slot < model.owned_weapons.size():
				_equip(model.owned_weapons[slot])
		elif event.keycode == KEY_SPACE:
			_enemy_turn()

func _center(cell: Vector2i) -> Vector2:
	return BOARD+Vector2(cell)*TILE+Vector2.ONE*TILE/2

func _text(at: Vector2,text: String,size: int=20,color: Color=INK,font: Font=null) -> void:
	draw_string(ui_font if font == null else font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _panel(rect: Rect2) -> void:
	draw_rect(rect,Color("0b1415"))
	draw_rect(rect,Color("324843"),false,2)
	draw_rect(rect.grow(-5),Color("1d2c29"),false,1)
	for corner in [rect.position,rect.position+Vector2(rect.size.x-4,0),rect.end-Vector2(4,4),rect.position+Vector2(0,rect.size.y-4)]:
		draw_rect(Rect2(corner,Vector2(4,4)),Color("829081"))

func _draw() -> void:
	draw_rect(Rect2(0,0,1152,720),Color("070b0d"))
	for x in range(0,1152,24):
		draw_line(Vector2(x,0),Vector2(x,720),Color("0d1718"))
	for y in range(0,720,24):
		draw_line(Vector2(0,y),Vector2(1152,y),Color("0d1718"))
	_panel(Rect2(24,24,1104,58))
	_text(Vector2(44,62),"戦闘 %d / 3" % (model.level+1),25,CYAN)
	_text(Vector2(260,62),"ターン %02d" % model.round_number,23)
	_text(Vector2(480,62),"敵 残り %d" % model.enemies.size(),23)
	_draw_board()
	_draw_player_panel()
	_draw_weapons()
	_draw_intel()
	_draw_flashes()
	_text(Vector2(352,126),"敵のターン" if busy and model.phase==Rules.Phase.ENEMY else "あなたのターン",27,CYAN if not busy else GOLD)

	if model.inside(hover_cell) and model.targets().has(hover_cell) and selected_item.is_empty() and not busy:
		_text(Vector2(36,673),"移動 1 AP" if model.enemy_at(hover_cell).is_empty() else "攻撃 1 AP",23,GOLD)
	if model.terminal() and not busy:
		_draw_result()
	if show_rules:
		_draw_rules()

func _draw_board() -> void:
	var extent := Vector2.ONE*model.board_size*TILE
	draw_rect(Rect2(BOARD-Vector2.ONE*10,extent+Vector2.ONE*20),Color("252820"))
	draw_rect(Rect2(BOARD-Vector2.ONE*10,extent+Vector2.ONE*20),Color("4d5443"),false,3)
	var legal: Array = []
	if model.phase == Rules.Phase.PLAYER and not busy and not show_rules and not inventory_ui.opened:
		legal = model.targets().filter(func(cell: Vector2i) -> bool: return not model.blocked(cell) or not model.cannon_at(cell).is_empty()) if selected_item.is_empty() else model.item_targets(selected_item)
		if item_origin != Vector2i(-1,-1):
			legal = model.directional_preview(selected_item,item_origin,aim)
	for y in range(model.board_size):
		for x in range(model.board_size):
			var cell := Vector2i(x,y)
			var pos := BOARD+Vector2(cell)*TILE
			var base := Color("665b48")
			var shade := 0.88+float((x*13+y*7)%5)*0.025
			draw_rect(Rect2(pos+Vector2(2,2),Vector2(60,60)),base*shade)
			draw_line(pos+Vector2(3,59),pos+Vector2(59,59),Color("38362a"),2)
			draw_line(pos+Vector2(3,3),pos+Vector2(59,3),Color("766b54"),1)
			if (x*3+y)%4==0:
				draw_line(pos+Vector2(39,4),pos+Vector2(34,13),Color("494535"),2)
			if legal.has(cell):
				var color := GOLD if model.enemy_at(cell).is_empty() and model.cannon_at(cell).is_empty() else Color("ff805a")
				if not selected_item.is_empty(): color = model.item_definition(selected_item).color
				draw_rect(Rect2(pos+Vector2(6,6),Vector2(52,52)),Color(color,0.18))
				draw_rect(Rect2(pos+Vector2(6,6),Vector2(52,52)),Color(color,0.7),false,2)
			if cell == hover_cell and model.inside(cell) and not show_rules:
				draw_rect(Rect2(pos+Vector2(3,3),Vector2(58,58)),Color("fff0bd"),false,2)
			if cell == model.player.cell:
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),Color(CYAN,0.8),false,2)
			var selected := _selected_enemy()
			if not selected.is_empty() and cell == selected.cell:
				draw_rect(Rect2(pos+Vector2(3,3),Vector2(58,58)),Color("ffbd59"),false,3)
			if model.mines.has(cell):
				_draw_mine(pos+Vector2(49,49))
			if model.obstacles.has(cell):
				draw_rect(Rect2(pos+Vector2(8,8),Vector2(48,48)),Color("263b3d"))
			if model.fairies.has(cell):
				SpiritIcon.paint(self,_center(cell),model.item_definition("stealth_fairy").icon,1.1)
			if model.walls.has(cell):
				SpiritIcon.paint(self,_center(cell),model.item_definition("wall_fairy").icon,0.95)
				_text(pos+Vector2(44,58),str(model.walls[cell]),20,INK)
			var cannon: Dictionary = model.cannon_at(cell)
			if not cannon.is_empty():
				var cannon_id: String = {"lance":"cannon_fairy","vane":"vane_cannon","firework":"firework_fairy"}[cannon.kind]
				# Directional art shows the facing itself; the plain icon gets an arrow.
				if not DirectionSheet.paint(self,_center(cell),cannon_id,cannon.dir,0.95):
					SpiritIcon.paint(self,_center(cell),model.item_definition(cannon_id).icon,0.95)
					if cannon.dir != Vector2i.ZERO:
						_draw_arrow(_center(cell)+Vector2(cannon.dir)*18,Vector2(cannon.dir),model.item_definition(cannon_id).color)
			if cell == item_origin and not DirectionSheet.paint(self,_center(cell),selected_item,aim,1.1):
				SpiritIcon.paint(self,_center(cell),model.item_definition(selected_item).icon,1.1)
	if item_origin != Vector2i(-1,-1):
		var start := _center(item_origin)
		var end := start+Vector2(aim)*28
		draw_line(start,end,GOLD,5)
		var side := Vector2(-aim.y,aim.x)*8
		draw_colored_polygon(PackedVector2Array([end+Vector2(aim)*8,end-Vector2(aim)*7+side,end-Vector2(aim)*7-side]),GOLD)

func _draw_arrow(tip: Vector2, dir: Vector2, color: Color) -> void:
	var side := Vector2(-dir.y,dir.x)*6
	draw_colored_polygon(PackedVector2Array([tip+dir*8,tip-dir*4+side,tip-dir*4-side]),color)

func _draw_mine(pos: Vector2) -> void:
	draw_circle(pos,12,Color("201710"))
	draw_arc(pos,12,0,TAU,16,GOLD,2)
	draw_rect(Rect2(pos-Vector2(9,5),Vector2(18,10)),Color("172326"))
	draw_rect(Rect2(pos-Vector2(6,7),Vector2(12,12)),Color("99703a"))
	draw_rect(Rect2(pos-Vector2(3,3),Vector2(6,5)),Color("ffad59"))
	draw_rect(Rect2(pos-Vector2(1,10),Vector2(2,3)),Color("ffdba0"))

func _draw_player_panel() -> void:
	_panel(Rect2(24,94,280,128))
	_text(Vector2(40,121),"HP",21)
	for i in range(5):
		_draw_heart(Vector2(102+i*40,115),25.0,Color("ff5b62"),i < model.player.hp)
	_text(Vector2(40,162),"AP",24,GOLD)
	for i in range(2):
		draw_rect(Rect2(94+i*96,137,84,29),GOLD if i<model.player.ap else Color("293d36"))
	_text(Vector2(40,204),"右向き固定  →",22,CYAN)

func _draw_weapons() -> void:
	_text(Vector2(352,605),"武器  %d / 3" % model.owned_weapons.size(),23,INK)
	_text(Vector2(555,605),"タップで装備・0 AP",20,MUTED)
	for slot in range(model.owned_weapons.size()):
		var index: int = model.owned_weapons[slot]
		var weapon: Dictionary = Rules.WEAPONS[index]
		var pos := Vector2(352+slot*260,620)
		var rect := Rect2(pos,Vector2(248,94))
		var accent := Color(weapon.color)
		draw_rect(rect,Color("152d2a") if model.weapon==index else Color("0b1415"))
		draw_rect(rect,accent if model.weapon==index else Color("324843"),false,3 if model.weapon==index else 2)
		_text(pos+Vector2(12,32),weapon.name,23,accent)
		_text(pos+Vector2(12,66),"装備中" if model.weapon==index else "装備する",19,INK)
		var offsets := model.weapon_offsets(index)
		var count := RangeDiagram.span(offsets)
		var cell_size := 72.0/count
		for y in range(count):
			for x in range(count):
				var offset := Vector2i(x-count/2,y-count/2)
				var tile := Rect2(pos+Vector2(166+x*cell_size,11+y*cell_size),Vector2.ONE*(cell_size-3))
				draw_rect(tile,Color(accent,0.55) if offsets.has(offset) else Color("253a36"))
				if offset == Vector2i.ZERO:
					_draw_player_portrait(index,tile.get_center(),28,1)

func _draw_intel() -> void:
	_panel(Rect2(832,94,296,508))
	if show_history:
		_text(Vector2(852,133),"戦闘履歴",26,CYAN)
		return
	if not selected_item.is_empty():
		var item: Resource = model.item_definition(selected_item)
		_text(Vector2(852,133),item.title,26,item.color)
		SpiritIcon.paint(self,Vector2(912,180),item.icon,1.35)
		_text(Vector2(992,187),"1 AP",24,GOLD)
		_text(Vector2(1032,222),"動作例",17,MUTED)
		ItemPreview.paint(self,model,selected_item,clock)
		var lines: PackedStringArray = item.description.split("\n")
		for i in range(lines.size()):
			_text(Vector2(850,335+i*25),lines[i],18,INK)
		_text(Vector2(852,440 if item_origin != Vector2i(-1,-1) else 487),"向きを選択" if item_origin != Vector2i(-1,-1) else "移動先を選択" if selected_item == "warp_fairy" else "配置先を選択",23,item.color)
		return
	var enemy := _preview_enemy()
	if not enemy.is_empty():
		_draw_enemy_inspector(enemy)
	elif selected_weapon >= 0:
		var weapon: Dictionary = Rules.WEAPONS[selected_weapon]
		_text(Vector2(852,133),weapon.name,25,Color(weapon.color))
		_text(Vector2(852,177),"装備中",21,MUTED)
		_draw_range(model.weapon_offsets(selected_weapon,model.facing),Color(weapon.color),{},selected_weapon,model.facing)
		_text(Vector2(852,495),"移動・攻撃範囲",23,INK)
		_text(Vector2(852,535),Rules.WEAPONS[selected_weapon].detail,20,MUTED)
	else:
		_text(Vector2(852,133),"敵の情報",26,CYAN)
		_text(Vector2(852,295),"敵にカーソルを",23,INK)
		_text(Vector2(852,330),"合わせて確認",23,INK)
		_text(Vector2(852,540),"右クリックで固定",20,MUTED)

func _draw_player_portrait(weapon_index: int, center: Vector2, side: float, facing_index: int = 2) -> void:
	var cell := UnitView.PLAYER_ATLAS_CELL
	var row: int = Rules.WEAPONS[weapon_index].row
	draw_texture_rect_region(UnitView.PLAYER_ATLAS,Rect2(center-Vector2.ONE*side/2,Vector2.ONE*side),Rect2(facing_index*cell,row*cell,cell,cell))

func _draw_range(offsets: Array, accent: Color, enemy: Dictionary = {}, weapon_index: int = -1, _forward_index: int = 0, portrait_index: int = 2, compact: bool = false) -> void:
	var count := 3
	var step := 52 if compact else 64
	# Cavalry and two-tile weapons need a larger preview for their jumps.
	var self_cell: Vector2i = Vector2i(1,1)
	if enemy.get("type","") == "cavalry" or RangeDiagram.span(offsets) == 5:
		count = 5
		step = 38
		self_cell = Vector2i(2,2)
	var origin := Vector2(980-count*step/2.0,192 if compact else 236)
	for y in range(count):
		for x in range(count):
			var offset := Vector2i(x,y)-self_cell
			var rect := Rect2(origin+Vector2(x,y)*step,Vector2.ONE*(step-5))
			var active: bool = offsets.has(offset)
			draw_rect(rect,Color(accent,0.3) if active else Color("192828"))
			draw_rect(rect,accent if active else Color("46625e"),false,2)
			if offset == Vector2i.ZERO:
				if not enemy.is_empty():
					_draw_enemy_portrait(enemy,rect.get_center(),0.85)
				else:
					_draw_player_portrait(weapon_index,rect.get_center(),step,portrait_index)
			elif active:
				draw_circle(rect.get_center(),6,accent)

func _draw_enemy_portrait(enemy: Dictionary, center: Vector2, factor: float = 1.0) -> void:
	var actor = actors.get(int(enemy.id))
	if actor == null:
		return
	draw_set_transform(center,0,Vector2.ONE*factor)
	if enemy.type == "miner":
		actor._draw_drone(Color.WHITE,self)
	elif enemy.type == "cavalry":
		actor._draw_cavalry(Color.WHITE,self)
	else:
		draw_texture_rect_region(UnitView.ENEMY_ATLAS,Rect2(-28,-28,56,56),Rect2(56,0,28,28))
		if enemy.type == "heavy":
			draw_rect(Rect2(-22,0,18,26),Color("78968f"))
			draw_rect(Rect2(-18,4,10,18),Color("293d42"))
	draw_set_transform(Vector2.ZERO)

func _draw_enemy_inspector(enemy: Dictionary) -> void:
	var type: Dictionary = Rules.TYPES[enemy.type]
	_text(Vector2(852,133),type.name,28,INK)
	_text(Vector2(852,175),"HP",20)
	for i in range(int(type.hp)):
		_draw_heart(Vector2(909+i*30,167),25,Color("ff5b62"),i<int(enemy.hp))
	_text(Vector2(984,175),"AP",20,GOLD)
	for i in range(int(type.ap)):
		draw_rect(Rect2(1029+i*36,153,28,23),GOLD)
	_text(Vector2(852,217),"移動・攻撃範囲",21,INK)
	_draw_range(model.enemy_offsets(enemy),CYAN,enemy)
	var intent := "前線へ前進" if enemy.type == "heavy" else "移動 → 地雷設置" if enemy.type == "miner" else "跳躍接近" if enemy.type == "cavalry" else "突撃準備 !" if enemy.state == "charge" else "包囲中" if enemy.state == "encircle" else "接近中"
	_text(Vector2(852,479),intent,25,GOLD if enemy.state=="charge" else CYAN)
	if enemy.type == "miner":
		_text(Vector2(852,520),"飛行・地雷を踏まない",19,MUTED)
	elif enemy.state == "charge":
		_text(Vector2(852,520),"次の敵ターンに突撃",20,INK)
	_text(Vector2(852,574),"固定中・右クリックで解除" if selected_enemy_id==int(enemy.id) else "右クリックで固定",18,MUTED)

func _draw_heart(center: Vector2, size: float, color: Color, filled: bool) -> void:
	var half := size * 0.5
	var points := PackedVector2Array([
		center + Vector2(-half, -half*0.08),
		center + Vector2(-half, -half*0.38),
		center + Vector2(-half*0.68, -half*0.64),
		center + Vector2(-half*0.30, -half*0.74),
		center + Vector2(0, -half*0.36),
		center + Vector2(half*0.30, -half*0.74),
		center + Vector2(half*0.68, -half*0.64),
		center + Vector2(half, -half*0.38),
		center + Vector2(half, -half*0.08),
		center + Vector2(0, half*0.72),
	])
	var draw_color := color if filled else Color("341d25")
	draw_colored_polygon(points,draw_color)
	draw_polyline(points,Color("ff8b8f") if filled else Color("70434a"),1.2,true)

func _draw_flashes() -> void:
	for effect in flashes:
		var pos := _center(effect.cell)
		var fade: float = effect.life/effect.get("max_life",0.42)
		if FX_LIFE.has(effect.kind):
			_draw_fx(effect,pos,fade)
			continue
		var row := 1 if effect.kind == "mine" else 3 if effect.kind == "plant" else 0
		if effect.kind != "weapon_hit":
			draw_texture_rect_region(EFFECTS,Rect2(pos-Vector2(32,32),Vector2(64,64)),Rect2(16*24,row*24,24,24),Color(1,1,1,fade))
		if effect.kind != "plant":
			_text(pos+Vector2(9,-26-(1-fade)*20),"−1",22,Color(1,0.65,0.4,fade))

## Fairy effects: small and quick, except the firework, which is allowed to show off.
const FX_LIFE = {"bolt":0.42, "warp":0.42, "summon":0.5, "ambush":0.42, "shot":0.45, "muzzle":0.35, "slash":0.45, "blast":0.8, "firework":0.95}
const FIREWORK_COLORS = [Color("ff5b8a"), Color("ffd35b"), Color("6bdcff"), Color("b58cff"), Color("8dffb0")]

func _draw_fx(effect: Dictionary, pos: Vector2, fade: float) -> void:
	var t := 1.0 - fade
	var dir := Vector2(effect.get("dir", Vector2i.ZERO))
	match effect.kind:
		"bolt":
			# A warm spark streaking through each tile.
			draw_line(pos - dir * (18 - t * 30), pos + dir * (t * 30 - 6), Color("ffbd59", fade), 4)
			draw_circle(pos + dir * (t * 24 - 12), 5 * fade + 1, Color("fff1c4", fade))
		"shot":
			draw_line(pos - dir * 30, pos + dir * 30, Color("5a1e0c", fade * 0.6), 11)
			draw_line(pos - dir * 30, pos + dir * 30, Color("ff8a4a", fade), 7)
			draw_line(pos - dir * 30, pos + dir * 30, Color("fff1c4", fade), 2)
		"muzzle":
			draw_circle(pos + dir * 22, 6 + t * 12, Color("ffb24a", fade * 0.8))
			for i in range(5):
				var a := dir.angle() + (i - 2) * 0.45
				draw_line(pos + dir * 22, pos + dir * 22 + Vector2.from_angle(a) * (8 + t * 16), Color("fff1c4", fade), 2)
		"slash":
			# A pale crescent sweeping across the tile.
			var base := dir.angle() if dir != Vector2.ZERO else 0.0
			var arc_center := pos - dir * 12 + dir * t * 18
			draw_arc(arc_center, 24, base - 1.1, base + 1.1, 14, Color("123a2c", fade * 0.7), 8, true)
			draw_arc(arc_center, 24, base - 1.1, base + 1.1, 14, Color("7fffd0", fade), 5, true)
			draw_arc(arc_center, 24, base - 0.8, base + 0.8, 12, Color("ffffff", fade), 2, true)
		"ambush":
			var r := 10 + t * 8
			draw_line(pos + Vector2(-r, -r), pos + Vector2(r, r), Color("c7a8ff", fade), 3)
			draw_line(pos + Vector2(r, -r), pos + Vector2(-r, r), Color("c7a8ff", fade), 3)
		"warp":
			draw_arc(pos, 12 + t * 22, 0, TAU, 24, Color(CYAN, fade), 4, true)
		"summon":
			match effect.get("fx", ""):
				"wall":
					# Dust puffs settling at the foot of the wall.
					for i in range(4):
						var x := -18 + i * 12
						draw_circle(pos + Vector2(x, 20 - t * 6), 4 + t * 6, Color("b9b39f", fade * 0.6))
				"acorn":
					for i in range(3):
						var leaf := pos + Vector2(-12 + i * 12, 10 - t * 26 - i * 3)
						draw_circle(leaf, 3, Color("9fd55f", fade))
				"cannon":
					for i in range(4):
						var spark := pos + Vector2.from_angle(i * TAU / 4 + 0.6) * (14 + t * 12)
						draw_line(spark - Vector2(4, 0), spark + Vector2(4, 0), Color("ffd98a", fade), 2)
						draw_line(spark - Vector2(0, 4), spark + Vector2(0, 4), Color("ffd98a", fade), 2)
				"stealth":
					draw_arc(pos, 16 + t * 8, t * 3, t * 3 + 4.5, 18, Color("aa8cff", fade * 0.8), 3, true)
				_:
					draw_arc(pos, 12 + t * 22, 0, TAU, 24, Color("aa8cff", fade), 4, true)
		"blast":
			# Sparks flying outward from the firework into each neighbouring tile.
			var from: Vector2 = _center(effect.get("from", effect.cell))
			var out := (pos - from).normalized()
			for i in range(3):
				var color: Color = FIREWORK_COLORS[(i + effect.cell.x + effect.cell.y) % FIREWORK_COLORS.size()]
				var spark := from + out * (20 + t * 60) + Vector2(-out.y, out.x) * (i - 1) * 8
				draw_circle(spark, 3.5 * fade + 1, Color(color, fade))
			draw_arc(pos, 8 + t * 18, 0, TAU, 16, Color(FIREWORK_COLORS[(effect.cell.x * 2 + effect.cell.y) % FIREWORK_COLORS.size()], fade * 0.8), 3, true)
		"firework":
			# A full starburst: coloured rays, a white core and a double ring.
			draw_circle(pos, 10 + t * 16, Color(1, 1, 0.9, fade * 0.8))
			for i in range(16):
				var angle := i * TAU / 16 + t * 0.4
				var color: Color = FIREWORK_COLORS[i % FIREWORK_COLORS.size()]
				var inner := pos + Vector2.from_angle(angle) * (8 + t * 40)
				var outer := pos + Vector2.from_angle(angle) * (18 + t * 90)
				draw_line(inner, outer, Color(color, fade), 3)
				draw_circle(outer, 3 * fade + 1, Color(color, fade))
			draw_arc(pos, 20 + t * 70, 0, TAU, 32, Color("ffd35b", fade * 0.7), 3, true)
			draw_arc(pos, 12 + t * 45, 0, TAU, 32, Color("ff5b8a", fade * 0.7), 2, true)

func _draw_result() -> void:
	draw_rect(Rect2(352,144,448,448),Color("0a1415"))
	_panel(Rect2(368,226,416,282))
	var won: bool = model.phase == Rules.Phase.WON
	_text(Vector2(414,278),"SECTOR CLEAR" if won else "EXPEDITION FAILED",36,CYAN if won else Color("ff8968"),LATIN)
	_text(Vector2(421,326),"全3戦クリア！" if won and model.level==2 else "包囲網を突破した" if won else "探索者、倒れる",26)
	_text(Vector2(423,365),"%dターン / 撃破 %d体" % [model.round_number,model.kills],18,MUTED)
	_text(Vector2(423,396),"妖精の使用回数が回復" if won else "初期ビルドから再挑戦",16,MUTED)

func _draw_rules() -> void:
	draw_rect(Rect2(320,116,500,501),Color("060e10"))
	_panel(Rect2(328,124,484,485))
	_text(Vector2(352,163),"FIELD MANUAL",28,CYAN,LATIN)
	var lines := ["移動・攻撃・妖精使用：1 AP", "武器をタップ：持ち替え 0 AP", "向きは固定。武器と妖精は各3枠", "終了後：どんぐり妖精 → 敵", "妖精は各戦闘で使用回数が回復"]
	for i in range(lines.size()):
		_text(Vector2(350,212+i*55),lines[i],20,INK if i%2==0 else MUTED)
	_text(Vector2(350,503),"! 次の敵ターンに突撃",20,GOLD)
	_text(Vector2(350,554),"1–3 武器 / 4–6 妖精 / Esc 取消",20,INK,LATIN)
