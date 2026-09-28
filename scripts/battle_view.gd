extends Node2D

signal finished
var managed_run := false

const Rules = preload("res://scripts/battle_model.gd")
const Planner = preload("res://scripts/enemy_planner.gd")
const WeaponEffect = preload("res://scripts/weapon_effect.gd")
const UnitView = preload("res://scripts/unit_view.gd")
const InventoryView = preload("res://scripts/items/inventory_view.gd")
const ItemPreview = preload("res://scripts/items/item_preview.gd")
const SHADOW_SPENT = preload("res://assets/sprites/spirits/shadow_stitch_spent.png")
const ABYSS_PIT = preload("res://assets/sprites/spirits/abyss_pit.png")
const GRAVITY_PULL = Color("5fd4ff")
const GRAVITY_PUSH = Color("ff9a4a")
## Hover preview for the gravity fairy: [from, to] per enemy it would move (cached per tile).
var gravity_hover := Vector2i(-9, -9)
var gravity_moves: Array = []
const SpiritIcon = preload("res://scripts/items/spirit_icon.gd")
const ThreatPreview = preload("res://scripts/threat_preview.gd")
const CAPACITOR_CHARGED = preload("res://assets/sprites/spirits/capacitor_fairy_charged.png")
const CAPACITOR_DISCHARGE = preload("res://assets/sprites/effects/capacitor_discharge.png")
const ZAP_H = preload("res://assets/sprites/effects/zap_h.png")
const ZAP_V = preload("res://assets/sprites/effects/zap_v.png")
const CLOCKWISE_NEXT = {Vector2i.UP: Vector2i.RIGHT, Vector2i.RIGHT: Vector2i.DOWN, Vector2i.DOWN: Vector2i.LEFT, Vector2i.LEFT: Vector2i.UP}
const RangeDiagram = preload("res://scripts/run/range_diagram.gd")
const Catalog = preload("res://scripts/run/weapon_catalog.gd")
const DirectionSheet = preload("res://scripts/items/direction_sheet.gd")
const AXE_DASH = preload("res://assets/sprites/spirits/axe_spirit_dash.png")
const MagicCircleFx = preload("res://scripts/fx/magic_circle_fx.gd")
const AbyssFx = preload("res://scripts/fx/abyss_fx.gd")
const BossCinematic = preload("res://scripts/fx/boss_cinematic.gd")
const BOSS_FLOOR = preload("res://assets/sprites/boss/boss_floor.png")
const BOSS_THRONE = preload("res://assets/sprites/boss/boss_throne_floor.png")
const FORTRESS_RUIN = preload("res://assets/sprites/boss/prison_fortress_ruin.png")
## The Prison King's throne dais: the tiles under him when the fight began.
var throne_cells: Array[Vector2i] = []
const HelpPanel = preload("res://scripts/ui/help_panel.gd")
## The manual opens by itself on the first battle after the game starts (not saved).
static var help_seen := false
var help: Control
const CIRCLE_WHITE = Color("f4f2ea")
const BgmPlayer = preload("res://scripts/audio/bgm_player.gd")
const SfxPlayer = preload("res://scripts/audio/sfx_player.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const LATIN = preload("res://assets/fonts/VT323-Regular.ttf")
const HP_EMPTY = preload("res://assets/sprites/editor_ui/part_capacity_unit_empty.png")
const HP_FULL = preload("res://assets/sprites/editor_ui/part_capacity_unit_filled.png")
const GADGET = preload("res://assets/sprites/editor_ui/part_gadget_editor_icon.png")
const EFFECTS = preload("res://assets/sprites/effects/element_connection_atlas_24.png")
var BOARD := Vector2(384,176)
## Largest board the grid buttons cover (the boss stage is 7x7).
const MAX_BOARD := 10
## Tile size: 64, or smaller so a 10x10 board fits the same space as an 8x8.
var TILE := 64.0
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
## Magic circle: enemies it kills stay on screen until the burst of light.
var hold_dead_until := 0.0
var last_circle: Dictionary = {}
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
var sfx: Node

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * UI_SCALE
	if not managed_run:
		model.reset()
	weapon_effects = Node2D.new()
	add_child(weapon_effects)
	bgm = BgmPlayer.new()
	add_child(bgm)
	sfx = SfxPlayer.new()
	add_child(sfx)
	_make_ui()
	_start(model.level,true)
	if model.level == 0:
		_maybe_first_help()

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
	for y in range(MAX_BOARD):
		for x in range(MAX_BOARD):
			var cell := Vector2i(x,y)
			var tile_button := _button(ui,Rect2(BOARD+Vector2(cell)*TILE,Vector2(TILE,TILE)),"",func(): _act(cell))
			grid_buttons.append(tile_button)
	end_button = _button(ui,Rect2(24,580,280,58),"ターン終了 [SPACE]",_enemy_turn)
	rules_button = _button(ui,Rect2(802,34,142,36),"遊び方 [H]",_toggle_rules)
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
	# The manual sits on top of everything else in the UI layer.
	help = HelpPanel.new()
	help.size = Vector2(1152,720)
	help.visible = false
	help.closed.connect(func():
		show_rules = false
		_update_controls())
	ui.add_child.call_deferred(help)
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
	bgm.theme = "king" if model.level == Rules.FINAL_LEVEL else "boss" if model.level == Rules.BOSS_LEVEL or Rules.LATE_LEVELS.has(model.level) else "rotorick" if model.level == Rules.BOSS2_LEVEL else "battle"
	TILE = 64.0 if model.board_size <= 8 else floorf(512.0/model.board_size)
	BOARD = Vector2(384,176)+Vector2.ONE*(6-model.board_size)*TILE/2.0
	# 8x8 (and the shrunk 10x10) fill the full height between the header and the weapon cards.
	if model.board_size >= 8:
		BOARD = Vector2(316,96)
	for i in range(grid_buttons.size()):
		var cell := Vector2i(i%MAX_BOARD,i/MAX_BOARD)
		grid_buttons[i].position = BOARD+Vector2(cell)*TILE
		grid_buttons[i].size = Vector2(TILE,TILE)
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
	_update_controls()
	queue_redraw()
	throne_cells.clear()
	for enemy in model.enemies:
		if enemy.type == "king":
			throne_cells.assign(model.footprint(enemy))
	if model.enemies.any(func(e: Dictionary) -> bool: return e.type in Rules.CHARGERS and e.state == "idle"):
		_boss_intro()
	if model.level == Rules.FINAL_LEVEL:
		_final_intro()
	elif model.level == Rules.BOSS2_LEVEL:
		# Rotorick: the reels spin up before his music starts.
		bgm.hold(1.9)
		_sting("rotorick_intro")

## The Prison King's entrance: black-out, the throne hall, his name, then the fight.
func _final_intro() -> void:
	busy = true
	var token := generation
	_update_controls()
	await _cinematic("intro")
	if token != generation:
		return
	busy = false
	_update_controls()

## Play one of the king's cinematics and wait for it.
func _cinematic(mode: String, focus := Vector2(576, 360)) -> void:
	var fx := BossCinematic.new()
	fx.mode = mode
	fx.focus = focus
	fx.screen = Rect2(Vector2(-40, -40), Vector2(1152, 720) + Vector2(80, 80))
	fx.shake_target = self
	# Above the side panels and buttons too: the whole screen goes dark.
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.scale = Vector2.ONE * UI_SCALE
	add_child(layer)
	layer.add_child(fx)
	# Each cinematic has its sting: the intro holds the music until it ends,
	# the rage and the fall dip it underneath.
	if mode == "intro":
		bgm.hold(BossCinematic.LIFE[mode])
	else:
		bgm.duck(BossCinematic.LIFE[mode])
	_sting({"intro":"king_intro", "rage":"king_rage", "fall":"king_fall"}[mode])
	await get_tree().create_timer(BossCinematic.LIFE[mode]).timeout

## The rook enters blue, pauses, then snaps into its red stance before the player moves.
func _boss_intro() -> void:
	busy = true
	var token := generation
	_update_controls()
	await get_tree().create_timer(0.9).timeout
	if token != generation:
		return
	model.boss_intro()
	_sync_units(false)
	_feedback()
	for actor in actors.values():
		if actor.kind in Rules.CHARGERS:
			actor.flash = 0.25
	queue_redraw()
	await get_tree().create_timer(0.5).timeout
	if token != generation:
		return
	busy = false
	_sync_units(false)
	_update_controls()

func _advance() -> void:
	if managed_run:
		finished.emit()
	else:
		_start(model.level+1 if model.level < Rules.LAST_LEVEL else 0,true)

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
	if not await _glutton_windup(token):
		return
	_sync_units(true)
	_feedback()
	_update_controls()
	if not model.allies.is_empty():
		var feast := model.events.any(func(e: Dictionary) -> bool: return e.kind in ["devour","gulp"])
		var wait := 0.8 if feast else 0.22
		if model.events.any(func(e: Dictionary) -> bool: return e.kind == "king_rage"):
			wait = BossCinematic.LIFE["rage"]
		if model.events.any(func(e: Dictionary) -> bool: return e.kind == "king_fall"):
			wait = BossCinematic.LIFE["fall"]
		await get_tree().create_timer(wait).timeout
		if token != generation:
			return
	if model.terminal():
		busy = false
		_update_controls()
		return
	planner.begin(model)
	_update_controls()
	if not model.events.is_empty():
		# Rule A: the siege closing and burning shows before the enemies move.
		_sync_units(true)
		_feedback()
		queue_redraw()
		await get_tree().create_timer(0.35).timeout
		if token != generation:
			return
	await get_tree().create_timer(0.12).timeout
	if token != generation:
		return
	for beat in range(2):
		var cells := {}
		for enemy in model.enemies:
			cells[enemy.id] = enemy.cell
		planner.beat(model,beat)
		if model.enemies.any(func(e: Dictionary) -> bool: return cells.has(e.id) and cells[e.id] != e.cell):
			_sound("enemy_step")
		if not await _play_charges(token):
			return
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
	if model.can_swap_shadow(cell):
		# 影縫い精霊: trade places with the pinned shadow, 0 AP.
		selected_enemy_id = -2
		model.player_action(cell)
		_finish_player_action(true)
		return
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
	var weapon_kind: String = Rules.WEAPONS[weapon_action.weapon].id if not weapon_action.is_empty() else ""
	# Swords swing; the hammer uses its own sheet; the bow just looses an arrow.
	var sword_attack: bool = not weapon_action.is_empty() and weapon_action.attacking and weapon_kind not in ["hammer","bow"]
	if not weapon_action.is_empty() and not weapon_action.attacking:
		_sound("step")
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
		if not weapon_action.is_empty() and weapon_kind != "bow":
			var effect := WeaponEffect.new()
			effect.weapon = 0 if weapon_kind == "hammer" else 1
			effect.attacking = weapon_action.attacking
			effect.origin = _center(weapon_action.origin)
			effect.destination = _center(weapon_action.destination)
			weapon_effects.add_child(effect)
			action_duration = effect.duration()
		_feedback(not weapon_action.is_empty() and weapon_action.attacking)
		# Let the magic circle play out before the turn moves on.
		if model.events.any(func(e: Dictionary) -> bool: return e.kind == "circle"):
			action_duration = maxf(action_duration, MagicCircleFx.BURST + 0.4)
		# The king's rage and fall are cinematics: wait them out.
		if model.events.any(func(e: Dictionary) -> bool: return e.kind == "king_rage"):
			action_duration = maxf(action_duration, BossCinematic.LIFE["rage"])
		if model.events.any(func(e: Dictionary) -> bool: return e.kind == "king_fall"):
			action_duration = maxf(action_duration, BossCinematic.LIFE["fall"])
		# Let the abyss finish opening too.
		if model.events.any(func(e: Dictionary) -> bool: return e.kind == "summon" and e.get("fx","") == "abyss"):
			action_duration = maxf(action_duration, AbyssFx.LIFE - 0.3)
		_update_controls()
		await get_tree().create_timer(action_duration).timeout
	if token != generation:
		return
	busy = false
	_update_controls()
	if not model.terminal() and model.player.ap == 0:
		_enemy_turn()

## Several charges in one beat (Rotorick's reel 7): play them one at a time with
## a pause, so each crash and stop reads before the next charge starts.
func _play_charges(token: int) -> bool:
	var marks: Array = model.events.filter(func(e: Dictionary) -> bool: return e.kind == "charge_end")
	if marks.size() < 2:
		return true
	var all_events: Array = model.events.duplicate()
	var start := 0
	for mark in marks.slice(0, marks.size() - 1):
		var end: int = all_events.find(mark)
		model.events.assign(all_events.slice(start, end))
		_feedback()
		var tween := create_tween().set_parallel(true)
		if actors.has(mark.id):
			var span: int = actors[mark.id].span
			tween.tween_property(actors[mark.id], "position", _unit_center({"cell":mark.cell, "size":span}), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(actors[-1], "position", _center(mark.player), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		queue_redraw()
		await get_tree().create_timer(0.5).timeout
		if token != generation:
			return false
		start = end + 1
	model.events.assign(all_events.slice(start))
	return true

func _select_item(id: String, slot: int = -1) -> void:
	if busy or show_rules or model.phase != Rules.Phase.PLAYER:
		return
	var item: Resource = model.item_definition(id)
	if item == null or model.inventory.get(id,0) <= 0 or model.player.ap < model.fairy_ap_cost(id):
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
	gravity_hover = Vector2i(-9, -9)
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
	if model.is_directional(selected_item):
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
	help.visible = show_rules
	if show_rules:
		help._show()
	_update_controls()

## First battle of this session: open the manual once.
func _maybe_first_help() -> void:
	if help_seen or not managed_run:
		return
	help_seen = true
	_toggle_rules()

func _sync_units(animate: bool) -> void:
	for event in model.events:
		if event.kind == "circle" and not is_same(event, last_circle):
			last_circle = event
			hold_dead_until = clock + MagicCircleFx.BURST
			get_tree().create_timer(MagicCircleFx.BURST + 0.05).timeout.connect(func(): _sync_units(false))
	var living: Array[int] = [-1]
	var units: Array = [model.player]+model.enemies+model.allies
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	if animate:
		move_tween = create_tween().set_parallel(true)
	# "!" marks every enemy that would hit the player if they stayed put.
	var threats: Array[int] = []
	if model.phase == Rules.Phase.PLAYER:
		threats = ThreatPreview.attackers(model)
	for unit in units:
		var id: int = unit.id
		living.append(id)
		if not actors.has(id):
			var actor := UnitView.new()
			actor.kind = unit.type
			actor.span = int(unit.get("size",1))
			actor.position = _unit_center(unit)
			actor.scale = Vector2.ONE*TILE/64.0
			actor.z_index = 2
			add_child(actor)
			actors[id] = actor
		var view: Node2D = actors[id]
		view.hp = unit.hp
		# "!" on enemies about to hit the player, and on a glutton about to bite them.
		view.charge_warning = id != -1 and threats.has(id)
		view.weapon_row = Rules.WEAPONS[model.weapon].row
		var target := _unit_center(unit)
		view.facing = int(unit.get("facing",2)) if unit.type == "holy_knight" else 1 if id < 0 else int(unit.get("facing",3)) if unit.type in UnitView.BOSS_KINDS else 3
		view.braced = unit.get("state","") == "brace"
		view.reel = int(unit.get("reel",0))
		view.alt_row = unit.get("state","") == "aim" or int(unit.get("learned",-1)) >= 0
		var learned := int(unit.get("learned",-1))
		view.learned_text = "解析:" + Rules.WEAPONS[learned].short if learned >= 0 else ""
		view.learned_color = Color(Rules.WEAPONS[learned].color) if learned >= 0 else Color.WHITE
		view.set_meta("cells", model.footprint(unit))
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
			if clock < hold_dead_until:
				continue
			if actors[id].kind in ["king", "fortress"] and not actors[id].get_meta("fallen", false):
				actors[id].set_meta("fallen", true)
				_sound(actors[id].kind + "_collapse")
			if actors[id].kind == "king":
				# The king crumbles through his death frames before he is gone.
				actors[id].play_anim("death")
				continue
			actors[id].queue_free()
			actors.erase(id)

func _sound(name: String, volume_db: float = 0.0) -> void:
	if sfx != null:
		sfx.play(name, volume_db)

func _sting(name: String) -> void:
	if sfx != null:
		sfx.sting(name)

## The sound one event makes ("" for none). Only the Prison King's fight has
## event sounds: his revivals, the fortresses' soldiers, and hits on either.
func _event_sound(event: Dictionary) -> String:
	match event.kind:
		"hit":
			if actors.has(int(event.id)):
				match actors[int(event.id)].kind:
					"king":
						return "king_hit"
					"fortress":
						return "fortress_crack"
		"summon":
			if event.has("by"):
				return "king_revive" if event.get("fx", "") == "revive" else "fortress_spawn"
	return ""

func _feedback(weapon_attack: bool = false) -> void:
	# A magic circle shows its own "99"s: no ordinary hit popups under it.
	var casting := model.events.any(func(e: Dictionary) -> bool: return e.kind == "circle")
	var heard := {}
	for event in model.events:
		var sound := _event_sound(event)
		if sound != "" and not heard.has(sound):
			heard[sound] = true
			_sound(sound)
	for event in model.events:
		if casting and event.kind == "hit" and event.id >= 0:
			continue
		var kind: String = "weapon_hit" if weapon_attack and event.kind == "hit" else event.kind
		var flash: Dictionary = event.duplicate()
		flash.kind = kind
		flash.life = FX_LIFE.get(kind,0.42)
		flash.max_life = flash.life
		flashes.append(flash)
		if event.kind == "circle":
			_cast_circle_fx(event)
		if event.kind == "summon" and event.get("fx","") == "abyss":
			_open_abyss_fx()
		# The Prison King and his fortresses act out what happened.
		if event.kind == "summon" and event.has("by") and actors.has(int(event.by)):
			actors[int(event.by)].play_anim("revive" if event.get("fx","") == "revive" else "spawn")
		if event.kind == "hit" and actors.has(int(event.id)) and actors[int(event.id)].kind == "king":
			actors[int(event.id)].play_anim("hurt")
		if event.kind == "king_rage":
			_cinematic("rage")
		if event.kind == "king_fall":
			_cinematic("fall", _center(event.cell))
		if event.kind in ["devour","gulp"] and actors.has(int(event.by)):
			# The glutton swells with every mouthful.
			var eater: Node2D = actors[int(event.by)]
			var swell := create_tween()
			var base := TILE/64.0
			swell.tween_property(eater,"scale",Vector2.ONE*base*(1.35 if event.kind == "devour" else 1.2),0.12)
			swell.tween_property(eater,"scale",Vector2.ONE*base,0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		if actors.has(event.id) and event.kind not in ["plant", "charge_end"]:
			actors[event.id].flash = 0.18

func _open_abyss_fx() -> void:
	var fx := AbyssFx.new()
	fx.tile = TILE
	fx.origin = _center(model.player.cell)
	for cell in model.pits:
		fx.pits.append(BOARD + Vector2(cell) * TILE)
	fx.screen = Rect2(Vector2(-40, -40), Vector2(1152, 720) + Vector2(80, 80))
	fx.shake_target = self
	# Above the side panels and buttons too: the whole screen goes dark.
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.scale = Vector2.ONE * UI_SCALE
	add_child(layer)
	layer.add_child(fx)

## Before a glutton bites the player it winds up: it trembles and swells, "……！"
func _glutton_windup(token: int) -> bool:
	var gulps: Array = model.events.filter(func(e: Dictionary) -> bool: return e.kind == "gulp")
	if gulps.is_empty():
		return true
	for event in gulps:
		if not actors.has(int(event.by)):
			continue
		var eater: Node2D = actors[int(event.by)]
		var home := eater.position
		var windup := create_tween()
		windup.tween_method(func(k: float):
			eater.scale = Vector2.ONE * TILE / 64.0 * (1.0 + 0.3 * k)
			eater.position = home + Vector2(sin(k * 90.0), cos(k * 70.0)) * 3.0 * k,0.0,1.0,0.65)
		windup.tween_callback(func(): eater.position = home)
		flashes.append({"kind":"windup", "cell":event.from, "id":-2, "life":0.7, "max_life":0.7})
	await get_tree().create_timer(0.7).timeout
	return token == generation

func _cast_circle_fx(event: Dictionary) -> void:
	var fx := MagicCircleFx.new()
	fx.tile = TILE
	for cell in event.cells:
		fx.area.append(_center(cell))
	for cell in event.line:
		fx.line.append(_center(cell))
	for unit in event.targets:
		fx.targets.append(_unit_center(unit))
	fx.damage = Rules.CIRCLE_DAMAGE
	fx.screen = Rect2(Vector2(-40, -40), Vector2(1152, 720) + Vector2(80, 80))
	fx.shake_target = self
	# Above the side panels and buttons too: the whole screen goes dark.
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.scale = Vector2.ONE * UI_SCALE
	add_child(layer)
	layer.add_child(fx)

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
	# Rotorick's music reacts to the reel on show: 5 breaks down, 7 hits the jackpot.
	var reel := 0
	for enemy in model.enemies:
		if enemy.type == "slot":
			reel = int(enemy.get("reel",0))
	bgm.set_layer("error" if reel == 5 else "jackpot" if reel == 7 else "normal")
	# The Prison King's theme turns to its rage twin at half health.
	bgm.set_king_rage(model.king_enraged())
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
	var attack_cells: Array = model.targets() if not busy and selected_item.is_empty() and model.phase == Rules.Phase.PLAYER and not model.is_circle(model.weapon) else []
	for id in actors:
		var actor = actors[id]
		var cells: Array = actor.get_meta("cells", [Vector2i((actor.position-BOARD)/TILE)])
		actor.attack_target = id >= 0 and cells.any(func(c: Vector2i) -> bool: return attack_cells.has(c))
	# A lone wolf inside any weapon's reach will sulk on its turn: it shows "…".
	if model.allies.any(func(a: Dictionary) -> bool: return a.type == "wolf"):
		var reach: Array[Vector2i] = model.all_reach()
		for wolf in model.allies:
			if wolf.type == "wolf" and actors.has(wolf.id):
				actors[wolf.id].sulking = wolf.hp > 0 and reach.has(wolf.cell)
				actors[wolf.id].sulk_flip = model.player.cell.x > wolf.cell.x
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
			bgm.toggle_mute()  # the sound effects follow the music
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

## Units bigger than one tile sit in the middle of their footprint.
func _unit_center(unit: Dictionary) -> Vector2:
	return _center(unit.cell)+Vector2.ONE*TILE/2*(int(unit.get("size",1))-1)

func _text(at: Vector2,text: String,size: int=20,color: Color=INK,font: Font=null) -> void:
	draw_string(ui_font if font == null else font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _text_width(text: String, size: int) -> float:
	return ui_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x

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
	var stage_title := "最終決戦" if model.level == Rules.FINAL_LEVEL else "ボス戦" if Rules.BOSS_LEVELS.has(model.level) else "中盤 %d / 3" % (Rules.MID_LEVELS.find(model.level)+1) if Rules.MID_LEVELS.has(model.level) else "終盤 %d / 3" % (Rules.LATE_LEVELS.find(model.level)+1) if Rules.LATE_LEVELS.has(model.level) else "戦闘 %d / 3" % (model.level+1)
	_text(Vector2(44,62),stage_title,25,Color("ff8b8f") if Rules.BOSS_LEVELS.has(model.level) else CYAN)
	_text(Vector2(260,62),"ターン %02d" % model.round_number,23)
	_text(Vector2(480,62),"敵 残り %d" % model.enemies.size(),23)
	_draw_board()
	_draw_player_panel()
	_draw_weapons()
	_draw_intel()
	_draw_flashes()
	var turn_text := "敵のターン" if busy and model.phase==Rules.Phase.ENEMY else "あなたのターン"
	if model.board_size >= 8:
		# The 8x8 board reaches up here, so the turn label moves into the player panel.
		_text(Vector2(40,208),turn_text,22,CYAN if not busy else GOLD)
	else:
		_text(Vector2(352,126),turn_text,27,CYAN if not busy else GOLD)
	if model.abyss_turns > 0:
		_text(Vector2(40,262) if model.board_size >= 8 else Vector2(352,156),"奈落 あと%dターン" % model.abyss_turns,18,Color("b8a8ff"))
	var countdown := model.siege_countdown()
	if model.rule_siege:
		var siege_text := "包囲：この敵ターンで狭まる" if countdown == 0 else "包囲まで %dターン" % countdown if countdown > 0 else "包囲：これ以上狭まらない"
		_text(Vector2(40,236) if model.board_size >= 8 else Vector2(560,126),siege_text,18,Color("ff8b8f") if countdown == 0 else MUTED)

	if selected_item == "gravity_fairy" and model.item_targets("gravity_fairy").has(hover_cell) and not busy:
		_text(Vector2(36,673),"引き寄せる（攻撃範囲）" if model.gravity_pulls(hover_cell) else "弾く（攻撃範囲外）",23,GRAVITY_PULL if model.gravity_pulls(hover_cell) else GRAVITY_PUSH)
	elif model.can_swap_shadow(hover_cell) and selected_item.is_empty() and not busy:
		_text(Vector2(36,673),"影と入れ替わる 0 AP",23,CYAN)
	elif model.inside(hover_cell) and model.targets().has(hover_cell) and selected_item.is_empty() and not busy:
		_text(Vector2(36,673),"移動 1 AP" if model.enemy_at(hover_cell).is_empty() else "攻撃 1 AP",23,GOLD)
	if model.terminal() and not busy:
		_draw_result()

func _draw_board() -> void:
	var extent := Vector2.ONE*model.board_size*TILE
	# The 8x8 board sits flush between the panels, so its frame is thinner.
	var rim := 4.0 if model.board_size >= 8 else 10.0
	draw_rect(Rect2(BOARD-Vector2.ONE*rim,extent+Vector2.ONE*rim*2),Color("252820"))
	draw_rect(Rect2(BOARD-Vector2.ONE*rim,extent+Vector2.ONE*rim*2),Color("4d5443"),false,3)
	var legal: Array = []
	if model.phase == Rules.Phase.PLAYER and not busy and not show_rules and not inventory_ui.opened:
		legal = model.targets().filter(func(cell: Vector2i) -> bool: return not model.blocked(cell) or not model.cannon_at(cell).is_empty()) if selected_item.is_empty() else model.item_targets(selected_item)
		if selected_item.is_empty() and model.is_circle(model.weapon):
			# A circle weapon only moves: enemies and cannons are not targets.
			legal = legal.filter(func(cell: Vector2i) -> bool: return model.enemy_at(cell).is_empty() and model.cannon_at(cell).is_empty())
		if item_origin != Vector2i(-1,-1):
			legal = model.directional_preview(selected_item,item_origin,aim)
		if selected_item.is_empty() and model.can_swap_shadow(model.shadow.get("cell",Vector2i(-1,-1))):
			legal.append(model.shadow.cell)
	# Hammer: hovering a target shows the whole area it will shake. Bow: its diagonal lines.
	var hammer_zone: Array[Vector2i] = []
	var bow_zone: Array[Vector2i] = []
	if model.phase == Rules.Phase.PLAYER and not busy and selected_item.is_empty():
		if Rules.WEAPONS[model.weapon].id == "hammer" and model.targets().has(hover_cell) and not model.enemy_at(hover_cell).is_empty():
			hammer_zone = model.hammer_area(hover_cell)
		elif Rules.WEAPONS[model.weapon].id == "bow":
			bow_zone = model.bow_lines()
	# Slash spirit: hovering a legal tile shows the two tiles it will cut.
	var slash_zone: Array[Vector2i] = []
	if selected_item == "slash_fairy" and model.item_targets("slash_fairy").has(hover_cell):
		slash_zone = model.side_slash_cells(hover_cell)
		if not model.enemy_at(hover_cell).is_empty():
			slash_zone.append(hover_cell)
	# Magic circle: hovering a move shows the area it would close.
	var circle_zone: Array[Vector2i] = []
	if model.is_circle(model.weapon) and model.phase == Rules.Phase.PLAYER and not busy and selected_item.is_empty() and model.targets().has(hover_cell) and model.enemy_at(hover_cell).is_empty() and not model.blocked(hover_cell):
		circle_zone = model.circle_preview(hover_cell)
	var danger: Array[Vector2i] = []
	for enemy in model.enemies:
		if enemy.hp > 0 and enemy.get("state","") == "aim":
			danger.append_array(model.archer_lane(enemy))
		elif enemy.hp > 0 and enemy.type in Rules.CHARGERS and enemy.get("state","") == "brace":
			danger.append_array(model.rook_lane(enemy))
	for y in range(model.board_size):
		for x in range(model.board_size):
			var cell := Vector2i(x,y)
			# Each tile is drawn in its own 64-unit space, scaled down on big boards.
			draw_set_transform(BOARD+Vector2(cell)*TILE,0,Vector2.ONE*TILE/64.0)
			var pos := Vector2.ZERO
			var mid := Vector2(32,32)
			var base := Color("665b48")
			var shade := 0.88+float((x*13+y*7)%5)*0.025
			if model.level == Rules.FINAL_LEVEL:
				# The prison's flagstones, and the throne dais under the king.
				draw_texture_rect(BOSS_THRONE if throne_cells.has(cell) else BOSS_FLOOR,Rect2(pos,Vector2(64,64)),false,Color(shade,shade,shade))
			else:
				draw_rect(Rect2(pos+Vector2(2,2),Vector2(60,60)),base*shade)
			draw_line(pos+Vector2(3,59),pos+Vector2(59,59),Color("38362a"),2)
			draw_line(pos+Vector2(3,3),pos+Vector2(59,3),Color("766b54"),1)
			if (x*3+y)%4==0:
				draw_line(pos+Vector2(39,4),pos+Vector2(34,13),Color("494535"),2)
			if bow_zone.has(cell):
				draw_circle(pos+Vector2(32,32),5,Color("b7e07a",0.55))
			if slash_zone.has(cell):
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),Color(model.item_definition("slash_fairy").color,0.3))
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),model.item_definition("slash_fairy").color,false,3)
			if hammer_zone.has(cell):
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),Color(1,0.55,0.25,0.25))
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),Color("ffa45a"),false,3)
			if model.circle_tiles.has(cell):
				# Magic circle chalk: white tiles that stay all fight (a burning floor is drawn over them).
				var glow := 0.55 + 0.08 * sin(clock * 3.0 + x + y)
				draw_rect(Rect2(pos+Vector2(3,3),Vector2(58,58)),Color(0.94,0.95,1.0,glow))
				draw_rect(Rect2(pos+Vector2(3,3),Vector2(58,58)),Color("fffdf2"),false,2)
				draw_arc(pos+Vector2(32,32),10,clock,clock+TAU*0.8,16,Color(GOLD,0.55),2,true)
			if circle_zone.has(cell):
				# Preview: what closing the circle here would catch (pulsing gold).
				var pulse := 0.5 + 0.5 * sin(clock * 8.0)
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),Color(1,0.95,0.7,0.2+0.15*pulse))
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),GOLD,false,2)
			if model.pits.has(cell):
				# 奈落の精霊: connected pits read as one dark rift (no repeated holes),
				# with a crumbling stone lip only where the rift meets solid floor.
				draw_rect(Rect2(pos,Vector2(64,64)),Color("08060f"))
				draw_rect(Rect2(pos,Vector2(64,64)),Color(0.32,0.24,0.62,0.07+0.04*sin(clock*1.3+x*0.8+y*0.6)))
				for side in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
					if model.pits.has(cell+side):
						continue
					var lip := Rect2(pos,Vector2(64,6)) if side == Vector2i.UP else Rect2(pos+Vector2(0,58),Vector2(64,6)) if side == Vector2i.DOWN else Rect2(pos,Vector2(6,64)) if side == Vector2i.LEFT else Rect2(pos+Vector2(58,0),Vector2(6,64))
					draw_rect(lip,Color("4a4233"))
					var edge_a := lip.position if side != Vector2i.RIGHT else lip.position+Vector2(6,0)
					var edge_b := edge_a+(Vector2(64,0) if side.y != 0 else Vector2(0,64))
					if side == Vector2i.DOWN:
						edge_a += Vector2(0,6)
						edge_b += Vector2(0,6)
					draw_line(edge_a,edge_b,Color("1a1610"),2)
			if model.sieged(cell):
				# Rule A: the closed siege ring, dark red with a hatch.
				draw_rect(Rect2(pos+Vector2(2,2),Vector2(60,60)),Color(0.35,0.02,0.05,0.55))
				for k in range(3):
					draw_line(pos+Vector2(4+k*20,60),pos+Vector2(20+k*20,4),Color(0.9,0.2,0.2,0.35),2)
			elif model.siege_warning(cell):
				# The ring that closes at the start of this enemy turn.
				var blink := 0.45 + 0.35 * sin(clock * 6.0)
				draw_rect(Rect2(pos+Vector2(3,3),Vector2(58,58)),Color(1,0.25,0.2,blink),false,2)
			if model.floor_cells.has(cell):
				# Reel 4: a red-and-black checker marks the execution floor.
				for q in range(4):
					var sub := Rect2(pos+Vector2(4+(q%2)*28,4+(q/2)*28),Vector2(28,28))
					draw_rect(sub,Color(0.85,0.1,0.1,0.55) if (q%2)==(q/2) else Color(0.05,0.02,0.02,0.6))
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),Color("ff3b3b"),false,2)
			if danger.has(cell):
				# Aimed archer: the lane its arrow will fly down next turn.
				draw_rect(Rect2(pos+Vector2(2,2),Vector2(60,60)),Color(1,0.25,0.2,0.28))
				for k in range(3):
					draw_line(pos+Vector2(6+k*20,58),pos+Vector2(20+k*20,6),Color(1,0.35,0.3,0.45),3)
			if legal.has(cell):
				var color := GOLD if model.enemy_at(cell).is_empty() and model.cannon_at(cell).is_empty() else Color("ff805a")
				if not selected_item.is_empty(): color = model.item_definition(selected_item).color
				if selected_item == "gravity_fairy":
					# Pull inside the weapon's range (cyan), push outside it (orange).
					color = GRAVITY_PULL if model.gravity_pulls(cell) else GRAVITY_PUSH
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
				SpiritIcon.paint(self,mid,model.item_definition("stealth_fairy").icon,1.1)
				_turn_badge(pos,int(model.fairy_turns.get(cell,0)))
				if model.is_plus("stealth_fairy"):
					SpiritIcon.paint_plus(self,pos+Vector2(62,2),14)
			if model.shadow.get("cell",Vector2i(-1,-1)) == cell:
				# The pinned shadow; a red ring pulses while a swap is available.
				if model.shadow.ready:
					draw_arc(mid,27,0,TAU,28,Color(model.item_definition("shadow_stitch").color,0.55+0.3*sin(clock*5.0)),3,true)
				SpiritIcon.paint(self,mid,model.item_definition("shadow_stitch").icon if model.shadow.ready else SHADOW_SPENT,1.1)
				_turn_badge(pos,int(model.shadow.turns))
				if model.is_plus("shadow_stitch"):
					SpiritIcon.paint_plus(self,pos+Vector2(62,2),14)
			if model.walls.has(cell):
				# The wall fills its whole tile; the countdown sits in a corner badge.
				SpiritIcon.paint(self,mid,model.item_definition("wall_fairy").icon,1.12)
				_turn_badge(pos,int(model.walls[cell]))
				if model.is_plus("wall_fairy"):
					SpiritIcon.paint_plus(self,pos+Vector2(62,2),14)
			var cannon: Dictionary = model.cannon_at(cell)
			if not cannon.is_empty():
				var cannon_id: String = {"lance":"cannon_fairy","vane":"vane_cannon","firework":"firework_fairy","capacitor":"capacitor_fairy"}[cannon.kind]
				# Directional art shows the facing itself; the plain icon gets an arrow.
				if cannon.kind == "capacitor":
					# Crackling art once any charge is stored.
					SpiritIcon.paint(self,mid,CAPACITOR_CHARGED if int(cannon.get("charge",0)) > 0 else model.item_definition(cannon_id).icon,0.95)
				elif not DirectionSheet.paint(self,mid,cannon_id,cannon.dir,0.95):
					SpiritIcon.paint(self,mid,model.item_definition(cannon_id).icon,0.95)
					if cannon.dir != Vector2i.ZERO:
						_draw_arrow(mid+Vector2(cannon.dir)*18,Vector2(cannon.dir),model.item_definition(cannon_id).color)
				if cannon.kind == "vane":
					_draw_turn_hint(mid,cannon.dir)
				_turn_badge(pos,int(cannon.get("turns",0)))
				if cannon.kind == "capacitor":
					# Stored charge: three pips across the top, lit as it fills.
					for k in range(Rules.CAPACITOR_FULL):
						var pip := Rect2(pos+Vector2(4+k*14,4),Vector2(12,8))
						draw_rect(pip,Color(0.03,0.06,0.07,0.9))
						if k < int(cannon.get("charge",0)):
							draw_rect(pip.grow(-2),Color("ffdc4a"))
				if cannon.get("plus",false):
					SpiritIcon.paint_plus(self,pos+Vector2(62,2),14)
			var ally := model.ally_at(cell)
			if ally.get("plus",false):
				SpiritIcon.paint_plus(self,pos+Vector2(62,2),14)
			if cell == item_origin and Rules.BIG_FAIRIES.has(selected_item):
				pass
			elif cell == item_origin and not DirectionSheet.paint(self,mid,selected_item,aim,1.1):
				SpiritIcon.paint(self,mid,model.item_definition(selected_item).icon,1.1)
	draw_set_transform(Vector2.ZERO)
	# Rubble where a fortress fell.
	for anchor in model.ruins:
		draw_texture_rect(FORTRESS_RUIN,Rect2(BOARD+Vector2(anchor)*TILE+Vector2(0,TILE*0.35),Vector2(TILE*2,TILE*2)*0.82),false)
	# Gravity fairy: arrows show where each enemy would be pulled or blown.
	if selected_item == "gravity_fairy" and model.item_targets("gravity_fairy").has(hover_cell):
		if hover_cell != gravity_hover:
			gravity_hover = hover_cell
			gravity_moves.clear()
			var sim: RefCounted = model.clone()
			sim.gravity(hover_cell)
			for enemy in model.enemies:
				var after: Dictionary = {}
				for other in sim.enemies:
					if other.id == enemy.id:
						after = other
				if after.is_empty():
					gravity_moves.append([enemy, null])
				elif after.cell != enemy.cell:
					gravity_moves.append([enemy, after.cell])
		var tint := GRAVITY_PULL if model.gravity_pulls(hover_cell) else GRAVITY_PUSH
		for move in gravity_moves:
			var from := _unit_center(move[0])
			if move[1] == null:
				draw_arc(from,20,0,TAU,20,Color("b8a8ff"),3,true)
				continue
			var to := _unit_center({"cell":move[1], "size":int(move[0].get("size",1))})
			draw_line(from,to,tint,4)
			_draw_arrow(to,(to-from).normalized(),tint)
	else:
		gravity_hover = Vector2i(-9, -9)
	# Before a 2x2 fairy is placed, hovering a legal tile shows the block it would take.
	# 2x2 fairies are drawn after the tiles so no later tile covers them.
	if Rules.BIG_FAIRIES.has(selected_item):
		if item_origin != Vector2i(-1,-1):
			_draw_big_ghost(item_origin,aim)
		elif model.item_targets(selected_item).has(hover_cell):
			_draw_big_ghost(hover_cell,Vector2i.RIGHT)
	if item_origin != Vector2i(-1,-1):
		if selected_item == "vane_cannon":
			_draw_turn_hint(_center(item_origin),aim)
		var start := _center(item_origin)
		var end := start+Vector2(aim)*28
		draw_line(start,end,GOLD,5)
		var side := Vector2(-aim.y,aim.x)*8
		draw_colored_polygon(PackedVector2Array([end+Vector2(aim)*8,end-Vector2(aim)*7+side,end-Vector2(aim)*7-side]),GOLD)

## Curved clockwise arrow from the vane's current aim to the aim it takes after firing.
func _draw_turn_hint(center: Vector2, dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	var from := Vector2(dir).angle()+0.45
	var to := from+PI/2-0.75
	var radius := 27.0
	var color := Color("9ff5ff")
	draw_arc(center,radius,from,to,12,Color(0,0,0,0.7),6)
	draw_arc(center,radius,from,to,12,color,3)
	var tip := center+Vector2.from_angle(to)*radius
	var tangent := Vector2.from_angle(to+PI/2)
	var side := Vector2(-tangent.y,tangent.x)*6
	var head := PackedVector2Array([tip+tangent*8,tip-tangent*3+side,tip-tangent*3-side])
	draw_colored_polygon(head,Color(0,0,0,0.7))
	draw_colored_polygon(PackedVector2Array([tip+tangent*6,tip-tangent*2+side*0.7,tip-tangent*2-side*0.7]),color)
	# A small ghost arrow shows where the next shot will point.
	var next := Vector2(CLOCKWISE_NEXT[dir])
	draw_circle(center+next*24,5,Color(0,0,0,0.6))
	draw_circle(center+next*24,3,color)

## Turns left for a placed spirit, in the tile's bottom-right corner.
func _turn_badge(pos: Vector2, turns: int) -> void:
	if turns <= 0:
		return
	draw_rect(Rect2(pos+Vector2(44,42),Vector2(18,20)),Color(0.03,0.06,0.07,0.85))
	_text(pos+Vector2(47,59),str(turns),20,INK)

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

func _draw_weapons() -> void:
	# The 7x7 boss board reaches down to this line, so the header gives way to it.
	if model.board_size < 7:
		_text(Vector2(352,605),"武器  %d / 3" % model.owned_weapons.size(),23,INK)
		_text(Vector2(555,605),"タップか1〜3キーで装備・0 AP",18,MUTED)
	for slot in range(model.owned_weapons.size()):
		var index: int = model.owned_weapons[slot]
		var weapon: Dictionary = Rules.WEAPONS[index]
		var pos := Vector2(352+slot*260,620)
		var rect := Rect2(pos,Vector2(248,94))
		var accent := Color(weapon.color)
		var equipped: bool = model.weapon == index
		draw_rect(rect,Color("1b3431") if equipped else Color("0b1415"))
		draw_rect(rect,accent if equipped else Color("324843"),false,4 if equipped else 2)
		_text(pos+Vector2(10,22),str(slot+1),15,MUTED)
		var label: String = ("▶ " if equipped else "")+weapon.name
		_text(pos+Vector2(28,38),label,22,accent)
		var forged: bool = model.weapon_power.has(index)
		if forged:
			_text(pos+Vector2(30+_text_width(label,22),38),"+",22,GOLD)
		var circle: bool = model.is_circle(index)
		var extras: Array[String] = []
		# Swap weapons trade places instead of dealing damage.
		extras.assign(["魔法陣","攻撃不可"] if circle else ["無傷で入替"] if weapon.get("swap",false) else ["攻撃%d" % model.weapon_damage(index)])
		if weapon.get("knockback",0) > 0:
			extras.append("押出")
		if weapon.has("slide"):
			extras.append("滑る")
		if weapon.get("pull",false):
			extras.append("引寄")

		if weapon.has("charge"):
			extras.append("溜め%d/%d" % [model.blade_charge, Rules.BLADE_MAX])
		if extras.size() == 1 and not weapon.has("slide") and (Catalog.is_jump(index) or weapon.offsets.any(func(o: Vector2i) -> bool: return maxi(absi(o.x),absi(o.y)) >= 2)):
			extras.append("跳ぶ")
		_text(pos+Vector2(28,72),"・".join(extras),16,Color("f4f2ea") if circle else GOLD if model.weapon_damage(index) > 1 else MUTED)
		if circle:
			# A white inner frame marks the enchantment.
			draw_rect(rect.grow(-3),Color(CIRCLE_WHITE,0.6),false,1)
		# Same picture as the reward cards: outlined tiles with a dot on each reachable one.
		var offsets := model.weapon_offsets(index)
		var count := RangeDiagram.span(offsets)
		var side := 84.0
		var cell_size := side/count
		var origin := pos+Vector2(248-side-6,5)
		for y in range(count):
			for x in range(count):
				var offset := Vector2i(x-count/2,y-count/2)
				var tile := Rect2(origin+Vector2(x,y)*cell_size+Vector2.ONE,Vector2.ONE*(cell_size-2))
				var active := offsets.has(offset)
				draw_rect(tile,Color(accent,0.3) if active else Color("172627"))
				draw_rect(tile,accent if active else Color("3d5753"),false,1)
				if offset == Vector2i.ZERO:
					_draw_player_portrait(index,tile.get_center(),cell_size*1.1,1)
				elif active:
					draw_circle(tile.get_center(),maxf(2,cell_size*0.16),accent)
		# Sliding weapons: arrows past the outer tiles.
		for direction in Catalog.slides(index):
			var far := origin+(Vector2(direction*(count/2)+Vector2i(count/2,count/2))+Vector2.ONE*0.5)*cell_size
			var tip: Vector2 = far+Vector2(direction).normalized()*cell_size*0.75
			draw_line(far,tip,accent,2)
			draw_circle(tip,2.5,accent)
		if forged:
			SpiritIcon.paint_plus(self,origin+Vector2(side+4,-3),18)
		if model.locked_slot >= 0:
			if slot == model.locked_slot:
				draw_rect(rect,Color("ffd35b"),false,4)
				_text(pos+Vector2(118,32),"判決",18,Color("ffd35b"))
			else:
				draw_rect(rect,Color(0,0,0,0.62))
				_text(pos+Vector2(70,56),"封印",26,Color("ff5b62"))

## A 2x2 fairy about to be placed: its sprite over the block it would take.
func _draw_big_ghost(cell: Vector2i, direction: Vector2i) -> void:
	var anchor: Vector2i = model.big_anchor(cell)
	if anchor == Vector2i(-1, -1):
		return
	var center := _center(anchor) + Vector2.ONE * TILE / 2
	var accent: Color = model.item_definition(selected_item).color
	_dashed_rect(Rect2(center - Vector2.ONE * (TILE - 4), Vector2.ONE * (TILE * 2 - 8)), accent, 3)
	if selected_item == "axe_spirit":
		var frame: int = Rules.CARDINALS.find(direction)
		draw_texture_rect_region(AXE_DASH, Rect2(center - Vector2.ONE * 62, Vector2.ONE * 124), Rect2(maxi(frame, 0) * 224, 0, 224, 224), Color(1, 1, 1, 0.85))
	else:
		draw_texture_rect(UnitView.HOLY_SPIRIT, Rect2(center - Vector2(62, 68), Vector2.ONE * 124), false, Color(1, 1, 1, 0.7))

func _dashed_rect(rect: Rect2, color: Color, width: float) -> void:
	var corners := [rect.position, rect.position+Vector2(rect.size.x,0), rect.end, rect.position+Vector2(0,rect.size.y)]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k+1)%4]
		var length := a.distance_to(b)
		var t := 0.0
		while t < length:
			draw_line(a.lerp(b,t/length),a.lerp(b,minf(t+7,length)/length),color,width)
			t += 12

func _draw_intel() -> void:
	_panel(Rect2(832,94,296,508))
	if show_history:
		_text(Vector2(852,133),"戦闘履歴",26,CYAN)
		return
	if not selected_item.is_empty():
		var item: Resource = model.item_definition(selected_item)
		_text(Vector2(852,133),item.title,26,item.color)
		if model.is_plus(selected_item):
			_text(Vector2(854+_text_width(item.title,26),133),"+",26,GOLD)
			SpiritIcon.paint_plus(self,Vector2(954,138),22)
		SpiritIcon.paint(self,Vector2(912,180),item.icon,1.35)
		_text(Vector2(992,187),"%d AP" % model.fairy_ap_cost(selected_item),24,GOLD)
		ItemPreview.paint(self,model,selected_item,clock)
		var lines: PackedStringArray = model.fairy_description(selected_item).split("\n")
		for i in range(lines.size()):
			_text(Vector2(850,335+i*25),lines[i],18,INK)
		_text(Vector2(852,440 if item_origin != Vector2i(-1,-1) else 487),"向きを選択" if item_origin != Vector2i(-1,-1) else "移動先を選択" if selected_item == "warp_fairy" else "自分のマスを押す" if selected_item == "abyss_spirit" else "配置先を選択",23,item.color)
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
		_wrapped(Vector2(852,528),Rules.WEAPONS[selected_weapon].detail,18,MUTED,14)
	else:
		_text(Vector2(852,133),"敵の情報",26,CYAN)
		_text(Vector2(852,295),"敵にカーソルを",23,INK)
		_text(Vector2(852,330),"合わせて確認",23,INK)
		_text(Vector2(852,540),"右クリックで固定",20,MUTED)

func _draw_player_portrait(weapon_index: int, center: Vector2, side: float, facing_index: int = 2) -> void:
	var cell := UnitView.PLAYER_ATLAS_CELL
	var row: int = Rules.WEAPONS[weapon_index].row
	draw_texture_rect_region(UnitView.PLAYER_ATLAS,Rect2(center-Vector2.ONE*side/2,Vector2.ONE*side),Rect2(facing_index*cell,row*cell,cell,cell))

func _draw_range(offsets: Array, accent: Color, enemy: Dictionary = {}, weapon_index: int = -1, _forward_index: int = 0, portrait_index: int = 2, compact: bool = false, attack: Array = []) -> void:
	var count := 3
	var step := 52 if compact else 64
	# Cavalry and two-tile weapons need a larger preview for their jumps.
	var self_cell: Vector2i = Vector2i(1,1)
	if enemy.get("type","") in Rules.JUMPERS or RangeDiagram.span(offsets) == 5 or RangeDiagram.span(attack) == 5:
		count = 5
		step = 38
		self_cell = Vector2i(2,2)
	var origin := Vector2(980-count*step/2.0,192 if compact else 236)
	for y in range(count):
		for x in range(count):
			var offset := Vector2i(x,y)-self_cell
			var rect := Rect2(origin+Vector2(x,y)*step,Vector2.ONE*(step-5))
			var active: bool = offsets.has(offset)
			var hits: bool = attack.has(offset)
			var tone: Color = Color("ff805a") if hits else accent
			draw_rect(rect,Color(tone,0.3) if active or hits else Color("192828"))
			draw_rect(rect,tone if active or hits else Color("46625e"),false,2)
			if offset == Vector2i.ZERO:
				if not enemy.is_empty():
					_draw_enemy_portrait(enemy,rect.get_center(),0.85)
				else:
					_draw_player_portrait(weapon_index,rect.get_center(),step,portrait_index)
			elif hits:
				draw_line(rect.get_center()-Vector2(6,6),rect.get_center()+Vector2(6,6),tone,3)
				draw_line(rect.get_center()-Vector2(6,-6),rect.get_center()+Vector2(6,-6),tone,3)
			elif active:
				draw_circle(rect.get_center(),6,accent)

func _draw_enemy_portrait(enemy: Dictionary, center: Vector2, factor: float = 1.0) -> void:
	var actor = actors.get(int(enemy.id))
	if actor == null:
		return
	draw_set_transform(center,0,Vector2.ONE*factor)
	if enemy.type == "miner":
		actor._draw_drone(Color.WHITE,self)
	elif enemy.type in Rules.JUMPERS:
		actor._draw_cavalry(Color.WHITE,self)
	elif UnitView.SOLDIER_SHEETS.has(enemy.type):
		UnitView.draw_soldier(self,enemy.type,int(enemy.get("facing",3)),enemy.get("state","") == "aim" or int(enemy.get("learned",-1)) >= 0,Color.WHITE,0.9)
	elif enemy.type in Rules.GENERALS:
		UnitView.draw_general(self,enemy.type)
	elif enemy.type == "king":
		draw_texture_rect_region(UnitView.KING_SHEETS["idle"][0],Rect2(-32,-34,64,64),Rect2(0,0,256,256))
	elif enemy.type == "fortress":
		draw_texture_rect_region(UnitView.FORTRESS_SHEETS["idle"][0],Rect2(-30,-32,60,60),Rect2(0,0,256,256))
	elif enemy.type in UnitView.BOSS_KINDS:
		UnitView.draw_boss(self,enemy.type,int(enemy.get("facing",3)),enemy.get("state","") == "brace",Color.WHITE,0.45 if enemy.get("size",1) > 1 else 0.9,int(enemy.get("reel",0)))
	else:
		draw_texture_rect_region(UnitView.ENEMY_ATLAS,Rect2(-28,-28,56,56),Rect2(56,0,28,28))
		if enemy.type == "heavy":
			draw_rect(Rect2(-22,0,18,26),Color("78968f"))
			draw_rect(Rect2(-18,4,10,18),Color("293d42"))
	draw_set_transform(Vector2.ZERO)

const ROOK_RANGE = [Vector2i(0,-1),Vector2i(0,-2),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(0,2),Vector2i(-1,0),Vector2i(-2,0)]
## Rotorick's line (short, polite) and the plain rule, per reel.
const REEL_LINES = {
	0: ["抽選中です。", "抽選中"],
	1: ["判決、一。第一の武器のみ許可します。", "武器は1枠目だけ"],
	2: ["判決、二。第二の武器のみ許可します。", "武器は2枠目だけ"],
	3: ["判決、三。第三の武器のみ許可します。", "武器は3枠目だけ"],
	4: ["判決、四。床を焼きます。", "赤黒マスに次の敵ターンで1ダメージ"],
	5: ["ERROR 05 ─ 停止中", "次の敵ターンは突進しない"],
	6: ["判決、六。残像を置いていきます。", "残像の隣に入ると1ダメージ"],
	7: ["刑を執行します。", "AP+1・2回突進・1回目は必中"],
}

## Draws text wrapped every `per_line` characters; returns the y after the last line.
func _wrapped(at: Vector2, text: String, size: int, color: Color, per_line: int) -> float:
	var y := at.y
	var line := ""
	for character in text:
		line += character
		if line.length() >= per_line:
			_text(Vector2(at.x,y),line,size,color)
			y += size+6
			line = ""
	if not line.is_empty():
		_text(Vector2(at.x,y),line,size,color)
		y += size+6
	return y

func _draw_rotorick_inspector(enemy: Dictionary) -> void:
	var reel: int = int(enemy.get("reel",0))
	var lines: Array = REEL_LINES[reel]
	_text(Vector2(852,214),"移動：飛車（向きの先まで突進）",16,CYAN)
	var line_color := Color("ffd35b") if reel == 5 else Color("f1e9d8")
	var y := _wrapped(Vector2(852,250),lines[0] if reel == 5 else "「%s」" % lines[0],18,line_color,15)
	if reel == 7:
		y = _wrapped(Vector2(852,y+2),"逃げ場は無い。",28,Color("ff3b3b"),9)
	_draw_reel_diagram(reel, Rect2(852,y+8,256,108))
	_wrapped(Vector2(852,y+140),lines[1],19,Color("ff5b62") if reel == 7 else Color("ffd35b"),14)

## Small picture of what the reel does, drawn from simple tiles.
func _draw_reel_diagram(reel: int, box: Rect2) -> void:
	draw_rect(box,Color("0b1415"))
	draw_rect(box,Color("324843"),false,2)
	var c := box.get_center()
	var red := Color("ff3b3b")
	var gold := Color("ffd35b")
	var cell := 22.0
	var tile := func(at: Vector2, color: Color, filled: bool = true) -> void:
		draw_rect(Rect2(at-Vector2.ONE*(cell/2-1),Vector2.ONE*(cell-2)),color,filled,-1.0 if filled else 2.0)
	var boss := func(at: Vector2, color: Color) -> void:
		draw_rect(Rect2(at-Vector2.ONE*cell,Vector2.ONE*cell*2),color)
		draw_rect(Rect2(at-Vector2.ONE*cell,Vector2.ONE*cell*2),Color("f1e9d8"),false,2)
	match reel:
		1, 2, 3:
			# Three weapon slots: the drawn one lit, the others sealed.
			for i in 3:
				var at := c+Vector2((i-1)*72,0)
				var active := i == reel-1
				draw_rect(Rect2(at-Vector2(30,34),Vector2(60,68)),Color("152d2a") if active else Color("1a1f20"))
				draw_rect(Rect2(at-Vector2(30,34),Vector2(60,68)),gold if active else Color("4d5443"),false,3 if active else 2)
				_text(at+Vector2(-7,10),str(i+1),26,gold if active else Color("5d6a66"))
				if not active:
					draw_line(at-Vector2(22,26),at+Vector2(22,26),red,4)
					draw_line(at+Vector2(-22,26),at+Vector2(22,-26),red,4)
		4:
			# A checker of burning tiles.
			for y in 4:
				for x in 8:
					var at := box.position+Vector2(22+x*30,15+y*26)
					if (x+y)%2 == 0:
						draw_rect(Rect2(at-Vector2(13,11),Vector2(26,22)),Color(0.85,0.1,0.1,0.8))
					else:
						draw_rect(Rect2(at-Vector2(13,11),Vector2(26,22)),Color(0.1,0.05,0.05))
		5:
			boss.call(c,Color("2a3a44"))
			draw_line(c-Vector2(14,14),c+Vector2(14,14),gold,5)
			draw_line(c+Vector2(-14,14),c+Vector2(14,-14),gold,5)
			_text(c+Vector2(34,8),"停止",20,gold)
		6:
			# Afterimage stays; Rotorick charges off; stepping next to it hurts.
			boss.call(c+Vector2(-60,0),Color(0.6,0.35,0.9,0.5))
			boss.call(c+Vector2(66,0),Color("2a3a44"))
			draw_line(c+Vector2(-30,0),c+Vector2(36,0),red,4)
			draw_colored_polygon(PackedVector2Array([c+Vector2(40,0),c+Vector2(28,-8),c+Vector2(28,8)]),red)
			# A player standing next to the afterimage gets cut.
			var victim := c+Vector2(-60-cell*1.5-8,0)
			tile.call(victim,Color("2bdcc8"),false)
			draw_circle(victim,6,Color("2bdcc8"))
			draw_line(victim+Vector2(-12,-12),victim+Vector2(12,12),red,3)
		7:
			# Two charges; the first always lands.
			boss.call(c+Vector2(-70,0),Color("3a2a18"))
			for k in 2:
				var y0 := c.y-12+k*24
				draw_line(Vector2(c.x-40,y0),Vector2(c.x+60,y0),red,4)
				draw_colored_polygon(PackedVector2Array([Vector2(c.x+68,y0),Vector2(c.x+56,y0-8),Vector2(c.x+56,y0+8)]),red)
			_text(c+Vector2(-30,-24),"×2",18,gold)
			draw_arc(c+Vector2(92,0),16,0,TAU,20,red,3)
			draw_line(c+Vector2(76,0),c+Vector2(108,0),red,2)
			draw_line(c+Vector2(92,-16),c+Vector2(92,16),red,2)
		_:
			_text(c+Vector2(-10,12),"?",34,gold)

## Two-by-two enemies: a 4x4 diagram, the body filling the middle 2x2 and the
## eight tiles around it marked (moves for the prison, cuts for the afterimage).
func _draw_big_range(enemy: Dictionary) -> void:
	var shadow: bool = enemy.type == "shadow"
	_text(Vector2(852,217),"攻撃範囲" if shadow else "移動・攻撃範囲",21,INK)
	var step := 46.0
	var origin := Vector2(980-step*2,236)
	var tone := Color("ff805a") if shadow else CYAN
	for y in range(4):
		for x in range(4):
			var rect := Rect2(origin+Vector2(x,y)*step,Vector2.ONE*(step-5))
			var inner: bool = x in [1,2] and y in [1,2]
			var edge: bool = not inner and (x in [1,2] or y in [1,2])
			draw_rect(rect,Color(tone,0.3) if edge else Color("192828"))
			draw_rect(rect,tone if edge else Color("46625e"),false,2)
			if edge:
				if shadow:
					draw_line(rect.get_center()-Vector2(6,6),rect.get_center()+Vector2(6,6),tone,3)
					draw_line(rect.get_center()-Vector2(6,-6),rect.get_center()+Vector2(6,-6),tone,3)
				else:
					draw_circle(rect.get_center(),6,tone)
	_draw_enemy_portrait(enemy,origin+Vector2.ONE*step*2-Vector2.ONE*2.5,0.9)
	if shadow:
		# Same wording as the stealth fairy, from the enemy's side.
		var y := _wrapped(Vector2(852,436),"ロトリックの残像。隠密中は通行をふさぐ。",17,INK,15)
		_wrapped(Vector2(852,y),"縦横に隣接したプレイヤーに1ダメージを与えて消える。",17,tone,15)
	else:
		_text(Vector2(852,450),"2×2で縦横に1マスずつ動く",18,tone)
		_text(Vector2(852,489),"壊すと執行兵2体",23,CYAN)
	_text(Vector2(852,574),"固定中・右クリックで解除" if selected_enemy_id==int(enemy.id) else "右クリックで固定",18,MUTED)

func _draw_enemy_inspector(enemy: Dictionary) -> void:
	var type: Dictionary = Rules.TYPES[enemy.type]
	_text(Vector2(852,133),type.name,28,INK)
	_text(Vector2(852,175),"HP",20)
	# Big HP pools (Rotorick's 7) use smaller hearts so AP still fits on the line.
	var hearts: int = maxi(int(type.hp), int(enemy.hp))
	var many: bool = hearts > 3
	var huge: bool = hearts > 7
	for i in range(hearts):
		_draw_heart(Vector2(909+i*(12 if huge else 16 if many else 30),167),11 if huge else 14 if many else 25,Color("ff5b62"),i<int(enemy.hp))
	# Three hearts reach further right, so AP moves over for them.
	var ap_x := 1040.0 if huge else 1030.0 if many else 1004.0 if hearts >= 3 else 984.0
	_text(Vector2(ap_x,175),"AP",20,GOLD)
	var ap_boxes: int = int(type.ap) + (1 if enemy.type == "slot" and int(enemy.get("reel",0)) == 7 else 0)
	for i in range(ap_boxes):
		draw_rect(Rect2(ap_x+45+i*26,153,22,23),Color("ff5b62") if i >= int(type.ap) else GOLD)
	if enemy.type == "slot":
		_draw_rotorick_inspector(enemy)
		return
	if enemy.type == "rook":
		_text(Vector2(852,217),"移動・攻撃範囲：飛車",21,INK)
		_draw_range(ROOK_RANGE,CYAN,enemy)
		_text(Vector2(852,450),"向きの先へ端まで突進",18,Color("ff805a"))
		var rook_intent := "赤：構えた向きへ突進" if enemy.get("state","") == "brace" else "すぐに構える"
		_text(Vector2(852,489),rook_intent,23,GOLD)
		_text(Vector2(852,574),"固定中・右クリックで解除" if selected_enemy_id==int(enemy.id) else "右クリックで固定",18,MUTED)
		return
	if enemy.type in ["prison", "shadow"]:
		_draw_big_range(enemy)
		return
	_text(Vector2(852,217),"移動・攻撃範囲",21,INK)
	_draw_range(model.enemy_offsets(enemy),CYAN,enemy,-1,0,2,false,model.enemy_attack_offsets(enemy))
	if enemy.type == "shield":
		# The shield sits on the left side of the soldier.
		var middle := Vector2(980-96+64,236+64)
		draw_rect(Rect2(middle+Vector2(-4,6),Vector2(9,47)),Color("101a1e"))
		draw_rect(Rect2(middle+Vector2(-2,8),Vector2(5,43)),Color("2bdcc8"))
	if enemy.type == "archer":
		_text(Vector2(852,450),"赤＝左へ一直線に射る",18,Color("ff805a"))
	elif enemy.type == "javelin":
		_text(Vector2(852,450),"赤＝投げ槍の着弾マス",18,Color("ff805a"))
	elif enemy.type == "shield":
		_text(Vector2(852,450),"真左からの攻撃は盾で防ぐ",18,Color("a9c4d2"))
	elif enemy.type == "king":
		if enemy.hp <= Rules.KING_RAGE_HP:
			_text(Vector2(852,520),"怒り：要塞が兵を2体ずつ出す",19,Color("ff6b6b"))
		var next := model.next_revival()
		_text(Vector2(852,450),"次に蘇る：%s（死んだ順）" % Rules.TYPES[next].name if next != "" else "攻撃も移動もしない",18,Color("ff6b8a"))
	elif enemy.type == "fortress":
		_text(Vector2(852,450),"毎ターン兵を%d体出す。壊すと2体" % (2 if model.king_enraged() else 1),18,Color("ff6b6b") if model.king_enraged() else Color("9ab8c8"))
	elif enemy.type == "gold":
		_text(Vector2(852,450),"左が前。右斜め後ろには動けない",18,Color("ffd35b"))
	elif enemy.type == "silver":
		_text(Vector2(852,450),"左が前。上下と真右には動けない",18,Color("d8e2ee"))
	elif enemy.type == "analyst":
		var learned := int(enemy.get("learned",-1))
		_text(Vector2(852,450),"解析済み：%s（効かない）" % Rules.WEAPONS[learned].name if learned >= 0 else "殴った武器を覚えて無効化",18,Color("7fffd0"))
	var intent := "死者を蘇らせる" if enemy.type == "king" else "兵を送り出す" if enemy.type == "fortress" else "金の動きで迫る" if enemy.type == "gold" else "銀の動きで迫る" if enemy.type == "silver" else "盾を構えて前進" if enemy.type == "shield" else "解析しながら前進" if enemy.type == "analyst" else "まっすぐ迫って攻撃" if enemy.type == "executioner" else "弓を構えている !" if enemy.get("state","") == "aim" else "照準合わせ" if enemy.type == "archer" else "接近して投擲" if enemy.type == "javelin" else "前線へ前進" if enemy.type == "heavy" else "移動 → 地雷設置" if enemy.type == "miner" else "跳躍接近" if enemy.type in Rules.JUMPERS else "突撃準備 !" if enemy.state == "charge" else "包囲中" if enemy.state == "encircle" else "囲んでから突撃"
	_text(Vector2(852,479),intent,25,GOLD if enemy.state in ["charge","aim","brace"] else CYAN)
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
const FX_LIFE = {"bolt":0.42, "warp":0.42, "summon":0.5, "ambush":0.42, "shot":0.45, "muzzle":0.35, "slash":0.45, "blast":0.8, "firework":0.95, "javelin":0.4, "arrow":0.4, "quake":0.6, "dash":0.4, "roar":0.7, "burn":0.6, "zap":0.45, "spark":0.35, "resonate":0.5, "push":0.35, "bump":0.45, "discharge":0.5, "block":0.45, "analyzed":0.6, "smash":0.5, "axe":0.7, "chalk":0.5, "circle":0.1, "pull":0.45, "swap":0.5, "bite":0.45, "combo":1.0, "fall":0.6, "gravity":0.6, "devour":0.85, "gulp":0.75, "windup":0.7}
const FIREWORK_COLORS = [Color("ff5b8a"), Color("ffd35b"), Color("6bdcff"), Color("b58cff"), Color("8dffb0")]

func _draw_fx(effect: Dictionary, pos: Vector2, fade: float) -> void:
	var t := 1.0 - fade
	var dir := Vector2(effect.get("dir", Vector2i.ZERO))
	match effect.kind:
		"zap":
			# The provided lightning tile, stretched across the tile and flickering.
			var vertical: bool = dir.x == 0
			var tex: Texture2D = ZAP_V if vertical else ZAP_H
			var flicker := 0.75 + 0.25 * sin(clock * 60.0)
			var rect := Rect2(pos - Vector2(12, 32), Vector2(24, 64)) if vertical else Rect2(pos - Vector2(32, 12), Vector2(64, 24))
			draw_texture_rect(tex, rect, false, Color(1, 1, 1, fade * flicker))
		"discharge":
			var side := 150.0 + t * 40.0
			draw_texture_rect(CAPACITOR_DISCHARGE, Rect2(pos - Vector2.ONE * side / 2, Vector2.ONE * side), false, Color(1, 1, 1, fade))
		"resonate":
			# Rings rippling out from a cannon the shot passed through.
			draw_arc(pos, 14 + t * 22, 0, TAU, 24, Color("9ff5ff", fade), 3, true)
			draw_arc(pos, 6 + t * 12, 0, TAU, 24, Color("ffffff", fade * 0.7), 2, true)
		"push":
			# Skid marks trailing behind a shoved enemy.
			for k in range(3):
				draw_line(pos - dir * (14 + k * 8) + Vector2(-dir.y, dir.x) * (k - 1) * 8, pos - dir * (24 + k * 8) + Vector2(-dir.y, dir.x) * (k - 1) * 8, Color("e5dfc5", fade * 0.7), 3)
		"bump":
			# Impact star where the enemy slams into something.
			var at := pos + dir * 26
			for k in range(6):
				var ray := Vector2.from_angle(k * TAU / 6) * (6 + t * 14)
				draw_line(at, at + ray, Color("ffd35b", fade), 3)
		"smash":
			# Debris flying out of a smashed tile.
			for k in range(7):
				var chunk := Vector2.from_angle(k * TAU / 7 + 0.3) * (6 + t * 26)
				draw_rect(Rect2(pos + chunk - Vector2(3, 3), Vector2(6, 6)), Color("c9b79a", fade))
			draw_arc(pos, 8 + t * 18, 0, TAU, 16, Color("ffd35b", fade * 0.8), 3, true)
		"pull":
			# The sickle's chain snapping the enemy in.
			var from := _center(effect.from)
			var at := from.lerp(pos, clampf(t * 2.0, 0.0, 1.0))
			for k in range(6):
				var link := at.lerp(pos - (pos - from).normalized() * 30, k / 5.0)
				draw_arc(link, 4, 0, TAU, 8, Color("b8c4d0", fade), 2, true)
			draw_line(at - Vector2(8, 8), at + Vector2(8, 8), Color("e8eef0", fade), 3)
		"swap":
			# Two violet arcs trading places.
			var from := _center(effect.from)
			var mid := (from + pos) / 2 + Vector2(0, -30)
			draw_polyline(PackedVector2Array([from, mid, pos]), Color("c89bff", fade), 3, true)
			draw_polyline(PackedVector2Array([pos, (from + pos) / 2 + Vector2(0, 30), from]), Color("e0c8ff", fade * 0.8), 3, true)
			draw_circle(pos, 6 + t * 16, Color("c89bff", fade * 0.4))
			draw_circle(from, 6 + t * 16, Color("c89bff", fade * 0.4))
		"chalk":
			# A tile turning white: a bright ring and a few rising sparkles.
			draw_arc(pos, 8 + t * 22, 0, TAU, 24, Color(1, 1, 1, fade), 3, true)
			for k in range(4):
				draw_circle(pos + Vector2(-15 + k * 10, 12 - t * 28 - (k % 2) * 6), 2.5, Color(GOLD, fade))
		"circle":
			pass
		"axe":
			# The wind axe sweeps from where it appeared to where it stops, then fades.
			var half := Vector2.ONE * TILE / 2
			var from := pos + half
			var to := _center(effect.to) + half
			var at := from.lerp(to, ease(minf(t * 1.6, 1.0), 0.6))
			var alpha := 1.0 if t < 0.7 else fade / 0.3
			for k in range(4):
				var lane := Vector2(-dir.y, dir.x) * (k - 1.5) * 22
				draw_line(at + lane - dir * 50, at + lane - dir * (90 + k * 10), Color("9fffc0", alpha * 0.55), 3)
			var frame: int = Rules.CARDINALS.find(Vector2i(dir))
			draw_texture_rect_region(AXE_DASH, Rect2(at - Vector2.ONE * 62, Vector2.ONE * 124), Rect2(maxi(frame, 0) * 224, 0, 224, 224), Color(1, 1, 1, alpha))
		"analyzed":
			# A scan ring and "解析済" floating up.
			draw_arc(pos, 18 + t * 10, 0, TAU, 24, Color("7fffd0", fade), 2, true)
			_text(pos + Vector2(-30, -30 - t * 12), "解析済", 18, Color("7fffd0", fade))
		"block":
			# Sparks off the shield on the left side.
			var hit_at := pos + Vector2(-24, -4)
			for k in range(5):
				var spark_ray := Vector2.from_angle(PI + (k - 2) * 0.45) * (6 + t * 16)
				draw_line(hit_at, hit_at + spark_ray, Color("e6f2ff", fade), 2)
			_text(pos + Vector2(-26, -30 - t * 10), "防", 18, Color("a9c4d2", fade))
		"spark":
			for k in range(6):
				var ray := Vector2.from_angle(k * TAU / 6 + t * 2) * (10 + t * 18)
				draw_line(pos + ray * 0.5, pos + ray, Color("ffe76a", fade), 2)
		"burn":
			draw_rect(Rect2(pos - Vector2.ONE * 28, Vector2.ONE * 56), Color(1, 0.25, 0.1, fade * 0.6))
			draw_arc(pos, 8 + t * 20, 0, TAU, 16, Color("ffb35b", fade), 3, true)
		"roar":
			# The boss's stance: a red shockwave from the middle of its footprint.
			var at := pos - Vector2.ONE * TILE / 2
			draw_arc(at, 20 + t * 70, 0, TAU, 32, Color(1, 0.3, 0.25, fade), 6, true)
			draw_arc(at, 10 + t * 45, 0, TAU, 32, Color(1, 0.75, 0.5, fade * 0.7), 3, true)
		"dash":
			# Dust kicked up behind the charging rook's two-tile footprint.
			var back := -dir
			for k in range(2):
				var lane := Vector2(absf(dir.y), absf(dir.x)) * TILE * k
				draw_circle(pos + lane + back * (10 + t * 16), 7 + t * 8, Color("c9b79a", fade * 0.5))
		"quake":
			# Shock rings and cracks across every tile the hammer shakes.
			for area_cell in effect.cells:
				var c := _center(area_cell)
				draw_arc(c,10+t*24,0,TAU,20,Color("ffd08a",fade),4)
				draw_line(c+Vector2(-14,-4),c+Vector2(0,4),Color("3a2412",fade),3)
				draw_line(c+Vector2(0,4),c+Vector2(12,-6),Color("3a2412",fade),3)
			draw_circle(pos,8+t*30,Color(1,0.8,0.5,fade*0.35))
		"javelin", "arrow":
			# The projectile flies from the thrower to where it lands.
			var from := _center(effect.from)
			var tip := from.lerp(pos, clampf(t*2.2,0.0,1.0))
			var back := tip + (from-pos).normalized()*(26 if effect.kind == "javelin" else 20)
			draw_line(back,tip,Color(0,0,0,fade*0.7),6)
			draw_line(back,tip,Color("c79a5b") if effect.kind == "javelin" else Color("f1ead2"),3)
			draw_circle(tip,3,Color("e8eef0",fade))
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
		"windup":
			# A glutton gathering itself before it bites the player.
			for k in range(2):
				draw_arc(pos, 30 + k * 8 + sin(t * 40.0) * 3.0, 0, TAU, 24, Color(1, 0.2, 0.35, fade * 0.7), 3, true)
			_text(pos + Vector2(-26, -44 - t * 8), "……！", 24, Color(1, 0.45, 0.55, fade))
		"devour", "gulp":
			# Huge jaws snap shut over the prey, then a red burst and crumbs sucked
			# back into the glutton. "ガブッ！"
			var span := 50.0 if effect.get("big", false) else 38.0
			var close := minf(t / 0.3, 1.0)
			var jaw_color := Color("d8245a") if effect.kind == "devour" else Color("ff3b4a")
			for side in [-1.0, 1.0]:
				var edge: float = side * lerpf(span + 14.0, 4.0, close)
				var back: float = edge + side * 14.0
				draw_colored_polygon(PackedVector2Array([pos + Vector2(-span, edge), pos + Vector2(span, edge), pos + Vector2(span, back), pos + Vector2(-span, back)]), Color(jaw_color.darkened(0.3), fade))
				for k in range(5):
					var x := -span + 8.0 + k * (span * 2.0 - 16.0) / 4.0
					draw_colored_polygon(PackedVector2Array([pos + Vector2(x - 7, edge), pos + Vector2(x + 7, edge), pos + Vector2(x, edge - side * 14.0)]), Color(1, 0.97, 0.9, fade))
			if t > 0.3:
				var burst := (t - 0.3) / 0.7
				draw_circle(pos, 10.0 + burst * 34.0, Color(jaw_color, (1.0 - burst) * 0.6))
				var home := _center(effect.get("from", effect.cell))
				for k in range(6):
					var start := pos + Vector2.from_angle(k * TAU / 6.0) * 26.0
					draw_circle(start.lerp(home, burst), 4.0 * (1.0 - burst) + 1.0, Color(jaw_color.lightened(0.2), fade))
				_text(pos + Vector2(-44, -40 - burst * 16.0), "ガブッ！", 26, Color(1, 0.95, 0.4, fade))
		"gravity":
			# The fairy shows for a moment on its tile, then fades with the rings:
			# closing in (pull) or rushing out (push).
			var pulling: bool = effect.get("pull", true)
			var side := 64.0 * (1.0 + 0.15 * sin(t * PI))
			draw_texture_rect(model.item_definition("gravity_fairy").icon, Rect2(pos - Vector2.ONE * side / 2, Vector2.ONE * side), false, Color(1, 1, 1, fade))
			for k in range(3):
				var r := (1.0 - t) * 60.0 - k * 14.0 if pulling else t * 60.0 + k * 14.0
				if r > 2.0:
					draw_arc(pos, r, 0, TAU, 32, Color(GRAVITY_PULL if pulling else GRAVITY_PUSH, fade * 0.8), 3, true)
		"fall":
			# Swallowed by the abyss: a closing dark mouth with a violet rim.
			var mouth := 26.0 * (1.0 - t * 0.7)
			draw_circle(pos, mouth, Color(0.02, 0.0, 0.06, fade))
			draw_arc(pos, mouth + 4, 0, TAU, 24, Color(0.62, 0.5, 1.0, fade), 3, true)
		"combo":
			# Rule C: the refund, rising over the player.
			_text(pos + Vector2(-58, -40 - t * 24), "連撃！ AP+1", 24, Color(GOLD, fade))
		"bite":
			# Two rows of fangs snapping shut on the tile.
			var close := minf(t * 2.5, 1.0)
			for side in [-1.0, 1.0]:
				var y: float = side * (20.0 - close * 14.0)
				for k in range(4):
					var x := -15.0 + k * 10.0
					draw_colored_polygon(PackedVector2Array([pos + Vector2(x - 4, y), pos + Vector2(x + 4, y), pos + Vector2(x, y - side * 9)]), Color(1, 0.96, 0.9, fade))
			if t > 0.35:
				draw_arc(pos, 8 + t * 16, 0, TAU, 18, Color(1, 0.3, 0.3, fade * 0.8), 3, true)
		"summon":
			match effect.get("fx", ""):
				"wall":
					# Dust puffs settling at the foot of the wall.
					for i in range(4):
						var x := -18 + i * 12
						draw_circle(pos + Vector2(x, 20 - t * 6), 4 + t * 6, Color("b9b39f", fade * 0.6))
				"holy":
					# Golden motes rising from the tile.
					for i in range(4):
						draw_circle(pos + Vector2(-18 + i * 12, 16 - t * 30 - (i % 2) * 6), 3, Color("ffe38a", fade))
					draw_arc(pos, 10 + t * 18, 0, TAU, 20, Color("fff4c4", fade * 0.7), 2, true)
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
				"revive":
					# The king raises the dead: cyan chains haul a pale soul up from the floor.
					for i in range(3):
						var x := -14.0 + i * 14.0
						draw_line(pos + Vector2(x, 30), pos + Vector2(x, 30 - t * 60), Color("6fe8ff", fade), 2)
					draw_circle(pos + Vector2(0, 10 - t * 24), 12 * (1.0 - t * 0.5), Color(0.8, 0.95, 1.0, fade * 0.7))
					draw_arc(pos, 10 + t * 20, 0, TAU, 24, Color("6fe8ff", fade), 3, true)
				"prison":
					# The prison doors burst open: cyan shards around the new executioner.
					for i in range(6):
						var shard := pos + Vector2.from_angle(i * TAU / 6) * (10 + t * 26)
						draw_line(shard, shard + Vector2.from_angle(i * TAU / 6) * 7, Color("6fe8ff", fade), 3)
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
	_text(Vector2(421,326),"ボス撃破！" if won and Rules.BOSS_LEVELS.has(model.level) else "包囲網を突破した" if won else "探索者、倒れる",26)
	_text(Vector2(423,365),"%dターン / 撃破 %d体" % [model.round_number,model.kills],18,MUTED)
	_text(Vector2(423,396),"妖精の使用回数が回復" if won else "初期ビルドから再挑戦",16,MUTED)

