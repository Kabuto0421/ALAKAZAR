extends Node2D

const Rules = preload("res://scripts/battle_model.gd")
const Planner = preload("res://scripts/enemy_planner.gd")
const WeaponEffect = preload("res://scripts/weapon_effect.gd")
const UnitView = preload("res://scripts/unit_view.gd")
const InventoryView = preload("res://scripts/items/inventory_view.gd")
const ItemPreview = preload("res://scripts/items/item_preview.gd")
const SpiritIcon = preload("res://scripts/items/spirit_icon.gd")
const BgmPlayer = preload("res://scripts/audio/bgm_player.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const LATIN = preload("res://assets/fonts/VT323-Regular.ttf")
const HP_EMPTY = preload("res://assets/sprites/editor_ui/part_capacity_unit_empty.png")
const HP_FULL = preload("res://assets/sprites/editor_ui/part_capacity_unit_filled.png")
const GADGET = preload("res://assets/sprites/editor_ui/part_gadget_editor_icon.png")
const EFFECTS = preload("res://assets/sprites/effects/element_connection_atlas_24.png")
const BOARD = Vector2(384,176)
const TILE = 64
const UI_SCALE := 1.5
const INK = Color("e5dfc5")
const MUTED = Color("92b3ae")
const CYAN = Color("2bdcc8")
const GOLD = Color("f4d56f")
const WEAPON_UI_ORDER = [1,0,2]
const FACING_ARROWS = ["↑","→","↓","←"]
const ITEM_ARROW_POSITIONS = [Vector2(956,449),Vector2(1010,483),Vector2(956,511),Vector2(902,483)]
const TURN_ARROW_POSITIONS = [Vector2(956,393),Vector2(1010,431),Vector2(956,469),Vector2(902,431)]

var ui_font: Font = FONT
var selected_weapon := -1
var facing_preview := -1
var facing_button: Button
var facing_confirm_button: Button
var equip_button: Button
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
var item_origin := Vector2i(-1,-1)
var aim := Vector2i.UP
var direction_buttons: Array[Button] = []
var cancel_button: Button
var rules_button: Button
var bgm: Node

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * UI_SCALE
	model.reset()
	weapon_effects = Node2D.new()
	add_child(weapon_effects)
	bgm = BgmPlayer.new()
	add_child(bgm)
	_make_ui()
	_start(0)

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
	_button(ui,Rect2(962,34,146,36),"やり直す [R]",func(): _start(model.level))
	facing_button = _button(ui,Rect2(36,177,256,36),"↑ 向き変更",_toggle_facing)
	facing_button.tooltip_text = "方向を確認してから1 APで確定"
	for slot in range(3):
		var weapon_index: int = WEAPON_UI_ORDER[slot]
		var button := _button(ui,Rect2(24,261+slot*75,280,72),"",func(): _equip(weapon_index))
		weapon_buttons.append(button)
	equip_button = _button(ui,Rect2(24,494,280,40),"装備中",_confirm_equip)
	for y in range(6):
		for x in range(6):
			var cell := Vector2i(x,y)
			var tile_button := _button(ui,Rect2(BOARD+Vector2(cell)*TILE,Vector2(TILE,TILE)),"",func(): _act(cell))
			grid_buttons.append(tile_button)
	end_button = _button(ui,Rect2(24,580,280,58),"ターン終了 [SPACE]",_enemy_turn)
	rules_button = _button(ui,Rect2(802,34,142,36),"ルール [H]",_toggle_rules)
	cancel_button = _button(ui,Rect2(832,552,296,42),"取消 [Esc]",_cancel_item)
	facing_confirm_button = _button(ui,Rect2(844,513,272,37),"この向きにする 1 AP",_confirm_facing)
	facing_confirm_button.add_theme_font_size_override("font_size",19)
	var arrow_positions := ITEM_ARROW_POSITIONS
	var arrows := ["↑","→","↓","←"]
	for i in range(4):
		var direction: Vector2i = Rules.CARDINALS[i]
		var arrow := _button(ui,Rect2(arrow_positions[i],Vector2(48,30)),arrows[i],func(): _choose_direction(direction))
		arrow.add_theme_font_size_override("font_size",24)
		arrow.mouse_entered.connect(func():
			if facing_preview < 0: aim = direction
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
	selected_item = ""
	facing_preview = -1
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
	var next_battle: bool = model.phase == Rules.Phase.WON and model.level < 2
	_start(model.level+1 if next_battle else 0 if model.phase == Rules.Phase.WON else model.level,next_battle)

func _equip(index: int) -> void:
	# Cards and keyboard shortcuts only inspect; this never spends AP.
	if busy or show_rules or inventory_ui.opened or model.phase != Rules.Phase.PLAYER:
		return
	if index < 0 or index >= Rules.WEAPONS.size():
		return
	_cancel_item()
	selected_weapon = index
	selected_enemy_id = -2
	show_history = false
	_update_controls()

func _confirm_equip() -> void:
	if busy or show_rules or inventory_ui.opened or selected_weapon < 0 or selected_weapon == model.weapon:
		return
	if model.equip(selected_weapon):
		selected_weapon = -1
		_sync_units(false)
		_update_controls()
		if model.player.ap == 0:
			_enemy_turn()

func _toggle_facing() -> void:
	if busy or show_rules or inventory_ui.opened or model.phase != Rules.Phase.PLAYER:
		return
	var was_open := facing_preview >= 0
	_cancel_item()
	selected_weapon = -1
	selected_enemy_id = -2
	show_history = false
	if not was_open:
		facing_preview = model.facing
	_update_controls()

func _choose_direction(direction: Vector2i) -> void:
	if busy or show_rules or inventory_ui.opened or model.phase != Rules.Phase.PLAYER:
		return
	if facing_preview >= 0:
		var index := Rules.CARDINALS.find(direction)
		if index >= 0:
			facing_preview = index
			_update_controls()
	else:
		_confirm_direction(direction)

func _confirm_facing() -> void:
	if busy or show_rules or inventory_ui.opened or facing_preview < 0:
		return
	if model.turn_to(facing_preview):
		_cancel_item()
		_finish_player_action(false)

func _enemy_turn() -> void:
	if busy or model.terminal() or show_rules or inventory_ui.opened:
		return
	_cancel_item()
	selected_weapon = -1
	busy = true
	var token := generation
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
		_toggle_facing()
		return
	if facing_preview >= 0:
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
	var sword_attack: bool = not weapon_action.is_empty() and weapon_action.attacking and weapon_action.weapon == 1
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
			effect.weapon = weapon_action.weapon
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

func _select_item(id: String) -> void:
	if busy or show_rules or model.phase != Rules.Phase.PLAYER:
		return
	var item: Resource = model.item_definition(id)
	if item == null or model.inventory.get(id,0) <= 0 or model.player.ap < item.ap_cost:
		return
	selected_item = id
	facing_preview = -1
	selected_weapon = -1
	show_history = false
	selected_enemy_id = -2
	item_origin = Vector2i(-1,-1)
	aim = Vector2i.UP
	_update_controls()

func _cancel_item() -> void:
	facing_preview = -1
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
	if model.use_item(selected_item,cell,direction):
		_cancel_item()
		_finish_player_action(false)

func _toggle_rules() -> void:
	inventory_ui.set_open(false)
	_cancel_item()
	show_rules = not show_rules
	_update_controls()

func _sync_units(animate: bool) -> void:
	var living: Array[int] = [-1]
	var units: Array = [model.player]+model.enemies
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
		if id == -1:
			view.facing = model.facing
		elif unit.type == "cavalry":
			view.facing = unit.facing
		else:
			var delta: Vector2i = model.player.cell-unit.cell
			view.facing = (1 if delta.x > 0 else 3) if absi(delta.x)>absi(delta.y) else (2 if delta.y >= 0 else 0)
		view.hop_height = 0.0
		if animate:
			var jumping: bool = id == -1 and model.weapon == 2 and view.position != target
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
		flashes.append({"cell":event.cell,"kind":kind,"life":0.42})
		if actors.has(event.id) and event.kind != "plant":
			actors[event.id].flash = 0.18

func _update_controls() -> void:
	weapon_effects.visible = not show_rules and not inventory_ui.opened and (not model.terminal() or busy)
	end_button.disabled = busy or model.phase != Rules.Phase.PLAYER or show_rules or inventory_ui.opened
	facing_button.disabled = end_button.disabled
	facing_button.text = FACING_ARROWS[model.facing] + " 向き変更"
	facing_button.self_modulate = CYAN if facing_preview >= 0 else Color.WHITE
	facing_confirm_button.visible = facing_preview >= 0 and not show_rules and not inventory_ui.opened
	facing_confirm_button.disabled = end_button.disabled or facing_preview == model.facing or model.player.ap < 1
	facing_confirm_button.text = "現在の向き" if facing_preview == model.facing else "AP不足" if model.player.ap < 1 else "この向きにする 1 AP"
	for button in grid_buttons:
		button.disabled = end_button.disabled
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE if show_rules or inventory_ui.opened else Control.MOUSE_FILTER_STOP
	for button in weapon_buttons:
		button.disabled = end_button.disabled
	equip_button.disabled = end_button.disabled or selected_weapon < 0 or selected_weapon == model.weapon or model.player.ap < 1
	equip_button.text = "装備中" if selected_weapon < 0 or selected_weapon == model.weapon else "装備する 1 AP" if model.player.ap > 0 else "AP不足"
	history_text.visible = show_history and not show_rules and not inventory_ui.opened
	history_text.text = "\n\n".join(model.logs)
	result_button.visible = model.terminal() and not busy and not show_rules and not inventory_ui.opened
	bgm.sync(model.terminal() and not busy,model.phase == Rules.Phase.WON)
	result_button.text = "次の戦闘へ →" if model.phase == Rules.Phase.WON and model.level < 2 else "もう一度挑戦 →"
	for actor in actors.values():
		actor.visible = (not model.terminal() or busy) and not show_rules and not inventory_ui.opened
	inventory_ui.model = model
	inventory_ui.visible = not show_rules
	inventory_ui.refresh(not busy and model.phase == Rules.Phase.PLAYER and not show_rules,selected_item)
	for index in range(direction_buttons.size()):
		var button := direction_buttons[index]
		button.visible = (facing_preview >= 0 or (not selected_item.is_empty() and item_origin != Vector2i(-1,-1))) and not show_rules and not inventory_ui.opened and not show_history
		button.position = TURN_ARROW_POSITIONS[index] if facing_preview >= 0 else ITEM_ARROW_POSITIONS[index]
		button.disabled = end_button.disabled
		button.self_modulate = CYAN if facing_preview == index else GOLD if facing_preview >= 0 and model.facing == index else Color.WHITE
	cancel_button.visible = (facing_preview >= 0 or not selected_item.is_empty()) and not show_rules and not show_history
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
	var attack_cells: Array = model.targets() if not busy and facing_preview < 0 and selected_item.is_empty() and model.phase == Rules.Phase.PLAYER else []
	for id in actors:
		var actor = actors[id]
		actor.attack_target = id >= 0 and attack_cells.has(Vector2i((actor.position-BOARD)/TILE))
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if facing_preview >= 0 or not selected_item.is_empty() or inventory_ui.opened:
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
		if event.keycode == KEY_ESCAPE and (facing_preview >= 0 or inventory_ui.opened or not selected_item.is_empty()):
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
		if event.keycode in [KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0]:
			inventory_ui.activate_slot(6 if event.keycode == KEY_0 else event.keycode-KEY_4)
			return
		if facing_preview >= 0 or item_origin != Vector2i(-1,-1):
			var directions := {KEY_UP:Vector2i.UP,KEY_RIGHT:Vector2i.RIGHT,KEY_DOWN:Vector2i.DOWN,KEY_LEFT:Vector2i.LEFT}
			if directions.has(event.keycode):
				_choose_direction(directions[event.keycode])
				return
		if event.keycode == KEY_R:
			_start(model.level)
		elif event.keycode == KEY_1:
			_equip(1)
		elif event.keycode == KEY_2:
			_equip(0)
		elif event.keycode == KEY_3:
			_equip(2)
		elif event.keycode == KEY_Q:
			_equip(posmod((selected_weapon if selected_weapon >= 0 else model.weapon)-1,3))
		elif event.keycode == KEY_E or event.keycode == KEY_TAB:
			_equip(posmod((selected_weapon if selected_weapon >= 0 else model.weapon)+1,3))
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
	_text(Vector2(480,62),"敵 残り %d" % maxi(actors.size()-1,0),23)
	_draw_board()
	_draw_player_panel()
	_draw_weapons()
	_draw_intel()
	_draw_flashes()
	_text(Vector2(352,126),"敵のターン" if busy and model.phase==Rules.Phase.ENEMY else "あなたのターン",27,CYAN if not busy else GOLD)

	if model.inside(hover_cell) and model.targets().has(hover_cell) and selected_item.is_empty() and facing_preview < 0 and not busy:
		_text(Vector2(36,673),"移動 1 AP" if model.enemy_at(hover_cell).is_empty() else "攻撃 1 AP",23,GOLD)
	if model.terminal() and not busy:
		_draw_result()
	if show_rules:
		_draw_rules()

func _draw_board() -> void:
	# Stone floor and wall palette come from the original main.gd.
	for y in range(-1,7):
		for x in range(-1,7):
			var pos := BOARD+Vector2(x,y)*TILE
			if x < 0 or x > 5 or y < 0 or y > 5:
				var rect := Rect2(pos+Vector2(2,2),Vector2(60,60))
				if x == -1: rect = Rect2(352,pos.y+2,28,60)
				if x == 6: rect = Rect2(772,pos.y+2,28,60)
				if y == -1: rect = Rect2(rect.position.x,144,rect.size.x,28)
				if y == 6: rect = Rect2(rect.position.x,564,rect.size.x,28)
				draw_rect(rect,Color("252820"))
				draw_rect(rect.grow(-5),Color("34352b"),false,2)
	var legal: Array = []
	if model.phase == Rules.Phase.PLAYER and not busy and not show_rules and not inventory_ui.opened:
		legal = model.targets().filter(func(cell: Vector2i) -> bool: return not model.blocked(cell)) if selected_item.is_empty() else model.item_targets(selected_item)
		if facing_preview >= 0:
			legal = model.targets_for_facing(facing_preview).filter(func(cell: Vector2i) -> bool: return not model.blocked(cell))
		if item_origin != Vector2i(-1,-1):
			legal = model.ray_cells(item_origin,aim)
	for y in range(6):
		for x in range(6):
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
				var color := GOLD if model.enemy_at(cell).is_empty() else Color("ff805a")
				if not selected_item.is_empty(): color = model.item_definition(selected_item).color
				if facing_preview >= 0: color = CYAN
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
			if cell == item_origin:
				SpiritIcon.paint(self,_center(cell),model.item_definition("magic_bolt").icon,1.1)
	if item_origin != Vector2i(-1,-1):
		var start := _center(item_origin)
		var end := start+Vector2(aim)*28
		draw_line(start,end,GOLD,5)
		var side := Vector2(-aim.y,aim.x)*8
		draw_colored_polygon(PackedVector2Array([end+Vector2(aim)*8,end-Vector2(aim)*7+side,end-Vector2(aim)*7-side]),GOLD)

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
	_text(Vector2(24,250),"武器",23,INK)
	_text(Vector2(153,250),"選択は無料",18,MUTED)

func _draw_weapons() -> void:
	for slot in range(3):
		var index: int = WEAPON_UI_ORDER[slot]
		var weapon: Dictionary = Rules.WEAPONS[index]
		var pos := Vector2(24,261+slot*75)
		var rect := Rect2(pos,Vector2(280,72))
		var accent := Color(weapon.color)
		draw_rect(rect,Color("152324") if model.weapon==index else Color("0b1415"))
		draw_rect(rect,accent if model.weapon==index else Color("324843"),false,3 if model.weapon==index else 2)
		if selected_weapon == index:
			draw_rect(rect.grow(-5),INK,false,1)
		draw_texture_rect_region(UnitView.PLAYER_ATLAS,Rect2(pos+Vector2(5,6),Vector2(60,60)),Rect2(2*UnitView.PLAYER_ATLAS_CELL,weapon.row*UnitView.PLAYER_ATLAS_CELL,UnitView.PLAYER_ATLAS_CELL,UnitView.PLAYER_ATLAS_CELL))
		_text(pos+Vector2(70,29),weapon.name,21,accent)
		_text(pos+Vector2(70,60),"装備中" if model.weapon==index else "確認中" if selected_weapon==index else "[%d]" % [2,1,3][index],18,INK if model.weapon==index else MUTED)
		var count := 3
		var step := 15
		var self_cell: Vector2i = Vector2i(1,1)-Rules.CARDINALS[model.facing] if index == 2 else Vector2i(1,1)
		var offsets := model.weapon_offsets(index,model.facing)
		for y in range(count):
			for x in range(count):
				var offset := Vector2i(x,y)-self_cell
				var active: bool = offsets.has(offset)
				var color := accent if active else INK if offset == Vector2i.ZERO else Color("30433d")
				var tile := Rect2(pos+Vector2(225+x*step,26+y*step),Vector2(step-3,step-3))
				draw_rect(tile,color if offset != Vector2i.ZERO else Color("192828"))
				if offset == Vector2i.ZERO:
					_draw_player_portrait(index,tile.get_center(),20)

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
	if facing_preview >= 0:
		_text(Vector2(852,133),"向き変更",26,CYAN)
		_text(Vector2(852,177),"現在 %s   選択 %s" % [FACING_ARROWS[model.facing],FACING_ARROWS[facing_preview]],21,INK)
		_draw_range(model.weapon_offsets(model.weapon,facing_preview),CYAN,{},model.weapon,facing_preview,facing_preview,true)
		_text(Vector2(852,376),"移動・攻撃範囲",21,INK)
		return
	var enemy := _preview_enemy()
	if not enemy.is_empty():
		_draw_enemy_inspector(enemy)
	elif selected_weapon >= 0:
		var weapon: Dictionary = Rules.WEAPONS[selected_weapon]
		_text(Vector2(852,133),weapon.name,25,Color(weapon.color))
		_text(Vector2(852,177),"装備中" if selected_weapon == model.weapon else "確認中・未装備",21,MUTED)
		_draw_range(model.weapon_offsets(selected_weapon,model.facing),Color(weapon.color),{},selected_weapon,model.facing)
		_text(Vector2(852,495),"移動・攻撃範囲",23,INK)
		if selected_weapon == 2:
			_text(Vector2(852,535),"前へ2マス・左右へ1マス",20,MUTED)
		else:
			_text(Vector2(852,535),"持ち替えは左のボタン",20,MUTED)
	else:
		_text(Vector2(852,133),"敵の情報",26,CYAN)
		_text(Vector2(852,295),"敵にカーソルを",23,INK)
		_text(Vector2(852,330),"合わせて確認",23,INK)
		_text(Vector2(852,540),"右クリックで固定",20,MUTED)

func _draw_player_portrait(weapon_index: int, center: Vector2, side: float, facing_index: int = 2) -> void:
	var cell := UnitView.PLAYER_ATLAS_CELL
	var row: int = Rules.WEAPONS[weapon_index].row
	draw_texture_rect_region(UnitView.PLAYER_ATLAS,Rect2(center-Vector2.ONE*side/2,Vector2.ONE*side),Rect2(facing_index*cell,row*cell,cell,cell))

func _draw_range(offsets: Array, accent: Color, enemy: Dictionary = {}, weapon_index: int = -1, forward_index: int = 0, portrait_index: int = 2, compact: bool = false) -> void:
	var count := 3
	var step := 52 if compact else 64
	# Place the knight opposite its forward direction to retain a true 3x3 range.
	var self_cell: Vector2i = Vector2i(1,1)-Rules.CARDINALS[forward_index] if weapon_index == 2 else Vector2i(1,1)
	if enemy.get("type","") == "cavalry":
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
		var fade: float = effect.life/0.42
		if effect.kind in ["bolt","warp","summon","ambush"]:
			var tint := Color("ffbd59") if effect.kind == "bolt" else CYAN if effect.kind == "warp" else Color("aa8cff")
			draw_arc(pos,12+(1-fade)*22,0,TAU,24,Color(tint,fade),4,true)
			continue
		var row := 1 if effect.kind == "mine" else 3 if effect.kind == "plant" else 0
		if effect.kind != "weapon_hit":
			draw_texture_rect_region(EFFECTS,Rect2(pos-Vector2(32,32),Vector2(64,64)),Rect2(16*24,row*24,24,24),Color(1,1,1,fade))
		if effect.kind != "plant":
			_text(pos+Vector2(9,-26-(1-fade)*20),"−1",22,Color(1,0.65,0.4,fade))

func _draw_result() -> void:
	draw_rect(Rect2(352,144,448,448),Color("0a1415"))
	_panel(Rect2(368,226,416,282))
	var won: bool = model.phase == Rules.Phase.WON
	_text(Vector2(414,278),"SECTOR CLEAR" if won else "EXPEDITION FAILED",36,CYAN if won else Color("ff8968"),LATIN)
	_text(Vector2(421,326),"全3戦クリア！" if won and model.level==2 else "包囲網を突破した" if won else "探索者、倒れる",26)
	_text(Vector2(423,365),"%dターン / 撃破 %d体" % [model.round_number,model.kills],18,MUTED)
	_text(Vector2(423,396),"次の戦闘はHP5から開始" if won else "武器と間合いを変えて再挑戦",16,MUTED)

func _draw_rules() -> void:
	draw_rect(Rect2(320,116,500,501),Color("060e10"))
	_panel(Rect2(328,124,484,485))
	_text(Vector2(352,163),"FIELD MANUAL",28,CYAN,LATIN)
	var lines := ["ENEMY  →  YOU", "MOVE / ATTACK / ITEM = 1 AP", "1–3 PREVIEW  /  EQUIP BUTTON = 1 AP", "TURN PREVIEW / CONFIRM = 1 AP", "SPACE  END TURN    R  RESET"]
	for i in range(lines.size()):
		_text(Vector2(350,212+i*55),lines[i],20,INK if i%2==0 else MUTED,LATIN)
	_text(Vector2(350,503),"! 次の敵ターンに突撃",20,GOLD)
	_text(Vector2(350,554),"4–9 / 0 CARDS   ESC CANCEL",20,INK,LATIN)
