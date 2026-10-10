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
const GRAVITY_PULL = Color("5fd4ff")
const GRAVITY_PUSH = Color("ff9a4a")
## Collisions from a shove (盾打ち・薙ぎ払い・突風剣・風斧精霊): their star, "ドンッ" and
## the extra "−1", which lands BUMP_LAG after the attack's own.
const BUMP = Color("ffe14a")
const BUMP_LAG := 0.28
## Hover preview for the gravity fairy: [from, to] per enemy it would move (cached per tile).
var gravity_hover := Vector2i(-9, -9)
var gravity_moves: Array = []
## Hover preview for a shoving weapon: where each enemy goes and what it slams into
## (cached per tile and weapon). {"key", "moves": [[unit, cell]], "bumps": [[cell, dir]], "hurt": [unit]}.
var shove_preview := {}
const SpiritIcon = preload("res://scripts/items/spirit_icon.gd")
const ThreatPreview = preload("res://scripts/threat_preview.gd")
const CAPACITOR_CHARGED = preload("res://assets/sprites/spirits/capacitor_fairy_charged.png")
const CAPACITOR_DISCHARGE = preload("res://assets/sprites/effects/capacitor_discharge.png")
const ZAP_H = preload("res://assets/sprites/effects/zap_h.png")
const ZAP_V = preload("res://assets/sprites/effects/zap_v.png")
const CLOCKWISE_NEXT = {Vector2i.UP: Vector2i.RIGHT, Vector2i.RIGHT: Vector2i.DOWN, Vector2i.DOWN: Vector2i.LEFT, Vector2i.LEFT: Vector2i.UP}
const RangeDiagram = preload("res://scripts/run/range_diagram.gd")
const RarityFrame = preload("res://scripts/run/rarity_frame.gd")
const Rarity = preload("res://scripts/run/rarity.gd")
## The weapon and fairy slots wear their rarity's material frame, thinner than a card's.
const SLOT_FRAME := 7.0
const Catalog = preload("res://scripts/run/weapon_catalog.gd")
const DirectionSheet = preload("res://scripts/items/direction_sheet.gd")
const AXE_DASH = preload("res://assets/sprites/spirits/axe_spirit_dash.png")
const MagicCircleFx = preload("res://scripts/fx/magic_circle_fx.gd")
const FairyBook = preload("res://scripts/fairy_book.gd")
const Achievements = preload("res://scripts/title/achievements.gd")
const AchievementToast = preload("res://scripts/title/achievement_toast.gd")
const AbyssFx = preload("res://scripts/fx/abyss_fx.gd")
const GuardianFx = preload("res://scripts/fx/guardian_fx.gd")
const ChainFx = preload("res://scripts/fx/chain_fx.gd")
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
## Plain information text: the light blue of the レア label (greys read poorly).
const MUTED = Rarity.INFO
const CYAN = Color("2bdcc8")
const GOLD = Color("f4d56f")
const ITEM_ARROW_POSITIONS = [Vector2(956,425),Vector2(1010,459),Vector2(956,493),Vector2(902,459)]

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
var last_chain: Dictionary = {}
var chain_shake := 0.0
## The hammer's hit-stop ({cell, until}) and the rumble after it (seconds left).
var hammer_stop: Dictionary = {}
var quake_shake := 0.0
const QUAKE_SHAKE_TIME := 0.5
const QUAKE_SHAKE_POWER := 9.0
var chain_shake_power := 0.0
## Hearts in a cannon chain drop as each shot lands: id -> [[clock time, hp], ...].
var hp_timeline: Dictionary = {}
var last_circle: Dictionary = {}
var grid_buttons: Array[Button] = []
var busy := false
var generation := 0
var hover_cell := Vector2i(-1,-1)
var flashes: Array[Dictionary] = []
var clock := 0.0
## The achievement banner being shown: {id, until}.
var toast := AchievementToast.new()
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
## 「タイトルへ」: the first press asks "もう一度押すと戻る"; a second press within a few seconds
## leaves the battle (the run is lost).
var title_button: Button
const TITLE_LABEL := "タイトルへ"
const TITLE_SURE := "本当に戻る？"
const TITLE_SCENE := "res://title.tscn"
var title_asked_at := -100.0
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
	add_child(toast)
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
	title_button = _button(ui,Rect2(956,34,172,36),TITLE_LABEL,_title_pressed)
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

func _title_pressed() -> void:
	if clock - title_asked_at > 3.0:
		title_asked_at = clock
		title_button.text = TITLE_SURE
		title_button.add_theme_color_override("font_color",Color("ff987f"))
		return
	_leave_to_title()

func _leave_to_title() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(TITLE_SCENE)

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
	bgm.theme = "king" if model.level == Rules.FINAL_LEVEL else "boss" if model.level == Rules.BOSS_LEVEL or Rules.LATE_LEVELS.has(model.level) else ("shark" if model.boss2_variant == 1 else "rotorick") if model.level == Rules.BOSS2_LEVEL else "battle"
	TILE = 64.0 if model.board_size <= 8 else floorf(512.0/model.board_size)
	# The small opening boards (4x4, 5x5) are drawn bigger, so the first fights fill the
	# space the larger boards use; they keep the 6x6 board's centre.
	if model.board_size <= 5:
		TILE = minf(96.0, floorf(400.0/model.board_size))
	BOARD = Vector2(576,368)-Vector2.ONE*model.board_size*TILE/2.0 if model.board_size <= 6 else Vector2(384,176)+Vector2.ONE*(6-model.board_size)*TILE/2.0
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
	elif model.level == Rules.BOSS2_LEVEL and model.boss2_variant == 1:
		_shark_intro()
	elif model.level == Rules.BOSS2_LEVEL:
		# Rotorick: the casino entrance (see _boss_intro) holds his music until the reels stop.
		bgm.hold(CasinoFx.LIFE["intro"])
		_sting("rotorick_intro")

## The storm shark's entrance, on the song's own clock: seven seconds of it circling as a shadow
## under the water (the build-up), then the drop at 53 s throws it up out of the water, rebuilt as
## a hologram.
const SHARK_LURK := 7.0
var shark_intro := false
var shark_intro_t := 0.0
var shark_title_t := -1.0
func _shark_intro() -> void:
	busy = true
	shark_intro = true
	shark_intro_t = 0.0
	shark_title_t = -1.0
	var token := generation
	_update_controls()
	var shark: Dictionary = model.storm_shark()
	if not shark.is_empty() and actors.has(int(shark.id)):
		actors[int(shark.id)].visible = false
		actors[int(shark.id)].holo_build = 0.0
		actors[int(shark.id)].holo_goal = 0.0
	while shark_intro_t < SHARK_LURK:
		await get_tree().process_frame
		if token != generation or not is_inside_tree():
			return
	if token != generation:
		return
	shark_intro = false
	shark_title_t = 0.0
	if not shark.is_empty() and actors.has(int(shark.id)):
		var actor = actors[int(shark.id)]
		actor.visible = true
		actor.holo_goal = 1.0
		actor.play_pose("surface")
		actor.flash = 0.35
	if not shark.is_empty():
		flashes.append({"kind": "emerge", "cell": shark.cell, "id": int(shark.id), "life": FX_LIFE["emerge"], "max_life": FX_LIFE["emerge"]})
	chain_shake = 0.55
	chain_shake_power = 14.0
	queue_redraw()
	await get_tree().create_timer(1.1).timeout
	if token != generation:
		return
	busy = false
	_sync_units(false)
	_update_controls()

## Rotorick's entrance: the lights drop, three reels spin and stop on 7-7-7, his name lights up,
## and only then does he drop in.
func _rotorick_entrance(token: int) -> bool:
	var boss: Dictionary = {}
	for enemy in model.enemies:
		if enemy.type == "slot":
			boss = enemy
	if not boss.is_empty() and actors.has(int(boss.id)):
		actors[int(boss.id)].visible = false
	reel_hold = true
	_casino_show("intro")
	await get_tree().create_timer(1.85).timeout
	if token != generation:
		return false
	if not boss.is_empty() and actors.has(int(boss.id)):
		actors[int(boss.id)].visible = true
		actors[int(boss.id)].flash = 0.4
	chain_shake = 0.5
	chain_shake_power = 14.0
	await get_tree().create_timer(CasinoFx.LIFE["intro"] - 1.85 + 0.1).timeout
	return token == generation

func _casino_show(mode: String, reel := 0, mini := 0) -> void:
	var fx := CasinoFx.new()
	fx.mode = mode
	fx.reel = reel
	fx.mini = mini
	fx.centre = BOARD + Vector2.ONE * model.board_size * TILE / 2.0
	fx.extent = model.board_size * TILE
	fx.reel_color = REEL_COLORS.get(reel, CasinoFx.GOLD)
	fx.reel_label = REEL_SHORT.get(reel, "")
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.scale = Vector2.ONE * UI_SCALE
	add_child(layer)
	layer.add_child(fx)

## After Rotorick spins (a "slot_spin" event): the draw plays out big, then the board shows the result.
func _play_lottery(token: int) -> bool:
	var spin := {}
	for event in model.events:
		if event.kind == "slot_spin":
			spin = event
	if spin.is_empty():
		reel_hold = false
		return true
	model.events.assign(model.events.filter(func(e: Dictionary) -> bool: return e.kind != "slot_spin"))
	reel_hold = true
	_sync_units(false)
	_casino_show("lottery", int(spin.reel), int(spin.mini))
	await get_tree().create_timer(1.0).timeout
	if token != generation:
		return false
	chain_shake = 0.2
	chain_shake_power = 6.0
	await get_tree().create_timer(CasinoFx.LIFE["lottery"] - 1.0).timeout
	if token != generation:
		return false
	reel_hold = false
	_sync_units(false)
	queue_redraw()
	return true

## While the draw plays (or the entrance), the reel on Rotorick's chest keeps spinning.
var reel_hold := false
const REEL_COLORS = {1: Color("ffd35b"), 2: Color("ffd35b"), 3: Color("ffd35b"), 4: Color("ff4b3b"), 5: Color("c9c9c9"), 6: Color("c79bff"), 7: Color("ff3b4a")}
const REEL_SHORT = {1: "武器制限[1]", 2: "武器制限[2]", 3: "武器制限[3]", 4: "ダメージ床", 5: "故障・停止", 6: "残像", 7: "AP+1"}

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
	var rotorick: bool = model.enemies.any(func(e: Dictionary) -> bool: return e.type == "slot")
	if rotorick:
		if not await _rotorick_entrance(token):
			return
	else:
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
	if rotorick:
		if not await _play_lottery(token):
			return
	else:
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
	# Pressing the weapon already in hand while a fairy is picked means "no fairy, the weapon then".
	var same_weapon: bool = index == model.weapon
	# A weapon with nowhere to move or strike cannot be taken up.
	if not same_weapon and model.weapon_stuck_reason(index) != "":
		return
	if model.equip(index):
		# A fairy picked before another weapon stays picked: only its reach (the new weapon's range) changes.
		if selected_item.is_empty() or same_weapon:
			_cancel_item()
		else:
			_update_controls()
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
		wait = maxf(wait, _chain_time() + 0.3)  # an acorn setting off a cannon chain
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
		# The blessed ground's heal at the end of the turn shows before the enemies move.
		_sync_units(true)
		_feedback()
		queue_redraw()
		await get_tree().create_timer(maxf(0.35, _chain_time() + 0.3)).timeout
		if token != generation:
			return
	await get_tree().create_timer(0.12).timeout
	if token != generation:
		return
	for beat in range(planner.beat_count(model)):
		var cells := {}
		for enemy in model.enemies:
			cells[enemy.id] = enemy.cell
		planner.beat(model,beat)
		if model.enemies.any(func(e: Dictionary) -> bool: return cells.has(e.id) and cells[e.id] != e.cell):
			_sound("enemy_step", -3.0)
		if not await _play_charges(token):
			return
		_sync_units(true)
		_feedback()
		queue_redraw()
		await get_tree().create_timer(0.17).timeout
		if token != generation:
			return
		if not model.terminal() and not await _play_lottery(token):
			return
		if model.terminal():
			break
	planner.finish(model)
	_sync_units(false)
	# A jester that has marched its three turns wakes at the end of the enemy turn, in plain view.
	var woke: Array = model.events.filter(func(e: Dictionary) -> bool: return e.kind == "awaken")
	if not woke.is_empty():
		for event in woke:
			var flash: Dictionary = event.duplicate()
			flash.life = FX_LIFE["awaken"]
			flash.max_life = flash.life
			flashes.append(flash)
			if actors.has(int(event.id)):
				actors[int(event.id)].flash = 0.3
		_sound("king_revive", -4.0)
		queue_redraw()
		await get_tree().create_timer(0.7).timeout
		if token != generation:
			return
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
		# 影縫い精霊: trade places with the pinned shadow (1 AP, 0 once classed up).
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
	var was_boosted: bool = model.combo_boost == model.weapon
	var used_weapon: int = model.weapon
	if not model.player_action(cell):
		if not model.targets().has(cell):
			selected_enemy_id = -2
			queue_redraw()
		return
	selected_enemy_id = -2
	_finish_player_action(true,{"origin":origin,"destination":cell,"attacking":attacking,"weapon":used_weapon,"boosted":was_boosted})

## Every enemy a weapon blow struck staggers and shakes the board, whatever the weapon.
func _react_to_weapon_hits(weapon_action: Dictionary) -> void:
	var hit_direction := Vector2(weapon_action.destination - weapon_action.origin)
	for event in model.events:
		# Hits further down a cannon chain react when their shot lands.
		if event.kind == "hit" and int(event.id) >= 0 and event.get("delay", 0.0) <= 0.0:
			_react_to_hit(event, hit_direction)

func _finish_player_action(animate: bool, weapon_action: Dictionary = {}) -> void:
	busy = true
	var token := generation
	var weapon_kind: String = Rules.WEAPONS[weapon_action.weapon].id if not weapon_action.is_empty() else ""
	if not weapon_action.is_empty() and Catalog.is_hammer(weapon_action.weapon):
		weapon_kind = "hammer"  # the mallet swings like the hammer
	# Swords swing; the hammer uses its own sheet; the bow just looses an arrow.
	var sword_attack: bool = not weapon_action.is_empty() and weapon_action.attacking and weapon_kind not in ["hammer","bow"]
	var hammer_attack: bool = not weapon_action.is_empty() and weapon_action.attacking and weapon_kind == "hammer"
	if not weapon_action.is_empty() and not weapon_action.attacking:
		_sound("step")
	if sword_attack or hammer_attack:
		# The model resolves immediately; keep the prior enemy visuals until contact.
		var player_view = actors[-1]
		var impact_time: float
		var duration: float
		if hammer_attack:
			# The hammer is raised, then brought down: the blow lands with the strike.
			player_view.play_hammer_attack(Vector2(weapon_action.destination - weapon_action.origin))
			impact_time = UnitView.hammer_contact()
			duration = UnitView.hammer_duration()
			# The slam's crack lands as the head touches the tile (the hit-stop).
			if sfx != null:
				sfx.play_at_impact("hammer_slam", impact_time)
		elif Catalog.is_dagger(weapon_action.weapon):
			var boosted: bool = weapon_action.get("boosted", false)
			player_view.play_dagger_attack(boosted, Vector2(weapon_action.destination - weapon_action.origin))
			impact_time = player_view.dagger_impact_time(boosted)
			duration = player_view.dagger_duration(boosted)
			if sfx != null:
				# The boosted finisher has its own sound: two slashes closing in, then the crossing.
				sfx.play_at_impact("cross_strike" if boosted else "sword_swing", impact_time)
		else:
			player_view.play_sword_attack(model.facing)
			impact_time = player_view.sword_impact_time()
			duration = player_view.sword_attack_duration()
			if sfx != null:
				sfx.play_at_impact("sword_swing", impact_time)
		_update_controls()
		await get_tree().create_timer(impact_time).timeout
		if token != generation:
			return
		if hammer_attack:
			# Hit-stop: the head sits on the tile, the ground flashes, nothing moves yet.
			hammer_stop = {"cell": weapon_action.destination, "until": clock + UnitView.HAMMER_HITSTOP}
			queue_redraw()
			await get_tree().create_timer(UnitView.HAMMER_HITSTOP).timeout
			if token != generation:
				return
			hammer_stop = {}
			impact_time += UnitView.HAMMER_HITSTOP
			# Then the ground heaves: a rumble, heavier up and down.
			quake_shake = QUAKE_SHAKE_TIME
		_sync_units(false)
		_feedback(true)
		_react_to_weapon_hits(weapon_action)
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
		# Bows, staffs and the rest shake the board and stagger the enemy just like a swing does.
		if not weapon_action.is_empty() and weapon_action.attacking:
			_react_to_weapon_hits(weapon_action)
		# Let the magic circle play out before the turn moves on.
		if model.events.any(func(e: Dictionary) -> bool: return e.kind == "circle"):
			action_duration = maxf(action_duration, MagicCircleFx.BURST + 0.4)
		# The king's rage and fall are cinematics: wait them out.
		if model.events.any(func(e: Dictionary) -> bool: return e.kind == "king_rage"):
			action_duration = maxf(action_duration, BossCinematic.LIFE["rage"])
		if model.events.any(func(e: Dictionary) -> bool: return e.kind == "king_fall"):
			action_duration = maxf(action_duration, BossCinematic.LIFE["fall"])
		if model.events.any(func(e: Dictionary) -> bool: return e.kind == "meteor"):
			action_duration = maxf(action_duration, FX_LIFE["meteor"])
		if model.events.any(func(e: Dictionary) -> bool: return e.kind == "barrier_break"):
			action_duration = maxf(action_duration, FX_LIFE["barrier_break"])
		for event in model.events:
			if event.kind == "guardian":
				# The guardian lands, its allies pop in one by one, then the light bursts.
				action_duration = maxf(action_duration, GuardianFx.LAND + float(event.calls.size()) * 0.15 + 0.7)
		# Let the abyss finish opening too.
		if model.events.any(func(e: Dictionary) -> bool: return e.kind == "summon" and e.get("fx","") == "abyss"):
			action_duration = maxf(action_duration, AbyssFx.LIFE - 0.3)
		_update_controls()
		await get_tree().create_timer(action_duration).timeout
	# Let a cannon chain play out, link by link (and its closing banner).
	var chain := _chain_time()
	if chain > 0.0:
		var banner := model.events.any(func(e: Dictionary) -> bool: return e.kind == "chain")
		await get_tree().create_timer(chain + (1.0 if banner else 0.3)).timeout
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
	var used := selected_item
	if model.use_item(selected_item,cell,direction,selected_item_slot):
		# The title screen lets a fairy out of its silhouette once it has been used.
		FairyBook.record_use(used)
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

func _exit_tree() -> void:
	Engine.time_scale = 1.0  # never leave a hit-stop behind

## A chain link lands: CHAIN ×n pops over the cannon, the screen shakes, and time
## stops for a heartbeat (a hit-stop). The last link also shows the chain's total.
func _chain_burst(event: Dictionary) -> void:
	var fx := ChainFx.new()
	fx.count = int(event.count)
	fx.position = _center(event.cell)
	fx.board = Rect2(BOARD, Vector2.ONE * TILE * model.board_size)
	var top := 0
	for other in model.events:
		if other.kind == "chain":
			top = maxi(top, int(other.count))
	if int(event.count) == top:
		fx.banner = true
		fx.hits = model.events.filter(func(e: Dictionary) -> bool: return e.kind == "hit" and int(e.id) >= 0).size()
	add_child(fx)
	# ピコン: one semitone higher for every link of this turn's chain.
	if sfx != null:
		sfx.chain_link(int(event.count) - 1)
	chain_shake = 0.22
	chain_shake_power = 5.0 + 2.0 * mini(int(event.count), 6)
	# Hit-stop: freeze for a beat (longer on the last link), then carry on.
	Engine.time_scale = 0.03
	get_tree().create_timer(0.16 if fx.banner else 0.09, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

## The last beat of a cannon chain (0 when nothing waits).
func _chain_time() -> float:
	var longest := 0.0
	for event in model.events:
		longest = maxf(longest, float(event.get("delay", 0.0)))
	return longest

func _sync_units(animate: bool) -> void:
	# A cannon chain: the fallen stay up until the shot that fells them lands.
	var chain := _chain_time()
	if chain > 0.0 and not model.events.is_empty() and not is_same(model.events[-1], last_chain):
		last_chain = model.events[-1]
		hp_timeline.clear()
		for event in model.events:
			if event.kind != "hit" or not event.has("hp_before"):
				continue
			var steps: Array = hp_timeline.get(int(event.id), [])
			if steps.is_empty():
				steps.append([clock - 1.0, int(event.hp_before)])
			steps.append([clock + float(event.get("delay", 0.0)), int(event.hp)])
			hp_timeline[int(event.id)] = steps
		hold_dead_until = maxf(hold_dead_until, clock + chain + 0.15)
		get_tree().create_timer(chain + 0.2).timeout.connect(func(): _sync_units(false))
	for event in model.events:
		if event.kind == "circle" and not is_same(event, last_circle):
			last_circle = event
			hold_dead_until = clock + MagicCircleFx.BURST
			get_tree().create_timer(MagicCircleFx.BURST + 0.05).timeout.connect(func(): _sync_units(false))
	var flung := {}
	for event in model.events:
		if event.kind == "knock_home":
			flung[int(event.id)] = true
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
		view.hp = _shown_hp(id, unit.hp)
		view.ap_boxes = _ap_boxes(unit) if id >= 0 else 0
		view.death_mark = Rules.DEATH_EFFECT_TYPES.has(unit.type)
		view.holo_goal = 0.0 if unit.get("diving", false) else 1.0
		# "!" on enemies about to hit the player, and on a glutton about to bite them.
		view.charge_warning = id != -1 and threats.has(id)
		view.weapon_row = Rules.WEAPONS[model.weapon].row
		var target := _unit_center(unit)
		if id == -1:
			var held: String = Rules.WEAPONS[model.weapon].id
			view.dagger_look = "thunder" if held == "thunder_dagger" else "flame" if held == "flame_dagger" else ""
			view.dagger_boosted = view.dagger_look != "" and model.combo_boost == model.weapon
		view.hearts_above = id == -1 and model.riding_wheel()
		if id == -1 and model.riding_wheel():
			# Standing on the wheel's platform (the gold bar on top of the larger wheel).
			target += Vector2(7.0, -25.0) * TILE / 64.0
		view.facing = int(unit.get("facing",2)) if unit.type == "holy_knight" else 1 if id < 0 else int(unit.get("facing",3)) if unit.type in UnitView.BOSS_KINDS or unit.type == "jester" else 3
		view.braced = unit.get("state","") == "brace"
		view.frozen = int(unit.get("frozen",0))
		view.time_stopped = id >= 0 and model.time_stopped()
		# The stopped world is drawn over the enemies but under you and your allies.
		view.z_index = 0 if id >= 0 and model.time_stopped() else 2
		view.reel = 0 if reel_hold and unit.type == "slot" else int(unit.get("reel",0))
		view.alt_row = unit.get("state","") == "aim" or int(unit.get("learned",-1)) >= 0 or unit.get("awake", false)
		view.wake_turns = Rules.JESTER_SLEEP_TURNS - int(unit.get("age", 0)) if unit.type == "jester" and not unit.get("awake", false) else 0
		var learned := int(unit.get("learned",-1))
		view.learned_text = "解析:" + Rules.WEAPONS[learned].short if learned >= 0 else ""
		view.learned_color = Color(Rules.WEAPONS[learned].color) if learned >= 0 else Color.WHITE
		view.set_meta("cells", model.footprint(unit))
		view.hop_height = 0.0
		if animate:
			var jumping := false
			if flung.has(id):
				# Blown back to the starting place: a long, fast slide that eases to a stop.
				move_tween.tween_property(view,"position",target,0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			else:
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
		"chain_cut":
			return "fortress_crack"
		"barrier_break":
			return "fortress_collapse"
	return ""

## A beat of hit-stop: time nearly freezes for a moment, so a blow lands with weight. Every hit on an
## enemy gets one (weapons, fairies, cannons' first shot, allies), never stacked on a running one.
func _hit_stop(seconds: float = 0.05) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

## Whether this event is a blow landing on someone right now (damage on anyone, or a mine going off).
func _blow_lands(event: Dictionary) -> bool:
	if float(event.get("delay", 0.0)) > 0.0 or int(event.get("id", -2)) == -2:
		return false
	if event.kind == "mine":
		return true
	return event.kind == "hit" and int(event.get("damage", 1)) > 0

func _feedback(weapon_attack: bool = false) -> void:
	# A shove counts as a blow too (the knockback weapons deal no damage but hit just as hard).
	if model.events.any(func(e: Dictionary) -> bool: return (e.kind == "hit" and int(e.id) >= 0 and int(e.get("damage", 1)) > 0 or e.kind == "push") and float(e.get("delay", 0.0)) <= 0.0):
		_hit_stop()
	# A magic circle shows its own "99"s: no ordinary hit popups under it.
	var casting := model.events.any(func(e: Dictionary) -> bool: return e.kind == "circle")
	var heard := {}
	for event in model.events:
		var sound := _event_sound(event)
		if sound != "" and not heard.has(sound):
			heard[sound] = true
			_sound(sound)
		# Every other blow that lands (an enemy on you, a fairy on an enemy, a mine) makes the sword's
		# hit sound too, once per beat (a chain's own links and the bosses' sounds keep theirs).
		elif sound == "" and not weapon_attack and not casting and not heard.has("blow") and _blow_lands(event):
			heard["blow"] = true
			_sound("sword_swing", -3.0)
		# The meteor's rumble is timed to land with the rock (0.35 s into its fall).
		if event.kind == "meteor" and not heard.has("meteor") and sfx != null:
			heard["meteor"] = true
			sfx.play_at_impact("meteor", 0.35)
	for event in model.events:
		if casting and event.kind == "hit" and event.id >= 0:
			continue
		if event.kind == "dive" and actors.has(int(event.id)):
			actors[int(event.id)].play_pose("dive")
		elif event.kind == "knock_home":
			chain_shake = 0.5
			chain_shake_power = 14.0
		elif event.kind == "cross_strike":
			chain_shake = 0.4
			chain_shake_power = 10.0
		elif event.kind == "thunder":
			chain_shake = 0.45
			chain_shake_power = 12.0
		elif event.kind == "surface" and actors.has(int(event.id)):
			actors[int(event.id)].play_pose("surface")
			chain_shake = 0.3
			chain_shake_power = 8.0
		elif event.kind == "hit" and event.get("by", -9) >= 0 and event.id == -1 and actors.has(int(event.by)) and actors[int(event.by)].kind == "storm_shark" and not model.events.any(func(e: Dictionary) -> bool: return e.kind == "surface"):
			actors[int(event.by)].play_pose("bite")
		var kind: String = "weapon_hit" if weapon_attack and event.kind == "hit" else event.kind
		var flash: Dictionary = event.duplicate()
		flash.kind = kind
		flash.life = FX_LIFE.get(kind,0.42)
		if event.get("damage", 1) >= Rules.CIRCLE_DAMAGE:
			flash.life = 1.0  # the big "99" stays up a moment
		if event.get("bump", false):
			flash.life = 0.85  # its "−1" waits a beat, then rises
		if event.kind == "bump" and event.get("hurt", true) and chain_shake < 0.12:
			# A collision jolts the board a little.
			chain_shake = 0.12
			chain_shake_power = 5.0
		if event.kind == "hit" and int(event.id) >= 0 and actors.has(int(event.id)):
			flash.span = int(actors[int(event.id)].span)
			flash.life = maxf(flash.life, 0.62)
		if event.kind == "hit" and int(event.id) >= 0 and not weapon_attack and flash.get("delay", 0.0) <= 0.0:
			_react_to_hit(event)
		flash.max_life = flash.life
		flashes.append(flash)
		if event.kind == "circle":
			_cast_circle_fx(event)
		if event.kind == "summon" and event.get("fx","") == "abyss":
			_open_abyss_fx()
		if event.kind == "guardian":
			_guardian_entrance(event)
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
		if actors.has(event.id) and event.kind not in ["plant", "charge_end", "heal"] and not (event.kind == "hit" and int(event.id) >= 0):
			actors[event.id].flash = 0.18

## An enemy taking damage: it blinks white, burns red and is knocked along the blow
## (the unit does that), and the board jolts, harder for bigger enemies.
func _react_to_hit(event: Dictionary, direction: Vector2 = Vector2.ZERO) -> void:
	var id := int(event.id)
	if id < 0:
		return
	# A killing blow has already removed the enemy's view: the board still shakes for it.
	var span := 1
	if actors.has(id):
		var actor: Node2D = actors[id]
		span = int(actor.span)
		if direction == Vector2.ZERO:
			direction = Vector2(event.get("dir", Vector2i.ZERO))
		if direction == Vector2.ZERO and actors.has(-1):
			direction = actor.position - actors[-1].position
		actor.play_hit_reaction(direction)
	# Every blow lands as hard as the first: a run of hits in one turn builds, never fades.
	if streak_round != model.round_number:
		streak_round = model.round_number
		hit_streak = 0
	hit_streak += 1
	var power := 3.0 + 2.0 * span + 1.5 * mini(hit_streak - 1, 3)
	if chain_shake <= 0.14:
		chain_shake = 0.2
		chain_shake_power = power
	else:
		chain_shake = maxf(chain_shake, 0.2)
		chain_shake_power = maxf(chain_shake_power, power)

## Blows landed so far this turn (each one shakes the board a little harder, up to a point).
var hit_streak := 0
var streak_round := -1

## 守護神の妖精: the board dims, a pillar of light drops the guardian in, and each ally
## it calls fades in on its beat as a streak of light reaches it.
func _guardian_entrance(event: Dictionary) -> void:
	var calls: Array = []
	for call in event.calls:
		var at := _center(call.cell)
		if actors.has(int(call.ally)):
			var actor: Node2D = actors[int(call.ally)]
			at = actor.position
			_fade_in(actor, float(call.delay))
			# It arrives with its usual hearts; a beat later the guardian's blessing
			# adds one with a twinkle (キラン・キラン・キラン).
			var bless_at := float(call.delay) + 0.3
			var hp := int(actor.hp)
			hp_timeline[int(call.ally)] = [[clock - 1.0, hp - 1], [clock + bless_at, hp]]
			actor.hp = hp - 1
			get_tree().create_timer(bless_at).timeout.connect(func():
				if is_instance_valid(actor):
					actor.sparkle())
		calls.append({"pos": at, "delay": float(call.delay)})
	var origin := _center(event.cell) + Vector2.ONE * TILE / 2
	if actors.has(int(event.ally)):
		_fade_in(actors[int(event.ally)], GuardianFx.LAND - 0.05)
	for dark in [true, false]:
		var fx := GuardianFx.new()
		fx.dark = dark
		fx.origin = origin
		fx.tile = TILE
		fx.calls = calls
		fx.screen = Rect2(Vector2(-40, -40), Vector2(1152, 720) + Vector2(80, 80))
		add_child(fx)

func _fade_in(actor: Node2D, delay: float) -> void:
	actor.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(actor, "modulate:a", 1.0, 0.12)

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

## Achievements earned inside a battle. Called after every change, so it only has to be true
## at that moment: all the fairies used (FairyBook), or the battle won while time stands still.
func _check_achievements() -> void:
	toast.show_new(Achievements.check(model))

## Weapon index -> why it cannot be used now (see BattleModel.weapon_stuck_reason). Looked up once per
## change, not once per drawn frame: judging a weapon tries its tiles on copies of the battle.
var stuck_reasons := {}

func _update_controls() -> void:
	stuck_reasons.clear()
	for index in model.owned_weapons:
		var reason: String = model.weapon_stuck_reason(index)
		if reason != "":
			stuck_reasons[index] = reason
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
	result_button.text = "報酬を選ぶ →" if model.phase == Rules.Phase.WON else "結果へ →"
	for actor in actors.values():
		actor.visible = (not model.terminal() or busy) and not show_rules and not inventory_ui.opened and not (shark_intro and actor.kind == "storm_shark")
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
	_check_achievements()
	queue_redraw()

func _selected_enemy() -> Dictionary:
	for enemy in model.enemies:
		if int(enemy.id) == selected_enemy_id:
			return enemy
	return {}

## A summoned ally under the cursor (or pinned with a right click; ally ids are -100 and down).
func _preview_ally() -> Dictionary:
	for ally in model.allies:
		if int(ally.id) == selected_enemy_id and ally.hp > 0:
			return ally
	if not _selected_enemy().is_empty():
		return {}
	return model.ally_at(hover_cell)

func _preview_enemy() -> Dictionary:
	var selected := _selected_enemy()
	if not selected.is_empty():
		return selected
	var enemy := model.enemy_at(hover_cell)
	# Rotorick's shadow can be walked through, but hovering still explains it.
	return enemy if not enemy.is_empty() else model.shadow_at(hover_cell)

## The AP an enemy has each turn, as the boxes under its hearts and in its info (an awakened jester's
## AP is 3 for good; Rotorick gains one on reel 7).
func _ap_boxes(enemy: Dictionary) -> int:
	if not Rules.TYPES.has(enemy.type):
		return 0
	var type: Dictionary = Rules.TYPES[enemy.type]
	var base_ap: int = Rules.JESTER_AWAKE_AP if enemy.type == "jester" and enemy.get("awake", false) else int(type.ap)
	return base_ap + (1 if enemy.type == "slot" and int(enemy.get("reel",0)) == 7 else 0)

## Where a hovered enemy could step with one AP (its plain move tiles; the big prison and shark show the
## tiles their body would newly cover; the other bosses show none).
func _enemy_step_cells(enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if enemy.is_empty() or enemy.get("diving", false):
		return result
	if enemy.type in ["prison", "storm_shark"]:
		# The 2x2 bodies step one tile in a straight line: the tiles the body would newly cover.
		for direction in Rules.CARDINALS:
			var front: Array = model._front_cells(enemy, direction)
			var free: bool = front.all(func(c: Vector2i) -> bool: return model.inside(c) and not model.enemy_blocked(c) and not model.mines.has(c) and model.enemy_at(c).is_empty() and c != model.player.cell)
			if free:
				for c in front:
					result.append(c)
		return result
	if enemy.type in ["rook","shadow","slot","king","fortress"] or int(enemy.get("size",1)) > 1:
		return result
	for offset in model.enemy_offsets(enemy):
		var cell: Vector2i = enemy.cell + offset
		if model.inside(cell) and not model.enemy_blocked(cell) and cell != model.player.cell and model.enemy_at(cell).is_empty() and not model.mines.has(cell):
			result.append(cell)
	return result

func _enemy_moves(enemy: Dictionary) -> Array[Vector2i]:
	if enemy.is_empty():
		return []
	var result: Array[Vector2i] = []
	for direction in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var cell: Vector2i = enemy.cell + direction
		if model.inside(cell):
			result.append(cell)
	return result

## HP to show: during a cannon chain, the hearts left after the shots that have landed.
func _shown_hp(id: int, hp: int) -> int:
	if not hp_timeline.has(id):
		return hp
	var shown := hp
	var steps: Array = hp_timeline[id]
	if clock >= float(steps[-1][0]):
		hp_timeline.erase(id)
		return hp
	for step in steps:
		if clock >= float(step[0]):
			shown = int(step[1])
	return shown

## 時の妖精: the board loses its colour while time stands still (a screen-reading
## overlay above the enemies, below the player and the allies), with a negative flash
## as it stops and a quick bleed back when it runs again.
const TimeStopShader = preload("res://scripts/fx/time_stop.gdshader")
const CasinoShader = preload("res://scripts/fx/casino.gdshader")
const CasinoFx = preload("res://scripts/fx/casino_fx.gd")
var time_overlay: ColorRect
var time_amount := 0.0
var time_negative := 0.0
var time_was_stopped := false
func _update_time_overlay(delta: float) -> void:
	var stopped: bool = model != null and model.time_stopped()
	if stopped and not time_was_stopped:
		time_negative = 1.0
	time_was_stopped = stopped
	time_amount = move_toward(time_amount, 1.0 if stopped else 0.0, delta * (2.5 if stopped else 4.0))
	time_negative = move_toward(time_negative, 0.0, delta * 2.2)
	if time_amount <= 0.0 and time_negative <= 0.0:
		if time_overlay != null:
			time_overlay.visible = false
		return
	if time_overlay == null:
		time_overlay = ColorRect.new()
		var shader_material := ShaderMaterial.new()
		shader_material.shader = TimeStopShader
		time_overlay.material = shader_material
		time_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_overlay.z_index = 1
		add_child(time_overlay)
	time_overlay.visible = true
	var rim := 4.0 if model.board_size >= 8 else 10.0
	time_overlay.position = BOARD - Vector2.ONE * rim
	time_overlay.size = Vector2.ONE * (model.board_size * TILE + rim * 2)
	(time_overlay.material as ShaderMaterial).set_shader_parameter("amount", time_amount)
	(time_overlay.material as ShaderMaterial).set_shader_parameter("negative", time_negative)

var casino_overlay: ColorRect
func _update_casino_overlay() -> void:
	var present: bool = model != null and model.enemies.any(func(e: Dictionary) -> bool: return e.type == "slot" and e.hp > 0)
	if not present:
		if casino_overlay != null:
			casino_overlay.visible = false
		return
	if casino_overlay == null:
		casino_overlay = ColorRect.new()
		var shader_material := ShaderMaterial.new()
		shader_material.shader = CasinoShader
		casino_overlay.material = shader_material
		casino_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		casino_overlay.z_index = 1
		add_child(casino_overlay)
	casino_overlay.visible = true
	var margin := 12.0
	casino_overlay.position = BOARD - Vector2.ONE * margin
	casino_overlay.size = Vector2.ONE * (model.board_size * TILE + margin * 2.0)
	(casino_overlay.material as ShaderMaterial).set_shader_parameter("time", clock)
	(casino_overlay.material as ShaderMaterial).set_shader_parameter("bulbs", float(model.board_size * 4 + 8))
	(casino_overlay.material as ShaderMaterial).set_shader_parameter("energy", 1.0 if not reel_hold else 1.5)
	var shown := 0
	for enemy in model.enemies:
		if enemy.type == "slot" and enemy.hp > 0 and not reel_hold:
			shown = int(enemy.get("reel",0))
	(casino_overlay.material as ShaderMaterial).set_shader_parameter("mode", shown if shown in [5, 7] else 0)

func _process(delta: float) -> void:
	clock += delta
	_update_casino_overlay()
	if shark_intro:
		# The song's own clock when it plays (so the drop lands on the beat); else our own.
		var song: float = bgm.shark_clock()
		shark_intro_t = song if song >= 0.0 else shark_intro_t + delta
	if shark_title_t >= 0.0:
		shark_title_t += delta
		if shark_title_t > 3.2:
			shark_title_t = -1.0
	if title_button.text == TITLE_SURE and clock - title_asked_at > 3.0:
		title_button.text = TITLE_LABEL
		title_button.remove_theme_color_override("font_color")
		title_button.add_theme_color_override("font_color",INK)
	_update_time_overlay(delta)
	if chain_shake > 0.0 or quake_shake > 0.0:
		chain_shake -= delta
		quake_shake -= delta
		var offset := Vector2.ZERO
		if chain_shake > 0.0:
			offset += Vector2(sin(clock * 97.0), cos(clock * 83.0)) * chain_shake_power * chain_shake / 0.22
		if quake_shake > 0.0:
			# A ground rumble: mostly up and down, a low heave under a fast judder.
			var left := pow(quake_shake / QUAKE_SHAKE_TIME, 1.5)
			offset += Vector2(sin(clock * 71.0) * 0.35, sin(clock * 38.0) * 0.7 + sin(clock * 113.0) * 0.3) * QUAKE_SHAKE_POWER * left
		position = offset
	for id in hp_timeline.keys():
		if actors.has(id):
			var unit: Dictionary = {}
			for other in model.enemies + model.allies:
				if int(other.id) == id:
					unit = other
			actors[id].hp = _shown_hp(id, int(unit.get("hp", 0)))
		else:
			hp_timeline.erase(id)
	for i in range(flashes.size()-1,-1,-1):
		if flashes[i].get("delay", 0.0) > 0.0:
			# A later link in a cannon chain waits its turn.
			flashes[i].delay -= delta
			if flashes[i].delay <= 0.0 and flashes[i].kind == "chain":
				_chain_burst(flashes[i])
			if flashes[i].delay <= 0.0 and flashes[i].kind in ["hit", "weapon_hit"]:
				_react_to_hit(flashes[i])
			continue
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
		for wolf in model.allies:
			if wolf.type == "wolf" and actors.has(wolf.id):
				actors[wolf.id].sulking = wolf.hp > 0 and model.reach_covers(wolf.cell)
				actors[wolf.id].sulk_flip = model.player.cell.x > wolf.cell.x
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not selected_item.is_empty() or inventory_ui.opened:
			inventory_ui.set_open(false)
			_cancel_item()
		elif not show_rules and not busy:
			var enemy := model.enemy_at(hover_cell)
			if enemy.is_empty():
				enemy = model.ally_at(hover_cell)  # allies can be pinned too
			selected_enemy_id = int(enemy.id) if not enemy.is_empty() and selected_enemy_id != int(enemy.id) else -2
			selected_weapon = -1
			show_history = false
			_update_controls()
		get_viewport().set_input_as_handled()

## Weapon slots 1-3 on the keyboard.
const WEAPON_KEYS := [KEY_J, KEY_K, KEY_L]

## The mouse wheel steps through the weapons (down: next, up: previous, round the three).
func _wheel_weapon(direction: int) -> void:
	var count: int = model.owned_weapons.size()
	if count < 2 or busy or show_rules or model.phase != Rules.Phase.PLAYER:
		return
	var at: int = model.owned_weapons.find(model.weapon)
	# Weapons with nowhere to go are stepped over.
	for step in range(1, count):
		var next: int = model.owned_weapons[posmod(at + direction * step, count)]
		if model.weapon_stuck_reason(next) == "":
			_equip(next)
			return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_wheel_weapon(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		return
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
		# Fairies are 1-3; weapons are J, K, L (and the mouse wheel).
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			inventory_ui.activate_slot(event.keycode-KEY_1)
			return
		if item_origin != Vector2i(-1,-1):
			var directions := {KEY_UP:Vector2i.UP,KEY_RIGHT:Vector2i.RIGHT,KEY_DOWN:Vector2i.DOWN,KEY_LEFT:Vector2i.LEFT}
			if directions.has(event.keycode):
				_choose_direction(directions[event.keycode])
				return
		if event.keycode == KEY_R:
			_start(model.level,true)
		elif WEAPON_KEYS.has(event.keycode):
			var slot: int = WEAPON_KEYS.find(event.keycode)
			if slot < model.owned_weapons.size():
				_equip(model.owned_weapons[slot])
		elif event.keycode == KEY_SPACE:
			_enemy_turn()

func _center(cell: Vector2i) -> Vector2:
	return BOARD+Vector2(cell)*TILE+Vector2.ONE*TILE/2

## Units bigger than one tile sit in the middle of their footprint.
func _unit_center(unit: Dictionary) -> Vector2:
	return _center(unit.cell)+Vector2.ONE*TILE/2*(int(unit.get("size",1))-1)

## Test hook: when set to an Array, every _text call is recorded as [position, text, size, width].
var text_audit = null

func _text(at: Vector2,text: String,size: int=20,color: Color=INK,font: Font=null) -> void:
	if text_audit != null:
		text_audit.append([at,text,size,_text_width(text,size)])
	draw_string(ui_font if font == null else font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

## `text` as lines no wider than `width`. A text that already fits keeps its own line breaks;
## otherwise its lines are joined up to each sentence end and re-wrapped, so no scrap of a
## word is left alone on a line.
func _wrap_lines(text: String, size: int, width: float) -> PackedStringArray:
	var own := text.split("\n")
	var fits := true
	for line in own:
		fits = fits and _text_width(line, size) <= width
	if fits:
		return own
	var sentences := PackedStringArray()
	var open_line := ""
	for line in own:
		open_line += line
		if line.ends_with("。") or line.ends_with("！") or line.ends_with("？"):
			sentences.append(open_line)
			open_line = ""
	if not open_line.is_empty():
		sentences.append(open_line)
	var rows := PackedStringArray()
	for sentence in sentences:
		var row := ""
		for index in sentence.length():
			var character := sentence[index]
			# A closing mark never starts a line: it hangs a little past the edge with its
			# character, which is never left alone either.
			var tail := character
			if index + 1 < sentence.length() and sentence[index + 1] in "。、）」！？":
				tail += sentence[index + 1]
			var allowed := width + (16.0 if tail.length() > 1 or character in "。、）」！？" else 0.0)
			if not row.is_empty() and _text_width(row + tail, size) > allowed and not character in "。、）」！？":
				rows.append(row)
				row = ""
			row += character
		rows.append(row)
	return rows

func _text_width(text: String, size: int) -> float:
	return ui_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x

func _panel(rect: Rect2) -> void:
	draw_rect(rect,Color("0b1415"))
	draw_rect(rect,Color("324843"),false,2)
	draw_rect(rect.grow(-5),Color("1d2c29"),false,1)
	for corner in [rect.position,rect.position+Vector2(rect.size.x-4,0),rect.end-Vector2(4,4),rect.position+Vector2(0,rect.size.y-4)]:
		draw_rect(Rect2(corner,Vector2(4,4)),Color("829081"))

const SHEATH_ART = preload("res://assets/sprites/spirits/sheath_fairy.png")
const SHEATH_ART_SWORD = preload("res://assets/sprites/spirits/sheath_fairy_sword.png")
const SHEATH_ART_HAMMER = preload("res://assets/sprites/spirits/sheath_fairy_hammer.png")

## The sheath fairy (layer 2): a separate slot below the fairy list holding one weapon out of the fight.
func _draw_sheath() -> void:
	if model.sheathed_weapon < 0:
		return
	var weapon: Dictionary = Rules.WEAPONS[model.sheathed_weapon]
	var art: Texture2D = SHEATH_ART_HAMMER if weapon.id == "hammer" else SHEATH_ART_SWORD
	_panel(Rect2(24,646,280,64))
	draw_texture_rect(art,Rect2(32,650,56,56),false)
	_text(Vector2(98,672),"鞘の妖精",16,Color("9aa7a3"))
	_text(Vector2(98,698),str(weapon.name),22,Color(weapon.color))

## An outline round the tiles each 2x2 enemy covers, so its whole body reads as one unit (not while it is
## under water).
func _draw_big_outlines() -> void:
	for enemy in model.enemies:
		if int(enemy.get("size",1)) < 2 or enemy.hp <= 0 or enemy.get("diving",false):
			continue
		var side: float = TILE * int(enemy.size)
		var rect := Rect2(BOARD + Vector2(enemy.cell) * TILE, Vector2.ONE * side)
		draw_rect(rect.grow(-2.0), Color(1.0, 0.5, 0.35, 0.10))
		draw_rect(rect.grow(-2.0), Color(1.0, 0.5, 0.35, 0.9), false, 3.0)

## A pop-up beside the cursor for the hazard tiles: the name, and what happens (the side panel says the same).
var hover_layer: Node2D
func _draw_hover_popup() -> void:
	if model != null and _shows_self_fairy_ghost():
		# The picked fairy hovers at your shoulder, breathing: pressing yourself uses it.
		var item: Resource = model.item_definition(selected_item)
		var side := TILE * 0.7
		var at := _center(model.player.cell) + Vector2(TILE * 0.3, -TILE * 0.38 + 4.0 * sin(clock * 3.0))
		hover_layer.draw_texture_rect(item.icon, Rect2(at - Vector2.ONE * side / 2.0, Vector2.ONE * side), false, Color(1, 1, 1, 0.8 + 0.15 * sin(clock * 4.0)))
	if model == null or model.phase != Rules.Phase.PLAYER or busy or show_rules or not model.inside(hover_cell):
		return
	var info := _hazard_at(hover_cell)
	if info.is_empty():
		return
	var canvas := hover_layer
	var color: Color = info.get("color", Color("ff5b62"))
	var lines: Array = []
	if str(info.get("state","")) != "":
		lines.append(str(info.state))
	lines.append_array(info.lines)
	var width := 300.0
	var height := 52.0 + lines.size() * 26.0
	var cell_rect := Rect2(BOARD + Vector2(hover_cell) * TILE, Vector2.ONE * TILE)
	var at := Vector2(cell_rect.end.x + 10.0, cell_rect.position.y)
	if at.x + width > 1128.0:
		at.x = cell_rect.position.x - 10.0 - width
	at.y = clampf(at.y, 90.0, 700.0 - height)
	canvas.draw_rect(Rect2(at + Vector2(4, 5), Vector2(width, height)), Color(0, 0, 0, 0.45))
	canvas.draw_rect(Rect2(at, Vector2(width, height)), Color(0.04, 0.08, 0.1, 0.96))
	canvas.draw_rect(Rect2(at, Vector2(width, height)), color, false, 3.0)
	canvas.draw_string(ui_font, at + Vector2(14, 31), str(info.title), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, color)
	var y := at.y + 58.0
	for line in lines:
		canvas.draw_string(ui_font, Vector2(at.x + 14, y + 14), str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
		y += 26.0

func _draw() -> void:
	if hover_layer == null:
		hover_layer = Node2D.new()
		hover_layer.z_index = 7
		add_child(hover_layer)
		hover_layer.draw.connect(_draw_hover_popup)
	hover_layer.queue_redraw()
	draw_rect(Rect2(0,0,1152,720),Color("070b0d"))
	for x in range(0,1152,24):
		draw_line(Vector2(x,0),Vector2(x,720),Color("0d1718"))
	for y in range(0,720,24):
		draw_line(Vector2(0,y),Vector2(1152,y),Color("0d1718"))
	_panel(Rect2(24,24,1104,58))
	var stage_title := "最終決戦" if model.level == Rules.FINAL_LEVEL else "ボス戦" if Rules.BOSS_LEVELS.has(model.level) else "中盤 %d / 3" % (Rules.MID_LEVELS.find(model.level)+1) if Rules.MID_LEVELS.has(model.level) else "終盤 %d / 4" % (Rules.LATE_LEVELS.find(model.level)+1) if Rules.LATE_LEVELS.has(model.level) else "戦闘 %d / 3" % (model.level+1)
	if model.layer2_board:
		stage_title = "2層目"
	_text(Vector2(44,62),stage_title,25,Color("ff8b8f") if Rules.BOSS_LEVELS.has(model.level) else CYAN)
	_text(Vector2(260,62),"ターン %02d" % model.round_number,23)
	_text(Vector2(480,62),"敵 残り %d" % model.enemies.size(),23)
	_draw_sheath()
	_draw_board()
	_draw_big_outlines()
	_draw_storm_frame()
	_draw_player_panel()
	_draw_weapons()
	_draw_intel()
	_draw_flashes()
	_draw_shark_title()
	var turn_text := "敵のターン" if busy and model.phase==Rules.Phase.ENEMY else "あなたのターン"
	if model.board_size >= 8:
		# The 8x8 board reaches up here, so the turn label moves into the player panel.
		_text(Vector2(40,208),turn_text,22,CYAN if not busy else GOLD)
	else:
		_text(Vector2(352,126),turn_text,27,CYAN if not busy else GOLD)
	if model.abyss_turns > 0:
		_text(Vector2(40,262) if model.board_size >= 8 else Vector2(352,156),"奈落 あと%dターン" % model.abyss_turns,18,Color("b8a8ff"))

	if selected_item == "gravity_fairy" and model.item_targets("gravity_fairy").has(hover_cell) and not busy:
		_text(Vector2(36,673),"引き寄せる（攻撃範囲）" if model.gravity_pulls(hover_cell) else "弾く（攻撃範囲外）",23,GRAVITY_PULL if model.gravity_pulls(hover_cell) else GRAVITY_PUSH)
	elif model.can_swap_shadow(hover_cell) and selected_item.is_empty() and not busy:
		_text(Vector2(36,673),"影と入れ替わる %d AP" % model.shadow_swap_cost(),23,CYAN)
	elif model.inside(hover_cell) and model.targets().has(hover_cell) and selected_item.is_empty() and not busy:
		_text(Vector2(36,673),"移動 1 AP" if model.enemy_at(hover_cell).is_empty() else "攻撃 1 AP",23,GOLD)
	if model.terminal() and not busy:
		_draw_result()

func _draw_board() -> void:
	var extent := Vector2.ONE*model.board_size*TILE
	# The 8x8 board sits flush between the panels, so its frame is thinner.
	var rim := 4.0 if model.board_size >= 8 else 10.0
	var frame := Rect2(BOARD-Vector2.ONE*rim,extent+Vector2.ONE*rim*2)
	var casino: bool = model.enemies.any(func(e: Dictionary) -> bool: return e.type == "slot" and e.hp > 0)
	if casino:
		_draw_casino_frame(frame)
	else:
		draw_rect(frame,Color("252820"))
		_draw_field_frame(frame)
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
		if Catalog.is_hammer(model.weapon) and model.targets().has(hover_cell) and not model.enemy_at(hover_cell).is_empty():
			hammer_zone = model.hammer_area(hover_cell)
		elif Catalog.is_dagger(model.weapon) and model.combo_boost == model.weapon and model.targets().has(hover_cell) and not model.enemy_at(hover_cell).is_empty():
			# クロス短剣, boosted by its pair: the blow also lands on the four diagonal tiles round the target.
			for side in Rules.DIAGONALS:
				if model.inside(hover_cell + side):
					hammer_zone.append(hover_cell + side)
		elif Rules.WEAPONS[model.weapon].id == "bow":
			bow_zone = model.bow_lines()
	# Hovering an enemy shows where it could step with one AP.
	var step_zone: Array[Vector2i] = []
	if model.phase == Rules.Phase.PLAYER and not busy and not show_rules and selected_item.is_empty() and not inventory_ui.opened and hammer_zone.is_empty():
		step_zone = _enemy_step_cells(model.enemy_at(hover_cell))
	# A hovered javelin thrower shows where its spears land (in red).
	var javelin_zone: Array[Vector2i] = []
	if model.phase == Rules.Phase.PLAYER and not busy and not show_rules and selected_item.is_empty() and not inventory_ui.opened:
		var thrower: Dictionary = model.enemy_at(hover_cell)
		if not thrower.is_empty() and thrower.type == "javelin":
			javelin_zone = model.javelin_cells(thrower)
	# Slash spirit: hovering a legal tile shows the two tiles it will cut.
	var slash_zone: Array[Vector2i] = []
	if selected_item == "slash_fairy" and model.item_targets("slash_fairy").has(hover_cell):
		slash_zone = model.side_slash_cells(hover_cell)
		if not model.enemy_at(hover_cell).is_empty():
			slash_zone.append(hover_cell)
	# 氷結妖精 / 加護の妖精: hovering a legal tile shows the square they cover.
	if selected_item in ["freeze_fairy", "blessing_fairy", "cat_fairy"] and model.item_targets(selected_item).has(hover_cell):
		var radius := Rules.CAT_RADIUS if selected_item == "cat_fairy" else 2 if selected_item == "blessing_fairy" and model.is_plus("blessing_fairy") else 1
		slash_zone = model.square_around(hover_cell, radius)
	# Magic circle: hovering a move shows the area it would close.
	var circle_zone: Array[Vector2i] = []
	if model.is_circle(model.weapon) and model.phase == Rules.Phase.PLAYER and not busy and selected_item.is_empty() and model.targets().has(hover_cell) and model.enemy_at(hover_cell).is_empty() and not model.blocked(hover_cell):
		circle_zone = model.circle_preview(hover_cell)
	# The storm shark: the shadow it dives under, and where the lightning is marked.
	var dive_cells: Array = []
	var dive_core: Array = []
	for enemy in model.enemies:
		if enemy.get("diving", false) and enemy.hp > 0:
			dive_cells.append_array(enemy.dive_area)
			dive_core.append_array(model.footprint({"cell":enemy.dive_anchor, "size":2}))
	var storm_marks: Array = model.storm.get("marks", [])
	var storm_groups: Array = model.storm.get("groups", [])
	var danger: Array[Vector2i] = []
	for enemy in model.enemies:
		if enemy.hp > 0 and enemy.get("state","") == "aim":
			danger.append_array(model.archer_lane(enemy))
		elif enemy.hp > 0 and enemy.type in Rules.CHARGERS and enemy.get("state","") == "brace":
			danger.append_array(model.rook_lane(enemy))
	for y in range(model.board_size):
		for x in range(model.board_size):
			var cell := Vector2i(x,y)
			if model.holes.has(cell):
				continue
			# Each tile is drawn in its own 64-unit space, scaled down on big boards.
			draw_set_transform(BOARD+Vector2(cell)*TILE,0,Vector2.ONE*TILE/64.0)
			var pos := Vector2.ZERO
			var mid := Vector2(32,32)
			var base := Color("4a5a60") if model.storm_active() else Color("665b48")
			var shade := 0.88+float((x*13+y*7)%5)*0.025
			if casino:
				_draw_casino_tile(x,y)
			elif model.level == Rules.FINAL_LEVEL:
				# The prison's flagstones, and the throne dais under the king.
				draw_texture_rect(BOSS_THRONE if throne_cells.has(cell) else BOSS_FLOOR,Rect2(pos,Vector2(64,64)),false,Color(shade,shade,shade))
			else:
				draw_rect(Rect2(pos+Vector2(2,2),Vector2(60,60)),base*shade)
			if not casino:
				draw_line(pos+Vector2(3,59),pos+Vector2(59,59),Color("38362a"),2)
				draw_line(pos+Vector2(3,3),pos+Vector2(59,3),Color("766b54"),1)
				if (x*3+y)%4==0:
					draw_line(pos+Vector2(39,4),pos+Vector2(34,13),Color("494535"),2)
			if bow_zone.has(cell):
				draw_circle(pos+Vector2(32,32),5,Color("b7e07a",0.55))
			if javelin_zone.has(cell):
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),Color("ff805a",0.25))
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),Color("ff805a",0.9),false,3)
				draw_line(pos+Vector2(22,22),pos+Vector2(42,42),Color("ff805a"),3)
				draw_line(pos+Vector2(22,42),pos+Vector2(42,22),Color("ff805a"),3)
			if step_zone.has(cell):
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),Color(CYAN,0.22))
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),Color(CYAN,0.85),false,2)
			if slash_zone.has(cell):
				var zone_color: Color = model.item_definition(selected_item if selected_item != "" else "slash_fairy").color
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),Color(zone_color,0.3))
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),zone_color,false,3)
			if model.blessed(cell):
				# 加護の地: warm gold ground, brighter while the player stands in it.
				var lit := 0.16 + (0.08 if model.blessed(model.player.cell) else 0.0) + 0.04 * sin(clock * 2.5 + x + y)
				draw_rect(Rect2(pos+Vector2(2,2),Vector2(60,60)),Color(1,0.86,0.45,lit))
				draw_rect(Rect2(pos+Vector2(2,2),Vector2(60,60)),Color(1,0.86,0.45,0.5),false,1)
			if dive_cells.has(cell):
				# Where the shark will come up: every tile is a red warning, the tiles its body lands on the worst.
				var core: bool = dive_core.has(cell)
				var throb := 0.5 + 0.5 * sin(clock * (11.0 if core else 7.0) + (0.0 if core else x * 0.9 + y * 0.9))
				draw_rect(Rect2(pos+Vector2(2,2),Vector2(60,60)),Color(1.0,0.1,0.15,(0.45 if core else 0.3)+0.25*throb))
				draw_rect(Rect2(pos+Vector2(2,2),Vector2(60,60)),Color(1.0,0.3,0.3,0.7+0.3*throb),false,5 if core else 3)
				# A red "!" on each tile (the bar and the dot), bolder on the landing tiles.
				var mark_color := Color(1.0,0.2,0.22,0.8+0.2*throb) if core else Color(1.0,0.4,0.4,0.55+0.4*throb)
				var bar_w := 9.0 if core else 6.0
				draw_rect(Rect2(pos+Vector2(32.0-bar_w/2.0,14),Vector2(bar_w,24)),mark_color)
				draw_rect(Rect2(pos+Vector2(32.0-bar_w/2.0,43),Vector2(bar_w,bar_w)),mark_color)
				if core:
					draw_rect(Rect2(pos+Vector2(32.0-bar_w/2.0,14),Vector2(bar_w,24)),Color(0.3,0.0,0.03,0.9),false,1.5)
					draw_rect(Rect2(pos+Vector2(32.0-bar_w/2.0,43),Vector2(bar_w,bar_w)),Color(0.3,0.0,0.03,0.9),false,1.5)
			if storm_marks.has(cell):
				# Lightning is coming: the tiles of the bolt glow, and only the bolt's outline is drawn.
				var flick := 0.34 + 0.14 * sin(clock * 12.0 + x * 1.7 + y)
				var bolt: Array = []
				var bolt_index := 0
				for group_index in storm_groups.size():
					if storm_groups[group_index].has(cell):
						bolt = storm_groups[group_index]
						bolt_index = group_index
				# Each bolt a slightly different yellow, so touching ones still read apart.
				var tints := [Color(1.0,0.93,0.35), Color(1.0,0.75,0.3), Color(0.95,1.0,0.5), Color(1.0,0.85,0.55)]
				draw_rect(Rect2(pos,Vector2(64,64)),Color(tints[bolt_index % 4],flick))
				# Every tile is its own danger: a thin square border and a bolt sign that pulses, offset tile by tile.
				var beat := 0.5 + 0.5 * sin(clock * 9.0 + x * 1.3 + y * 2.1)
				draw_rect(Rect2(pos+Vector2(4,4),Vector2(56,56)),Color(1.0,0.9,0.3,0.55+0.3*beat),false,2)
				var sign_points := PackedVector2Array([pos+Vector2(37,11),pos+Vector2(21,36),pos+Vector2(31,36),pos+Vector2(26,54),pos+Vector2(44,27),pos+Vector2(34,27)])
				draw_colored_polygon(sign_points,Color(1.0,0.97,0.45,0.5+0.4*beat))
				draw_polyline(sign_points+PackedVector2Array([sign_points[0]]),Color(0.35,0.2,0.0,0.85),1.5)
				var edge := Color(1.0,0.97,0.6,0.98)
				for side in [[Vector2i.UP,pos+Vector2(0,1),pos+Vector2(64,1)],[Vector2i.DOWN,pos+Vector2(0,63),pos+Vector2(64,63)],[Vector2i.LEFT,pos+Vector2(1,0),pos+Vector2(1,64)],[Vector2i.RIGHT,pos+Vector2(63,0),pos+Vector2(63,64)]]:
					if not bolt.has(cell + side[0]):
						draw_line(side[1],side[2],edge,4)
			if model.cat_zone_at(cell):
				# 猫の妖精's field: yellow-green ground, with a slow glow.
				var glow := 0.15 + 0.05 * sin(clock * 2.0 + x * 0.7 + y * 0.7)
				draw_rect(Rect2(pos+Vector2(2,2),Vector2(60,60)),Color(0.71,0.88,0.29,glow))
				draw_rect(Rect2(pos+Vector2(2,2),Vector2(60,60)),Color(0.8,1.0,0.4,0.55),false,1)
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
			var zone_index := _mini_zone_of(cell)
			if zone_index >= 0:
				_draw_mini_zone_tile(cell, zone_index)
			if model.floor_cells.has(cell):
				# A burning floor (reel 4, or the drawn strip): a loud red-and-black checker, a
				# pulsing white-hot border and a "!" so it still reads under the casino lights.
				var beat := 0.5 + 0.5 * sin(clock * 9.0)
				for q in range(4):
					var sub := Rect2(pos+Vector2(3+(q%2)*29,3+(q/2)*29),Vector2(29,29))
					draw_rect(sub,Color(1.0,0.12,0.08,0.92) if (q%2)==(q/2) else Color(0.1,0.0,0.0,0.92))
				draw_rect(Rect2(pos+Vector2(3,3),Vector2(58,58)),Color(1.0,0.95-0.55*beat,0.8-0.7*beat),false,4)
				draw_rect(Rect2(pos+Vector2(1,1),Vector2(62,62)),Color(1.0,0.15,0.1,0.35+0.35*beat),false,2)
				_text(pos+Vector2(26,44),"!",34,Color(1,1,1,0.55+0.4*beat))
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
				var combo := _combo_color()
				if combo.a > 0.0:
					# The dagger the last one powered up: this tile glows in its colour.
					UnitView.draw_frame_fire(self,Rect2(pos+Vector2(2,2),Vector2(60,60)),combo)
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
			if model.wheel_cell() == cell:
				# The wheel turns under whoever rides it.
				SpiritIcon.paint(self,mid + (Vector2(-5, 8) if model.riding_wheel() else Vector2.ZERO),model.item_definition("wheel_fairy").icon,0.9)
				_turn_badge(pos,int(model.wheel.turns))
			for field in model.cats:
				if field.cell == cell:
					SpiritIcon.paint(self,mid,model.item_definition("cat_fairy").icon,1.1)
					_turn_badge(pos,int(field.turns))
			if model.blessing.get("cell",Vector2i(-1,-1)) == cell:
				SpiritIcon.paint(self,mid,model.item_definition("blessing_fairy").icon,0.9)
				_turn_badge(pos,int(model.blessing.turns))
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
	_draw_shove_preview()
	# The big numbers written on Rotorick's three floor blocks (over the tiles, under the units).
	for k in model.mini_zones.size():
		var box := _mini_zone_rect(k)
		var drawn_zone := _mini_drawn() == k + 1
		var glyph_color := Color("ff5b62") if drawn_zone else Color("62e4ff")
		var glyph_size := 112
		var glyph_width := _text_width(str(k+1),glyph_size)
		var glyph_at := box.get_center() + Vector2(-glyph_width / 2.0, glyph_size * 0.34)
		# A neon glow: the number again, wider and fainter, under the sharp one.
		for halo in [Vector2(-3,0), Vector2(3,0), Vector2(0,-3), Vector2(0,3)]:
			_text(glyph_at + halo,str(k+1),glyph_size,Color(glyph_color,0.22))
		_text(glyph_at + Vector2(3,3),str(k+1),glyph_size,Color(0,0,0,0.55))
		_text(glyph_at,str(k+1),glyph_size,Color(glyph_color,0.95 if drawn_zone else 0.75))
		if drawn_zone:
			# A targeting reticle turning around the drawn number.
			var reticle := minf(box.size.x,box.size.y) * 0.46
			for q in range(4):
				var start := clock * 1.6 + q * TAU / 4.0
				draw_arc(box.get_center(), reticle, start, start + 0.9, 10, Color("ff5b62", 0.9), 3, true)
	_draw_king_barrier()
	_draw_mini_slot_badge()
	_draw_reel_badge()
	# Before a 2x2 fairy is placed, hovering a legal tile shows the block it would take.
	# 2x2 fairies are drawn after the tiles so no later tile covers them.
	if model.time_stopped():
		_draw_time_stop_board()
	if Rules.BIG_FAIRIES.has(selected_item):
		if item_origin != Vector2i(-1,-1):
			_draw_big_ghost(item_origin,aim)
		elif model.item_targets(selected_item).has(hover_cell):
			_draw_big_ghost(hover_cell,Vector2i.RIGHT)
	elif _shows_self_fairy_ghost():
		# A fairy used on yourself: a dashed ring round your own tile (its silhouette floats over you, drawn
		# on the layer above the units: see _draw_hover_popup).
		var self_item: Resource = model.item_definition(selected_item)
		var self_middle := _center(model.player.cell)
		_dashed_rect(Rect2(self_middle - Vector2.ONE * (TILE / 2.0 - 4.0), Vector2.ONE * (TILE - 8.0)), self_item.color, 3)
	elif _shows_fairy_ghost():
		# A fairy about to be put down: its silhouette on the tile under the cursor (the way the 2x2
		# fairies show theirs), so it reads that a fairy is picked.
		var item: Resource = model.item_definition(selected_item)
		var middle := _center(hover_cell)
		var side := TILE * 0.95
		_dashed_rect(Rect2(middle - Vector2.ONE * (TILE / 2.0 - 4.0), Vector2.ONE * (TILE - 8.0)), item.color, 3)
		draw_texture_rect(item.icon, Rect2(middle - Vector2.ONE * side / 2.0, Vector2.ONE * side), false, Color(1, 1, 1, 0.72))
	if item_origin != Vector2i(-1,-1):
		if selected_item == "vane_cannon":
			_draw_turn_hint(_center(item_origin),aim)
		var start := _center(item_origin)
		var end := start+Vector2(aim)*28
		draw_line(start,end,GOLD,5)
		var side := Vector2(-aim.y,aim.x)*8
		draw_colored_polygon(PackedVector2Array([end+Vector2(aim)*8,end-Vector2(aim)*7+side,end-Vector2(aim)*7-side]),GOLD)

## 時の妖精: while time stands still (the colour is drained by the overlay) a still clock
## face behind it whose second hand trembles but never moves on.
const TIME_GOLD := Color("ffcf52")
func _draw_time_stop_board() -> void:
	var extent := Vector2.ONE*model.board_size*TILE
	_draw_clock_face(BOARD+extent/2,extent.x*0.36,Color(TIME_GOLD,0.22),0.0)

## A clock face: ring, twelve ticks and two hands (the long one at `turn` of a revolution).
func _draw_clock_face(center: Vector2, radius: float, color: Color, turn: float) -> void:
	draw_arc(center,radius,0,TAU,64,color,4,true)
	for k in 12:
		var a := k*TAU/12
		draw_line(center+Vector2.from_angle(a)*radius*0.86,center+Vector2.from_angle(a)*radius*(0.96 if k % 3 else 1.0),color,3 if k % 3 == 0 else 2)
	var tremble := sin(clock*40.0)*0.012
	draw_line(center,center+Vector2.from_angle(-PI/2+TAU*(turn+tremble))*radius*0.78,color,3)
	draw_line(center,center+Vector2.from_angle(-PI/2+TAU*0.33)*radius*0.5,color,5)

## The battlefield's outer frame: a clear light-blue line with a soft glow outside it,
## brighter corner brackets and a faint inner line, breathing very slowly. The 8x8
## and larger boards sit flush between the panels, so there it keeps inside its rim.
const FIELD_BLUE := Color("7fe6ff")
## Rotorick's floor: dark glass tiles in a violet checker, a neon grid, a faint inner glow.
func _draw_casino_tile(x: int, y: int) -> void:
	var even := (x + y) % 2 == 0
	var floor_color := Color("1a1030") if even else Color("120a24")
	draw_rect(Rect2(Vector2(2,2),Vector2(60,60)),floor_color)
	# Glassy sheen across the top, a soft pulse that runs diagonally over the whole floor.
	draw_rect(Rect2(Vector2(2,2),Vector2(60,22)),Color(1,1,1,0.035))
	var wave := 0.5 + 0.5 * sin(clock * 1.4 - float(x + y) * 0.6)
	draw_rect(Rect2(Vector2(2,2),Vector2(60,60)),Color(0.55,0.2,0.9,0.05 + 0.07 * wave))
	var neon := Color("ff4fd8") if even else Color("46d9ff")
	draw_rect(Rect2(Vector2(2.5,2.5),Vector2(59,59)),Color(neon,0.45),false,1)
	# Little corner ticks, like a circuit board.
	for corner in [Vector2(3,3), Vector2(61,3), Vector2(3,61), Vector2(61,61)]:
		var sx := 1.0 if corner.x < 32.0 else -1.0
		var sy := 1.0 if corner.y < 32.0 else -1.0
		draw_line(corner, corner + Vector2(sx * 7.0, 0), Color(neon, 0.9), 2)
		draw_line(corner, corner + Vector2(0, sy * 7.0), Color(neon, 0.9), 2)

## Rotorick's board frame: a heavy dark bezel with a gold line and a neon line, rivets, and
## ornate corner brackets.
func _draw_casino_frame(frame: Rect2) -> void:
	var outer := frame.grow(8.0)
	draw_rect(outer.grow(3.0),Color(0,0,0,0.6))
	draw_rect(outer,Color("0c0614"))
	draw_rect(outer,Color("3a2a52"),false,2)
	draw_rect(frame.grow(5.0),Color("1b1030"))
	draw_rect(frame.grow(5.0),Color("ffd35b"),false,2)
	draw_rect(frame.grow(1.0),Color("ff4fd8"),false,2)
	draw_rect(frame.grow(-1.0),Color(0.6,0.9,1.0,0.5),false,1)
	# Rivets between the bulbs.
	var gap := 32.0
	var x := frame.position.x + gap / 2.0
	while x < frame.end.x:
		for y in [outer.position.y + 3.0, outer.end.y - 3.0]:
			draw_circle(Vector2(x,y),1.6,Color("a98fd0"))
		x += gap
	var y_at := frame.position.y + gap / 2.0
	while y_at < frame.end.y:
		for x_at in [outer.position.x + 3.0, outer.end.x - 3.0]:
			draw_circle(Vector2(x_at,y_at),1.6,Color("a98fd0"))
		y_at += gap
	# Corner brackets: gold L plates with a magenta gem.
	for corner: Vector2 in [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]:
		var sx := 1.0 if corner.x <= outer.get_center().x else -1.0
		var sy := 1.0 if corner.y <= outer.get_center().y else -1.0
		draw_line(corner + Vector2(-sx * 2.0, 0), corner + Vector2(sx * 34.0, 0), Color("ffd35b"), 6)
		draw_line(corner + Vector2(0, -sy * 2.0), corner + Vector2(0, sy * 34.0), Color("ffd35b"), 6)
		draw_line(corner + Vector2(sx * 3.0, sy * 3.0), corner + Vector2(sx * 28.0, sy * 3.0), Color("8a6a1c"), 2)
		draw_line(corner + Vector2(sx * 3.0, sy * 3.0), corner + Vector2(sx * 3.0, sy * 28.0), Color("8a6a1c"), 2)
		var gem: Vector2 = corner + Vector2(sx * 8.0, sy * 8.0)
		draw_colored_polygon(PackedVector2Array([gem + Vector2(0,-6), gem + Vector2(6,0), gem + Vector2(0,6), gem + Vector2(-6,0)]), Color("ff4fd8"))
		draw_polyline(PackedVector2Array([gem + Vector2(0,-6), gem + Vector2(6,0), gem + Vector2(0,6), gem + Vector2(-6,0), gem + Vector2(0,-6)]), Color.WHITE, 1)

func _draw_field_frame(frame: Rect2) -> void:
	var breath := 0.85 + 0.15 * sin(clock * 1.6)
	var compact := model.board_size >= 8
	if compact:
		frame = frame.grow(-2.0)
	else:
		for k in 4:
			draw_rect(frame.grow(2.0 + k * 3.0), Color(FIELD_BLUE, (0.2 - k * 0.045) * breath), false, 3)
	draw_rect(frame, Color(FIELD_BLUE, 0.95), false, 3)
	draw_rect(frame.grow(-5.0), Color(FIELD_BLUE, 0.22), false, 1)
	var arm := 18.0 if compact else 26.0
	var bright := Color("d8f8ff")
	for corner in [frame.position, Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]:
		var sx := 1.0 if corner.x <= frame.get_center().x else -1.0
		var sy := 1.0 if corner.y <= frame.get_center().y else -1.0
		var tip: Vector2 = corner + Vector2(-sx, -sy) * (0.0 if compact else 3.0)
		draw_line(tip, tip + Vector2(sx * arm, 0), bright, 5)
		draw_line(tip, tip + Vector2(0, sy * arm), bright, 5)
		if not compact:
			draw_rect(Rect2(tip - Vector2.ONE * 3.5, Vector2.ONE * 7), bright)

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

## Before a shoving attack: arrows to where each enemy would be pushed, a red burst
## where it would slam into something, and "+1" over every enemy the collision hurts.
func _draw_shove_preview() -> void:
	var busy := not model.events.is_empty() and _chain_time() > 0.0
	if not selected_item.is_empty() or busy or Catalog.knockback(model.weapon) <= 0 or not model.targets().has(hover_cell) or model.enemy_at(hover_cell).is_empty():
		shove_preview = {}
		return
	var key := str([hover_cell, model.weapon, model.player.cell, model.enemies.map(func(e: Dictionary) -> Array: return [e.cell, e.hp]), model.walls.keys()])
	if shove_preview.get("key", "") != key:
		var sim: RefCounted = model.clone()
		sim.events.clear()
		sim.player_action(hover_cell)
		var moves: Array = []
		var hurt: Array = []
		for enemy in model.enemies:
			for other in sim.enemies:
				if other.id == enemy.id and other.cell != enemy.cell:
					moves.append([enemy, other.cell])
		var bumps: Array = []
		for event in sim.events:
			if event.kind == "bump" and event.get("hurt", true):
				bumps.append([event.cell, event.dir])
			if event.kind == "hit" and event.get("bump", false):
				for enemy in model.enemies:
					if enemy.id == event.id and not hurt.has(enemy):
						hurt.append(enemy)
		shove_preview = {"key": key, "moves": moves, "bumps": bumps, "hurt": hurt}
	for move in shove_preview.moves:
		var from := _unit_center(move[0])
		var to := _unit_center({"cell": move[1], "size": int(move[0].get("size", 1))})
		draw_line(from, to, Color(1, 1, 1, 0.85), 4)
		_draw_arrow(to, (to - from).normalized(), Color.WHITE)
	var pulse := 0.7 + 0.3 * sin(clock * 9.0)
	for bump in shove_preview.bumps:
		var at := _center(bump[0]) + Vector2(bump[1]) * TILE * 0.5
		draw_circle(at, 15, Color(0.1, 0.02, 0.02, 0.7))
		for k in 10:
			var ray := Vector2.from_angle(k * TAU / 10 + 0.2) * (20.0 if k % 2 == 0 else 11.0) * (0.85 + 0.15 * pulse)
			draw_line(at, at + ray, Color(1, 0.22, 0.18, pulse), 4)
		draw_circle(at, 6, Color(1, 0.92, 0.85, pulse))
	for enemy in shove_preview.hurt:
		var over := _unit_center(enemy) + Vector2(-30, -16)
		draw_string_outline(ui_font, over, "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color("140806"))
		draw_string(ui_font, over, "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.35, 0.3))

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
	# Two boxes; a rider on the wheel has three (narrower so they still fit).
	var ap_boxes := maxi(maxi(2, model.player.ap), 3 if model.riding_wheel() else 2)
	var box_w := 84.0 if ap_boxes == 2 else 56.0
	var box_step := 96.0 if ap_boxes == 2 else 66.0
	for i in range(ap_boxes):
		draw_rect(Rect2(94+i*box_step,137,box_w,29),GOLD if i<model.player.ap else Color("293d36"))

## クロス短剣: the colour of the dagger the last one powered up (clear when none is).
func _combo_color() -> Color:
	if model.combo_boost < 0 or model.combo_boost >= Rules.WEAPONS.size():
		return Color(0, 0, 0, 0)
	return Color(Rules.WEAPONS[model.combo_boost].color)

## The powered-up dagger's slot takes on its own aura: tongues of light and sparks rising inside it.
func _draw_slot_aura(rect: Rect2, color: Color) -> void:
	UnitView.draw_frame_fire(self, rect.grow(SLOT_FRAME - 1), color)

func _draw_weapons() -> void:
	# The 7x7 boss board reaches down to this line, so the header gives way to it.
	if model.board_size < 7:
		_text(Vector2(352,605),"武器  %d / 3" % model.owned_weapons.size(),23,INK)
		# Shrinks to fit left of the info panel (it used to run under it).
		var swap_hint := "別の武器＝範囲変更／同じ武器＝妖精をやめる" if not selected_item.is_empty() else "タップ・JKL・ホイールで装備 0AP"
		var hint_size := 18
		while hint_size > 13 and _text_width(swap_hint,hint_size) > 268:
			hint_size -= 1
		_text(Vector2(555,605),swap_hint,hint_size,MUTED)
	for slot in range(model.owned_weapons.size()):
		var index: int = model.owned_weapons[slot]
		var weapon: Dictionary = Rules.WEAPONS[index]
		var pos := Vector2(352+slot*260,620)
		var rect := Rect2(pos,Vector2(248,94))
		var accent := Color(weapon.color)
		var equipped: bool = model.weapon == index
		draw_rect(rect,Color("1b3431") if equipped else Color("0b1415"))
		var circle: bool = model.is_circle(index)
		# The frame in the weapon's rarity material; the equipped one is lit and ringed
		# inside in its colour.
		RarityFrame.paint(self, rect, Rarity.tier({"kind":"weapon","value":index,"enchant":"circle" if circle else ""}), clock, SLOT_FRAME, equipped)
		if equipped:
			draw_rect(rect.grow(-SLOT_FRAME-1),accent,false,2)
		_text(pos+Vector2(13,30),str(slot+1),15,MUTED)
		# The equipped marker is drawn: the pixel font has no ▶ glyph (tofu on the Web).
		var label: String = weapon.name
		var label_x := 28.0
		if equipped:
			var tip := pos+Vector2(28,31)
			draw_colored_polygon(PackedVector2Array([tip+Vector2(0,-8),tip+Vector2(12,0),tip+Vector2(0,8)]),accent)
			label_x = 46.0
		var forged: bool = model.weapon_power.has(index)
		var extras: Array[String] = []
		# Swap weapons trade places instead of dealing damage.
		extras.assign(["魔法陣","攻撃不可"] if circle else ["入替・初回0AP" if forged and not model.free_swap_used else "無傷で入替"] if weapon.get("swap",false) else ["攻撃%d" % model.weapon_damage(index)])
		if weapon.get("knockback",0) > 0:
			# Knockback weapons deal no damage of their own (until forged).
			if model.weapon_damage(index) <= 0:
				extras.clear()
			extras.append("ノックバック")
		if weapon.get("pull",false):
			extras.append("引寄")

		if weapon.has("charge"):
			extras.append("溜め%d/%d" % [model.blade_charge, model.blade_max()])
		if model.combo_boost == index:
			extras.append("強化中")
			_draw_slot_aura(rect.grow(-SLOT_FRAME), accent)
		# Same picture as the reward cards: outlined tiles with a dot on each reachable one.
		var offsets := model.weapon_offsets(index)
		var echo := Catalog.hammer_echo(index, model.weapon_power.has(index))
		var strikes := Catalog.attack_offsets(index, model.weapon_power.has(index))
		var count := RangeDiagram.span(offsets + echo)
		# Inside the frame; sliding weapons leave room for their arrows past the tiles.
		var inner := 94.0-SLOT_FRAME*2-4
		var arrow := 0.0 if Catalog.slides(index).is_empty() else 1.0
		var side := inner*count/(count+arrow*2)
		var cell_size := side/count
		var origin := pos+Vector2(248-SLOT_FRAME-2-side-arrow*cell_size,SLOT_FRAME+2+arrow*cell_size)
		# The name (and its +) steps down in size rather than run into the diagram.
		var name_size := 22
		var name_room := origin.x - arrow * cell_size - 6.0 - (pos.x + label_x)
		while name_size > 14 and _text_width(label, name_size) + (name_size if forged else 0) > name_room:
			name_size -= 1
		_text(pos+Vector2(label_x,38),label,name_size,accent)
		if forged:
			_text(pos+Vector2(label_x+2+_text_width(label,name_size),38),"+",name_size,GOLD)
		# The stats line stops short of the diagram (a forged knockback weapon's is long).
		var stats := "・".join(extras)
		var stats_size := 16
		while stats_size > 11 and pos.x+14+_text_width(stats,stats_size) > origin.x-arrow*cell_size-4:
			stats_size -= 1
		var boosted_now: bool = model.combo_boost == index and Catalog.is_dagger(index)
		if boosted_now:
			# The raised damage is the point of the boost: bright, pulsing, with an arrow.
			var beat := 0.5 + 0.5 * sin(clock * 6.0)
			stats = "▲" + stats
			_text(pos+Vector2(14,72),stats,stats_size,Color(accent.lightened(0.45 + 0.3 * beat), 1.0))
		else:
			_text(pos+Vector2(14,72),stats,stats_size,Color("ff7ae6") if circle else GOLD if model.weapon_damage(index) > 1 else MUTED)
		for y in range(count):
			for x in range(count):
				var offset := Vector2i(x-count/2,y-count/2)
				var tile := Rect2(origin+Vector2(x,y)*cell_size+Vector2.ONE,Vector2.ONE*(cell_size-2))
				var active := offsets.has(offset)
				var striking := strikes.has(offset)
				var tone: Color = Color("ff805a") if striking else accent
				draw_rect(tile,Color(tone,0.3) if active else Color("172627"))
				if echo.has(offset) and not active:
					_hatch(tile, HAMMER_ECHO)
				draw_rect(tile,tone if active else HAMMER_ECHO if echo.has(offset) else Color("3d5753"),false,1)
				if striking:
					var mid := tile.get_center()
					var arm := cell_size * 0.2
					draw_line(mid - Vector2(arm, arm), mid + Vector2(arm, arm), tone, 2)
					draw_line(mid - Vector2(arm, -arm), mid + Vector2(arm, -arm), tone, 2)
				if offset == Vector2i.ZERO:
					_draw_player_portrait(index,tile.get_center(),cell_size*1.1,1)
				elif active and not striking:
					draw_circle(tile.get_center(),maxf(2,cell_size*0.16),accent)
		# Sliding weapons: arrows past the outer tiles.
		for direction in Catalog.slides(index):
			var far := origin+(Vector2(direction*(count/2)+Vector2i(count/2,count/2))+Vector2.ONE*0.5)*cell_size
			var tip: Vector2 = far+Vector2(direction).normalized()*cell_size*0.75
			draw_line(far,tip,accent,2)
			draw_circle(tip,2.5,accent)
		if forged:
			SpiritIcon.paint_plus(self,origin+Vector2(side+4,-3),18)
		var stuck: String = "" if busy else stuck_reasons.get(index,"")
		if stuck != "" and model.locked_slot < 0:
			draw_rect(rect,Color(0,0,0,0.62))
			var stuck_size := 20
			_text(pos+Vector2((248-_text_width(stuck,stuck_size))/2.0,58),stuck,stuck_size,Color("ff8f8f"))
		if model.locked_slot >= 0:
			if slot == model.locked_slot:
				draw_rect(rect,Color("ffd35b"),false,4)
				_text(pos+Vector2(118,32),"判決",18,Color("ffd35b"))
			else:
				draw_rect(rect,Color(0,0,0,0.62))
				_text(pos+Vector2(70,56),"封印",26,Color("ff5b62"))

## True while a fairy that is used by pressing yourself is picked (it needs no hovering: there is one tile).
func _shows_self_fairy_ghost() -> bool:
	if selected_item.is_empty() or busy or item_origin != Vector2i(-1,-1) or Rules.BIG_FAIRIES.has(selected_item):
		return false
	var item: Resource = model.item_definition(selected_item)
	return item != null and item.icon != null and item.target == Rules.ItemDefinition.Target.SELF

## True while a fairy that is set down on a tile is picked and the cursor is over a tile it can go on.
func _shows_fairy_ghost() -> bool:
	if selected_item.is_empty() or busy or item_origin != Vector2i(-1,-1) or Rules.BIG_FAIRIES.has(selected_item):
		return false
	var item: Resource = model.item_definition(selected_item)
	if item == null or item.icon == null or item.target == Rules.ItemDefinition.Target.SELF:
		return false
	return model.inside(hover_cell) and model.item_targets(selected_item).has(hover_cell)

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
	elif selected_item == "guardian_fairy":
		draw_texture_rect(UnitView.GUARDIAN, Rect2(center - Vector2(64, 75), Vector2.ONE * 127), false, Color(1, 1, 1, 0.7))
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
			var plus_mark := "+" if model.plus_level(selected_item) <= 1 else "+%d" % model.plus_level(selected_item)
			_text(Vector2(854+_text_width(item.title,26),133),plus_mark,26,GOLD)
			SpiritIcon.paint_plus(self,Vector2(954,138),22)
		SpiritIcon.paint(self,Vector2(912,180),item.icon,1.35)
		if model.fairy_ap_cost(selected_item) == 0:
			# A free fairy: the cost is the news.
			draw_rect(Rect2(988,162,92,34),Color("7dff9a"))
			_text(Vector2(996,188),"0 AP",30,Color("0c181b"))
		else:
			_text(Vector2(992,187),"%d AP" % model.fairy_ap_cost(selected_item),24,GOLD)
		# Choosing a direction, the board already previews the shot: the example makes
		# way so the text and the prompt sit above the arrow buttons.
		var choosing := item_origin != Vector2i(-1,-1)
		if not choosing:
			ItemPreview.paint(self,model,selected_item,clock)
		var description := model.fairy_description(selected_item)
		# Lines wider than the panel wrap instead of running out of it; a long text steps down a size.
		var font_size := 18
		var step := 25
		# A text that only just overflows goes down a size or two rather than wrapping.
		for trial in [18, 17, 16]:
			var all_fit := true
			for line in description.split("\n"):
				all_fit = all_fit and _text_width(line, trial) <= 262.0
			if all_fit:
				font_size = trial
				step = 25 if trial == 18 else roundi(trial * 1.4)
				break
		var lines := _wrap_lines(description, font_size, 262.0)
		if lines.size() > 8:
			font_size = 16
			step = 22
			lines = _wrap_lines(description, font_size, 262.0)
		# The text's baseline sits a line below the example so the first line clears it.
		var text_top := 252.0 if choosing else 352.0
		for i in range(lines.size()):
			_text(Vector2(850,text_top+i*step),lines[i],font_size,INK)
		_text(Vector2(852,text_top+(lines.size()-1)*step+42 if choosing else maxf(490.0,text_top+lines.size()*step+14.0)),"向きを選択" if item_origin != Vector2i(-1,-1) else "移動先を選択" if selected_item == "warp_fairy" else "自分のマスを押す" if item.target == Rules.ItemDefinition.Target.SELF else "配置先を選択",23,item.color)
		return
	var enemy := _preview_enemy()
	var ally := _preview_ally()
	if not ally.is_empty():
		_draw_ally_inspector(ally)
	elif not enemy.is_empty():
		_draw_enemy_inspector(enemy)
	elif not _placed_at(hover_cell).is_empty():
		_draw_placed_inspector(_placed_at(hover_cell))
	elif selected_weapon >= 0:
		var weapon: Dictionary = Rules.WEAPONS[selected_weapon]
		_text(Vector2(852,133),weapon.name,25,Color(weapon.color))
		_text(Vector2(852,177),"装備中",21,MUTED)
		_draw_range(model.weapon_offsets(selected_weapon,model.facing),Color(weapon.color),{},selected_weapon,model.facing,2,false,Catalog.attack_offsets(selected_weapon, model.weapon_power.has(selected_weapon)))
		_text(Vector2(852,495),"移動・攻撃範囲",23,INK)
		_wrapped(Vector2(852,528),Rules.WEAPONS[selected_weapon].detail,18,MUTED,14)
	else:
		_text(Vector2(852,133),"敵の情報",26,CYAN)
		_text(Vector2(852,295),"敵や味方にカーソルを",23,INK)
		_text(Vector2(852,330),"合わせて確認",23,INK)
		_text(Vector2(852,540),"右クリックで固定",20,MUTED)

## A hammer's echo tile: hatched in orange (the blow spreads here too).
const HAMMER_ECHO = Color("ffa04a")
func _hatch(rect: Rect2, color: Color) -> void:
	draw_rect(rect, Color(color, 0.14))
	for k in range(1, 8):
		var t := k / 4.0
		var a := rect.position + Vector2(minf(t,1.0), maxf(t-1.0,0.0)) * rect.size.x
		var b := rect.position + Vector2(maxf(t-1.0,0.0), minf(t,1.0)) * rect.size.x
		draw_line(a, b, Color(color, 0.5), 1.5)

func _draw_player_portrait(weapon_index: int, center: Vector2, side: float, facing_index: int = 2) -> void:
	if Catalog.is_hammer(weapon_index):
		# The hammer pose (it only faces right).
		UnitView.draw_hammer_pose(self, 0, Vector2.ZERO, Color.WHITE, side/64.0, center/(side/64.0) + Vector2(0, 21))
		return
	var cell := UnitView.PLAYER_ATLAS_CELL
	var row: int = Rules.WEAPONS[weapon_index].row
	draw_texture_rect_region(UnitView.PLAYER_ATLAS,Rect2(center-Vector2.ONE*side/2,Vector2.ONE*side),Rect2(facing_index*cell,row*cell,cell,cell))

func _draw_range(offsets: Array, accent: Color, enemy: Dictionary = {}, weapon_index: int = -1, _forward_index: int = 0, portrait_index: int = 2, compact: bool = false, attack: Array = []) -> void:
	var count := 3
	# Hammers: where the blow also reaches when it strikes the tile to the right.
	var echo: Array[Vector2i] = []
	if enemy.is_empty() and weapon_index >= 0:
		echo = Catalog.hammer_echo(weapon_index, model.weapon_power.has(weapon_index))
	var step := 52 if compact else 64
	# Cavalry and two-tile weapons need a larger preview for their jumps.
	var self_cell: Vector2i = Vector2i(1,1)
	var wide := maxi(RangeDiagram.span(offsets + echo), RangeDiagram.span(attack))
	if enemy.get("type","") in Rules.JUMPERS:
		wide = maxi(wide, 5)
	if wide >= 5:
		count = wide
		step = 38 if wide == 5 else 30
		self_cell = Vector2i(wide / 2, wide / 2)
	var origin := Vector2(980-count*step/2.0,192 if compact else 236)
	for y in range(count):
		for x in range(count):
			var offset := Vector2i(x,y)-self_cell
			var rect := Rect2(origin+Vector2(x,y)*step,Vector2.ONE*(step-5))
			var active: bool = offsets.has(offset)
			var hits: bool = attack.has(offset)
			var tone: Color = Color("ff805a") if hits else accent
			draw_rect(rect,Color(tone,0.3) if active or hits else Color("192828"))
			if echo.has(offset) and not active:
				_hatch(rect, HAMMER_ECHO)
			draw_rect(rect,tone if active or hits else HAMMER_ECHO if echo.has(offset) else Color("46625e"),false,2)
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
	if ALLY_PORTRAITS.has(enemy.type):
		var art: Array = ALLY_PORTRAITS[enemy.type]
		if art.size() > 2:
			# Direction sheets: the frame facing the way it faces now.
			draw_texture_rect_region(art[0],art[1],Rect2(int(enemy.get("facing",1))*art[2],0,art[2],art[2]))
		else:
			draw_texture_rect(art[0],art[1],false)
	elif enemy.type == "miner":
		actor._draw_drone(Color.WHITE,self)
	elif enemy.type in Rules.JUMPERS:
		actor._draw_cavalry(Color.WHITE,self)
	elif enemy.type == "jester":
		UnitView.draw_jester(self,int(enemy.get("facing",3)),enemy.get("awake",false),Color.WHITE,0.9)
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

## Allies' portraits for the inspector: [texture, rect(, frame size for direction sheets)].
const ALLY_PORTRAITS = {
	"acorn": [UnitView.ACORN, Rect2(-28,-30,56,56)],
	"wall": [UnitView.WALL, Rect2(-28,-30,56,56)],
	"glutton": [UnitView.GLUTTON, Rect2(-28,-30,56,56)],
	"wolf": [UnitView.WOLF_SHEET, Rect2(-32,-36,64,64), 256],
	"holy": [UnitView.HOLY_SPIRIT, Rect2(-30,-32,60,60)],
	"guardian": [UnitView.GUARDIAN, Rect2(-30,-34,60,60)],
	"holy_knight": [UnitView.HOLY_KNIGHT, Rect2(-30,-32,60,60), 128],
}
const ALLY_GREEN = Color("8dffb0")
const CARDINAL_OFFSETS = [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
const DIAGONAL_OFFSETS = [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]

## A summoned ally, shown like an enemy: HP/AP, its moves (green dots) and where it
## strikes (red crosses), and what it will do.
func _draw_ally_inspector(ally: Dictionary) -> void:
	var title: String = Rules.ALLY_NAMES.get(ally.type, "味方")
	_text(Vector2(852,133),title,28,INK)
	_text(Vector2(858+_text_width(title,28),133),"味方",18,ALLY_GREEN)
	_text(Vector2(852,175),"HP",20)
	var hearts: int = maxi(int(ally.hp), 1)
	var many: bool = hearts > 3
	var huge: bool = hearts > 7
	for i in range(hearts):
		_draw_heart(Vector2(909+i*(12 if huge else 16 if many else 30),167),11 if huge else 14 if many else 25,Color("ff5b62"),true)
	var ap_x := 1046.0 if hearts > 8 else 1030.0 if many else 1004.0 if hearts >= 3 else 984.0
	_text(Vector2(ap_x,175),"AP",20,GOLD)
	var ap: int = Rules.ally_ap(ally.type)
	for i in range(ap):
		draw_rect(Rect2(ap_x+45+i*26,153,22,23),GOLD)
	var moves: Array = []
	var strikes: Array = []
	var lines: Array = []
	var intent := ""
	var warn := false
	match ally.type:
		"acorn", "holy_knight":
			moves = CARDINAL_OFFSETS
			strikes = CARDINAL_OFFSETS + (DIAGONAL_OFFSETS if ally.get("plus", false) else [])
			lines = ["敵より先に動く", "隣の大砲は叩いて撃たせる", "隣の敵に1（HPの低い敵から）" if not ally.get("plus", false) else "縦横斜めの敵に1", "いなければ近い敵へ1歩"]
			if ally.type == "holy_knight":
				lines = ["敵より先に動く", "AP%d：隣の敵に1か、敵へ1歩" % Rules.HOLY_KNIGHT_AP, "これを1ターンに%d回" % Rules.HOLY_KNIGHT_AP]
			intent = "近くの敵を攻撃"
		"wall":
			lines = ["敵も自分も通れない壁", "動かず、何もしない", "敵は隣にあると壊しにくる"]
			intent = "ただ立っている"
		"wolf":
			moves = Rules.WOLF_MOVES
			strikes = Rules.WOLF_MOVES
			lines = ["銀の動き・右向き固定", "AP%d：1歩か1噛みでAP1" % Rules.ally_ap("wolf"), "噛むと%dダメージ" % Rules.WOLF_BITE, "武器が届く所ではすねて動かず、", "届かない所で移動・攻撃"]
			var sulking: bool = model.reach_covers(ally.cell)
			intent = "すねている…（動かない）" if sulking else "群れずに噛みつく"
		"glutton":
			moves = Rules.GLUTTON_MOVES
			strikes = Rules.GLUTTON_MOVES
			lines = ["金の動き・右向き固定", "%d回動いて一番近い相手を噛む" % Rules.ally_ap("glutton"), "噛むと%dダメージ" % Rules.CIRCLE_DAMAGE, "同じ距離ならあなたを優先"]
			# The same "!" the board shows (worked out once per turn in _sync_units).
			warn = actors.has(int(ally.id)) and actors[int(ally.id)].charge_warning
		"holy":
			_draw_ally_big_range(ally)
			lines = ["敵より先に動く", "辺に接する敵に1、", "いなければ敵へ1マス進む", "壊れると聖騎士（HP%d・AP%d）が%d体" % [Rules.HOLY_KNIGHT_HP, Rules.HOLY_KNIGHT_AP, 4 if ally.get("plus", false) else 2]]
			intent = "近くの敵を攻撃"
		"guardian":
			_draw_ally_big_range(ally)
			lines = ["敵より先に動く", "辺に接する敵に1、", "いなければ敵へ1マス進む", "この戦闘の妖精をHP+%dで呼んだ" % Rules.GUARDIAN_BONUS_HP]
			intent = "仲間を率いて戦う"
	if ally.type not in ["holy", "guardian"]:
		_text(Vector2(852,217),"移動・攻撃範囲",21,INK)
		_draw_range(moves,ALLY_GREEN,ally,-1,0,2,false,strikes)
	var y := 454.0
	for line in lines:
		_text(Vector2(852,y),line,16,MUTED)
		y += 22
	# The glutton can bite you too: the same warning as an enemy's.
	if ally.type == "glutton":
		_text(Vector2(852,y+14),THREAT_TEXT[0] if warn else THREAT_TEXT[1],20,THREAT_RED if warn else MUTED)
	_text(Vector2(852,574),"固定中・右クリックで解除" if selected_enemy_id==int(ally.id) else "右クリックで固定",18,MUTED)

## The 2x2 holy spirit: it strikes and steps along its four sides.
func _draw_ally_big_range(ally: Dictionary) -> void:
	_text(Vector2(852,217),"移動・攻撃範囲",21,INK)
	var step := 46.0
	var origin := Vector2(980-step*2,236)
	for y in range(4):
		for x in range(4):
			var rect := Rect2(origin+Vector2(x,y)*step,Vector2.ONE*(step-5))
			var inner: bool = x in [1,2] and y in [1,2]
			var edge: bool = not inner and (x in [1,2] or y in [1,2])
			var tone := Color("ff805a")
			draw_rect(rect,Color(tone,0.3) if edge else Color("192828"))
			draw_rect(rect,tone if edge else Color("46625e"),false,2)
			if edge:
				draw_line(rect.get_center()-Vector2(6,6),rect.get_center()+Vector2(6,6),tone,3)
				draw_line(rect.get_center()-Vector2(6,-6),rect.get_center()+Vector2(6,-6),tone,3)
	_draw_enemy_portrait(ally,origin+Vector2.ONE*step*2-Vector2.ONE*2.5,1.4)

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
	7: ["刑を執行します。", "AP+1・2回突進・走った道が次のターンに焼ける"],
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

## The mini slot on the board: three little windows over the numbered blocks, the drawn one lit
## and pointed at, like a slot machine's payline (above the blocks, or below them on the top rows).
func _draw_mini_slot_badge() -> void:
	if model.mini_zones.is_empty():
		return
	var drawn := _mini_drawn()
	var side := 30.0
	var gap := 8.0
	var width := side * 3 + gap * 2
	var band := _mini_zone_rect(0).merge(_mini_zone_rect(1)).merge(_mini_zone_rect(2))
	var vertical := band.size.y > band.size.x
	# On the far side of the board from the blocks (there is no room outside the 8x8 board).
	var board_middle := BOARD + Vector2.ONE * TILE * model.board_size / 2.0
	var centre_x := board_middle.x
	var y := BOARD.y + (model.board_size - 1) * TILE + (TILE - side) / 2.0
	if vertical:
		centre_x = BOARD.x + TILE * (model.board_size - 2.0) if band.get_center().x < board_middle.x else BOARD.x + TILE * 2.0
	elif band.get_center().y > board_middle.y:
		y = BOARD.y + (TILE - side) / 2.0
	var left := centre_x - width / 2.0
	var frame := Rect2(left - 10, y - 6, width + 20, side + 12)
	draw_rect(frame, Color(0.06, 0.03, 0.04, 0.92))
	draw_rect(frame, Color("ff5b62"), false, 3)
	for k in 3:
		var window := Rect2(left + k * (side + gap), y, side, side)
		var lit := drawn == k + 1
		var pulse := 0.65 + 0.35 * sin(clock * 8.0) if lit else 1.0
		draw_rect(window, Color(0.35, 0.08, 0.08, 0.95) if lit else Color("0b1415"))
		draw_rect(window, Color("ffd35b") if lit else Color("46625e"), false, 3 if lit else 2)
		_text(window.position + Vector2(8, 24), str(k + 1), 24, Color(1, 0.82, 0.3, pulse) if lit else Color(0.5, 0.6, 0.6))
	if drawn > 0:
		var tip := Vector2(left + (drawn - 1) * (side + gap) + side / 2.0, y + side + 2.0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 8), tip + Vector2(-7, -1), tip + Vector2(7, -1)]), Color("ffd35b"))

## The pixel rectangle covered by numbered block `k`.
func _mini_zone_rect(k: int) -> Rect2:
	var low := Vector2i(99, 99)
	var high := Vector2i(-1, -1)
	for cell in model.mini_zones[k]:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	return Rect2(BOARD + Vector2(low) * TILE, Vector2(high - low + Vector2i.ONE) * TILE)

## One tile of a numbered block: glass, a scanning light, hazard chevrons on the drawn one,
## and a glowing outline around the whole block.
func _draw_mini_zone_tile(cell: Vector2i, k: int) -> void:
	var drawn := _mini_drawn() == k + 1
	var box := _mini_zone_rect(k)
	var horizontal := box.size.x >= box.size.y
	var local := (BOARD + Vector2(cell) * TILE - box.position) / box.size
	var tone := Color("ff3b4a") if drawn else Color("46d9ff")
	var glow := (0.48 + 0.14 * sin(clock * 9.0)) if drawn else 0.12
	draw_rect(Rect2(Vector2(2,2),Vector2(60,60)),Color(tone,glow))
	if drawn:
		# Hazard chevrons running along the block toward the charge.
		var shift := fmod(clock * 46.0, 32.0)
		for stripe in range(-2, 4):
			var at := float(stripe) * 32.0 + shift
			draw_line(Vector2(at, 64.0), Vector2(at + 32.0, 0.0), Color("ffb03b", 0.6), 9)
	else:
		# A band of light sweeping along the block.
		var progress := fmod(clock * 0.55 + float(k) * 0.3, 1.4) - 0.2
		var along := local.x if horizontal else local.y
		var span := (box.size.x if horizontal else box.size.y) / TILE
		var d := absf(along - progress) * span
		if d < 0.6:
			draw_rect(Rect2(Vector2(2,2),Vector2(60,60)),Color(tone,0.30 * (1.0 - d / 0.6)))
	# Glowing outline, only on the sides that face outside the block.
	var edge_color := Color(tone, 0.95 if drawn else 0.6)
	var neighbours := {Vector2i.UP:[Vector2(0,1),Vector2(64,1)], Vector2i.DOWN:[Vector2(0,63),Vector2(64,63)], Vector2i.LEFT:[Vector2(1,0),Vector2(1,64)], Vector2i.RIGHT:[Vector2(63,0),Vector2(63,64)]}
	for side in neighbours:
		if not model.mini_zones[k].has(cell + side):
			draw_line(neighbours[side][0], neighbours[side][1], Color(tone, 0.25), 8)
			draw_line(neighbours[side][0], neighbours[side][1], edge_color, 3)

## The Prison King's barrier: a red dome on him, a pulsing chain from every fortress that still feeds
## it, and pips over his head (one per fortress, filled while it stands). It thins from red to
## nothing as the fortresses fall.
func _draw_king_barrier() -> void:
	for king in model.enemies:
		if king.type != "king" or king.hp <= 0 or not model.king_shielded(king):
			continue
		var left: int = king.barrier_cells.size()
		var total: int = maxi(1, int(king.get("barrier_max", 1)))
		var strength := float(left) / float(total)
		var centre := BOARD + (Vector2(king.cell) + Vector2(1.5, 1.5)) * TILE
		var beat := 0.5 + 0.5 * sin(clock * 5.0)
		var tone := Color(1.0, 0.18 + 0.5 * (1.0 - strength), 0.2 + 0.7 * (1.0 - strength))
		# The chains, from each fortress that still feeds the barrier.
		for fortress in model.enemies:
			if fortress.type != "fortress" or fortress.hp <= 0 or not king.barrier_cells.has(int(fortress.id)):
				continue
			var from := BOARD + (Vector2(fortress.cell) + Vector2.ONE) * TILE
			draw_line(from, centre, Color(tone, 0.28 + 0.2 * beat), 6.0)
			draw_line(from, centre, Color(1.0, 0.7, 0.7, 0.5 + 0.3 * beat), 2.0)
			var length := from.distance_to(centre)
			var links := int(length / 24.0)
			for k in range(links):
				var along := fposmod(float(k) / float(maxi(links, 1)) + clock * 0.5, 1.0)
				draw_circle(from.lerp(centre, along), 4.0, Color(1.0, 0.85, 0.8, 0.9))
		# The barrier: a square of red glass exactly over his 3x3, with scanning lines and corner brackets.
		var box := Rect2(BOARD + Vector2(king.cell) * TILE, Vector2.ONE * TILE * 3.0).grow(3.0)
		draw_rect(box, Color(tone, 0.12 + 0.12 * strength + 0.05 * beat))
		draw_rect(box, Color(tone, 0.6 + 0.3 * beat), false, 5.0)
		draw_rect(box.grow(-9.0), Color(1, 1, 1, 0.2), false, 2.0)
		for k in range(1, 6):
			var y := box.position.y + fposmod(clock * 40.0 + k * box.size.y / 6.0, box.size.y)
			draw_line(Vector2(box.position.x + 4.0, y), Vector2(box.end.x - 4.0, y), Color(tone, 0.18), 2.0)
		var arm := TILE * 0.5
		for corner in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
			var sx := 1.0 if corner.x < centre.x else -1.0
			var sy := 1.0 if corner.y < centre.y else -1.0
			draw_line(corner, corner + Vector2(sx * arm, 0), Color(1, 0.85, 0.85, 0.95), 7.0)
			draw_line(corner, corner + Vector2(0, sy * arm), Color(1, 0.85, 0.85, 0.95), 7.0)
		# One pip per fortress over his head.
		var pip_y := centre.y - TILE * 1.5 - 22.0
		for k in range(total):
			var at := Vector2(centre.x + (k - (total - 1) / 2.0) * 26.0, pip_y)
			if k < left:
				draw_circle(at, 9.0, Color(1.0, 0.25, 0.25))
				draw_circle(at, 9.0, Color(1, 1, 1, 0.8), false, 2.0)
			else:
				draw_arc(at, 9.0, 0.0, TAU, 20, Color(0.7, 0.9, 1.0, 0.7), 3.0, true)

## The drawn number, big, floating over Rotorick so the result can't be missed.
func _draw_reel_badge() -> void:
	if reel_hold:
		return
	for enemy in model.enemies:
		if enemy.type != "slot" or enemy.hp <= 0 or int(enemy.get("reel",0)) <= 0:
			continue
		var reel_now: int = int(enemy.reel)
		var colour: Color = REEL_COLORS.get(reel_now, CasinoFx.GOLD)
		var size := Vector2(250, 60)
		var at := BOARD + Vector2(enemy.cell) * TILE + Vector2(TILE - size.x / 2.0, -size.y - 30.0)
		var rect := Rect2(at, size)
		# No room above the top row: hang below Rotorick instead.
		if rect.position.y < BOARD.y - 8.0:
			rect.position.y = BOARD.y + (enemy.cell.y + 2) * TILE + 6.0
		rect.position.x = clampf(rect.position.x, BOARD.x, BOARD.x + model.board_size * TILE - size.x)
		draw_rect(rect, Color(0.05, 0.02, 0.07, 0.94))
		var pulse := 0.7 + 0.3 * sin(clock * 6.0)
		draw_rect(rect, Color(colour, pulse), false, 4)
		draw_rect(rect.grow(4), Color(colour, 0.25 * pulse), false, 2)
		_text(rect.position + Vector2(14, 46), str(reel_now), 48, colour)
		_text(rect.position + Vector2(52, 38), REEL_SHORT.get(reel_now, ""), 22, Color("f1e9d8"))
		return

func _mini_zone_of(cell: Vector2i) -> int:
	for k in model.mini_zones.size():
		if model.mini_zones[k].has(cell):
			return k
	return -1

func _mini_drawn() -> int:
	for enemy in model.enemies:
		if enemy.type == "slot" and enemy.hp > 0:
			return int(enemy.get("mini",0))
	return 0

func _draw_rotorick_inspector(enemy: Dictionary) -> void:
	var reel: int = int(enemy.get("reel",0))
	var lines: Array = REEL_LINES[reel]
	_draw_rook_lane_diagram(Vector2(852,206))
	var top := 322.0
	var line_color := Color("ffd35b") if reel == 5 else Color("f1e9d8")
	var y := _wrapped(Vector2(852,top),lines[0] if reel == 5 else "「%s」" % lines[0],18,line_color,15)
	_draw_reel_diagram(reel, Rect2(852,y+4,256,92))
	var y_end := _wrapped(Vector2(852,y+122),lines[1],18,Color("ff5b62") if reel == 7 else Color("ffd35b"),14)
	if enemy.hp <= Rules.MINI_SLOT_HP:
		# Below the HP line a small second slot (1-3) names the numbered floor block that burns.
		var mini: int = int(enemy.get("mini",0))
		var box := Rect2(852,y_end+2,256,40)
		draw_rect(box,Color("1a0f12"))
		draw_rect(box,Color("ff5b62"),false,2)
		_text(Vector2(862,y_end+30),"ミニスロット",16,Color("f1e9d8"))
		_text(Vector2(982,y_end+32),str(mini) if mini > 0 else "－",26,Color("ffd35b"))
		_text(Vector2(1010,y_end+30),"%dの床が焼ける" % mini if mini > 0 else "停止中",13,Color("ff5b62"))

## How Rotorick moves: the 2x2 body and the four lanes it charges down like a rook.
func _draw_rook_lane_diagram(at: Vector2) -> void:
	var cell := 12.0
	var cols := 19
	var rows := 7
	var mid_col := cols / 2
	var mid_row := rows / 2
	_text(at + Vector2(0,-2),"移動・突進（飛車の動き）",15,CYAN)
	var origin := at + Vector2(0,6)
	var lane := Color(1,0.3,0.28,0.55)
	for row in range(rows):
		for col in range(cols):
			var rect := Rect2(origin + Vector2(col,row) * cell, Vector2.ONE * (cell - 1))
			# The body is 2x2 (columns mid-1..mid, rows mid-1..mid); lanes are as wide as the body.
			var in_body: bool = col in [mid_col-1, mid_col] and row in [mid_row-1, mid_row]
			var in_lane: bool = (col in [mid_col-1, mid_col]) != (row in [mid_row-1, mid_row])
			if in_body:
				draw_rect(rect, Color("f1e9d8"))
			elif in_lane:
				draw_rect(rect, lane)
			else:
				draw_rect(rect, Color("152221"))
	# Arrow heads at the four ends of the lanes, kept inside the grid.
	var centre := origin + Vector2(mid_col, mid_row) * cell
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var reach: float = cols * cell / 2.0 if direction.x != 0 else rows * cell / 2.0
		var tip: Vector2 = centre + direction * reach
		var side := Vector2(-direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([tip, tip - direction * 9 + side * 6, tip - direction * 9 - side * 6]), Color("ff3b3b"))

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
					var at := box.position+Vector2(22+x*30,13+y*22)
					if (x+y)%2 == 0:
						draw_rect(Rect2(at-Vector2(13,9),Vector2(26,18)),Color(0.85,0.1,0.1,0.8))
					else:
						draw_rect(Rect2(at-Vector2(13,9),Vector2(26,18)),Color(0.1,0.05,0.05))
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
		var y := _wrapped(Vector2(852,436),"ロトリックの残像。誰でも通り抜けられる。",17,INK,15)
		_wrapped(Vector2(852,y),"縦横に隣接したプレイヤーに1ダメージを与えて消える。",17,tone,15)
	elif enemy.type == "storm_shark":
		_text(Vector2(852,440),"2×2で縦横に1マスずつ動く",18,tone)
		_text(Vector2(852,464),"ときどき潜り、影の下に浮上",18,CYAN)
		_text(Vector2(852,488),"2ダメージ＋ノックバック",18,CYAN)
		_text(Vector2(852,514),"嵐：S字の雷4本",15,MUTED)
		_text(Vector2(852,534),"津波：あなた・召喚妖精を運ぶ",15,MUTED)
		_text(Vector2(852,552),"（嵐鮫と設置物は動かない）",15,MUTED)
		_draw_threat(enemy,576)
	else:
		_text(Vector2(852,450),"2×2で縦横に1マスずつ動く",18,tone)
		UnitView.draw_skull(self, Vector2(862,468), 1.7)
		_text(Vector2(878,476),"壊すと執行兵が2体出る",19,CYAN)
		_draw_released_soldier()
		_draw_threat(enemy,568)
	_text(Vector2(852,596 if enemy.type in ["prison", "storm_shark"] else 574),"固定中・右クリックで解除" if selected_enemy_id==int(enemy.id) else "右クリックで固定",18,MUTED)

## What a broken moving prison lets out: the executioner with its HP 2 and AP 2, and the
## four directions it walks in.
func _draw_released_soldier() -> void:
	var type: Dictionary = Rules.TYPES.executioner
	draw_set_transform(Vector2(884,500),0,Vector2.ONE*0.9)
	UnitView.draw_boss(self,"executioner",2,false,Color.WHITE,0.9,0)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	for i in int(type.hp):
		_draw_heart(Vector2(926+i*22,500),18,Color("ff5b62"),true)
	_text(Vector2(984,508),"AP",18,GOLD)
	for i in int(type.ap):
		draw_rect(Rect2(1014+i*22,491,18,19),GOLD)
	_text(Vector2(852,544),"上下左右に1マスずつ動く",17,CYAN)

## Things placed on the board (fairies' devices, pits, mines, the magic circle),
## for the inspector: {title, icon (fairy id or ""), turns, state, lines, color}.
const CANNON_FAIRIES := {"lance": "cannon_fairy", "vane": "vane_cannon", "firework": "firework_fairy", "capacitor": "capacitor_fairy"}
const DIRECTION_NAMES := {Vector2i.RIGHT: "右", Vector2i.LEFT: "左", Vector2i.UP: "上", Vector2i.DOWN: "下"}
## The boss hazard tiles (the shark's coming surface, marked lightning, marked burning floor), with the
## text the side panel and the pop-up beside the cursor both show.
func _hazard_at(cell: Vector2i) -> Dictionary:
	for enemy in model.enemies:
		if enemy.get("diving", false) and enemy.hp > 0 and enemy.dive_area.has(cell):
			var landing: bool = model.footprint({"cell":enemy.dive_anchor, "size":2}).has(cell)
			return {"title": "浮上の危険マス", "kind": "危険マス", "icon": "", "turns": 0, "state": "嵐鮫の体が出てくるマス" if landing else "浮上の衝撃が届くマス", "lines": ["潜った嵐鮫が次の敵ターンに", "ここから浮上する", "いると%dダメージ＋ノックバック" % Rules.DIVE_DAMAGE], "color": Color("ff5b62")}
	if model.storm.get("marks", []).has(cell):
		return {"title": "落雷の予告マス", "kind": "危険マス", "icon": "", "turns": 0, "state": "", "lines": ["次の敵ターンに雷が落ちる", "立っていると1ダメージ", "雷は4本、それぞれS字の4マス"], "color": Color("ffe45a")}
	if model.floor_cells.has(cell):
		return {"title": "燃える床の予告", "kind": "危険マス", "icon": "", "turns": 0, "state": "", "lines": ["次の敵ターンに床が燃える", "立っていると1ダメージ", "敵や味方も巻き込まれる"], "color": Color("ff8b3a")}
	return {}

func _placed_at(cell: Vector2i) -> Dictionary:
	if not model.inside(cell):
		return {}
	var cannon: Dictionary = model.cannon_at(cell)
	if not cannon.is_empty():
		var info := {"icon": CANNON_FAIRIES[cannon.kind], "turns": int(cannon.get("turns", Rules.WALL_TURNS))}
		match cannon.kind:
			"lance":
				info.state = "向き：%s" % DIRECTION_NAMES.get(cannon.dir, "")
				info.lines = ["叩くと向きの直線上の", "敵すべてに1"]
			"vane":
				info.state = "向き：%s" % DIRECTION_NAMES.get(cannon.dir, "")
				info.lines = (["叩くと向きの直線上に", "2連射（各1）"] if cannon.get("plus", false) else ["叩くと向きの直線上の", "敵すべてに1"]) + ["撃つたびに向きが", "時計回りに回る"]
			"firework":
				info.state = ""
				info.lines = ["叩くと爆発して消える", "周囲8マスの敵に1", "自分・味方は巻き込まない"] if cannon.get("plus", false) else ["叩くと爆発して消える", "周囲8マスに1", "自分・味方も巻き込む"]
			"capacitor":
				info.state = "電気：%d / %d" % [int(cannon.get("charge", 0)), Rules.CAPACITOR_FULL]
				info.lines = ["叩かれた時に1溜まる", "%dで縦横4方向の直線上の" % Rules.CAPACITOR_FULL, "敵すべてに1"]
		info.lines.append("他の大砲・魔弾でも誘爆")
		return info
	if model.walls.has(cell):
		return {"icon": "wall_fairy", "turns": int(model.walls[cell]), "state": "", "lines": ["完全な障害物", "敵も自分も通れない"]}
	if model.fairies.has(cell):
		return {"icon": "stealth_fairy", "turns": int(model.fairy_turns.get(cell, 0)), "state": "", "lines": ["通り道をふさぐ", "縦横に敵が来ると1ダメージ", "消えずに残る（1ターン1回）"] if model.is_plus("stealth_fairy") else ["通り道をふさぐ", "縦横に敵が来ると", "1ダメージを与えて消える"]}
	if not model.shadow.is_empty() and model.shadow.cell == cell:
		return {"icon": "shadow_stitch", "turns": int(model.shadow.turns), "state": "今ターン：入れ替わり可" if model.shadow.get("ready", false) else "今ターン：入れ替わり済み", "lines": ["押すと%d APで" % model.shadow_swap_cost(), "影と入れ替わる", "入れ替わりは1ターン1回"]}
	if model.mines.has(cell):
		return {"title": "地雷", "icon": "", "turns": 0, "state": "", "lines": ["踏むと1ダメージ", "（自分・味方・敵とも）", "地雷兵は踏まない"], "color": Color("ff8b5a")}
	if model.pits.has(cell):
		return {"icon": "abyss_spirit", "title": "奈落", "turns": model.abyss_turns, "state": "", "lines": ["押し込んだ敵は落ちて即撃破", "2×2は落ちず手前で止まる", "動くと届く範囲に合わせて", "奈落も変わる"]}
	if model.wheel_cell() == cell:
		return {"icon": "wheel_fairy", "turns": int(model.wheel.turns), "state": "乗っている（毎ターンAP+1）" if model.riding_wheel() else "乗っていない", "lines": ["乗ると降りられず、次のターンから", "3ターンの間AP+1", "敵は上に乗れない"]}
	if model.cat_zone_at(cell):
		return {"icon": "cat_fairy", "title": "猫のフィールド", "turns": int(model.cat_at_zone(cell).turns), "state": "", "lines": ["敵は入れず、避けて動く", "（中の敵は出て行く）", "攻撃は止めない"]}
	if not model.blessing.is_empty() and model.blessed(cell):
		return {"icon": "blessing_fairy", "title": "加護の地", "turns": int(model.blessing.turns), "state": "今、中にいる" if model.blessed(model.player.cell) else "今は外にいる", "lines": ["中にいる間、攻撃が", "当たったマスの", "上下左右（十字）にも当たる"] + (["中でターンを終えるとHP+%d" % Rules.BLESS_HEAL] if model.blessing.get("plus", false) else [])}
	var hazard := _hazard_at(cell)
	if not hazard.is_empty():
		return hazard
	if model.circle_tiles.has(cell):
		return {"title": "魔法陣の白マス", "icon": "", "turns": 0, "state": "", "lines": ["白マスで囲むと", "内側と白線上の敵に", "99ダメージ", "（使った白線は消える）"], "color": CIRCLE_WHITE}
	return {}

func _draw_placed_inspector(info: Dictionary) -> void:
	var item: Resource = model.item_definition(info.icon) if info.icon != "" else null
	var title: String = info.get("title", item.title if item != null else "")
	var color: Color = item.color if item != null else info.get("color", INK)
	var x := 852.0
	if item != null:
		SpiritIcon.paint(self,Vector2(880,128),item.icon,0.8)
		x = 912.0
	_text(Vector2(x,140),title,26,color)
	_text(Vector2(852,187),info.get("kind","設置物"),18,MUTED)
	if int(info.turns) > 0:
		_text(Vector2(930,187),"あと%dターン" % int(info.turns),20,GOLD)
	var y := 240.0
	if info.state != "":
		_text(Vector2(852,y),info.state,20,CYAN)
		y += 44
	for line in info.lines:
		_text(Vector2(852,y),line,18,INK)
		y += 28

## The big line under an enemy: whether it will hit you next enemy turn if you
## stay where you are (the same check as the "!" over it on the board).
const THREAT_TEXT := ["このままだと攻撃される！", "今の位置なら攻撃は届かない"]
const THREAT_RED := Color("ff5b62")
func _draw_threat(unit: Dictionary, y: float) -> void:
	var id := int(unit.id)
	var warn: bool = actors.has(id) and actors[id].charge_warning
	_text(Vector2(852,y),THREAT_TEXT[0] if warn else THREAT_TEXT[1],20,THREAT_RED if warn else MUTED)

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
	var ap_x := 1030.0 if huge else 1030.0 if many else 1004.0 if hearts >= 3 else 984.0
	_text(Vector2(ap_x,175),"AP",20,GOLD)
	# An awakened jester's AP is 3 for good (its own, not a bonus).
	var base_ap: int = Rules.JESTER_AWAKE_AP if enemy.type == "jester" and enemy.get("awake", false) else int(type.ap)
	var ap_boxes: int = base_ap + (1 if enemy.type == "slot" and int(enemy.get("reel",0)) == 7 else 0)
	for i in range(ap_boxes):
		draw_rect(Rect2(ap_x+45+i*26,153,22,23),Color("ff5b62") if i >= base_ap else GOLD)
	if enemy.type == "slot":
		_draw_rotorick_inspector(enemy)
		return
	if enemy.type == "rook":
		_text(Vector2(852,217),"移動・攻撃範囲：飛車",21,INK)
		_draw_range(ROOK_RANGE,CYAN,enemy)
		_text(Vector2(852,450),"向きの先へ端まで突進",18,Color("ff805a"))
		_draw_threat(enemy,489)
		_text(Vector2(852,520),"赤：構えた向きへ次に突進" if enemy.get("state","") == "brace" else "次の敵ターンに構える",19,GOLD if enemy.get("state","") == "brace" else MUTED)
		_text(Vector2(852,574),"固定中・右クリックで解除" if selected_enemy_id==int(enemy.id) else "右クリックで固定",18,MUTED)
		return
	if enemy.type in ["prison", "shadow", "storm_shark"]:
		_draw_big_range(enemy)
		return
	_text(Vector2(852,217),"兵を出す場所" if enemy.type in ["king", "fortress"] else "移動・攻撃範囲",21,INK)
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
		if model.king_shielded(enemy):
			_wrapped(Vector2(852,508),"怒り：要塞を壊すまで無敵（あと%d基）" % enemy.barrier_cells.size(),18,Color("ff9a9a"),14)
		elif enemy.get("barrier_broken", false):
			_wrapped(Vector2(852,508),"障壁崩壊：攻撃が通る",18,Color("9fe8ff"),14)
		elif model.king_enraged():
			_wrapped(Vector2(852,508),"怒り状態",18,Color("ff9a9a"),14)
		var next := model.next_revival()
		_wrapped(Vector2(852,446),"次に蘇る：%s（2ターンに1体）" % Rules.TYPES[next].name if next != "" else "動かない。倒れた兵を蘇らせる",18,Color("ff6b8a"),14)
	elif enemy.type == "fortress":
		_wrapped(Vector2(852,450),"毎ターン兵を1体出す。全部壊すと障壁が消える" if model.king_enraged() else "毎ターン兵を1体出す",18,Color("ff6b6b") if model.king_enraged() else Color("9ab8c8"),14)
	elif enemy.type == "jester":
		var left_turns: int = Rules.JESTER_SLEEP_TURNS - int(enemy.get("age", 0))
		if enemy.get("awake", false):
			_text(Vector2(852,450),"覚醒中：AP3・四方へ",18,Color("ff7ac8"))
		else:
			_text(Vector2(852,450),"次の敵ターンに覚醒" if left_turns <= 0 else "覚醒まであと%dターン" % left_turns,18,Color("9ab8c8"))
	elif enemy.type == "gold":
		_text(Vector2(852,450),"左が前。右斜め後ろには動けない",18,Color("ffd35b"))
	elif enemy.type == "silver":
		_text(Vector2(852,450),"左が前。上下と真右には動けない",18,Color("d8e2ee"))
	elif enemy.type == "analyst":
		var learned := int(enemy.get("learned",-1))
		_text(Vector2(852,450),"解析済み：%s（効かない）" % Rules.WEAPONS[learned].name if learned >= 0 else "殴った武器を覚えて無効化",18,Color("7fffd0"))
	if int(enemy.get("frozen",0)) > 0:
		_text(Vector2(852,546),"凍結中：あと%dターン動けない" % int(enemy.frozen),19,Color("9fe4ff"))
	elif model.time_stopped():
		_text(Vector2(852,546),"時間停止：次の敵ターンは動けない",19,TIME_GOLD)
	if enemy.type not in ["king", "fortress"]:
		_draw_threat(enemy,489)  # they never strike
	# What it is up to right now, under the warning.
	if enemy.type == "miner":
		_text(Vector2(852,520),"飛行・地雷を踏まない",19,MUTED)
	elif enemy.state == "charge":
		_text(Vector2(852,520),"突撃準備：次の敵ターンに突撃",19,GOLD)
	elif enemy.get("state","") == "aim":
		_text(Vector2(852,520),"弓を構えている：次に射る",19,GOLD)
	# Its habits, under the status lines (when nothing else is using them).
	if Rules.HABITS.has(enemy.type) and int(enemy.get("frozen",0)) <= 0 and not model.time_stopped() and not (enemy.type == "king" or enemy.type == "fortress"):
		var habits: Array = Rules.HABITS[enemy.type]
		_text(Vector2(852,546),habits[0],17,Color("e5dfc5"))
		_text(Vector2(852,567),habits[1],17,Color("e5dfc5"))
	_text(Vector2(852,592),"固定中・右クリックで解除" if selected_enemy_id==int(enemy.id) else "右クリックで固定",16,MUTED)

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
	if not hammer_stop.is_empty():
		# The hit-stop: the struck tile blazes white, a bright ring pins the contact.
		var c := _center(hammer_stop.cell)
		draw_rect(Rect2(c - Vector2.ONE * TILE / 2, Vector2.ONE * TILE), Color(1, 0.97, 0.85, 0.75))
		draw_arc(c, TILE * 0.62, 0, TAU, 40, Color(1, 1, 1, 0.9), 5)
		draw_arc(c, TILE * 0.8, 0, TAU, 40, Color(QUAKE_YELLOW, 0.6), 3)
	for effect in flashes:
		if effect.get("delay", 0.0) > 0.0:
			continue
		var pos := _center(effect.cell)
		var fade: float = effect.life/effect.get("max_life",0.42)
		if FX_LIFE.has(effect.kind):
			_draw_fx(effect,pos,fade)
			continue
		var row := 1 if effect.kind == "mine" else 3 if effect.kind == "plant" else 0
		if effect.get("bump", false):
			# A collision's damage: a beat after the attack, in the collision's colour.
			var age: float = effect.max_life - effect.life
			if age >= BUMP_LAG:
				var rise: float = (age - BUMP_LAG) / (float(effect.max_life) - BUMP_LAG)
				draw_string_outline(ui_font, pos + Vector2(-4, -20 - rise * 18), "−1", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0.05, 0.03, 0.02, 1.0 - rise))
				draw_string(ui_font, pos + Vector2(-4, -20 - rise * 18), "−1", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(BUMP, 1.0 - rise))
			continue
		# Every blow that lands on someone (an enemy, you or an ally) is drawn the way a sword hit on an
		# enemy is: the white flash, the burst, and the big number.
		var on_enemy: bool = (effect.kind in ["hit", "weapon_hit"] or effect.kind == "mine") and int(effect.get("id", -2)) != -2
		if on_enemy:
			_draw_enemy_hit(effect, fade)
			continue
		if effect.kind != "weapon_hit":
			draw_texture_rect_region(EFFECTS,Rect2(pos-Vector2(32,32),Vector2(64,64)),Rect2(16*24,row*24,24,24),Color(1,1,1,fade))
		if effect.get("damage", 1) >= Rules.CIRCLE_DAMAGE:
			_draw_big_damage(pos, fade, int(effect.damage))
		elif effect.kind != "plant":
			_text(pos+Vector2(9,-26-(1-fade)*20),"−1",22,Color(1,0.65,0.4,fade))

## An enemy taking damage, sized to its footprint (1x1, 2x2, 3x3): a white flash on
## its tiles, a ring and sparks bursting out, the hit sprite, and a big damage number
## that pops up with a bounce.
const HIT_RED := Color("ff5b4a")
func _draw_enemy_hit(effect: Dictionary, fade: float) -> void:
	var span := int(effect.get("span", 1))
	var t := 1.0 - fade
	var center := _center(effect.cell) + Vector2.ONE * TILE * (span - 1) / 2.0
	var size := TILE * span
	# The struck tiles blink white, then the burst fades.
	if t < 0.25:
		draw_rect(Rect2(center - Vector2.ONE * size / 2, Vector2.ONE * size), Color(1, 0.96, 0.88, 0.55 * (1.0 - t / 0.25)))
	var burst := ease(minf(t * 2.2, 1.0), 0.35)
	draw_arc(center, size * (0.3 + 0.45 * burst), 0, TAU, 40, Color(1, 1, 1, 0.9 * fade), 4.0 + span, true)
	draw_arc(center, size * (0.22 + 0.36 * burst), 0, TAU, 40, Color(HIT_RED, 0.8 * fade), 3.0 + span, true)
	var seed_value := int(effect.cell.x) * 31 + int(effect.cell.y) * 17
	for k in 8 + span * 2:
		var angle := k * TAU / (8 + span * 2) + float((seed_value + k * 7) % 10) * 0.05
		var from := center + Vector2.from_angle(angle) * size * (0.18 + 0.3 * burst)
		var to := center + Vector2.from_angle(angle) * size * (0.3 + 0.55 * burst)
		draw_line(from, to, Color(1, 0.85, 0.45, fade) if k % 2 == 0 else Color(1, 1, 1, fade), 2.0 + span * 0.5)
	# Only a mine keeps its own burst picture: every other blow looks like a sword hit.
	if effect.kind == "mine":
		var art := maxf(TILE, 64.0) * (0.8 + 0.4 * span)
		draw_texture_rect_region(EFFECTS,Rect2(center-Vector2.ONE*art/2,Vector2.ONE*art),Rect2(16*24,(1 if effect.kind == "mine" else 0)*24,24,24),Color(1,1,1,fade))
	var amount := int(effect.get("damage", int(effect.get("hp_before", 1)) - int(effect.get("hp", 0)) if effect.has("hp_before") else 1))
	if amount >= Rules.CIRCLE_DAMAGE:
		_draw_big_damage(center, fade, amount)
		return
	# The number: pops big, settles, rises and fades.
	var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - t / 0.18) if t < 0.18 else 1.0
	var font_size := int((30 + 6 * span) * pop)
	var text := "−%d" % maxi(amount, 1)
	var at := center + Vector2(size * 0.18, -size * 0.32 - ease(t, 0.6) * 26)
	draw_string_outline(ui_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color(0.08, 0.02, 0.02, fade))
	draw_string(ui_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 0.86, 0.4, fade) if t < 0.12 else Color(HIT_RED.lightened(0.25), fade))

## 隕石妖精, in the fairy's own colours: a charcoal rock veined with lava streaks in
## from the upper left on a red-orange-cream flame, then the 3x3 turns to molten
## cracks with a shockwave and embers.
const METEOR_ROCK = Color("3b3431")
const METEOR_LAVA = Color("ff7a1a")
const METEOR_GOLD = Color("ffd23a")
const METEOR_RED = Color("c8261a")
const METEOR_CREAM = Color("fff0a0")
## The hammer's blow spreading: one quake from the struck tile out over every tile it
## shakes, as large as that area allows but never past it. A tremor wave lights
## each tile as it passes, cracks run out to them, and sparks (yellow and cyan, like
## the strike art) and stones fly out from the struck tile to the area's edge.
const QUAKE_YELLOW = Color("ffd84a")
const QUAKE_CYAN = Color("6fe3ff")
const QUAKE_STONE = Color("6b5238")
func _draw_quake(effect: Dictionary, origin: Vector2, t: float) -> void:
	var cells: Array = effect.cells
	var struck: Vector2i = effect.cell
	# How far the area reaches from the struck tile (to its farthest corner).
	var reach := 0.0
	for cell in cells:
		reach = maxf(reach, origin.distance_to(_center(cell)) + TILE * 0.5)
	var wave := (1.0 - pow(1.0 - clampf(t / 0.55, 0.0, 1.0), 2.0)) * reach
	var gone := 1.0 - t
	# The tremor: each tile brightens as the wave passes under it, then settles.
	for cell in cells:
		var c := _center(cell)
		var ahead := wave - origin.distance_to(c)
		if ahead < -TILE * 0.5:
			continue
		var glow := clampf(1.0 - absf(ahead) / (TILE * 0.9), 0.0, 1.0)
		var inset := 3.0
		draw_rect(Rect2(c - Vector2.ONE * (TILE / 2 - inset), Vector2.ONE * (TILE - inset * 2)), Color(1.0, 0.8, 0.4, 0.12 * gone + 0.3 * glow * gone))
		# Cracks running out to the tile as the wave arrives.
		if cell != struck:
			var along := clampf(wave / origin.distance_to(c), 0.0, 1.0)
			var seed_value: int = int(cell.x) * 7 + int(cell.y) * 13
			var normal := (c - origin).normalized().orthogonal()
			var points := PackedVector2Array([origin])
			for k in range(1, 5):
				var bend := float((seed_value * 31 + k * 17) % 11 - 5) * (1.0 if k < 4 else 0.3)
				points.append(origin.lerp(c, along * k / 4.0) + normal * bend)
			draw_polyline(points, Color(0.13, 0.08, 0.04, 0.8 * gone + 0.1), 4)
			draw_polyline(points, Color(1.0, 0.85, 0.45, 0.55 * gone), 1)
	# Sparks and stones fly from the struck tile toward every shaken tile, each one
	# stopping at the edge of the area.
	var n := 0
	for cell in cells:
		var toward := _center(cell) - origin
		for k in 4:
			n += 1
			var angle: float = (toward.angle() if toward.length() > 1.0 else float(n) * 1.3) + float((n * 37) % 9 - 4) * 0.09
			var direction := Vector2.from_angle(angle)
			var limit := _quake_extent(origin, direction, cells)
			var travel := minf(wave * (0.85 + float(n % 3) * 0.1), limit)
			if travel <= 2.0:
				continue
			var head := origin + direction * travel
			var tail := origin + direction * maxf(travel - (22.0 * gone + 4.0), 0.0)
			if k < 3:
				draw_line(tail, head, Color(QUAKE_YELLOW if n % 2 == 0 else QUAKE_CYAN, gone), 4 if n % 2 == 0 else 3)
			else:
				# A stone, arcing a little but kept inside the area.
				var lift := sin(clampf(travel / maxf(limit, 1.0), 0.0, 1.0) * PI) * 8.0
				var stone := head - Vector2(0, lift)
				if _in_quake(stone, cells):
					draw_rect(Rect2(stone - Vector2(3, 3), Vector2(6, 5)), Color(QUAKE_STONE, gone))
					draw_rect(Rect2(stone - Vector2(3, 3), Vector2(6, 2)), Color(0.55, 0.45, 0.33, gone))
	# Dust thrown up off every tile as the wave passes it, rising and spreading.
	for cell in cells:
		var c := _center(cell)
		var since := (wave - origin.distance_to(c)) / maxf(reach, 1.0)
		if since <= 0.0:
			continue
		var puff := clampf(since * 1.6, 0.0, 1.0)
		for k in 3:
			var side := float(k - 1) * TILE * 0.28
			var at := c + Vector2(side, TILE * 0.3 - puff * TILE * 0.35 - float(k % 2) * 6.0)
			var radius := 9.0 + puff * TILE * 0.24
			if _in_quake(at, cells):
				draw_circle(at, radius, Color(0.9, 0.84, 0.72, 0.55 * (1.0 - puff) * gone))
				draw_circle(at + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.45, Color(1, 0.97, 0.9, 0.35 * (1.0 - puff) * gone))
	# A white-hot core where the head landed.
	if t < 0.3:
		draw_circle(origin, 12 * (1.0 - t / 0.3) + 3, Color(1, 1, 0.9, 0.9 * (1.0 - t / 0.3)))

## How far from `origin` a ray in `direction` stays inside the shaken tiles.
func _quake_extent(origin: Vector2, direction: Vector2, cells: Array) -> float:
	var distance := 0.0
	while distance < TILE * 4 and _in_quake(origin + direction * (distance + 3.0), cells):
		distance += 3.0
	return maxf(distance - 4.0, 0.0)

func _in_quake(point: Vector2, cells: Array) -> bool:
	var cell := Vector2i(floori((point.x - BOARD.x) / TILE), floori((point.y - BOARD.y) / TILE))
	return cells.has(cell)

func _draw_meteor(effect: Dictionary, pos: Vector2, t: float) -> void:
	var fall := clampf(t / 0.35, 0.0, 1.0)
	if fall < 1.0:
		var from := pos + Vector2(-300, -340)
		var rock := from.lerp(pos, fall * fall)
		var back := (from - rock).normalized()
		# The flame trail: red outside, orange, then a cream core.
		for layer in [[METEOR_RED, 26.0, 150.0], [METEOR_LAVA, 17.0, 120.0], [METEOR_CREAM, 7.0, 80.0]]:
			draw_line(rock, rock + back * layer[2], layer[0], layer[1])
		for k in 5:
			var ember := rock + back * (40 + k * 24) + Vector2(-back.y, back.x) * (sin(k * 2.3 + t * 30.0) * 14)
			draw_rect(Rect2(ember - Vector2(3, 3), Vector2(6, 6)), METEOR_GOLD if k % 2 == 0 else METEOR_LAVA)
		draw_circle(rock, 17, Color("140c0a"))
		draw_circle(rock, 14, METEOR_ROCK)
		for k in 3:
			draw_line(rock + Vector2.from_angle(k * 2.1) * 3, rock + Vector2.from_angle(k * 2.1 + 0.4) * 12, METEOR_LAVA, 2)
		return
	var burst := clampf((t - 0.35) / 0.65, 0.0, 1.0)
	var fade := 1.0 - burst
	for tile in effect.get("cells", []):
		var at := _center(tile)
		var half := Vector2.ONE * TILE * 0.5
		# Scorched ground glowing through molten cracks.
		draw_rect(Rect2(at - half, half * 2), Color(METEOR_ROCK, 0.75 * fade))
		draw_rect(Rect2(at - half, half * 2), Color(METEOR_LAVA, 0.35 * fade * (0.6 + 0.4 * sin(burst * 20.0))))
		var mark: int = int(tile.x) * 7 + int(tile.y) * 13
		for k in 3:
			var a := at + Vector2(sin(mark + k), cos(mark * 1.3 + k)) * TILE * 0.35
			var b := at + Vector2(cos(mark * 0.7 + k * 2.0), sin(mark + k * 1.7)) * TILE * 0.4
			draw_line(a, at, Color(METEOR_GOLD, fade), 3)
			draw_line(at, b, Color(METEOR_LAVA, fade), 2)
	# Flash, shockwave and embers thrown out.
	if burst < 0.15:
		draw_circle(pos, TILE * 1.6, Color(METEOR_CREAM, 0.8 * (1.0 - burst / 0.15)))
	draw_arc(pos, TILE * (0.7 + burst * 1.6), 0, TAU, 48, Color(METEOR_LAVA, fade), 6, true)
	draw_arc(pos, TILE * (0.5 + burst * 1.2), 0, TAU, 48, Color(METEOR_GOLD, fade * 0.8), 3, true)
	for k in 10:
		var dir := Vector2.from_angle(k * TAU / 10 + 0.3)
		var ember := pos + dir * TILE * (0.6 + burst * 1.8) + Vector2(0, burst * burst * 30)
		draw_rect(Rect2(ember - Vector2(3, 3), Vector2(6, 6)), Color(METEOR_GOLD if k % 2 == 0 else METEOR_LAVA, fade))

## A lethal bite: a big gold "99" that pops and rises, like the magic circle's.
func _draw_big_damage(pos: Vector2, fade: float, amount: int) -> void:
	var t := 1.0 - fade
	var size := int(46 * (1.0 + 0.6 * maxf(0.0, 1.0 - t / 0.25)))
	# Above the bite's "ガブッ！" (the sprites draw over the board, so not on the victim).
	var at := pos + Vector2(-size * 0.45, -50 - t * 18)
	var text := str(amount)
	for offset in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3)]:
		draw_string(LATIN, at + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.1, 0.02, 0.2, fade))
	draw_string(LATIN, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.83, 0.36, fade))

## The storm over the board: digital rain, the lightning sigil (one great shape in lights),
## and the tsunami (a crescent crest of cyan water) with where it will carry everyone.
func _draw_storm_frame() -> void:
	if not model.storm_active():
		return
	draw_set_transform(Vector2.ZERO)
	var extent := Vector2.ONE * model.board_size * TILE
	# Digital rain over the floor: small falling blocks.
	for k in range(36):
		var seed_x := fposmod(float(k) * 53.0 + 17.0, extent.x)
		var fall := fposmod(clock * (90.0 + (k % 5) * 25.0) + float(k) * 71.0, extent.y + 40.0) - 20.0
		var length := 14.0 + (k % 4) * 6.0
		draw_rect(Rect2(BOARD + Vector2(seed_x, fall), Vector2(3, length)), Color(0.45, 1.0, 0.9, 0.16))
	if shark_intro:
		_draw_shark_lurk()
		return
	_draw_tsunami()

## The entrance's first seven seconds: the board seen from above the water, the shark only a
## dark shape circling below, closing in on where it will rise as the music builds.
func _draw_shark_lurk() -> void:
	var t: float = clampf(shark_intro_t, 0.0, SHARK_LURK)
	var build := t / SHARK_LURK
	var extent := Vector2.ONE * model.board_size * TILE
	var mid := BOARD + extent / 2.0
	var u := TILE / 64.0
	draw_rect(Rect2(BOARD, extent), Color(0.0, 0.08, 0.16, 0.38 + 0.2 * build))
	# Light rippling on the water: slow bands of cyan sliding across.
	for k in range(7):
		var y := fposmod(clock * 22.0 + float(k) * extent.y / 7.0, extent.y)
		draw_rect(Rect2(BOARD + Vector2(0, y), Vector2(extent.x, 2.0)), Color(0.5, 1.0, 1.0, 0.05 + 0.05 * build))
	var shark := model.storm_shark()
	var home: Vector2 = mid
	if not shark.is_empty():
		home = BOARD + (Vector2(shark.cell) + Vector2.ONE) * TILE
	# The shadow: a wide ellipse around the board that tightens onto the spot it will rise from.
	var close := ease(clampf((t - 4.6) / 2.2, 0.0, 1.0), 0.5)
	var angle := 1.2 + t * (0.9 + 0.8 * build)
	var orbit := mid + Vector2(cos(angle) * extent.x * 0.36, sin(angle) * extent.y * 0.3)
	var at := orbit.lerp(home, close)
	var moving := Vector2(-sin(angle), cos(angle) * 0.8)
	var size := 156.0 * u * (1.05 + 0.5 * close)
	var shade := Color(0.0, 0.03, 0.08, 0.5 + 0.2 * close)
	var rect := Rect2(at - Vector2.ONE * size / 2.0, Vector2.ONE * size)
	if moving.x > 0.0 and close < 0.8:
		rect = Rect2(rect.position + Vector2(size, 0), Vector2(-size, size))
	draw_texture_rect(UnitView.STORM_SHARK, rect, false, shade)
	# Ripples breathing out of it, faster as the drop nears.
	var rate := 0.9 + 1.6 * build
	for k in range(4):
		var phase := fposmod(clock * rate + float(k) * 0.25, 1.0)
		draw_arc(at, (14.0 + phase * 110.0) * u, 0.0, TAU, 48, Color(0.55, 1.0, 1.0, (1.0 - phase) * (0.3 + 0.4 * build)), 2.0 * u)
	# Where it will break the surface: a hologram marker drawing itself in.
	if t > 3.0:
		var m := clampf((t - 3.0) / 4.0, 0.0, 1.0)
		var ring := TILE * 1.15
		draw_arc(home, ring, -PI / 2.0, -PI / 2.0 + TAU * m, 48, Color(0.6, 1.0, 1.0, 0.5 + 0.4 * m), 3.0 * u)
		draw_arc(home, ring * (0.55 + 0.1 * sin(clock * 9.0)), 0.0, TAU, 32, Color(1.0, 0.45, 0.5, 0.35 * m), 2.0 * u)
	# The last second: the whole board flickers with the riser.
	if t > 6.0:
		var flick := (t - 6.0) * (0.12 + 0.1 * sin(clock * 40.0))
		draw_rect(Rect2(BOARD, extent), Color(0.7, 1.0, 1.0, maxf(flick, 0.0)))

## The title card after the drop.
func _draw_shark_title() -> void:
	if shark_title_t < 0.0:
		return
	var fade := clampf(minf(shark_title_t / 0.25, (3.2 - shark_title_t) / 0.7), 0.0, 1.0)
	var glitch := Vector2(sin(clock * 53.0) * 5.0, 0.0) if shark_title_t < 0.5 else Vector2.ZERO
	var middle := BOARD + Vector2.ONE * model.board_size * TILE / 2.0
	var latin := "STORM SHARK"
	var jp := "嵐　鮫"
	var latin_w := 56.0 * 0.62 * float(latin.length())
	# On whichever half of the board the shark is not.
	var extent_y := model.board_size * TILE
	var shark := model.storm_shark()
	var shark_y: float = BOARD.y + (float(shark.cell.y) + 1.0) * TILE if not shark.is_empty() else middle.y
	var title_y: float = BOARD.y + extent_y * (0.8 if shark_y < middle.y else 0.2)
	var base := Vector2(BOARD.x + model.board_size * TILE / 2.0 - latin_w / 2.0, title_y)
	draw_string_outline(ui_font, base + glitch + Vector2(-3, 0), latin, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, 10, Color(0.02, 0.1, 0.12, 0.9 * fade))
	draw_string(ui_font, base + glitch + Vector2(-3, 0), latin, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(1.0, 0.3, 0.45, 0.45 * fade))
	draw_string(ui_font, base + glitch + Vector2(3, 0), latin, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(0.3, 0.5, 1.0, 0.45 * fade))
	draw_string(ui_font, base + glitch, latin, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(0.7, 1.0, 1.0, fade))
	var jp_base := base + Vector2(latin_w / 2.0 - 64.0, 56.0)
	draw_string_outline(ui_font, jp_base, jp, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, 8, Color(0.02, 0.1, 0.12, 0.9 * fade))
	draw_string(ui_font, jp_base, jp, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(0.6, 1.0, 0.95, fade))

## The tsunami's warning: the tiles it will cover washed in cyan, and where each thing it
## carries will land (the wave itself rushes over the board when the enemy turn begins: _draw_fx).
## The alert and its slide to the corner, drawn on the layer above the units.
func _draw_tsunami_alert() -> void:
	if model == null or model.storm.get("wind", Vector2i.ZERO) == Vector2i.ZERO or model.storm.get("wave", []).is_empty():
		return
	var age := clock - tsunami_alert_start
	if age >= TSUNAMI_ALERT_HOLD + TSUNAMI_ALERT_MOVE or tsunami_alert_round != model.round_number:
		return
	var canvas := tsunami_layer
	var label_at: Vector2 = BOARD + Vector2(0, -16)
	var extent := Vector2.ONE * model.board_size * TILE
	var middle := BOARD + extent / 2.0
	var move := clampf((age - TSUNAMI_ALERT_HOLD) / TSUNAMI_ALERT_MOVE, 0.0, 1.0)
	move = move * move * (3.0 - 2.0 * move)
	var flash := 0.5 + 0.5 * sin(clock * 14.0)
	var fade := 1.0 - move
	# For the first moments the whole alert strobes (a few quick blinks), then it holds steady.
	var blink := 1.0
	if age < 0.9:
		blink = 1.0 if sin(age * 44.0) > -0.2 else 0.3
	# The alert band: dark water with flashing cyan stripes above and below.
	var band := Rect2(BOARD.x, middle.y - 110.0, extent.x, 220.0)
	canvas.draw_rect(band, Color(0.01, 0.06, 0.1, 0.86 * fade * blink))
	var stripe := Color(0.4, 1.0, 1.0, (0.5 + 0.5 * flash) * fade * blink)
	canvas.draw_rect(Rect2(band.position, Vector2(band.size.x, 6.0)), stripe)
	canvas.draw_rect(Rect2(band.position + Vector2(0, band.size.y - 6.0), Vector2(band.size.x, 6.0)), stripe)
	if age < 0.9 and blink >= 1.0:
		canvas.draw_rect(Rect2(BOARD, extent), Color(0.5, 1.0, 1.0, 0.12 * fade))
	var big_size := 120
	var big_width := ui_font.get_string_size(tsunami_label, HORIZONTAL_ALIGNMENT_LEFT, -1, big_size).x
	var start_at := Vector2(middle.x - big_width / 2.0, middle.y + 20.0)
	var at := start_at.lerp(label_at, move)
	var size := int(lerpf(float(big_size), 56.0, move))
	var text_alpha := 1.0 if move > 0.0 else blink
	canvas.draw_string_outline(ui_font, at, tsunami_label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(0.02, 0.1, 0.12, 0.95 * text_alpha))
	var text_color := Color(0.6, 1.0, 0.95).lerp(Color.WHITE, flash * fade * 0.6)
	canvas.draw_string(ui_font, at, tsunami_label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(text_color, text_alpha))
	if move <= 0.0:
		var note := "あなた・召喚妖精が流される"
		var note_width := ui_font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		canvas.draw_string(ui_font, Vector2(middle.x - note_width / 2.0, middle.y + 66.0), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.85, 0.5, (0.6 + 0.4 * flash) * blink))
		var note2 := "（嵐鮫と設置物は動かない）"
		var note2_width := ui_font.get_string_size(note2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		canvas.draw_string(ui_font, Vector2(middle.x - note2_width / 2.0, middle.y + 96.0), note2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.8, 0.9, 0.9, 0.85 * blink))

const TSUNAMI_ALERT_HOLD := 1.4
const TSUNAMI_ALERT_MOVE := 0.6
var tsunami_alert_round := -1
var tsunami_layer: Node2D
var tsunami_label := ""
var tsunami_alert_start := -100.0
func _draw_tsunami() -> void:
	var wave: Array = model.storm.get("wave", [])
	var wind: Vector2i = model.storm.get("wind", Vector2i.ZERO)
	if wave.is_empty() or wind == Vector2i.ZERO:
		return
	var dir := Vector2(wind)
	var side := dir.orthogonal()
	var u := TILE / 64.0
	var swell := 0.16 + 0.06 * sin(clock * 3.0)
	for tile in wave:
		var rect := Rect2(BOARD + Vector2(tile) * TILE + Vector2.ONE * 2, Vector2.ONE * (TILE - 4))
		draw_rect(rect, Color(0.3, 0.85, 1.0, swell))
	# Where everyone it carries will land: a bold arrow and the landing tile, the player's boldest.
	for entry in _wave_plan():
		var is_player: bool = int(entry.id) == -1
		var size: int = entry.size
		var bold := 1.0 if is_player else 0.6
		var from_c: Vector2 = _center(entry.from) + Vector2.ONE * TILE / 2.0 * float(size - 1)
		var to_c: Vector2 = _center(entry.to) + Vector2.ONE * TILE / 2.0 * float(size - 1)
		var landing := Rect2(BOARD + Vector2(entry.to) * TILE + Vector2.ONE * 3, Vector2.ONE * (TILE * size - 6))
		if entry.to == entry.from:
			if is_player:
				draw_rect(landing, Color(1.0, 0.45, 0.4, 0.9), false, 3)
				_text(from_c + Vector2(-22, -TILE * 0.5 - 4), "動かない", 15, Color(1.0, 0.55, 0.5))
			continue
		var pulse := 0.6 + 0.4 * sin(clock * 7.0)
		# The way it sweeps them: the tiles on the road, then the landing tile.
		var road: Vector2i = entry.from
		while road != entry.to:
			road += wind
			if road != entry.to:
				draw_rect(Rect2(BOARD + Vector2(road) * TILE + Vector2.ONE * 6, Vector2.ONE * (TILE * size - 12)), Color(0.5, 1.0, 0.95, 0.09 * bold))
		draw_rect(landing, Color(0.5, 1.0, 0.95, (0.16 + 0.1 * pulse) * bold))
		draw_rect(landing, Color(0.7, 1.0, 1.0, bold), false, 4 if is_player else 2)
		var tail := from_c + dir * TILE * 0.18
		var tip := to_c - dir * TILE * 0.12
		var arrow_color := Color(0.8, 1.0, 1.0, bold)
		draw_line(tail, tip, arrow_color, 6 if is_player else 3)
		draw_line(tip, tip - dir * 18.0 + side * 13.0, arrow_color, 6 if is_player else 3)
		draw_line(tip, tip - dir * 18.0 - side * 13.0, arrow_color, 6 if is_player else 3)
	var wave_label: String = "津波 " + {Vector2i.UP: "↑", Vector2i.DOWN: "↓", Vector2i.LEFT: "←", Vector2i.RIGHT: "→"}.get(wind, "")
	var label_at: Vector2 = BOARD + Vector2(0, -16)
	# Each new turn the direction is announced as an alert in the middle of the board (the way Rotorick's
	# reel is), and then the words slide up to the corner where they stay. The alert is drawn on a layer
	# above the units, so the shark cannot hide it.
	# Not while the shark makes its entrance (its title card is on the board then): the alert waits for the end.
	if shark_intro or shark_title_t >= 0.0:
		tsunami_alert_round = -1
		return
	if tsunami_alert_round != model.round_number:
		tsunami_alert_round = model.round_number
		tsunami_alert_start = clock
	if tsunami_layer == null:
		tsunami_layer = Node2D.new()
		tsunami_layer.z_index = 6
		add_child(tsunami_layer)
		tsunami_layer.draw.connect(_draw_tsunami_alert)
	tsunami_label = wave_label
	tsunami_layer.queue_redraw()
	if clock - tsunami_alert_start < TSUNAMI_ALERT_HOLD + TSUNAMI_ALERT_MOVE:
		return
	draw_string_outline(ui_font, label_at, wave_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, 10, Color(0.02, 0.1, 0.12, 0.95))
	_text(label_at, wave_label, 56, Color(0.6, 1.0, 0.95))

## The lightning coming down: one great bolt per mino falls from the top of the screen onto it
## (thick, glowing, with forks), the mino's tiles blaze white and a shock ring rolls out.
func _draw_thunder_strike(effect: Dictionary, t: float, fade: float) -> void:
	var u := TILE / 64.0
	var drop := clampf(t / 0.12, 0.0, 1.0)
	var land := clampf((t - 0.12) / 0.88, 0.0, 1.0)
	var glow := 1.0 - land
	var groups: Array = effect.get("groups", [])
	if groups.is_empty():
		groups = [effect.get("cells", [])]
	# The whole board flashes at the moment of the strike.
	if t > 0.1:
		draw_rect(Rect2(BOARD, Vector2.ONE * model.board_size * TILE), Color(0.85, 0.97, 1.0, 0.28 * pow(glow, 2.0)))
	var flick := 1.0 if int(clock * 30.0) % 3 != 0 else 0.7
	for group in groups:
		if group.is_empty():
			continue
		var sum := Vector2.ZERO
		for tile in group:
			sum += Vector2(tile)
		var middle := sum / float(group.size())
		var target: Vector2i = group[0]
		for tile in group:
			if Vector2(tile).distance_to(middle) < Vector2(target).distance_to(middle):
				target = tile
		var hit := _center(target)
		var seed_v := float(target.x) * 5.1 + float(target.y) * 2.3
		var steps := 11
		var main := PackedVector2Array()
		for i in range(steps + 1):
			var k := float(i) / float(steps)
			var jitter := sin(float(i) * 2.3 + seed_v) * 30.0 * u * (1.0 - k * 0.75) if i > 0 and i < steps else 0.0
			main.append(Vector2(hit.x + jitter, lerpf(-20.0, hit.y, k)))
		var shown := PackedVector2Array()
		for i in main.size():
			if float(i) / float(steps) <= drop:
				shown.append(main[i])
		var body := 1.0 if drop < 1.0 else maxf(glow * 1.4, 0.0)
		body = minf(body, 1.0) * flick
		if shown.size() >= 2:
			draw_polyline(shown, Color(0.4, 0.8, 1.0, 0.22 * body), 56.0 * u)
			draw_polyline(shown, Color(0.55, 0.92, 1.0, 0.45 * body), 30.0 * u)
			draw_polyline(shown, Color(0.9, 1.0, 1.0, 0.9 * body), 15.0 * u)
			draw_polyline(shown, Color(1, 1, 1, body), 7.0 * u)
			# Forks: branches splitting off the bolt on the way down.
			for i in range(2, shown.size() - 1, 3):
				var side := 1.0 if (i / 3) % 2 == 0 else -1.0
				var fork := PackedVector2Array([shown[i], shown[i] + Vector2(side * 30.0, 34.0) * u, shown[i] + Vector2(side * 18.0, 70.0) * u, shown[i] + Vector2(side * 46.0, 104.0) * u])
				draw_polyline(fork, Color(0.6, 0.95, 1.0, 0.5 * body), 9.0 * u)
				draw_polyline(fork, Color(1, 1, 1, 0.9 * body), 3.5 * u)
		if drop >= 1.0:
			for tile in group:
				var at := BOARD + Vector2(tile) * TILE
				draw_rect(Rect2(at, Vector2.ONE * TILE), Color(1.0, 0.98, 0.8, 0.9 * glow))
				draw_rect(Rect2(at + Vector2.ONE * 4.0, Vector2.ONE * (TILE - 8.0)), Color(1, 1, 1, 0.7 * glow * glow))
			draw_circle(hit, (30.0 + 40.0 * land) * u, Color(1, 1, 1, 0.65 * glow))
			draw_arc(hit, (20.0 + land * 150.0) * u, 0.0, TAU, 48, Color(0.8, 1.0, 1.0, 0.9 * glow), (9.0 - 6.0 * land) * u)
			draw_arc(hit, (10.0 + land * 90.0) * u, 0.0, TAU, 40, Color(1, 1, 1, 0.8 * glow), 4.0 * u)

## クロス短剣's finisher: a flame slash and a lightning slash cross over the target in an X,
## then burst; the diagonal tiles the blow spreads to flash with small crosses.
func _draw_cross_strike(effect: Dictionary, pos: Vector2, t: float, fade: float) -> void:
	var u := TILE / 64.0
	var reach := TILE * 1.45
	var fire_a := pos + Vector2(-1.0, -0.8) * reach
	var fire_b := pos + Vector2(1.0, 0.9) * reach
	var bolt_a := pos + Vector2(-1.0, 0.8) * reach
	var bolt_b := pos + Vector2(1.0, -0.9) * reach
	# The flash behind the cross.
	draw_circle(pos, (26.0 + 80.0 * minf(t * 2.0, 1.0)) * u, Color(1, 0.97, 0.88, 0.5 * pow(fade, 2.0)))
	var fire_draw := clampf(t / 0.22, 0.0, 1.0)
	var bolt_draw := fire_draw
	var body := minf(1.0, fade * 1.6)
	# Flame slash: a curved sweep from the upper left to the lower right.
	if fire_draw > 0.0:
		var arc := PackedVector2Array()
		for i in range(0, 17):
			var k := float(i) / 16.0
			if k > fire_draw:
				break
			var bend := sin(k * PI) * 0.35 * reach
			arc.append(fire_a.lerp(fire_b, k) + Vector2(1, -1).normalized() * bend)
		if arc.size() >= 2:
			draw_polyline(arc, Color(1.0, 0.25, 0.1, 0.55 * body), 26.0 * u)
			draw_polyline(arc, Color(1.0, 0.55, 0.15, 0.85 * body), 15.0 * u)
			draw_polyline(arc, Color(1.0, 0.95, 0.6, body), 6.0 * u)
	# Lightning slash: a jagged bolt from the lower left to the upper right.
	if bolt_draw > 0.0:
		var jag := PackedVector2Array()
		for i in range(0, 13):
			var k := float(i) / 12.0
			if k > bolt_draw:
				break
			var wobble := Vector2(1, 1).normalized() * (sin(float(i) * 2.6 + t * 40.0) * 9.0 * u if i > 0 and i < 12 else 0.0)
			jag.append(bolt_a.lerp(bolt_b, k) + wobble)
		if jag.size() >= 2:
			draw_polyline(jag, Color(0.2, 0.55, 1.0, 0.5 * body), 24.0 * u)
			draw_polyline(jag, Color(0.45, 0.85, 1.0, 0.85 * body), 13.0 * u)
			draw_polyline(jag, Color(0.92, 0.98, 1.0, body), 5.0 * u)
	# The burst where they cross.
	if t > 0.2:
		var b := clampf((t - 0.2) / 0.8, 0.0, 1.0)
		draw_arc(pos, (14.0 + b * 90.0) * u, 0.0, TAU, 40, Color(1.0, 0.9, 0.7, (1.0 - b) * 0.9), (8.0 - 5.0 * b) * u)
		draw_arc(pos, (8.0 + b * 60.0) * u, 0.0, TAU, 32, Color(0.6, 0.9, 1.0, (1.0 - b) * 0.9), 4.0 * u)
		for i in range(10):
			var angle := TAU * float(i) / 10.0 + 0.3
			var spark_color: Color = Color(1.0, 0.6, 0.2) if i % 2 == 0 else Color(0.5, 0.85, 1.0)
			var from := pos + Vector2.from_angle(angle) * (16.0 + b * 40.0) * u
			var to := pos + Vector2.from_angle(angle) * (28.0 + b * 100.0) * u
			draw_line(from, to, Color(spark_color, (1.0 - b)), 3.0 * u)
	# The tiles the blow spreads to: a small flame-and-lightning cross on each.
	if t > 0.28:
		var s := clampf((t - 0.28) / 0.6, 0.0, 1.0)
		for tile in effect.get("cells", []):
			var c := _center(tile)
			var r := TILE * 0.32 * (0.6 + 0.4 * s)
			draw_line(c + Vector2(-r, -r), c + Vector2(r, r), Color(1.0, 0.55, 0.2, (1.0 - s)), 5.0 * u)
			draw_line(c + Vector2(-r, r), c + Vector2(r, -r), Color(0.5, 0.85, 1.0, (1.0 - s)), 5.0 * u)
			draw_circle(c, TILE * 0.22 * (1.0 - s), Color(1, 1, 1, 0.6 * (1.0 - s)))

## The drop: a white flash, shockwaves off the water, a column of light the shark is projected
## inside, glitch bars and a scan line sweeping the board.
func _draw_shark_emerge(effect: Dictionary, t: float, fade: float) -> void:
	var extent := Vector2.ONE * model.board_size * TILE
	var u := TILE / 64.0
	var at := BOARD + (Vector2(effect.cell) + Vector2.ONE) * TILE
	draw_rect(Rect2(BOARD, extent), Color(0.85, 1.0, 1.0, 0.75 * pow(fade, 3.0)))
	for k in range(3):
		var r := clampf(t * 1.8 - float(k) * 0.18, 0.0, 1.0)
		if r > 0.0:
			draw_arc(at, (20.0 + r * 330.0) * u, 0.0, TAU, 64, Color(0.6, 1.0, 1.0, (1.0 - r) * 0.9), (7.0 - 4.0 * r) * u)
	var width := TILE * 2.2 * (1.0 - clampf(t * 1.6, 0.0, 1.0)) + 6.0
	draw_rect(Rect2(at.x - width / 2.0, BOARD.y, width, at.y - BOARD.y + TILE), Color(0.6, 1.0, 1.0, 0.35 * fade))
	draw_rect(Rect2(at.x - width / 6.0, BOARD.y, width / 3.0, at.y - BOARD.y + TILE), Color(1, 1, 1, 0.6 * fade))
	if t < 0.55:
		for k in range(9):
			var seedv := float((int(clock * 24.0) * 31 + k * 17) % 97) / 97.0
			var y := BOARD.y + seedv * extent.y
			var shift := (float((k * 13 + int(clock * 24.0)) % 11) - 5.0) * 7.0
			draw_rect(Rect2(BOARD.x + shift, y, extent.x * (0.3 + 0.5 * seedv), 3.0 + 6.0 * seedv), Color(0.7, 1.0, 1.0, 0.45 * (1.0 - t / 0.55)))
	var sweep_y := BOARD.y + clampf(t * 1.6, 0.0, 1.0) * extent.y
	draw_rect(Rect2(BOARD.x, sweep_y - 2.0, extent.x, 4.0), Color(1, 1, 1, 0.8 * fade))

## The great wave itself: a body of water with a curling crest sweeping across the whole board
## the way the tsunami runs, foam and spray along its front, then draining away.
func _draw_tsunami_rush(effect: Dictionary, t: float, fade: float) -> void:
	var n := model.board_size
	var wdir: Vector2i = effect.dir
	var u := TILE / 64.0
	# One band of water runs the whole way across and off the far side: its front first, its
	# tail right behind, so the board is clear again once it has gone by.
	var sweep := clampf(t, 0.0, 1.0)
	var alpha := 1.0
	var to_world := func(a: float, lane: float) -> Vector2:
		var p := Vector2(a, lane)
		if wdir == Vector2i.LEFT:
			p = Vector2(float(n) - a, lane)
		elif wdir == Vector2i.DOWN:
			p = Vector2(lane, a)
		elif wdir == Vector2i.UP:
			p = Vector2(lane, float(n) - a)
		return BOARD + p * TILE
	var base := lerpf(-2.0, float(n) + 4.5, sweep)
	# [front lag, band thickness, colour]
	var layers := [[0.0, 4.2, Color(0.45, 0.95, 1.0, 0.55)], [-0.9, 3.4, Color(0.25, 0.7, 0.95, 0.5)], [-1.8, 2.6, Color(0.12, 0.45, 0.8, 0.5)]]
	var crest_points := PackedVector2Array()
	var tail_points := PackedVector2Array()
	for layer in layers:
		var lag: float = layer[0]
		var thick: float = layer[1]
		var front := PackedVector2Array()
		var tail := PackedVector2Array()
		for step in range(0, 41):
			var lane := float(step) / 40.0 * float(n)
			var bulge := sin(clampf((lane - 0.5) / float(n - 1), 0.0, 1.0) * PI) * 1.9
			var f := clampf(base + lag + bulge, 0.0, float(n))
			var r := clampf(base + lag + bulge - thick, 0.0, float(n))
			front.append(to_world.call(f, lane))
			tail.append(to_world.call(r, lane))
			if lag == 0.0:
				crest_points.append(to_world.call(base + bulge, lane))
				tail_points.append(to_world.call(base + bulge - thick, lane))
		tail.reverse()
		var poly := PackedVector2Array()
		poly.append_array(front)
		poly.append_array(tail)
		if poly.size() >= 4 and Geometry2D.triangulate_polygon(poly).size() >= 3:
			var color: Color = layer[2]
			draw_colored_polygon(poly, color)
	# Foam along the crest and spray thrown ahead of it.
	var clipped := PackedVector2Array()
	for point in crest_points:
		if Rect2(BOARD - Vector2.ONE * 6, Vector2.ONE * float(n) * TILE + Vector2.ONE * 12).has_point(point):
			clipped.append(point)
	if clipped.size() >= 2:
		draw_polyline(clipped, Color(0.95, 1.0, 1.0, 0.95 * alpha), 7.0 * u)
	var tail_clipped := PackedVector2Array()
	for point in tail_points:
		if Rect2(BOARD - Vector2.ONE * 6, Vector2.ONE * float(n) * TILE + Vector2.ONE * 12).has_point(point):
			tail_clipped.append(point)
	if tail_clipped.size() >= 2:
		draw_polyline(tail_clipped, Color(0.85, 1.0, 1.0, 0.55), 4.0 * u)
	var forward := Vector2(wdir)
	for i in range(0, crest_points.size(), 2):
		var point: Vector2 = crest_points[i]
		if not Rect2(BOARD, Vector2.ONE * float(n) * TILE).has_point(point):
			continue
		var wobble := sin(clock * 11.0 + float(i) * 1.7)
		draw_circle(point + forward * (6.0 + 6.0 * wobble) * u, (4.0 + 3.0 * absf(wobble)) * u, Color(1, 1, 1, 0.9 * alpha))
		if i % 4 == 0:
			draw_circle(point + forward * (18.0 + 10.0 * wobble) * u + forward.orthogonal() * 5.0 * wobble * u, 2.5 * u, Color(0.9, 1.0, 1.0, 0.8 * alpha))

## The wave's plan, worked out again only when something that matters has changed.
var _wave_key := ""
var _wave_cache: Array = []
func _wave_plan() -> Array:
	var key := str([model.storm.get("wind"), model.player.cell, model.round_number, model.enemies.map(func(e: Dictionary) -> Array: return [e.cell, e.hp, e.get("diving", false)]), model.allies.map(func(a: Dictionary) -> Array: return [a.cell, a.hp]), model.obstacles.size(), model.walls.size(), model.cannons.size()])
	if key != _wave_key:
		_wave_key = key
		_wave_cache = model.storm_wave_plan()
	return _wave_cache

## Fairy effects: small and quick, except the firework, which is allowed to show off.
const FX_LIFE = {"cross_strike":1.0, "emerge":1.6, "tsunami":2.6, "dive":0.8, "surface":0.9, "thunder":1.1, "thunder_warn":0.45, "knock":0.3, "knock_home":0.8, "barrier_block":0.8, "chain_cut":0.9, "barrier_break":1.7, "barrier_up":1.4, "wind":0.3, "bolt":0.42, "warp":0.42, "summon":0.5, "ambush":0.42, "shot":0.45, "muzzle":0.35, "slash":0.45, "blast":0.8, "firework":0.95, "javelin":0.4, "arrow":0.4, "quake":0.75, "dash":0.4, "roar":0.7, "burn":0.6, "awaken":0.9, "zap":0.45, "spark":0.35, "resonate":0.5, "push":0.35, "bump":0.5, "discharge":0.5, "block":0.45, "analyzed":0.6, "smash":0.5, "axe":0.7, "chalk":0.5, "circle":0.1, "pull":0.45, "swap":0.5, "bite":0.45, "fall":0.6, "gravity":0.6, "devour":0.85, "gulp":0.75, "windup":0.7, "freeze":0.8, "meteor":1.0, "chain":0.05, "heal":1.0, "time_stop":1.2}
const FIREWORK_COLORS = [Color("ff5b8a"), Color("ffd35b"), Color("6bdcff"), Color("b58cff"), Color("8dffb0")]

func _draw_fx(effect: Dictionary, pos: Vector2, fade: float) -> void:
	var t := 1.0 - fade
	var dir := Vector2(effect.get("dir", Vector2i.ZERO))
	match effect.kind:
		"time_stop":
			# 時の妖精: a golden clock swells over the board, its hand sweeps and stops dead.
			var extent := Vector2.ONE*model.board_size*TILE
			var middle := BOARD+extent/2
			draw_rect(Rect2(BOARD,extent),Color(1.0,0.9,0.6,0.35*fade*fade))
			var radius := extent.x*(0.2+0.18*ease(minf(t*2.0,1.0),0.4))
			_draw_clock_face(middle,radius,Color(TIME_GOLD,minf(1.0,fade*1.6)),ease(minf(t*1.6,1.0),0.3)*1.5)
			_text(middle+Vector2(-48,radius+40),"時間停止",24,Color(TIME_GOLD,fade))
		"freeze":
			# Frost spreading over the 3x3.
			for tile in effect.get("cells", []):
				var at := _center(tile)
				draw_rect(Rect2(at-Vector2.ONE*TILE*0.45,Vector2.ONE*TILE*0.9),Color(0.7,0.92,1.0,0.45*fade))
				for k in 3:
					var arm := Vector2.from_angle(k*PI/3+t)*TILE*0.3*(0.4+t)
					draw_line(at-arm,at+arm,Color(1,1,1,0.8*fade),2)
		"meteor":
			_draw_meteor(effect, pos, t)
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
			# Impact star where the enemy slams into something, and a big "ドンッ" when it
			# hit another enemy (against a wall it just stops: a small puff, no damage).
			var at := pos + dir * 30
			if not effect.get("hurt", true):
				draw_arc(at, 6 + t * 10, 0, TAU, 12, Color(1, 1, 1, fade * 0.7), 2)
				return
			for k in range(8):
				var ray := Vector2.from_angle(k * TAU / 8 + 0.2) * (8 + t * 22) * (1.0 if k % 2 == 0 else 0.6)
				draw_line(at, at + ray, Color(BUMP, fade), 4)
			draw_circle(at, 7 * (1.0 - t) + 2, Color(1, 1, 1, fade))
			# The word clears before the collision's "−1"s rise in the same place.
			if t < 0.5:
				var word_at := at + Vector2(-30, -30 - t * 10)
				var word := 1.0 - t * 2.0
				draw_string_outline(ui_font, word_at, "ドンッ", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color(0.05, 0.03, 0.02, word))
				draw_string(ui_font, word_at, "ドンッ", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(BUMP, word))
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
		"heal":
			# 加護の地: a heart and a green "+1" rise over the player.
			var rise := pos + Vector2(0, -34 - t * 22)
			_draw_heart(rise + Vector2(-14, 0), 18.0, Color("ff5b62", fade), true)
			_text(rise + Vector2(-2, 7), "+1", 20, Color("7dff9a", fade))
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
		"awaken":
			# A hot-pink shockwave and rising sparks.
			draw_arc(pos, 14 + t * 60, 0, TAU, 32, Color(1, 0.4, 0.78, fade), 5, true)
			draw_arc(pos, 8 + t * 36, 0, TAU, 32, Color(1, 0.85, 0.95, fade * 0.8), 3, true)
			for k in range(6):
				var ray := Vector2.from_angle(k * TAU / 6 + 0.4) * (16 + t * 40)
				draw_line(pos + ray * 0.6, pos + ray, Color(1, 0.7, 0.9, fade), 2)
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
			_draw_quake(effect, pos, t)
		"tsunami":
			_draw_tsunami_rush(effect, t, fade)
		"emerge":
			_draw_shark_emerge(effect, t, fade)
		"cross_strike":
			_draw_cross_strike(effect, pos, t, fade)
		"dive":
			# The shark breaks into glowing squares that drift apart.
			var heart := pos + Vector2.ONE * TILE / 2
			for k in range(18):
				var angle := float(k) * 2.4
				var out := (20.0 + float(k % 5) * 14.0) * t
				var block := heart + Vector2(cos(angle), sin(angle) * 0.7) * out + Vector2(0, -30.0 * t)
				draw_rect(Rect2(block - Vector2(4, 4), Vector2(8, 8)), Color(0.55, 1.0, 0.95, fade))
		"surface":
			# It comes up with a ring of cyan light running out across the shadow.
			var middle := pos + Vector2.ONE * TILE / 2
			draw_arc(middle, TILE * (0.6 + 2.2 * t), 0, TAU, 48, Color(0.6, 1.0, 1.0, fade), 5.0 * fade + 1)
			draw_circle(middle, TILE * 1.2 * fade, Color(0.6, 1.0, 0.95, 0.25 * fade))
		"thunder_warn":
			draw_circle(pos, 10 + 24 * t, Color(1.0, 0.95, 0.5, 0.5 * fade))
		"thunder":
			_draw_thunder_strike(effect, t, fade)
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
		"barrier_up":
			# The barrier rises: a red square swelling out to his 3x3, then holding.
			var up_centre := BOARD + Vector2(effect.cell) * TILE + Vector2.ONE * TILE / 2.0
			var half := TILE * (0.6 + 1.0 * minf(t * 2.0, 1.0))
			var up_box := Rect2(up_centre - Vector2.ONE * half, Vector2.ONE * half * 2.0)
			draw_rect(up_box, Color(1.0, 0.2, 0.2, 0.35 * fade))
			draw_rect(up_box, Color(1.0, 0.45, 0.45, fade), false, 7.0)
			draw_rect(up_box.grow(-8.0), Color(1, 1, 1, 0.6 * fade), false, 2.0)
			_text(up_centre + Vector2(-64, -TILE * 2.0 - t * 16.0), "障壁展開", 40, Color(1.0, 0.55, 0.55, fade))
		"barrier_block":
			# The shot is turned away: blue sparks ring the dome and "無敵" / "ブロック" rise.
			var block_at := BOARD + Vector2(effect.cell) * TILE + Vector2.ONE * TILE / 2.0
			var flash_box := Rect2(block_at - Vector2.ONE * TILE * 1.5, Vector2.ONE * TILE * 3.0).grow(3.0 + 10.0 * t)
			draw_rect(flash_box, Color(0.5, 0.85, 1.0, 0.28 * fade))
			draw_rect(flash_box, Color(0.7, 0.93, 1.0, fade), false, 6.0)
			for k in range(10):
				var ray := Vector2.from_angle(k * TAU / 10.0 + 0.3)
				draw_line(block_at + ray * TILE * (1.2 + 0.2 * t), block_at + ray * TILE * (1.5 + 0.5 * t), Color(0.8, 0.95, 1.0, fade), 3.0)
			_text(block_at + Vector2(-44, -TILE * 1.9 - t * 18.0), "無敵", 42, Color(0.62, 0.91, 1.0, fade))
			_text(block_at + Vector2(-44, -TILE * 1.9 + 30.0 - t * 18.0), "ブロック", 24, Color(1, 1, 1, fade))
		"chain_cut":
			# A fortress falls: its chain snaps in the middle, the halves recoil and sparks fly.
			var chain_from := BOARD + (Vector2(effect.cell) + Vector2.ONE) * TILE
			var chain_to := BOARD + (Vector2(effect.to) + Vector2(1.5, 1.5)) * TILE
			var mid := chain_from.lerp(chain_to, 0.5)
			var gap := 0.04 + 0.4 * t
			draw_line(chain_from, chain_from.lerp(chain_to, 0.5 - gap), Color(1.0, 0.35, 0.3, fade), 5.0)
			draw_line(chain_to, chain_to.lerp(chain_from, 0.5 - gap), Color(1.0, 0.35, 0.3, fade), 5.0)
			for k in range(12):
				var spark := Vector2.from_angle(k * TAU / 12.0 + 0.2) * (10.0 + 60.0 * t) * (1.0 if k % 2 == 0 else 0.6)
				draw_line(mid + spark * 0.5, mid + spark, Color(1.0, 0.9, 0.5, fade), 3.0)
			draw_circle(mid, 14.0 * (1.0 - t) + 3.0, Color(1, 1, 1, fade))
		"barrier_break":
			# The barrier shatters like glass: shards fly out and the words flash up.
			var shatter_at := BOARD + Vector2(effect.cell) * TILE + Vector2.ONE * TILE / 2.0
			draw_rect(Rect2(BOARD, Vector2.ONE * model.board_size * TILE), Color(1, 1, 1, 0.35 * fade * fade))
			for k in range(18):
				var direction := Vector2.from_angle(k * TAU / 18.0 + 0.1)
				var shard_at := shatter_at + direction * TILE * (1.0 + 2.6 * t) 
				var side := Vector2(-direction.y, direction.x)
				draw_colored_polygon(PackedVector2Array([shard_at + direction * 14.0, shard_at + side * 7.0, shard_at - side * 7.0]), Color(0.75, 0.93, 1.0, fade * 0.9))
			draw_rect(Rect2(shatter_at - Vector2.ONE * TILE * (1.5 + 1.6 * t), Vector2.ONE * TILE * (3.0 + 3.2 * t)), Color(0.8, 0.95, 1.0, fade), false, 6.0)
			var banner_at := BOARD + Vector2(model.board_size * TILE / 2.0, model.board_size * TILE * 0.28)
			_text(banner_at + Vector2(-132, 14), "障壁崩壊", 66, Color(0.62, 0.94, 1.0, minf(1.0, fade * 2.0)))
		"knock_home":
			# Blown back: speed lines streak from where it stood to where it lands, then an impact star.
			var half_span := Vector2.ONE * TILE / 2.0 * (1.0 if effect.get("big", false) else 0.0)
			var from_at := pos + half_span
			var to_at := _center(effect.to) + half_span
			var along := (to_at - from_at)
			var heading := along.normalized() if along.length() > 1.0 else Vector2.RIGHT
			var side := Vector2(-heading.y, heading.x)
			var head := from_at.lerp(to_at, ease(minf(t * 2.5, 1.0), 0.3))
			for k in range(5):
				var lane := side * (k - 2) * (16.0 if effect.get("big", false) else 10.0)
				draw_line(head + lane - heading * 90.0, head + lane, Color(1, 1, 1, fade * 0.8), 3)
				draw_line(from_at + lane, head + lane, Color(0.6, 0.85, 1.0, fade * 0.45), 2)
			if t > 0.25:
				var burst := (t - 0.25) / 0.75
				for k in range(10):
					var ray := Vector2.from_angle(k * TAU / 10 + 0.15) * (10 + burst * 34) * (1.0 if k % 2 == 0 else 0.6)
					draw_line(to_at + ray * 0.4, to_at + ray, Color(1, 0.9, 0.5, fade), 4)
				draw_arc(to_at, 12 + burst * 36, 0, TAU, 24, Color(1, 1, 1, fade * 0.8), 3, true)
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
	_text(Vector2(423,396),("HP %d回復・妖精の使用回数が回復" % model.win_heal if model.win_heal > 0 and model.player.hp < Rules.MAX_HP else "妖精の使用回数が回復") if won else "初期ビルドから再挑戦",16,MUTED)

