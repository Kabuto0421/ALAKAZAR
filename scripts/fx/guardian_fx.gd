extends Node2D
## 守護神の妖精's entrance, in two layers: `dark` (under the units) dims the board;
## the light layer (over everything) drops a pillar of light onto the guardian, then
## shoots a streak to each ally it calls as they pop in, and ends in a burst.

const LAND := 0.75
var dark := false
## Guardian centre, and each call: {pos, delay}.
var origin := Vector2.ZERO
var calls: Array = []
var screen := Rect2(0, 0, 1152, 720)
var time := 0.0

func life() -> float:
	return _end() + 0.5

func _end() -> float:
	var last := LAND
	for call in calls:
		last = maxf(last, float(call.delay))
	return last + 0.2

func _ready() -> void:
	z_index = 1 if dark else 60

func _process(delta: float) -> void:
	time += delta
	if time >= life():
		queue_free()
		return
	queue_redraw()

func _fade(t0: float, t1: float) -> float:
	return clampf((time - t0) / (t1 - t0), 0.0, 1.0)

func _draw() -> void:
	if dark:
		var dim := _fade(0.0, 0.25) * (1.0 - _fade(_end(), _end() + 0.45))
		draw_rect(screen, Color(0.02, 0.03, 0.08, 0.5 * dim))
		return
	var gold := Color("ffe39a")
	var sky := Color("bfe4ff")
	# The pillar of light falling onto the guardian.
	var fall := _fade(0.15, LAND)
	if time < LAND + 0.3:
		var top := Vector2(origin.x, screen.position.y)
		var bottom := top.lerp(origin, fall)
		var width := 18.0 + 40.0 * fall
		var alpha := 1.0 - _fade(LAND, LAND + 0.3)
		draw_rect(Rect2(Vector2(origin.x - width, top.y), Vector2(width * 2, bottom.y - top.y)), Color(sky, 0.35 * alpha))
		draw_rect(Rect2(Vector2(origin.x - width * 0.35, top.y), Vector2(width * 0.7, bottom.y - top.y)), Color(1, 1, 1, 0.8 * alpha))
	if time >= LAND and time < LAND + 0.4:
		var k := _fade(LAND, LAND + 0.4)
		draw_arc(origin, 30 + 90 * k, 0, TAU, 48, Color(gold, 1.0 - k), 6, true)
		draw_circle(origin, 50 * (1.0 - k), Color(1, 1, 1, 0.7 * (1.0 - k)))
	# A streak to each ally as it is called.
	for call in calls:
		var t: float = time - float(call.delay)
		if t < -0.05 or t > 0.35:
			continue
		var k := clampf(t / 0.12, 0.0, 1.0)
		var fade := 1.0 - clampf((t - 0.12) / 0.23, 0.0, 1.0)
		var tip: Vector2 = origin.lerp(call.pos, k)
		draw_line(origin, tip, Color(gold, 0.6 * fade), 10)
		draw_line(origin, tip, Color(1, 1, 1, fade), 3)
		if k >= 1.0:
			draw_circle(call.pos, 26 * fade + 4, Color(1, 1, 1, 0.55 * fade))
			for i in 8:
				var dir := Vector2.from_angle(i * TAU / 8)
				draw_line(call.pos + dir * 14, call.pos + dir * (24 + 20 * (1.0 - fade)), Color(gold, fade), 2)
	# Everyone is here: the light bursts outward.
	var burst := _fade(_end(), _end() + 0.45)
	if burst > 0.0 and burst < 1.0:
		draw_arc(origin, 40 + 360 * burst, 0, TAU, 64, Color(gold, 1.0 - burst), 8, true)
		draw_arc(origin, 30 + 260 * burst, 0, TAU, 64, Color(1, 1, 1, 0.8 * (1.0 - burst)), 3, true)
