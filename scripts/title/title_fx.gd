extends Node2D
## The title screen's particle layer, drawn over the painted background and under the
## heroes, the army and the logo: fireflies drifting in the moonlit forest (left), rain
## slanting through the neon prison city (right) that turns into digital rain when the
## music goes cyber, sparks thrown up by the lead, and the lightning bolt and shock
## ring of a big hit. Everything ambient runs on its own clock; the screen calls
## pop_fly / twinkle / spark_burst / strike on the music's cues. The sparks and motes
## are drawn by a second node (`sparks`) that the screen places in front of the army,
## so they fly over the soldiers instead of behind them.

## Where the two armies meet (the crack in the painted background).
const CLASH := Vector2(884, 860)
const RAIN_LEFT := 880.0
const RAIN_RIGHT := 1760.0

var time := 0.0
## 0: slanting pink rain, 1: green-cyan digital rain (columns of falling blocks).
var digital := 0.0
## Digital rain on the forest's side too (only when both worlds play together).
var digital_left := 0.0
## 0-1: how hard the music plays (how much rain falls).
var energy := 0.5

var _flies: Array = []  # [home, phase, speed, glow]
var _drops: Array = []  # [position, speed, length]
var _left_drops: Array = []
var _motes: Array = []  # [position, velocity, life, life at start, colour, size, gravity, streak]
var _bolt: Array = []  # polylines (PackedVector2Array), the trunk first
var _bolt_born := -10.0
var _bolt_color := Color.WHITE
var _rings: Array = []  # [born, colour, strength]
var _rng := RandomNumberGenerator.new()
var sparks: Node2D

## Draws the parent's motes (see TitleFx.draw_motes).
class Sparks extends Node2D:
	var fx: Node2D

	func _init() -> void:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		fx.draw_motes(self)

func _ready() -> void:
	sparks = Sparks.new()
	sparks.fx = self
	add_child(sparks)
	_rng.seed = 2207
	for i in 34:
		_flies.append([Vector2(_rng.randf_range(20, 820), _rng.randf_range(330, 1040)), _rng.randf_range(0, TAU), _rng.randf_range(0.5, 1.2), 0.0])
	for i in 150:
		_drops.append([Vector2(_rng.randf_range(RAIN_LEFT, RAIN_RIGHT), _rng.randf_range(0, 1080)), _rng.randf_range(900, 1300), _rng.randf_range(14, 26)])
	for i in 70:
		_left_drops.append([Vector2(_rng.randf_range(20, RAIN_LEFT), _rng.randf_range(0, 1080)), _rng.randf_range(700, 1100), _rng.randf_range(14, 26)])
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add

func _process(delta: float) -> void:
	time += delta
	for fly in _flies:
		fly[3] = maxf(0.0, fly[3] - delta * 1.8)
	var i := _motes.size() - 1
	while i >= 0:
		var mote: Array = _motes[i]
		mote[2] -= delta
		if mote[2] <= 0.0:
			_motes[i] = _motes[-1]
			_motes.pop_back()
		else:
			mote[1].y += mote[6] * delta
			mote[0] += mote[1] * delta
		i -= 1
	_rings = _rings.filter(func(ring: Array) -> bool: return time - ring[0] < 0.9)
	queue_redraw()

# --- the music's cues -----------------------------------------------------------

## A melody note makes one firefly flare and shed a few motes.
func pop_fly(seed: int, amount: float = 1.0) -> void:
	var fly: Array = _flies[posmod(seed * 7, _flies.size())]
	fly[3] = maxf(fly[3], amount)
	var at := _fly_at(fly)
	for k in 3:
		_add_mote(at, Vector2(_rng.randf_range(-24, 24), _rng.randf_range(-70, -25)), 1.0, Color(0.8, 1.0, 0.5, 0.8), 2.6, -20.0, false)

## A harp note: a firefly glimmers.
func twinkle(seed: int) -> void:
	var fly: Array = _flies[posmod(seed * 13 + 5, _flies.size())]
	fly[3] = maxf(fly[3], 0.55)

## Sparks thrown up from the ground at x (the EDM lead's notes).
func spark_burst(x: float, count: int, color: Color, power: float = 1.0) -> void:
	for k in count:
		var vel := Vector2(_rng.randf_range(-140, 140), -_rng.randf_range(450, 900) * power)
		_add_mote(Vector2(x + _rng.randf_range(-16, 16), _rng.randf_range(790, 880)), vel, _rng.randf_range(0.5, 0.95), color, _rng.randf_range(3.5, 6.0), 900.0, true)

## A big hit: a lightning bolt from the sky to where the armies meet, and a shock ring
## spreading along the ground.
func strike(color: Color, strength: float = 1.0) -> void:
	_bolt_born = time
	_bolt_color = color
	_bolt.clear()
	var top := Vector2(CLASH.x + _rng.randf_range(-60, 60), -20.0)
	var trunk := PackedVector2Array([top])
	var steps := 13
	for s in range(1, steps):
		var f := float(s) / steps
		var wobble := (1.0 - f) * 70.0 + 14.0
		trunk.append(top.lerp(CLASH, f) + Vector2(_rng.randf_range(-wobble, wobble), 0.0))
	trunk.append(CLASH)
	_bolt.append(trunk)
	for b in 3:
		var from: Vector2 = trunk[_rng.randi_range(3, steps - 3)]
		var branch := PackedVector2Array([from])
		var dir := Vector2(_rng.randf_range(-1, 1), 1.0).normalized()
		for s in 4:
			from += dir * _rng.randf_range(34, 60) + Vector2(_rng.randf_range(-16, 16), 0)
			branch.append(from)
		_bolt.append(branch)
	_rings.append([time, color, strength])

func _add_mote(at: Vector2, vel: Vector2, life: float, color: Color, size: float, gravity: float, streak: bool) -> void:
	if _motes.size() < 420:
		_motes.append([at, vel, life, life, color, size, gravity, streak])

func _fly_at(fly: Array) -> Vector2:
	var phase: float = fly[1] + time * fly[2]
	return fly[0] + Vector2(sin(phase * 0.7) * 26, cos(phase * 0.5) * 18)

# --- drawing --------------------------------------------------------------------

func _draw() -> void:
	_draw_rain()
	for fly in _flies:
		var phase: float = fly[1] + time * fly[2]
		var at := _fly_at(fly)
		var glow := (0.35 + 0.65 * maxf(0.0, sin(phase * 1.8))) * (0.55 + 0.45 * energy)
		var flare: float = fly[3]
		draw_circle(at, 7 + 12 * flare, Color(0.75, 1.0, 0.45, 0.10 * glow + 0.3 * flare))
		draw_circle(at, 2.6 + 2.0 * flare, Color(0.92, 1.0, 0.62, minf(1.0, 0.85 * glow + flare)))
	for ring in _rings:
		var f: float = (time - ring[0]) / 0.9
		var color: Color = ring[1]
		color.a *= (1.0 - f) * 0.7 * ring[2]
		draw_set_transform(CLASH, 0.0, Vector2(1.0, 0.22))
		draw_arc(Vector2.ZERO, 40.0 + 1100.0 * sqrt(f), 0.0, TAU, 72, color, 10.0 * (1.0 - f) + 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_bolt()

## The sparks and motes, drawn on `canvas` (the front node).
func draw_motes(canvas: CanvasItem) -> void:
	for mote in _motes:
		var fade: float = clampf(mote[2] / mote[3], 0.0, 1.0)
		var color: Color = mote[4]
		color.a *= fade
		if mote[7]:
			var vel: Vector2 = mote[1]
			canvas.draw_line(mote[0], mote[0] - vel * 0.04, color, mote[5])
			canvas.draw_line(mote[0], mote[0] - vel * 0.015, Color(1.0, 1.0, 1.0, color.a), mote[5] * 0.5)
		else:
			canvas.draw_circle(mote[0], mote[5] * (0.5 + 0.5 * fade), color)

func _draw_rain() -> void:
	var count := int(lerpf(0.0, 150.0, pow(energy, 1.5)))
	var slant_a := 1.0 - digital
	for n in count:
		var drop: Array = _drops[n]
		var speed: float = drop[1]
		var y := fposmod(drop[0].y + time * speed, 1100.0) - 20.0
		if slant_a > 0.01:
			var x: float = drop[0].x - (y - drop[0].y) * 0.12
			var x0 := fposmod(x - RAIN_LEFT, RAIN_RIGHT - RAIN_LEFT) + RAIN_LEFT
			draw_line(Vector2(x0, y), Vector2(x0 - drop[2] * 0.12, y - drop[2]), Color(1.0, 0.8, 0.9, 0.22 * slant_a), 2)
		if digital > 0.01:
			_draw_digital(drop, y, Color(0.35, 1.0, 0.85), digital)
	if digital_left > 0.01:
		for n in int(lerpf(0.0, 70.0, pow(energy, 1.5))):
			var drop: Array = _left_drops[n]
			_draw_digital(drop, fposmod(drop[0].y + time * drop[1], 1100.0) - 20.0, Color(0.7, 1.0, 0.45), digital_left)

## A digital raindrop: a column of small blocks falling, brightest at the head.
func _draw_digital(drop: Array, y: float, color: Color, amount: float) -> void:
	var x := roundf(drop[0].x / 14.0) * 14.0
	for j in 6:
		var a := (1.0 - j / 6.0) * 0.5 * amount
		draw_rect(Rect2(x, y - j * 15.0, 6, 11), Color(color, a * (0.5 if j > 0 else 1.0)))
	draw_rect(Rect2(x - 1, y + 1, 8, 12), Color(1.0, 1.0, 1.0, 0.55 * amount))

func _draw_bolt() -> void:
	var age := time - _bolt_born
	if age > 0.32 or _bolt.is_empty():
		return
	var flicker := 1.0 if int(age * 60.0) % 4 != 3 else 0.45
	var fade := (1.0 - age / 0.32) * flicker
	for n in _bolt.size():
		var line: PackedVector2Array = _bolt[n]
		var scale := 1.0 if n == 0 else 0.55
		draw_polyline(line, Color(_bolt_color, 0.22 * fade), 22.0 * scale)
		draw_polyline(line, Color(_bolt_color, 0.6 * fade), 8.0 * scale)
		draw_polyline(line, Color(1.0, 1.0, 1.0, fade), 3.0 * scale)
	draw_circle(CLASH, 90.0 * fade, Color(_bolt_color, 0.25 * fade))
	draw_circle(CLASH, 36.0 * fade, Color(1.0, 1.0, 1.0, 0.5 * fade))
