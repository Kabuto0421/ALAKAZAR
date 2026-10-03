extends Node2D
## Rotorick's casino show, drawn over the board:
##   "intro"   — the lights drop, spotlights sweep, three reels spin and stop on 7-7-7, his name lights up;
##   "lottery" — after each of his spins, a big reel window rolls and stops on the number it drew
##               (and, below 4 HP, a small second window for the mini slot) so the result is hard to miss.
## The battle view waits for LIFE[mode] before play resumes.

const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const LIFE := {"intro": 2.6, "lottery": 1.75}
const GOLD := Color("ffd35b")
const RED := Color("ff3b4a")
const NEON := Color("ff4fd8")
const SYMBOLS := ["7", "♦", "♠", "♥", "★", "7"]

var mode := "lottery"
var time := 0.0
## Board centre and size (base screen units).
var centre := Vector2(640, 432)
var extent := 512.0
var reel := 1
var mini := 0
var reel_color := GOLD
var reel_label := ""
var shake_target: Node2D

func _ready() -> void:
	z_index = 100

func _process(delta: float) -> void:
	time += delta
	if time >= LIFE[mode]:
		var layer := get_parent()
		if layer is CanvasLayer:
			layer.queue_free()
		else:
			queue_free()
		return
	queue_redraw()

func _fade(t0: float, t1: float) -> float:
	return clampf((time - t0) / (t1 - t0), 0.0, 1.0)

func _centered(at: Vector2, text: String, size: int, color: Color, outline: Color = Color(0, 0, 0, 0.85)) -> void:
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var origin := at + Vector2(-width / 2.0, size * 0.36)
	for offset in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(3, 3), Vector2(-3, -3)]:
		draw_string(FONT, origin + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline)
	draw_string(FONT, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

## A frame of chasing marquee bulbs.
func _marquee(rect: Rect2, alpha: float, speed: float = 8.0) -> void:
	var step := 20.0
	var count_x := int(rect.size.x / step)
	var count_y := int(rect.size.y / step)
	var total := (count_x + count_y) * 2
	var index := 0
	for i in count_x:
		_bulb(rect.position + Vector2((i + 0.5) * rect.size.x / count_x, 0), index, total, alpha, speed)
		index += 1
	for i in count_y:
		_bulb(rect.position + Vector2(rect.size.x, (i + 0.5) * rect.size.y / count_y), index, total, alpha, speed)
		index += 1
	for i in count_x:
		_bulb(rect.position + Vector2(rect.size.x - (i + 0.5) * rect.size.x / count_x, rect.size.y), index, total, alpha, speed)
		index += 1
	for i in count_y:
		_bulb(rect.position + Vector2(0, rect.size.y - (i + 0.5) * rect.size.y / count_y), index, total, alpha, speed)
		index += 1

func _bulb(at: Vector2, index: int, _total: int, alpha: float, speed: float) -> void:
	var lit := fmod(float(index) - time * speed, 4.0) < 2.0
	var color := GOLD if index % 2 == 0 else NEON
	draw_circle(at, 7.0, Color(color, (0.28 if lit else 0.06) * alpha))
	draw_circle(at, 3.5, Color(color.lightened(0.5) if lit else color.darkened(0.6), alpha))

func _draw() -> void:
	match mode:
		"intro":
			_draw_intro()
		"lottery":
			_draw_lottery()

# --- the entrance ------------------------------------------------------------

func _draw_intro() -> void:
	var life: float = LIFE["intro"]
	var dark := minf(_fade(0.0, 0.35), 1.0 - _fade(life - 0.45, life))
	var half := extent / 2.0 + 14.0
	var board := Rect2(centre - Vector2.ONE * half, Vector2.ONE * half * 2.0)
	draw_rect(board, Color(0.03, 0.0, 0.06, 0.8 * dark))
	# Two spotlights sweeping across.
	for k in 2:
		var sway := sin(time * 2.2 + k * 2.4) * extent * 0.32
		var top := Vector2(centre.x + (k - 0.5) * extent * 0.9 + sway * 0.4, board.position.y)
		var floor_at := Vector2(centre.x + sway, centre.y + extent * 0.28)
		var spread := 46.0
		var tint := Color(1.0, 0.9, 0.55, 0.16 * dark) if k == 0 else Color(1.0, 0.4, 0.85, 0.14 * dark)
		draw_colored_polygon(PackedVector2Array([top, floor_at + Vector2(-spread, 0), floor_at + Vector2(spread, 0)]), tint)
		draw_circle(floor_at, spread * 0.8, Color(tint, tint.a * 0.7))
	_marquee(board, dark, 14.0 if time < 1.6 else 7.0)
	# The three reels: they spin, then stop one by one on 7.
	var reel_size := Vector2(120, 150)
	for k in 3:
		var at := centre + Vector2((k - 1) * 138.0, -26.0)
		var stop_time := 1.0 + k * 0.28
		var rect := Rect2(at - reel_size / 2.0, reel_size)
		draw_rect(rect, Color(0.05, 0.02, 0.07, 0.95 * dark))
		draw_rect(rect, Color(GOLD, dark), false, 4)
		var symbol := "7"
		var offset := 0.0
		if time < stop_time:
			var fast := time * 34.0
			symbol = SYMBOLS[int(fast + k * 2) % SYMBOLS.size()]
			offset = fmod(fast, 1.0) * 40.0 - 20.0
		else:
			var settle := 1.0 - _fade(stop_time, stop_time + 0.18)
			offset = sin(settle * 9.0) * settle * 10.0
		var tone := RED if symbol == "7" else Color.WHITE
		_centered(at + Vector2(0, offset), symbol, 104, Color(tone, dark))
	# Reels stop: a flash and the name.
	var flash := 1.0 - _fade(1.85, 2.2)
	if time > 1.85:
		draw_rect(board, Color(1.0, 0.95, 0.7, 0.55 * flash * dark))
	var title := _fade(1.9, 2.1)
	if title > 0.0:
		var glow := 0.75 + 0.25 * sin(time * 18.0)
		draw_rect(Rect2(centre + Vector2(-extent * 0.46, 62), Vector2(extent * 0.92, 112)), Color(0.04, 0.0, 0.08, 0.88 * title * dark))
		draw_rect(Rect2(centre + Vector2(-extent * 0.46, 62), Vector2(extent * 0.92, 112)), Color(NEON, title * dark), false, 4)
		_centered(centre + Vector2(0, 100), "ROTORICK", 72, Color(GOLD, title * glow * dark), Color(0.5, 0.0, 0.35, 0.9))
		_centered(centre + Vector2(0, 150), "ロトリック", 34, Color(1, 1, 1, title * dark))
	# Coins burst out on the stop.
	if time > 1.85:
		var burst := _fade(1.85, 2.5)
		for k in 18:
			var angle := k * TAU / 18.0 + 0.2
			var speed := 120.0 + (k % 3) * 70.0
			var pos := centre + Vector2(0, -26.0) + Vector2.from_angle(angle) * speed * burst + Vector2(0, 90.0 * burst * burst)
			draw_circle(pos, 6.0, Color(GOLD, (1.0 - burst) * dark))
			draw_arc(pos, 6.0, 0, TAU, 12, Color(1.0, 0.7, 0.2, (1.0 - burst) * dark), 2)

# --- the draw after each spin ---------------------------------------------------

func _draw_lottery() -> void:
	var life: float = LIFE["lottery"]
	var alpha := minf(_fade(0.0, 0.15), 1.0 - _fade(life - 0.3, life))
	var half := extent / 2.0 + 14.0
	draw_rect(Rect2(centre - Vector2.ONE * half, Vector2.ONE * half * 2.0), Color(0.02, 0.0, 0.05, 0.5 * alpha))
	var stop_at := 1.0
	var window := Rect2(centre + Vector2(-80, -150), Vector2(160, 190))
	_marquee(window.grow(22), alpha, 12.0 if time < stop_at else 5.0)
	draw_rect(window, Color(0.05, 0.02, 0.07, 0.96 * alpha))
	draw_rect(window, Color(reel_color if time > stop_at else GOLD, alpha), false, 5)
	var digit: int
	var offset := 0.0
	if time < stop_at:
		# Slowing roll: the shown digit changes ever more rarely.
		var slow := time / stop_at
		var rate := lerpf(30.0, 5.0, slow * slow)
		var phase := time * rate
		digit = (int(phase * 1.0) * 3 + 1) % 7 + 1
		offset = fmod(phase, 1.0) * 70.0 - 35.0
	else:
		digit = reel
		var settle := 1.0 - _fade(stop_at, stop_at + 0.2)
		offset = sin(settle * 9.0) * settle * 14.0
	_centered(window.get_center() + Vector2(0, offset), str(digit), 150, Color(reel_color if time >= stop_at else Color.WHITE, alpha))
	# The result lands: flash, rings and the name of what it does.
	if time >= stop_at:
		var land := _fade(stop_at, stop_at + 0.55)
		draw_arc(window.get_center(), 90.0 + land * 150.0, 0, TAU, 40, Color(reel_color, (1.0 - land) * alpha), 6)
		draw_arc(window.get_center(), 60.0 + land * 90.0, 0, TAU, 40, Color(1, 1, 1, (1.0 - land) * alpha), 3)
		draw_rect(window, Color(1, 1, 1, 0.45 * (1.0 - _fade(stop_at, stop_at + 0.15)) * alpha))
		var banner := Rect2(centre + Vector2(-190, 62), Vector2(380, 62))
		draw_rect(banner, Color(0.04, 0.02, 0.06, 0.92 * alpha))
		draw_rect(banner, Color(reel_color, alpha), false, 4)
		_centered(banner.get_center(), reel_label, 38, Color(reel_color, alpha))
	# The mini slot (low HP): a smaller window beside it, stopping a beat later.
	if mini > 0:
		var small := Rect2(centre + Vector2(110, -90), Vector2(84, 100))
		draw_rect(small, Color(0.05, 0.02, 0.07, 0.96 * alpha))
		var mini_stop := stop_at + 0.25
		draw_rect(small, Color(RED if time >= mini_stop else GOLD, alpha), false, 4)
		var shown := mini if time >= mini_stop else (int(time * 22.0) % 3) + 1
		_centered(small.get_center(), str(shown), 70, Color(RED if time >= mini_stop else Color.WHITE, alpha))
