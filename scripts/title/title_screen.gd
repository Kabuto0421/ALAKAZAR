extends Control
## The title screen: the five art layers (assets/title/, 1920x1080, stacked at the same
## origin and centred in the 1728-wide window), the fanfare-and-march title theme, and
## a two-item menu (GAME START / 実績) in big type. The art arrives with the music:
## the scene fades up under the timpani roll, the heroes and the Prison army step in
## and the logo lands on the first brass call, the menu appears, and the fanfare's
## final crash flashes the screen. Any key or click skips to the finished screen.

const Achievements = preload("res://scripts/title/achievements.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const BACKGROUND = preload("res://assets/title/layer_00_background.png")
const HEROES = preload("res://assets/title/layer_10_heroes.png")
const ENEMIES = preload("res://assets/title/layer_20_enemies.png")
const LOGO = preload("res://assets/title/layer_30_logo.png")
const WINDOW = preload("res://assets/title/layer_40_menu_window.png")
const MUSIC = preload("res://assets/audio/bgm/title_theme.ogg")
const GAME_SCENE := "res://main.tscn"

const VIEW := Vector2(1728, 1080)
## The art is 1920 wide: centred, 96px is cut from each side. The two armies are
## nudged in by 30px so nobody at the edges is clipped.
const ART_SHIFT := Vector2(-96, 0)
const HEROES_SHIFT := Vector2(30, 0)
const ENEMIES_SHIFT := Vector2(-30, 0)
## The title theme: 104 BPM, the fanfare's bars.
const BAR := 60.0 / 104.0 * 4.0
const CALL_TIME := BAR  # the first brass call: the logo lands
const MENU_TIME := BAR + 0.9
const CRASH_TIME := BAR * 4.0  # the great D major chord
const MUSIC_DB := -8.0

const GOLD := Color("f2c14e")
const CREAM := Color("fff6e0")
const EDGE := Color("07080f")
## Menu items (from the art's layout.json, moved into the 1728 window).
const ITEM_CENTERS := [Vector2(864, 939), Vector2(864, 1013)]
const ITEM_SIZE := Vector2(402, 66)
const ITEM_FONT_SIZE := 56

var clock := 0.0
## How far the reveal has got (jumps ahead when the player skips the intro).
var reveal := 0.0
var selected := 0
var leaving := false
var crash_done := false
var call_done := false
var art: Control
var heroes: TextureRect
var enemies: TextureRect
var logo: TextureRect
var window: TextureRect
var menu: Control
var item_labels: Array[Label] = []
var item_glows: Array[Label] = []
var cursor: Label
var fx: Node2D
var flash: ColorRect
var curtain: ColorRect
var music := AudioStreamPlayer.new()
var achievements_page: Control
var shake := 0.0

func _ready() -> void:
	size = VIEW
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.size = VIEW
	add_child(backdrop)
	art = Control.new()
	art.size = VIEW
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	_layer(BACKGROUND)
	fx = TitleFx.new()
	art.add_child(fx)
	heroes = _layer(HEROES)
	enemies = _layer(ENEMIES)
	logo = _layer(LOGO)
	window = _layer(WINDOW)
	_build_menu()
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = VIEW
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	curtain = ColorRect.new()
	curtain.color = Color.BLACK
	curtain.size = VIEW
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)
	music.stream = MUSIC
	music.volume_db = MUSIC_DB
	add_child(music)
	music.play()
	_select(0)
	_update_reveal()

func _layer(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.position = ART_SHIFT
	rect.size = texture.get_size()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(rect)
	return rect

func _build_menu() -> void:
	menu = Control.new()
	menu.size = VIEW
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	var texts := ["GAME START", "実績"]
	for i in texts.size():
		var rect := Rect2(ITEM_CENTERS[i] - ITEM_SIZE / 2, ITEM_SIZE)
		# A soft gold glow behind the selected item: the text's outline alone, wide.
		var glow := _menu_label(texts[i], rect)
		glow.add_theme_color_override("font_color", Color(0, 0, 0, 0))
		glow.add_theme_constant_override("outline_size", 26)
		glow.add_theme_color_override("font_outline_color", Color(GOLD, 0.0))
		menu.add_child(glow)
		item_glows.append(glow)
		var label := _menu_label(texts[i], rect)
		label.add_theme_constant_override("outline_size", 8)
		label.add_theme_color_override("font_outline_color", EDGE)
		menu.add_child(label)
		item_labels.append(label)
		# The whole row is the click target.
		var hit := Control.new()
		hit.position = rect.position
		hit.size = rect.size
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.mouse_entered.connect(func() -> void: _select(i))
		hit.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select(i)
				_activate())
		menu.add_child(hit)
	cursor = Label.new()
	cursor.text = "▶"
	cursor.add_theme_font_override("font", FONT)
	cursor.add_theme_font_size_override("font_size", 44)
	cursor.add_theme_color_override("font_color", GOLD)
	cursor.add_theme_constant_override("outline_size", 8)
	cursor.add_theme_color_override("font_outline_color", EDGE)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(cursor)

func _menu_label(text: String, rect: Rect2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", ITEM_FONT_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _select(index: int) -> void:
	if index != selected:
		selected = index
	for i in item_labels.size():
		item_labels[i].add_theme_color_override("font_color", GOLD if i == selected else CREAM)
	var label := item_labels[selected]
	var width := FONT.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ITEM_FONT_SIZE).x
	cursor.position = Vector2(ITEM_CENTERS[selected].x - width / 2 - 64, ITEM_CENTERS[selected].y - 33)
	cursor.size = Vector2(48, 66)
	cursor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _activate() -> void:
	if leaving or reveal < MENU_TIME or is_instance_valid(achievements_page):
		return
	if selected == 0:
		_start_game()
	else:
		_open_achievements()

func _start_game() -> void:
	leaving = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(curtain, "color:a", 1.0, 0.8)
	tween.tween_property(music, "volume_db", -40.0, 0.8)
	tween.chain().tween_callback(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))

func _unhandled_input(event: InputEvent) -> void:
	if leaving:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	# The first press during the intro only skips it.
	if reveal < MENU_TIME:
		reveal = MENU_TIME
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	if is_instance_valid(achievements_page):
		if event.keycode in [KEY_ESCAPE, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z, KEY_X]:
			_close_achievements()
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_UP, KEY_W:
			_select((selected + item_labels.size() - 1) % item_labels.size())
		KEY_DOWN, KEY_S:
			_select((selected + 1) % item_labels.size())
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z:
			_activate()
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	clock += delta
	reveal = maxf(reveal + delta, clock)
	_update_reveal()
	# The fanfare's last chord: a white flash and a jolt, in time with the music.
	if not crash_done and clock >= CRASH_TIME:
		crash_done = true
		flash.color.a = maxf(flash.color.a, 0.55)
		shake = 0.35
	flash.color.a = maxf(0.0, flash.color.a - delta * 1.8)
	shake = maxf(0.0, shake - delta)
	art.position = Vector2(sin(clock * 83.0), cos(clock * 71.0)) * 10.0 * shake
	# The selected item breathes a gold glow.
	for i in item_glows.size():
		var on := i == selected
		item_glows[i].add_theme_color_override("font_outline_color", Color(GOLD, (0.28 + 0.12 * sin(clock * 3.0)) if on else 0.0))
	cursor.modulate.a = 0.75 + 0.25 * sin(clock * 6.0)

## Where everything stands at this point of the intro (also after a skip).
func _update_reveal() -> void:
	curtain.color.a = 1.0 - _ease(reveal, 0.0, 1.6) if not leaving else curtain.color.a
	var arrive := _ease(reveal, CALL_TIME - 1.2, CALL_TIME)
	var bob := sin(clock * 1.6) * 3.0
	heroes.position = ART_SHIFT + HEROES_SHIFT + Vector2(-80 * (1.0 - arrive), bob)
	heroes.modulate.a = arrive
	enemies.position = ART_SHIFT + ENEMIES_SHIFT + Vector2(80 * (1.0 - arrive), sin(clock * 1.2 + 1.0) * 3.0)
	enemies.modulate.a = arrive
	# The logo drops in on the brass call, a little large, and settles.
	var land := _ease(reveal, CALL_TIME - 0.12, CALL_TIME + 0.25)
	logo.modulate.a = land
	var swell := 1.0 + 0.12 * (1.0 - land)
	logo.pivot_offset = Vector2(960, 150)
	logo.scale = Vector2.ONE * swell
	if not call_done and reveal >= CALL_TIME:
		call_done = true
		flash.color.a = maxf(flash.color.a, 0.35)
	var shown := _ease(reveal, MENU_TIME - 0.5, MENU_TIME)
	window.modulate.a = shown
	menu.modulate.a = shown
	fx.modulate.a = _ease(reveal, 0.3, 1.8)

static func _ease(t: float, from: float, to: float) -> float:
	return ease(clampf((t - from) / (to - from), 0.0, 1.0), 0.4)

# --- 実績 ---------------------------------------------------------------------

func _open_achievements() -> void:
	achievements_page = Control.new()
	achievements_page.size = VIEW
	add_child(achievements_page)
	move_child(achievements_page, curtain.get_index())
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, 0.82)
	dim.size = VIEW
	achievements_page.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(234, 110)
	panel.size = Vector2(1260, 860)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b1218")
	style.border_color = GOLD
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(GOLD, 0.25)
	style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", style)
	achievements_page.add_child(panel)
	var all: Array[Dictionary] = Achievements.all()
	_page_label(panel, "実績", Vector2(0, 34), Vector2(1260, 90), 72, GOLD, true)
	_page_label(panel, "解除 %d / %d" % [Achievements.unlocked_count(), all.size()], Vector2(0, 130), Vector2(1260, 50), 34, CREAM, true)
	if all.is_empty():
		_page_label(panel, "実績は準備中です", Vector2(0, 330), Vector2(1260, 80), 54, CREAM, true)
		_page_label(panel, "これから追加されます。お楽しみに！", Vector2(0, 420), Vector2(1260, 60), 34, Color("b9c4c9"), true)
	else:
		var scroll := ScrollContainer.new()
		scroll.position = Vector2(60, 200)
		scroll.size = Vector2(1140, 520)
		panel.add_child(scroll)
		var rows := VBoxContainer.new()
		rows.custom_minimum_size = Vector2(1120, 0)
		rows.add_theme_constant_override("separation", 18)
		scroll.add_child(rows)
		for entry in all:
			var unlocked := Achievements.is_unlocked(entry.id)
			var hidden: bool = entry.get("hidden", false) and not unlocked
			var name_label := _row_label(("★ " if unlocked else "☆ ") + ("？？？" if hidden else str(entry.title)), 40, GOLD if unlocked else Color("8a949a"))
			rows.add_child(name_label)
			rows.add_child(_row_label("？？？" if hidden else str(entry.get("description", "")), 28, CREAM if unlocked else Color("6f797e")))
	var back := Button.new()
	back.text = "戻る  [Esc]"
	back.add_theme_font_override("font", FONT)
	back.add_theme_font_size_override("font_size", 44)
	back.position = Vector2(430, 742)
	back.size = Vector2(400, 84)
	back.focus_mode = Control.FOCUS_NONE
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("172b2b") if state != "normal" else Color("0c181b")
		button_style.border_color = GOLD if state != "normal" else CREAM
		button_style.set_border_width_all(3)
		button_style.set_corner_radius_all(8)
		back.add_theme_stylebox_override(state, button_style)
	back.add_theme_color_override("font_color", CREAM)
	back.add_theme_color_override("font_hover_color", GOLD)
	back.pressed.connect(_close_achievements)
	panel.add_child(back)

func _page_label(parent: Control, text: String, at: Vector2, box: Vector2, font_size: int, color: Color, centered: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = box
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", EDGE)
	parent.add_child(label)
	return label

func _row_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _close_achievements() -> void:
	if is_instance_valid(achievements_page):
		achievements_page.queue_free()
		achievements_page = null

func _exit_tree() -> void:
	music.stop()

## Fireflies drifting in the moonlit forest (left) and rain slanting through the
## neon prison city (right), over the painted background.
class TitleFx extends Node2D:
	var flies: Array = []
	var drops: Array = []
	var time := 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2207
		for i in 34:
			flies.append([Vector2(rng.randf_range(20, 820), rng.randf_range(330, 1040)), rng.randf_range(0, TAU), rng.randf_range(0.5, 1.2)])
		for i in 150:
			drops.append([Vector2(rng.randf_range(880, 1760), rng.randf_range(0, 1080)), rng.randf_range(900, 1300), rng.randf_range(14, 26)])

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		for fly in flies:
			var phase: float = fly[1] + time * fly[2]
			var at: Vector2 = fly[0] + Vector2(sin(phase * 0.7) * 26, cos(phase * 0.5) * 18)
			var glow := 0.35 + 0.65 * maxf(0.0, sin(phase * 1.8))
			draw_circle(at, 7, Color(0.75, 1.0, 0.45, 0.10 * glow))
			draw_circle(at, 2.6, Color(0.92, 1.0, 0.62, 0.85 * glow))
		for drop in drops:
			var speed: float = drop[1]
			var y := fposmod(drop[0].y + time * speed, 1100.0) - 20.0
			var x: float = drop[0].x - (y - drop[0].y) * 0.12
			var x0 := fposmod(x - 880.0, 880.0) + 880.0
			draw_line(Vector2(x0, y), Vector2(x0 - drop[2] * 0.12, y - drop[2]), Color(1.0, 0.8, 0.9, 0.22), 2)
