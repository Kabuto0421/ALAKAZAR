extends Node2D
## 守護神の妖精's entrance, in two layers: `dark` (under the units) dims the board;
## the light layer (over everything) is the show:
##   0.00  the board dims; a golden sigil starts drawing itself on the ground
##   0.15  a pillar of light falls: soft glow, white core, motes streaming down
##   0.75  it lands: a soft flash, a wave of light along the ground, motes rising
##   then  a small pillar of light drops onto each called ally as it appears
##   end   the sigil flares and a last wave rolls out along the ground

const LAND := 0.75
const GOLD := Color("ffe39a")
const SKY := Color("bfe4ff")
var dark := false
## Guardian centre, and each call: {pos, delay}.
var origin := Vector2.ZERO
## One board tile: the sigil's outer ring sits exactly inside the guardian's 2x2.
var tile := 64.0
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
		# Under the units: the dimming and everything lying on the ground.
		var dim := _fade(0.0, 0.25) * (1.0 - _fade(_end(), _end() + 0.5))
		draw_rect(screen, Color(0.02, 0.03, 0.09, 0.55 * dim))
		_draw_sigil()
		_draw_ground()
		return
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
	# At the finale it flares brighter (it never grows past the 2x2).
	var flare := _fade(_end() - 0.05, _end() + 0.1) * (1.0 - _fade(_end() + 0.1, _end() + 0.4))
	var alpha := minf(1.0, out * minf(1.0, grow * 1.5) * (1.0 + flare))
	var spin := time * 0.8
	var r := tile * 0.97
	if flare > 0.0:
		_glow(origin, r, Color(GOLD, 0.35 * flare))
	# The 2x2 frame itself, so the circle reads as set into the guardian's square.
	draw_rect(Rect2(origin - Vector2.ONE * tile, Vector2.ONE * tile * 2), Color(GOLD, 0.45 * alpha * grow), false, 2)
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

## A ring lying flat on the ground (an ellipse), soft: a wide faint band under a thin bright one.
func _ground_ring(at: Vector2, radius: float, color: Color, width: float) -> void:
	draw_set_transform(at, 0.0, Vector2(1.0, 0.36))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 80, Color(color, color.a * 0.25), width * 3.0, true)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 80, color, width, true)
	draw_set_transform(Vector2.ZERO)

## A glow lying flat on the ground.
func _ground_glow(at: Vector2, radius: float, color: Color) -> void:
	draw_set_transform(at, 0.0, Vector2(1.0, 0.36))
	_glow(Vector2.ZERO, radius, color)
	draw_set_transform(Vector2.ZERO)

func _draw_landing() -> void:
	if time < LAND or time > LAND + 1.0:
		return
	var t := time - LAND
	var feet := origin + Vector2(0, 26)
	# A short, soft flash where it lands (no white-out).
	if t < 0.25:
		_glow(origin, 90.0, Color(1, 0.98, 0.9, 0.55 * (1.0 - t / 0.25)))
	# The light spreads over the ground as one smooth wave, then settles into a glow.
	# Motes of light drifting up off the ground.
	var rise := clampf(t / 1.0, 0.0, 1.0)
	for i in motes.size():
		var mote: Dictionary = motes[i]
		var spread: float = mote.x * 110.0
		var at := feet + Vector2(spread, -abs(spread) * 0.1) + Vector2(0, -rise * (60.0 + 90.0 * mote.speed))
		draw_circle(at, mote.size, Color(GOLD if i % 3 else Color.WHITE, 0.9 * (1.0 - rise)))

## A narrow pillar of light dropping onto a tile, landing with a small ground ring.
func _small_pillar(target: Vector2, t: float) -> void:
	var drop := clampf(t / 0.12, 0.0, 1.0)
	var fade := 1.0 - clampf((t - 0.12) / 0.3, 0.0, 1.0)
	if fade <= 0.0:
		return
	var top := target.y - 170.0
	var bottom := lerpf(top, target.y + 18.0, drop)
	_beam(target.x, top, bottom, 22.0, Color(SKY, 0.35 * fade))
	_beam(target.x, top, bottom, 8.0, Color(1, 1, 1, 0.9 * fade))

func _draw_calls():
	for call in calls:
		var t: float = time - float(call.delay) + 0.12
		if t < 0.0 or t > 0.45:
			continue
		_small_pillar(call.pos, t)

func _draw_finale():
	var burst := _fade(_end(), _end() + 0.55)
	if burst <= 0.0 or burst >= 1.0:
		return
	# The sigil flares and one last wave of light rolls out along the ground.
	_glow(origin, 110.0, Color(1, 0.97, 0.85, 0.4 * (1.0 - burst)))

## On the ground, under the units: the landing wave, each call's ring and the last wave.
func _draw_ground() -> void:
	var feet := origin + Vector2(0, 26)
	if time >= LAND and time < LAND + 0.6:
		var p := clampf((time - LAND) / 0.6, 0.0, 1.0)
		var ease_out := 1.0 - (1.0 - p) * (1.0 - p)
		_ground_glow(feet, 60.0 + 110.0 * ease_out, Color(GOLD, 0.45 * (1.0 - p)))
		_ground_ring(feet, 50.0 + 150.0 * ease_out, Color(1, 0.95, 0.8, 0.9 * (1.0 - p)), 3.0)
	for call in calls:
		var t: float = time - float(call.delay)
		if t < 0.0 or t > 0.3:
			continue
		var p := t / 0.3
		var target: Vector2 = call.pos + Vector2(0, 18)
		_ground_glow(target, 30.0 + 16.0 * p, Color(GOLD, 0.5 * (1.0 - p)))
		_ground_ring(target, 16.0 + 26.0 * p, Color(1, 0.95, 0.8, 1.0 - p), 2.0)
	var burst := _fade(_end(), _end() + 0.55)
	if burst > 0.0 and burst < 1.0:
		var ease_out := 1.0 - (1.0 - burst) * (1.0 - burst)
		_ground_ring(feet, 70.0 + 320.0 * ease_out, Color(GOLD, 0.85 * (1.0 - burst)), 3.0)
