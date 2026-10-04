extends Control
## The title screen: the five art layers (assets/title/, 1920x1080, stacked at the same
## origin and centred in the 1728-wide window), the fanfare-and-march title theme, and
## a two-item menu (GAME START / 実績) in big type. The art arrives with the music:
## the scene fades up under the timpani roll, the heroes and the Prison army step in
## and the logo lands on the first brass call, the menu appears, and the fanfare's
## final crash flashes the screen. Any key or click skips to the finished screen.
##
## After the fanfare the picture follows the music through its cue sheet (title_sync.gd,
## written by tools/generate_bgm.py): each part of the song grades the colours its own
## way (moonlit forest, red-lit war, cold cyber, both worlds together), the kick
## pulses the logo, the menu frame and the row of fairies, the war drums and the cyber
## kicks flare the lights of the Prison army, melody notes light ALAKAZAR's letters,
## shake fireflies loose and throw sparks, and the big hits bring a bolt of lightning,
## a shock ring and a flash. The build-up zooms in, the outro closes letterbox bars.

const Achievements = preload("res://scripts/title/achievements.gd")
const CatalogView = preload("res://scripts/ui/catalog_view.gd")
const Sync = preload("res://scripts/title/title_sync.gd")
const TitleFx = preload("res://scripts/title/title_fx.gd")
const TitleExtras = preload("res://scripts/title/title_extras.gd")
const GRADE_SHADER = preload("res://scripts/title/title_grade.gdshader")
const LOGO_SHADER = preload("res://scripts/title/title_logo.gdshader")
const LAYER_SHADER = preload("res://scripts/title/title_layer.gdshader")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const BACKGROUND = preload("res://assets/title/layer_00_background.png")
const Roster = preload("res://scripts/title/title_roster.gd")
const FairyBook = preload("res://scripts/fairy_book.gd")
const LaunchReset = preload("res://scripts/launch_reset.gd")
const ENEMIES = preload("res://assets/title/layer_20_enemies.png")
## Once the Prison King has been beaten (ALAKAZAR's KING): he lies in rubble where he stood
## (tools/make_fallen_king.py).
const ENEMIES_FALLEN = preload("res://assets/title/layer_20_enemies_fallen.png")
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
## The title theme: 100 BPM, the fanfare's bars.
const BAR := 60.0 / 100.0 * 4.0
const CALL_TIME := BAR  # the pipes' first call: the logo lands
const MENU_TIME := BAR + 0.9
const CRASH_TIME := BAR * 4.0  # the great D chord
const MUSIC_DB := -8.0
## On the web the browser keeps the sound off until the first click, so the screen waits for that click
## before it starts the song and the intro (otherwise the picture runs ahead of a song that has not begun).
##
## Web only: seconds added to the song position the picture follows. The browser reports no usable output
## latency, so none is subtracted; raise this if the picture runs behind the sound, lower it (below 0)
## if it runs ahead.
const WEB_AUDIO_OFFSET := 0.0

## How the picture is graded in each part of the song (the sections of the cue sheet):
## gain on the forest side (l) and the city side (r), saturation, brightness, vignette,
## scanlines, digital rain on the city side and on the forest side (dleft), whether the ordinary
## slanting rain falls at all (rain: not under the gentle horn of the fanfare), and how many
## seconds the change from the part before takes.
const GRADES := {
	"fanfare": {"l": Color(1.0, 1.0, 1.0), "r": Color(1.0, 1.0, 1.0), "sat": 1.0, "bri": 1.0, "vig": 0.25, "scan": 0.0, "digital": 0.0, "dleft": 0.0, "rain": 0.0, "blend": 1.0},
	"glen": {"l": Color(0.96, 1.07, 1.02), "r": Color(0.7, 0.76, 0.92), "sat": 0.95, "bri": 0.93, "vig": 0.4, "scan": 0.0, "digital": 0.0, "dleft": 0.0, "rain": 1.0, "blend": 1.4},
	"war": {"l": Color(0.98, 1.0, 0.94), "r": Color(1.22, 0.88, 0.84), "sat": 1.1, "bri": 1.0, "vig": 0.3, "scan": 0.0, "digital": 0.0, "dleft": 0.0, "rain": 1.0, "blend": 0.3},
	"cyber": {"l": Color(0.58, 0.84, 1.16), "r": Color(0.68, 1.0, 1.3), "sat": 0.55, "bri": 1.0, "vig": 0.4, "scan": 0.16, "digital": 1.0, "dleft": 0.0, "rain": 1.0, "blend": 0.2},
	"build": {"l": Color(0.7, 0.9, 1.25), "r": Color(0.82, 1.06, 1.38), "sat": 0.6, "bri": 1.06, "vig": 0.5, "scan": 0.22, "digital": 1.0, "dleft": 0.0, "rain": 1.0, "blend": 0.8},
	"climax": {"l": Color(0.92, 1.06, 1.3), "r": Color(1.0, 1.14, 1.42), "sat": 0.85, "bri": 1.16, "vig": 0.3, "scan": 0.1, "digital": 1.0, "dleft": 0.0, "rain": 1.0, "blend": 0.1},
	"finish": {"l": Color(0.7, 0.9, 1.2), "r": Color(0.76, 1.0, 1.26), "sat": 0.62, "bri": 1.0, "vig": 0.45, "scan": 0.14, "digital": 1.0, "dleft": 0.0, "rain": 1.0, "blend": 0.8},
	"outro": {"l": Color(0.55, 0.72, 0.98), "r": Color(0.6, 0.78, 1.04), "sat": 0.3, "bri": 0.62, "vig": 0.75, "scan": 0.1, "digital": 0.6, "dleft": 0.0, "rain": 1.0, "blend": 0.9},
	"fusion": {"l": Color(1.06, 1.12, 0.9), "r": Color(0.84, 1.06, 1.32), "sat": 1.32, "bri": 1.06, "vig": 0.3, "scan": 0.04, "digital": 0.8, "dleft": 0.6, "rain": 1.0, "blend": 0.12},
}
## The big hits: the flash (colour, strength), the jolt, the colour of the lightning, the
## colour split and the glitch bands.
const HITS := {
	"chord": {"flash": Color(1.0, 1.0, 1.0), "alpha": 0.5, "shake": 0.35, "bolt": Color(1.0, 0.85, 0.45), "split": 0.006, "glitch": 0.0},
	"war": {"flash": Color(1.0, 0.5, 0.4), "alpha": 0.3, "shake": 0.25, "bolt": Color(1.0, 0.4, 0.3), "split": 0.005, "glitch": 0.0},
	"cyber": {"flash": Color(0.75, 1.0, 1.0), "alpha": 0.45, "shake": 0.4, "bolt": Color(0.4, 0.95, 1.0), "split": 0.014, "glitch": 1.0},
	"climax": {"flash": Color(1.0, 1.0, 1.0), "alpha": 0.5, "shake": 0.45, "bolt": Color(0.7, 0.95, 1.0), "split": 0.016, "glitch": 0.7},
	"fusion": {"flash": Color(1.0, 0.95, 0.75), "alpha": 0.55, "shake": 0.5, "bolt": Color(1.0, 0.85, 0.5), "split": 0.018, "glitch": 0.5},
}
const ZOOM_BUILD := 0.07  # how far the build-up pushes in
const CLASH_X := 884.0  # where the two armies meet
const LETTERBOX := 84.0

const GOLD := Color("f2c14e")
const CREAM := Color("fff6e0")
const EDGE := Color("07080f")
## Menu items (from the art's layout.json, moved into the 1728 window).
const ITEM_CENTERS := [Vector2(864, 939), Vector2(864, 1013)]
const ITEM_SIZE := Vector2(402, 66)
const ITEM_FONT_SIZE := 56
## The ▶ glyph sits a little high in its line: nudged down to the text's middle.
const CURSOR_DROP := 3.0

var clock := 0.0
## Web: nothing starts until the first click (see ON_WEB).
var waiting_for_click := false
var click_prompt: Label
## How far the reveal has got (jumps ahead when the player skips the intro).
var reveal := 0.0
var selected := 0
var leaving := false
var crash_done := false
var call_done := false
## The cue sheet and the music clock (a number of seconds >= 0 here overrides the clock).
var sync: Sync
var override_time := -1.0
var song_t := 0.0
var prev_song_t := -1.0
var looped := false
var call_flash := 0.0
var kick_pulse := 0.0
var drum_pulse := 0.0
var shine := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
var grade: ColorRect
var logo_mat: ShaderMaterial
var heroes_mat: ShaderMaterial
var enemies_mat: ShaderMaterial
var window_mat: ShaderMaterial
var bar_top: ColorRect
var bar_bottom: ColorRect
var art: Control
var heroes: Control
## The hero side, one picture each: {id, item, node}; and the fairies used since the title
## was last shown (they step out of their silhouettes after the menu appears).
var hero_units: Array[Dictionary] = []
var fresh_items: Array[String] = []
var unlock_burst_done := false
var extras: Node2D
var enemies: TextureRect
var logo: TextureRect
var window: TextureRect
var menu: Control
var item_labels: Array[Label] = []
var item_glows: Array[Label] = []
var cursor: Label
var fx: TitleFx
var flash: ColorRect
var curtain: ColorRect
var music := AudioStreamPlayer.new()
var achievements_page: Control
var shake := 0.0

func _ready() -> void:
	# The trial version starts from nothing at every launch (once; not on coming back here).
	LaunchReset.start_session()
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
	sync = Sync.new()
	if not sync.load_sheet():
		push_warning("title theme cue sheet missing: the title screen will not follow the music")
		sync = null
	art.pivot_offset = VIEW / 2
	_layer(BACKGROUND)
	fx = TitleFx.new()
	art.add_child(fx)
	_build_heroes()
	# Fairies the art does not show yet stand in the free sky above them.
	extras = TitleExtras.new()
	heroes.add_child(extras)
	enemies = _layer(ENEMIES_FALLEN if Achievements.is_unlocked("alakazar_king") else ENEMIES)
	enemies_mat = _shade(enemies, LAYER_SHADER)
	# The sparks fly in front of the army.
	fx.sparks.reparent(art)
	art.move_child(fx.sparks, enemies.get_index() + 1)
	bar_top = _bar()
	bar_bottom = _bar()
	logo = _layer(LOGO)
	logo_mat = _shade(logo, LOGO_SHADER)
	logo_mat.set_shader_parameter("shine", shine)
	window = _layer(WINDOW)
	window_mat = _shade(window, LAYER_SHADER)
	grade = ColorRect.new()
	grade.size = VIEW
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade.material = ShaderMaterial.new()
	(grade.material as ShaderMaterial).shader = GRADE_SHADER
	add_child(grade)
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
	if OS.has_feature("web") and override_time < 0.0:
		waiting_for_click = true
		click_prompt = Label.new()
		click_prompt.text = "クリックしてスタート"
		click_prompt.add_theme_font_override("font", FONT)
		click_prompt.add_theme_font_size_override("font_size", 56)
		click_prompt.add_theme_color_override("font_color", CREAM)
		click_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		click_prompt.add_theme_constant_override("outline_size", 8)
		click_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		click_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		click_prompt.size = VIEW
		click_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(click_prompt)
	else:
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

## The hero and the fairies, one picture each, in their places on the art. A fairy that has
## not been used yet stands in the dark; the ones used since the title was last shown wait
## in the dark too, and step out of it when ALAKAZAR appears after the drum roll (_update_unlocks).
func _build_heroes() -> void:
	heroes = Control.new()
	heroes.size = Vector2(1920, 1080)
	heroes.position = ART_SHIFT
	heroes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(heroes)
	heroes_mat = ShaderMaterial.new()
	heroes_mat.shader = LAYER_SHADER
	fresh_items = FairyBook.unseen()
	FairyBook.mark_seen()
	for unit in Roster.heroes():
		var rect := TextureRect.new()
		rect.texture = unit.texture
		rect.position = unit.rect.position
		rect.size = unit.rect.size
		rect.pivot_offset = rect.size / 2.0
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.material = heroes_mat
		heroes.add_child(rect)
		hero_units.append({"id": unit.id, "item": unit.item, "node": rect})

func _shade(rect: TextureRect, shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	return material

## A letterbox bar (see _follow_music): above the army, under the logo.
func _bar() -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.size = Vector2(VIEW.x + 240, 120)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	art.add_child(bar)
	return bar

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
	# A small button in the corner opens the weapon and fairy catalog.
	var catalog_button := Button.new()
	catalog_button.text = "カタログ [C]"
	catalog_button.position = Vector2(1448, 1000)
	catalog_button.size = Vector2(240, 56)
	catalog_button.focus_mode = Control.FOCUS_NONE
	catalog_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	catalog_button.add_theme_font_override("font", FONT)
	catalog_button.add_theme_font_size_override("font_size", 30)
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.05, 0.09, 0.1, 0.85) if state == "normal" else Color(0.09, 0.17, 0.17, 0.95)
		box.border_color = CREAM if state == "normal" else GOLD
		box.set_border_width_all(3)
		box.set_corner_radius_all(8)
		catalog_button.add_theme_stylebox_override(state, box)
	catalog_button.add_theme_color_override("font_color", CREAM)
	catalog_button.add_theme_color_override("font_hover_color", GOLD)
	catalog_button.pressed.connect(_open_catalog)
	menu.add_child(catalog_button)
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
	cursor.position = Vector2(ITEM_CENTERS[selected].x - width / 2 - 64, ITEM_CENTERS[selected].y - 33 + CURSOR_DROP)
	cursor.size = Vector2(48, 66)
	cursor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

## The weapon and fairy catalog (C, or the button in the corner).
var catalog: Control
func _open_catalog() -> void:
	if leaving or reveal < MENU_TIME or is_instance_valid(achievements_page) or is_instance_valid(catalog):
		return
	catalog = CatalogView.new()
	add_child(catalog)
	move_child(catalog, curtain.get_index())

func _activate() -> void:
	if leaving or reveal < MENU_TIME or is_instance_valid(achievements_page) or is_instance_valid(catalog):
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
	if waiting_for_click:
		# The first click or key only starts the song (and the intro with it).
		waiting_for_click = false
		click_prompt.queue_free()
		music.play()
		get_viewport().set_input_as_handled()
		return
	# The first press during the intro only skips it.
	if reveal < MENU_TIME:
		reveal = MENU_TIME
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	if is_instance_valid(catalog):
		return
	if event.keycode == KEY_C and not is_instance_valid(achievements_page):
		_open_catalog()
		get_viewport().set_input_as_handled()
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
	if waiting_for_click:
		click_prompt.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 3.0)
		return
	clock += delta
	reveal = maxf(reveal + delta, clock)
	call_flash = maxf(0.0, call_flash - delta * 1.8)
	var flash_color := Color(1, 1, 1, call_flash)
	var jolt := 0.0
	if sync != null:
		var look := _follow_music(_song_time())
		if look.flash.a > call_flash:
			flash_color = look.flash
		jolt = look.jolt
	# Without the cue sheet the fanfare's last chord still flashes and jolts the screen.
	elif not crash_done and clock >= CRASH_TIME:
		crash_done = true
		call_flash = 0.55
		flash_color.a = 0.55
		shake = 0.35
	shake = maxf(0.0, shake - delta)
	flash.color = flash_color
	art.position = Vector2(sin(clock * 83.0), cos(clock * 71.0)) * 10.0 * maxf(shake, jolt)
	_update_reveal()
	# The selected item breathes a gold glow.
	for i in item_glows.size():
		var on := i == selected
		item_glows[i].add_theme_color_override("font_outline_color", Color(GOLD, (0.28 + 0.12 * sin(clock * 3.0)) if on else 0.0))
	cursor.modulate.a = 0.75 + 0.25 * sin(clock * 6.0)

## Where the song is, in seconds of the file (folded into the loop): what the speakers
## are playing now, from the audio clock (interpolated between mixes, less the output
## latency); the screen's own clock if the audio is not running.
func _song_time() -> float:
	if override_time >= 0.0:
		return sync.wrap(override_time)
	if music.playing and not (clock > 1.0 and music.get_playback_position() <= 0.0):
		var heard := music.get_playback_position() + AudioServer.get_time_since_last_mix()
		if OS.has_feature("web"):
			heard += WEB_AUDIO_OFFSET
		else:
			heard -= AudioServer.get_output_latency()
		return sync.wrap(maxf(heard, 0.0))
	return sync.wrap(clock)

## Moves the picture with the music at song time t. Cues that just happened (a note,
## a hit) start their particles; everything else is a function of how long ago the
## latest kick, drum or hit was, so it is right whatever the frame rate. Returns the
## hit's flash and jolt for _process.
func _follow_music(t: float) -> Dictionary:
	if prev_song_t >= 0.0 and t < prev_song_t - 1.0:
		looped = true
	if prev_song_t >= 0.0:
		_spawn_cues(prev_song_t, t)
	if t >= prev_song_t or t < prev_song_t - 1.0:
		prev_song_t = t
	song_t = t
	# The kick and the war drums pulse the picture.
	kick_pulse = sync.pulse("kick", t, 9.0)
	drum_pulse = sync.pulse("drum", t, 7.0)
	# The part of the song sets the colours (and how digital the rain is).
	var look := _grade_at(t)
	var energy := sync.energy(t)
	var hit := sync.last("hit", t)
	var since_hit: float = t - float(hit[0]) if not hit.is_empty() and float(hit[0]) <= t else INF
	var mood: Dictionary = HITS.get(str(hit[2]), HITS.fusion) if not hit.is_empty() else HITS.fusion
	var flash_a: float = mood.alpha * exp(-since_hit * 5.5) if since_hit < 2.0 else 0.0
	var split: float = mood.split * exp(-since_hit * 8.0) if since_hit < 2.0 else 0.0
	var tear: float = mood.glitch * clampf(1.0 - since_hit / 0.25, 0.0, 1.0)
	var jolt: float = mood.shake * clampf(1.0 - since_hit / 0.4, 0.0, 1.0)
	var flare := exp(-since_hit * 6.0) if since_hit < 2.0 else 0.0
	var gradient: ShaderMaterial = grade.material
	gradient.set_shader_parameter("gain_left", Vector3(look.l.r, look.l.g, look.l.b))
	gradient.set_shader_parameter("gain_right", Vector3(look.r.r, look.r.g, look.r.b))
	gradient.set_shader_parameter("saturation", look.sat)
	gradient.set_shader_parameter("brightness", look.bri * (0.92 + 0.08 * energy))
	gradient.set_shader_parameter("vignette", look.vig)
	gradient.set_shader_parameter("scan", look.scan)
	gradient.set_shader_parameter("aberration", split)
	gradient.set_shader_parameter("glitch", tear)
	gradient.set_shader_parameter("pulse", kick_pulse * 0.5)
	fx.digital = look.digital
	fx.rain = look.rain
	fx.digital_left = look.dleft
	fx.energy = energy
	# The Prison army's lights: red on the war drums, cyan on the cyber kicks.
	enemies_mat.set_shader_parameter("red_glow", drum_pulse * 1.4)
	enemies_mat.set_shader_parameter("cyan_glow", kick_pulse * look.digital * 1.1)
	heroes_mat.set_shader_parameter("lift", kick_pulse * 0.3)
	heroes_mat.set_shader_parameter("wave", kick_pulse * 0.004)
	heroes_mat.set_shader_parameter("wave_phase", t * 5.0)
	window_mat.set_shader_parameter("lift", kick_pulse * 0.9)
	# ALAKAZAR: each letter lights when the melody plays its note, and the logo flares and
	# a glint crosses it on a big hit.
	shine.fill(0.0)
	for row in sync.recent("note", t, 1.2):
		var letter := sync.letter_of(row)
		shine[letter] = maxf(shine[letter], exp(-(t - float(row[0])) * 3.2))
	logo_mat.set_shader_parameter("shine", shine)
	logo_mat.set_shader_parameter("flare", flare)
	logo_mat.set_shader_parameter("sweep", 400.0 + since_hit * 2800.0 if since_hit < 0.55 else -1.0)
	# The build-up pushes the camera in; the climax lets go with a rebound.
	var build := sync.start_of("build")
	var climax := sync.start_of("climax")
	var zoom := 1.0
	if t >= climax:
		zoom += ZOOM_BUILD * 0.45 * exp(-(t - climax) * 2.5)
	elif t >= build:
		zoom += ZOOM_BUILD * pow((t - build) / (climax - build), 2.0)
	art.scale = Vector2.ONE * zoom
	# Letterbox bars close in on the outro and are thrown open by the fusion's hit.
	var bars := 0.0
	var closing := sync.start_of("finish") + 1.0
	var fusion := sync.start_of("fusion")
	if t >= fusion:
		bars = LETTERBOX * exp(-(t - fusion) * 9.0)
	elif t >= closing:
		bars = LETTERBOX * smoothstep(closing, sync.start_of("outro"), t)
	bar_top.visible = bars > 0.5
	bar_bottom.visible = bars > 0.5
	bar_top.position = Vector2(-120, bars - 120)
	bar_bottom.position = Vector2(-120, VIEW.y - bars)
	return {"flash": Color(mood.flash, flash_a), "jolt": jolt}

## Starts the particles of the cues that came up between two readings of the clock.
func _spawn_cues(from: float, to: float) -> void:
	for row in sync.fresh("hit", from, to):
		fx.strike(HITS.get(str(row[2]), HITS.fusion).bolt, float(row[1]))
	for row in sync.fresh("harp", from, to):
		fx.twinkle(int(row[1]))
	for row in sync.fresh("clap", from, to):
		fx.spark_burst(randf_range(930.0, 1700.0), 5, Color(0.55, 1.0, 1.0, 0.8), 0.6)
	for row in sync.fresh("note", from, to):
		var pitch := int(row[1])
		match int(row[3]):
			0, 1:
				fx.pop_fly(pitch + int(float(row[0]) * 10.0))
			2:
				fx.spark_burst(lerpf(930.0, 1700.0, clampf((pitch - 72) / 18.0, 0.0, 1.0)), 11, Color(0.5, 1.0, 1.0, 0.9))
			_:
				# The fusion tune: gold sparks over the forest, cyan over the city.
				var x := lerpf(140.0, 1700.0, clampf((pitch - 70) / 16.0, 0.0, 1.0))
				fx.spark_burst(x, 9, Color(1.0, 0.88, 0.45, 0.9) if x < CLASH_X else Color(0.5, 1.0, 1.0, 0.9))
				if x < CLASH_X:
					fx.pop_fly(pitch)

## The grade at song time t: the part's own, eased in from the part before it.
func _grade_at(t: float) -> Dictionary:
	var index := sync.section_index(t)
	var current: Dictionary = GRADES.get(str(sync.sections[index][0]), GRADES.fanfare)
	var before: int = index - 1
	if index == 0:
		before = 0
	elif index == 1 and looped:
		before = sync.sections.size() - 1  # round again: the glen comes out of the fusion
	var previous: Dictionary = GRADES.get(str(sync.sections[before][0]), current)
	var f := smoothstep(0.0, 1.0, (t - sync.section_start(t)) / maxf(current.blend, 0.01))
	var mixed := {}
	for key in current:
		if key != "blend":
			mixed[key] = lerp(previous[key], current[key], f)
	return mixed

## Where everything stands at this point of the intro (also after a skip).
func _update_reveal() -> void:
	curtain.color.a = 1.0 - _ease(reveal, 0.0, 1.6) if not leaving else curtain.color.a
	var arrive := _ease(reveal, CALL_TIME - 1.2, CALL_TIME)
	var bob := sin(clock * 1.6) * 3.0 - kick_pulse * 7.0
	heroes.position = ART_SHIFT + HEROES_SHIFT + Vector2(-80 * (1.0 - arrive), bob)
	heroes.modulate.a = arrive
	_update_unlocks()
	enemies.position = ART_SHIFT + ENEMIES_SHIFT + Vector2(80 * (1.0 - arrive) + drum_pulse * 7.0, sin(clock * 1.2 + 1.0) * 3.0)
	enemies.modulate.a = arrive
	# The logo drops in on the brass call, a little large, and settles.
	var land := _ease(reveal, CALL_TIME - 0.12, CALL_TIME + 0.25)
	logo.modulate.a = land
	var swell := 1.0 + 0.12 * (1.0 - land) + 0.03 * kick_pulse
	logo.pivot_offset = Vector2(960, 150)
	logo.scale = Vector2.ONE * swell
	if not call_done and reveal >= CALL_TIME:
		call_done = true
		call_flash = maxf(call_flash, 0.35)
	var shown := _ease(reveal, MENU_TIME - 0.5, MENU_TIME)
	window.modulate.a = shown
	menu.modulate.a = shown
	fx.modulate.a = _ease(reveal, 0.3, 1.8)
	fx.sparks.modulate.a = fx.modulate.a

## Each fairy in colour once it has been used, as a silhouette before; the newly used ones
## step out of the dark just as ALAKAZAR appears after the drum roll (the brass call), with
## a pop, a white flash and a shower of gold sparks.
func _update_unlocks() -> void:
	var pop := reveal - CALL_TIME
	for unit in hero_units:
		var rect: TextureRect = unit.node
		var item: String = unit.item
		var used := item == "" or FairyBook.has_used(item)
		if used and item in fresh_items and pop < 0.0:
			used = false
		var bright := 1.0
		var grow := 1.0
		if used and item in fresh_items and pop < 0.7:
			var k := pow(1.0 - pop / 0.7, 2.0)
			grow = 1.0 + 0.4 * k
			bright = 1.0 + 1.6 * k
		rect.modulate = Color(bright, bright, bright, 1.0) if used else TitleExtras.LOCKED
		rect.scale = Vector2.ONE * grow
	if not unlock_burst_done and pop >= 0.0:
		unlock_burst_done = true
		# Only when it happens live (a skip jumps past it).
		if pop < 0.5:
			for unit in hero_units:
				if unit.item != "" and unit.item in fresh_items and FairyBook.has_used(unit.item):
					var rect: TextureRect = unit.node
					var x: float = rect.position.x + rect.size.x * 0.5 + ART_SHIFT.x + HEROES_SHIFT.x
					var y: float = rect.position.y + rect.size.y * 0.55 + ART_SHIFT.y
					fx.spark_burst(x, 18, Color(1.0, 0.85, 0.4), 0.45, y)
					fx.spark_burst(x, 10, Color(1.0, 1.0, 1.0), 0.3, y)

static func _ease(t: float, from: float, to: float) -> float:
	return ease(clampf((t - from) / (to - from), 0.0, 1.0), 0.4)

# --- 実績 ---------------------------------------------------------------------

const LOCKED_ICON := "res://assets/achievements/locked.png"

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
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 28)
			rows.add_child(row)
			# The icon: in colour once earned, a dark silhouette until then.
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(120, 120)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# Until it is earned: a "？" icon (the same frame colour for Y O U　 D I E D).
			icon.texture = load(entry.icon if unlocked else entry.get("locked_icon", LOCKED_ICON))
			row.add_child(icon)
			var text := VBoxContainer.new()
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(text)
			text.add_child(_row_label(("★ " if unlocked else "☆ ") + (str(entry.title) if unlocked else "？？？"), 44, Color(str(entry.get("title_color", "f4d56f"))) if unlocked else Color(str(entry.get("title_color", "8a949a")))))
			text.add_child(_row_label("？？？" if hidden else str(entry.get("description", "")), 30, CREAM if unlocked else Color("6f797e")))
			# A counting one shows how far it has got.
			var progress := Achievements.progress(entry.id)
			if not progress.is_empty():
				var done: int = progress[0]
				var line := _row_label("%s  %d / %d" % [entry.get("progress_label", "進捗"), done, progress[1]], 30, GOLD if unlocked else Color("2bdcc8"))
				text.add_child(line)
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
