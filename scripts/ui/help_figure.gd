extends Control
## One animated picture in the field manual. Each `kind` is a tiny looping
## scene drawn with the game's own sprites, so a player can learn by looking.

const Units = preload("res://scripts/unit_view.gd")
const Icon = preload("res://scripts/items/spirit_icon.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const LATIN = preload("res://assets/fonts/VT323-Regular.ttf")
const GOLD := Color("ffd35b")
const ORANGE := Color("ff805a")
const INK := Color("e5dfc5")
const CYAN := Color("2bdcc8")
const RED := Color("ff5b62")
const VIOLET := Color("9b6bff")
const MUTED := Color("92b3ae")
const T := 40.0

var kind := "move"
var time := 0.0
var icons := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for id in ["wall_fairy", "cannon_fairy", "capacitor_fairy", "magic_bolt"]:
		icons[id] = load("res://items/%s.tres" % id).icon

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

# --- helpers ---------------------------------------------------------------

func _origin(count: int) -> Vector2:
	return (size - Vector2.ONE * T * count) / 2.0

func _grid(count: int, lit: Array = [], lit_color: Color = GOLD) -> Vector2:
	var origin := _origin(count)
	for y in count:
		for x in count:
			var cell := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(cell) * T + Vector2.ONE * 2, Vector2.ONE * (T - 4))
			draw_rect(rect, Color("5e5442"))
			if lit.has(cell):
				draw_rect(rect, Color(lit_color, 0.28))
				draw_rect(rect, lit_color, false, 2)
	return origin

func _at(origin: Vector2, cell: Vector2) -> Vector2:
	return origin + cell * T + Vector2.ONE * T / 2

func _player(pos: Vector2, scale_by: float = 1.0) -> void:
	var cell := Units.PLAYER_ATLAS_CELL
	var side := 44.0 * scale_by
	draw_texture_rect_region(Units.PLAYER_ATLAS, Rect2(pos - Vector2(side / 2, side * 0.62), Vector2.ONE * side), Rect2(cell, 2 * cell, cell, cell))

func _enemy(pos: Vector2, alpha: float = 1.0) -> void:
	draw_texture_rect_region(Units.ENEMY_ATLAS, Rect2(pos - Vector2(19, 23), Vector2(38, 38)), Rect2(3 * 28, 0, 28, 28), Color(1, 1, 1, alpha))

func _cursor(pos: Vector2) -> void:
	var tip := pos
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(0, 18), tip + Vector2(5, 13), tip + Vector2(10, 20), tip + Vector2(13, 18), tip + Vector2(8, 11), tip + Vector2(14, 11)]), Color.WHITE)
	draw_polyline(PackedVector2Array([tip, tip + Vector2(0, 18), tip + Vector2(5, 13), tip + Vector2(10, 20), tip + Vector2(13, 18), tip + Vector2(8, 11), tip + Vector2(14, 11), tip]), Color.BLACK, 1.5)

func _text(pos: Vector2, text: String, font_size: int, color: Color, font: Font = FONT) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _phase(period: float) -> float:
	return fmod(time, period)

func _slash(pos: Vector2, t: float) -> void:
	if t < 0.0 or t > 0.5:
		return
	var a := t / 0.5
	draw_arc(pos, 16, -2.2 + a * 1.5, -0.6 + a * 1.5, 12, Color(1, 1, 1, 1 - a), 4, true)
	_text(pos + Vector2(6, -18 - a * 16), "−1", 20, Color(ORANGE, 1 - a))

func _outlined(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	for offset in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		draw_string(LATIN, pos + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.08, 0.02, 0.15))
	draw_string(LATIN, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _hearts(pos: Vector2, full: int, total: int) -> void:
	for i in total:
		var c := pos + Vector2(i * 26, 0)
		var col := RED if i < full else Color("3a2228")
		draw_circle(c + Vector2(-5, -3), 7, col)
		draw_circle(c + Vector2(5, -3), 7, col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -1), c + Vector2(12, -1), c + Vector2(0, 12)]), col)

func _keycap(pos: Vector2, label: String, width: float = 44.0) -> void:
	var rect := Rect2(pos, Vector2(width, 40))
	draw_rect(rect, Color("1c2a2c"))
	draw_rect(rect, INK, false, 2)
	draw_rect(Rect2(pos + Vector2(0, 34), Vector2(width, 6)), Color("0d1516"))
	_text(pos + Vector2(width / 2 - label.length() * 7, 28), label, 22, INK, LATIN)

# --- scenes ---------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0c181b"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("2c4a44"), false, 2)
	call("_draw_" + kind)

## The lit tiles are where the weapon goes; clicking one moves there.
func _draw_move() -> void:
	var t := _phase(2.6)
	var lit := [Vector2i(2, 0), Vector2i(2, 2)]
	var origin := _grid(3, lit)
	var target := _at(origin, Vector2(2, 2))
	var start := _at(origin, Vector2(1, 1))
	var hop := clampf((t - 1.1) / 0.3, 0.0, 1.0)
	var pos := start.lerp(target, hop) + Vector2(0, -sin(hop * PI) * 14)
	_player(pos)
	if t < 1.4:
		_cursor(start.lerp(target, clampf(t / 0.9, 0.0, 1.0)) + Vector2(4, 6))

## Clicking an enemy on a lit tile attacks it; you stay where you are.
func _draw_attack() -> void:
	var t := _phase(2.2)
	var origin := _grid(3, [Vector2i(2, 1)], ORANGE)
	var foe := _at(origin, Vector2(2, 1))
	_enemy(foe + Vector2(sin(t * 60.0) * 2.0 if t > 0.9 and t < 1.1 else 0.0, 0))
	var you := _at(origin, Vector2(1, 1))
	_player(you + Vector2(minf(1.0, maxf(0.0, (t - 0.7) * 5.0)) * 8.0 if t < 1.0 else 0.0, 0))
	_slash(foe, t - 0.9)
	if t < 0.9:
		_cursor(foe + Vector2(4, 6))

## Two AP a turn; then the enemies move.
func _draw_ap() -> void:
	var t := _phase(3.2)
	var used := 0 if t < 0.8 else 1 if t < 1.6 else 2
	for i in 2:
		var rect := Rect2(Vector2(40 + i * 84, 34), Vector2(72, 26))
		draw_rect(rect, GOLD if i >= used else Color("293d36"))
	_text(Vector2(40, 26), "AP", 22, GOLD, LATIN)
	var origin := Vector2(60, 90)
	for x in 3:
		draw_rect(Rect2(origin + Vector2(x * T, 0) + Vector2.ONE * 2, Vector2.ONE * (T - 4)), Color("5e5442"))
	_player(origin + Vector2(T / 2, T / 2))
	var step := clampf((t - 1.9) / 0.4, 0.0, 1.0)
	_enemy(origin + Vector2(T * 2.5 - step * T, T / 2))
	if t > 1.6:
		_text(Vector2(64, 170), "敵のターン", 22, RED)

## "!" marks an enemy that will hit you if you stay; step away and it goes.
func _draw_threat() -> void:
	var t := _phase(2.6)
	var origin := _grid(3)
	var foe := _at(origin, Vector2(2, 1))
	_enemy(foe)
	var moved := clampf((t - 1.2) / 0.3, 0.0, 1.0)
	var you := _at(origin, Vector2(1, 1)).lerp(_at(origin, Vector2(0, 0)), moved)
	_player(you)
	if moved < 1.0:
		draw_circle(foe + Vector2(12, -26), 11, RED)
		_text(foe + Vector2(8, -18), "!", 20, Color.WHITE)
		draw_line(foe + Vector2(-14, 0), you + Vector2(16, 0), Color(RED, 0.8), 3)

## Hover an enemy to see where it moves and hits.
func _draw_inspect() -> void:
	var t := _phase(2.4)
	var origin := _grid(3)
	var foe := _at(origin, Vector2(1, 1))
	var shown := t > 0.8
	if shown:
		for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
			var rect := Rect2(origin + (Vector2(1, 1) + d) * T + Vector2.ONE * 2, Vector2.ONE * (T - 4))
			draw_rect(rect, Color(RED, 0.3))
			draw_rect(rect, RED, false, 2)
	_enemy(foe)
	_cursor(foe.lerp(foe + Vector2(40, 40), clampf(1.0 - t / 0.8, 0.0, 1.0)) + Vector2(6, 6))

## Clear the board to win.
func _draw_win() -> void:
	var t := _phase(2.6)
	var origin := _grid(3)
	var alpha := clampf(1.0 - (t - 0.6) / 0.5, 0.0, 1.0)
	_enemy(_at(origin, Vector2(2, 0)), alpha)
	_enemy(_at(origin, Vector2(2, 2)), alpha)
	_player(_at(origin, Vector2(0, 1)))
	if t > 1.2:
		_outlined(Vector2(size.x / 2 - 30, size.y - 22), "WIN", 48, GOLD)

## Three weapons; switching is free and changes the lit tiles.
func _draw_switch() -> void:
	var pick := int(time / 1.1) % 3
	var patterns := [[Vector2i(2, 1)], [Vector2i(1, 0), Vector2i(1, 2)], [Vector2i(2, 0), Vector2i(2, 2)]]
	var colors := [GOLD, Color("bda0ff"), Color("ffad70")]
	var origin := Vector2((size.x - T * 3) / 2, 18)
	for y in 3:
		for x in 3:
			var cell := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(cell) * T + Vector2.ONE * 2, Vector2.ONE * (T - 4))
			draw_rect(rect, Color("5e5442"))
			if patterns[pick].has(cell):
				draw_rect(rect, Color(colors[pick], 0.3))
				draw_rect(rect, colors[pick], false, 2)
	_player(_at(origin, Vector2(1, 1)))
	for i in 3:
		var rect := Rect2(Vector2(22 + i * 68, 150), Vector2(60, 40))
		draw_rect(rect, Color("152d2a") if i == pick else Color("0b1415"))
		draw_rect(rect, colors[i] if i == pick else Color("324843"), false, 3 if i == pick else 1)
		_text(rect.position + Vector2(24, 29), str(i + 1), 24, colors[i], LATIN)

## Jumping weapons skip over what is in between.
func _draw_jump() -> void:
	var t := _phase(2.2)
	var origin := _grid(3, [Vector2i(2, 0)])
	var start := _at(origin, Vector2(0, 2))
	var end := _at(origin, Vector2(2, 0))
	_enemy(_at(origin, Vector2(1, 1)))
	var hop := clampf((t - 0.6) / 0.6, 0.0, 1.0)
	_player(start.lerp(end, hop) + Vector2(0, -sin(hop * PI) * 40))

## Sliding weapons run until something is in the way.
func _draw_slide() -> void:
	var t := _phase(2.4)
	var origin := Vector2(10, 70)
	for x in 5:
		var rect := Rect2(origin + Vector2(x * T, 0) + Vector2.ONE * 2, Vector2.ONE * (T - 4))
		draw_rect(rect, Color("5e5442"))
		if x > 0:
			draw_rect(rect, Color(GOLD, 0.25))
	_enemy(origin + Vector2(T * 4.5, T / 2))
	var run := clampf((t - 0.5) / 0.6, 0.0, 1.0)
	_player(origin + Vector2(T / 2 + run * T * 3, T / 2))
	if run >= 1.0:
		_slash(origin + Vector2(T * 4.5, T / 2), t - 1.1)
	draw_line(origin + Vector2(T * 0.9, T + 16), origin + Vector2(T * 3.6, T + 16), GOLD, 3)
	draw_colored_polygon(PackedVector2Array([origin + Vector2(T * 3.8, T + 16), origin + Vector2(T * 3.55, T + 9), origin + Vector2(T * 3.55, T + 23)]), GOLD)

## Fairies go on a lit tile.
func _draw_place() -> void:
	var t := _phase(2.4)
	var lit := [Vector2i(2, 1)]
	var origin := _grid(3, lit, CYAN)
	_player(_at(origin, Vector2(1, 1)))
	var spot := _at(origin, Vector2(2, 1))
	var drop := clampf((t - 0.4) / 0.5, 0.0, 1.0)
	Icon.paint(self, spot + Vector2(0, -60 * (1.0 - drop)), icons["wall_fairy"], 0.62)

## Hitting a placed cannon fires it down its line.
func _draw_cannon() -> void:
	var t := _phase(2.4)
	var origin := Vector2(10, 70)
	for x in 5:
		draw_rect(Rect2(origin + Vector2(x * T, 0) + Vector2.ONE * 2, Vector2.ONE * (T - 4)), Color("5e5442"))
	_player(origin + Vector2(T / 2, T / 2))
	Icon.paint(self, origin + Vector2(T * 1.5, T / 2), icons["cannon_fairy"], 0.6)
	var hit := t > 1.3
	_enemy(origin + Vector2(T * 3.5, T / 2), 0.4 if hit else 1.0)
	_enemy(origin + Vector2(T * 4.5, T / 2), 0.4 if hit else 1.0)
	_slash(origin + Vector2(T * 1.5, T / 2), t - 0.6)
	if t > 0.9 and t < 1.5:
		var head := origin + Vector2(T * 2 + (t - 0.9) / 0.4 * T * 3, T / 2)
		draw_line(origin + Vector2(T * 2, T / 2), head, ORANGE, 6)
	if hit:
		_text(origin + Vector2(T * 3.1, -8), "−1  −1", 18, ORANGE)

## Placed walls and cannons count down and vanish after 3 turns.
func _draw_fade() -> void:
	var left := 3 - int(time / 0.9) % 4
	var center := size / 2 - Vector2(0, 10)
	if left > 0:
		Icon.paint(self, center, icons["wall_fairy"], 1.1)
		draw_rect(Rect2(center + Vector2(22, 18), Vector2(24, 26)), Color(0.03, 0.06, 0.07, 0.9))
		_text(center + Vector2(27, 40), str(left), 26, INK, LATIN)
	else:
		for k in 6:
			draw_circle(center + Vector2.from_angle(k) * 26, 4, Color("b9b39f", 0.6))

## An act: three fights, a camp, then the boss.
func _draw_flow() -> void:
	var steps := ["⚔", "⚔", "⚔", "camp", "boss"]
	var lit := int(time / 0.6) % 6
	for i in steps.size():
		var at := Vector2(24 + i * 44, size.y / 2 - 10)
		var on := i < lit
		draw_circle(at, 17, Color("15301f") if on else Color("101a1c"))
		draw_arc(at, 17, 0, TAU, 24, GOLD if on else Color(INK, 0.4), 2, true)
		match steps[i]:
			"⚔":
				for flip in [-1.0, 1.0]:
					var dir := Vector2(flip, -1).normalized()
					draw_line(at - dir * 8, at + dir * 10, Color.WHITE, 3)
			"camp":
				draw_colored_polygon(PackedVector2Array([at + Vector2(-7, 7), at + Vector2(7, 7), at + Vector2(0, -9)]), Color("ff8a3a"))
			"boss":
				draw_rect(Rect2(at + Vector2(-9, -6), Vector2(18, 14)), RED, false, 2)
				for k in 3:
					draw_rect(Rect2(at + Vector2(-9 + k * 7, -10), Vector2(4, 4)), RED)
		if i < steps.size() - 1:
			draw_line(at + Vector2(18, 0), at + Vector2(26, 0), Color(INK, 0.5), 2)
	_text(Vector2(size.x / 2 - 22, size.y / 2 + 50), "×2章", 22, GOLD)

## After a win, pick one of five.
func _draw_reward() -> void:
	var pick := int(time / 0.7) % 5
	for i in 5:
		var rect := Rect2(Vector2(14 + i * 43, 60), Vector2(38, 60))
		var chosen := i == pick
		draw_rect(rect, Color("172b2b") if chosen else Color("0c181b"))
		draw_rect(rect, GOLD if chosen else Color(INK, 0.4), false, 3 if chosen else 1)
		if i < 3:
			# A tiny range picture: the hero in the middle, two reachable tiles.
			var shapes := [[Vector2i(1, -1), Vector2i(1, 1)], [Vector2i(0, -1), Vector2i(0, 1)], [Vector2i(2, 1), Vector2i(-2, -1)]]
			for y in range(-2, 3):
				for x in range(-2, 3):
					var dot := rect.get_center() + Vector2(x, y) * 6.5
					var on: bool = shapes[i].has(Vector2i(x, y))
					draw_rect(Rect2(dot - Vector2(2.5, 2.5), Vector2(5, 5)), GOLD if on else Color(INK, 0.15) if Vector2i(x, y) != Vector2i.ZERO else CYAN)
		else:
			Icon.paint(self, rect.get_center(), icons["magic_bolt"] if i == 3 else icons["capacitor_fairy"], 0.4)
	_text(Vector2(30, 150), "武器3　妖精2", 20, INK)

## HP carries over; each win heals 1.
func _draw_hp() -> void:
	var t := _phase(2.4)
	var full := 3 if t < 1.2 else 4
	_hearts(Vector2(48, size.y / 2), full, 5)
	if t > 1.2:
		_text(Vector2(size.x / 2 - 18, size.y / 2 - 26 - (t - 1.2) * 20), "+1", 24, Color("7be08a"), LATIN)

## The magic circle: close a ring of white tiles, everything inside takes 99.
func _draw_circle() -> void:
	var t := _phase(3.0)
	var ring := [Vector2i(1, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(0, 1)]
	var shown := mini(int(t / 0.4) + 1, 4)
	var origin := _origin(3)
	for y in 3:
		for x in 3:
			var cell := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(cell) * T + Vector2.ONE * 2, Vector2.ONE * (T - 4))
			draw_rect(rect, Color("5e5442"))
			var i := ring.find(cell)
			if i >= 0 and i < shown:
				draw_rect(rect, Color(0.94, 0.95, 1.0, 0.8))
	var burst := t > 1.8
	_enemy(_at(origin, Vector2(1, 1)), 0.3 if burst else 1.0)
	if burst:
		var a := clampf((t - 1.8) / 0.8, 0.0, 1.0)
		draw_arc(_at(origin, Vector2(1, 1)), 20 + a * 60, 0, TAU, 32, Color(VIOLET, 1 - a), 5, true)
		_outlined(Vector2(size.x / 2 - 22, origin.y - 8), "99", 52, GOLD)

## A yellow "+" marks an upgraded weapon or fairy.
func _draw_plus() -> void:
	var center := size / 2
	Icon.paint(self, center, icons["capacitor_fairy"], 1.3)
	var pulse := 1.0 + 0.1 * sin(time * 5.0)
	Icon.paint_plus(self, center + Vector2(48, -52), 30 * pulse)

## Knockback: shove the enemy; if it slams into something it takes 1 more.
func _draw_push() -> void:
	var t := _phase(2.4)
	var origin := Vector2(30, 70)
	for x in 4:
		draw_rect(Rect2(origin + Vector2(x * T, 0) + Vector2.ONE * 2, Vector2.ONE * (T - 4)), Color("5e5442"))
	draw_rect(Rect2(origin + Vector2(T * 3, 0) + Vector2.ONE * 2, Vector2.ONE * (T - 4)), Color("263b3d"))
	_player(origin + Vector2(T / 2, T / 2))
	var shove := clampf((t - 0.8) / 0.25, 0.0, 1.0)
	var foe := origin + Vector2(T * 1.5 + shove * T, T / 2)
	_enemy(foe)
	_slash(origin + Vector2(T * 1.5, T / 2), t - 0.7)
	if t > 1.1 and t < 1.7:
		for k in 6:
			draw_line(foe + Vector2(20, 0), foe + Vector2(20, 0) + Vector2.from_angle(k * TAU / 6) * 12, GOLD, 3)
		_text(foe + Vector2(0, -26), "+1", 20, GOLD, LATIN)

## The keys and the mouse, laid out wide.
func _draw_keys() -> void:
	var rows := [[["1", "2", "3"], "武器を持ち替え"], [["4", "5", "6"], "妖精を選ぶ"]]
	for r in rows.size():
		for k in 3:
			_keycap(Vector2(40 + k * 54, 30 + r * 64), rows[r][0][k])
		_text(Vector2(212, 58 + r * 64), rows[r][1], 22, INK)
	_keycap(Vector2(40, 170), "SPACE", 150)
	_text(Vector2(212, 198), "ターン終了", 22, INK)
	_keycap(Vector2(40, 234), "Esc", 60)
	_text(Vector2(112, 262), "取消", 22, INK)
	_keycap(Vector2(400, 30), "H")
	_text(Vector2(456, 58), "この説明", 22, INK)
	_keycap(Vector2(400, 94), "R")
	_text(Vector2(456, 122), "戦闘をやり直す", 22, INK)
	# Mouse: left click acts, right click pins the enemy info.
	var mouse := Vector2(420, 170)
	draw_rect(Rect2(mouse, Vector2(40, 60)), Color("1c2a2c"))
	draw_rect(Rect2(mouse, Vector2(40, 60)), INK, false, 2)
	draw_line(mouse + Vector2(20, 0), mouse + Vector2(20, 24), INK, 2)
	draw_line(mouse + Vector2(0, 24), mouse + Vector2(40, 24), INK, 2)
	var blink := 0.5 + 0.5 * sin(time * 4.0)
	draw_rect(Rect2(mouse + Vector2(2, 2), Vector2(17, 21)), Color(GOLD, 0.5 * blink))
	_text(Vector2(476, 190), "左：移動・攻撃・置く", 20, INK)
	_text(Vector2(476, 222), "右：敵の情報を固定", 20, MUTED)
