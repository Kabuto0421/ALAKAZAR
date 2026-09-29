extends Node2D
## A link in a cannon chain, COMBO style: "CHAIN" over a big "×n" that slams in,
## a burst of speed lines, colours heating up with the count. The last link of a
## chain also throws a banner across the board: "n CHAIN!!" and the hits.

const FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const LIFE := 0.95
const HEAT := [Color("fff27a"), Color("ffc93c"), Color("ff8a2a"), Color("ff4a3a"), Color("ff3aa8"), Color("b86bff")]

var count := 2
var banner := false
var hits := 0
var board := Rect2(316, 96, 512, 512)
var time := 0.0

func _ready() -> void:
	z_index = 60

func _process(delta: float) -> void:
	time += delta
	if time >= LIFE + (0.5 if banner else 0.0):
		queue_free()
		return
	queue_redraw()

func _heat() -> Color:
	return HEAT[clampi(count - 2, 0, HEAT.size() - 1)]

func _outlined(at: Vector2, text: String, size: int, color: Color, alpha: float) -> void:
	for offset in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4), Vector2(-3, -3), Vector2(3, 3), Vector2(3, -3), Vector2(-3, 3)]:
		draw_string(FONT, at + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.08, 0.02, 0.05, alpha))
	draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, alpha))

func _draw() -> void:
	var t := minf(time, LIFE)
	var alpha := clampf(1.0 - (t - LIFE * 0.6) / (LIFE * 0.4), 0.0, 1.0)
	var heat := _heat()
	# Speed lines bursting out of the cannon.
	if t < 0.3:
		var k := t / 0.3
		for i in 16:
			var dir := Vector2.from_angle(i * TAU / 16 + 0.2)
			draw_line(dir * (20 + 60 * k), dir * (50 + 140 * k), Color(heat, 1.0 - k), 4)
		draw_circle(Vector2.ZERO, 34 * (1.0 - k) + 6, Color(1, 1, 1, 0.8 * (1.0 - k)))
	# "×n" slams in big, then settles.
	var slam := 1.0 + 1.2 * maxf(0.0, 1.0 - t / 0.12)
	var size := int((44 + mini(count, 8) * 6) * slam)
	var number := "×%d" % count
	var width := FONT.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var rise := -40 - t * 30
	_outlined(Vector2(-width / 2, rise), number, size, heat, alpha)
	var label := "CHAIN"
	var lw := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	_outlined(Vector2(-lw / 2, rise - size * 0.72), label, 26, Color.WHITE, alpha)
	if banner:
		_draw_banner()

func _draw_banner() -> void:
	var t := time - 0.15
	if t < 0.0:
		return
	var alpha := clampf(1.0 - (t - 0.9) / 0.4, 0.0, 1.0)
	var slide := minf(t / 0.12, 1.0)
	var center := board.get_center() - position
	var band := Rect2(Vector2(board.position.x - position.x - 40 + (1.0 - slide) * -300, center.y - 58), Vector2(board.size.x + 80, 104))
	draw_rect(band, Color(0.05, 0.02, 0.08, 0.78 * alpha))
	draw_rect(Rect2(band.position, Vector2(band.size.x, 5)), Color(_heat(), alpha))
	draw_rect(Rect2(band.position + Vector2(0, band.size.y - 5), Vector2(band.size.x, 5)), Color(_heat(), alpha))
	var title := "%d CHAIN!!" % count
	var size := int(68 * (1.0 + 0.5 * maxf(0.0, 1.0 - t / 0.12)))
	var width := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_outlined(Vector2(center.x - width / 2, center.y + 6), title, size, _heat(), alpha)
	var sub := "%d HIT" % hits
	var sw := FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_outlined(Vector2(center.x - sw / 2, center.y + 38), sub, 30, Color.WHITE, alpha)
