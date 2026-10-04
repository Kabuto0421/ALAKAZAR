extends SceneTree
## Records one shot of the PV from the real game. Run it with Godot's movie writer so every frame
## is rendered at a fixed 30 fps (and the clip is exactly as long as the shot):
##   xvfb-run godot --rendering-driver opengl3 --path . --write-movie build/pv/<shot>.avi \
##       --fixed-fps 30 --resolution 1728x1080 --script res://tools/pv/pv_shot.gd -- <shot>
## tools/pv/make_pv.py runs every shot and puts them together with the title theme.

const RunView = preload("res://scripts/run/run_view.gd")
const Weapons = preload("res://scripts/run/weapon_catalog.gd")
const FPS := 30

var view
var bv
var m
var run

func _init() -> void:
	load("res://scripts/fairy_book.gd").recording = false
	load("res://scripts/title/achievements.gd").recording = false
	load("res://scripts/battle_view.gd").help_seen = true
	root.size = Vector2i(1728, 1080)
	var args := OS.get_cmdline_user_args()
	var shot: String = args[0] if args.size() > 0 else ""
	await _run(shot)
	quit()

func _run(shot: String) -> void:
	if shot.begins_with("art_pn_"):
		await portrait(shot.substr(7), true)
	elif shot.begins_with("art_p_"):
		await portrait(shot.substr(6), false)
	elif has_method("shot_" + shot):
		await call("shot_" + shot)
	else:
		push_error("no such shot: " + shot)

# ---- helpers -------------------------------------------------------------------

func frames(count: int) -> void:
	for i in count:
		await process_frame

func seconds(s: float) -> void:
	await frames(roundi(s * FPS))

## Waits until the battle view has finished animating whatever it was doing (at most `limit` seconds).
func idle(limit: float = 6.0) -> void:
	var left := roundi(limit * FPS)
	while bv.busy and left > 0:
		await process_frame
		left -= 1

func weapon_index(id: String) -> int:
	return Weapons.DATA.map(func(w): return w.id).find(id)

var cover: CanvasLayer

## A real run's battle screen on the given level (entrance cinematics included), with the given
## weapons (ids or indexes) and fairies ready. The screen stays black until `uncover()`.
func boot(level: int, weapons: Array, fairies: Array, plus: Dictionary = {}, uncover_now: bool = true, boss2_variant: int = 0) -> void:
	# Every achievement is already earned (in memory only), so no toast pops up over the footage.
	var Achievements = load("res://scripts/title/achievements.gd")
	Achievements._loaded = true
	for definition in Achievements.DEFINITIONS:
		Achievements._unlocked[definition.id] = true
	cover = CanvasLayer.new()
	cover.layer = 100
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(1728, 1080)
	cover.add_child(black)
	root.add_child(cover)
	view = RunView.new()
	root.add_child(view)
	await process_frame
	run = view.run
	run.start(3)
	run.choose(0)
	run.choose(0)
	view._render()
	await frames(8)
	bv = view.battle_view
	m = run.battle
	m.boss2_variant = boss2_variant
	m.owned_weapons.assign(weapons.map(func(w): return w if w is int else weapon_index(w)))
	m.fairy_loadout.assign(fairies)
	m.fairy_plus.clear()
	for id in plus:
		m.fairy_plus[id] = int(plus[id])
	bv._start(level, true)
	m.weapon = m.owned_weapons[0]
	m.refill_fairies()
	bv._sync_units(false)
	bv._update_controls()
	bv.queue_redraw()
	await frames(4)
	if uncover_now:
		uncover()

func uncover() -> void:
	if cover != null:
		cover.queue_free()
		cover = null

## Replace the enemies: [[type, cell, hp?], ...] and the player's cell.
func arrange(player_cell: Vector2i, foes: Array) -> void:
	# The old enemies' pictures go too (they are keyed by id, and the new ones reuse the ids).
	for id in bv.actors.keys():
		if int(id) >= 0:
			bv.actors[id].queue_free()
			bv.actors.erase(id)
	m.enemies.clear()
	m.obstacles.clear()
	var id := 0
	for foe in foes:
		var enemy: Dictionary = m.make_enemy(foe[0], foe[1], id)
		if foe.size() > 2:
			enemy.hp = foe[2]
		m.enemies.append(enemy)
		id += 1
	m.player.cell = player_cell
	m.player.ap = 2
	bv._sync_units(false)
	bv._update_controls()
	bv.queue_redraw()

## Click a board cell like the player would.
func click(cell: Vector2i) -> void:
	bv._act(cell)
	await frames(2)
	await idle()

func fairy(id: String, cell: Vector2i, direction: Vector2i = Vector2i.ZERO) -> void:
	bv._select_item(id)
	await frames(2)
	bv._item_act(cell)
	if direction != Vector2i.ZERO:
		await frames(2)
		bv._item_act(cell + direction)
	await frames(2)
	await idle()

func end_turn() -> void:
	bv._enemy_turn()
	await frames(2)
	await idle(10.0)

# ---- shots ---------------------------------------------------------------------

## The guardian fairy lands and calls everything back; then the allies go to work.
func shot_guardian() -> void:
	await boot(8, ["eight_knight", "lance", "hammer"], ["holy_spirit", "guardian_fairy", "lone_wolf"], {"holy_spirit": 1, "guardian_fairy": 1})
	await seconds(0.5)
	var spots: Array = m.item_targets("holy_spirit")
	print("PV holy spots ", spots.size(), " ", spots.slice(0, 4))
	await fairy("holy_spirit", spots[0])
	await seconds(0.3)
	var gspots: Array = m.item_targets("guardian_fairy")
	print("PV guardian spots ", gspots.size())
	await fairy("guardian_fairy", gspots[0])
	await seconds(0.5)
	await end_turn()
	await seconds(0.5)

## Four meteors on a crowd standing where the knight sword reaches.
func shot_meteor() -> void:
	await boot(9, ["eight_knight", "lance", "hammer"], ["meteor_fairy", "magic_bolt", "wall_fairy"], {"meteor_fairy": 3})
	var spots := [Vector2i(1, 2), Vector2i(1, 4), Vector2i(2, 1), Vector2i(2, 5), Vector2i(4, 1), Vector2i(4, 5), Vector2i(5, 2), Vector2i(5, 4)]
	var foes: Array = []
	var kinds := ["heavy", "executioner", "horse", "gold", "javelin", "silver", "cavalry", "analyst"]
	for k in spots.size():
		foes.append([kinds[k], spots[k], 2])
	foes.append(["prison", Vector2i(5, 3), 2])
	arrange(Vector2i(3, 3), foes)
	await seconds(1.2)
	await fairy("meteor_fairy", m.player.cell)
	await seconds(2.0)

## A web of cannons: one blow on the first sets off the rest (CHAIN x n).
func shot_chain() -> void:
	await boot(9, ["forward", "lance", "hammer"], ["cannon_fairy", "magic_bolt", "wall_fairy"])
	arrange(Vector2i(0, 3), [["heavy", Vector2i(4, 3), 3], ["horse", Vector2i(6, 3), 3], ["javelin", Vector2i(3, 0)], ["javelin", Vector2i(3, 2)], ["executioner", Vector2i(5, 6)], ["gold", Vector2i(4, 5)], ["silver", Vector2i(6, 1)], ["analyst", Vector2i(5, 2)]])
	m.place_cannon(Vector2i(1, 3), Vector2i.RIGHT, "lance")
	m.place_cannon(Vector2i(3, 3), Vector2i.UP, "lance")
	m.place_cannon(Vector2i(5, 3), Vector2i.DOWN, "lance")
	m.place_cannon(Vector2i(3, 1), Vector2i.RIGHT, "lance")
	m.place_cannon(Vector2i(5, 5), Vector2i.LEFT, "lance")
	m.place_cannon(Vector2i(5, 1), Vector2i.DOWN, "lance")
	m.weapon = 0
	bv._sync_units(false)
	bv.queue_redraw()
	await seconds(1.0)
	await click(Vector2i(1, 3))
	await seconds(1.5)

## The hammer comes down on a crowd.
func shot_hammer() -> void:
	await boot(9, ["hammer", "forward", "lance"], ["magic_bolt", "wall_fairy", "stealth_fairy"])
	arrange(Vector2i(1, 3), [["heavy", Vector2i(2, 3), 3], ["executioner", Vector2i(2, 2), 3], ["horse", Vector2i(2, 4), 3], ["gold", Vector2i(3, 3), 3], ["javelin", Vector2i(4, 3)], ["silver", Vector2i(3, 1)], ["cavalry", Vector2i(3, 5)]])
	m.weapon = 0
	await seconds(0.8)
	await click(Vector2i(2, 3))
	await seconds(1.5)

## Rotorick's casino.
func shot_rotorick() -> void:
	await boot(7, ["lance", "forward", "hammer"], ["magic_bolt", "wall_fairy", "stealth_fairy"])
	await seconds(4.0)
	await end_turn()
	await seconds(1.0)
	await end_turn()
	await seconds(1.0)

## The storm shark.
func shot_shark() -> void:
	await boot(7, ["lance", "forward", "hammer"], ["magic_bolt", "wall_fairy", "stealth_fairy"], {}, true, 1)
	await seconds(9.0)

## The Prison King.
func shot_king() -> void:
	await boot(12, ["lance", "forward", "hammer"], ["magic_bolt", "wall_fairy", "stealth_fairy"])
	await seconds(5.0)
	for king in m.enemies:
		if king.type == "king":
			king.hp = 5
	m._check_rage()
	bv._feedback()
	await seconds(4.0)

# ---- art shots (the title's own pictures, moved like a camera) ------------------------

const TITLE_DIR := "res://assets/title/"
const FONT_PATH := "res://assets/fonts/DotGothic16-Regular.ttf"

class Rain extends Node2D:
	var f := 0
	var strength := 1.0
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 150:
			var x := rng.randf() * 1800.0
			var speed := 26.0 + rng.randf() * 16.0
			var y := fposmod(rng.randf() * 1100.0 + f * speed, 1120.0) - 20.0
			draw_line(Vector2(x, y), Vector2(x - 7.0, y + 28.0), Color(0.72, 0.82, 1.0, 0.32 * strength), 2.0)

var stage: Node2D
var flash_rect: ColorRect
var fade_rect: ColorRect

func new_stage() -> void:
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.size = Vector2(1728, 1080)
	root.add_child(back)
	stage = Node2D.new()
	root.add_child(stage)
	var top := CanvasLayer.new()
	top.layer = 50
	root.add_child(top)
	flash_rect = ColorRect.new()
	flash_rect.color = Color.WHITE
	flash_rect.size = Vector2(1728, 1080)
	flash_rect.modulate.a = 0.0
	top.add_child(flash_rect)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.size = Vector2(1728, 1080)
	fade_rect.modulate.a = 0.0
	top.add_child(fade_rect)

func sprite(path: String, pos: Vector2 = Vector2.ZERO, factor: float = 1.0, nearest: bool = true) -> Sprite2D:
	var node := Sprite2D.new()
	node.texture = load(path)
	node.centered = false
	node.position = pos
	node.scale = Vector2.ONE * factor
	if nearest:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(node)
	return node

## A sprite centred on `pos` (art coordinates).
func sprite_c(path: String, pos: Vector2, factor: float) -> Sprite2D:
	var node := sprite(path, Vector2.ZERO, factor)
	node.position = pos - node.texture.get_size() * factor * 0.5
	return node

## The camera looks at `center` (art coordinates) at this zoom (the art is 1920 wide, the screen 1728).
func cam(center: Vector2, zoom: float, shake: Vector2 = Vector2.ZERO) -> void:
	var cx := clampf(center.x, 864.0 / zoom, 1920.0 - 864.0 / zoom)
	var cy := clampf(center.y, 540.0 / zoom, 1080.0 - 540.0 / zoom)
	stage.scale = Vector2.ONE * zoom
	stage.position = Vector2(864, 540) - Vector2(cx, cy) * zoom + shake

func lerp_v(a: Vector2, b: Vector2, u: float) -> Vector2:
	return a.lerp(b, u)

func smooth(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

func add_rain(strength: float = 1.0) -> Rain:
	var layer := CanvasLayer.new()
	layer.layer = 10
	root.add_child(layer)
	var rain := Rain.new()
	rain.strength = strength
	layer.add_child(rain)
	return rain

func label(text: String, size: int, color: Color, pos: Vector2, width: float = 1728.0, parent: Node = null) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", load(FONT_PATH))
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	node.add_theme_constant_override("outline_size", maxi(4, size / 8))
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.position = pos
	node.size = Vector2(width, size * 1.4)
	(parent if parent != null else root).add_child(node)
	return node

func flash(a: float) -> void:
	flash_rect.modulate.a = clampf(a, 0.0, 1.0)

## Dark drumroll: the prison city in the storm, lightning showing its soldiers.
func shot_art_intro() -> void:
	new_stage()
	var bg := sprite(TITLE_DIR + "layer_00_background.png", Vector2.ZERO, 1.0, false)
	var foes := sprite(TITLE_DIR + "layer_20_enemies.png", Vector2.ZERO, 1.0, false)
	var rain := add_rain(1.0)
	for f in 72:
		var u := f / 71.0
		var lit := 0.0
		for strike in [22, 50]:
			var d: int = f - strike
			if d >= 0 and d < 6:
				lit = maxf(lit, 1.0 - d / 6.0)
		bg.modulate = Color(0.2, 0.2, 0.27).lerp(Color(0.85, 0.85, 1.0), lit)
		foes.modulate = Color(0.03, 0.0, 0.04, 0.92).lerp(Color(1, 1, 1, 1), lit)
		cam(lerp_v(Vector2(1500, 600), Vector2(1450, 640), smooth(u)), lerpf(1.05, 1.35, smooth(u)))
		flash(lit * 0.35)
		rain.f = f
		rain.queue_redraw()
		fade_rect.modulate.a = 1.0 - smooth(f / 8.0)
		await process_frame

## The fortress prison, its red lamp lit.
func shot_art_fortress() -> void:
	new_stage()
	var bg := sprite(TITLE_DIR + "layer_00_background.png", Vector2.ZERO, 1.0, false)
	bg.modulate = Color(0.45, 0.2, 0.25)
	var glow := ColorRect.new()
	glow.color = Color(1, 0.1, 0.1, 0.0)
	glow.size = Vector2(1728, 1080)
	root.add_child(glow)
	var unit := sprite_c("res://assets/title/units/enemies_fortress.png", Vector2(864, 560), 5.2)
	unit.reparent(root)
	var rain := add_rain(0.8)
	cam(Vector2(1400, 600), 1.6)
	for f in 72:
		var u := f / 71.0
		var pulse := 0.5 + 0.5 * sin(f * 0.5)
		glow.color.a = 0.08 + 0.12 * pulse
		unit.scale = Vector2.ONE * lerpf(5.0, 5.6, smooth(u))
		unit.position = Vector2(864, 580) - unit.texture.get_size() * unit.scale.x * 0.5
		unit.modulate = Color(1, 1, 1).lerp(Color(1.4, 0.9, 0.9), pulse * 0.6)
		cam(Vector2(1400, 600) + Vector2(-30, 0) * u, 1.6)
		flash(maxf(0.0, 0.8 - f / 5.0))
		rain.f = f
		rain.queue_redraw()
		await process_frame

## The Prison King on his throne, silhouette with red eyes.
func shot_art_king() -> void:
	new_stage()
	var bg := sprite(TITLE_DIR + "layer_00_background.png", Vector2.ZERO, 1.0, false)
	bg.modulate = Color(0.25, 0.1, 0.14)
	var halo := ColorRect.new()
	halo.color = Color(0.9, 0.05, 0.1, 0.0)
	halo.size = Vector2(1728, 1080)
	root.add_child(halo)
	var king := sprite_c("res://assets/title/units/enemies_king.png", Vector2(864, 590), 2.7)
	king.reparent(root)
	var rain := add_rain(0.7)
	cam(Vector2(1500, 600), 1.7)
	for f in 72:
		var u := f / 71.0
		var pulse := 0.5 + 0.5 * sin(f * 0.35)
		halo.color.a = 0.06 + 0.2 * pulse * smooth(u * 1.5)
		var k := lerpf(2.55, 3.0, smooth(u))
		king.scale = Vector2.ONE * k
		king.position = Vector2(864, 610 - 40 * u) - king.texture.get_size() * k * 0.5
		flash(maxf(0.0, 0.7 - f / 5.0))
		rain.f = f
		rain.queue_redraw()
		await process_frame

## The hero in the moonlit forest, drawing the sword.
func shot_art_hero() -> void:
	new_stage()
	var bg := sprite(TITLE_DIR + "layer_00_background.png", Vector2.ZERO, 1.0, false)
	bg.modulate = Color(0.8, 1.0, 0.9)
	var hero := sprite("res://assets/title/units/heroes_hero.png", Vector2.ZERO, 1.0, false)
	var units: Array = JSON.parse_string(FileAccess.get_file_as_string(TITLE_DIR + "units.json"))
	var spot: Dictionary = units.filter(func(x): return x.id == "hero")[0]
	hero.position = Vector2(spot.x, spot.y)
	var focus := Vector2(spot.x + spot.w * 0.5, spot.y + spot.h * 0.45)
	for f in 72:
		var u := f / 71.0
		cam(focus + Vector2(0, -10) * u, lerpf(1.7, 2.6, smooth(u)))
		hero.modulate = Color(1, 1, 1).lerp(Color(1.8, 1.8, 1.8), smooth((u - 0.85) / 0.15))
		fade_rect.modulate.a = 1.0 - smooth(f / 8.0)
		flash(smooth((u - 0.9) / 0.1) * 0.5)
		await process_frame

## ALAKAZAR lands on the great chord.
func shot_art_logo() -> void:
	new_stage()
	var bg := sprite(TITLE_DIR + "layer_00_background.png", Vector2.ZERO, 1.0, false)
	bg.modulate = Color(0.55, 0.55, 0.65)
	var logo := sprite(TITLE_DIR + "layer_30_logo.png", Vector2.ZERO, 1.0, false)
	logo.modulate.a = 0.0
	var rain := add_rain(0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for f in 72:
		var u := f / 71.0
		var land := smooth(f / 5.0)
		logo.modulate.a = land
		var swell := 1.0 + 0.18 * (1.0 - land)
		var shake := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * maxf(0.0, 14.0 - f)
		cam(Vector2(960, 300), (1.3 - 0.06 * u) * swell, shake)
		bg.modulate = Color(0.55, 0.55, 0.65).lerp(Color(1, 1, 1), maxf(0.0, 1.0 - f / 12.0))
		flash(maxf(0.0, 1.0 - f / 7.0))
		rain.f = f
		rain.queue_redraw()
		await process_frame

## The fairies step out one by one on the harp (the hero first).
func shot_art_fairies() -> void:
	new_stage()
	var bg := sprite(TITLE_DIR + "layer_00_background.png", Vector2.ZERO, 1.0, false)
	bg.modulate = Color(0.75, 0.95, 0.85)
	var units: Array = JSON.parse_string(FileAccess.get_file_as_string(TITLE_DIR + "units.json"))
	var heroes: Array = units.filter(func(x): return x.side == "heroes")
	heroes.sort_custom(func(a, b): return int(a.z) < int(b.z))
	var hero_first: Array = heroes.filter(func(x): return x.id == "hero") + heroes.filter(func(x): return x.id != "hero")
	var nodes: Array = []
	for unit in hero_first:
		var node := sprite(TITLE_DIR + unit.file, Vector2(unit.x, unit.y), 1.0, false)
		node.modulate.a = 0.0
		nodes.append(node)
	var count := 155
	var follow := Vector2.ZERO
	for f in count:
		var t := f / 30.0
		for i in nodes.size():
			var born := 0.10 + i * 0.205
			var k := clampf((t - born) / 0.28, 0.0, 1.0)
			var node: Sprite2D = nodes[i]
			node.modulate = Color(1, 1, 1, smooth(k * 2.0))
			var pop := 1.0 + 0.35 * pow(1.0 - k, 2.0)
			var spot: Dictionary = hero_first[i]
			var size := Vector2(spot.w, spot.h)
			node.scale = Vector2.ONE * pop
			node.position = Vector2(spot.x, spot.y) + size * (1.0 - pop) * 0.5
			if k > 0.0 and k < 0.4:
				var b := 1.0 + 1.4 * (1.0 - k / 0.4)
				node.modulate = Color(b, b, b, 1.0)
		# The camera follows the newest arrival (close), then pulls back to show them all.
		var newest := clampi(int(floor((t - 0.10) / 0.205)), 0, nodes.size() - 1)
		var spot: Dictionary = hero_first[newest]
		var target := Vector2(spot.x + spot.w * 0.5, spot.y + spot.h * 0.5)
		follow = follow.lerp(target, 0.22) if f > 0 else target
		var back := smooth((t - 4.4) / 0.77)
		cam(follow.lerp(Vector2(700, 640), back), lerpf(2.3, 1.15, back))
		await process_frame

## Quick cuts of the cast, one on every sixteenth.
func shot_art_montage() -> void:
	new_stage()
	var cast := [["jester", "道化兵", Color(0.5, 0.15, 0.4)], ["dragon", "竜装兵", Color(0.1, 0.35, 0.5)], ["cross", "バッテン兵", Color(0.5, 0.25, 0.1)], ["shark", "嵐鮫", Color(0.1, 0.3, 0.45)], ["rotorick", "ロトリック", Color(0.45, 0.1, 0.35)], ["rook", "突進くん", Color(0.45, 0.15, 0.1)], ["fortress", "要塞監獄", Color(0.25, 0.25, 0.4)], ["king", "監獄の王", Color(0.5, 0.05, 0.1)]]
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1728, 1080)
	root.add_child(backdrop)
	var unit := Sprite2D.new()
	unit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	unit.centered = true
	root.add_child(unit)
	var name_label := label("", 96, Color.WHITE, Vector2(0, 880))
	var count := 62
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for f in count:
		var idx := mini(int(f * 8.0 / count), 7)
		var start := int(ceil(idx * count / 8.0))
		var k := f - start
		var entry: Array = cast[idx]
		unit.texture = load("res://assets/title/units/enemies_%s.png" % entry[0])
		var h: float = unit.texture.get_size().y
		var fit: float = (760.0 if entry[0] != "shark" else 560.0) / h
		backdrop.color = (entry[2] as Color).lerp(Color.BLACK, 0.45)
		var grow := 1.0 + 0.12 * (1.0 - clampf(k / 6.0, 0.0, 1.0)) + 0.001 * k
		unit.scale = Vector2.ONE * fit * grow
		unit.position = Vector2(864, 440) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * maxf(0.0, 10.0 - k * 2.0)
		name_label.text = entry[1]
		flash(maxf(0.0, 0.8 - k / 3.0))
		await process_frame

## The real title screen at the song's last part (the picture follows the music), menu hidden.
func shot_title_fusion() -> void:
	var Book = load("res://scripts/fairy_book.gd")
	for item in load("res://scripts/battle_model.gd").ITEMS:
		Book._used[item.id] = true
		Book._seen[item.id] = true
	Book._loaded = true
	var title = load("res://title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	title.reveal = 100.0
	title.menu.visible = false
	title.window.visible = false
	var top := CanvasLayer.new()
	top.layer = 50
	root.add_child(top)
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.size = Vector2(1728, 1080)
	top.add_child(fade)
	var band := ColorRect.new()
	band.color = Color(0.02, 0.02, 0.05, 0.62)
	band.position = Vector2(0, 540)
	band.size = Vector2(1728, 330)
	band.modulate.a = 0.0
	top.add_child(band)
	var line1 := label("3つの武器と、3つの妖精で。", 64, Color("fff6e0"), Vector2(0, 575), 1728.0, top)
	var line2 := label("監獄都市を踏破せよ。", 84, Color("f2c14e"), Vector2(0, 665), 1728.0, top)
	var line3 := label("UnityRoomで体験版公開中", 44, Color("fff6e0"), Vector2(0, 780), 1728.0, top)
	var line4 := label("（Steamで正式版後日公開予定）", 32, Color("d8d2c0"), Vector2(0, 840), 1728.0, top)
	line4.modulate.a = 0.0
	line1.modulate.a = 0.0
	line2.modulate.a = 0.0
	line3.modulate.a = 0.0
	var start := 41.85
	var count := int(round((58.402 - start) * 30.0))
	for f in count:
		var t := start + f / 30.0
		title.override_time = t
		title.reveal = 100.0
		title.menu.visible = false
		title.window.visible = false
		band.modulate.a = smooth((t - 51.8) / 0.6)
		line1.modulate.a = smooth((t - 52.0) / 0.6)
		line2.modulate.a = smooth((t - 53.4) / 0.6)
		line3.modulate.a = smooth((t - 55.4) / 0.6)
		line4.modulate.a = smooth((t - 55.8) / 0.6)
		fade.modulate.a = 0.0 if t < 57.2 else smooth((t - 57.2) / 1.2)
		await process_frame

# ---- portraits (one character, filling the screen, 1.3 s) --------------------------------

const NAMES := {"fortress": "要塞監獄", "prison": "移動監獄", "king": "監獄の王", "rook": "突進くん", "rotorick": "ロトリック", "shark": "嵐鮫",
	"jester": "道化兵", "dragon": "竜装兵", "cross": "バッテン兵", "shield": "盾兵", "exec": "執行兵", "archer": "弓兵",
	"javelin": "投げ槍兵", "analyst": "解析兵", "police": "歩兵", "cavalry": "跳躍騎兵", "hero": "冒険者"}
const TINTS := {"fortress": Color(0.55, 0.12, 0.14), "prison": Color(0.2, 0.25, 0.5), "king": Color(0.5, 0.05, 0.1), "rook": Color(0.5, 0.2, 0.1),
	"rotorick": Color(0.5, 0.1, 0.4), "shark": Color(0.08, 0.35, 0.5), "jester": Color(0.5, 0.1, 0.35), "dragon": Color(0.08, 0.4, 0.5),
	"cross": Color(0.5, 0.25, 0.08), "shield": Color(0.15, 0.4, 0.4), "exec": Color(0.45, 0.2, 0.1), "archer": Color(0.2, 0.45, 0.2),
	"javelin": Color(0.5, 0.2, 0.25), "analyst": Color(0.15, 0.45, 0.35), "police": Color(0.3, 0.35, 0.4), "cavalry": Color(0.4, 0.3, 0.15), "hero": Color(0.1, 0.45, 0.3)}

func portrait(id: String, with_name: bool = false) -> void:
	new_stage()
	var bg := sprite(TITLE_DIR + "layer_00_background.png", Vector2.ZERO, 1.0, false)
	var tint: Color = TINTS.get(id, Color(0.3, 0.3, 0.4))
	bg.modulate = tint.lerp(Color(0.12, 0.12, 0.16), 0.55)
	var path := "res://assets/title/units/%s_%s.png" % ["heroes" if id == "hero" else "enemies", id]
	var unit := Sprite2D.new()
	unit.texture = load(path)
	unit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	unit.centered = true
	root.add_child(unit)
	var rain := add_rain(0.9)
	var size: Vector2 = unit.texture.get_size()
	var fit: float = minf(780.0 / size.y, 1500.0 / size.x)
	var name_label: Label = null
	if with_name:
		name_label = label(NAMES.get(id, id), 84, Color.WHITE, Vector2(0, 880))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for f in 40:
		var grow := 1.0 + 0.28 * pow(1.0 - clampf(f / 6.0, 0.0, 1.0), 2.0) + 0.0012 * f
		unit.scale = Vector2.ONE * fit * grow
		unit.position = Vector2(864, 440) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * maxf(0.0, 9.0 - f * 1.8)
		cam(Vector2(1000, 600), 1.0)
		bg.modulate = tint.lerp(Color(0.12, 0.12, 0.16), 0.55) * (1.0 + 0.6 * maxf(0.0, 1.0 - f / 5.0))
		flash(maxf(0.0, 0.85 - f / 3.5))
		rain.f = f
		rain.queue_redraw()
		await process_frame

# ---- fighting the way a player does ---------------------------------------------------

func enemy_distance(cell: Vector2i) -> int:
	var best := 99
	for e in m.enemies:
		best = mini(best, m.footprint_distance(e, cell))
	return best

## One sensible action: strike the weakest enemy in reach (changing weapon if another one reaches),
## otherwise step towards the nearest enemy. Returns false when nothing can be done.
func auto_step() -> bool:
	if m.player.ap <= 0 or m.terminal():
		return false
	var order: Array = m.owned_weapons.duplicate()
	order.erase(m.weapon)
	order.push_front(m.weapon)
	var chosen := -1
	var target := Vector2i(-1, -1)
	for w in order:
		if m.locked_slot >= 0:
			continue
		var saved: int = m.weapon
		m.weapon = w
		var hits: Array = m.targets().filter(func(c): return not m.enemy_at(c).is_empty() and not m.is_circle(w))
		m.weapon = saved
		if not hits.is_empty():
			hits.sort_custom(func(a, b): return m.enemy_at(a).hp < m.enemy_at(b).hp)
			chosen = w
			target = hits[0]
			break
	if chosen < 0:
		var best_d := 99
		for w in order:
			var saved: int = m.weapon
			m.weapon = w
			for c in m.targets():
				if m.mines.has(c) or not m.enemy_at(c).is_empty():
					continue
				var d := enemy_distance(c)
				if d < best_d:
					best_d = d
					chosen = w
					target = c
			m.weapon = saved
	if chosen < 0:
		return false
	if chosen != m.weapon:
		bv._equip(chosen)
		await frames(4)
	await click(target)
	await seconds(0.3)
	return true

func play_turn(actions: int = 2) -> void:
	for i in actions:
		if not await auto_step():
			break
	await seconds(0.3)
	await end_turn()
	await seconds(0.3)

## The plainest weapons, moving and fighting: a crowd of weak soldiers, every action a blow.
func shot_basic() -> void:
	await boot(4, ["forward", "front_diagonal", "vertical"], ["magic_bolt", "wall_fairy"])
	var side: int = m.board_size
	print("PV basic board ", side)
	arrange(Vector2i(2, 3), [["recruit", Vector2i(3, 3)], ["recruit", Vector2i(2, 2)], ["recruit", Vector2i(4, 3)], ["recruit", Vector2i(3, 1)], ["recruit", Vector2i(4, 5)], ["recruit", Vector2i(5, 2)], ["recruit", Vector2i(2, 5)], ["infantry", Vector2i(5, 5)]])
	m.player.hp = 5
	await seconds(0.8)
	for turn in 5:
		await play_turn()
		if m.terminal() or m.enemies.is_empty():
			break
		m.player.hp = maxi(m.player.hp, 3)
	await seconds(1.0)

## Everything the player has called this battle, and then the guardian calls it all again.
func shot_swarm() -> void:
	await boot(10, ["eight_knight", "lance", "hammer"], ["holy_spirit", "guardian_fairy", "lone_wolf"], {"holy_spirit": 1, "guardian_fairy": 1})
	arrange(Vector2i(0, 3), [["heavy", Vector2i(6, 1), 3], ["executioner", Vector2i(6, 3), 3], ["gold", Vector2i(7, 2), 3], ["horse", Vector2i(6, 5), 3], ["silver", Vector2i(7, 4), 3], ["javelin", Vector2i(7, 6)], ["cavalry", Vector2i(5, 6), 3]])
	m.summon_acorn(Vector2i(1, 1))
	m.summon_acorn(Vector2i(1, 5))
	m.summon_acorn(Vector2i(0, 5))
	m.summon_wolf(Vector2i(2, 2))
	m.summon_wolf(Vector2i(2, 4))
	m.summon_wall(Vector2i(1, 3))
	m.summon_wall(Vector2i(3, 3))
	m.summon_wall(Vector2i(3, 2))
	m.summon_holy(Vector2i(2, 6))
	bv._sync_units(false)
	bv._update_controls()
	bv.queue_redraw()
	await seconds(1.5)
	m.summon_guardian(Vector2i(3, 0))
	bv._sync_units(false)
	bv._feedback()
	bv.queue_redraw()
	await seconds(3.2)
	await end_turn()
	await seconds(1.5)

## The cross daggers: thunder first, then the flame dagger's boosted cross strike.
func shot_daggers() -> void:
	await boot(9, ["thunder_dagger", "flame_dagger", "forward"], ["magic_bolt", "wall_fairy"])
	arrange(Vector2i(2, 3), [["heavy", Vector2i(3, 2), 2], ["executioner", Vector2i(3, 4), 1], ["gold", Vector2i(4, 3), 1], ["silver", Vector2i(2, 5), 1], ["horse", Vector2i(4, 5), 1], ["javelin", Vector2i(6, 3)], ["archer", Vector2i(6, 1)]])
	m.weapon = m.owned_weapons[0]
	bv._update_controls()
	await seconds(1.2)
	await click(Vector2i(3, 2))
	await seconds(0.8)
	bv._equip(m.owned_weapons[1])
	await seconds(0.6)
	await click(Vector2i(3, 4))
	await seconds(2.0)

## The cross hammer: one blow, the cross around it.
func shot_hammer2() -> void:
	await boot(9, ["cross_hammer", "forward", "vertical"], ["magic_bolt", "wall_fairy"])
	arrange(Vector2i(2, 3), [["heavy", Vector2i(3, 3), 1], ["executioner", Vector2i(3, 2), 1], ["gold", Vector2i(3, 4), 1], ["silver", Vector2i(4, 3), 1], ["horse", Vector2i(5, 3), 3], ["javelin", Vector2i(6, 5)], ["archer", Vector2i(6, 1)]])
	m.weapon = m.owned_weapons[0]
	bv._update_controls()
	await seconds(1.2)
	await click(Vector2i(3, 3))
	await seconds(2.2)

## The glutton fairy turns on its own master: the gulp that ends the run.
func shot_glutton() -> void:
	await boot(9, ["forward", "front_diagonal", "vertical"], ["glutton_fairy", "magic_bolt", "wall_fairy"])
	arrange(Vector2i(2, 3), [["heavy", Vector2i(6, 1), 3], ["gold", Vector2i(6, 5), 3], ["javelin", Vector2i(5, 6)]])
	m.summon_glutton(Vector2i(3, 3))
	bv._sync_units(false)
	bv._update_controls()
	bv.queue_redraw()
	await seconds(1.2)
	await end_turn()
	await seconds(1.5)

## A rook-spear magic circle: closing the ring deals 99 to everything inside.
func shot_circle() -> void:
	await boot(9, ["rook_spear", "forward", "hammer"], ["magic_bolt", "wall_fairy"])
	m.enchants[m.owned_weapons[0]] = "circle"
	m.weapon = m.owned_weapons[0]
	var foes := [["heavy", Vector2i(2, 2), 3], ["executioner", Vector2i(4, 2), 3], ["gold", Vector2i(3, 3), 3], ["horse", Vector2i(2, 4), 3], ["silver", Vector2i(4, 4), 3], ["javelin", Vector2i(6, 6)], ["archer", Vector2i(6, 0)]]
	arrange(Vector2i(2, 5), foes)
	for x in range(1, 6):
		m.circle_tiles.append(Vector2i(x, 1))
	for y in range(2, 6):
		m.circle_tiles.append(Vector2i(5, y))
	for x in range(3, 5):
		m.circle_tiles.append(Vector2i(x, 5))
	bv._sync_units(false)
	bv.queue_redraw()
	await seconds(1.4)
	await click(Vector2i(1, 5))
	await seconds(0.9)
	await click(Vector2i(1, 1))
	await seconds(2.2)

## Fairies, one after another on a pack of enemies.
func shot_fairies() -> void:
	await boot(9, ["forward", "front_diagonal", "vertical"], ["freeze_fairy", "gravity_fairy", "slash_fairy"])
	var showcase := [["freeze_fairy", "gravity_fairy", "slash_fairy"], ["time_fairy", "firework_fairy", "axe_spirit"], ["abyss_spirit", "glutton_fairy", "lone_wolf"], ["cat_fairy", "warp_fairy", "acorn_fairy"]]
	for group in showcase:
		m.fairy_loadout.assign(group)
		m.refill_fairies()
		for id in group:
			arrange(Vector2i(0, 3), [["heavy", Vector2i(3, 2), 3], ["executioner", Vector2i(3, 4), 3], ["gold", Vector2i(4, 3), 3], ["horse", Vector2i(5, 1), 3], ["silver", Vector2i(5, 5), 3], ["javelin", Vector2i(6, 3)]])
			m.player.ap = 2
			bv._update_controls()
			await seconds(0.5)
			await fairy_auto(id)
			await seconds(1.3)

func fairy_auto(id: String) -> void:
	var cells: Array = m.item_targets(id)
	if cells.is_empty():
		print("PV no target for ", id)
		return
	var center := Vector2.ZERO
	for e in m.enemies:
		center += Vector2(e.cell)
	center /= maxf(1.0, m.enemies.size())
	cells.sort_custom(func(a, b): return Vector2(a).distance_to(center) < Vector2(b).distance_to(center))
	var cell: Vector2i = cells[0]
	var direction := Vector2i.ZERO
	if m.is_directional(id):
		var toward := center - Vector2(cell)
		direction = Vector2i(signi(int(toward.x)), 0) if absf(toward.x) >= absf(toward.y) else Vector2i(0, signi(int(toward.y)))
		if direction == Vector2i.ZERO:
			direction = Vector2i.RIGHT
	bv._select_item(id)
	await frames(2)
	bv._item_act(cell)
	await frames(2)
	if direction != Vector2i.ZERO:
		bv._item_act(cell + direction)
		await frames(2)
	await idle()

## The last late fight: the jester wakes, the dragon soldier fires, the fortress keeps sending.
func shot_late4() -> void:
	await boot(11, ["forward", "front_diagonal", "vertical"], ["magic_bolt", "wall_fairy", "stealth_fairy"])
	await seconds(1.0)
	for turn in 5:
		await play_turn()
		if m.terminal():
			break
