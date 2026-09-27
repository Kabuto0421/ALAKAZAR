extends Control
## The expedition map: the hero and the fairies march from the old forest on the
## left into the neon prison city ALAKAZAR on the right. Columns are the stages
## (with a camp before each boss); the middle floor of each act forks into a
## fight (⚔) or a "?" event. Conquered ground behind the hero turns green.

const Units = preload("res://scripts/unit_view.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const GOLD := Color("ffd35b")
const INK := Color("e5dfc5")
const FOREST := Color("7fd08a")
const NEON := Color("2bdcc8")
const NEON_PINK := Color("ff5bd1")
const DANGER := Color("ff6b6b")

## Entries left to right: {"kind", "stage", "row" (index in the stage's row), "count"}.
var columns: Array = []
var map_rows: Array = []
var map_path: Array = []
var stage := 0
## The stage the hero stands before (nodes of this stage are the choices).
var waiting := true
var camp_done: Array = []
var fairy_icons: Array[Texture2D] = []
var hover := Vector2i(-1, -1)
var time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

## Screen position of a node (column, index among the column's nodes).
func node_position(column: int, index: int) -> Vector2:
	var entry: Dictionary = columns[column]
	var x := 62.0 + column * (size.x - 124.0) / (columns.size() - 1)
	var count: int = entry.count
	var mid := size.y * 0.55
	if count == 1:
		return Vector2(x, mid)
	return Vector2(x, mid + (index - 0.5) * 128.0)

## The column holding the hero: the stage being chosen, or the last one reached.
func hero_column() -> int:
	for c in columns.size():
		var entry: Dictionary = columns[c]
		if entry.kind == "stage" and entry.stage == stage:
			return c
	return 0

func _draw() -> void:
	var city_x := _city_edge()
	_draw_sky(city_x)
	_draw_forest(city_x)
	_draw_city(city_x)
	_draw_paths()
	_draw_nodes()
	_draw_hero()

func _city_edge() -> float:
	for c in columns.size():
		if columns[c].get("boss", false):
			return node_position(c, 0).x - 30.0
	return size.x * 0.45

func _draw_sky(city_x: float) -> void:
	# Night sky: deep green over the forest, violet over the city.
	for k in 12:
		var y := size.y * k / 12.0
		var t := k / 11.0
		draw_rect(Rect2(0, y, city_x, size.y / 12.0 + 1), Color("0b1f17").lerp(Color("132a1c"), t))
		draw_rect(Rect2(city_x, y, size.x - city_x, size.y / 12.0 + 1), Color("120c24").lerp(Color("1a1030"), t))
	# The green of the invasion bleeds into the conquered part of the city.
	var hero_x := node_position(hero_column(), 0).x
	if hero_x > city_x:
		draw_rect(Rect2(city_x, 0, hero_x - city_x, size.y), Color(FOREST, 0.06))
	draw_rect(Rect2(Vector2.ZERO, size), Color("2c4a44"), false, 2)

func _draw_forest(city_x: float) -> void:
	# Layered pine trees and fairy lights drifting between them.
	for layer in 2:
		var base_y := size.y - 18.0 - layer * 26.0
		var shade := Color("1d4a2c") if layer == 0 else Color("153822")
		var step := 38.0 + layer * 14.0
		var x := 10.0 + layer * 17.0
		while x < city_x - 12:
			var h := 44.0 + fmod(x * 7.3, 30.0) + layer * 10.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 16, base_y), Vector2(x + 16, base_y), Vector2(x, base_y - h)]), shade)
			x += step
	for k in 18:
		var fx := fmod(k * 73.0 + time * (8 + k % 5), city_x - 20.0) + 10.0
		var fy := size.y * 0.25 + fmod(k * 47.0, size.y * 0.55) + sin(time * 2.0 + k) * 8.0
		draw_circle(Vector2(fx, fy), 2.0, Color(FOREST.lightened(0.4), 0.5 + 0.4 * sin(time * 3.0 + k)))

func _draw_city(city_x: float) -> void:
	# The outer wall with its gate, then neon towers deeper in.
	draw_rect(Rect2(city_x - 6, size.y * 0.2, 12, size.y * 0.8), Color("2a2240"))
	draw_rect(Rect2(city_x - 6, size.y * 0.2, 12, size.y * 0.8), Color(NEON, 0.5), false, 1)
	var x := city_x + 30.0
	var k := 0
	var hero_x := node_position(hero_column(), 0).x
	while x < size.x - 20:
		var w := 26.0 + fmod(k * 13.0, 22.0)
		var h := 70.0 + fmod(k * 37.0, 120.0)
		var top := size.y - 14.0 - h
		# Towers behind the hero are taken: vines creep over them.
		var taken := x + w < hero_x
		draw_rect(Rect2(x, top, w, h), Color("1c1633") if not taken else Color("16261d"))
		draw_rect(Rect2(x, top, w, 3), NEON_PINK if k % 3 == 0 and not taken else NEON if not taken else FOREST, false)
		for wy in range(int(top) + 10, int(size.y) - 20, 14):
			for wx in range(int(x) + 5, int(x + w) - 4, 9):
				var lit := int(wx * 3 + wy + k) % 5 != 0
				if lit:
					var glow := Color(NEON, 0.35 + 0.2 * sin(time * 1.5 + wx)) if not taken else Color(FOREST, 0.35)
					draw_rect(Rect2(wx, wy, 4, 6), glow)
		if taken:
			draw_line(Vector2(x + 3, size.y - 14), Vector2(x + w * 0.5, top + h * 0.3), Color(FOREST, 0.6), 2)
		x += w + 10.0
		k += 1
	# Scanlines over the city.
	for y in range(0, int(size.y), 4):
		draw_line(Vector2(city_x, y), Vector2(size.x, y), Color(0, 0, 0, 0.12), 1)

func _node_state(column: int, index: int) -> String:
	var entry: Dictionary = columns[column]
	if entry.kind == "camp":
		return "done" if camp_done.has(column) else "future"
	var s: int = entry.stage
	if s < stage or (s == stage and not waiting):
		return "taken" if map_path[s] == index else "skipped"
	if s == stage and waiting:
		return "choice"
	return "future"

func _draw_paths() -> void:
	for c in columns.size() - 1:
		for a in columns[c].count:
			for b in columns[c + 1].count:
				var from := node_position(c, a)
				var to := node_position(c + 1, b)
				var walked := _node_state(c, a) in ["taken", "done"] and _node_state(c + 1, b) in ["taken", "done", "choice"]
				if walked:
					draw_line(from, to, Color(GOLD, 0.9), 4)
				else:
					var length := from.distance_to(to)
					var t := 0.0
					while t < length:
						draw_line(from.lerp(to, t / length), from.lerp(to, minf(t + 6, length) / length), Color(INK, 0.3), 2)
						t += 12

func _draw_nodes() -> void:
	for c in columns.size():
		for i in columns[c].count:
			var at := node_position(c, i)
			var state := _node_state(c, i)
			var kind := _kind(c, i)
			var radius := 30.0 if kind == "boss" else 24.0
			var ring := Color(INK, 0.4)
			var fill := Color("101a1c")
			if state == "choice":
				var pulse := 0.5 + 0.5 * sin(time * 5.0)
				ring = GOLD.lerp(Color.WHITE, pulse * 0.4)
				radius += 3.0 + pulse * 2.0
				if hover == Vector2i(c, i):
					fill = Color("2b3a26")
					radius += 3.0
			elif state in ["taken", "done"]:
				ring = FOREST
				fill = Color("15301f")
			elif state == "skipped":
				ring = Color(INK, 0.15)
			if kind == "boss":
				ring = DANGER if state != "taken" else FOREST
			draw_circle(at, radius, fill)
			draw_arc(at, radius, 0, TAU, 32, ring, 3, true)
			var ink := Color.WHITE if state != "skipped" else Color(INK, 0.3)
			match kind:
				"battle":
					_draw_swords(at, ink)
				"event":
					draw_string(FONT, at + Vector2(-11, 11), "？", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("c9b3ff") if state != "skipped" else ink)
				"camp":
					_draw_fire(at)
				"boss":
					_draw_gate(at, ring)
			if state in ["taken", "done"]:
				# A green banner planted on conquered ground.
				draw_line(at + Vector2(14, -8), at + Vector2(14, -34), Color("c9b79a"), 2)
				draw_colored_polygon(PackedVector2Array([at + Vector2(15, -34), at + Vector2(31, -29), at + Vector2(15, -24)]), FOREST)
			var label: String = {"battle": "戦闘", "event": "イベント", "camp": "キャンプ", "boss": "ボス"}[kind]
			draw_string(FONT, at + Vector2(-label.length() * 7, radius + 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(INK, 0.8 if state != "skipped" else 0.3))

func _kind(column: int, index: int) -> String:
	var entry: Dictionary = columns[column]
	if entry.kind == "camp":
		return "camp"
	return map_rows[entry.stage][index].kind

## ⚔: two crossed swords.
func _draw_swords(at: Vector2, ink: Color) -> void:
	for flip in [-1.0, 1.0]:
		var dir := Vector2(flip, -1).normalized()
		var tip := at + dir * 15
		var hilt := at - dir * 11
		draw_line(hilt, tip, ink, 4)
		draw_line(tip, tip - dir * 4, Color("cfe8ff"), 4)
		var guard := Vector2(-dir.y, dir.x) * 6
		draw_line(hilt + dir * 3 - guard, hilt + dir * 3 + guard, GOLD, 3)
		draw_line(hilt, hilt - dir * 5, Color("8a5a2b"), 4)

func _draw_fire(at: Vector2) -> void:
	var flick := sin(time * 9.0) * 2.0
	draw_line(at + Vector2(-10, 10), at + Vector2(10, 4), Color("8a5a2b"), 4)
	draw_line(at + Vector2(-10, 4), at + Vector2(10, 10), Color("8a5a2b"), 4)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-9, 6), at + Vector2(9, 6), at + Vector2(flick, -14)]), Color("ff8a3a"))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-5, 6), at + Vector2(5, 6), at + Vector2(-flick * 0.5, -6)]), Color("ffe08a"))

## The city gate / tower of a boss.
func _draw_gate(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at + Vector2(-14, -10), Vector2(28, 22)), Color("241a38"))
	draw_rect(Rect2(at + Vector2(-14, -10), Vector2(28, 22)), color, false, 2)
	for k in 3:
		draw_rect(Rect2(at + Vector2(-14 + k * 11, -16), Vector2(6, 6)), color)
	draw_rect(Rect2(at + Vector2(-5, 0), Vector2(10, 12)), Color("0a0612"))
	draw_circle(at + Vector2(0, -3), 2.5, DANGER)

## The hero with the fairies in tow, standing at the current column.
func _draw_hero() -> void:
	var c := hero_column()
	var at := node_position(c, 0) if columns[c].count == 1 else (node_position(c, 0) + node_position(c, 1)) / 2.0
	at += Vector2(-58, 0)
	var bob := sin(time * 4.0) * 2.0
	var cell := Units.PLAYER_ATLAS_CELL
	draw_texture_rect_region(Units.PLAYER_ATLAS, Rect2(at + Vector2(-28, -34 + bob), Vector2(56, 56)), Rect2(cell, 2 * cell, cell, cell))
	for k in fairy_icons.size():
		var angle := time * 1.8 + k * TAU / maxf(1, fairy_icons.size())
		var spot := at + Vector2(cos(angle) * 30, sin(angle) * 12 - 34)
		draw_texture_rect(fairy_icons[k], Rect2(spot - Vector2(12, 12), Vector2(24, 24)), false)
	# "Onward" arrow.
	var tip := at + Vector2(46, -30)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-10, -6), tip + Vector2(-10, 6)]), Color(GOLD, 0.6 + 0.4 * sin(time * 5.0)))
