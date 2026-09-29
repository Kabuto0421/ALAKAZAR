extends Node2D
## 守護神の妖精's entrance, in two layers: `dark` (under the units) dims the board;
## the light layer (over everything) is the show:
##   0.00  the board dims; a golden sigil starts drawing itself on the ground
##   0.15  a pillar of light falls: soft glow, white core, motes streaming down
##   0.75  it lands: flash, three shockwaves, rotating rays, sparks thrown out
##   then  a curved streak of light flies to each called ally, which bursts in
##   end   the sigil flares and the light bursts across the board

const LAND := 0.75
const GOLD := Color("ffe39a")
const SKY := Color("bfe4ff")
var dark := false
## Guardian centre, and each call: {pos, delay}.
var origin := Vector2.ZERO
var calls: Array = []
var screen := Rect2(0, 0, 1152, 720)
var time := 0.0
var motes: Array = []

func life() -> float:
	return _end() + 0.6

func _end() -> float:
	var last := LAND
	for call in calls:
		last = maxf(last, float(call.delay))
	return last + 0.25

func _ready() -> void:
	z_index = 1 if dark else 60
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		motes.append({"x": rng.randf_range(-1.0, 1.0), "speed": rng.randf_range(0.8, 1.6), "phase": rng.randf(), "size": rng.randf_range(1.5, 3.5)})

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
		var dim := _fade(0.0, 0.25) * (1.0 - _fade(_end(), _end() + 0.5))
		draw_rect(screen, Color(0.02, 0.03, 0.09, 0.55 * dim))
		return
	_draw_sigil()
	_draw_pillar()
	_draw_landing()
	_draw_calls()
	_draw_finale()

## A soft-edged vertical band: transparent at the sides, `color` in the middle.
func _beam(x: float, top: float, bottom: float, half: float, color: Color) -> void:
	var clear := Color(color, 0.0)
	draw_polygon(PackedVector2Array([Vector2(x - half, top), Vector2(x, top), Vector2(x, bottom), Vector2(x - half, bottom)]), PackedColorArray([clear, color, color, clear]))
	draw_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + half, top), Vector2(x + half, bottom), Vector2(x, bottom)]), PackedColorArray([color, clear, clear, color]))

## A glow disc: bright centre fading to nothing.
func _glow(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([at])
	var colors := PackedColorArray([color])
	for i in 33:
		points.append(at + Vector2.from_angle(i * TAU / 32) * radius)
		colors.append(Color(color, 0.0))
	for i in 32:
		draw_polygon(PackedVector2Array([points[0], points[i + 1], points[i + 2]]), PackedColorArray([colors[0], colors[i + 1], colors[i + 2]]))

func _draw_sigil() -> void:
	# A golden circle drawn on the ground under the guardian, turning slowly.
	var grow := _fade(0.0, LAND)
	var out := 1.0 - _fade(_end() + 0.1, _end() + 0.55)
	if grow <= 0.0 or out <= 0.0:
		return
	var flare := 1.0 + 0.6 * _fade(_end() - 0.05, _end() + 0.1) * (1.0 - _fade(_end() + 0.1, _end() + 0.4))
	var alpha := out * minf(1.0, grow * 1.5)
	var spin := time * 0.8
	var r := 78.0 * flare
	draw_arc(origin, r, spin, spin + TAU * grow, 64, Color(GOLD, 0.85 * alpha), 3, true)
	draw_arc(origin, r * 0.8, -spin, -spin + TAU * grow, 64, Color(GOLD, 0.6 * alpha), 2, true)
	for i in 12:
		var a := spin + i * TAU / 12
		if float(i) / 12.0 > grow:
			break
		draw_line(origin + Vector2.from_angle(a) * r * 0.8, origin + Vector2.from_angle(a) * r, Color(GOLD, 0.8 * alpha), 2)
	# A six-pointed star inside.
	for k in 2:
		var tri := PackedVector2Array()
		for i in 4:
			tri.append(origin + Vector2.from_angle(-spin * 0.5 + k * PI / 3 + i * TAU / 3) * r * 0.72)
		draw_polyline(tri, Color(GOLD, 0.55 * alpha * grow), 2, true)

func _draw_pillar() -> void:
	var fall := _fade(0.15, LAND)
	if fall <= 0.0 or time > LAND + 0.45:
		return
	var alpha := 1.0 - _fade(LAND + 0.05, LAND + 0.45)
	var top := screen.position.y
	var bottom := lerpf(top, origin.y, fall * fall)
	var flicker := 0.9 + 0.1 * sin(time * 60.0)
	var half := 26.0 + 30.0 * fall + (40.0 * _fade(LAND, LAND + 0.15) if time > LAND else 0.0)
	_beam(origin.x, top, bottom, half * 2.2, Color(SKY, 0.22 * alpha))
	_beam(origin.x, top, bottom, half, Color(SKY, 0.55 * alpha * flicker))
	_beam(origin.x, top, bottom, half * 0.35, Color(1, 1, 1, 0.95 * alpha))
	# Motes of light streaming down inside it.
	for mote in motes:
		var y := top + fmod(mote.phase + time * mote.speed, 1.0) * (bottom - top)
		draw_circle(Vector2(origin.x + mote.x * half * 0.9, y), mote.size, Color(1, 1, 1, 0.8 * alpha))
	# The head of the pillar: a hot glow where it hits.
	_glow(Vector2(origin.x, bottom), half * 1.6, Color(1, 1, 1, 0.7 * alpha))

func _draw_landing() -> void:
	if time < LAND or time > LAND + 0.8:
		return
	var t := time - LAND
	_glow(origin, 150.0 * (1.0 - t / 0.8) + 40.0, Color(1, 0.98, 0.9, 0.9 * (1.0 - t / 0.35) if t < 0.35 else 0.0))
	# Three shockwaves, one after another.
	for k in 3:
		var w := t - k * 0.08
		if w < 0.0 or w > 0.5:
			continue
		var p := w / 0.5
		draw_arc(origin, 40 + 230 * p, 0, TAU, 72, Color(GOLD if k != 1 else Color.WHITE, (1.0 - p) * 0.9), 8.0 * (1.0 - p) + 1.0, true)
	# Rotating rays.
	var ray_alpha := 1.0 - clampf(t / 0.6, 0.0, 1.0)
	for i in 12:
		var a := i * TAU / 12 + t * 1.5
		var inner := origin + Vector2.from_angle(a) * 40.0
		var outer := origin + Vector2.from_angle(a) * (140.0 + 60.0 * t)
		draw_line(inner, outer, Color(1, 0.96, 0.8, 0.5 * ray_alpha), 6.0 if i % 2 == 0 else 3.0)
	# Sparks thrown out.
	for i in 18:
		var dir := Vector2.from_angle(i * TAU / 18 + 0.17)
		var at := origin + dir * (30.0 + 260.0 * t) + Vector2(0, 90.0 * t * t)
		draw_rect(Rect2(at - Vector2(2.5, 2.5), Vector2(5, 5)), Color(GOLD if i % 3 else Color.WHITE, ray_alpha))

func _draw_calls():
	for call in calls:
		var t: float = time - float(call.delay)
		if t < -0.06 or t > 0.45:
			continue
		var target: Vector2 = call.pos
		var k := clampf((t + 0.06) / 0.14, 0.0, 1.0)
		var fade := 1.0 - clampf((t - 0.1) / 0.35, 0.0, 1.0)
		# A curved streak arcing up and over to the ally, with a bright head.
		var mid := (origin + target) / 2.0 + Vector2(0, -70)
		var trail := PackedVector2Array()
		for i in 13:
			var s := k * i / 12.0
			trail.append(origin.lerp(mid, s).lerp(mid.lerp(target, s), s))
		if trail.size() >= 2:
			draw_polyline(trail, Color(GOLD, 0.55 * fade), 9, true)
			draw_polyline(trail, Color(1, 1, 1, 0.95 * fade), 3, true)
		_glow(trail[-1], 18, Color(1, 1, 1, 0.9 * fade))
		if k >= 1.0:
			# The ally bursts in: a flash, a ring and a small sigil at its feet.
			var p := clampf(t / 0.35, 0.0, 1.0)
			_glow(target, 44 * (1.0 - p) + 10, Color(1, 0.97, 0.85, 0.8 * (1.0 - p)))
			draw_arc(target, 14 + 34 * p, 0, TAU, 32, Color(GOLD, 1.0 - p), 3, true)
			for i in 8:
				var dir := Vector2.from_angle(i * TAU / 8 + p)
				draw_line(target + dir * (10 + 14 * p), target + dir * (20 + 26 * p), Color(1, 1, 1, 1.0 - p), 2)

func _draw_finale():
	var burst := _fade(_end(), _end() + 0.55)
	if burst <= 0.0 or burst >= 1.0:
		return
	# A quick white-gold flash, then two wide rings racing over the board.
	if burst < 0.2:
		draw_rect(screen, Color(1, 0.97, 0.85, 0.35 * (1.0 - burst / 0.2)))
	_glow(origin, 120 + 200 * burst, Color(GOLD, 0.35 * (1.0 - burst)))
	draw_arc(origin, 50 + 520 * burst, 0, TAU, 96, Color(GOLD, 1.0 - burst), 10.0 * (1.0 - burst) + 2.0, true)
	draw_arc(origin, 30 + 400 * burst, 0, TAU, 96, Color(1, 1, 1, 0.85 * (1.0 - burst)), 3, true)
