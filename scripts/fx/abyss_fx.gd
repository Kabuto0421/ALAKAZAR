extends Node2D
## 奈落の精霊 opening the abyss: the screen darkens and violet light gathers
## under the player, a crack wave runs outward and every pit tile collapses in
## turn (floor shards tumbling into the dark), then a shockwave, a rumble and
## the dust settling. Drawn above the board.

const VIOLET := Color("9b7bff")
const DEEP := Color("08060f")
const FLOOR := Color("5f5442")
const LIFE := 2.6
const GATHER := 0.5
## Seconds for the crack wave to cross one tile.
const WAVE := 0.07
const RUMBLE_END := 2.0

var tile := 64.0
var origin := Vector2.ZERO
## Top-left corners of the pit tiles, nearest first.
var pits: Array[Vector2] = []
var screen := Rect2(0, 0, 1152, 720)
## What the effect shakes (the battle board); it is drawn on its own canvas layer.
var shake_target: Node2D
var time := 0.0
var shards: Array[Dictionary] = []
var cracks: Array[PackedVector2Array] = []
var last_collapse := GATHER

func _ready() -> void:
	z_index = 19
	pits.sort_custom(func(a: Vector2, b: Vector2) -> bool: return _center(a).distance_to(origin) < _center(b).distance_to(origin))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for pit in pits:
		var at := _collapse_time(pit)
		last_collapse = maxf(last_collapse, at)
		for k in 5:
			shards.append({"from": pit + Vector2(rng.randf_range(6, tile - 16), rng.randf_range(6, tile - 16)), "size": rng.randf_range(6, 14), "spin": rng.randf_range(-6, 6), "at": at + rng.randf_range(0, 0.12)})
	# Lightning-like cracks from the player out towards the far pits.
	for i in 8:
		var angle := i * TAU / 8 + rng.randf_range(-0.3, 0.3)
		var crack := PackedVector2Array([origin])
		var point := origin
		for step in 7:
			point += Vector2.from_angle(angle + rng.randf_range(-0.5, 0.5)) * rng.randf_range(24, 44)
			crack.append(point)
		cracks.append(crack)

func _center(pit: Vector2) -> Vector2:
	return pit + Vector2.ONE * tile / 2

func _collapse_time(pit: Vector2) -> float:
	return GATHER + _center(pit).distance_to(origin) / tile * WAVE * 1.6

func _process(delta: float) -> void:
	time += delta
	var parent := shake_target
	if is_instance_valid(parent):
		var shake := 0.0
		if time > GATHER and time < RUMBLE_END:
			shake = 5.0 + 7.0 * clampf((time - GATHER) / (last_collapse - GATHER + 0.01), 0.0, 1.0)
			if time > last_collapse:
				shake *= clampf(1.0 - (time - last_collapse) / (RUMBLE_END - last_collapse), 0.0, 1.0)
		parent.position = Vector2(sin(time * 83.0), cos(time * 71.0)) * shake
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
	# Darkness over the whole screen, deepest while the ground gives way.
	var dark := clampf(time / GATHER, 0.0, 1.0) * 0.55
	if time > last_collapse:
		dark *= clampf(1.0 - (time - last_collapse) / 0.8, 0.0, 1.0)
	draw_rect(screen, Color(0, 0, 0.02, dark))
	_draw_tiles()
	_draw_gather()
	_draw_cracks()
	_draw_shards()
	_draw_finale()

## Before its turn a pit still shows solid floor; then it flashes violet and goes black.
func _draw_tiles() -> void:
	for pit in pits:
		var at := _collapse_time(pit)
		var rect := Rect2(pit, Vector2.ONE * tile)
		if time < at:
			draw_rect(rect, FLOOR)
			draw_rect(rect.grow(-2), FLOOR.lightened(0.08), false, 1)
			# Hairline cracks appear as the wave nears.
			var near := clampf(1.0 - (at - time) / 0.3, 0.0, 1.0)
			if near > 0.0:
				var c := _center(pit)
				draw_line(c + Vector2(-20, -6) * near, c + Vector2(18, 8) * near, Color(0.1, 0.05, 0.2, near), 2)
				draw_line(c + Vector2(-4, -22) * near, c + Vector2(6, 20) * near, Color(0.1, 0.05, 0.2, near), 2)
		else:
			var since := time - at
			draw_rect(rect, DEEP)
			if since < 0.35:
				draw_rect(rect, Color(VIOLET, 0.85 * (1.0 - since / 0.35)))
				draw_rect(rect.grow(-since * 40.0), Color(1, 1, 1, 0.5 * (1.0 - since / 0.35)), false, 3)

func _draw_gather() -> void:
	if time > last_collapse + 0.3:
		return
	var grow := clampf(time / GATHER, 0.0, 1.0)
	for k in 3:
		var r := (1.0 - fmod(time * 1.6 + k / 3.0, 1.0)) * 90.0 * grow
		draw_arc(origin, r, 0, TAU, 36, Color(VIOLET, 0.6 * grow), 3, true)
	draw_circle(origin, 18.0 * grow, Color(VIOLET, 0.35))

func _draw_cracks() -> void:
	if time < GATHER * 0.6 or time > last_collapse + 0.4:
		return
	var reach := clampf((time - GATHER * 0.6) / (last_collapse - GATHER * 0.6 + 0.01), 0.0, 1.0)
	for crack in cracks:
		var count := int(ceil(reach * (crack.size() - 1)))
		for i in count:
			draw_line(crack[i], crack[i + 1], Color(0.8, 0.7, 1.0, 0.9), 3)
			draw_line(crack[i], crack[i + 1], Color(1, 1, 1, 0.9), 1)

## Floor shards drop into the dark: they shrink, spin and fade.
func _draw_shards() -> void:
	for shard in shards:
		var since: float = time - shard.at
		if since < 0.0 or since > 0.7:
			continue
		var k := since / 0.7
		var side: float = shard.size * (1.0 - k)
		var at: Vector2 = shard.from + Vector2(0, since * 30.0)
		draw_set_transform(at, shard.spin * since, Vector2.ONE)
		draw_rect(Rect2(-Vector2.ONE * side / 2, Vector2.ONE * side), Color(FLOOR.lightened(0.15), 1.0 - k))
		draw_set_transform(Vector2.ZERO)

## The shockwave once the last tile has fallen.
func _draw_finale() -> void:
	var since := time - last_collapse
	if since < 0.0 or since >= 0.6:
		return
	draw_arc(origin, 40 + since * 700.0, 0, TAU, 64, Color(VIOLET, 1.0 - since / 0.6), 6, true)
