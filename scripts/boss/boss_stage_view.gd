extends Node2D
## Prototype stage: one fight against the 2x2 rook boss on the 6x6 board.

const Boss = preload("res://scripts/boss/rook_boss_model.gd")
const UnitView = preload("res://scripts/unit_view.gd")
const BgmPlayer = preload("res://scripts/audio/bgm_player.gd")
const BOSS_ATLAS = preload("res://assets/sprites/enemies/rook_boss_56.png")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const LATIN = preload("res://assets/fonts/VT323-Regular.ttf")
const TITLE_SCENE := "res://title.tscn"
const BOARD = Vector2(384,176)
const TILE = 64
const UI_SCALE := 1.5
const INK = Color("e5dfc5")
const MUTED = Color("92b3ae")
const CYAN = Color("2bdcc8")
const GOLD = Color("f4d56f")
const RED = Color("ff5b62")
const ARROWS = ["↑","→","↓","←"]
## Key 1/2/3 -> weapon index, matching the main battle (silver, gold, knight).
const WEAPON_KEYS = {KEY_1: 1, KEY_2: 0, KEY_3: 2}

var model := Boss.new()
var bgm: Node
var player_view: Node2D
var boss_pos := Vector2.ZERO
var boss_frame_state := 0
var boss_flash := 0.0
var shake := 0.0
var busy := false
var clock := 0.0
var hover_cell := Vector2i(-1,-1)
var generation := 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * UI_SCALE
	bgm = BgmPlayer.new()
	add_child(bgm)
	player_view = UnitView.new()
	player_view.kind = "player"
	player_view.z_index = 2
	add_child(player_view)
	_start()

func _start() -> void:
	generation += 1
	model.reset()
	boss_pos = _cell_pos(model.boss.origin)
	boss_frame_state = model.boss.state
	player_view.position = _center(model.player.cell)
	_sync_player()
	_boss_phase()

func _cell_pos(cell: Vector2i) -> Vector2:
	return BOARD + Vector2(cell) * TILE

func _center(cell: Vector2i) -> Vector2:
	return _cell_pos(cell) + Vector2(TILE, TILE) * 0.5

func _sync_player() -> void:
	player_view.hp = model.player.hp
	player_view.facing = model.facing
	player_view.weapon_row = Boss.WEAPON_ROWS[model.weapon]
	bgm.sync(model.terminal() and not busy, model.phase == Boss.Phase.WON)

# --- turn flow ------------------------------------------------------------

func _boss_phase() -> void:
	var run := generation
	busy = true
	_sync_player()
	await get_tree().create_timer(0.45).timeout
	if run != generation:
		return
	var hp_before: int = model.player.hp
	model.boss_turn()
	var action: Dictionary = model.last_boss_action
	var target := _cell_pos(action.to)
	if action.kind == "charge":
		# Keep the wind-up pose while it runs, then show the result.
		var tween := create_tween()
		tween.tween_property(self, "boss_pos", target, 0.08 + 0.05 * boss_pos.distance_to(target) / TILE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween.finished
		shake = 0.25
	elif action.kind == "brace" and boss_pos != target:
		var tween := create_tween()
		tween.tween_property(self, "boss_pos", target, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished
	elif action.kind == "melee":
		shake = 0.12
	if run != generation:
		return
	boss_pos = target
	boss_frame_state = model.boss.state
	if model.player.hp < hp_before:
		player_view.play_hit_reaction(Vector2(model.boss.charge_dir) if action.kind == "charge" else Vector2.ZERO)
	busy = false
	_sync_player()

func _player_act(cell: Vector2i) -> void:
	if busy or not model.player_action(cell):
		return
	if model.is_boss_cell(cell):
		boss_flash = 0.18
		if Boss.WEAPON_ROWS[model.weapon] == 2:
			player_view.play_sword_attack(model.facing)
	else:
		var tween := create_tween()
		tween.tween_property(player_view, "position", _center(model.player.cell), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_after_player_action()

func _after_player_action() -> void:
	_sync_player()
	if model.phase == Boss.Phase.PLAYER and model.player.ap <= 0:
		_end_turn()

func _end_turn() -> void:
	if busy or model.phase != Boss.Phase.PLAYER:
		return
	model.end_player_turn()
	_boss_phase()

# --- input ----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_cell = Vector2i(((event.position / UI_SCALE - BOARD) / TILE).floor())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := Vector2i(((event.position / UI_SCALE - BOARD) / TILE).floor())
		if model.inside(cell):
			_player_act(cell)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_start()
			KEY_ESCAPE:
				get_tree().change_scene_to_file(TITLE_SCENE)
			KEY_M:
				bgm.toggle_mute()
			KEY_SPACE:
				_end_turn()
			KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT:
				if not busy and model.turn_to([KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT].find(event.keycode)):
					_after_player_action()
			_:
				if WEAPON_KEYS.has(event.keycode) and not busy and model.equip(WEAPON_KEYS[event.keycode]):
					_after_player_action()

# --- drawing --------------------------------------------------------------

func _process(delta: float) -> void:
	clock += delta
	boss_flash = maxf(0.0, boss_flash - delta)
	shake = maxf(0.0, shake - delta)
	position = Vector2(sin(clock * 90.0), cos(clock * 70.0)) * shake * 14.0
	queue_redraw()

func _text(at: Vector2, text: String, size: int = 20, color: Color = INK, font: Font = FONT) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _panel(rect: Rect2) -> void:
	draw_rect(rect, Color("0b1415"))
	draw_rect(rect, Color("324843"), false, 2)
	draw_rect(rect.grow(-5), Color("1d2c29"), false, 1)

func _draw() -> void:
	draw_rect(Rect2(-40,-40,1232,800), Color("070b0d"))
	_panel(Rect2(24,24,1104,58))
	_text(Vector2(44,63), "BOSS TEST", 32, CYAN, LATIN)
	_text(Vector2(200,62), "飛車の大将", 25, INK)
	_text(Vector2(420,62), "ターン %02d" % model.round_number, 22, MUTED)
	_text(Vector2(700,62), "R やり直し   Esc タイトル   M 音楽", 18, MUTED)
	_draw_board()
	_draw_boss()
	_draw_player_panel()
	_draw_boss_panel()
	var status := "大将のターン" if busy else "あなたのターン"
	_text(Vector2(384,150), status, 26, GOLD if busy else CYAN)
	if model.terminal() and not busy:
		_draw_result()

func _draw_board() -> void:
	draw_rect(Rect2(BOARD - Vector2(12,12), Vector2(TILE * 6 + 24, TILE * 6 + 24)), Color("1b1d17"))
	var lane := model.charge_lane()
	var melee: Array[Vector2i] = []
	if model.boss.state == Boss.State.IDLE:
		melee = model.melee_cells()
	var legal: Array[Vector2i] = []
	if model.phase == Boss.Phase.PLAYER and not busy:
		legal = model.targets()
	var pulse := 0.55 + 0.45 * sin(clock * 6.0)
	for y in range(6):
		for x in range(6):
			var cell := Vector2i(x, y)
			var pos := _cell_pos(cell)
			var shade := 0.88 + float((x * 13 + y * 7) % 5) * 0.025
			draw_rect(Rect2(pos + Vector2(2,2), Vector2(60,60)), Color("665b48") * shade)
			draw_line(pos + Vector2(3,59), pos + Vector2(59,59), Color("38362a"), 2)
			draw_line(pos + Vector2(3,3), pos + Vector2(59,3), Color("766b54"), 1)
			if lane.has(cell):
				draw_rect(Rect2(pos + Vector2(2,2), Vector2(60,60)), Color(RED, 0.18 + 0.2 * pulse))
				_draw_chevron(_center(cell), Vector2(model.boss.charge_dir), Color(RED, 0.5 + 0.4 * pulse))
			elif melee.has(cell):
				draw_rect(Rect2(pos + Vector2(6,6), Vector2(52,52)), Color(RED, 0.5), false, 1)
			if legal.has(cell):
				var color := Color("ff805a") if model.is_boss_cell(cell) else GOLD
				draw_rect(Rect2(pos + Vector2(6,6), Vector2(52,52)), Color(color, 0.18))
				draw_rect(Rect2(pos + Vector2(6,6), Vector2(52,52)), Color(color, 0.75), false, 2)
			if cell == hover_cell:
				draw_rect(Rect2(pos + Vector2(3,3), Vector2(58,58)), Color("fff0bd"), false, 2)
			if cell == model.player.cell:
				draw_rect(Rect2(pos + Vector2(4,4), Vector2(56,56)), Color(CYAN, 0.8), false, 2)

func _draw_chevron(center: Vector2, dir: Vector2, color: Color) -> void:
	var side := Vector2(-dir.y, dir.x) * 12
	var tip := center + dir * 10
	draw_polyline(PackedVector2Array([tip - dir * 12 + side, tip, tip - dir * 12 - side]), color, 4)

func _draw_boss() -> void:
	var col: int = model.boss.facing
	var row := boss_frame_state
	var tint := Color("ff997e") if boss_flash > 0 else Color.WHITE
	draw_circle(boss_pos + Vector2(64, 108), 26, Color(0,0,0,0.3))
	draw_texture_rect_region(BOSS_ATLAS, Rect2(boss_pos + Vector2(0,-14), Vector2(128,128)), Rect2(col * 56, row * 56, 56, 56), tint)

func _draw_player_panel() -> void:
	_panel(Rect2(24,100,300,540))
	_text(Vector2(44,140), "探索者", 24, CYAN)
	_text(Vector2(44,180), "HP", 20, MUTED, LATIN)
	for i in range(5):
		draw_rect(Rect2(90 + i * 36, 164, 28, 18), RED if i < model.player.hp else Color("3a1c21"))
	_text(Vector2(44,216), "AP", 20, MUTED, LATIN)
	for i in range(2):
		draw_rect(Rect2(90 + i * 36, 200, 28, 18), GOLD if i < model.player.ap else Color("3a3420"))
	_text(Vector2(44,256), "向き  %s    [矢印キー 1 AP]" % ARROWS[model.facing], 18)
	_text(Vector2(44,296), "武器  [1/2/3 で持ち替え 1 AP]", 18, MUTED)
	var order := [1, 0, 2]
	for i in range(3):
		var w: int = order[i]
		var y := 322 + i * 40
		var active: bool = w == model.weapon
		if active:
			draw_rect(Rect2(40, y - 4, 268, 34), Color(CYAN, 0.12))
			draw_rect(Rect2(40, y - 4, 268, 34), CYAN, false, 2)
		_text(Vector2(52, y + 22), "[%d] %s" % [i + 1, Boss.WEAPON_NAMES[w]], 20, CYAN if active else INK)
	_text(Vector2(44,470), "盤面クリック：移動 / 攻撃", 17, MUTED)
	_text(Vector2(44,496), "Space：ターン終了", 17, MUTED)
	_text(Vector2(44,540), "赤い帯：次の突進の進路", 17, RED)
	_text(Vector2(44,566), "赤い枠：大将の薙ぎ払いの範囲", 17, Color(RED, 0.8))
	_text(Vector2(44,592), "斜めの角は届かない", 17, MUTED)

func _draw_boss_panel() -> void:
	_panel(Rect2(832,100,296,540))
	_text(Vector2(852,140), "飛車の大将", 24, RED)
	draw_rect(Rect2(852,158,256,16), Color("3a1c21"))
	draw_rect(Rect2(852,158,256.0 * maxi(model.boss.hp, 0) / Boss.BOSS_HP,16), RED)
	_text(Vector2(852,198), "HP %d / %d" % [maxi(model.boss.hp, 0), Boss.BOSS_HP], 18, MUTED)
	var state_text := ""
	var state_color := INK
	match model.boss.state:
		Boss.State.BRACE:
			state_text = "構え：次のターンに突進！"
			state_color = RED
		Boss.State.STUN:
			state_text = "気絶：攻撃が2倍！"
			state_color = GOLD
		_:
			state_text = "様子を見ている"
	draw_rect(Rect2(852,214,256,40), Color(state_color, 0.12))
	_text(Vector2(862,241), state_text, 19, state_color)
	_text(Vector2(852,290), "行動", 18, MUTED)
	var rules := ["飛車の動きで軸を合わせ、構える", "構えた次のターンに突進（2ダメ）", "壁に激突すると1ターン気絶", "隣接していれば薙ぎ払い（1ダメ）"]
	for i in range(rules.size()):
		_text(Vector2(852,316 + i * 26), "・" + rules[i], 15, INK)
	_text(Vector2(852,442), "ログ", 18, MUTED)
	for i in range(model.logs.size()):
		_text(Vector2(852,468 + i * 26), model.logs[i], 15, INK if i == 0 else MUTED)

func _draw_result() -> void:
	var won := model.phase == Boss.Phase.WON
	draw_rect(Rect2(384,300,384,136), Color("0a1415"))
	draw_rect(Rect2(384,300,384,136), CYAN if won else RED, false, 2)
	_text(Vector2(410,352), "BOSS DEFEATED" if won else "EXPEDITION FAILED", 34, CYAN if won else RED, LATIN)
	_text(Vector2(412,392), "%dターンで撃破！" % model.round_number if won else "探索者、倒れる", 22)
	_text(Vector2(412,422), "R でもう一度 / Esc でタイトル", 16, MUTED)
