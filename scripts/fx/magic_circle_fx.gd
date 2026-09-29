extends Node2D
## The magic circle going off: the chalk line ignites, a sigil unfolds over
## the captured area, gathers light, then bursts into pillars of light with a
## white flash, a shockwave and a rain of sparks. Drawn above every unit.

const LATIN = preload("res://assets/fonts/VT323-Regular.ttf")
const VIOLET := Color("ffffff")
const CYAN := Color("e4eeff")
const GOLD := Color("ffd35b")
const WHITE := Color("fffaf0")
const LIFE := 2.9
const IGNITE := 0.45
const SIGIL := 1.25
const BURST := 1.45

var tile := 64.0
## Centres of the captured tiles, of the white line around them, and of the enemies hit.
var area: Array[Vector2] = []
var line: Array[Vector2] = []
var targets: Array[Vector2] = []
var damage := 99
## The screen area to flash (the battle view's own coordinates).
var screen := Rect2(0, 0, 1152, 720)
## What the effect shakes (the battle board); it is drawn on its own canvas layer.
var shake_target: Node2D
var time := 0.0
var center := Vector2.ZERO
var radius := 80.0
var sparks: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var runes: Array[PackedVector2Array] = []

func _ready() -> void:
	z_index = 20
	var sum := Vector2.ZERO
	for point in area:
		sum += point
	center = sum / maxf(1, area.size())
	for point in area:
		radius = maxf(radius, point.distance_to(center) + tile * 0.9)
	# The line ignites in order around the centre.
	line.sort_custom(func(a: Vector2, b: Vector2) -> bool: return (a - center).angle() < (b - center).angle())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for i in 90:
		sparks.append({"angle": rng.randf() * TAU, "speed": rng.randf_range(180, 620), "size": rng.randf_range(2, 5), "color": [WHITE, GOLD, CYAN, VIOLET][i % 4]})
	for i in 40:
		motes.append({"from": area[rng.randi_range(0, area.size() - 1)] + Vector2(rng.randf_range(-24, 24), rng.randf_range(-24, 24)), "rise": rng.randf_range(40, 140), "delay": rng.randf_range(0, 0.8)})
	# Hand-made looking glyphs: short random strokes inside a small box.
	for i in 16:
		var glyph := PackedVector2Array()
		for k in 4:
			glyph.append(Vector2(rng.randf_range(-6, 6), rng.randf_range(-8, 8)))
		runes.append(glyph)

func _process(delta: float) -> void:
	time += delta
	var parent := shake_target
	if is_instance_valid(parent):
		# A heavy shake at the burst, dying away.
		var shake := 0.0
		if time > BURST and time < BURST + 0.6:
			shake = 12.0 * (1.0 - (time - BURST) / 0.6)
		parent.position = Vector2(sin(time * 91.0), cos(time * 77.0)) * shake
	if time >= LIFE:
		if is_instance_valid(parent):
			parent.position = Vector2.ZERO
		# Its canvas layer goes with it.
		var layer := get_parent()
		if layer is CanvasLayer:
			layer.queue_free()
		else:
			queue_free()
		return
	queue_redraw()

func _draw() -> void:
	_draw_area()
	_draw_ignite()
	_draw_sigil()
	_draw_burst()
	_draw_numbers()

## The captured ground glows, brighter as the spell gathers.
func _draw_area() -> void:
	var rise := clampf(time / SIGIL, 0.0, 1.0)
	var fall := 1.0 if time < BURST else clampf(1.0 - (time - BURST) / 1.2, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(time * 14.0)
	for point in area:
		var rect := Rect2(point - Vector2.ONE * tile / 2 + Vector2.ONE * 2, Vector2.ONE * (tile - 4))
		draw_rect(rect, Color(VIOLET, (0.18 + 0.22 * rise * pulse) * fall))
		draw_rect(rect, Color(CYAN, 0.7 * rise * fall), false, 2)

## A spark races along the white line, lighting it tile by tile.
func _draw_ignite() -> void:
	if line.is_empty():
		return
	var lit := int(clampf(time / IGNITE, 0.0, 1.0) * line.size())
	var fall := 1.0 if time < BURST else clampf(1.0 - (time - BURST) / 0.5, 0.0, 1.0)
	for i in mini(lit + 1, line.size()):
		var point := line[i]
		draw_rect(Rect2(point - Vector2.ONE * (tile / 2 - 3), Vector2.ONE * (tile - 6)), Color(WHITE, 0.55 * fall))
		draw_rect(Rect2(point - Vector2.ONE * (tile / 2 - 3), Vector2.ONE * (tile - 6)), Color(GOLD, fall), false, 3)
		if i > 0:
			draw_line(line[i - 1], point, Color(WHITE, fall), 4)
	if lit > 0 and lit >= line.size():
		draw_line(line[line.size() - 1], line[0], Color(WHITE, fall), 4)
	if time < IGNITE:
		var head := line[mini(lit, line.size() - 1)]
		draw_circle(head, 10, Color(WHITE, 0.9))
		draw_circle(head, 18, Color(GOLD, 0.35))

## The sigil: rings, ticks, runes and a turning hexagram over the whole area.
func _draw_sigil() -> void:
	if time < IGNITE * 0.6:
		return
	var open := clampf((time - IGNITE * 0.6) / 0.5, 0.0, 1.0)
	open = 1.0 - pow(1.0 - open, 3.0)
	var gather := clampf((time - SIGIL) / (BURST - SIGIL), 0.0, 1.0)
	var r := radius * open * (1.0 - 0.18 * gather)
	var fade := 1.0
	if time > BURST:
		fade = clampf(1.0 - (time - BURST) / 0.9, 0.0, 1.0)
		r *= 1.0 + (time - BURST) * 0.8
	if fade <= 0.0 or r < 2.0:
		return
	var spin := time * 1.6
	# Soft halo.
	for k in 5:
		draw_circle(center, r * (1.0 - k * 0.12), Color(VIOLET, 0.05 * fade))
	# Double outer ring with 48 ticks.
	draw_arc(center, r, 0, TAU, 96, Color(CYAN, fade), 3, true)
	draw_arc(center, r * 0.93, 0, TAU, 96, Color(WHITE, 0.8 * fade), 2, true)
	for k in 48:
		var a := spin * 0.5 + k * TAU / 48
		var long := 10.0 if k % 4 == 0 else 5.0
		draw_line(center + Vector2.from_angle(a) * r * 0.93, center + Vector2.from_angle(a) * (r * 0.93 - long), Color(CYAN, 0.9 * fade), 2)
	# Rune band turning the other way.
	var band := r * 0.8
	draw_arc(center, band + 12, 0, TAU, 80, Color(VIOLET, 0.8 * fade), 2, true)
	draw_arc(center, band - 12, 0, TAU, 80, Color(VIOLET, 0.8 * fade), 2, true)
	for k in runes.size():
		var a := -spin * 0.8 + k * TAU / runes.size()
		var at := center + Vector2.from_angle(a) * band
		var glyph := PackedVector2Array()
		for p in runes[k]:
			glyph.append(at + p.rotated(a + PI / 2))
		draw_polyline(glyph, Color(GOLD, fade), 2)
	# Hexagram.
	var star := r * 0.62
	for flip in [0.0, PI]:
		var tri := PackedVector2Array()
		for k in 4:
			tri.append(center + Vector2.from_angle(spin + flip + k * TAU / 3 - PI / 2) * star)
		draw_polyline(tri, Color(WHITE, 0.95 * fade), 3, true)
	draw_arc(center, star, 0, TAU, 64, Color(GOLD, 0.9 * fade), 2, true)
	# Inner core ring and pentagram, spinning fast while it gathers.
	var core := r * 0.3
	var pent := PackedVector2Array()
	for k in 6:
		pent.append(center + Vector2.from_angle(-spin * (2.0 + gather * 6.0) + k * TAU * 2 / 5 - PI / 2) * core)
	draw_polyline(pent, Color(CYAN, fade), 2, true)
	draw_arc(center, core, 0, TAU, 48, Color(WHITE, fade), 2, true)
	draw_circle(center, 6 + gather * 22, Color(WHITE, (0.5 + 0.5 * gather) * fade))
	# Motes spiral in while it gathers.
	if time > SIGIL - 0.3 and time < BURST:
		var pull := clampf((time - (SIGIL - 0.3)) / (BURST - SIGIL + 0.3), 0.0, 1.0)
		for k in 24:
			var a := k * TAU / 24 + pull * 5.0
			var d := r * (1.1 - pull)
			draw_circle(center + Vector2.from_angle(a) * d, 3, Color(WHITE, 0.9))

## The burst: white-out, pillars of light on every captured tile, a shockwave and sparks.
func _draw_burst() -> void:
	if time < BURST:
		return
	var t := time - BURST
	# Flash.
	var flash := clampf(1.0 - t / 0.35, 0.0, 1.0)
	if flash > 0.0:
		draw_rect(screen, Color(1, 0.98, 0.92, 0.85 * flash))
	# Pillars of light.
	var pillar := clampf(1.0 - t / 1.1, 0.0, 1.0)
	if pillar > 0.0:
		for point in area:
			var width := tile * (0.9 - t * 0.5)
			if width <= 0.0:
				continue
			var top := screen.position.y
			draw_rect(Rect2(Vector2(point.x - width / 2, top), Vector2(width, point.y + tile / 2 - top)), Color(VIOLET, 0.25 * pillar))
			draw_rect(Rect2(Vector2(point.x - width / 4, top), Vector2(width / 2, point.y + tile / 2 - top)), Color(CYAN, 0.35 * pillar))
			draw_rect(Rect2(Vector2(point.x - width / 10, top), Vector2(width / 5, point.y + tile / 2 - top)), Color(WHITE, 0.9 * pillar))
			draw_circle(point, tile * 0.45 * (1.0 + t), Color(WHITE, 0.4 * pillar))
	# Shockwaves, split into three colours.
	var wave := clampf(1.0 - t / 0.9, 0.0, 1.0)
	if wave > 0.0:
		var reach := radius * (1.0 + t * 4.0)
		draw_arc(center, reach, 0, TAU, 96, Color(VIOLET, wave), 10, true)
		draw_arc(center, reach * 0.97, 0, TAU, 96, Color(CYAN, wave), 6, true)
		draw_arc(center, reach * 0.94, 0, TAU, 96, Color(WHITE, wave), 3, true)
	# Sparks flying out.
	var fly := clampf(1.0 - t / 1.3, 0.0, 1.0)
	if fly > 0.0:
		for spark in sparks:
			var dist: float = spark.speed * t * (1.0 - t * 0.3)
			var at: Vector2 = center + Vector2.from_angle(spark.angle) * dist + Vector2(0, 60 * t * t)
			var tail: Vector2 = at - Vector2.from_angle(spark.angle) * 14
			draw_line(tail, at, Color(spark.color, fly), spark.size)
	# Motes drifting up afterwards.
	for mote in motes:
		var life: float = t - mote.delay
		if life <= 0.0 or life > 1.2:
			continue
		var at: Vector2 = mote.from + Vector2(sin(life * 6.0 + mote.rise) * 6.0, -mote.rise * life)
		draw_circle(at, 2.5, Color(GOLD, 1.0 - life / 1.2))

## Big "99"s popping over every enemy caught.
func _draw_numbers() -> void:
	if time < BURST:
		return
	var t := time - BURST
	var alpha := clampf(1.0 - (t - 0.9) / 0.5, 0.0, 1.0)
	var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - t / 0.18)
	var size := int(58 * pop)
	var text := str(damage)
	for point in targets:
		var at := point + Vector2(-size * 0.5, -tile * 0.5 - t * 30)
		for offset in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3)]:
			draw_string(LATIN, at + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.1, 0.02, 0.2, alpha))
		draw_string(LATIN, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(GOLD, alpha))
		draw_string(LATIN, at + Vector2(0, -2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(WHITE, alpha * 0.5))
