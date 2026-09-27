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

func _ap_boxes(pos: Vector2, total: int, left: int, color: Color = GOLD, label: String = "AP") -> void:
	_text(pos + Vector2(0, 14), label, 18, color)
	var shift := 12.0 * label.length() + 14.0
	for i in total:
		var rect := Rect2(pos + Vector2(shift + i * 24, 0), Vector2(20, 16))
		draw_rect(rect, color if i < left else Color("293d36"))
		draw_rect(rect, Color(color, 0.6), false, 1)

func _row(origin: Vector2, count: int) -> void:
	for x in count:
		draw_rect(Rect2(origin + Vector2(x * T, 0) + Vector2.ONE * 2, Vector2.ONE * (T - 4)), Color("5e5442"))

## Your AP: each action costs 1 - a move, an attack, or a fairy.
func _draw_ap_actions() -> void:
	var t := _phase(4.0)
	var origin := Vector2(36, 70)
	_row(origin, 4)
	var step := clampf((t - 0.5) / 0.3, 0.0, 1.0)
	var you := origin + Vector2(T / 2 + step * T, T / 2)
	_player(you)
	var placed := t > 1.9
	if t > 1.5:
		var drop := clampf((t - 1.5) / 0.4, 0.0, 1.0)
		Icon.paint(self, origin + Vector2(T * 2.5, T / 2 - 50 * (1.0 - drop)), icons["wall_fairy"], 0.55)
	var left := 2 - (1 if t > 0.8 else 0) - (1 if placed else 0)
	_ap_boxes(Vector2(70, 26), 2, left)
	if t > 0.8 and t < 1.6:
		_text(you + Vector2(-14, -34), "−1", 20, GOLD, LATIN)
	if placed and t < 2.8:
		_text(origin + Vector2(T * 2.2, -8), "−1", 20, GOLD, LATIN)
	# Legend: the three actions, 1 AP each.
	var legend := [["移動", Color.WHITE], ["攻撃", ORANGE], ["妖精", CYAN]]
	for i in 3:
		var at := Vector2(20 + i * 70, 160)
		draw_rect(Rect2(at, Vector2(62, 44)), Color("101c1e"))
		draw_rect(Rect2(at, Vector2(62, 44)), Color(legend[i][1], 0.6), false, 1)
		_text(at + Vector2(6, 20), legend[i][0], 16, legend[i][1])
		draw_rect(Rect2(at + Vector2(8, 26), Vector2(14, 11)), GOLD)
		_text(at + Vector2(26, 38), "1", 16, GOLD, LATIN)

## AP 0 (or "ターン終了") hands the turn to the enemies.
func _draw_ap_end() -> void:
	var t := _phase(3.4)
	var ended := t > 1.2
	_ap_boxes(Vector2(70, 22), 2, 0 if ended else 1)
	var button := Rect2(Vector2(46, 56), Vector2(140, 34))
	draw_rect(button, Color("203432") if t > 0.9 and t < 1.2 else Color("0c191a"))
	draw_rect(button, CYAN, false, 2)
	_text(button.position + Vector2(18, 24), "ターン終了", 18, INK)
	if t < 1.2:
		_cursor(button.get_center().lerp(button.get_center() + Vector2(40, 60), clampf(1.0 - t / 0.9, 0.0, 1.0)))
	var origin := Vector2(56, 110)
	_row(origin, 3)
	_player(origin + Vector2(T / 2, T / 2))
	var step := clampf((t - 1.6) / 0.4, 0.0, 1.0)
	_enemy(origin + Vector2(T * 2.5 - step * T, T / 2))
	if ended:
		_text(Vector2(62, 196), "敵のターン", 22, RED)

## Enemies spend AP too: an AP-1 enemy moves one tile and is done.
func _draw_enemy_ap1() -> void:
	var t := _phase(3.0)
	var origin := Vector2(36, 96)
	_row(origin, 4)
	_player(origin + Vector2(T / 2, T / 2))
	var step := clampf((t - 0.6) / 0.35, 0.0, 1.0)
	var foe := origin + Vector2(T * 3.5 - step * T, T / 2)
	_enemy(foe)
	_ap_boxes(Vector2(64, 36), 1, 0 if step >= 1.0 else 1, RED, "敵のAP")
	if t > 1.2:
		_text(Vector2(64, 190), "ここで止まる", 20, MUTED)

## An AP-2 enemy moves AND hits: danger from two tiles away.
func _draw_enemy_ap2() -> void:
	var t := _phase(3.4)
	var origin := Vector2(36, 96)
	_row(origin, 4)
	var you := origin + Vector2(T / 2, T / 2)
	var step := clampf((t - 0.6) / 0.35, 0.0, 1.0)
	var foe := origin + Vector2(T * 2.5 - step * T, T / 2)
	var struck := t > 1.5
	_player(you + (Vector2(-4, 0) if struck and t < 1.7 else Vector2.ZERO))
	_enemy(foe)
	var left := 2 - (1 if step >= 1.0 else 0) - (1 if struck else 0)
	_ap_boxes(Vector2(64, 36), 2, left, RED, "敵のAP")
	if struck and t < 2.4:
		draw_arc(you, 18, -2.4, -0.4, 12, Color(1, 1, 1, 0.9), 4, true)
		_text(you + Vector2(-8, -34), "−1", 22, RED, LATIN)
	if struck:
		_hearts(Vector2(70, 196), 4, 5)

## Hovering an enemy shows its AP (how many actions it gets).
func _draw_enemy_ap_info() -> void:
	var t := _phase(3.0)
	var foe := Vector2(56, 70)
	draw_rect(Rect2(foe - Vector2(T / 2, T / 2) + Vector2.ONE * 2, Vector2.ONE * (T - 4)), Color("5e5442"))
	_enemy(foe)
	var shown := t > 0.8
	_cursor(foe.lerp(foe + Vector2(40, 60), clampf(1.0 - t / 0.8, 0.0, 1.0)) + Vector2(6, 6))
	if shown:
		var panel := Rect2(Vector2(96, 24), Vector2(124, 150))
		draw_rect(panel, Color("0b1415"))
		draw_rect(panel, Color("324843"), false, 2)
		_text(panel.position + Vector2(10, 26), "歩兵", 20, INK)
		_text(panel.position + Vector2(10, 56), "HP", 18, RED, LATIN)
		draw_circle(panel.position + Vector2(52, 50), 6, RED)
		var pulse := 0.6 + 0.4 * sin(time * 8.0)
		draw_rect(Rect2(panel.position + Vector2(4, 70), Vector2(116, 30)), Color(GOLD, 0.15 * pulse))
		_ap_boxes(panel.position + Vector2(10, 78), 2, 2)
		_text(panel.position + Vector2(10, 132), "2回動ける", 16, GOLD)
